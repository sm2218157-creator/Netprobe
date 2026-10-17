#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "═══ NetProbe — Auto Build Fixer ═══"

# 1. إنشاء ملف GitHub Actions
echo "[1/4] Creating GitHub Actions workflow..."
mkdir -p .github/workflows
cat > .github/workflows/build.yml << 'EOF'
name: Build APK
on:
  push:
    branches: [ main ]
  workflow_dispatch:
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
      - name: Setup Gradle
        uses: gradle/actions/setup-gradle@v3
      - name: Grant execute permission
        run: chmod +x gradlew
      - name: Build Debug APK
        run: ./gradlew assembleDebug
      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: NetProbe-v20.0-APK
          path: app/build/outputs/apk/debug/app-debug.apk
EOF

# 2. إصلاح .gitignore
echo "[2/4] Fixing .gitignore (allowing wrapper.jar)..."
# حذف قاعدة منع الـ jar لمنع مشاكل البناء
sed -i '/^\*.jar$/d' .gitignore 2>/dev/null || true
# إضافة استثناء للتأمين
echo "!gradle/wrapper/gradle-wrapper.jar" >> .gitignore

# 3. إضافة الملفات بالقوة (Force) لضمان رفعها
echo "[3/4] Staging files..."
git add -f gradle/wrapper/gradle-wrapper.jar gradlew
git add .github/workflows/build.yml .gitignore

# 4. الرفع لـ GitHub
echo "[4/4] Committing and pushing..."
if git diff --cached --quiet; then
    echo "لا توجد تغييرات جديدة للرفع. (Everything is up to date)"
else
    git commit -m "ci: fix build (add wrapper.jar + workflow)"
    git push origin main
fi

echo ""
echo "════════════════════════════════════════════════"
echo " ✓ اكتمل الإعداد!"
echo " اذهب إلى هذا الرابط لمشاهدة البناء:"
echo " https://github.com/sm2218157-creator/Netprobe/actions"
echo "════════════════════════════════════════════════"
