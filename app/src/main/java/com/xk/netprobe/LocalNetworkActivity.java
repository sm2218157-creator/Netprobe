package com.xk.netprobe;
import android.net.wifi.WifiManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.View;
import android.widget.ImageButton;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
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
        
        String gatewayIp = NetInfo.getGatewayIp();
        if (gatewayIp != null) adapter.setGateway(gatewayIp);

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
                    adapter.updateDevice(ip, openPorts.size(), "Unknown", String.join("\n", openPorts));
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
    @Override protected void onDestroy() { super.onDestroy(); isRunning = false; handler.removeCallbacksAndMessages(null); }
}
