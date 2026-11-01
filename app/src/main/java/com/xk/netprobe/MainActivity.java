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
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.lang.reflect.Method;
import rikka.shizuku.Shizuku;

public class MainActivity extends AppCompatActivity {
    private TextView tvSetupStatus; 
    private Button btnSetup;
    private Button btnDownloadNethunter;
    private Button btnCheckNethunter;
    private static final int LOC_PERM_CODE = 101; private static final int SHIZUKU_REQ_CODE = 202; private static final int BRIDGE_REQ_CODE = 303;
    private final Handler pollHandler = new Handler(Looper.getMainLooper());
    private boolean isShizukuReady = false;

    private final Shizuku.OnRequestPermissionResultListener permListener = (requestCode, grantResult) -> {
        if (requestCode == SHIZUKU_REQ_CODE) {
            if (grantResult == PackageManager.PERMISSION_GRANTED) { isShizukuReady = true; checkNmapViaShizuku(); } 
            else { attemptSilentBridge(); }
        }
    };

    @Override protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        tvSetupStatus = findViewById(R.id.tvSetupStatus); 
        btnSetup = findViewById(R.id.btnSetup);
        btnDownloadNethunter = findViewById(R.id.btnDownloadNethunter);
        btnCheckNethunter = findViewById(R.id.btnCheckNethunter);

        btnSetup.setOnClickListener(v -> {
            if (btnSetup.getText().toString().equals("تم تفعيل الإعدادات")) openLocalNetwork();
            else launchSetup();
        });

        findViewById(R.id.cardLocalNetwork).setOnClickListener(v -> openLocalNetwork());
        findViewById(R.id.cardAttack).setOnClickListener(v -> startActivity(new Intent(this, AttackActivity.class)));
        
        btnDownloadNethunter.setOnClickListener(v -> {
            ClipboardManager clipboard = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
            if (clipboard != null) clipboard.setPrimaryClip(ClipData.newPlainText("nethunter", SetupScriptStore.NETHUNTER_SCRIPT));
            Toast.makeText(this, "Copied! Paste in Termux to install NetHunter.", Toast.LENGTH_LONG).show();
            TermuxBridge.openTermux(this);
        });

        btnCheckNethunter.setOnClickListener(v -> {
            ClipboardManager clipboard = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
            if (clipboard != null) clipboard.setPrimaryClip(ClipData.newPlainText("check", SetupScriptStore.NETHUNTER_CHECK_SCRIPT));
            Toast.makeText(this, "Copied check script. Paste in Termux.", Toast.LENGTH_SHORT).show();
            TermuxBridge.openTermux(this);
        });

        findViewById(R.id.tvCodeEnter).setOnClickListener(v -> copyToClipboard("nethunter"));
        findViewById(R.id.tvCodeExit).setOnClickListener(v -> copyToClipboard("exit"));

