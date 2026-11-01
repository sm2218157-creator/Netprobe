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

        findViewById(R.id.cardInstallWps).setOnClickListener(v -> {
            // استخدام الوضع الصامت (الخلفية)
            boolean sent = TermuxBridge.runCommandBackground(this, SetupScriptStore.WPS_INSTALL_SCRIPT, 606);
            if (sent) {
                Toast.makeText(this, "Executing in background...", Toast.LENGTH_SHORT).show();
                // تأخير ثانيتين لضمان استقبال Termux للأمر قبل فتح الشاشة
                new Handler(Looper.getMainLooper()).postDelayed(() -> TermuxBridge.openTermux(this), 2000);
            } else {
                // الحل الرابع (الاحتياطي): نسخ إلى الحافظة
                copyToClipboard(SetupScriptStore.WPS_INSTALL_SCRIPT);
            }
        });

        findViewById(R.id.cardRunWps).setOnClickListener(v -> {
            boolean sent = TermuxBridge.runCommandBackground(this, SetupScriptStore.WPS_RUN_SCRIPT, 707);
            if (sent) {
                Toast.makeText(this, "Executing in background...", Toast.LENGTH_SHORT).show();
                new Handler(Looper.getMainLooper()).postDelayed(() -> TermuxBridge.openTermux(this), 2000);
            } else {
                copyToClipboard(SetupScriptStore.WPS_RUN_SCRIPT);
            }
        });
    }

    private void copyToClipboard(String text) {
        ClipboardManager clipboard = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
        if (clipboard != null) {
            clipboard.setPrimaryClip(ClipData.newPlainText("script", text));
            Toast.makeText(this, "Termux bridge failed. Script copied to clipboard.", Toast.LENGTH_LONG).show();
            TermuxBridge.openTermux(this);
        }
    }
}
