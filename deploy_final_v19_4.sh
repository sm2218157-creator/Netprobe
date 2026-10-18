#!/bin/bash
set -e

echo "⏳ [1/6] Writing project files (v19.4)..."

# 1. setup.sh
cat > setup.sh << 'EOF'
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
grep -q "allow-external-apps=true" "$HOME/.termux/termux.properties" || echo "allow-external-apps=true" >> "$HOME/.termux/termux.properties"
termux-reload-settings 2>/dev/null || true
ok "external apps allowed"
log "5. Installing tools..."
pkg install -y nmap curl wget || fail "tool install failed"
command -v nmap >/dev/null || fail "nmap not found"
command -v curl >/dev/null || fail "curl not found"
echo "READY" > "$MEDIA/ready.txt"
ok "Setup COMPLETE — return to NetProbe App."
EOF

# 2. TermuxBridge.java
mkdir -p app/src/main/java/com/xk/netprobe
cat > app/src/main/java/com/xk/netprobe/TermuxBridge.java << 'EOF'
package com.xk.netprobe;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
import android.util.Log;
public class TermuxBridge {
    public static final String ACTION_RESULT = "com.xk.netprobe.TERMUX_RESULT";
    public static final String EXTRA_STDOUT = "stdout";
    public static final String EXTRA_STDERR = "stderr";
    public static final String EXTRA_EXIT   = "exit";
    public static boolean isTermuxInstalled(Context ctx) {
        try { ctx.getPackageManager().getPackageInfo("com.termux", 0); return true; } catch (Exception e) { return false; }
    }
    public static boolean runCommand(Context ctx, String cmd, int requestCode) {
        if (!isTermuxInstalled(ctx)) return false;
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
        intent.putExtra("com.termux.RUN_COMMAND_PENDING_INTENT", PendingIntent.getBroadcast(ctx, requestCode, resultIntent, flags));
        try { ctx.startService(intent); return true; } catch (Exception e) { return false; }
    }
    public static void openTermux(Context ctx) {
        Intent i = new Intent(); i.setClassName("com.termux", "com.termux.app.TermuxActivity"); i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        try { ctx.startActivity(i); } catch (Exception ignored) {}
    }
}
EOF

# 3. FileHelper.java
cat > app/src/main/java/com/xk/netprobe/FileHelper.java << 'EOF'
package com.xk.netprobe;
import android.content.Context;
import android.util.Log;
import java.io.*;
public class FileHelper {
    public static File dir(Context ctx) {
        File[] dirs = ctx.getExternalMediaDirs();
        File base = (dirs != null && dirs.length > 0) ? dirs[0] : ctx.getFilesDir();
        File dir = new File(base, "NetProbe"); if (!dir.exists()) dir.mkdirs(); return dir;
    }
    public static String pathOf(Context ctx, String name) { return new File(dir(ctx), name).getAbsolutePath(); }
    public static boolean exists(Context ctx, String name) { return new File(pathOf(ctx, name)).exists(); }
    public static boolean delete(Context ctx, String name) { return new File(pathOf(ctx, name)).delete(); }
    public static String read(Context ctx, String name) {
        File f = new File(pathOf(ctx, name)); if (!f.exists()) return "";
        StringBuilder sb = new StringBuilder();
        try (BufferedReader br = new BufferedReader(new FileReader(f))) { String l; while ((l = br.readLine()) != null) sb.append(l).append("\n"); } catch (Exception ignored) {}
        return sb.toString();
    }
    public static boolean write(Context ctx, String name, String data) {
        File target = new File(pathOf(ctx, name)); File tmp = new File(target.getAbsolutePath() + ".tmp");
        try (FileWriter fw = new FileWriter(tmp)) { fw.write(data); } catch (Exception e) { return false; }
        return tmp.renameTo(target);
    }
}
EOF

