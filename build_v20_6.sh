#!/bin/bash
set -e
PROJ="/workspaces/NetProbe-Final"
APP="$PROJ/app"
PKG="$APP/src/main/java/com/xk/netprobe"
RES="$APP/src/main/res"
EXPLORER="/workspaces/Netprobe"
KS="/workspaces/debug.keystore"
SDK="$HOME/android-sdk"
VERSION="20.6"

export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH="$JAVA_HOME/bin:$PATH"
export ANDROID_HOME="$SDK"

echo "=== Building NetProbe v$VERSION (Forced ARP & Expanded Vendors) ==="

# 1. توسيع قاعدة بيانات أسماء الشركات (MAC Vendor)
cat > "$PKG/MacVendorLookup.java" << 'EOF'
package com.xk.netprobe;
import java.util.HashMap;
import java.util.Map;
public class MacVendorLookup {
    private static final Map<String, String> vendors = new HashMap<>();
    static {
        // Apple
        vendors.put("A8:42:A1", "Apple"); vendors.put("00:1B:63", "Apple"); vendors.put("00:1C:B3", "Apple");
        vendors.put("BC:92:6B", "Apple"); vendors.put("68:AB:1E", "Apple"); vendors.put("F0:18:98", "Apple");
        vendors.put("AC:BC:32", "Apple"); vendors.put("D0:81:7A", "Apple"); vendors.put("F4:5C:89", "Apple");
        // Samsung
        vendors.put("D8:9E:F3", "Samsung"); vendors.put("B4:79:A7", "Samsung"); vendors.put("64:B5:C6", "Samsung");
        vendors.put("34:23:BA", "Samsung"); vendors.put("C8:19:F7", "Samsung"); vendors.put("78:1F:DB", "Samsung");
        vendors.put("E8:50:8B", "Samsung"); vendors.put("5C:0A:5B", "Samsung");
        // Huawei / Honor
        vendors.put("88:36:6C", "Huawei"); vendors.put("00:E0:FC", "Huawei"); vendors.put("48:DB:50", "Huawei");
        vendors.put("B0:5B:67", "Huawei"); vendors.put("8C:34:FD", "Huawei"); vendors.put("F4:9F:F3", "Huawei");
        // Xiaomi / Redmi
        vendors.put("64:09:80", "Xiaomi"); vendors.put("50:64:2B", "Xiaomi"); vendors.put("68:C6:3A", "Xiaomi");
        vendors.put("78:11:DC", "Xiaomi"); vendors.put("8C:BE:BE", "Xiaomi"); vendors.put("F0:B4:29", "Xiaomi");
        // Google
        vendors.put("00:1A:11", "Google"); vendors.put("F4:F5:D8", "Google"); vendors.put("3C:5A:B4", "Google");
        vendors.put("94:EB:2C", "Google"); vendors.put("CC:32:E5", "Google");
        // Intel
        vendors.put("F4:8C:50", "Intel"); vendors.put("00:1E:67", "Intel"); vendors.put("A4:BB:6D", "Intel");
        vendors.put("34:13:E8", "Intel"); vendors.put("7C:B2:7D", "Intel");
        // Routers & Networking
        vendors.put("54:04:A6", "TP-Link"); vendors.put("F4:F2:6D", "TP-Link"); vendors.put("00:1D:AA", "MikroTik");
        vendors.put("00:11:32", "Synology"); vendors.put("B0:BE:76", "Roku"); vendors.put("00:0C:29", "VMware");
        vendors.put("00:50:56", "VMware"); vendors.put("00:24:36", "Apple"); vendors.put("E0:94:67", "Intel");
        vendors.put("C0:56:27", "Belkin"); vendors.put("00:14:BF", "Cisco-Linksys"); vendors.put("00:1A:70", "Cisco");
        vendors.put("00:0F:B5", "Netgear"); vendors.put("A0:40:A0", "Netgear"); vendors.put("00:05:5D", "D-Link");
        // TV & Smart Devices
        vendors.put("00:17:88", "Philips Hue"); vendors.put("B8:27:EB", "Raspberry Pi"); vendors.put("CC:50:E3", "Espressif");
        vendors.put("3C:71:BF", "Espressif"); vendors.put("A0:20:A6", "Espressif"); vendors.put("DC:4F:22", "Espressif");
        vendors.put("54:27:1E", "Amazon"); vendors.put("F0:27:2D", "Amazon"); vendors.put("68:54:FD", "Amazon");
        vendors.put("C4:3A:35", "Sony"); vendors.put("00:13:A9", "Sony"); vendors.put("FC:0F:E6", "Sony");
        vendors.put("2C:54:91", "Microsoft"); vendors.put("7C:1E:52", "Microsoft");
        // Laptops & PCs
        vendors.put("00:1A:A0", "Dell"); vendors.put("B8:2A:72", "Dell"); vendors.put("3C:52:82", "HP");
        vendors.put("00:1F:29", "HP"); vendors.put("00:25:90", "Super Micro"); vendors.put("E8:6A:64", "Lenovo");
        vendors.put("00:12:FE", "Lenovo"); vendors.put("00:1E:37", "Lenovo"); vendors.put("1C:87:2C", "Asus");
        vendors.put("00:1B:FC", "Asus"); vendors.put("F4:6D:04", "Asus");
        // Realtek / Others
        vendors.put("00:E0:4C", "Realtek"); vendors.put("52:54:00", "QEMU"); vendors.put("08:00:27", "VirtualBox");
    }
    public static String getVendor(String mac) {
        if (mac == null || mac.equals("Unknown") || mac.length() < 8) return "Device";
        String prefix = mac.substring(0, 8).toUpperCase();
        return vendors.getOrDefault(prefix, "Device");
    }
}
EOF

