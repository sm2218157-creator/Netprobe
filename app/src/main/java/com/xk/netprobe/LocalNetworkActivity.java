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
import java.util.regex.Matcher;
import java.util.regex.Pattern;
public class LocalNetworkActivity extends AppCompatActivity {
    private TextView tvSsid, tvSubnet, tvStatus, tvMyIp;
    private ProgressBar progressBar; private ImageButton btnRescan; private DeviceAdapter adapter;
    private Handler handler = new Handler(Looper.getMainLooper()); private boolean isRunning = true;
    private int pollSeconds = 0; private String currentSubnet; private static final int NMAP_REQ_CODE = 303;
    @Override protected void onCreate(Bundle b) {
        super.onCreate(b); setContentView(R.layout.activity_local);
        tvSsid = findViewById(R.id.tvSsid); tvSubnet = findViewById(R.id.tvSubnet); tvStatus = findViewById(R.id.tvStatus); tvMyIp = findViewById(R.id.tvMyIp);
        progressBar = findViewById(R.id.progressBar); btnRescan = findViewById(R.id.btnRescan);
        RecyclerView recycler = findViewById(R.id.recyclerDevices); recycler.setLayoutManager(new LinearLayoutManager(this));
        adapter = new DeviceAdapter(); recycler.setAdapter(adapter);
        btnRescan.setOnClickListener(v -> { adapter.clear(); startDiscovery(); });
        if (!TermuxBridge.isTermuxInstalled(this)) { Toast.makeText(this, "Termux is not installed", Toast.LENGTH_LONG).show(); finish(); return; }
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
            @Override public void onFinished(int total) { if(!isRunning) return; handler.post(() -> scanPorts()); }
        });
    }
    private void scanPorts() {
        StringBuilder targets = new StringBuilder();
        for (int i = 0; i < adapter.getItemCount(); i++) targets.append(adapter.getIpAt(i)).append("\n");
        if (targets.length() == 0) { progressBar.setVisibility(View.GONE); tvStatus.setText("No devices found."); return; }
        tvStatus.setText("Found " + adapter.getItemCount() + " devices. Scanning ports...");
        String targetsPath = FileHelper.pathOf(this, "targets.txt"); FileHelper.write(this, "targets.txt", targets.toString());
        String outPath = FileHelper.pathOf(this, "ports.txt"); FileHelper.write(this, "ports.txt", "");
        String cmd = "export PATH=/data/data/com.termux/files/usr/bin:$PATH; timeout 45 nmap -sT -T4 -F -iL \"" + targetsPath + "\" > \"" + outPath + "\" 2>&1; echo DONE >> \"" + outPath + "\"";
        if (!TermuxBridge.runCommand(this, cmd, NMAP_REQ_CODE)) {
            progressBar.setVisibility(View.GONE); tvStatus.setText("Failed to reach Termux."); tvStatus.setTextColor(0xFFF85149); return;
        }
        pollSeconds = 0; pollPorts(outPath);
    }
    private void pollPorts(String path) {
        if (!isRunning) return;
        if (pollSeconds++ > 55) { progressBar.setVisibility(View.GONE); tvStatus.setText("Timeout. Termux might be busy."); tvStatus.setTextColor(0xFFF85149); return; }
        handler.postDelayed(() -> {
            String data = FileHelper.read(this, "ports.txt");
            if (data.contains("DONE")) updatePorts(data); else pollPorts(path);
        }, 1000);
    }
    private void updatePorts(String data) {
        String currentIp = null; int portCount = 0; String currentMac = "Unknown"; StringBuilder currentRaw = new StringBuilder();
        String[] lines = data.split("\n");
        Pattern ipPattern = Pattern.compile("([0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3})");
        Pattern macPattern = Pattern.compile("MAC Address: ([0-9A-Fa-f:]{17})");
        for (String line : lines) {
            if (line.contains("Nmap scan report for")) {
                if (currentIp != null) adapter.updateDevice(currentIp, portCount, currentMac, currentRaw.toString());
                Matcher m = ipPattern.matcher(line);
                if (m.find()) { currentIp = m.group(1); portCount = 0; currentMac = "Unknown"; currentRaw.setLength(0); }
            } else if (line.contains("/tcp") && line.contains("open")) { portCount++; currentRaw.append(line).append("\n"); }
            else if (line.contains("MAC Address:")) {
                Matcher m = macPattern.matcher(line);
                if (m.find()) currentMac = m.group(1);
            }
        }
        if (currentIp != null) adapter.updateDevice(currentIp, portCount, currentMac, currentRaw.toString());
        progressBar.setVisibility(View.GONE); tvStatus.setText("Scan Complete. Tap a device for details."); tvStatus.setTextColor(0xFF3FB950);
    }
    @Override protected void onDestroy() { super.onDestroy(); isRunning = false; handler.removeCallbacksAndMessages(null); }
}
