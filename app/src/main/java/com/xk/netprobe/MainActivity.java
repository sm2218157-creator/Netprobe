package com.xk.netprobe;
import android.Manifest;
import android.content.*;
import android.content.pm.PackageManager;
import android.content.res.ColorStateList;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;
import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
public class MainActivity extends AppCompatActivity {
    private TextView tvSetupStatus; private Button btnSetup;
    private static final int LOC_PERM_CODE = 101; private static final int SETUP_REQ_CODE = 202;
    private final Handler pollHandler = new Handler(Looper.getMainLooper()); private boolean polling = false;
    private final Runnable pollRunnable = new Runnable() {
        @Override public void run() {
            if (!polling) return; refreshSetupState();
            if (FileHelper.exists(MainActivity.this, "ready.txt") || FileHelper.exists(MainActivity.this, "error.txt")) { polling = false; return; }
            pollHandler.postDelayed(this, 2000);
        }
    };
    private final BroadcastReceiver termuxResult = new BroadcastReceiver() {
        @Override public void onReceive(Context ctx, Intent intent) { refreshSetupState(); }
    };
    @Override protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        tvSetupStatus = findViewById(R.id.tvSetupStatus); btnSetup = findViewById(R.id.btnSetup);
        btnSetup.setOnClickListener(v -> { if (FileHelper.exists(this, "ready.txt")) Toast.makeText(this, "Already active!", Toast.LENGTH_SHORT).show(); else launchSetup(); });
        btnSetup.setOnLongClickListener(v -> { FileHelper.delete(this, "ready.txt"); FileHelper.delete(this, "error.txt"); launchSetup(); return true; });
        findViewById(R.id.cardLocalNetwork).setOnClickListener(v -> {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) ActivityCompat.requestPermissions(this, new String[]{Manifest.permission.ACCESS_FINE_LOCATION}, LOC_PERM_CODE);
            else startActivity(new Intent(this, LocalNetworkActivity.class));
        });
        ContextCompat.registerReceiver(this, termuxResult, new IntentFilter(TermuxBridge.ACTION_RESULT), ContextCompat.RECEIVER_NOT_EXPORTED);
    }
    @Override protected void onDestroy() { super.onDestroy(); polling = false; try { unregisterReceiver(termuxResult); } catch (Exception ignored) {} }
    @Override public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == LOC_PERM_CODE && grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) startActivity(new Intent(this, LocalNetworkActivity.class));
    }
    @Override protected void onResume() { super.onResume(); refreshSetupState(); if (!FileHelper.exists(this, "ready.txt") && !FileHelper.exists(this, "error.txt")) startPolling(); }
    @Override protected void onPause() { super.onPause(); polling = false; }
    private void startPolling() { if (polling) return; polling = true; pollHandler.post(pollRunnable); }
    private void refreshSetupState() {
        if (FileHelper.exists(this, "error.txt")) {
            tvSetupStatus.setText("Status: Setup failed — long-press to retry"); tvSetupStatus.setTextColor(0xFFF85149);
            btnSetup.setText("RETRY SETUP"); btnSetup.setBackgroundTintList(ColorStateList.valueOf(0xFFDA3633)); btnSetup.setEnabled(true);
        } else if (FileHelper.exists(this, "ready.txt")) {
            tvSetupStatus.setText("Status: Setup Ready ✓"); tvSetupStatus.setTextColor(0xFF3FB950);
            btnSetup.setText("تم تفعيل الإعدادات"); btnSetup.setBackgroundTintList(ColorStateList.valueOf(0xFF3FB950)); btnSetup.setEnabled(false);
        } else {
            tvSetupStatus.setText("Status: Setup needed"); tvSetupStatus.setTextColor(0xFFF85149);
            btnSetup.setText("SETUP TERMUX"); btnSetup.setBackgroundTintList(ColorStateList.valueOf(0xFF1F6FEB)); btnSetup.setEnabled(true);
        }
    }
    private void launchSetup() {
        if (!TermuxBridge.isTermuxInstalled(this)) { Toast.makeText(this, "Termux not installed.", Toast.LENGTH_LONG).show(); return; }
        String cmd = "pkg install curl -y && curl -fsSL https://raw.githubusercontent.com/sm2218157-creator/Netprobe/main/setup.sh -o setup.sh && bash setup.sh";
        if (TermuxBridge.runCommand(this, cmd, SETUP_REQ_CODE)) {
            tvSetupStatus.setText("Status: Running setup..."); tvSetupStatus.setTextColor(0xFFF0B72F); startPolling(); TermuxBridge.openTermux(this);
        } else {
            ((ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE)).setPrimaryClip(ClipData.newPlainText("setup", cmd));
            Toast.makeText(this, "Copied! Paste in Termux.", Toast.LENGTH_LONG).show(); TermuxBridge.openTermux(this);
        }
    }
}