        try { Shizuku.addRequestPermissionResultListener(permListener); } catch (Exception ignored) {}
        checkInitialStatus();
    }
    
    private void copyToClipboard(String text) {
        ClipboardManager clipboard = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
        if (clipboard != null) {
            clipboard.setPrimaryClip(ClipData.newPlainText("code", text));
            Toast.makeText(this, "Copied: " + text, Toast.LENGTH_SHORT).show();
        }
    }

    @Override protected void onResume() { 
        super.onResume(); 
        checkInitialStatus(); 
        checkNethunterStatus();
    }
    
    private void checkNethunterStatus() {
        String status = FileHelper.read(this, "nethunter_status.txt").trim();
        if (status.equals("READY")) {
            btnCheckNethunter.setText("مثبت وجاهز");
            btnCheckNethunter.setBackgroundTintList(ColorStateList.valueOf(0xFF3FB950)); // Green
            btnCheckNethunter.setEnabled(false);
            
            btnDownloadNethunter.setEnabled(false);
            btnDownloadNethunter.setAlpha(0.5f); // Baha
        } else if (status.equals("MISSING")) {
            btnCheckNethunter.setText("غير مثبت");
            btnCheckNethunter.setBackgroundTintList(ColorStateList.valueOf(0xFFF85149)); // Red
            btnCheckNethunter.setEnabled(true);
            
            btnDownloadNethunter.setEnabled(true);
            btnDownloadNethunter.setAlpha(1.0f); // Bariz
        } else {
            btnCheckNethunter.setText("تحقق من NetHunter");
            btnCheckNethunter.setBackgroundTintList(ColorStateList.valueOf(0xFFF0B72F)); // Orange
            btnCheckNethunter.setEnabled(true);
            
            btnDownloadNethunter.setEnabled(true);
            btnDownloadNethunter.setAlpha(1.0f); // Bariz
        }
    }

    @Override protected void onDestroy() { super.onDestroy(); try { Shizuku.removeRequestPermissionResultListener(permListener); } catch (Exception ignored) {} }

    private void checkInitialStatus() {
        setButtonState("جاري الفحص...", 0xFFF0B72F, false);
        try {
            if (Shizuku.pingBinder()) {
                if (Shizuku.isPreV11() || Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED) { isShizukuReady = true; checkNmapViaShizuku(); } 
                else { Shizuku.requestPermission(SHIZUKU_REQ_CODE); }
            } else { attemptSilentBridge(); }
        } catch (Exception e) { attemptSilentBridge(); }
    }

    private void checkNmapViaShizuku() {
        new Thread(() -> {
            boolean hasNmap = false;
            try {
                Method method = Shizuku.class.getDeclaredMethod("newProcess", String[].class, String[].class, String.class);
                method.setAccessible(true);
                String cmd = "export PATH=/data/data/com.termux/files/usr/bin:$PATH; command -v nmap";
                Process p = (Process) method.invoke(null, new String[]{"sh", "-c", cmd}, null, null);
                BufferedReader br = new BufferedReader(new InputStreamReader(p.getInputStream()));
                String line = br.readLine();
                if (line != null && line.contains("nmap")) hasNmap = true;
            } catch (Exception ignored) {}
            final boolean finalHasNmap = hasNmap;
            runOnUiThread(() -> { if (finalHasNmap) setButtonState("تم تفعيل الإعدادات", 0xFF3FB950, true); else attemptSilentBridge(); });
        }).start();
    }

    private void attemptSilentBridge() {
        String cmd = "mkdir -p /sdcard/Android/media/com.xk.netprobe/NetProbe && echo 'READY_CF' > /sdcard/Android/media/com.xk.netprobe/NetProbe/ready.txt";
        if (TermuxBridge.runCommand(this, cmd, BRIDGE_REQ_CODE)) pollHandler.postDelayed(this::checkReadyFile, 2000);
        else checkReadyFile(); 
    }

    private void checkReadyFile() {
        if (FileHelper.read(this, "ready.txt").contains("READY")) setButtonState("تم تفعيل الإعدادات", 0xFF3FB950, true);
        else setButtonState("SETUP TERMUX", 0xFFF85149, true);
    }

    private void setButtonState(String text, int color, boolean enabled) {
        btnSetup.setText(text); btnSetup.setBackgroundTintList(ColorStateList.valueOf(color)); btnSetup.setEnabled(enabled);
        if (text.equals("جاري الفحص...")) { tvSetupStatus.setText("Status: Checking..."); tvSetupStatus.setTextColor(0xFFF0B72F); }
        else if (text.equals("تم تفعيل الإعدادات")) { tvSetupStatus.setText("Status: Setup Ready ✓"); tvSetupStatus.setTextColor(0xFF3FB950); }
        else { tvSetupStatus.setText("Status: Setup needed"); tvSetupStatus.setTextColor(0xFFF85149); }
    }

    private void openLocalNetwork() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) 
            ActivityCompat.requestPermissions(this, new String[]{Manifest.permission.ACCESS_FINE_LOCATION}, LOC_PERM_CODE);
        else startActivity(new Intent(this, LocalNetworkActivity.class));
    }

    private void launchSetup() {
        ClipboardManager clipboard = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
        if (clipboard != null) clipboard.setPrimaryClip(ClipData.newPlainText("setup", SetupScriptStore.SETUP_SCRIPT));
        Toast.makeText(this, "Copied! Paste in Termux.", Toast.LENGTH_LONG).show();
        setButtonState("جاري الفحص...", 0xFFF0B72F, false);
        TermuxBridge.openTermux(this);
        pollHandler.postDelayed(this::checkInitialStatus, 10000);
    }

    @Override public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == LOC_PERM_CODE && grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) startActivity(new Intent(this, LocalNetworkActivity.class));
    }
}