# 2. تحديث LocalNetworkActivity لإجبار تحديث الـ ARP
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

    private final Shizuku.OnRequestPermissionResultListener permListener = (requestCode, grantResult) -> {
        if (requestCode == SHIZUKU_REQ_CODE) {
            if (grantResult == PackageManager.PERMISSION_GRANTED) {
                isShizukuReady = true;
                tvShizukuHint.setText("✅ شيزوكو مفعل - سيتم جلب أسماء الأجهزة");
                tvShizukuHint.setTextColor(0xFF3FB950); 
            } else {
                tvShizukuHint.setText("❌ تم رفض صلاحية شيزوكو");
                tvShizukuHint.setTextColor(0xFFF85149); 
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
                    tvShizukuHint.setText("⏳ يرجى الموافقة على صلاحية شيزوكو...");
                    tvShizukuHint.setTextColor(0xFFF0B72F); 
                    Shizuku.addRequestPermissionResultListener(permListener);
                    Shizuku.requestPermission(SHIZUKU_REQ_CODE);
                }
            } else {
                tvShizukuHint.setText("فعل شيزوكو لتحصل على صلاحيات أقوى");
                tvShizukuHint.setTextColor(0xFFF0B72F);
            }
        } catch (Exception ignored) {}
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
                    mac = getMacFromShizuku(ip); // استخدام شيزوكو مع إجبار النبضة
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
            Method method = Shizuku.class.getDeclaredMethod("newProcess", String[].class, String[].class, String.class);
            method.setAccessible(true);
            
            // إجبار إرسال Ping لتحديث ARP ثم قراءة ip neigh
            String cmd = "ping -c 1 -W 1 " + ip + " > /dev/null 2>&1; ip neigh";
            Process p = (Process) method.invoke(null, new String[]{"sh", "-c", cmd}, null, null);
            
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

# 3. تحديث الإصدار
sed -i 's/versionCode 29/versionCode 30/' "$APP/build.gradle" || true
sed -i 's/versionName "20.5"/versionName "20.6"/' "$APP/build.gradle" || true
sed -i 's/v20.5/v20.6/' "$RES/layout/activity_main.xml" || true

# 4. البناء والتوقيع
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

# 5. نقل الملفات للمستكشف
echo "⏳ Moving to Explorer..."
mkdir -p "$EXPLORER"
cp "$APK_TMP" "$EXPLORER/NetProbe-v${VERSION}.apk"
cd "$EXPLORER"
zip -q "NetProbe-v${VERSION}.zip" "NetProbe-v${VERSION}.apk"

echo "✅ ALL DONE! NetProbe-v${VERSION}.apk and .zip are in Explorer."