# 4. NetworkDiscovery.java
cat > app/src/main/java/com/xk/netprobe/NetworkDiscovery.java << 'EOF'
package com.xk.netprobe;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
public class NetworkDiscovery {
    public interface Callback { void onDeviceFound(String ip); void onFinished(int total); }
    public static void scan(String subnet, Callback callback) {
        if (subnet == null || !subnet.contains(".")) { callback.onFinished(0); return; }
        ExecutorService executor = Executors.newFixedThreadPool(20);
        String base = subnet.substring(0, subnet.lastIndexOf('.'));
        final int[] count = {0};
        for (int i = 1; i <= 254; i++) {
            final String ip = base + "." + i;
            executor.execute(() -> {
                try { if (java.net.InetAddress.getByName(ip).isReachable(800)) { synchronized (count) { count[0]++; } callback.onDeviceFound(ip); } } catch (Exception ignored) {}
            });
        }
        executor.shutdown();
        new Thread(() -> { while (!executor.isTerminated()) { try { Thread.sleep(100); } catch (Exception ignored) {} } callback.onFinished(count[0]); }).start();
    }
}
EOF

# 5. NetInfo.java
cat > app/src/main/java/com/xk/netprobe/NetInfo.java << 'EOF'
package com.xk.netprobe;
import android.content.Context;
import android.net.wifi.WifiManager;
import android.util.Log;
import java.net.*;
import java.util.*;
public class NetInfo {
    public static String getMyIp(Context ctx) {
        try {
            Enumeration<NetworkInterface> interfaces = NetworkInterface.getNetworkInterfaces();
            while (interfaces.hasMoreElements()) {
                NetworkInterface ni = interfaces.nextElement();
                if (!ni.isUp() || ni.isLoopback()) continue;
                String name = ni.getName().toLowerCase();
                if (name.startsWith("wlan") || name.startsWith("eth")) {
                    Enumeration<InetAddress> addresses = ni.getInetAddresses();
                    while (addresses.hasMoreElements()) {
                        InetAddress addr = addresses.nextElement();
                        if (addr instanceof Inet4Address && !addr.isLoopbackAddress()) return addr.getHostAddress();
                    }
                }
            }
        } catch (Exception ignored) {}
        try {
            WifiManager wm = (WifiManager) ctx.getApplicationContext().getSystemService(Context.WIFI_SERVICE);
            if (wm != null && wm.isWifiEnabled()) {
                int ip = wm.getConnectionInfo().getIpAddress();
                if (ip != 0) return String.format(Locale.US, "%d.%d.%d.%d", (ip & 0xff), (ip >> 8 & 0xff), (ip >> 16 & 0xff), (ip >> 24 & 0xff));
            }
        } catch (Exception ignored) {}
        return null;
    }
    public static String getSubnet(Context ctx) {
        String ip = getMyIp(ctx); if (ip == null) return null;
        int lastDot = ip.lastIndexOf('.'); if (lastDot <= 0) return null;
        return ip.substring(0, lastDot) + ".0/24";
    }
}
EOF

