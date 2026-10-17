package com.xk.netprobe;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.net.wifi.ScanResult;
import android.net.wifi.WifiManager;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import java.util.ArrayList;
import java.util.List;

public class WifiScannerActivity extends AppCompatActivity {

    private WifiManager wifi;
    private TextView tvStatus;
    private WifiAdapter adapter;
    private BroadcastReceiver receiver;

    @Override
    protected void onCreate(Bundle s) {
        super.onCreate(s);
        setContentView(R.layout.activity_wifi);

        wifi = (WifiManager) getApplicationContext().getSystemService(Context.WIFI_SERVICE);
        RecyclerView recycler = findViewById(R.id.recyclerWifi);
        tvStatus = findViewById(R.id.tvWifiStatus);
        Button btn = findViewById(R.id.btnScanWifi);

        adapter = new WifiAdapter();
        recycler.setLayoutManager(new LinearLayoutManager(this));
        recycler.setAdapter(adapter);

        receiver = new BroadcastReceiver() {
            @Override public void onReceive(Context c, Intent i) { showResults(); }
        };

        btn.setOnClickListener(v -> {
            try {
                registerReceiver(receiver, new IntentFilter(WifiManager.SCAN_RESULTS_AVAILABLE_ACTION));
                boolean started = wifi.startScan();
                tvStatus.setText(started ? "جاري الفحص..." : "فشل بدء الفحص");
            } catch (Exception e) {
                Toast.makeText(this, "خطأ: " + e.getMessage(), Toast.LENGTH_LONG).show();
            }
        });
    }

    private void showResults() {
        try {
            List<ScanResult> list = wifi.getScanResults();
            if (list == null) list = new ArrayList<>();
            adapter.setItems(list);
            tvStatus.setText("عدد الشبكات: " + list.size());
        } catch (Exception e) {
            tvStatus.setText("خطأ: " + e.getMessage());
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        try { unregisterReceiver(receiver); } catch (Exception ignored) {}
    }

    static class WifiAdapter extends RecyclerView.Adapter<WifiAdapter.VH> {
        private final List<ScanResult> items = new ArrayList<>();
        void setItems(List<ScanResult> l) { items.clear(); items.addAll(l); notifyDataSetChanged(); }
        @NonNull @Override public VH onCreateViewHolder(@NonNull ViewGroup p, int t) {
            return new VH(LayoutInflater.from(p.getContext()).inflate(R.layout.item_wifi, p, false));
        }
        @Override public void onBindViewHolder(@NonNull VH h, int i) {
            ScanResult r = items.get(i);
            h.ssid.setText(r.SSID == null || r.SSID.isEmpty() ? "(hidden)" : r.SSID);
            h.bssid.setText(r.BSSID);
            h.info.setText("Signal: " + r.level + " dBm  |  " + r.frequency + " MHz");
        }
        @Override public int getItemCount() { return items.size(); }
        static class VH extends RecyclerView.ViewHolder {
            TextView ssid, bssid, info;
            VH(@NonNull View v) {
                super(v);
                ssid = v.findViewById(R.id.tvWifiSsid);
                bssid = v.findViewById(R.id.tvWifiBssid);
                info = v.findViewById(R.id.tvWifiInfo);
            }
        }
    }
}
