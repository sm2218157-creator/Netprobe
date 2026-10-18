#!/bin/bash
set -e

PROJ="/workspaces/NetProbe-Final"
EXPLORER="/workspaces/Netprobe"
VERSION="19.9"

echo "⏳ [1/4] Finding Java 17 and forcing Gradle to use it..."
# البحث عن مسار Java 17
JAVA_PATH=$(ls -d /usr/lib/jvm/java-17-openjdk-* 2>/dev/null | head -n 1)

if [ -z "$JAVA_PATH" ]; then
    echo "Java 17 not found. Installing..."
    sudo apt update -qq && sudo apt install -y openjdk-17-jdk -qq
    JAVA_PATH=$(ls -d /usr/lib/jvm/java-17-openjdk-* 2>/dev/null | head -n 1)
fi

# مسح أي إعدادات قديمة وإضافة مسار Java 17 الصريح
sed -i '/org.gradle.java.home/d' "$PROJ/gradle.properties"
echo "org.gradle.java.home=$JAVA_PATH" >> "$PROJ/gradle.properties"
echo "✅ Forced Java at: $JAVA_PATH"

echo "⏳ [2/4] Stopping Gradle Daemons and Building..."
export JAVA_HOME=$JAVA_PATH
export PATH="$JAVA_HOME/bin:$PATH"
cd "$PROJ"

# إيقاف أي daemon قديم عالق على Java 25
./gradlew --stop > /dev/null 2>&1 || true

# البناء
./gradlew clean assembleDebug

APK_TMP="$PROJ/app/build/outputs/apk/debug/app-debug.apk"
if [ ! -f "$APK_TMP" ]; then
    echo "❌ BUILD FAILED. Please check logs above."
    exit 1
fi

echo "⏳ [3/4] Copying APK to Explorer..."
mkdir -p "$EXPLORER"
cp "$APK_TMP" "$EXPLORER/NetProbe-v${VERSION}.apk"

echo "⏳ [4/4] Creating ZIP Backup..."
cd "$EXPLORER"
zip -q "NetProbe-v${VERSION}.zip" "NetProbe-v${VERSION}.apk"

echo "✅ ALL DONE! NetProbe-v${VERSION}.apk and .zip are in Explorer."
