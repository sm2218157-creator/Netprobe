package com.xk.netprobe;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.net.wifi.WifiManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.widget.TextView;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.content.ContextCompat;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class LocalNetworkActivity extends AppCompatActivity {
    private static final int NMAP_REQ_CODE = 303;

    private TextView tvSsid, tvSubnet, tvStatus, tvMyIp;
    private DeviceAdapter adapter;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private boolean isRunning = true;
    private int pollSeconds = 0;

    private final BroadcastReceiver nmapResult = new BroadcastReceiver() {
        @Override public void onReceive(Context ctx, Intent intent) {
            int exit = intent.getIntExtra(TermuxBridge.EXTRA_EXIT, -1);
            String out = intent.getStringExtra(TermuxBridge.EXTRA_STDOUT);
            if (exit == 0 && out != null && !out.isEmpty()) {
                updatePorts(out);
            } else if (exit != 0) {
                tvStatus.setText("Nmap failed (exit " + exit + ")");
                tvStatus.setTextColor(0xFFF85149);
            }
        }
    };

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
        if (subnet == null) {
            tvStatus.setText("Could not detect Wi-Fi network");
            tvStatus.setTextColor(0xFFF85149);
            return;
        }

        tvMyIp.setText("My IP: " + myIp);
        tvSubnet.setText("Subnet: " + subnet);

        WifiManager wm = (WifiManager) getApplicationContext().getSystemService(WIFI_SERVICE);
        if (wm != null && wm.getConnectionInfo() != null) {
            String ssid = wm.getConnectionInfo().getSSID().replace("\"", "");
            tvSsid.setText(ssid.isEmpty() || ssid.equals("<unknown ssid>") ? "Unknown" : ssid);
        }

        IntentFilter filter = new IntentFilter(TermuxBridge.ACTION_RESULT);
        ContextCompat.registerReceiver(this, nmapResult, filter,
                ContextCompat.RECEIVER_NOT_EXPORTED);

        startDiscovery(subnet);
    }

    private void startDiscovery(String subnet) {
        tvStatus.setText("Scanning network...");
        NetworkDiscovery.scan(subnet, new NetworkDiscovery.Callback() {
            @Override public void onDeviceFound(String ip) {
                if (!isRunning) return;
                handler.post(() -> adapter.addDevice(ip));
            }
            @Override public void onFinished(int total) {
                if (!isRunning) return;
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
        String outPath = FileHelper.pathOf(this, "ports.txt");
        FileHelper.write(this, "targets.txt", targets.toString());
        FileHelper.write(this, "ports.txt", "");

        String cmd = "export PATH=/data/data/com.termux/files/usr/bin:$PATH; "
                + "timeout 45 nmap -sT -T4 -F -iL \"" + targetsPath + "\" > \"" + outPath + "\" 2>&1; "
                + "echo DONE >> \"" + outPath + "\"";

        boolean sent = TermuxBridge.runCommand(this, cmd, NMAP_REQ_CODE);
        if (!sent) {
            tvStatus.setText("Failed to reach Termux");
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
            if (data.contains("DONE")) updatePorts(data);
            else pollPorts(path);
        }, 1000);
    }

    private void updatePorts(String data) {
        String currentIp = null;
        int portCount = 0;
        Pattern p = Pattern.compile("([0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3})");
        for (String line : data.split("\n")) {
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
        try { unregisterReceiver(nmapResult); } catch (Exception ignored) {}
    }
}
