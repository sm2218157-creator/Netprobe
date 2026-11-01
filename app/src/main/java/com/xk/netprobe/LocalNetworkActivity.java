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
