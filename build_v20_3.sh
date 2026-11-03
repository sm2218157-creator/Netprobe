#!/bin/bash
set -e
PROJ="/workspaces/NetProbe-Final"
APP="$PROJ/app"
PKG="$APP/src/main/java/com/xk/netprobe"
RES="$APP/src/main/res"
EXPLORER="/workspaces/Netprobe"
KS="/workspaces/debug.keystore"
SDK="$HOME/android-sdk"
VERSION="20.3"

export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH="$JAVA_HOME/bin:$PATH"
export ANDROID_HOME="$SDK"

echo "=== Building NetProbe v$VERSION (Hybrid Naming: DNS + MAC Vendor) ==="

# 1. إنشاء قاعدة بيانات أسماء الشركات المصنعة (MAC Vendor)
cat > "$PKG/MacVendorLookup.java" << 'EOF'
package com.xk.netprobe;
import java.util.HashMap;
import java.util.Map;
public class MacVendorLookup {
    private static final Map<String, String> vendors = new HashMap<>();
    static {
        vendors.put("A8:42:A1", "Apple"); vendors.put("00:1A:11", "Google");
        vendors.put("F4:F5:D8", "Google"); vendors.put("00:1B:63", "Apple");
        vendors.put("3C:5A:B4", "Google"); vendors.put("94:EB:2C", "Google");
        vendors.put("D8:9E:F3", "Samsung"); vendors.put("B4:79:A7", "Samsung");
        vendors.put("64:B5:C6", "Samsung"); vendors.put("34:23:BA", "Samsung");
        vendors.put("F4:8C:50", "Intel"); vendors.put("00:1E:67", "Intel");
        vendors.put("88:36:6C", "Huawei"); vendors.put("00:E0:FC", "Huawei");
        vendors.put("64:09:80", "Xiaomi"); vendors.put("50:64:2B", "Xiaomi");
        vendors.put("00:0C:29", "VMware"); vendors.put("00:50:56", "VMware");
        vendors.put("00:1A:A0", "Dell"); vendors.put("B8:2A:72", "Dell");
        vendors.put("3C:52:82", "HP"); vendors.put("00:1F:29", "HP");
        vendors.put("54:04:A6", "TP-Link"); vendors.put("F4:F2:6D", "TP-Link");
        vendors.put("00:11:32", "Synology"); vendors.put("00:1D:AA", "MikroTik");
        vendors.put("B0:BE:76", "Roku"); vendors.put("CC:50:E3", "Espressif");
        vendors.put("3C:71:BF", "Espressif"); vendors.put("B8:27:EB", "Raspberry Pi");
        vendors.put("00:1C:B3", "Apple"); vendors.put("BC:92:6B", "Apple");
        vendors.put("68:AB:1E", "Apple"); vendors.put("00:17:88", "Philips Hue");
        vendors.put("68:C6:3A", "Xiaomi"); vendors.put("78:11:DC", "Xiaomi");
        vendors.put("A0:20:A6", "Espressif"); vendors.put("DC:4F:22", "Espressif");
    }
    public static String getVendor(String mac) {
        if (mac == null || mac.equals("Unknown") || mac.length() < 8) return "Device";
        String prefix = mac.substring(0, 8).toUpperCase();
        return vendors.getOrDefault(prefix, "Device");
    }
}
EOF

# 2. تحديث LocalNetworkActivity لدمج (DNS ثم MAC)
cat > "$PKG/LocalNetworkActivity.java" << 'EOF'
package com.xk.netprobe;
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
import java.net.InetAddress;

public class LocalNetworkActivity extends AppCompatActivity {
    private TextView tvSsid, tvSubnet, tvStatus, tvMyIp;
    private ProgressBar progressBar; private ImageButton btnRescan; private DeviceAdapter adapter;
    private Handler handler = new Handler(Looper.getMainLooper()); private boolean isRunning = true;
    private String currentSubnet;
    