# 6. MainActivity.java
cat > app/src/main/java/com/xk/netprobe/MainActivity.java << 'EOF'
package com.xk.netprobe;
import android.Manifest;
import android.content.*;
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
    private TextView tvSetupStatus; private Button btnSetup;
    private static final int LOC_PERM_CODE = 101; private static final int SETUP_REQ_CODE = 202;
    private final Handler pollHandler = new Handler(Looper.getMainLooper()); private boolean polling = false;
    private final Runnable pollRunnable = new Runnable() {
        @Override public void run() {
            if (!polling) return; refreshSetupState();
            if (FileHelper.exists(MainActivity.this, "ready.txt") || FileHelper.exists(MainActivity.this, "error.txt")) { polling = false; return; }
            pollHandler.postDelayed(this, 2000);
        }
    };
    private final BroadcastReceiver termuxResult = new BroadcastReceiver() {
        @Override public void onReceive(Context ctx, Intent intent) { refreshSetupState(); }
    };
    @Override protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        tvSetupStatus = findViewById(R.id.tvSetupStatus); btnSetup = findViewById(R.id.btnSetup);
        btnSetup.setOnClickListener(v -> { if (FileHelper.exists(this, "ready.txt")) Toast.makeText(this, "Already active!", Toast.LENGTH_SHORT).show(); else launchSetup(); });
        btnSetup.setOnLongClickListener(v -> { FileHelper.delete(this, "ready.txt"); FileHelper.delete(this, "error.txt"); launchSetup(); return true; });
        findViewById(R.id.cardLocalNetwork).setOnClickListener(v -> {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) ActivityCompat.requestPermissions(this, new String[]{Manifest.permission.ACCESS_FINE_LOCATION}, LOC_PERM_CODE);
            else startActivity(new Intent(this, LocalNetworkActivity.class));
        });
        ContextCompat.registerReceiver(this, termuxResult, new IntentFilter(TermuxBridge.ACTION_RESULT), ContextCompat.RECEIVER_NOT_EXPORTED);
    }
    @Override protected void onDestroy() { super.onDestroy(); polling = false; try { unregisterReceiver(termuxResult); } catch (Exception ignored) {} }
    @Override public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == LOC_PERM_CODE && grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) startActivity(new Intent(this, LocalNetworkActivity.class));
    }
    @Override protected void onResume() { super.onResume(); refreshSetupState(); if (!FileHelper.exists(this, "ready.txt") && !FileHelper.exists(this, "error.txt")) startPolling(); }
    @Override protected void onPause() { super.onPause(); polling = false; }
    private void startPolling() { if (polling) return; polling = true; pollHandler.post(pollRunnable); }
    private void refreshSetupState() {
        if (FileHelper.exists(this, "error.txt")) {
            tvSetupStatus.setText("Status: Setup failed — long-press to retry"); tvSetupStatus.setTextColor(0xFFF85149);
            btnSetup.setText("RETRY SETUP"); btnSetup.setBackgroundTintList(ColorStateList.valueOf(0xFFDA3633)); btnSetup.setEnabled(true);
        } else if (FileHelper.exists(this, "ready.txt")) {
            tvSetupStatus.setText("Status: Setup Ready ✓"); tvSetupStatus.setTextColor(0xFF3FB950);
            btnSetup.setText("تم تفعيل الإعدادات"); btnSetup.setBackgroundTintList(ColorStateList.valueOf(0xFF3FB950)); btnSetup.setEnabled(false);
        } else {
            tvSetupStatus.setText("Status: Setup needed"); tvSetupStatus.setTextColor(0xFFF85149);
            btnSetup.setText("SETUP TERMUX"); btnSetup.setBackgroundTintList(ColorStateList.valueOf(0xFF1F6FEB)); btnSetup.setEnabled(true);
        }
    }
    private void launchSetup() {
        if (!TermuxBridge.isTermuxInstalled(this)) { Toast.makeText(this, "Termux not installed.", Toast.LENGTH_LONG).show(); return; }
        String cmd = "pkg install curl -y && curl -fsSL https://raw.githubusercontent.com/sm2218157-creator/Netprobe/main/setup.sh -o setup.sh && bash setup.sh";
        if (TermuxBridge.runCommand(this, cmd, SETUP_REQ_CODE)) {
            tvSetupStatus.setText("Status: Running setup..."); tvSetupStatus.setTextColor(0xFFF0B72F); startPolling(); TermuxBridge.openTermux(this);
        } else {
            ((ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE)).setPrimaryClip(ClipData.newPlainText("setup", cmd));
            Toast.makeText(this, "Copied! Paste in Termux.", Toast.LENGTH_LONG).show(); TermuxBridge.openTermux(this);
        }
    }
}
EOF

