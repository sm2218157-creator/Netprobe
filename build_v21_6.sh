#!/bin/bash
set -e
PROJ="/workspaces/NetProbe-Final"
APP="$PROJ/app"
PKG="$APP/src/main/java/com/xk/netprobe"
RES="$APP/src/main/res"
EXPLORER="/workspaces/Netprobe"
KS="/workspaces/debug.keystore"
SDK="$HOME/android-sdk"
VERSION="21.6"

export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH="$JAVA_HOME/bin:$PATH"
export ANDROID_HOME="$SDK"

echo "=== Building NetProbe v$VERSION (Fixing WPS Script & Button) ==="

# 1. تحديث الإصدار
sed -i 's/versionCode 38/versionCode 39/' "$APP/build.gradle" || true
sed -i 's/versionName "21.5"/versionName "21.6"/' "$APP/build.gradle" || true

# 2. تحديث سكربت WPS ليكتشف اسم الكرت تلقائياً
cat > "$PKG/SetupScriptStore.java" << 'EOF'
package com.xk.netprobe;
public class SetupScriptStore {
    public static final String SETUP_SCRIPT = 
        "export DEBIAN_FRONTEND=noninteractive; " +
        "echo 'deb https://packages-cf.termux.dev/apt/termux-main stable main' > $PREFIX/etc/apt/sources.list; " +
        "pkg update -y > /dev/null 2>&1; " +
        "pkg install nmap curl wget -y > /dev/null 2>&1; " +
        "mkdir -p /sdcard/Android/media/com.xk.netprobe/NetProbe; " +
        "echo 'READY_CF' > /sdcard/Android/media/com.xk.netprobe/NetProbe/ready.txt; " +
        "echo '✅ Setup COMPLETE! Return to NetProbe.'";

    public static final String WPS_SCRIPT = 
        "export DEBIAN_FRONTEND=noninteractive; " +
        "echo '[*] Installing WPS Tools...'; " +
        "pkg update -y > /dev/null 2>&1; " +
        "pkg install aircrack-ng reaver iw -y > /dev/null 2>&1; " +
        "echo '[*] Detecting external adapter...'; " +
        "IFACE=$(iw dev | awk '$1==\"Interface\"{print $2}' | grep -v wlan0 | head -n 1); " +
        "if [ -z \"$IFACE\" ]; then echo '[-] No external adapter found!'; exit 1; fi; " +
        "echo \"[+] Found adapter: $IFACE\"; " +
        "echo '[*] Starting Monitor Mode...'; " +
        "airmon-ng check kill > /dev/null 2>&1; " +
        "airmon-ng start $IFACE > /dev/null 2>&1; " +
        "MON_IFACE=$(iw dev | awk '$1==\"Interface\"{print $2}' | grep mon | head -n 1); " +
        "if [ -z \"$MON_IFACE\" ]; then echo '[-] Failed to start monitor mode.'; exit 1; fi; " +
        "echo \"[+] Monitor mode active on $MON_IFACE\"; " +
        "echo '[*] Scanning for WPS Networks (Press Ctrl+C to stop)...'; " +
        "wash -i $MON_IFACE";
}
EOF

# 3. كتابة MainActivity بالكامل (لضمان عمل زر WPS بدون أخطاء الاستبدال)
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
    private TextView tvSetupStatus; private Button btnSetup;
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
        tvSetupStatus = findViewById(R.id.tvSetupStatus); btnSetup = findViewById(R.id.btnSetup);

        btnSetup.setOnClickListener(v -> {
            if (btnSetup.getText().toString().equals("تم تفعيل الإعدادات")) openLocalNetwork();
            else launchSetup();
        });

        findViewById(R.id.cardLocalNetwork).setOnClickListener(v -> openLocalNetwork());

        findViewById(R.id.cardWps).setOnClickListener(v -> {
            String cmd = SetupScriptStore.WPS_SCRIPT;
            TermuxBridge.runCommand(this, cmd, 505);
            TermuxBridge.openTermux(this);
            Toast.makeText(this, "جاري تشغيل أداة WPS في Termux...", Toast.LENGTH_LONG).show();
        });

        try { Shizuku.addRequestPermissionResultListener(permListener); } catch (Exception ignored) {}
        checkInitialStatus();
    }

    @Override protected void onResume() { super.onResume(); checkInitialStatus(); }
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
EOF

# 4. تحديث الإصدار في الواجهة
sed -i 's/v21.5/v21.6/' "$RES/layout/activity_main.xml" || true

# 5. البناء والتوقيع
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

# 6. نقل الملفات للمستكشف
echo "⏳ Moving to Explorer..."
mkdir -p "$EXPLORER"
cp "$APK_TMP" "$EXPLORER/NetProbe-v${VERSION}.apk"
cd "$EXPLORER"
zip -q "NetProbe-v${VERSION}.zip" "NetProbe-v${VERSION}.apk"

echo "✅ ALL DONE! NetProbe-v${VERSION}.apk and .zip are in Explorer."
