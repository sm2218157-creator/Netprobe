#!/bin/bash
set -e
PROJ="/workspaces/NetProbe-Final"
APP="$PROJ/app"
PKG="$APP/src/main/java/com/xk/netprobe"
RES="$APP/src/main/res"
EXPLORER="/workspaces/Netprobe"
KS="/workspaces/debug.keystore"
SDK="$HOME/android-sdk"
VERSION="21.8"

export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH="$JAVA_HOME/bin:$PATH"
export ANDROID_HOME="$SDK"

echo "=== Building NetProbe v$VERSION (Fixing Termux Execution) ==="

# 1. تحديث الإصدار
sed -i 's/versionCode 40/versionCode 41/' "$APP/build.gradle" || true
sed -i 's/versionName "21.7"/versionName "21.8"/' "$APP/build.gradle" || true
sed -i 's/v21.7/v21.8/' "$RES/layout/activity_main.xml" || true

# 2. إصلاح TermuxBridge لضمان التنفيذ المباشر
cat > "$PKG/TermuxBridge.java" << 'EOF'
package com.xk.netprobe;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
public class TermuxBridge {
    public static final String ACTION_RESULT = "com.xk.netprobe.TERMUX_RESULT";
    public static boolean isTermuxInstalled(Context ctx) {
        try { ctx.getPackageManager().getPackageInfo("com.termux", 0); return true; } catch (Exception e) { return false; }
    }
    public static boolean runCommand(Context ctx, String cmd, int requestCode) {
        if (!isTermuxInstalled(ctx)) return false;
        Intent intent = new Intent();
        intent.setClassName("com.termux", "com.termux.app.RunCommandService");
        intent.setAction("com.termux.RUN_COMMAND");
        intent.putExtra("com.termux.RUN_COMMAND_PATH", "/data/data/com.termux/files/usr/bin/bash");
        intent.putExtra("com.termux.RUN_COMMAND_ARGUMENTS", new String[]{"-c", cmd});
        intent.putExtra("com.termux.RUN_COMMAND_WORKDIR", "/data/data/com.termux/files/home");
        // false لجعل Termux يفتح الشاشة ليرى المستخدم النتيجة
        intent.putExtra("com.termux.RUN_COMMAND_BACKGROUND", false); 
        // 0 لفتح الجلسة (Session) وعرض المخرجات
        intent.putExtra("com.termux.RUN_COMMAND_SESSION_ACTION", "0"); 
        intent.putExtra("com.termux.RUN_COMMAND_COMMAND_LABEL", "NetProbe Tool");

        Intent resultIntent = new Intent(ACTION_RESULT).setPackage(ctx.getPackageName());
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= 31) flags |= PendingIntent.FLAG_MUTABLE;
        PendingIntent pi = PendingIntent.getBroadcast(ctx, requestCode, resultIntent, flags);
        intent.putExtra("com.termux.RUN_COMMAND_PENDING_INTENT", pi);

        try { 
            ctx.startService(intent); 
            return true; 
        } catch (Exception e) { 
            return false; 
        }
    }
    public static void openTermux(Context ctx) {
        Intent i = new Intent(); i.setClassName("com.termux", "com.termux.app.TermuxActivity"); i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        try { ctx.startActivity(i); } catch (Exception ignored) {}
    }
}
EOF

# 3. تحديث AttackActivity لإضافة تأخير بسيط لضمان التنفيذ
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

        findViewById(R.id.cardInstallWps).setOnClickListener(v -> {
            boolean sent = TermuxBridge.runCommand(this, SetupScriptStore.WPS_INSTALL_SCRIPT, 606);
            if (sent) {
                Toast.makeText(this, "Executing in Termux...", Toast.LENGTH_SHORT).show();
                // تأخير بسيط لضمان استقبال Termux للأمر قبل فتح الشاشة
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
