#!/bin/bash
set -e
PROJ="/workspaces/NetProbe-Final"
APP="$PROJ/app"
PKG="$APP/src/main/java/com/xk/netprobe"
RES="$APP/src/main/res"
EXPLORER="/workspaces/Netprobe"
KS="/workspaces/debug.keystore"
SDK="$HOME/android-sdk"
VERSION="19.7"

export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH="$JAVA_HOME/bin:$PATH"
export ANDROID_HOME="$SDK"

echo "=== Building NetProbe v$VERSION (Final IP & Termux Fixes) ==="

# 1. تحديث NetInfo (إرجاع null بدل الـ IP الوهمي، وتجاهل الـ VPN)
cat > "$PKG/NetInfo.java" << 'EOF'
package com.xk.netprobe;

import android.content.Context;
import android.net.wifi.WifiManager;
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
                if (name.startsWith("tun") || name.startsWith("ppp") || name.startsWith("rmnet")) continue;

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
        } catch (Exception ignored) {}

        try {
            WifiManager wifiManager = (WifiManager) ctx.getApplicationContext().getSystemService(Context.WIFI_SERVICE);
            if (wifiManager != null && wifiManager.isWifiEnabled()) {
                int ipAddress = wifiManager.getConnectionInfo().getIpAddress();
                if (ipAddress != 0) {
                    return String.format(Locale.US, "%d.%d.%d.%d",
                            (ipAddress & 0xff), (ipAddress >> 8 & 0xff),
                            (ipAddress >> 16 & 0xff), (ipAddress >> 24 & 0xff));
                }
            }
        } catch (Exception ignored) {}

        return null; // إرجاع null بدلاً من IP وهمي
    }

    public static String getSubnet(Context ctx) {
        String ip = getMyIp(ctx);
        if (ip != null && ip.lastIndexOf('.') > 0) {
            return ip.substring(0, ip.lastIndexOf('.')) + ".0/24";
        }
        return null;
    }
}
EOF

# 2. تحديث TermuxBridge (دعم أندرويد 12+ وإضافة دالة openTermux)
cat > "$PKG/TermuxBridge.java" << 'EOF'
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

    // دالة للتوافق مع الكود القديم الذي يستدعيها بمدخلين
    public static boolean runCommand(Context ctx, String cmd) {
        return runCommand(ctx, cmd, 0);
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
            Log.e(TAG, "startService failed: " + e.getMessage());
            return false;
        }
    }

    // إضافة هذه الدالة العائدة لتفادي خطأ MainActivity
    public static void openTermux(Context ctx) {
        Intent i = new Intent();
        i.setClassName("com.termux", "com.termux.app.TermuxActivity");
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        try { ctx.startActivity(i); } catch (Exception ignored) {}
    }
}
EOF

# 3. تحديث LocalNetworkActivity (معالجة IP null وإظهار رسالة واضحة إذا كان Termux مغلقاً)
cat > "$PKG/LocalNetworkActivity.java" << 'EOF'
package com.xk.netprobe;

import android.net.wifi.WifiManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.widget.TextView;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class LocalNetworkActivity extends AppCompatActivity {
    private TextView tvSsid, tvSubnet, tvStatus, tvMyIp;
    private DeviceAdapter adapter;
    private Handler handler = new Handler(Looper.getMainLooper());
    private boolean isRunning = true;
    private int pollSeconds = 0;
    private static final int NMAP_REQ_CODE = 303;

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
        
        if (myIp == null || subnet == null) {
            tvMyIp.setText("My IP: Unknown");
            tvSubnet.setText("Subnet: Unknown");
            tvStatus.setText("Could not detect Wi-Fi network. Ensure Wi-Fi is on and Location is granted.");
            tvStatus.setTextColor(0xFFF85149);
            return;
        }

        tvMyIp.setText("My IP: " + myIp);
        tvSubnet.setText("Subnet: " + subnet);

        WifiManager wifiManager = (WifiManager) getApplicationContext().getSystemService(WIFI_SERVICE);
        if (wifiManager != null && wifiManager.getConnectionInfo() != null) {
            String ssid = wifiManager.getConnectionInfo().getSSID().replace("\"", "");
            if (!ssid.equals("<unknown ssid>") && !ssid.isEmpty()) {
                tvSsid.setText(ssid);
            }
        }

        startDiscovery(subnet);
    }

    private void startDiscovery(String subnet) {
        tvStatus.setText("Scanning network...");
        NetworkDiscovery.scan(subnet, new NetworkDiscovery.Callback() {
            @Override public void onDeviceFound(String ip) {
                if(!isRunning) return;
                handler.post(() -> adapter.addDevice(ip));
            }
            @Override public void onFinished(int total) {
                if(!isRunning) return;
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
        FileHelper.write(this, "targets.txt", targets.toString());

        String outPath = FileHelper.pathOf(this, "ports.txt");
        FileHelper.write(this, "ports.txt", "");
        
        String cmd = "export PATH=/data/data/com.termux/files/usr/bin:$PATH; timeout 45 nmap -sT -T4 -F -iL \"" + targetsPath + "\" > \"" + outPath + "\" 2>&1; echo DONE >> \"" + outPath + "\"";
        
        boolean sent = TermuxBridge.runCommand(this, cmd, NMAP_REQ_CODE);
        if (!sent) {
            tvStatus.setText("Failed to reach Termux. Please open Termux app once, then try again.");
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
            if (data.contains("DONE")) {
                updatePorts(data);
            } else {
                pollPorts(path);
            }
        }, 1000);
    }

    private void updatePorts(String data) {
        String currentIp = null;
        int portCount = 0;
        String[] lines = data.split("\n");
        Pattern p = Pattern.compile("([0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3})");
        
        for (String line : lines) {
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
    }
}
EOF

# 4. البناء والتوقيع (نفس القالب المعتمد الخاص بك)
cd "$PROJ"
./gradlew clean assembleDebug 2>&1 | tail -5

APK_TMP="$APP/build/outputs/apk/debug/app-debug.apk"
if [ ! -f "$APK_TMP" ]; then echo "BUILD FAILED"; exit 1; fi

APKSIGNER=$(find "$SDK/build-tools" -name apksigner | head -1)
ZIPALIGN=$(find "$SDK/build-tools" -name zipalign | head -1)
[ ! -f "$KS" ] && keytool -genkeypair -v -keystore "$KS" -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US" 2>&1 | tail -1

[ -n "$ZIPALIGN" ] && {
    "$ZIPALIGN" -f -p 4 "$APK_TMP" "${APK_TMP%.apk}-aligned.apk"
    mv "${APK_TMP%.apk}-aligned.apk" "$APK_TMP"
}
"$APKSIGNER" sign --ks "$KS" --ks-pass pass:android --key-pass pass:android "$APK_TMP" 2>&1

mkdir -p "$EXPLORER"
cp "$APK_TMP" "$EXPLORER/NetProbe-v${VERSION}.apk"
cd "$EXPLORER"
rm -f "NetProbe-v${VERSION}.zip"
zip -q "NetProbe-v${VERSION}.zip" "NetProbe-v${VERSION}.apk"
echo "=== SUCCESS: NetProbe-v${VERSION}.zip ==="
