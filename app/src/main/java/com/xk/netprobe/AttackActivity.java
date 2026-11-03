package com.xk.netprobe;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;

public class AttackActivity extends AppCompatActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_attack);

        if (!FileHelper.exists(this, "ready.txt")) {
            Toast.makeText(this, "يرجى إكمال التهيئة (Setup) أولاً من الشاشة الرئيسية!", Toast.LENGTH_LONG).show();
            finish();
            return;
        }

        // زر Bettercap
        findViewById(R.id.cardBettercap).setOnClickListener(v -> {
            copyToClipboard(SetupScriptStore.BETTERCAP_SCRIPT);
        });

        // زر WiFite2
        findViewById(R.id.cardInstallWps).setOnClickListener(v -> {
            boolean sent = TermuxBridge.runCommandBackground(this, SetupScriptStore.WIFITE_SCRIPT, 606);
            if (sent) {
                Toast.makeText(this, "Executing in background...", Toast.LENGTH_SHORT).show();
                new Handler(Looper.getMainLooper()).postDelayed(() -> TermuxBridge.openTermux(this), 2000);
            } else {
                copyToClipboard(SetupScriptStore.WIFITE_SCRIPT);
            }
        });

        // زر Wi-Fi Nightmare
        findViewById(R.id.cardRunWps).setOnClickListener(v -> {
            copyToClipboard(SetupScriptStore.WIFI_NIGHTMARE_SCRIPT);
        });
    }

    private void copyToClipboard(String text) {
        ClipboardManager clipboard = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
        if (clipboard != null) {
            clipboard.setPrimaryClip(ClipData.newPlainText("script", text));
            Toast.makeText(this, "Script copied! Paste in Termux.", Toast.LENGTH_LONG).show();
            TermuxBridge.openTermux(this);
        }
    }
}
