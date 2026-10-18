#!/bin/bash

# ═══════════════════════════════════════════════════════════════
# NetProbe - Standard Update & Build Script (SOP)
# ═══════════════════════════════════════════════════════════════

VERSION="19.6" # <--- قم بتغيير هذا الرقم في كل تحديث
VERSION_CODE=22 # <--- قم بزيادة هذا الرقم في كل تحديث

echo "⏳ [1/6] Ensuring all source files are in place..."
# (هنا سيتم لصق أكواد التحديث الجديد مستقبلاً)

cat > app/build.gradle << GRADLE_EOF
plugins { id 'com.android.application' }
android {
    namespace 'com.xk.netprobe'
    compileSdk 34
    defaultConfig {
        applicationId "com.xk.netprobe"
        minSdk 24
        targetSdk 34
        versionCode $VERSION_CODE
        versionName "$VERSION"
    }
    buildTypes { release { minifyEnabled false } }
    compileOptions { sourceCompatibility JavaVersion.VERSION_17; targetCompatibility JavaVersion.VERSION_17 }
}
dependencies {
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'androidx.recyclerview:recyclerview:1.3.2'
    implementation 'androidx.cardview:cardview:1.0.0'
    implementation 'com.google.android.material:material:1.11.0'
    implementation 'dev.rikka.shizuku:api:13.1.5'
    implementation 'dev.rikka.shizuku:provider:13.1.5'
}
GRADLE_EOF

cat > app/src/main/res/values/colors.xml << XML_EOF
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="bg">#0D1117</color>
    <color name="surface">#161B22</color>
    <color name="primary">#58A6FF</color>
    <color name="text">#C9D1D9</color>
    <color name="text_secondary">#8B949E</color>
    <color name="error">#F85149</color>
    <color name="success">#3FB950</color>
</resources>
XML_EOF

echo "⏳ [2/6] Setting up Java 17..."
JAVA_17_PATH=$(ls -d /usr/lib/jvm/java-17-openjdk-* 2>/dev/null | head -n 1)
sed -i '/org.gradle.java.home/d' gradle.properties
if [ -n "$JAVA_17_PATH" ]; then echo "org.gradle.java.home=$JAVA_17_PATH" >> gradle.properties; fi

echo "⏳ [3/6] Building APK..."
chmod +x gradlew
sed -i 's/\r$//' gradlew
./gradlew clean assembleDebug

if [ ! -f "app/build/outputs/apk/debug/app-debug.apk" ]; then
    echo "❌ BUILD FAILED. Please check logs."
    exit 1
fi

echo "⏳ [4/6] Adding APK to Explorer (No Deletion)..."
# نسخ الـ APK للجذر (سيتم إضافته بجانب الملفات القديمة)
cp app/build/outputs/apk/debug/app-debug.apk "NetProbe-v${VERSION}.apk"
echo "✅ APK successfully added to Explorer: NetProbe-v${VERSION}.apk"

echo "⏳ [5/6] Pushing to GitHub..."
echo '*.zip' > .gitignore
echo '*.apk' >> .gitignore
echo '!gradle/wrapper/gradle-wrapper.jar' >> .gitignore
echo 'local.properties' >> .gitignore

git add -A
git add -f gradle/wrapper/gradle-wrapper.jar
git commit -m "feat: release v${VERSION}" || true
git push origin main --force

echo "⏳ [6/6] Creating Backup & Publishing Release..."
# إنشاء الـ ZIP ورفعه لـ GitHub Releases (سيبقى أيضاً في المستكشف بجانب الآخرين)
ZIP_NAME="NetProbe-v${VERSION}.zip"
zip -r "$ZIP_NAME" . -x "*.git/*" "build/*" "app/build/*" ".gradle/*" "app/.gradle/*" "*.zip" "*.apk" "local.properties" "*.log" > /dev/null

gh release create "v${VERSION}" "$ZIP_NAME" \
    --title "NetProbe v${VERSION} - Full Backup" \
    --notes "النسخة المحدثة v${VERSION}. تشمل الكود المصدري وملفات البناء." \
    --repo sm2218157-creator/Netprobe --clobber || true

echo "✅ ALL DONE! v${VERSION} is ready."
echo "ملف APK والـ ZIP موجودان الآن في المستكشف."
