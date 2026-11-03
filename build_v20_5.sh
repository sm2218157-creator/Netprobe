#!/bin/bash
set -e
PROJ="/workspaces/NetProbe-Final"
APP="$PROJ/app"
PKG="$APP/src/main/java/com/xk/netprobe"
RES="$APP/src/main/res"
EXPLORER="/workspaces/Netprobe"
KS="/workspaces/debug.keystore"
SDK="$HOME/android-sdk"
VERSION="20.5"

export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH="$JAVA_HOME/bin:$PATH"
export ANDROID_HOME="$SDK"

echo "=== Building NetProbe v$VERSION (Fixing Shizuku Request & Exec) ==="

# 1. تحديث LocalNetworkActivity لطلب الصلاحية وتنفيذ الأمر عبر Reflection
cat > "$PKG/LocalNetworkActivity.java" << 'EOF'
package com.xk.netprobe;
import android.content.pm.PackageManager;
import android.net.wifi.WifiManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.View;
import android.widget.ImageButton;
import android.widget.ProgressBar;
import android.widget.TextView;
import androidx.appcompat.app.AppCompatActivity;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import java.io.BufferedReader;
import java.io.FileReader;
import java.io.InputStreamReader;
import java.lang.reflect.Method;
import java.net.InetAddress;

import rikka.shizuku.Shizuku;

public class LocalNetworkActivity extends AppCompatActivity {
    private TextView tvSsid, tvSubnet, tvStatus, tvMyIp, tvShizukuHint;
    private ProgressBar progressBar; private ImageButton btnRescan; private DeviceAdapter adapter;
    private Handler handler = new Handler(Looper.getMainLooper()); private boolean isRunning = true;
    private String currentSubnet;
    private static final int SHIZUKU_REQ_CODE = 777;
    private boolean isShizukuReady = false;

    // مستمع نتيجة طلب الصلاحية
    private final Shizuku.OnRequestPermissionResultListener permListener = (requestCode, grantResult) -> {
        if (requestCode == SHIZUKU_REQ_CODE) {
            if (grantResult == PackageManager.PERMISSION_GRANTED) {
                isShizukuReady = true;
                tvShizukuHint.setText("✅ شيزوكو مفعل - سيتم جلب أسماء الأجهزة");
                tvShizukuHint.setTextColor(0xFF3FB950); // أخضر
            } else {
                tvShizukuHint.setText("❌ تم رفض صلاحية شيزوكو");
                tvShizukuHint.setTextColor(0xFFF85149); // أحمر
            }
        }
    };
    
    @Override protected void onCreate(Bundle b) {
        super.onCreate(b); setContentView(R.layout.activity_local);
        tvSsid = findViewById(R.id.tvSsid); tvSubnet = findViewById(R.id.tvSubnet); tvStatus = findViewById(R.id.tvStatus); tvMyIp = findViewById(R.id.tvMyIp);
        tvShizukuHint = findViewById(R.id.tvShizukuHint);
        progressBar = findViewById(R.id.progressBar); btnRescan = findViewById(R.id.btnRescan);
        RecyclerView recycler = findViewById(R.id.recyclerDevices); recycler.setLayoutManager(new LinearLayoutManager(this));
        adapter = new DeviceAdapter(); recycler.setAdapter(adapter);
        
        btnRescan.setOnClickListener(v -> { adapter.clear(); startDiscovery(); });
        
        // محاولة تفعيل شيزوكو وطلب الصلاحية
        checkAndRequestShizuku();
        startDiscovery();
    }
    
