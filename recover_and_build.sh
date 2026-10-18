#!/bin/bash

echo "⏳ [1/6] Restoring essential Android files..."

# 1. settings.gradle
cat > settings.gradle << 'EOF'
pluginManagement {
    repositories { google(); mavenCentral(); gradlePluginPortal() }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories { google(); mavenCentral() }
}
rootProject.name = "NetProbe"
include ':app'
EOF

# 2. AndroidManifest.xml
mkdir -p app/src/main
cat > app/src/main/AndroidManifest.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="com.termux.permission.RUN_COMMAND" />
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <queries><package android:name="com.termux" /></queries>
    <application android:label="NetProbe" android:icon="@drawable/ic_launcher" android:theme="@style/AppTheme">
        <activity android:name=".MainActivity" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
        <activity android:name=".LocalNetworkActivity" android:exported="false" />
    </application>
</manifest>
EOF

# 3. app/build.gradle
cat > app/build.gradle << 'EOF'
plugins { id 'com.android.application' }
android {
    namespace 'com.xk.netprobe'
    compileSdk 34
    defaultConfig {
        applicationId "com.xk.netprobe"
        minSdk 24
        targetSdk 34
        versionCode 21
        versionName "19.5"
    }
    buildTypes { release { minifyEnabled false } }
    compileOptions { sourceCompatibility JavaVersion.VERSION_17; targetCompatibility JavaVersion.VERSION_17 }
}
dependencies {
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'androidx.recyclerview:recyclerview:1.3.2'
    implementation 'androidx.cardview:cardview:1.0.0'
    implementation 'com.google.android.material:material:1.11.0'
}
EOF

# 4. Resources (Drawables & Layouts)
mkdir -p app/src/main/res/drawable app/src/main/res/layout app/src/main/res/values

# ic_launcher.xml
cat > app/src/main/res/drawable/ic_launcher.xml << 'EOF'
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
    <path android:fillColor="#0D1117" android:pathData="M0,0h108v108h-108z"/>
    <path android:fillColor="#3FB950" android:pathData="M20,30 L50,30 L50,50 L20,50 Z"/>
    <path android:fillColor="#58A6FF" android:pathData="M20,60 L80,60 L80,80 L20,80 Z"/>
</vector>
EOF

# circle_bg.xml
cat > app/src/main/res/drawable/circle_bg.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="oval">
    <solid android:color="#21262D" />
</shape>
EOF

# styles.xml
cat > app/src/main/res/values/styles.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="AppTheme" parent="Theme.MaterialComponents.NoActionBar">
        <item name="android:windowBackground">#0D1117</item>
        <item name="android:statusBarColor">#161B22</item>
        <item name="colorPrimary">#58A6FF</item>
    </style>
</resources>
EOF

# activity_main.xml
cat > app/src/main/res/layout/activity_main.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:app="http://schemas.android.com/apk/res-auto"
    android:layout_width="match_parent" android:layout_height="match_parent"
    android:orientation="vertical" android:background="#0D1117" android:padding="16dp">
    <androidx.cardview.widget.CardView
        android:layout_width="match_parent" android:layout_height="wrap_content"
        app:cardBackgroundColor="#161B22" app:cardCornerRadius="12dp" app:cardElevation="0dp">
        <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content"
            android:orientation="vertical" android:padding="20dp" android:gravity="center">
            <TextView android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:text="NetProbe" android:textColor="#58A6FF" android:textSize="24sp" android:textStyle="bold"/>
            <TextView android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:text="v19.5" android:textColor="#8B949E" android:textSize="12sp"/>
            <TextView android:id="@+id/tvSetupStatus" android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:text="Status: Setup needed" android:textColor="#F85149" android:textSize="14sp" android:textStyle="bold"
                android:layout_marginTop="10dp"/>
            <TextView android:layout_width="match_parent" android:layout_height="wrap_content"
                android:text="اضغط الزر بالأسفل للذهاب إلى Termux ولصق السكربت لتفعيل الإعدادات."
                android:textColor="#C9D1D9" android:textSize="12sp" android:gravity="center" android:layout_marginTop="8dp" android:layout_marginBottom="16dp"/>
            <Button android:id="@+id/btnSetup" android:layout_width="match_parent" android:layout_height="wrap_content"
                android:text="SETUP TERMUX" android:textColor="#FFFFFF" android:backgroundTint="#1F6FEB"/>
        </LinearLayout>
    </androidx.cardview.widget.CardView>
    <TextView android:layout_width="match_parent" android:layout_height="wrap_content"
        android:text="الأدوات والأقسام" android:textColor="#8B949E" android:layout_marginTop="24dp" android:layout_marginBottom="12dp"/>
    <androidx.cardview.widget.CardView
        android:id="@+id/cardLocalNetwork"
        android:layout_width="match_parent" android:layout_height="wrap_content"
        app:cardBackgroundColor="#161B22" app:cardCornerRadius="12dp" app:cardElevation="0dp">
        <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content"
            android:orientation="horizontal" android:padding="20dp" android:gravity="center_vertical">
            <TextView android:layout_width="0dp" android:layout_height="wrap_content" android:layout_weight="1"
                android:text="الشبكة المحلية\nاكتشاف الأجهزة المتصلة" android:textColor="#C9D1D9" android:textSize="14sp"/>
            <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="→" android:textSize="24sp" android:textColor="#58A6FF"/>
        </LinearLayout>
    </androidx.cardview.widget.CardView>
