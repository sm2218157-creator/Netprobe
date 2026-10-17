#!/data/data/com.termux/files/usr/bin/bash
set -e

PROJECT_DIR="${1:-$PWD}"
cd "$PROJECT_DIR" || { echo "✗ dir not found: $PROJECT_DIR"; exit 1; }
[ -d ".git" ] || { echo "✗ not a git repo. run 'git init' first."; exit 1; }

# detect environment
if command -v pkg >/dev/null 2>&1; then
    ENV="termux"
elif command -v apt-get >/dev/null 2>&1; then
    ENV="linux"
else
    ENV="unknown"
fi
echo "═══ NetProbe v20.0 Build & Deploy ═══"
echo "→ project: $PROJECT_DIR"
echo "→ env:     $ENV"
echo ""

# ═══ 1. setup.sh ═══
echo "[1/7] Creating setup.sh (edit later: nano setup.sh)"
cat > setup.sh << 'SETUP_EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -e
MEDIA="/sdcard/Android/media/com.xk.netprobe/NetProbe"
LOG="$MEDIA/setup.log"
mkdir -p "$MEDIA"
exec > >(tee -a "$LOG") 2>&1

log()  { echo -e "\033[36m[*] $1\033[0m"; }
ok()   { echo -e "\033[32m[+] $1\033[0m"; }
fail() { echo -e "\033[31m[!] $1\033[0m"; echo "ERROR: $1" > "$MEDIA/error.txt"; exit 1; }

rm -f "$MEDIA/error.txt" "$MEDIA/ready.txt"

log "1. Setting up Cloudflare mirror..."
mkdir -p "$PREFIX/etc/apt"
echo "deb https://packages-cf.termux.dev/apt/termux-main stable main" > "$PREFIX/etc/apt/sources.list"
ok "mirror set"

log "2. Requesting storage permission..."
termux-setup-storage || true
sleep 3
[ -d "/sdcard" ] || fail "storage permission denied"
mkdir -p "$MEDIA"
ok "storage ready"

log "3. Updating package index..."
pkg update -y || fail "pkg update failed"
ok "index updated"

log "4. Allowing external apps..."
mkdir -p "$HOME/.termux"
grep -q "allow-external-apps=true" "$HOME/.termux/termux.properties" \
    || echo "allow-external-apps=true" >> "$HOME/.termux/termux.properties"
termux-reload-settings 2>/dev/null || true
ok "external apps allowed"

log "5. Installing tools..."
pkg install -y nmap curl wget || fail "tool install failed"
ok "tools installed"

log "6. Verifying..."
command -v nmap >/dev/null || fail "nmap not found"
command -v curl >/dev/null || fail "curl not found"
ok "verification passed"

echo "READY" > "$MEDIA/ready.txt"
ok "Setup COMPLETE — return to NetProbe App."
SETUP_EOF
chmod +x setup.sh

# ═══ 2. Java files ═══
echo "[2/7] Creating Java files..."
mkdir -p app/src/main/java/com/xk/netprobe

cat > app/src/main/java/com/xk/netprobe/TermuxBridge.java << 'JAVA_EOF'
package com.xk.netprobe;

import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
import android.util.Log;

public class TermuxBridge {
    private static final String TAG = "TermuxBridge";
    public static final String ACTION_RESULT = "com.xk.netprobe.TERMUX_RESULT";
    public static final String EXTRA_STDOUT = "stdout";
    public static final String EXTRA_STDERR = "stderr";
    public static final String EXTRA_EXIT   = "exit";

    public static boolean isTermuxInstalled(Context ctx) {
        try {
            ctx.getPackageManager().getPackageInfo("com.termux", 0);
            return true;
        } catch (PackageManager.NameNotFoundException e) {
            return false;
        }
    }