    private void checkAndRequestShizuku() {
        try {
            if (Shizuku.pingBinder()) {
                if (Shizuku.isPreV11()) {
                    isShizukuReady = true;
                    tvShizukuHint.setText("✅ شيزوكو (قديم) مفعل");
                    tvShizukuHint.setTextColor(0xFF3FB950);
                } else if (Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED) {
                    isShizukuReady = true;
                    tvShizukuHint.setText("✅ شيزوكو مفعل - سيتم جلب أسماء الأجهزة");
                    tvShizukuHint.setTextColor(0xFF3FB950);
                } else {
                    // طلب الصلاحية من شيزوكو
                    tvShizukuHint.setText("⏳ يرجى الموافقة على صلاحية شيزوكو...");
                    tvShizukuHint.setTextColor(0xFFF0B72F); 
                    Shizuku.addRequestPermissionResultListener(permListener);
                    Shizuku.requestPermission(SHIZUKU_REQ_CODE);
                }
            } else {
                tvShizukuHint.setText("فعل شيزوكو لتحصل على صلاحيات أقوى");
                tvShizukuHint.setTextColor(0xFFF0B72F);
            }
        } catch (Exception ignored) {
            // شيزوكو غير مثبت
        }
    }

    private void startDiscovery() {
        progressBar.setVisibility(View.VISIBLE); tvStatus.setText("Scanning network...");
        String myIp = NetInfo.getMyIp(this); currentSubnet = NetInfo.getSubnet(this);
        if (myIp == null || currentSubnet == null) {
            progressBar.setVisibility(View.GONE); tvMyIp.setText("My IP: Unknown"); tvSubnet.setText("Router: Unknown");
            tvStatus.setText("Could not detect Wi-Fi network."); tvStatus.setTextColor(0xFFF85149); return;
        }
        tvMyIp.setText("My IP: " + myIp);
        
        String gatewayIp = NetInfo.getGatewayIp();
        if (gatewayIp == null || gatewayIp.isEmpty()) {
            gatewayIp = myIp.substring(0, myIp.lastIndexOf('.')) + ".1";
        }
        adapter.setGateway(gatewayIp);

        WifiManager wifiManager = (WifiManager) getApplicationContext().getSystemService(WIFI_SERVICE);
        String ssidName = "Unknown";
        if (wifiManager != null && wifiManager.getConnectionInfo() != null) {
            String ssid = wifiManager.getConnectionInfo().getSSID().replace("\"", "");
            if (!ssid.equals("<unknown ssid>") && !ssid.isEmpty()) {
                tvSsid.setText(ssid);
                ssidName = ssid;
            }
        }
        
        tvSubnet.setText("Router: " + gatewayIp + " | " + ssidName);

        NetworkDiscovery.scan(currentSubnet, new NetworkDiscovery.Callback() {
            @Override public void onDeviceFound(String ip) { if(!isRunning) return; handler.post(() -> adapter.addDevice(ip)); }
            @Override public void onFinished(int total) { if(!isRunning) return; handler.post(() -> scanJavaPorts()); }
        });
    }
    
    private void scanJavaPorts() {
        tvStatus.setText("Scanning common ports & names...");
        final int[] completed = {0};
        final int total = adapter.getItemCount();
        if (total == 0) { progressBar.setVisibility(View.GONE); tvStatus.setText("No devices found."); return; }
        
        for (int i = 0; i < total; i++) {
            final String ip = adapter.getIpAt(i);
            new Thread(() -> {
                String displayName = "Unknown";
                try {
                    String dnsName = InetAddress.getByName(ip).getCanonicalHostName();
                    if (!dnsName.equals(ip)) displayName = dnsName;
                } catch (Exception ignored) {}

                String mac = getMacFromArp(ip);
                if (mac.equals("Unknown")) {
                    mac = getMacFromShizuku(ip); // استخدام شيزوكو
                }
                
                if (displayName.equals("Unknown")) {
                    displayName = MacVendorLookup.getVendor(mac);
                }

                final String finalDisplayName = displayName;
                final String finalMac = mac;
                JavaPortScanner.scan(ip, openPorts -> {
                    handler.post(() -> {
                        adapter.updateDevice(ip, openPorts.size(), finalMac, finalDisplayName, String.join("\n", openPorts));
                        completed[0]++;
                        if (completed[0] == total) {
                            progressBar.setVisibility(View.GONE);
                            tvStatus.setText("Scan Complete. Tap a device for details.");
                            tvStatus.setTextColor(0xFF3FB950);
                        }
                    });
                });
            }).start();
        }
    }