</LinearLayout>
EOF

# activity_local.xml
cat > app/src/main/res/layout/activity_local.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:app="http://schemas.android.com/apk/res-auto"
    android:layout_width="match_parent" android:layout_height="match_parent"
    android:orientation="vertical" android:background="#0D1117" android:padding="16dp">
    <androidx.cardview.widget.CardView
        android:layout_width="match_parent" android:layout_height="wrap_content"
        android:layout_marginBottom="16dp" app:cardBackgroundColor="#161B22" app:cardCornerRadius="12dp" app:cardElevation="0dp">
        <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content"
            android:orientation="vertical" android:padding="20dp">
            <TextView android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:text="NETWORK INFO" android:textColor="#58A6FF" android:textSize="12sp" android:textStyle="bold"/>
            <TextView android:id="@+id/tvSsid" android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:text="Wi-Fi Name" android:textColor="#C9D1D9" android:textSize="18sp" android:layout_marginTop="8dp"/>
            <TextView android:id="@+id/tvMyIp" android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:text="My IP: 192.168.x.x" android:textColor="#F85149" android:textSize="14sp" android:layout_marginTop="4dp" android:textStyle="bold"/>
            <TextView android:id="@+id/tvSubnet" android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:text="Subnet: 192.168.1.0/24" android:textColor="#8B949E" android:textSize="12sp" android:layout_marginTop="4dp"/>
            <TextView android:id="@+id/tvStatus" android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:text="Scanning the network..." android:textColor="#3FB950" android:textSize="12sp" android:layout_marginTop="8dp"/>
        </LinearLayout>
    </androidx.cardview.widget.CardView>
    <androidx.recyclerview.widget.RecyclerView
        android:id="@+id/recyclerDevices"
        android:layout_width="match_parent" android:layout_height="match_parent"/>
</LinearLayout>
EOF

# item_device.xml
cat > app/src/main/res/layout/item_device.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<androidx.cardview.widget.CardView xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:app="http://schemas.android.com/apk/res-auto"
    android:layout_width="match_parent" android:layout_height="wrap_content"
    android:layout_marginBottom="8dp" app:cardBackgroundColor="#161B22" app:cardCornerRadius="8dp" app:cardElevation="0dp">
    <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content"
        android:orientation="horizontal" android:padding="16dp" android:gravity="center_vertical">
        <TextView android:id="@+id/tvPortCount" android:layout_width="36dp" android:layout_height="36dp"
            android:background="@drawable/circle_bg" android:gravity="center" android:text="?"
            android:textColor="#58A6FF" android:textStyle="bold"/>
        <LinearLayout android:layout_width="0dp" android:layout_height="wrap_content" android:layout_weight="1"
            android:orientation="vertical" android:paddingStart="16dp">
            <TextView android:id="@+id/tvIp" android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:text="192.168.1.1" android:textColor="#C9D1D9" android:textSize="16sp" android:textStyle="bold"/>
            <TextView android:id="@+id/tvVendor" android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:text="Device" android:textColor="#8B949E" android:textSize="12sp"/>
        </LinearLayout>
    </LinearLayout>
</androidx.cardview.widget.CardView>
EOF

echo "⏳ [2/6] Setting up Local SDK environment..."
export ANDROID_HOME="$HOME/android-sdk"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

if ! command -v java >/dev/null 2>&1; then
    sudo apt update -qq && sudo apt install -y openjdk-17-jdk -qq
fi
echo "sdk.dir=$HOME/android-sdk" > local.properties

echo "⏳ [3/6] Building APK Locally (Logging output)..."
chmod +x gradlew
sed -i 's/\r$//' gradlew

# بناء المشروع وحفظ السجل في حال الفشل
./gradlew clean assembleDebug --stacktrace > build_output.log 2>&1

if [ $? -eq 0 ]; then
    echo "✅ BUILD SUCCESSFUL! APK is ready."
    ls -lh app/build/outputs/apk/debug/app-debug.apk
else
    echo "❌ BUILD FAILED. Please check 'build_output.log'"
    tail -n 20 build_output.log
fi

echo "⏳ [4/6] Committing new files..."
git add -A
git commit -m "fix: restore missing Android boilerplate for local build" || true

echo "⏳ [5/6] Pushing to GitHub..."
git push origin main --force

echo "⏳ [6/6] Creating ZIP Backup..."
ZIP_NAME="NetProbe_v19.5_Source.zip"
zip -r "$ZIP_NAME" . -x "*.git/*" "build/*" "app/build/*" ".gradle/*" "app/.gradle/*" "*.zip" "*.apk" "local.properties" "build_output.log" > /dev/null

if command -v gh >/dev/null 2>&1; then
    gh release create v19.5 "$ZIP_NAME" \
        --title "NetProbe v19.5 - Full Backup" \
        --notes "نسخة كاملة من الكود المصدري مع ملفات البناء." \
        --repo sm2218157-creator/Netprobe --clobber || true
fi

echo "✅ ALL DONE!"
