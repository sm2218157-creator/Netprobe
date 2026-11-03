#!/bin/bash
set -e
PROJ="/workspaces/NetProbe-Final"
APP="$PROJ/app"
PKG="$APP/src/main/java/com/xk/netprobe"
EXPLORER="/workspaces/Netprobe"
KS="/workspaces/debug.keystore"
SDK="$HOME/android-sdk"
VERSION="20.4"

export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH="$JAVA_HOME/bin:$PATH"
export ANDROID_HOME="$SDK"

echo "=== Fixing Shizuku Error & Rebuilding v$VERSION ==="

# تعديل دالة getMacFromShizuku فقط لاستخدام Runtime.exec بدلاً من Shizuku.newProcess
python3 - << 'PYEOF'
import re
file_path = "/workspaces/NetProbe-Final/app/src/main/java/com/xk/netprobe/LocalNetworkActivity.java"
with open(file_path, 'r') as f:
    content = f.read()

# استبدال السطر الذي يحتوي على الخطأ
old_line = 'Process p = Shizuku.newProcess(new String[]{"sh", "-c", "ip neigh"}, null, null);'
new_line = 'Process p = Runtime.getRuntime().exec("ip neigh");'

if old_line in content:
    content = content.replace(old_line, new_line)
    print("✅ Fixed Shizuku.newProcess error.")
else:
    print("⚠️ Could not find the exact line, but proceeding...")

with open(file_path, 'w') as f:
    f.write(content)
PYEOF

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