    public static boolean runCommand(Context ctx, String cmd, int requestCode) {
        if (!isTermuxInstalled(ctx)) {
            Log.e(TAG, "Termux not installed");
            return false;
        }
        Intent intent = new Intent();
        intent.setClassName("com.termux", "com.termux.app.RunCommandService");
        intent.setAction("com.termux.RUN_COMMAND");
        intent.putExtra("com.termux.RUN_COMMAND_PATH", "/data/data/com.termux/files/usr/bin/bash");
        intent.putExtra("com.termux.RUN_COMMAND_ARGUMENTS", new String[]{"-c", cmd});
        intent.putExtra("com.termux.RUN_COMMAND_WORKDIR", "/data/data/com.termux/files/home");
        intent.putExtra("com.termux.RUN_COMMAND_BACKGROUND", false);

        Intent resultIntent = new Intent(ACTION_RESULT).setPackage(ctx.getPackageName());
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= 31) flags |= PendingIntent.FLAG_MUTABLE;
        PendingIntent pi = PendingIntent.getBroadcast(ctx, requestCode, resultIntent, flags);
        intent.putExtra("com.termux.RUN_COMMAND_PENDING_INTENT", pi);

        try {
            ctx.startService(intent);
            return true;
        } catch (Exception e) {
            Log.e(TAG, "startService failed", e);
            return false;
        }
    }

    public static void openTermux(Context ctx) {
        Intent i = new Intent();
        i.setClassName("com.termux", "com.termux.app.TermuxActivity");
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        try { ctx.startActivity(i); } catch (Exception ignored) {}
    }
}
JAVA_EOF

cat > app/src/main/java/com/xk/netprobe/FileHelper.java << 'JAVA_EOF'
package com.xk.netprobe;

import android.content.Context;
import android.util.Log;
import java.io.*;

public class FileHelper {
    private static final String TAG = "FileHelper";

    public static File dir(Context ctx) {
        File[] dirs = ctx.getExternalMediaDirs();
        File base = (dirs != null && dirs.length > 0) ? dirs[0] : ctx.getFilesDir();
        File dir = new File(base, "NetProbe");
        if (!dir.exists() && !dir.mkdirs()) {
            Log.e(TAG, "failed to create dir: " + dir.getAbsolutePath());
        }
        return dir;
    }

    public static String pathOf(Context ctx, String name) {
        return new File(dir(ctx), name).getAbsolutePath();
    }
    public static boolean exists(Context ctx, String name) {
        return new File(pathOf(ctx, name)).exists();
    }
    public static boolean delete(Context ctx, String name) {
        return new File(pathOf(ctx, name)).delete();
    }

    public static String read(Context ctx, String name) {
        File f = new File(pathOf(ctx, name));
        if (!f.exists()) return "";
        StringBuilder sb = new StringBuilder();
        try (BufferedReader br = new BufferedReader(new FileReader(f))) {
            String line;
            while ((line = br.readLine()) != null) sb.append(line).append("\n");
        } catch (Exception e) {
            Log.e(TAG, "read failed: " + name, e);
        }
        return sb.toString();
    }

    public static boolean write(Context ctx, String name, String data) {
        File target = new File(pathOf(ctx, name));
        File tmp = new File(target.getAbsolutePath() + ".tmp");
        try (FileWriter fw = new FileWriter(tmp)) {
            fw.write(data);
        } catch (Exception e) {
            Log.e(TAG, "write failed: " + name, e);
            return false;
        }
        return tmp.renameTo(target);
    }
}
JAVA_EOF

cat > app/src/main/java/com/xk/netprobe/NetworkDiscovery.java << 'JAVA_EOF'
package com.xk.netprobe;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class NetworkDiscovery {
    public interface Callback {
        void onDeviceFound(String ip);
        void onFinished(int total);
    }

    public static void scan(String subnet, Callback callback) {
        if (subnet == null || !subnet.contains(".")) {
            callback.onFinished(0);
            return;
        }
        ExecutorService executor = Executors.newFixedThreadPool(20);
        String base = subnet.substring(0, subnet.lastIndexOf('.'));
        final int[] count = {0};

        for (int i = 1; i <= 254; i++) {
            final String ip = base + "." + i;
            executor.execute(() -> {
                try {
                    java.net.InetAddress addr = java.net.InetAddress.getByName(ip);
                    if (addr.isReachable(800)) {
                        synchronized (count) { count[0]++; }
                        callback.onDeviceFound(ip);
                    }
                } catch (Exception ignored) {}
            });
        }

        executor.shutdown();
        new Thread(() -> {
            while (!executor.isTerminated()) {
                try { Thread.sleep(100); } catch (Exception ignored) {}
            }
            callback.onFinished(count[0]);
        }).start();
    }
}
JAVA_EOF

