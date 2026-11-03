#!/bin/bash
set -e
PROJ="/workspaces/NetProbe-Final"
APP="$PROJ/app"
PKG="$APP/src/main/java/com/xk/netprobe"
RES="$APP/src/main/res"
EXPLORER="/workspaces/Netprobe"
KS="/workspaces/debug.keystore"
SDK="$HOME/android-sdk"
VERSION="21.9"

export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH="$JAVA_HOME/bin:$PATH"
export ANDROID_HOME="$SDK"

echo "=== Building NetProbe v$VERSION (Force Setup Check & DB Verification) ==="

# 1. تحديث الإصدار
sed -i 's/versionCode 41/versionCode 42/' "$APP/build.gradle" || true
sed -i 's/versionName "21.8"/versionName "21.9"/' "$APP/build.gradle" || true
sed -i 's/v21.8/v21.9/' "$RES/layout/activity_main.xml" || true

# 2. إعادة كتابة قاعدة البيانات (تأكيد السكربتات)
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

    public static final String WPS_INSTALL_SCRIPT = 
        "export DEBIAN_FRONTEND=noninteractive; " +
        "echo '[*] Installing WPS Tools...'; " +
        "pkg update -y > /dev/null 2>&1; " +
        "pkg install aircrack-ng reaver iw -y; " +
        "echo '✅ Tools Installed. You can close Termux now.'";

    public static final String WPS_RUN_SCRIPT = 
        "export DEBIAN_FRONTEND=noninteractive; " +
        "echo '[*] Detecting adapter...'; " +
        "IFACE=$(iw dev | awk '$1==\"Interface\"{print $2}' | grep -v wlan0 | head -n 1); " +
        "if [ -z \"$IFACE\" ]; then echo '[-] No external adapter found!'; exit 1; fi; " +
        "echo \"[+] Found: $IFACE\"; " +
        "echo '[*] Starting Monitor Mode...'; " +
        "airmon-ng check kill > /dev/null 2>&1; " +
        "airmon-ng start $IFACE > /dev/null 2>&1; " +
        "MON_IFACE=$(iw dev | awk '$1==\"Interface\"{print $2}' | grep mon | head -n 1); " +
        "if [ -z \"$MON_IFACE\" ]; then echo '[-] Monitor mode failed.'; exit 1; fi; " +
        "echo '[*] Scanning for WPS...'; " +
        "wash -i $MON_IFACE";
}
EOF

# 3. تحديث AttackActivity لإجبار التهيئة
cat > "$PKG/AttackActivity.java" << 'EOF'
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

        // التحقق من إتمام التهيئة (وجود ملف ready.txt)
        if (!FileHelper.exists(this, "ready.txt")) {
            Toast.makeText(this, "يرجى إكمال التهيئة (Setup) أولاً من الشاشة الرئيسية!", Toast.LENGTH_LONG).show();
            finish(); // إغلاق القسم
            return;
        }

        findViewById(R.id.cardInstallWps).setOnClickListener(v -> {
            boolean sent = TermuxBridge.runCommand(this, SetupScriptStore.WPS_INSTALL_SCRIPT, 606);
            if (sent) {
                Toast.makeText(this, "Executing in Termux...", Toast.LENGTH_SHORT).show();
                new Handler(Looper.getMainLooper()).postDelayed(() -> TermuxBridge.openTermux(this), 500);
            } else {
                copyToClipboard(SetupScriptStore.WPS_INSTALL_SCRIPT);
            }
        });

        findViewById(R.id.cardRunWps).setOnClickListener(v -> {
            boolean sent = TermuxBridge.runCommand(this, SetupScriptStore.WPS_RUN_SCRIPT, 707);
            if (sent) {
                Toast.makeText(this, "Executing in Termux...", Toast.LENGTH_SHORT).show();
                new Handler(Looper.getMainLooper()).postDelayed(() -> TermuxBridge.openTermux(this), 500);
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
EOF

# 4. البناء والتوقيع
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

# 5. نقل الملفات للمستكشف
echo "⏳ Moving to Explorer..."
mkdir -p "$EXPLORER"
cp "$APK_TMP" "$EXPLORER/NetProbe-v${VERSION}.apk"
cd "$EXPLORER"
zip -q "NetProbe-v${VERSION}.zip" "NetProbe-v${VERSION}.apk"

echo "✅ ALL DONE! NetProbe-v${VERSION}.apk and .zip are in Explorer."