    @Override protected void onCreate(Bundle b) {
        super.onCreate(b); setContentView(R.layout.activity_local);
        tvSsid = findViewById(R.id.tvSsid); tvSubnet = findViewById(R.id.tvSubnet); tvStatus = findViewById(R.id.tvStatus); tvMyIp = findViewById(R.id.tvMyIp);
        progressBar = findViewById(R.id.progressBar); btnRescan = findViewById(R.id.btnRescan);
        RecyclerView recycler = findViewById(R.id.recyclerDevices); recycler.setLayoutManager(new LinearLayoutManager(this));
        adapter = new DeviceAdapter(); recycler.setAdapter(adapter);
        
        btnRescan.setOnClickListener(v -> { adapter.clear(); startDiscovery(); });
        startDiscovery();
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
                // 1. محاولة جلب الاسم عبر Local DNS
                String displayName = "Unknown";
                try {
                    String dnsName = InetAddress.getByName(ip).getCanonicalHostName();
                    if (!dnsName.equals(ip)) displayName = dnsName;
                } catch (Exception ignored) {}

                String mac = getMacFromArp(ip);
                
                // 2. إذا فشل الـ DNS، نستخدم اسم الشركة المصنعة (MAC Vendor)
                if (displayName.equals("Unknown")) {
                    displayName = MacVendorLookup.getVendor(mac);
                }

                final String finalDisplayName = displayName;
                JavaPortScanner.scan(ip, openPorts -> {
                    handler.post(() -> {
                        adapter.updateDevice(ip, openPorts.size(), mac, finalDisplayName, String.join("\n", openPorts));
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
    
    @Override protected void onDestroy() { super.onDestroy(); isRunning = false; handler.removeCallbacksAndMessages(null); }
}
EOF

# 3. تحديث DeviceAdapter ليعرض الاسم النهائي
cat > "$PKG/DeviceAdapter.java" << 'EOF'
package com.xk.netprobe;
import android.content.Intent;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;
import java.util.ArrayList;
import java.util.List;
public class DeviceAdapter extends RecyclerView.Adapter<DeviceAdapter.VH> {
    static class Device { String ip; String mac; String displayName; int ports; String rawPorts; boolean isGateway; 
        Device(String ip, String mac, String displayName, int ports, String raw, boolean gw) { this.ip = ip; this.mac = mac; this.displayName = displayName; this.ports = ports; this.rawPorts = raw; this.isGateway = gw; } }
    private final List<Device> devices = new ArrayList<>();
    private String gatewayIp = "";
    
    public void setGateway(String gw) { this.gatewayIp = gw; }
    
    public void addDevice(String ip) {
        for (Device d : devices) if (d.ip.equals(ip)) return;
        devices.add(new Device(ip, "Unknown", "Unknown", -1, "", ip.equals(gatewayIp)));
        notifyItemInserted(devices.size() - 1);
    }
    public void updateDevice(String ip, int ports, String mac, String displayName, String raw) {
        for (int i = 0; i < devices.size(); i++) {
            if (devices.get(i).ip.equals(ip)) {
                devices.get(i).ports = ports; 
                devices.get(i).mac = mac; 
                devices.get(i).displayName = displayName;
                devices.get(i).rawPorts = raw;
                notifyItemChanged(i); break;
            }
        }
    }
    public String getIpAt(int index) { return devices.get(index).ip; }
    public void clear() { devices.clear(); notifyDataSetChanged(); }
    @NonNull @Override public VH onCreateViewHolder(@NonNull ViewGroup p, int t) { return new VH(LayoutInflater.from(p.getContext()).inflate(R.layout.item_device, p, false)); }
    @Override public void onBindViewHolder(@NonNull VH h, int i) {
        Device d = devices.get(i);
        h.tvIp.setText(d.ip); h.tvPortCount.setText(d.ports == -1 ? "?" : String.valueOf(d.ports));
        
        if (d.isGateway) {
            h.tvVendor.setText("Router / Gateway");
        } else if (d.displayName != null && !d.displayName.equals("Unknown")) {
            h.tvVendor.setText(d.displayName); // عرض الاسم (سواء DNS أو الشركة المصنعة)
        } else {
            h.tvVendor.setText(d.mac.equals("Unknown") ? "Device" : d.mac);
        }
        
        h.itemView.setOnClickListener(v -> {
            Intent intent = new Intent(v.getContext(), DeviceDetailsActivity.class);
            intent.putExtra("ip", d.ip); intent.putExtra("mac", d.mac); intent.putExtra("rawPorts", d.rawPorts);
            v.getContext().startActivity(intent);
        });
    }
    @Override public int getItemCount() { return devices.size(); }
    static class VH extends RecyclerView.ViewHolder {
        TextView tvIp, tvPortCount, tvVendor;
        VH(@NonNull View v) { super(v); tvIp = v.findViewById(R.id.tvIp); tvPortCount = v.findViewById(R.id.tvPortCount); tvVendor = v.findViewById(R.id.tvVendor); }
    }
}
EOF

# 4. تحديث الإصدار
sed -i 's/versionCode 26/versionCode 27/' "$APP/build.gradle" || true
sed -i 's/versionName "20.2"/versionName "20.3"/' "$APP/build.gradle" || true
sed -i 's/v20.2/v20.3/' "$RES/layout/activity_main.xml" || true

# 5. البناء والتوقيع
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

# 6. نقل الملفات للمستكشف
echo "⏳ Moving to Explorer..."
mkdir -p "$EXPLORER"
cp "$APK_TMP" "$EXPLORER/NetProbe-v${VERSION}.apk"
cd "$EXPLORER"
zip -q "NetProbe-v${VERSION}.zip" "NetProbe-v${VERSION}.apk"

echo "✅ ALL DONE! NetProbe-v${VERSION}.apk and .zip are in Explorer."