cat > app/src/main/java/com/xk/netprobe/NetInfo.java << 'JAVA_EOF'
package com.xk.netprobe;

import android.content.Context;
import android.net.wifi.WifiManager;
import android.util.Log;
import java.net.*;
import java.util.*;

public class NetInfo {
    private static final String TAG = "NetInfo";

    public static String getMyIp(Context ctx) {
        try {
            Enumeration<NetworkInterface> interfaces = NetworkInterface.getNetworkInterfaces();
            while (interfaces.hasMoreElements()) {
                NetworkInterface ni = interfaces.nextElement();
                if (!ni.isUp() || ni.isLoopback()) continue;
                String name = ni.getName().toLowerCase();
                if (name.startsWith("wlan") || name.startsWith("ap") || name.startsWith("eth")) {
                    Enumeration<InetAddress> addresses = ni.getInetAddresses();
                    while (addresses.hasMoreElements()) {
                        InetAddress addr = addresses.nextElement();
                        if (addr instanceof Inet4Address && !addr.isLoopbackAddress()) {
                            return addr.getHostAddress();
                        }
                    }
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "NetworkInterface failed", e);
        }

        try {
            WifiManager wm = (WifiManager) ctx.getApplicationContext()
                    .getSystemService(Context.WIFI_SERVICE);
            if (wm != null && wm.isWifiEnabled()) {
                int ip = wm.getConnectionInfo().getIpAddress();
                if (ip != 0) {
                    return String.format(Locale.US, "%d.%d.%d.%d",
                            (ip & 0xff), (ip >> 8 & 0xff),
                            (ip >> 16 & 0xff), (ip >> 24 & 0xff));
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "WifiManager failed", e);
        }
        return null;
    }

    public static String getSubnet(Context ctx) {
        String ip = getMyIp(ctx);
        if (ip == null) return null;
        int lastDot = ip.lastIndexOf('.');
        if (lastDot <= 0) return null;
        return ip.substring(0, lastDot) + ".0/24";
    }
}
JAVA_EOF

cat > app/src/main/java/com/xk/netprobe/MainActivity.java << 'JAVA_EOF'
package com.xk.netprobe;

import android.Manifest;
import android.content.BroadcastReceiver;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.content.res.ColorStateList;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;
import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

public class MainActivity extends AppCompatActivity {
    private TextView tvSetupStatus;
    private Button btnSetup;
    private static final int LOC_PERM_CODE = 101;
    private static final int SETUP_REQ_CODE = 202;
    private final Handler pollHandler = new Handler(Looper.getMainLooper());
    private boolean polling = false;

    private final Runnable pollRunnable = new Runnable() {
        @Override public void run() {
            if (!polling) return;
            refreshSetupState();
            if (FileHelper.exists(MainActivity.this, "ready.txt")
                || FileHelper.exists(MainActivity.this, "error.txt")) {
                polling = false;
                return;
            }
            pollHandler.postDelayed(this, 2000);
        }
    };

    private final BroadcastReceiver termuxResult = new BroadcastReceiver() {
        @Override public void onReceive(Context ctx, Intent intent) {
            int exit = intent.getIntExtra(TermuxBridge.EXTRA_EXIT, -1);
            String err = intent.getStringExtra(TermuxBridge.EXTRA_STDERR);
            if (exit != 0 && err != null) {
                Toast.makeText(ctx, "Setup error: " + err, Toast.LENGTH_LONG).show();
            }
            refreshSetupState();
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        tvSetupStatus = findViewById(R.id.tvSetupStatus);
        btnSetup = findViewById(R.id.btnSetup);

        btnSetup.setOnClickListener(v -> {
            if (FileHelper.exists(this, "ready.txt")) {
                Toast.makeText(this, "Settings are already active!", Toast.LENGTH_SHORT).show();
            } else launchSetup();
        });

        btnSetup.setOnLongClickListener(v -> {
            FileHelper.delete(this, "ready.txt");
            FileHelper.delete(this, "error.txt");
            launchSetup();
            return true;
        });

        findViewById(R.id.cardLocalNetwork).setOnClickListener(v -> {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
                    != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(this,
                        new String[]{Manifest.permission.ACCESS_FINE_LOCATION}, LOC_PERM_CODE);
            } else {
                startActivity(new Intent(this, LocalNetworkActivity.class));
            }
        });

        IntentFilter filter = new IntentFilter(TermuxBridge.ACTION_RESULT);
        ContextCompat.registerReceiver(this, termuxResult, filter,
                ContextCompat.RECEIVER_NOT_EXPORTED);
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        polling = false;
        try { unregisterReceiver(termuxResult); } catch (Exception ignored) {}
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions,
                                           @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == LOC_PERM_CODE && grantResults.length > 0
                && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            startActivity(new Intent(this, LocalNetworkActivity.class));
        } else {
            Toast.makeText(this, "Location permission is required for Wi-Fi scan",
                    Toast.LENGTH_LONG).show();
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        refreshSetupState();
        if (!FileHelper.exists(this, "ready.txt") && !FileHelper.exists(this, "error.txt")) {
            startPolling();
        }
    }

    @Override
    protected void onPause() {
        super.onPause();
        polling = false;
    }

    private void startPolling() {
        if (polling) return;
        polling = true;
        pollHandler.post(pollRunnable);
    }

    private void refreshSetupState() {
        if (FileHelper.exists(this, "error.txt")) {
            tvSetupStatus.setText("Status: Setup failed — long-press to retry");
            tvSetupStatus.setTextColor(0xFFF85149);
            btnSetup.setText("RETRY SETUP");
            btnSetup.setBackgroundTintList(ColorStateList.valueOf(0xFFDA3633));
            btnSetup.setEnabled(true);
            return;
        }
        if (FileHelper.exists(this, "ready.txt")) {
            tvSetupStatus.setText("Status: Setup Ready ✓");
            tvSetupStatus.setTextColor(0xFF3FB950);
            btnSetup.setText("تم تفعيل الإعدادات");
            btnSetup.setBackgroundTintList(ColorStateList.valueOf(0xFF3FB950));
            btnSetup.setEnabled(false);
        } else {
            tvSetupStatus.setText("Status: Setup needed");
            tvSetupStatus.setTextColor(0xFFF85149);
            btnSetup.setText("SETUP TERMUX");
            btnSetup.setBackgroundTintList(ColorStateList.valueOf(0xFF1F6FEB));
            btnSetup.setEnabled(true);
        }
    }

    private void launchSetup() {
        if (!TermuxBridge.isTermuxInstalled(this)) {
            Toast.makeText(this, "Termux not installed. Install it first.", Toast.LENGTH_LONG).show();
            return;
        }
        String cmd = "curl -sL https://raw.githubusercontent.com/sm2218157-creator/Netprobe/main/setup.sh -o setup.sh && bash setup.sh";
        boolean sent = TermuxBridge.runCommand(this, cmd, SETUP_REQ_CODE);
        if (sent) {
            Toast.makeText(this, "Setup running in Termux", Toast.LENGTH_LONG).show();
            tvSetupStatus.setText("Status: Running setup...");
            tvSetupStatus.setTextColor(0xFFF0B72F);
            startPolling();
            TermuxBridge.openTermux(this);
        } else {
            ClipboardManager clipboard = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
            if (clipboard != null) {
                clipboard.setPrimaryClip(ClipData.newPlainText("setup", cmd));
            }
            Toast.makeText(this, "Copied! Paste in Termux, then return here.",
                    Toast.LENGTH_LONG).show();
            TermuxBridge.openTermux(this);
        }
    }
}
JAVA_EOF

cat > app/src/main/java/com/xk/netprobe/LocalNetworkActivity.java << 'JAVA_EOF'
package com.xk.netprobe;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.net.wifi.WifiManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.widget.TextView;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.content.ContextCompat;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class LocalNetworkActivity extends AppCompatActivity {
    private static final int NMAP_REQ_CODE = 303;

    private TextView tvSsid, tvSubnet, tvStatus, tvMyIp;
    private DeviceAdapter adapter;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private boolean isRunning = true;
    private int pollSeconds = 0;

    private final BroadcastReceiver nmapResult = new BroadcastReceiver() {
        @Override public void onReceive(Context ctx, Intent intent) {
            int exit = intent.getIntExtra(TermuxBridge.EXTRA_EXIT, -1);
            String out = intent.getStringExtra(TermuxBridge.EXTRA_STDOUT);
            if (exit == 0 && out != null && !out.isEmpty()) {
                updatePorts(out);
            } else if (exit != 0) {
                tvStatus.setText("Nmap failed (exit " + exit + ")");
                tvStatus.setTextColor(0xFFF85149);
            }
        }
    };

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        setContentView(R.layout.activity_local);

        tvSsid = findViewById(R.id.tvSsid);
        tvSubnet = findViewById(R.id.tvSubnet);
        tvStatus = findViewById(R.id.tvStatus);
        tvMyIp = findViewById(R.id.tvMyIp);

        RecyclerView recycler = findViewById(R.id.recyclerDevices);
        recycler.setLayoutManager(new LinearLayoutManager(this));
        adapter = new DeviceAdapter();
        recycler.setAdapter(adapter);

        if (!TermuxBridge.isTermuxInstalled(this)) {
            Toast.makeText(this, "Termux is not installed", Toast.LENGTH_LONG).show();
            finish();
            return;
        }

        String myIp = NetInfo.getMyIp(this);
        String subnet = NetInfo.getSubnet(this);
        if (subnet == null) {
            tvStatus.setText("Could not detect Wi-Fi network");
            tvStatus.setTextColor(0xFFF85149);
            return;
        }

        tvMyIp.setText("My IP: " + myIp);
        tvSubnet.setText("Subnet: " + subnet);

        WifiManager wm = (WifiManager) getApplicationContext().getSystemService(WIFI_SERVICE);
        if (wm != null && wm.getConnectionInfo() != null) {
            String ssid = wm.getConnectionInfo().getSSID().replace("\"", "");
            tvSsid.setText(ssid.isEmpty() || ssid.equals("<unknown ssid>") ? "Unknown" : ssid);
        }

        IntentFilter filter = new IntentFilter(TermuxBridge.ACTION_RESULT);
        ContextCompat.registerReceiver(this, nmapResult, filter,
                ContextCompat.RECEIVER_NOT_EXPORTED);

        startDiscovery(subnet);
    }

    private void startDiscovery(String subnet) {
        tvStatus.setText("Scanning network...");
        NetworkDiscovery.scan(subnet, new NetworkDiscovery.Callback() {
            @Override public void onDeviceFound(String ip) {
                if (!isRunning) return;
                handler.post(() -> adapter.addDevice(ip));
            }
            @Override public void onFinished(int total) {
                if (!isRunning) return;
                handler.post(() -> {
                    tvStatus.setText("Found " + total + " devices. Scanning ports...");
                    scanPorts();
                });
            }
        });
    }

    private void scanPorts() {
        StringBuilder targets = new StringBuilder();
        for (int i = 0; i < adapter.getItemCount(); i++) {
            targets.append(adapter.getIpAt(i)).append("\n");
        }
        if (targets.length() == 0) {
            tvStatus.setText("No devices to scan.");
            return;
        }
        String targetsPath = FileHelper.pathOf(this, "targets.txt");
        String outPath = FileHelper.pathOf(this, "ports.txt");
        FileHelper.write(this, "targets.txt", targets.toString());
        FileHelper.write(this, "ports.txt", "");

        String cmd = "export PATH=/data/data/com.termux/files/usr/bin:$PATH; "
                + "timeout 45 nmap -sT -T4 -F -iL \"" + targetsPath + "\" > \"" + outPath + "\" 2>&1; "
                + "echo DONE >> \"" + outPath + "\"";

        boolean sent = TermuxBridge.runCommand(this, cmd, NMAP_REQ_CODE);
        if (!sent) {
            tvStatus.setText("Failed to reach Termux");
            tvStatus.setTextColor(0xFFF85149);
            return;
        }
        pollSeconds = 0;
        pollPorts(outPath);
    }

    private void pollPorts(String path) {
        if (!isRunning) return;
        if (pollSeconds++ > 55) {
            tvStatus.setText("Timeout. Termux might be busy.");
            tvStatus.setTextColor(0xFFF85149);
            return;
        }
        handler.postDelayed(() -> {
            String data = FileHelper.read(this, "ports.txt");
            if (data.contains("DONE")) updatePorts(data);
            else pollPorts(path);
        }, 1000);
    }

    private void updatePorts(String data) {
        String currentIp = null;
        int portCount = 0;
        Pattern p = Pattern.compile("([0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3})");
        for (String line : data.split("\n")) {
            if (line.contains("Nmap scan report for")) {
                Matcher m = p.matcher(line);
                if (m.find()) {
                    if (currentIp != null) adapter.updatePorts(currentIp, portCount);
                    currentIp = m.group(1);
                    portCount = 0;
                }
            } else if (line.contains("/tcp") && line.contains("open")) {
                portCount++;
            }
        }
        if (currentIp != null) adapter.updatePorts(currentIp, portCount);
        tvStatus.setText("Scan Complete.");
        tvStatus.setTextColor(0xFF3FB950);
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        isRunning = false;
        handler.removeCallbacksAndMessages(null);
        try { unregisterReceiver(nmapResult); } catch (Exception ignored) {}
    }
}
JAVA_EOF

# ═══ 3. XML resources ═══
echo "[3/7] Creating XML resources..."
mkdir -p app/src/main/res/{layout,drawable,values}

cat > app/src/main/res/values/styles.xml << 'XML_EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="AppTheme" parent="Theme.MaterialComponents.NoActionBar">
        <item name="android:windowBackground">#0D1117</item>
        <item name="android:statusBarColor">#161B22</item>
        <item name="colorPrimary">#58A6FF</item>
    </style>
</resources>
XML_EOF

cat > app/src/main/res/drawable/ic_launcher.xml << 'XML_EOF'
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
    <path android:fillColor="#0D1117" android:pathData="M0,0h108v108h-108z"/>
    <path android:fillColor="#3FB950" android:pathData="M20,30 L50,30 L50,50 L20,50 Z"/>
    <path android:fillColor="#58A6FF" android:pathData="M20,60 L80,60 L80,80 L20,80 Z"/>
</vector>
XML_EOF

cat > app/src/main/res/drawable/circle_bg.xml << 'XML_EOF'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="oval">
    <solid android:color="#21262D" />
</shape>
XML_EOF

cat > app/src/main/res/layout/activity_main.xml << 'XML_EOF'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:app="http://schemas.android.com/apk/res-auto"
    android:layout_width="match_parent" android:layout_height="match_parent"
    android:orientation="vertical" android:background="#0D1117" android:padding="16dp">

