#!/bin/bash
set -e
PROJ="/workspaces/NetProbe-Final"
APP="$PROJ/app"
PKG="$APP/src/main/java/com/xk/netprobe"
RES="$APP/src/main/res"
EXPLORER="/workspaces/Netprobe"
KS="/workspaces/debug.keystore"
SDK="$HOME/android-sdk"
VERSION="20.9"

export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH="$JAVA_HOME/bin:$PATH"
export ANDROID_HOME="$SDK"

echo "=== Building NetProbe v$VERSION (Silent Termux Bridge Fix) ==="

# تحديث MainActivity فقط لإضافة ميزة الجسر الصامت
cat > "$PKG/MainActivity.java" << 'EOF'
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
    private static final int LOC_PERM_CODE = 101;
    private static final int SHIZUKU_REQ_CODE = 202;
    private static final int BRIDGE_REQ_CODE = 303;
    private final Handler pollHandler = new Handler(Looper.getMainLooper());
    private boolean isShizukuReady = false;

    private final Shizuku.OnRequestPermissionResultListener permListener = (requestCode, grantResult) -> {
        if (requestCode == SHIZUKU_REQ_CODE) {
            if (grantResult == PackageManager.PERMISSION_GRANTED) {
                isShizukuReady = true;
                checkNmapViaShizuku();
            } else {
                attemptSilentBridge(); 
            }
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        tvSetupStatus = findViewById(R.id.tvSetupStatus);
        btnSetup = findViewById(R.id.btnSetup);

        btnSetup.setOnClickListener(v -> {
            if (btnSetup.getText().toString().equals("تم تفعيل الإعدادات")) {
                openLocalNetwork();
            } else if (btnSetup.getText().toString().equals("SETUP TERMUX") || btnSetup.getText().toString().equals("RETRY SETUP")) {
                launchSetup();
            }
        });

        try { Shizuku.addRequestPermissionResultListener(permListener); } catch (Exception ignored) {}
        checkInitialStatus();
    }

    @Override
    protected void onResume() {
        super.onResume();
        checkInitialStatus();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        try { Shizuku.removeRequestPermissionResultListener(permListener); } catch (Exception ignored) {}
    }

    private void checkInitialStatus() {
        setButtonState("جاري الفحص...", 0xFFF0B72F, false);
        
        try {
            if (Shizuku.pingBinder()) {
                if (Shizuku.isPreV11()) {
                    isShizukuReady = true;
                    checkNmapViaShizuku();
                } else if (Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED) {
                    isShizukuReady = true;
                    checkNmapViaShizuku();
                } else {
                    Shizuku.requestPermission(SHIZUKU_REQ_CODE);
                }
            } else {
                attemptSilentBridge();
            }
        } catch (Exception e) {
            attemptSilentBridge();
        }
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
            runOnUiThread(() -> {
                if (finalHasNmap) setButtonState("تم تفعيل الإعدادات", 0xFF3FB950, true);
                else attemptSilentBridge();
            });
        }).start();
    }

    private void attemptSilentBridge() {
        // إرسال أمر صامت عبر الجسر لإنشاء الملف
        String cmd = "mkdir -p /sdcard/Android/media/com.xk.netprobe/NetProbe && echo 'READY_CF' > /sdcard/Android/media/com.xk.netprobe/NetProbe/ready.txt";
        boolean sent = TermuxBridge.runCommand(this, cmd, BRIDGE_REQ_CODE);
        
        // انتظار بسيط لإتاحة الفرصة لـ Termux لإنشاء الملف ثم الفحص
        if (sent) {
            pollHandler.postDelayed(this::checkReadyFile, 2000);
        } else {
            checkReadyFile(); 
        }
    }

    private void checkReadyFile() {
        String content = FileHelper.read(this, "ready.txt");
        if (content.contains("READY")) { 
            setButtonState("تم تفعيل الإعدادات", 0xFF3FB950, true);
        } else {
            setButtonState("SETUP TERMUX", 0xFFF85149, true);
        }
    }

    private void setButtonState(String text, int color, boolean enabled) {
        btnSetup.setText(text);
        btnSetup.setBackgroundTintList(ColorStateList.valueOf(color));
        btnSetup.setEnabled(enabled);
        
        if (text.equals("جاري الفحص...")) {
            tvSetupStatus.setText("Status: Checking...");
            tvSetupStatus.setTextColor(0xFFF0B72F);
        } else if (text.equals("تم تفعيل الإعدادات")) {
            tvSetupStatus.setText("Status: Setup Ready ✓");
            tvSetupStatus.setTextColor(0xFF3FB950);
        } else {
            tvSetupStatus.setText("Status: Setup needed");
            tvSetupStatus.setTextColor(0xFFF85149);
        }
    }

    private void openLocalNetwork() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, new String[]{Manifest.permission.ACCESS_FINE_LOCATION}, LOC_PERM_CODE);
        } else {
            startActivity(new Intent(this, LocalNetworkActivity.class));
        }
    }

    private void launchSetup() {
        String cmd = SetupScriptStore.SETUP_SCRIPT;
        ClipboardManager clipboard = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
        if (clipboard != null) clipboard.setPrimaryClip(ClipData.newPlainText("setup", cmd));
        Toast.makeText(this, "Copied! Paste in Termux.", Toast.LENGTH_LONG).show();
        
        setButtonState("جاري الفحص...", 0xFFF0B72F, false);
        TermuxBridge.openTermux(this);
        
        pollHandler.postDelayed(this::checkInitialStatus, 10000);
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == LOC_PERM_CODE && grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            startActivity(new Intent(this, LocalNetworkActivity.class));
        }
    }
}
EOF

# تحديث الإصدار
sed -i 's/versionCode 32/versionCode 33/' "$APP/build.gradle" || true
sed -i 's/versionName "20.8"/versionName "20.9"/' "$APP/build.gradle" || true
sed -i 's/v20.8/v20.9/' "$RES/layout/activity_main.xml" || true

# البناء والتوقيع
echo "⏳ Building APK..."
cd "$PROJ"
./gradlew --stop > /dev/null 2>&1 || true
./gradlew clean assembleDebug

APK_TMP="$APP/build/outputs/apk/debug/app-debug.apk"
if [ ! -f "$APK_TMP" ]; then echo "❌ BUILD FAILED."; exit 1; fi

APKSIGNER=$(find "$SDK/build-tools" -name apksigner | head -1)
ZIPALIGN=$(find "$SDK/build-tools" -name zipalign | head -1)
[ ! -f "$KS" ] && keytool -genkeypair -v -keystore "$KS" -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US" 2>&1 | tail -1

[ -n "$ZIPALIGN" ] && {
    "$ZIPALIGN" -f -p 4 "$APK_TMP" "${APK_TMP%.apk}-aligned.apk"
    mv "${APK_TMP%.apk}-aligned.apk" "$APK_TMP"
}
"$APKSIGNER" sign --ks "$KS" --ks-pass pass:android --key-pass pass:android "$APK_TMP" 2>&1

# نقل الملفات للمستكشف
echo "⏳ Moving to Explorer..."
mkdir -p "$EXPLORER"
cp "$APK_TMP" "$EXPLORER/NetProbe-v${VERSION}.apk"
cd "$EXPLORER"
zip -q "NetProbe-v${VERSION}.zip" "NetProbe-v${VERSION}.apk"

echo "✅ ALL DONE! NetProbe-v${VERSION}.apk and .zip are in Explorer."
