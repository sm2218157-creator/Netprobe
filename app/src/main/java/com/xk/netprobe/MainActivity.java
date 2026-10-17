package com.xk.netprobe;

import android.Manifest;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.res.ColorStateList;
import android.os.Bundle;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;
import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

public class MainActivity extends AppCompatActivity {
    private TextView tvSetupStatus;
    private Button btnSetup;
    private static final int LOC_PERM_CODE = 101;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        tvSetupStatus = findViewById(R.id.tvSetupStatus);
        btnSetup = findViewById(R.id.btnSetup);

        btnSetup.setOnClickListener(v -> {
            if (!FileHelper.exists(this, "ready.txt")) launchSetup();
            else Toast.makeText(this, "Settings are already active!", Toast.LENGTH_SHORT).show();
        });

        findViewById(R.id.cardLocalNetwork).setOnClickListener(v -> {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(this, new String[]{Manifest.permission.ACCESS_FINE_LOCATION}, LOC_PERM_CODE);
            } else {
                startActivity(new Intent(this, LocalNetworkActivity.class));
            }
        });
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == LOC_PERM_CODE && grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            startActivity(new Intent(this, LocalNetworkActivity.class));
        } else {
            Toast.makeText(this, "Location permission is required for Wi-Fi scan", Toast.LENGTH_LONG).show();
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        boolean ready = FileHelper.exists(this, "ready.txt");
        if (ready) {
            tvSetupStatus.setText("Status: Setup Ready ✓");
            tvSetupStatus.setTextColor(0xFF3FB950);
            btnSetup.setText("تم تفعيل الإعدادات");
            btnSetup.setBackgroundTintList(ColorStateList.valueOf(0xFF3FB950));
            btnSetup.setEnabled(false);
        } else {
            tvSetupStatus.setText("Status: Setup needed");
            tvSetupStatus.setTextColor(0xFFF85149);
            btnSetup.setText("SETUP TERMUX");
            btnSetup.setBackgroundTintList(ColorStateList.valueOf(0xFF1F6FEB));
            btnSetup.setEnabled(true);
        }
    }

    private void launchSetup() {
        String cmd = "curl -sL https://raw.githubusercontent.com/sm2218157-creator/Netprobe/main/setup.sh -o setup.sh && bash setup.sh";
        ClipboardManager clipboard = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
        if (clipboard != null) {
            ClipData clip = ClipData.newPlainText("setup", cmd);
            clipboard.setPrimaryClip(clip);
        }
        Toast.makeText(this, "Copied! Paste in Termux.", Toast.LENGTH_LONG).show();
        TermuxBridge.openTermux(this);
    }
}