    <androidx.cardview.widget.CardView
        android:layout_width="match_parent" android:layout_height="wrap_content"
        app:cardBackgroundColor="#161B22" app:cardCornerRadius="12dp" app:cardElevation="0dp">
        <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content"
            android:orientation="vertical" android:padding="20dp" android:gravity="center">
            <TextView android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:text="NetProbe" android:textColor="#58A6FF" android:textSize="24sp" android:textStyle="bold"/>
            <TextView android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:text="v20.0" android:textColor="#8B949E" android:textSize="12sp"/>
            <TextView android:id="@+id/tvSetupStatus" android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:text="Status: Setup needed" android:textColor="#F85149" android:textSize="14sp" android:textStyle="bold"
                android:layout_marginTop="10dp"/>
            <TextView android:layout_width="match_parent" android:layout_height="wrap_content"
                android:text="اضغط الزر بالأسفل للذهاب إلى Termux ولصق السكربت لتفعيل الإعدادات."
                android:textColor="#C9D1D9" android:textSize="12sp" android:gravity="center" android:layout_marginTop="8dp" android:layout_marginBottom="16dp"/>
            <Button android:id="@+id/btnSetup" android:layout_width="match_parent" android:layout_height="wrap_content"
                android:text="SETUP TERMUX" android:textColor="#FFFFFF" android:backgroundTint="#1F6FEB"/>
        </LinearLayout>
    </androidx.cardview.widget.CardView>

