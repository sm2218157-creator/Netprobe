#!/bin/bash
set -e

PROJ="/workspaces/NetProbe-Final"
EXPLORER="/workspaces/Netprobe"
VERSION="19.9"

echo "⏳ [1/5] Fixing settings.gradle..."
cat > "$PROJ/settings.gradle" << 'EOF'
pluginManagement {
    repositories {
        maven { url 'https://maven.aliyun.com/repository/gradle-plugin' }
        maven { url 'https://maven.aliyun.com/repository/google' }
        maven { url 'https://maven.aliyun.com/repository/public' }
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        maven { url 'https://maven.aliyun.com/repository/google' }
        maven { url 'https://maven.aliyun.com/repository/public' }
        google()
        mavenCentral()
    }
}
rootProject.name = "NetProbe"
include ':app'
EOF

echo "⏳ [2/5] Fixing app/build.gradle (Adding Shizuku)..."
cat > "$PROJ/app/build.gradle" << 'EOF'
plugins { id 'com.android.application' }

android {
    namespace 'com.xk.netprobe'
    compileSdk 34
    defaultConfig {
        applicationId "com.xk.netprobe"
        minSdk 24
        targetSdk 34
        versionCode 22
        versionName "19.9"
    }
    buildTypes { release { minifyEnabled false } }
    compileOptions { 
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17 
    }
}

dependencies {
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'androidx.recyclerview:recyclerview:1.3.2'
    implementation 'androidx.cardview:cardview:1.0.0'
    implementation 'com.google.android.material:material:1.11.0'
    implementation 'dev.rikka.shizuku:api:13.1.5'
    implementation 'dev.rikka.shizuku:provider:13.1.5'
}
EOF

echo "⏳ [3/5] Building APK (This may take a minute)..."
cd "$PROJ"
./gradlew clean assembleDebug

APK_TMP="$PROJ/app/build/outputs/apk/debug/app-debug.apk"
if [ ! -f "$APK_TMP" ]; then
    echo "❌ BUILD FAILED. Please check logs above."
    exit 1
fi

echo "⏳ [4/5] Copying APK to Explorer..."
mkdir -p "$EXPLORER"
cp "$APK_TMP" "$EXPLORER/NetProbe-v${VERSION}.apk"

echo "⏳ [5/5] Creating ZIP Backup..."
cd "$EXPLORER"
zip -q "NetProbe-v${VERSION}.zip" "NetProbe-v${VERSION}.apk"

echo "✅ ALL DONE! NetProbe-v${VERSION}.apk and .zip are in Explorer."
