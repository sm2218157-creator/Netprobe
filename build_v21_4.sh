#!/bin/bash
set -e
PROJ="/workspaces/NetProbe-Final"
APP="$PROJ/app"
PKG="$APP/src/main/java/com/xk/netprobe"
RES="$APP/src/main/res"
EXPLORER="/workspaces/Netprobe"
KS="/workspaces/debug.keystore"
SDK="$HOME/android-sdk"
VERSION="21.4"

export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH="$JAVA_HOME/bin:$PATH"
export ANDROID_HOME="$SDK"

echo "=== Building NetProbe v$VERSION (Final Fixes & Optimization) ==="

# 1. تحديث ملف build.gradle
sed -i 's/versionCode 36/versionCode 37/' "$APP/build.gradle" || true
sed -i 's/versionName "21.3"/versionName "21.4"/' "$APP/build.gradle" || true
sed -i 's/v21.3/v21.4/' "$RES/layout/activity_main.xml" || true

# 2. تصميم عنصر الجهاز (تأكيد خاصية النقر)
cat > "$RES/layout/item_device.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android" xmlns:app="http://schemas.android.com/apk/res-auto"
    android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="vertical" 
    android:layout_marginBottom="8dp"
    android:clickable="true" android:focusable="true" android:foreground="?attr/selectableItemBackground">
    <androidx.cardview.widget.CardView
        android:layout_width="match_parent" android:layout_height="wrap_content"
        app:cardBackgroundColor="#161B22" app:cardCornerRadius="8dp" app:cardElevation="0dp">
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
            <TextView android:id="@+id/tvArrow" android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:text="▼" android:textColor="#58A6FF" android:textSize="16sp"/>
        </LinearLayout>
    </androidx.cardview.widget.CardView>
    <androidx.cardview.widget.CardView
        android:id="@+id/cardExpandable"
        android:layout_width="match_parent" android:layout_height="wrap_content"
        android:layout_marginTop="4dp" android:visibility="gone"
        app:cardBackgroundColor="#0D1117" app:cardCornerRadius="8dp" app:cardElevation="0dp"
        app:strokeColor="#30363D" app:strokeWidth="1dp">
        <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="vertical" android:padding="12dp">
            <TextView android:id="@+id/tvPortsList" android:layout_width="match_parent" android:layout_height="wrap_content"
                android:text="Scanning ports..." android:textColor="#3FB950" android:textSize="14sp" android:lineSpacingExtra="4dp"/>
        </LinearLayout>
    </androidx.cardview.widget.CardView>
</LinearLayout>
EOF

# 3. DeviceAdapter (تنسيق المنافذ)
cat > "$PKG/DeviceAdapter.java" << 'EOF'
package com.xk.netprobe;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;
import java.util.ArrayList;
import java.util.List;

public class DeviceAdapter extends RecyclerView.Adapter<DeviceAdapter.VH> {
    static class Device { 
        String ip; String mac; String displayName; int ports; String rawPorts; boolean isGateway; 
        Device(String ip, String mac, String displayName, int ports, String raw, boolean gw) { 
            this.ip = ip; this.mac = mac; this.displayName = displayName; this.ports = ports; this.rawPorts = raw; this.isGateway = gw; 
        } 
    }
    private final List<Device> devices = new ArrayList<>();
    private String gatewayIp = "";
    private int expandedPosition = -1;

    public void setGateway(String gw) { this.gatewayIp = gw; }
    public void addDevice(String ip) {
        for (Device d : devices) if (d.ip.equals(ip)) return;
        devices.add(new Device(ip, "Unknown", "Unknown", -1, "Scanning...", ip.equals(gatewayIp)));
        notifyItemInserted(devices.size() - 1);
    }
    public void updateDevice(String ip, int ports, String mac, String displayName, String raw) {
        for (int i = 0; i < devices.size(); i++) {
            if (devices.get(i).ip.equals(ip)) {
                devices.get(i).ports = ports; devices.get(i).mac = mac; 
                devices.get(i).displayName = displayName; devices.get(i).rawPorts = raw;
                notifyItemChanged(i); break;
            }
        }
    }
    public String getIpAt(int index) { return devices.get(index).ip; }
    public void clear() { devices.clear(); expandedPosition = -1; notifyDataSetChanged(); }
    