    <TextView android:layout_width="match_parent" android:layout_height="wrap_content"
        android:text="الأدوات والأقسام" android:textColor="#8B949E" android:layout_marginTop="24dp" android:layout_marginBottom="12dp"/>

    <androidx.cardview.widget.CardView
        android:id="@+id/cardLocalNetwork"
        android:layout_width="match_parent" android:layout_height="wrap_content"
        app:cardBackgroundColor="#161B22" app:cardCornerRadius="12dp" app:cardElevation="0dp">
        <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content"
            android:orientation="horizontal" android:padding="20dp" android:gravity="center_vertical">
            <TextView android:layout_width="0dp" android:layout_height="wrap_content" android:layout_weight="1"
                android:text="الشبكة المحلية\nاكتشاف الأجهزة المتصلة" android:textColor="#C9D1D9" android:textSize="14sp"/>
            <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="→" android:textSize="24sp" android:textColor="#58A6FF"/>
        </LinearLayout>
    </androidx.cardview.widget.CardView>
</LinearLayout>
XML_EOF

cat > app/src/main/res/layout/activity_local.xml << 'XML_EOF'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:app="http://schemas.android.com/apk/res-auto"
    android:layout_width="match_parent" android:layout_height="match_parent"
    android:orientation="vertical" android:background="#0D1117" android:padding="16dp">

