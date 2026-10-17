package com.xk.netprobe;

import android.Manifest;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

public class MainActivity extends AppCompatActivity {

    private static final int REQ_LOCATION = 1001;

    private EditText etTarget, etExtra;
    private TextView tvStatus, tvShizuku;
    private Button btnStart, btnWifi;

    @Override
    protected void onCreate(Bundle s) {
        super.onCreate(s);
        setContentView(R.layout.activity_main);

        etTarget = findViewById(R.id.etTarget);
        etExtra = findViewById(R.id.etExtraArgs);
        tvStatus = findViewById(R.id.tvStatus);
        tvShizuku = findViewById(R.id.tvShizukuStatus);
        btnStart = findViewById(R.id.btnStart);
        btnWifi = findViewById(R.id.btnWifi);

        requestLocationIfNeeded();

        PrivilegeManager.Level lvl = PrivilegeManager.detect(this);
        tvShizuku.setText("Privileges: " + PrivilegeManager.describe(lvl));

        wireShortcut(R.id.chipSn, "-sn");
        wireShortcut(R.id.chipSv, "-sV");
        wireShortcut(R.id.chipSt, "-sT");
        wireShortcut(R.id.chipA, "-A");
        wireShortcut(R.id.chipPn, "-Pn");
        wireShortcut(R.id.chipF, "-F");
        wireShortcut(R.id.chipP, "-p-");
        wireShortcut(R.id.chipTop100, "--top-ports 100");
        wireShortcut(R.id.chipT4, "-T4");
        wireShortcut(R.id.chipSC, "-sC");

        btnStart.setOnClickListener(v -> {
            String target = etTarget.getText().toString().trim();
            if (target.isEmpty()) {
                Toast.makeText(this, "أدخل IP أو نطاق", Toast.LENGTH_SHORT).show();
                return;
            }
            String extra = etExtra.getText().toString().trim();
            Intent i = new Intent(this, TerminalActivity.class);
            i.putExtra("target", target);
            i.putExtra("extra", extra);
            startActivity(i);
        });

        btnWifi.setOnClickListener(v -> {
            if (!hasLocationPerm()) {
                requestLocationIfNeeded();
                Toast.makeText(this, "امنح صلاحية الموقع أولاً", Toast.LENGTH_SHORT).show();
                return;
            }
            startActivity(new Intent(this, WifiScannerActivity.class));
        });
    }

    private void wireShortcut(int id, String cmd) {
        try {
            Button b = findViewById(id);
            if (b == null) return;
            b.setOnClickListener(v -> {
                String cur = etExtra.getText().toString();
                etExtra.setText(cur.isEmpty() ? cmd : cur + " " + cmd);
                etExtra.setSelection(etExtra.getText().length());
            });
        } catch (Exception ignored) {}
    }

    private boolean hasLocationPerm() {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
                == PackageManager.PERMISSION_GRANTED;
    }

    private void requestLocationIfNeeded() {
        if (!hasLocationPerm()) {
            ActivityCompat.requestPermissions(this,
                new String[]{Manifest.permission.ACCESS_FINE_LOCATION,
                             Manifest.permission.ACCESS_COARSE_LOCATION},
                REQ_LOCATION);
        }
    }
}
