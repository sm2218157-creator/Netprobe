package com.xk.netprobe;
import android.Manifest;
import android.provider.Settings;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import android.widget.ProgressBar;

import android.app.DownloadManager;
import android.content.BroadcastReceiver;
import android.content.IntentFilter;
import android.net.Uri;
import android.os.Environment;
import android.view.View;
import android.widget.ImageButton;
import androidx.core.content.FileProvider;
import org.json.JSONObject;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.io.File;

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
import androidx.appcompat.app.AlertDialog;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.lang.reflect.Method;
import rikka.shizuku.Shizuku;

public class MainActivity extends AppCompatActivity {
    private long downloadId = -1;
    private BroadcastReceiver onDownloadComplete;
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
        
        // ربط زر ESP32
        findViewById(R.id.cardEsp32).setOnClickListener(v -> startActivity(new Intent(this, Esp32Activity.class)));
        
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
        checkForUpdates();
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
            btnCheckNethunter.setBackgroundTintList(ColorStateList.valueOf(0xFF3FB950));
            btnCheckNethunter.setEnabled(false);
            btnDownloadNethunter.setEnabled(false);
            btnDownloadNethunter.setAlpha(0.5f);
        } else if (status.equals("MISSING")) {
            btnCheckNethunter.setText("غير مثبت");
            btnCheckNethunter.setBackgroundTintList(ColorStateList.valueOf(0xFFF85149));
            btnCheckNethunter.setEnabled(true);
            btnDownloadNethunter.setEnabled(true);
            btnDownloadNethunter.setAlpha(1.0f);
        } else {
            btnCheckNethunter.setText("تحقق من NetHunter");
            btnCheckNethunter.setBackgroundTintList(ColorStateList.valueOf(0xFFF0B72F));
            btnCheckNethunter.setEnabled(true);
            btnDownloadNethunter.setEnabled(true);
            btnDownloadNethunter.setAlpha(1.0f);
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

    private void checkForUpdates() {
        new Thread(() -> {
            try {
                URL url = new URL("https://raw.githubusercontent.com/sm2218157-creator/Netprobe/main/update.json");
                HttpURLConnection conn = (HttpURLConnection) url.openConnection();
                conn.setRequestMethod("GET");
                BufferedReader reader = new BufferedReader(new InputStreamReader(conn.getInputStream()));
                StringBuilder response = new StringBuilder();
                String line;
                while ((line = reader.readLine()) != null) { response.append(line); }
                reader.close();
                
                JSONObject json = new JSONObject(response.toString());
                int latestVersion = json.getInt("versionCode");
                String apkUrl = json.getString("apk_url");
                String versionName = json.getString("versionName");

                int tempVersion = 0;
                try {
                    tempVersion = getPackageManager().getPackageInfo(getPackageName(), 0).versionCode;
                } catch (Exception ignored) {}
                final int currentVersion = tempVersion;

                if (latestVersion > currentVersion) {
                    runOnUiThread(() -> showUpdateDialog(apkUrl, versionName));
                } else {
                    runOnUiThread(() -> Toast.makeText(MainActivity.this, "Debug: You have the latest version (" + currentVersion + ")", Toast.LENGTH_SHORT).show());
                }
            } catch (Exception e) {
                e.printStackTrace();
                runOnUiThread(() -> Toast.makeText(MainActivity.this, "Debug: Update check failed - " + e.getMessage(), Toast.LENGTH_LONG).show());
            }
        }).start();
    }

    private void showUpdateDialog(String apkUrl, String versionName) {
        AlertDialog.Builder builder = new AlertDialog.Builder(this, android.R.style.Theme_DeviceDefault_Dialog_Alert);
        View view = getLayoutInflater().inflate(R.layout.dialog_update, null);
        builder.setView(view);
        AlertDialog dialog = builder.create();
        dialog.setCancelable(false);

        ImageButton btnClose = view.findViewById(R.id.btnCloseUpdate);
        Button btnUpdate = view.findViewById(R.id.btnUpdateNow);
        TextView tvVersion = view.findViewById(R.id.tvUpdateVersion);
        
        tvVersion.setText("Version " + versionName + " is available!");
        
        btnClose.setOnClickListener(v -> dialog.dismiss());
        btnUpdate.setOnClickListener(v -> {
            ProgressBar progressBar = view.findViewById(R.id.progressBar);
            TextView tvProgress = view.findViewById(R.id.tvProgressText);
            downloadAndInstall(apkUrl, progressBar, tvProgress, btnUpdate);
        });
        dialog.show();
    }

    private void downloadAndInstall(String apkUrl, ProgressBar progressBar, TextView tvProgressText, Button btnUpdate) {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            if (!getPackageManager().canRequestPackageInstalls()) {
                Toast.makeText(this, "Please allow installing updates from this app.", Toast.LENGTH_LONG).show();
                Intent intent = new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES);
                intent.setData(Uri.parse("package:" + getPackageName()));
                startActivity(intent);
                return;
            }
        }

        btnUpdate.setVisibility(View.GONE);
        progressBar.setVisibility(View.VISIBLE);
        tvProgressText.setVisibility(View.VISIBLE);

        new Thread(() -> {
            try {
                URL url = new URL(apkUrl);
                HttpURLConnection conn = (HttpURLConnection) url.openConnection();
                conn.connect();

                int fileLength = conn.getContentLength();
                File apkFile = new File(getExternalFilesDir(null), "update.apk");
                FileOutputStream fos = new FileOutputStream(apkFile);
                InputStream is = conn.getInputStream();

                byte[] buffer = new byte[1024];
                int len;
                long total = 0;

                while ((len = is.read(buffer)) != -1) {
                    total += len;
                    fos.write(buffer, 0, len);
                    if (fileLength > 0) {
                        int progress = (int) (total * 100 / fileLength);
                        runOnUiThread(() -> {
                            progressBar.setProgress(progress);
                            tvProgressText.setText(progress + "%");
                        });
                    }
                }
                fos.close();
                is.close();

                runOnUiThread(() -> {
                    tvProgressText.setText("Download Complete. Installing...");
                    installApk(apkFile);
                });
            } catch (Exception e) {
                runOnUiThread(() -> {
                    Toast.makeText(this, "Download failed: " + e.getMessage(), Toast.LENGTH_SHORT).show();
                    progressBar.setVisibility(View.GONE);
                    tvProgressText.setVisibility(View.GONE);
                    btnUpdate.setVisibility(View.VISIBLE);
                });
            }
        }).start();
    }

    private void installApk(File apkFile) {
        try {
            Intent intent = new Intent(Intent.ACTION_VIEW);
            intent.setDataAndType(FileProvider.getUriForFile(this, getPackageName() + ".fileprovider", apkFile), "application/vnd.android.package-archive");
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(intent);
        } catch (Exception e) {
            Toast.makeText(this, "Failed to open installer: " + e.getMessage(), Toast.LENGTH_SHORT).show();
        }
    }

}

