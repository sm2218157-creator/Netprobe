#!/bin/bash
set -e
PROJ="/workspaces/NetProbe-Final"
APP="$PROJ/app"
PKG="$APP/src/main/java/com/xk/netprobe"
RES="$APP/src/main/res"
EXPLORER="/workspaces/Netprobe"
KS="/workspaces/debug.keystore"
SDK="$HOME/android-sdk"
VERSION="22.5"

export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH="$JAVA_HOME/bin:$PATH"
export ANDROID_HOME="$SDK"

echo "=== Building NetProbe v$VERSION (NetHunter Rootless Button) ==="

# 1. تحديث الإصدار
sed -i 's/versionCode 47/versionCode 48/' "$APP/build.gradle" || true
sed -i 's/versionName "22.4"/versionName "22.5"/' "$APP/build.gradle" || true
sed -i 's/v22.4/v22.5/' "$RES/layout/activity_main.xml" || true

# 2. إضافة سكربت NetHunter إلى قاعدة البيانات
python3 - << 'PYEOF'
file_path = "/workspaces/NetProbe-Final/app/src/main/java/com/xk/netprobe/SetupScriptStore.java"
with open(file_path, 'r') as f:
    content = f.read()

new_script = '''
    public static final String NETHUNTER_SCRIPT = 
        "export DEBIAN_FRONTEND=noninteractive; " +
        "pkg install wget curl -y; " +
        "echo '[*] Downloading NetHunter Rootless Installer...'; " +
        "wget -O install-nethunter-termux https://offs.ec/2MceZWr; " +
        "chmod +x install-nethunter-termux; " +
        "echo '[*] Starting NetHunter Installation (This takes time)...'; " +
        "./install-nethunter-termux";
}'''

if "NETHUNTER_SCRIPT" not in content:
    content = content.replace("}", new_script, 1) # Replace the last closing brace
    print("✅ Added NETHUNTER_SCRIPT to SetupScriptStore.")
else:
    print("⚠️ NETHUNTER_SCRIPT already exists, skipping.")

with open(file_path, 'w') as f:
    f.write(content)
PYEOF