    private String getMacFromArp(String ip) {
        try (BufferedReader br = new BufferedReader(new FileReader("/proc/net/arp"))) {
            String line;
            while ((line = br.readLine()) != null) {
                String[] parts = line.trim().split("\\s+");
                if (parts.length >= 4 && parts[0].equals(ip)) {
                    String mac = parts[3];
                    if (!mac.equals("00:00:00:00:00:00")) return mac;
                }
            }
        } catch (Exception ignored) {}
        return "Unknown";
    }

    private String getMacFromShizuku(String ip) {
        if (!isShizukuReady) return "Unknown";
        try {
            // استخدام Reflection للوصول للدالة المحمية newProcess
            Method method = Shizuku.class.getDeclaredMethod("newProcess", String[].class, String[].class, String.class);
            method.setAccessible(true);
            Process p = (Process) method.invoke(null, new String[]{"sh", "-c", "ip neigh"}, null, null);
            
            BufferedReader br = new BufferedReader(new InputStreamReader(p.getInputStream()));
            String line;
            while ((line = br.readLine()) != null) {
                if (line.contains(ip)) {
                    String[] parts = line.split("\\s+");
                    for (String part : parts) {
                        if (part.matches("([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}")) {
                            return part.toUpperCase();
                        }
                    }
                }
            }
        } catch (Exception ignored) {}
        return "Unknown";
    }
    
    @Override protected void onDestroy() { 
        super.onDestroy(); 
        isRunning = false; 
        handler.removeCallbacksAndMessages(null); 
        try { Shizuku.removeRequestPermissionResultListener(permListener); } catch (Exception ignored) {}
    }
}
EOF

# 2. تحديث الإصدار
sed -i 's/versionCode 28/versionCode 29/' "$APP/build.gradle" || true
sed -i 's/versionName "20.4"/versionName "20.5"/' "$APP/build.gradle" || true
sed -i 's/v20.4/v20.5/' "$RES/layout/activity_main.xml" || true

# 3. البناء والتوقيع
echo "⏳ Building APK..."
cd "$PROJ"
./gradlew --stop > /dev/null 2>&1 || true
./gradlew clean assembleDebug

APK_TMP="$APP/build/outputs/apk/debug/app-debug.apk"
if [ ! -f "$APK_TMP" ]; then echo "❌ BUILD FAILED."; exit 1; fi

APKSIGNER=$(find "$SDK/build-tools" -name apksigner | head -1)
ZIPALIGN=$(find "$SDK/build-tools" -name zipalign | head -1)
[ ! -f "$KS" ] && keytool -genkeypair -v -keystore "$KS" -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US" 2>&1 | tail -1

[ -n "$ZIPALIGN" ] && {
    "$ZIPALIGN" -f -p 4 "$APK_TMP" "${APK_TMP%.apk}-aligned.apk"
    mv "${APK_TMP%.apk}-aligned.apk" "$APK_TMP"
}
"$APKSIGNER" sign --ks "$KS" --ks-pass pass:android --key-pass pass:android "$APK_TMP" 2>&1

# 4. نقل الملفات للمستكشف
echo "⏳ Moving to Explorer..."
mkdir -p "$EXPLORER"
cp "$APK_TMP" "$EXPLORER/NetProbe-v${VERSION}.apk"
cd "$EXPLORER"
zip -q "NetProbe-v${VERSION}.zip" "NetProbe-v${VERSION}.apk"

echo "✅ ALL DONE! NetProbe-v${VERSION}.apk and .zip are in Explorer."
