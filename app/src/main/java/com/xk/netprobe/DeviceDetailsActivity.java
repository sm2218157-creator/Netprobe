package com.xk.netprobe;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
public class DeviceDetailsActivity extends AppCompatActivity {
    private String ip, mac, rawPorts;
    private PortAdapter adapter;
    private TextView tvStatus;
    private Button btnDeepScan;
    @Override protected void onCreate(Bundle b) {
        super.onCreate(b);
        setContentView(R.layout.activity_device_details);
        ip = getIntent().getStringExtra("ip"); mac = getIntent().getStringExtra("mac"); rawPorts = getIntent().getStringExtra("rawPorts");
        TextView tvIp = findViewById(R.id.tvDetailsIp); TextView tvMac = findViewById(R.id.tvDetailsMac);
        tvStatus = findViewById(R.id.tvStatus); btnDeepScan = findViewById(R.id.btnDeepScan);
        tvIp.setText(ip); tvMac.setText("MAC: " + mac);
        RecyclerView recycler = findViewById(R.id.recyclerPorts);
        recycler.setLayoutManager(new LinearLayoutManager(this));
        adapter = new PortAdapter(); recycler.setAdapter(adapter); adapter.setData(rawPorts);
        btnDeepScan.setOnClickListener(v -> performDeepScan());
    }
    private void performDeepScan() {
        tvStatus.setText("Running Deep Scan (Nmap -sV)..."); btnDeepScan.setEnabled(false);
        String outPath = FileHelper.pathOf(this, "deep_ports.txt"); FileHelper.write(this, "deep_ports.txt", "");
        String cmd = "export PATH=/data/data/com.termux/files/usr/bin:$PATH; timeout 60 nmap -sV -F " + ip + " > \"" + outPath + "\" 2>&1; echo DONE >> \"" + outPath + "\"";
        if (!TermuxBridge.runCommand(this, cmd, 404)) {
            Toast.makeText(this, "Failed to reach Termux", Toast.LENGTH_SHORT).show(); btnDeepScan.setEnabled(true); return;
        }
        new Handler(Looper.getMainLooper()).postDelayed(new Runnable() {
            int secs = 0;
            @Override public void run() {
                String data = FileHelper.read(DeviceDetailsActivity.this, "deep_ports.txt");
                if (data.contains("DONE")) { adapter.setData(data); tvStatus.setText("Deep Scan Complete."); btnDeepScan.setEnabled(true); }
                else if (secs++ > 65) { tvStatus.setText("Deep Scan Timeout."); btnDeepScan.setEnabled(true); }
                else { new Handler(Looper.getMainLooper()).postDelayed(this, 1000); }
            }
        }, 1000);
    }
}
