#!/bin/bash
set -e
PROJ="/workspaces/NetProbe-Final"
APP="$PROJ/app"
RES="$APP/src/main/res"
EXPLORER="/workspaces/Netprobe"
KS="/workspaces/debug.keystore"
SDK="$HOME/android-sdk"
VERSION="21.2"

export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH="$JAVA_HOME/bin:$PATH"
export ANDROID_HOME="$SDK"

echo "=== Building NetProbe v$VERSION (Fixing Accordion Click) ==="

# إصلاح ملف التصميم فقط (نقل خاصية النقر للحاوية الرئيسية)
cat > "$RES/layout/item_device.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android" xmlns:app="http://schemas.android.com/apk/res-auto"
    android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="vertical" 
    android:layout_marginBottom="8dp"
    android:clickable="true" android:focusable="true" android:foreground="?attr/selectableItemBackground">

    <!-- الكارت الأساسي للجهاز -->
    <androidx.cardview.widget.CardView
        android:layout_width="match_parent" android:layout_height="wrap_content"
        app:cardBackgroundColor="#161B22" app:cardCornerRadius="8dp" app:cardElevation="0dp">
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
            <TextView android:id="@+id/tvArrow" android:layout_width="wrap_content" android:layout_height="wrap_content"
                android:text="▼" android:textColor="#58A6FF" android:textSize="16sp"/>
        </LinearLayout>
    </androidx.cardview.widget.CardView>

    <!-- القائمة المنسدلة (مخفية افتراضياً) -->
    <androidx.cardview.widget.CardView
        android:id="@+id/cardExpandable"
        android:layout_width="match_parent" android:layout_height="wrap_content"
        android:layout_marginTop="4dp" android:visibility="gone"
        app:cardBackgroundColor="#0D1117" app:cardCornerRadius="8dp" app:cardElevation="0dp"
        app:strokeColor="#30363D" app:strokeWidth="1dp">
        
        <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="vertical" android:padding="12dp">
            <TextView android:id="@+id/tvPortsList" android:layout_width="match_parent" android:layout_height="wrap_content"
                android:text="Scanning ports..." android:textColor="#3FB950" android:textSize="14sp" android:lineSpacingExtra="4dp"/>
        </LinearLayout>
    </androidx.cardview.widget.CardView>
</LinearLayout>
EOF

# تحديث الإصدار
sed -i 's/versionCode 34/versionCode 35/' "$APP/build.gradle" || true
sed -i 's/versionName "21.1"/versionName "21.2"/' "$APP/build.gradle" || true
sed -i 's/v21.1/v21.2/' "$RES/layout/activity_main.xml" || true

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
