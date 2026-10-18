#!/bin/bash

echo "⏳ 1. Finding Java 17..."
JAVA_17_PATH=$(ls -d /usr/lib/jvm/java-17-openjdk-* 2>/dev/null | head -n 1)

if [ -z "$JAVA_17_PATH" ]; then
    echo "Java 17 not found. Installing..."
    sudo apt-get update -qq
    sudo apt-get install -y openjdk-17-jdk -qq
    JAVA_17_PATH=$(ls -d /usr/lib/jvm/java-17-openjdk-* 2>/dev/null | head -n 1)
fi

echo "✅ Using Java at: $JAVA_17_PATH"

echo "⏳ 2. Updating gradle.properties..."
sed -i '/org.gradle.java.home/d' gradle.properties
echo "org.gradle.java.home=$JAVA_17_PATH" >> gradle.properties

echo "⏳ 3. Building APK..."
chmod +x gradlew
sed -i 's/\r$//' gradlew
./gradlew clean assembleDebug

echo "⏳ 4. Checking result..."
if [ -f "app/build/outputs/apk/debug/app-debug.apk" ]; then
    echo "✅ BUILD SUCCESSFUL! APK is at app/build/outputs/apk/debug/app-debug.apk"
else
    echo "❌ BUILD FAILED. Please check the logs above."
fi
