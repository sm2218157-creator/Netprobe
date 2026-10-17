#!/bin/bash
set -e

echo "⏳ 1. Creating workflow file..."
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
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'

      - name: Setup Gradle
        uses: gradle/actions/setup-gradle@v3

      - name: Fix gradlew permissions and line endings
        run: |
          sed -i 's/\r$//' gradlew
          chmod +x gradlew
          
      - name: Generate wrapper if missing
        run: |
          if [ ! -f "gradlew" ] || [ ! -f "gradle/wrapper/gradle-wrapper.jar" ]; then
            echo "Wrapper missing, generating..."
            gradle wrapper
            sed -i 's/\r$//' gradlew
            chmod +x gradlew
          fi

      - name: Build Debug APK
        run: ./gradlew assembleDebug --stacktrace

      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: NetProbe-v20.0-APK
          path: app/build/outputs/apk/debug/app-debug.apk
          if-no-files-found: warn
EOF

echo "⏳ 2. Fixing .gitignore..."
touch .gitignore
sed -i '/^\*.jar$/d' .gitignore || true
grep -q "gradle-wrapper.jar" .gitignore || echo "!gradle/wrapper/gradle-wrapper.jar" >> .gitignore

echo "⏳ 3. Committing and pushing..."
git add -f gradle/wrapper/gradle-wrapper.jar gradlew
git add .github/workflows/build.yml .gitignore

git commit -m "fix: bulletproof CI/CD build" || echo "Nothing new to commit"
git push origin main

echo ""
echo "✅ ALL DONE! Check: https://github.com/sm2218157-creator/Netprobe/actions"