    <androidx.cardview.widget.CardView
        android:layout_width="match_parent" android:layout_height="wrap_content"
        android:layout_marginBottom="16dp" app:cardBackgroundColor="#161B22" app:cardCornerRadius="12dp" app:cardElevation="0dp">
        <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content"
            android:orientation="vertical" android:padding="20dp">
            <TextView android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:text="NETWORK INFO" android:textColor="#58A6FF" android:textSize="12sp" android:textStyle="bold"/>
            <TextView android:id="@+id/tvSsid" android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:text="Wi-Fi Name" android:textColor="#C9D1D9" android:textSize="18sp" android:layout_marginTop="8dp"/>
            <TextView android:id="@+id/tvMyIp" android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:text="My IP: 192.168.x.x" android:textColor="#F85149" android:textSize="14sp" android:layout_marginTop="4dp" android:textStyle="bold"/>
            <TextView android:id="@+id/tvSubnet" android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:text="Subnet: 192.168.1.0/24" android:textColor="#8B949E" android:textSize="12sp" android:layout_marginTop="4dp"/>
            <TextView android:id="@+id/tvStatus" android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:text="Scanning the network..." android:textColor="#3FB950" android:textSize="12sp" android:layout_marginTop="8dp"/>
        </LinearLayout>
    </androidx.cardview.widget.CardView>