# 7. LocalNetworkActivity.java
cat > app/src/main/java/com/xk/netprobe/LocalNetworkActivity.java << 'EOF'
package com.xk.netprobe;
import android.content.*;
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
    private TextView tvSsid, tvSubnet, tvStatus, tvMyIp; private DeviceAdapter adapter;
    private final Handler handler = new Handler(Looper.getMainLooper()); private boolean isRunning = true; private int pollSeconds = 0;
    private final BroadcastReceiver nmapResult = new BroadcastReceiver() {
        @Override public void onReceive(Context ctx, Intent intent) {
            int exit = intent.getIntExtra(TermuxBridge.EXTRA_EXIT, -1);
            String out = intent.getStringExtra(TermuxBridge.EXTRA_STDOUT);
            if (exit == 0 && out != null && !out.isEmpty()) updatePorts(out);
            else if (exit != 0) { tvStatus.setText("Nmap failed."); tvStatus.setTextColor(0xFFF85149); }
        }
    };
    @Override protected void onCreate(Bundle b) {
        super.onCreate(b); setContentView(R.layout.activity_local);
        tvSsid = findViewById(R.id.tvSsid); tvSubnet = findViewById(R.id.tvSubnet); tvStatus = findViewById(R.id.tvStatus); tvMyIp = findViewById(R.id.tvMyIp);
        RecyclerView recycler = findViewById(R.id.recyclerDevices); recycler.setLayoutManager(new LinearLayoutManager(this));
        adapter = new DeviceAdapter(); recycler.setAdapter(adapter);
        if (!TermuxBridge.isTermuxInstalled(this)) { Toast.makeText(this, "Termux not installed", Toast.LENGTH_LONG).show(); finish(); return; }
        String myIp = NetInfo.getMyIp(this); String subnet = NetInfo.getSubnet(this);
        if (subnet == null) { tvStatus.setText("Could not detect Wi-Fi"); tvStatus.setTextColor(0xFFF85149); return; }
        tvMyIp.setText("My IP: " + myIp); tvSubnet.setText("Subnet: " + subnet);
        WifiManager wm = (WifiManager) getApplicationContext().getSystemService(WIFI_SERVICE);
        if (wm != null && wm.getConnectionInfo() != null) {
            String ssid = wm.getConnectionInfo().getSSID().replace("\"", "");
            tvSsid.setText(ssid.isEmpty() || ssid.equals("<unknown ssid>") ? "Unknown" : ssid);
        }
        ContextCompat.registerReceiver(this, nmapResult, new IntentFilter(TermuxBridge.ACTION_RESULT), ContextCompat.RECEIVER_NOT_EXPORTED);
        startDiscovery(subnet);
    }
    private void startDiscovery(String subnet) {
        tvStatus.setText("Scanning network...");
        NetworkDiscovery.scan(subnet, new NetworkDiscovery.Callback() {
            @Override public void onDeviceFound(String ip) { if (!isRunning) return; handler.post(() -> adapter.addDevice(ip)); }
            @Override public void onFinished(int total) { if (!isRunning) return; handler.post(() -> { tvStatus.setText("Found " + total + " devices. Scanning ports..."); scanPorts(); }); }
        });
    }
    private void scanPorts() {
        StringBuilder targets = new StringBuilder();
        for (int i = 0; i < adapter.getItemCount(); i++) targets.append(adapter.getIpAt(i)).append("\n");
        if (targets.length() == 0) { tvStatus.setText("No devices."); return; }
        String targetsPath = FileHelper.pathOf(this, "targets.txt"); String outPath = FileHelper.pathOf(this, "ports.txt");
        FileHelper.write(this, "targets.txt", targets.toString()); FileHelper.write(this, "ports.txt", "");
        String cmd = "export PATH=/data/data/com.termux/files/usr/bin:$PATH; timeout 45 nmap -sT -T4 -F -iL \"" + targetsPath + "\" > \"" + outPath + "\" 2>&1; echo DONE >> \"" + outPath + "\"";
        if (!TermuxBridge.runCommand(this, cmd, NMAP_REQ_CODE)) { tvStatus.setText("Failed to reach Termux"); tvStatus.setTextColor(0xFFF85149); return; }
        pollSeconds = 0; pollPorts(outPath);
    }
    private void pollPorts(String path) {
        if (!isRunning) return; if (pollSeconds++ > 55) { tvStatus.setText("Timeout."); tvStatus.setTextColor(0xFFF85149); return; }
        handler.postDelayed(() -> { String data = FileHelper.read(this, "ports.txt"); if (data.contains("DONE")) updatePorts(data); else pollPorts(path); }, 1000);
    }
    private void updatePorts(String data) {
        String currentIp = null; int portCount = 0;
        Pattern p = Pattern.compile("([0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3})");
        for (String line : data.split("\n")) {
            if (line.contains("Nmap scan report for")) {
                Matcher m = p.matcher(line);
                if (m.find()) { if (currentIp != null) adapter.updatePorts(currentIp, portCount); currentIp = m.group(1); portCount = 0; }
            } else if (line.contains("/tcp") && line.contains("open")) portCount++;
        }
        if (currentIp != null) adapter.updatePorts(currentIp, portCount);
        tvStatus.setText("Scan Complete."); tvStatus.setTextColor(0xFF3FB950);
    }
    @Override protected void onDestroy() { super.onDestroy(); isRunning = false; handler.removeCallbacksAndMessages(null); try { unregisterReceiver(nmapResult); } catch (Exception ignored) {} }
}
EOF

