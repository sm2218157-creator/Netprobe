#!/bin/bash
set -e
PROJ="/workspaces/NetProbe-Final"
APP="$PROJ/app"
PKG="$APP/src/main/java/com/xk/netprobe"
RES="$APP/src/main/res"
EXPLORER="/workspaces/Netprobe"
KS="/workspaces/debug.keystore"
SDK="$HOME/android-sdk"
VERSION="20.1"

export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH="$JAVA_HOME/bin:$PATH"
export ANDROID_HOME="$SDK"

echo "=== Building NetProbe v$VERSION (Fixing Ports, MAC, Gateway) ==="

# 1. إصلاح PortAdapter لقراءة صيغة الجافا وصيغة nmap
cat > "$PKG/PortAdapter.java" << 'EOF'
package com.xk.netprobe;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;
import java.util.ArrayList;
import java.util.List;
public class PortAdapter extends RecyclerView.Adapter<PortAdapter.VH> {
    private final List<String[]> ports = new ArrayList<>();
    public void setData(String rawData) {
        ports.clear();
        if (rawData != null) {
            for (String line : rawData.split("\n")) {
                String trimmed = line.trim();
                if (trimmed.isEmpty()) continue;
                if (trimmed.contains("/tcp") && trimmed.contains("open")) { // صيغة nmap
                    String[] parts = trimmed.split("\\s+");
                    if (parts.length >= 3) {
                        String port = parts[0].split("/")[0];
                        String service = parts.length >= 4 ? parts[2] + " " + parts[3] : parts[2];
                        ports.add(new String[]{port, service});
                    }
                } else if (trimmed.contains("(") && trimmed.contains(")")) { // صيغة الماسح المدمج (جافا)
                    String[] parts = trimmed.split("\\(");
                    if (parts.length >= 2) {
                        String port = parts[0].trim();
                        String service = parts[1].replace(")", "").trim();
                        ports.add(new String[]{port, service});
                    }
                }
            }
        }
        notifyDataSetChanged();
    }
    @NonNull @Override public VH onCreateViewHolder(@NonNull ViewGroup p, int t) { return new VH(LayoutInflater.from(p.getContext()).inflate(R.layout.item_port, p, false)); }
    @Override public void onBindViewHolder(@NonNull VH h, int i) { h.tvNumber.setText(ports.get(i)[0]); h.tvService.setText(ports.get(i)[1]); }
    @Override public int getItemCount() { return ports.size(); }
    static class VH extends RecyclerView.ViewHolder {
        TextView tvNumber, tvService;
        VH(@NonNull View v) { super(v); tvNumber = v.findViewById(R.id.tvPortNumber); tvService = v.findViewById(R.id.tvPortService); }
    }
}
EOF

# 2. إصلاح NetInfo لضمان قراءة البوابة
cat > "$PKG/NetInfo.java" << 'EOF'
package com.xk.netprobe;
import android.content.Context;
import android.net.wifi.WifiManager;
import java.io.BufferedReader;
import java.io.FileReader;
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
            WifiManager wifiManager = (WifiManager) ctx.getApplicationContext().getSystemService(Context.WIFI_SERVICE);
            if (wifiManager != null && wifiManager.isWifiEnabled()) {
                int ipAddress = wifiManager.getConnectionInfo().getIpAddress();
                if (ipAddress != 0) return String.format(Locale.US, "%d.%d.%d.%d", (ipAddress & 0xff), (ipAddress >> 8 & 0xff), (ipAddress >> 16 & 0xff), (ipAddress >> 24 & 0xff));
            }
        } catch (Exception ignored) {}
        return null;
    }
    public static String getSubnet(Context ctx) {
        String ip = getMyIp(ctx);
        if (ip != null && ip.lastIndexOf('.') > 0) return ip.substring(0, ip.lastIndexOf('.')) + ".0/24";
        return null;
    }
    public static String getGatewayIp() {
        try (BufferedReader br = new BufferedReader(new FileReader("/proc/net/route"))) {
            String line;
            while ((line = br.readLine()) != null) {
                String[] parts = line.trim().split("\\s+");
                if (parts.length > 2 && parts[1].equals("00000000")) {
                    String hex = parts[2];
                    int ip = Integer.parseInt(hex, 16);
                    return String.format(Locale.US, "%d.%d.%d.%d", (ip & 0xFF), (ip >> 8 & 0xFF), (ip >> 16 & 0xFF), (ip >> 24 & 0xFF));
                }
            }
        } catch (Exception ignored) {}
        return null;
    }
}
EOF

# 3. تحديث LocalNetworkActivity (قراءة MAC من ARP وتحديد البوابة)
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
            progressBar.setVisibility(View.GONE); tvMyIp.setText("My IP: Unknown"); tvSubnet.setText("Subnet: Unknown");
            tvStatus.setText("Could not detect Wi-Fi network."); tvStatus.setTextColor(0xFFF85149); return;
        }
        tvMyIp.setText("My IP: " + myIp); tvSubnet.setText("Subnet: " + currentSubnet);
        
        // إصلاح اسم البوابة (Fallback إلى .1 إذا فشل النظام)
        String gatewayIp = NetInfo.getGatewayIp();
        if (gatewayIp == null || gatewayIp.isEmpty()) {
            gatewayIp = myIp.substring(0, myIp.lastIndexOf('.')) + ".1";
        }
        adapter.setGateway(gatewayIp);

        WifiManager wifiManager = (WifiManager) getApplicationContext().getSystemService(WIFI_SERVICE);
        if (wifiManager != null && wifiManager.getConnectionInfo() != null) {
            String ssid = wifiManager.getConnectionInfo().getSSID().replace("\"", "");
            if (!ssid.equals("<unknown ssid>") && !ssid.isEmpty()) tvSsid.setText(ssid);
        }
        NetworkDiscovery.scan(currentSubnet, new NetworkDiscovery.Callback() {
            @Override public void onDeviceFound(String ip) { if(!isRunning) return; handler.post(() -> adapter.addDevice(ip)); }
            @Override public void onFinished(int total) { if(!isRunning) return; handler.post(() -> scanJavaPorts()); }
        });
    }
    
    private void scanJavaPorts() {
        tvStatus.setText("Scanning common ports (Java)...");
        final int[] completed = {0};
        final int total = adapter.getItemCount();
        if (total == 0) { progressBar.setVisibility(View.GONE); tvStatus.setText("No devices found."); return; }
        
        for (int i = 0; i < total; i++) {
            final String ip = adapter.getIpAt(i);
            JavaPortScanner.scan(ip, openPorts -> {
                handler.post(() -> {
                    String mac = getMacFromArp(ip);
                    adapter.updateDevice(ip, openPorts.size(), mac, String.join("\n", openPorts));
                    completed[0]++;
                    if (completed[0] == total) {
                        progressBar.setVisibility(View.GONE);
                        tvStatus.setText("Scan Complete. Tap a device for details.");
                        tvStatus.setTextColor(0xFF3FB950);
                    }
                });
            });
        }
    }

    // قراءة عنوان MAC الحقيقي من جدول ARP
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

# 4. تحديث الإصدار
sed -i 's/versionCode 24/versionCode 25/' "$APP/build.gradle" || true
sed -i 's/versionName "20.0"/versionName "20.1"/' "$APP/build.gradle" || true
sed -i 's/v20.0/v20.1/' "$RES/layout/activity_main.xml" || true

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