    <androidx.recyclerview.widget.RecyclerView
        android:id="@+id/recyclerDevices"
        android:layout_width="match_parent" android:layout_height="match_parent"/>
</LinearLayout>
XML_EOF

cat > app/src/main/res/layout/item_device.xml << 'XML_EOF'
<?xml version="1.0" encoding="utf-8"?>
<androidx.cardview.widget.CardView xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:app="http://schemas.android.com/apk/res-auto"
    android:layout_width="match_parent" android:layout_height="wrap_content"
    android:layout_marginBottom="8dp" app:cardBackgroundColor="#161B22" app:cardCornerRadius="8dp" app:cardElevation="0dp">
    <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content"
        android:orientation="horizontal" android:padding="16dp" android:gravity="center_vertical">
        <TextView android:id="@+id/tvPortCount" android:layout_width="36dp" android:layout_height="36dp"
            android:background="@drawable/circle_bg" android:gravity="center" android:text="?"
            android:textColor="#58A6FF" android:textStyle="bold"/>
        <LinearLayout android:layout_width="0dp" android:layout_height="wrap_content" android:layout_weight="1"
            android:orientation="vertical" android:paddingStart="16dp">
            <TextView android:id="@+id/tvIp" android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:text="192.168.1.1" android:textColor="#C9D1D9" android:textSize="16sp" android:textStyle="bold"/>
            <TextView android:id="@+id/tvVendor" android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:text="Device" android:textColor="#8B949E" android:textSize="12sp"/>
        </LinearLayout>
    </LinearLayout>
</androidx.cardview.widget.CardView>
XML_EOF

# ═══ 4. app/build.gradle ═══
echo "[4/7] Creating app/build.gradle..."
cat > app/build.gradle << 'GRADLE_EOF'
plugins { id 'com.android.application' }
android {
    namespace 'com.xk.netprobe'
    compileSdk 34
    defaultConfig {
        applicationId "com.xk.netprobe"
        minSdk 24
        targetSdk 34
        versionCode 20
        versionName "20.0"
    }
    buildTypes { release { minifyEnabled false } }
    compileOptions { sourceCompatibility JavaVersion.VERSION_17; targetCompatibility JavaVersion.VERSION_17 }
}
dependencies {
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'androidx.recyclerview:recyclerview:1.3.2'
    implementation 'androidx.cardview:cardview:1.0.0'
    implementation 'com.google.android.material:material:1.11.0'
}
GRADLE_EOF

# ═══ 5. CHANGELOG ═══
echo "[5/7] Creating CHANGELOG.md..."
cat > CHANGELOG.md << 'MD_EOF'
# NetProbe Changelog

## v20.0 — Major Rewrite

### Fixed
- NetworkDiscovery: Runtime.exec fails on Android 10+ → InetAddress.isReachable()
- TermuxBridge: added PendingIntent to receive stdout/stderr/exit
- MainActivity: polling on ready.txt/error.txt + retry
- FileHelper: added delete(), atomic write, error logging
- setup.sh: set -e, error.txt on failure, nmap/curl verification
- NetInfo: NetworkInterface first, returns null on failure
- LocalNetworkActivity: Termux check, 55s polling

### Changed
- versionCode: 19 → 20
- versionName: "19.0" → "20.0"
- Discovery threads: 50 → 20
MD_EOF

# ═══ 6. Git push ═══
echo "[6/7] Committing & pushing to GitHub..."
git add -A
if git diff --cached --quiet; then
    echo "  (no changes to commit)"
else
    git commit -m "v20.0: full rewrite" || true
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
if git push origin "$BRANCH"; then
    echo "  ✓ pushed to origin/$BRANCH"
else
    echo "  ⚠ push failed — check credentials"
fi

# ═══ 7. Zip & open ═══
echo "[7/7] Creating ZIP..."
ZIP_NAME="NetProbe_v20.0_$(date +%Y%m%d_%H%M%S).zip"
ZIP_PATH="$PROJECT_DIR/$ZIP_NAME"

# install zip if needed (works in both envs)
if ! command -v zip >/dev/null 2>&1; then
    if [ "$ENV" = "termux" ]; then
        pkg install -y zip >/dev/null 2>&1 || true
    elif [ "$ENV" = "linux" ]; then
        sudo apt-get update -qq >/dev/null 2>&1 || true
        sudo apt-get install -y zip >/dev/null 2>&1 || true
    fi
fi

cd "$PROJECT_DIR"
zip -r "$ZIP_NAME" . -x "*.git/*" "build/*" "app/build/*" "*.zip" "gradlew.bat" >/dev/null
echo "  ✓ $ZIP_NAME ($(du -h "$ZIP_PATH" | cut -f1))"

# open in explorer only on termux
if [ "$ENV" = "termux" ] && command -v termux-open >/dev/null 2>&1; then
    termux-open --content-type application/zip "$ZIP_PATH" 2>/dev/null || true
fi

echo ""
echo "═══════════════════════════════════════════"
echo " ✓ v20.0 complete"
echo "═══════════════════════════════════════════"
echo " setup.sh → $PROJECT_DIR/setup.sh  (edit: nano setup.sh)"
echo " ZIP      → $ZIP_PATH"
echo " GitHub   → origin/$BRANCH"
if [ "$ENV" = "linux" ]; then
    echo ""
    echo " ℹ Running in Linux/Codespaces — ZIP will be in file explorer"
    echo "   (in VS Code: click the file in the left sidebar → Download)"
fi
echo ""
