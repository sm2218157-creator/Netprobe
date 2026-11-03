#!/bin/bash
set -e
PROJ="/workspaces/NetProbe-Final"
APP="$PROJ/app"
PKG="$APP/src/main/java/com/xk/netprobe"
RES="$APP/src/main/res"
EXPLORER="/workspaces/Netprobe"
KS="/workspaces/debug.keystore"
SDK="$HOME/android-sdk"
VERSION="22.8"

export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH="$JAVA_HOME/bin:$PATH"
export ANDROID_HOME="$SDK"

echo "=== Building NetProbe v$VERSION (Add termux-setup-storage) ==="

# 1. تحديث الإصدار
sed -i 's/versionCode 50/versionCode 51/' "$APP/build.gradle" || true
sed -i 's/versionName "22.7"/versionName "22.8"/' "$APP/build.gradle" || true
sed -i 's/v22.7/v22.8/' "$RES/layout/activity_main.xml" || true

# 2. تحديث SetupScriptStore (إضافة termux-setup-storage للسكربت الأولي)
cat > "$PKG/SetupScriptStore.java" << 'EOF'
package com.xk.netprobe;
public class SetupScriptStore {
    public static final String SETUP_SCRIPT = 
        "export DEBIAN_FRONTEND=noninteractive; " +
        "termux-setup-storage; " +
        "sleep 2; " +
        "echo 'deb https://mirrors.tuna.tsinghua.edu.cn/termux/apt/termux-main stable main' > $PREFIX/etc/apt/sources.list; " +
        "pkg update -y > /dev/null 2>&1; " +
        "pkg install nmap curl wget -y > /dev/null 2>&1; " +
        "mkdir -p /sdcard/Android/media/com.xk.netprobe/NetProbe; " +
        "echo 'READY_CF' > /sdcard/Android/media/com.xk.netprobe/NetProbe/ready.txt; " +
        "echo '✅ Setup COMPLETE! Return to NetProbe.'";

    public static final String WPS_INSTALL_SCRIPT = 
        "export DEBIAN_FRONTEND=noninteractive; " +
        "set -e; " +
        "echo '[*] Updating package lists...'; " +
        "pkg update -y; " +
        "pkg upgrade -y -o Dpkg::Options::=--force-confold; " +
        "echo '[*] Adding root-repo...'; " +
        "pkg install root-repo -y; " +
        "echo '[*] Refreshing lists after root-repo...'; " +
        "pkg update -y; " +
        "echo '[*] Installing WPS tools...'; " +
        "pkg install aircrack-ng reaver iw -y; " +
        "command -v aircrack-ng >/dev/null || { echo '[-] aircrack-ng missing'; exit 1; }; " +
        "command -v reaver >/dev/null || { echo '[-] reaver missing'; exit 1; }; " +
        "command -v iw >/dev/null || { echo '[-] iw missing'; exit 1; }; " +
        "echo '✅ All WPS tools installed successfully. You can close Termux.'";

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

    public static final String NETHUNTER_SCRIPT = 
        "export DEBIAN_FRONTEND=noninteractive; " +
        "pkg install wget curl -y; " +
        "echo '[*] Downloading NetHunter Installer...'; " +
        "wget -O install-nethunter-termux https://offs.ec/2MceZWr; " +
        "chmod +x install-nethunter-termux; " +
        "echo '[*] Auto-selecting Minimal (2)...'; " +
        "echo '2' | ./install-nethunter-termux; " +
        "echo '[*] Fixing DNS and Updating packages...'; " +
        "nethunter -r -c \"echo 'nameserver 8.8.8.8' > /etc/resolv.conf && apt update\"; " +
        "echo '✅ NetHunter Installed & Network Fixed.'";
}
EOF

# 3. البناء والتوقيع
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

# 4. نقل الملفات للمستكشف
echo "⏳ Moving to Explorer..."
mkdir -p "$EXPLORER"
cp "$APK_TMP" "$EXPLORER/NetProbe-v${VERSION}.apk"
cd "$EXPLORER"
zip -q "NetProbe-v${VERSION}.zip" "NetProbe-v${VERSION}.apk"

echo "✅ ALL DONE! NetProbe-v${VERSION}.apk and .zip are in Explorer."