# 3. تحديث الواجهة (إضافة كارت NetHunter)
cat > "$RES/layout/activity_main.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<ScrollView xmlns:android="http://schemas.android.com/apk/res/android" xmlns:app="http://schemas.android.com/apk/res-auto"
    android:layout_width="match_parent" android:layout_height="match_parent" android:background="#0D1117" android:fillViewport="true">
    <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="vertical" android:padding="16dp">

        <androidx.cardview.widget.CardView android:layout_width="match_parent" android:layout_height="wrap_content" app:cardBackgroundColor="#161B22" app:cardCornerRadius="12dp" app:cardElevation="0dp" android:layout_marginBottom="16dp">
            <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="vertical" android:padding="20dp" android:gravity="center">
                <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="NetProbe" android:textColor="#58A6FF" android:textSize="24sp" android:textStyle="bold"/>
                <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="v22.5" android:textColor="#8B949E" android:textSize="12sp"/>
                <TextView android:id="@+id/tvSetupStatus" android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="Status: Setup needed" android:textColor="#F85149" android:textSize="14sp" android:textStyle="bold" android:layout_marginTop="10dp"/>
                <Button android:id="@+id/btnSetup" android:layout_width="match_parent" android:layout_height="wrap_content" android:text="SETUP TERMUX" android:textColor="#FFFFFF" android:backgroundTint="#1F6FEB" android:layout_marginTop="16dp"/>
            </LinearLayout>
        </androidx.cardview.widget.CardView>

        <!-- كارت NetHunter الجديد -->
        <androidx.cardview.widget.CardView android:id="@+id/cardNethunter" android:layout_width="match_parent" android:layout_height="wrap_content" app:cardBackgroundColor="#161B22" app:cardCornerRadius="12dp" app:cardElevation="0dp" android:layout_marginBottom="24dp">
            <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="vertical" android:padding="20dp" android:gravity="center">
                <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="Install NetHunter Rootless" android:textColor="#A371F7" android:textSize="16sp" android:textStyle="bold"/>
                <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="(~2GB Download)" android:textColor="#8B949E" android:textSize="12sp" android:layout_marginTop="4dp"/>
            </LinearLayout>
        </androidx.cardview.widget.CardView>

        <TextView android:layout_width="match_parent" android:layout_height="wrap_content" android:text="Tools" android:textColor="#FFFFFF" android:textSize="20sp" android:textStyle="bold" android:layout_marginBottom="12dp"/>

        <GridLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:columnCount="2" android:rowCount="1" android:useDefaultMargins="true">
            
            <androidx.cardview.widget.CardView android:id="@+id/cardLocalNetwork" android:layout_width="0dp" android:layout_height="wrap_content" android:layout_columnWeight="1" android:layout_marginEnd="8dp" app:cardBackgroundColor="#161B22" app:cardCornerRadius="12dp" app:cardElevation="0dp">
                <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="vertical" android:padding="20dp" android:gravity="center">
                    <ImageView android:layout_width="48dp" android:layout_height="48dp" android:src="@drawable/ic_wifi"/>
                    <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="Local network" android:textColor="#C9D1D9" android:textSize="14sp" android:layout_marginTop="12dp"/>
                </LinearLayout>
            </androidx.cardview.widget.CardView>

            <androidx.cardview.widget.CardView android:id="@+id/cardAttack" android:layout_width="0dp" android:layout_height="wrap_content" android:layout_columnWeight="1" android:layout_marginStart="8dp" app:cardBackgroundColor="#161B22" app:cardCornerRadius="12dp" app:cardElevation="0dp">
                <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="vertical" android:padding="20dp" android:gravity="center">
                    <ImageView android:layout_width="48dp" android:layout_height="48dp" android:src="@drawable/ic_key"/>
                    <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="Attack" android:textColor="#C9D1D9" android:textSize="14sp" android:layout_marginTop="12dp"/>
                </LinearLayout>
            </androidx.cardview.widget.CardView>
        </GridLayout>
    </LinearLayout>
</ScrollView>
EOF

# 4. تحديث MainActivity لإضافة حدث النقر على NetHunter
python3 - << 'PYEOF'
file_path = "/workspaces/NetProbe-Final/app/src/main/java/com/xk/netprobe/MainActivity.java"
with open(file_path, 'r') as f:
    content = f.read()

old_code = 'findViewById(R.id.cardLocalNetwork).setOnClickListener(v -> openLocalNetwork());'
new_code = '''findViewById(R.id.cardLocalNetwork).setOnClickListener(v -> openLocalNetwork());
        
        findViewById(R.id.cardNethunter).setOnClickListener(v -> {
            ClipboardManager clipboard = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
            if (clipboard != null) clipboard.setPrimaryClip(ClipData.newPlainText("nethunter", SetupScriptStore.NETHUNTER_SCRIPT));
            Toast.makeText(this, "Copied! Paste in Termux to install NetHunter.", Toast.LENGTH_LONG).show();
            TermuxBridge.openTermux(this);
        });'''

if 'cardNethunter' not in content:
    content = content.replace(old_code, new_code)
    print("✅ Added NetHunter click listener.")
else:
    print("⚠️ NetHunter listener already exists.")

with open(file_path, 'w') as f:
    f.write(content)
PYEOF

# 5. البناء والتوقيع
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

# 6. نقل الملفات للمستكشف
echo "⏳ Moving to Explorer..."
mkdir -p "$EXPLORER"
cp "$APK_TMP" "$EXPLORER/NetProbe-v${VERSION}.apk"
cd "$EXPLORER"
zip -q "NetProbe-v${VERSION}.zip" "NetProbe-v${VERSION}.apk"

echo "✅ ALL DONE! NetProbe-v${VERSION}.apk and .zip are in Explorer."