    @NonNull @Override public VH onCreateViewHolder(@NonNull ViewGroup p, int t) { 
        return new VH(LayoutInflater.from(p.getContext()).inflate(R.layout.item_device, p, false)); 
    }
    @Override public void onBindViewHolder(@NonNull VH h, int i) {
        Device d = devices.get(i);
        h.tvIp.setText(d.ip); h.tvPortCount.setText(d.ports == -1 ? "?" : String.valueOf(d.ports));
        
        if (d.isGateway) h.tvVendor.setText("Router / Gateway");
        else if (d.displayName != null && !d.displayName.equals("Unknown")) h.tvVendor.setText(d.displayName);
        else h.tvVendor.setText(d.mac.equals("Unknown") ? "Device" : d.mac);

        if (expandedPosition == i) {
            h.cardExpandable.setVisibility(View.VISIBLE);
            h.tvArrow.setText("▲");
            if (d.rawPorts == null || d.rawPorts.isEmpty() || d.rawPorts.equals("Scanning...")) {
                h.tvPortsList.setText("No open ports found.");
            } else {
                h.tvPortsList.setText(d.rawPorts);
            }
        } else {
            h.cardExpandable.setVisibility(View.GONE);
            h.tvArrow.setText("▼");
        }
        
        h.itemView.setOnClickListener(v -> {
            if (expandedPosition == i) {
                expandedPosition = -1; notifyItemChanged(i);
            } else {
                int prev = expandedPosition; expandedPosition = i; notifyItemChanged(i);
                if (prev != -1) notifyItemChanged(prev);
            }
        });
    }
    @Override public int getItemCount() { return devices.size(); }
    static class VH extends RecyclerView.ViewHolder {
        TextView tvIp, tvPortCount, tvVendor, tvArrow, tvPortsList; View cardExpandable;
        VH(@NonNull View v) { 
            super(v); tvIp = v.findViewById(R.id.tvIp); tvPortCount = v.findViewById(R.id.tvPortCount); 
            tvVendor = v.findViewById(R.id.tvVendor); tvArrow = v.findViewById(R.id.tvArrow); 
            tvPortsList = v.findViewById(R.id.tvPortsList); cardExpandable = v.findViewById(R.id.cardExpandable);
        }
    }
}
EOF

