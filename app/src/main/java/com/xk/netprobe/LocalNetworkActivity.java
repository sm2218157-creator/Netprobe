package com.xk.netprobe;

import android.net.wifi.WifiManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.widget.TextView;
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

        // قراءة الـ IP الحقيقي
        String myIp = NetInfo.getMyIp(this);
        String subnet = NetInfo.getSubnet(this);
        
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
        
        // timeout 45 لضمان عدم التعليق
        String cmd = "export PATH=/data/data/com.termux/files/usr/bin:$PATH; timeout 45 nmap -sT -T4 -F -iL \"" + targetsPath + "\" > \"" + outPath + "\" 2>&1; echo DONE >> \"" + outPath + "\"";
        TermuxBridge.runCommand(this, cmd);
        pollPorts(outPath, 0);
    }

    private void pollPorts(String path, int seconds) {
        if (!isRunning) return;
        if (seconds > 60) {
            tvStatus.setText("Timeout. Termux might be busy.");
            tvStatus.setTextColor(0xFFF85149);
            return;
        }
        handler.postDelayed(() -> {
            String data = FileHelper.read(this, "ports.txt");
            if (data.contains("DONE")) {
                updatePorts(data);
            } else {
                pollPorts(path, seconds + 1);
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