echo "⏳ [2/6] Overwriting app/build.gradle completely..."
cat > app/build.gradle << 'EOF'
plugins { id 'com.android.application' }
android {
    namespace 'com.xk.netprobe'
    compileSdk 34
    defaultConfig {
        applicationId "com.xk.netprobe"
        minSdk 24
        targetSdk 34
        versionCode 20
        versionName "19.4"
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
EOF

echo "⏳ [3/6] Fixing gradle.properties and resources..."
# إصلاح مسار الجافا
echo "org.gradle.jvmargs=-Xmx2g -Dfile.encoding=UTF-8" > gradle.properties
echo "android.useAndroidX=true" >> gradle.properties
echo "android.nonTransitiveRClass=true" >> gradle.properties

# إصلاح الموارد (منع الخطأ السابق)
rm -f app/src/main/res/values/themes.xml
rm -f app/src/main/res/values/colors.xml
mkdir -p app/src/main/res/values
cat > app/src/main/res/values/styles.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="AppTheme" parent="Theme.MaterialComponents.NoActionBar">
        <item name="android:windowBackground">#0D1117</item>
        <item name="android:statusBarColor">#161B22</item>
        <item name="colorPrimary">#58A6FF</item>
    </style>
</resources>
EOF

echo "⏳ [4/6] Creating GitHub Action..."
mkdir -p .github/workflows
cat > .github/workflows/build.yml << 'EOF'
name: Build APK
on:
  push:
    branches: [ main ]
  workflow_dispatch:
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
      - name: Setup Gradle
        uses: gradle/actions/setup-gradle@v3
      - name: Fix gradlew line endings and perms
        run: |
          sed -i 's/\r$//' gradlew
          chmod +x gradlew
      - name: Build Debug APK
        run: ./gradlew assembleDebug --stacktrace
      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: NetProbe-v19.4-APK
          path: app/build/outputs/apk/debug/app-debug.apk
EOF

echo "⏳ [5/6] Configuring Git..."
echo '*.zip' > .gitignore
echo '!gradle/wrapper/gradle-wrapper.jar' >> .gitignore
sed -i 's/\r$//' gradlew
chmod +x gradlew

echo "⏳ [6/6] Pushing to GitHub..."
git add -A
git add -f gradle/wrapper/gradle-wrapper.jar
git commit -m "fix: bulletproof release v19.4 (clean gradle config, no duplicate resources)" || true
git push origin main --force

echo "✅ ALL DONE! Check: https://github.com/sm2218157-creator/Netprobe/actions"