# 4. LocalNetworkActivity (إصلاح الـ MAC والفحص السريع)
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
    private String currentSubnet; private static final int SHIZUKU_REQ_CODE = 777; private boolean isShizukuReady = false;

    private final Shizuku.OnRequestPermissionResultListener permListener = (req, grant) -> {
        if (req == SHIZUKU_REQ_CODE && grant == PackageManager.PERMISSION_GRANTED) {
            isShizukuReady = true; tvShizukuHint.setText("✅ شيزوكو مفعل"); tvShizukuHint.setTextColor(0xFF3FB950);
        }
    };
    
    @Override protected void onCreate(Bundle b) {
        super.onCreate(b); setContentView(R.layout.activity_local);
        tvSsid = findViewById(R.id.tvSsid); tvSubnet = findViewById(R.id.tvSubnet); tvStatus = findViewById(R.id.tvStatus); tvMyIp = findViewById(R.id.tvMyIp);
        tvShizukuHint = findViewById(R.id.tvShizukuHint);
        progressBar = findViewById(R.id.progressBar); btnRescan = findViewById(R.id.btnRescan);
        RecyclerView recycler = findViewById(R.id.recyclerDevices); recycler.setLayoutManager(new LinearLayoutManager(this));
        adapter = new DeviceAdapter(); recycler.setAdapter(adapter);
        
        btnRescan.setOnClickListener(v -> { 
            adapter.clear(); 
            tvStatus.setText("Scanning network..."); 
            progressBar.setVisibility(View.VISIBLE);
            startDiscovery(); 
        });
        
        checkAndRequestShizuku(); startDiscovery();
    }
    
    private void checkAndRequestShizuku() {
        try {
            if (Shizuku.pingBinder()) {
                if (Shizuku.isPreV11() || Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED) {
                    isShizukuReady = true; tvShizukuHint.setText("✅ شيزوكو مفعل"); tvShizukuHint.setTextColor(0xFF3FB950);
                } else {
                    tvShizukuHint.setText("⏳ يرجى الموافقة على شيزوكو..."); tvShizukuHint.setTextColor(0xFFF0B72F);
                    Shizuku.addRequestPermissionResultListener(permListener); Shizuku.requestPermission(SHIZUKU_REQ_CODE);
                }
            } else { tvShizukuHint.setText("فعل شيزوكو لتحصل على صلاحيات أقوى"); tvShizukuHint.setTextColor(0xFFF0B72F); }
        } catch (Exception ignored) {}
    }

    private void startDiscovery() {
        progressBar.setVisibility(View.VISIBLE); tvStatus.setText("Scanning network...");
        String myIp = NetInfo.getMyIp(this); currentSubnet = NetInfo.getSubnet(this);
        if (myIp == null || currentSubnet == null) {
            progressBar.setVisibility(View.GONE); tvMyIp.setText("My IP: Unknown"); tvSubnet.setText("Router: Unknown");
            tvStatus.setText("Could not detect Wi-Fi."); tvStatus.setTextColor(0xFFF85149); return;
        }
        tvMyIp.setText("My IP: " + myIp);
        String gatewayIp = NetInfo.getGatewayIp(); if (gatewayIp == null || gatewayIp.isEmpty()) gatewayIp = myIp.substring(0, myIp.lastIndexOf('.')) + ".1";
        adapter.setGateway(gatewayIp);
        WifiManager wm = (WifiManager) getApplicationContext().getSystemService(WIFI_SERVICE);
        String ssidName = "Unknown";
        if (wm != null && wm.getConnectionInfo() != null) {
            String ssid = wm.getConnectionInfo().getSSID().replace("\"", "");
            if (!ssid.equals("<unknown ssid>") && !ssid.isEmpty()) { tvSsid.setText(ssid); ssidName = ssid; }
        }
        tvSubnet.setText("Router: " + gatewayIp + " | " + ssidName);
        NetworkDiscovery.scan(currentSubnet, new NetworkDiscovery.Callback() {
            @Override public void onDeviceFound(String ip) { if(!isRunning) return; handler.post(() -> adapter.addDevice(ip)); }
            @Override public void onFinished(int total) { if(!isRunning) return; handler.post(() -> scanJavaPorts()); }
        });
    }
    
    private void scanJavaPorts() {
        tvStatus.setText("Scanning ports & names...");
        final int[] completed = {0}; final int total = adapter.getItemCount();
        if (total == 0) { progressBar.setVisibility(View.GONE); tvStatus.setText("No devices found."); return; }
        for (int i = 0; i < total; i++) {
            final String ip = adapter.getIpAt(i);
            new Thread(() -> {
                String dName = "Unknown";
                try { String dns = InetAddress.getByName(ip).getCanonicalHostName(); if (!dns.equals(ip)) dName = dns; } catch (Exception ignored) {}
                
                String mac = getMacFromArp(ip); 
                if (mac.equals("Unknown")) mac = getMacFromShizuku(ip);
                mac = mac.replace("-", ":").toUpperCase(); // إصلاح تنسيق الـ MAC
                
                if (dName.equals("Unknown")) dName = MacVendorLookup.getVendor(mac);
                final String finalName = dName; final String finalMac = mac;
                
                JavaPortScanner.scan(ip, openPorts -> {
                    handler.post(() -> {
                        adapter.updateDevice(ip, openPorts.size(), finalMac, finalName, String.join("\n", openPorts));
                        completed[0]++;
                        if (completed[0] == total) { progressBar.setVisibility(View.GONE); tvStatus.setText("Scan Complete."); tvStatus.setTextColor(0xFF3FB950); }
                    });
                });
            }).start();
        }
    }

    private String getMacFromArp(String ip) {
        try (BufferedReader br = new BufferedReader(new FileReader("/proc/net/arp"))) {
            String line; while ((line = br.readLine()) != null) {
                String[] parts = line.trim().split("\\s+"); if (parts.length >= 4 && parts[0].equals(ip)) { String mac = parts[3]; if (!mac.equals("00:00:00:00:00:00")) return mac; }
            }
        } catch (Exception ignored) {} return "Unknown";
    }

    private String getMacFromShizuku(String ip) {
        if (!isShizukuReady) return "Unknown";
        try {
            Method method = Shizuku.class.getDeclaredMethod("newProcess", String[].class, String[].class, String.class);
            method.setAccessible(true); String cmd = "ping -c 1 -W 1 " + ip + " > /dev/null 2>&1; ip neigh";
            Process p = (Process) method.invoke(null, new String[]{"sh", "-c", cmd}, null, null);
            BufferedReader br = new BufferedReader(new InputStreamReader(p.getInputStream())); String line;
            while ((line = br.readLine()) != null) {
                if (line.contains(ip)) { String[] parts = line.split("\\s+"); for (String part : parts) { if (part.matches("([0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2}")) return part; } }
            }
        } catch (Exception ignored) {} return "Unknown";
    }
    
    @Override protected void onDestroy() { super.onDestroy(); isRunning = false; handler.removeCallbacksAndMessages(null); try { Shizuku.removeRequestPermissionResultListener(permListener); } catch (Exception ignored) {} }
}
EOF

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

