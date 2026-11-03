#!/bin/bash
set -e
PROJ="/workspaces/NetProbe-Final"
APP="$PROJ/app"
PKG="$APP/src/main/java/com/xk/netprobe"
RES="$APP/src/main/res"
EXPLORER="/workspaces/Netprobe"
KS="/workspaces/debug.keystore"
SDK="$HOME/android-sdk"
VERSION="21.7"

export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH="$JAVA_HOME/bin:$PATH"
export ANDROID_HOME="$SDK"

echo "=== Building NetProbe v$VERSION (Grid UI + Attack Section) ==="

# 1. تحديث الإصدار
sed -i 's/versionCode 39/versionCode 40/' "$APP/build.gradle" || true
sed -i 's/versionName "21.6"/versionName "21.7"/' "$APP/build.gradle" || true

# 2. إضافة الأيقونات (Wi-Fi و Key)
cat > "$RES/drawable/ic_wifi.xml" << 'EOF'
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24">
    <path android:fillColor="#58A6FF" android:pathData="M12,21l3,-4c0,0 -1.5,-2 -3,-2s-3,2 -3,2l3,4zM12,11c-2.5,0 -4.8,1 -6.5,2.6L7,15.2c1.4,-1.2 3.1,-1.9 5,-1.9s3.6,0.7 5,1.9l1.5,-1.6C16.8,12 14.5,11 12,11zM12,1C7.3,1 3,2.8 0,5.6l1.5,1.6C4.1,4.5 7.8,3 12,3s7.9,1.5 10.5,4.2L24,5.6C21,2.8 16.7,1 12,1z"/>
</vector>
EOF

cat > "$RES/drawable/ic_key.xml" << 'EOF'
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24">
    <path android:fillColor="#DA3633" android:pathData="M12.65,10C11.83,7.67 9.61,6 7,6c-3.31,0 -6,2.69 -6,6s2.69,6 6,6c2.61,0 4.83,-1.67 5.65,-4H17v4h4v-4h2v-4H12.65zM7,14c-1.1,0 -2,-0.9 -2,-2s0.9,-2 2,-2 2,0.9 2,2 -0.9,2 -2,2z"/>
</vector>
EOF

# 3. تحديث قاعدة البيانات بسكربتات WPS
cat > "$PKG/SetupScriptStore.java" << 'EOF'
package com.xk.netprobe;
public class SetupScriptStore {
    public static final String SETUP_SCRIPT = 
        "export DEBIAN_FRONTEND=noninteractive; " +
        "echo 'deb https://packages-cf.termux.dev/apt/termux-main stable main' > $PREFIX/etc/apt/sources.list; " +
        "pkg update -y > /dev/null 2>&1; " +
        "pkg install nmap curl wget -y > /dev/null 2>&1; " +
        "mkdir -p /sdcard/Android/media/com.xk.netprobe/NetProbe; " +
        "echo 'READY_CF' > /sdcard/Android/media/com.xk.netprobe/NetProbe/ready.txt; " +
        "echo '✅ Setup COMPLETE! Return to NetProbe.'";

    public static final String WPS_INSTALL_SCRIPT = 
        "export DEBIAN_FRONTEND=noninteractive; " +
        "echo '[*] Installing WPS Tools...'; " +
        "pkg update -y > /dev/null 2>&1; " +
        "pkg install aircrack-ng reaver iw -y; " +
        "echo '✅ Tools Installed. You can close Termux now.'";

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
}
EOF

# 4. تصميم الشاشة الرئيسية (Grid)
cat > "$RES/layout/activity_main.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android" xmlns:app="http://schemas.android.com/apk/res-auto"
    android:layout_width="match_parent" android:layout_height="match_parent" android:orientation="vertical" android:background="#0D1117" android:padding="16dp">

    <androidx.cardview.widget.CardView android:layout_width="match_parent" android:layout_height="wrap_content" app:cardBackgroundColor="#161B22" app:cardCornerRadius="12dp" app:cardElevation="0dp" android:layout_marginBottom="24dp">
        <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="vertical" android:padding="20dp" android:gravity="center">
            <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="NetProbe" android:textColor="#58A6FF" android:textSize="24sp" android:textStyle="bold"/>
            <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="v21.7" android:textColor="#8B949E" android:textSize="12sp"/>
            <TextView android:id="@+id/tvSetupStatus" android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="Status: Setup needed" android:textColor="#F85149" android:textSize="14sp" android:textStyle="bold" android:layout_marginTop="10dp"/>
            <Button android:id="@+id/btnSetup" android:layout_width="match_parent" android:layout_height="wrap_content" android:text="SETUP TERMUX" android:textColor="#FFFFFF" android:backgroundTint="#1F6FEB" android:layout_marginTop="16dp"/>
        </LinearLayout>
    </androidx.cardview.widget.CardView>

    <TextView android:layout_width="match_parent" android:layout_height="wrap_content" android:text="Tools" android:textColor="#FFFFFF" android:textSize="20sp" android:textStyle="bold" android:layout_marginBottom="12dp"/>

    <GridLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:columnCount="2" android:rowCount="1" android:useDefaultMargins="true">
        
        <!-- كارت الشبكة المحلية -->
        <androidx.cardview.widget.CardView android:id="@+id/cardLocalNetwork" android:layout_width="0dp" android:layout_height="wrap_content" android:layout_columnWeight="1" android:layout_marginEnd="8dp" app:cardBackgroundColor="#161B22" app:cardCornerRadius="12dp" app:cardElevation="0dp">
            <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="vertical" android:padding="20dp" android:gravity="center">
                <ImageView android:layout_width="48dp" android:layout_height="48dp" android:src="@drawable/ic_wifi"/>
                <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="Local network" android:textColor="#C9D1D9" android:textSize="14sp" android:layout_marginTop="12dp"/>
            </LinearLayout>
        </androidx.cardview.widget.CardView>

        <!-- كارت الهجوم -->
        <androidx.cardview.widget.CardView android:id="@+id/cardAttack" android:layout_width="0dp" android:layout_height="wrap_content" android:layout_columnWeight="1" android:layout_marginStart="8dp" app:cardBackgroundColor="#161B22" app:cardCornerRadius="12dp" app:cardElevation="0dp">
            <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="vertical" android:padding="20dp" android:gravity="center">
                <ImageView android:layout_width="48dp" android:layout_height="48dp" android:src="@drawable/ic_key"/>
                <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="Attack" android:textColor="#C9D1D9" android:textSize="14sp" android:layout_marginTop="12dp"/>
            </LinearLayout>
        </androidx.cardview.widget.CardView>
    </GridLayout>
</LinearLayout>
EOF

# 5. تصميم شاشة الهجوم
cat > "$RES/layout/activity_attack.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android" xmlns:app="http://schemas.android.com/apk/res-auto"
    android:layout_width="match_parent" android:layout_height="match_parent" android:orientation="vertical" android:background="#0D1117" android:padding="16dp">

    <androidx.cardview.widget.CardView android:layout_width="match_parent" android:layout_height="wrap_content" app:cardBackgroundColor="#161B22" app:cardCornerRadius="12dp" app:cardElevation="0dp" android:layout_marginBottom="16dp">
        <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="vertical" android:padding="20dp">
            <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="WPS ATTACK" android:textColor="#DA3633" android:textSize="18sp" android:textStyle="bold"/>
            <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="Requires External Adapter (Monitor Mode)" android:textColor="#8B949E" android:textSize="12sp" android:layout_marginTop="4dp"/>
        </LinearLayout>
    </androidx.cardview.widget.CardView>

    <!-- زر التنزيل -->
    <androidx.cardview.widget.CardView android:id="@+id/cardInstallWps" android:layout_width="match_parent" android:layout_height="wrap_content" app:cardBackgroundColor="#1F6FEB" app:cardCornerRadius="8dp" app:cardElevation="0dp" android:layout_marginBottom="12dp">
        <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="horizontal" android:padding="16dp" android:gravity="center_vertical">
            <TextView android:layout_width="0dp" android:layout_height="wrap_content" android:layout_weight="1" android:text="1. Install WPS Tools" android:textColor="#FFFFFF" android:textSize="16sp" android:textStyle="bold"/>
            <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="⬇" android:textColor="#FFFFFF" android:textSize="20sp"/>
        </LinearLayout>
    </androidx.cardview.widget.CardView>

    <!-- زر التشغيل -->
    <androidx.cardview.widget.CardView android:id="@+id/cardRunWps" android:layout_width="match_parent" android:layout_height="wrap_content" app:cardBackgroundColor="#3FB950" app:cardCornerRadius="8dp" app:cardElevation="0dp">
        <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="horizontal" android:padding="16dp" android:gravity="center_vertical">
            <TextView android:layout_width="0dp" android:layout_height="wrap_content" android:layout_weight="1" android:text="2. Start WPS Attack" android:textColor="#000000" android:textSize="16sp" android:textStyle="bold"/>
            <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="▶" android:textColor="#000000" android:textSize="20sp"/>
        </LinearLayout>
    </androidx.cardview.widget.CardView>
</LinearLayout>
EOF

# 6. إنشاء AttackActivity
cat > "$PKG/AttackActivity.java" << 'EOF'
package com.xk.netprobe;
import android.os.Bundle;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;

public class AttackActivity extends AppCompatActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_attack);

        findViewById(R.id.cardInstallWps).setOnClickListener(v -> {
            TermuxBridge.runCommand(this, SetupScriptStore.WPS_INSTALL_SCRIPT, 606);
            TermuxBridge.openTermux(this);
            Toast.makeText(this, "Running installation in Termux...", Toast.LENGTH_SHORT).show();
        });

        findViewById(R.id.cardRunWps).setOnClickListener(v -> {
            TermuxBridge.runCommand(this, SetupScriptStore.WPS_RUN_SCRIPT, 707);
            TermuxBridge.openTermux(this);
            Toast.makeText(this, "Starting WPS attack in Termux...", Toast.LENGTH_SHORT).show();
        });
    }
}
EOF

# 7. تحديث MainActivity لربط كارت الهجوم
cat > "$PKG/MainActivity.java" << 'EOF'
package com.xk.netprobe;
import android.Manifest;
import android.content.*;
import android.content.pm.PackageManager;
import android.content.res.ColorStateList;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;
import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.lang.reflect.Method;
import rikka.shizuku.Shizuku;

public class MainActivity extends AppCompatActivity {
    private TextView tvSetupStatus; private Button btnSetup;
    private static final int LOC_PERM_CODE = 101; private static final int SHIZUKU_REQ_CODE = 202; private static final int BRIDGE_REQ_CODE = 303;
    private final Handler pollHandler = new Handler(Looper.getMainLooper());
    private boolean isShizukuReady = false;

    private final Shizuku.OnRequestPermissionResultListener permListener = (requestCode, grantResult) -> {
        if (requestCode == SHIZUKU_REQ_CODE) {
            if (grantResult == PackageManager.PERMISSION_GRANTED) { isShizukuReady = true; checkNmapViaShizuku(); } 
            else { attemptSilentBridge(); }
        }
    };

    @Override protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        tvSetupStatus = findViewById(R.id.tvSetupStatus); btnSetup = findViewById(R.id.btnSetup);

        btnSetup.setOnClickListener(v -> {
            if (btnSetup.getText().toString().equals("تم تفعيل الإعدادات")) openLocalNetwork();
            else launchSetup();
        });

        findViewById(R.id.cardLocalNetwork).setOnClickListener(v -> openLocalNetwork());
        findViewById(R.id.cardAttack).setOnClickListener(v -> startActivity(new Intent(this, AttackActivity.class)));

        try { Shizuku.addRequestPermissionResultListener(permListener); } catch (Exception ignored) {}
        checkInitialStatus();
    }

    @Override protected void onResume() { super.onResume(); checkInitialStatus(); }
    @Override protected void onDestroy() { super.onDestroy(); try { Shizuku.removeRequestPermissionResultListener(permListener); } catch (Exception ignored) {} }

    private void checkInitialStatus() {
        setButtonState("جاري الفحص...", 0xFFF0B72F, false);
        try {
            if (Shizuku.pingBinder()) {
                if (Shizuku.isPreV11() || Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED) { isShizukuReady = true; checkNmapViaShizuku(); } 
                else { Shizuku.requestPermission(SHIZUKU_REQ_CODE); }
            } else { attemptSilentBridge(); }
        } catch (Exception e) { attemptSilentBridge(); }
    }

    private void checkNmapViaShizuku() {
        new Thread(() -> {
            boolean hasNmap = false;
            try {
                Method method = Shizuku.class.getDeclaredMethod("newProcess", String[].class, String[].class, String.class);
                method.setAccessible(true);
                String cmd = "export PATH=/data/data/com.termux/files/usr/bin:$PATH; command -v nmap";
                Process p = (Process) method.invoke(null, new String[]{"sh", "-c", cmd}, null, null);
                BufferedReader br = new BufferedReader(new InputStreamReader(p.getInputStream()));
                String line = br.readLine();
                if (line != null && line.contains("nmap")) hasNmap = true;
            } catch (Exception ignored) {}
            final boolean finalHasNmap = hasNmap;
            runOnUiThread(() -> { if (finalHasNmap) setButtonState("تم تفعيل الإعدادات", 0xFF3FB950, true); else attemptSilentBridge(); });
        }).start();
    }

    private void attemptSilentBridge() {
        String cmd = "mkdir -p /sdcard/Android/media/com.xk.netprobe/NetProbe && echo 'READY_CF' > /sdcard/Android/media/com.xk.netprobe/NetProbe/ready.txt";
        if (TermuxBridge.runCommand(this, cmd, BRIDGE_REQ_CODE)) pollHandler.postDelayed(this::checkReadyFile, 2000);
        else checkReadyFile(); 
    }

    private void checkReadyFile() {
        if (FileHelper.read(this, "ready.txt").contains("READY")) setButtonState("تم تفعيل الإعدادات", 0xFF3FB950, true);
        else setButtonState("SETUP TERMUX", 0xFFF85149, true);
    }

    private void setButtonState(String text, int color, boolean enabled) {
        btnSetup.setText(text); btnSetup.setBackgroundTintList(ColorStateList.valueOf(color)); btnSetup.setEnabled(enabled);
        if (text.equals("جاري الفحص...")) { tvSetupStatus.setText("Status: Checking..."); tvSetupStatus.setTextColor(0xFFF0B72F); }
        else if (text.equals("تم تفعيل الإعدادات")) { tvSetupStatus.setText("Status: Setup Ready ✓"); tvSetupStatus.setTextColor(0xFF3FB950); }
        else { tvSetupStatus.setText("Status: Setup needed"); tvSetupStatus.setTextColor(0xFFF85149); }
    }

    private void openLocalNetwork() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) 
            ActivityCompat.requestPermissions(this, new String[]{Manifest.permission.ACCESS_FINE_LOCATION}, LOC_PERM_CODE);
        else startActivity(new Intent(this, LocalNetworkActivity.class));
    }

    private void launchSetup() {
        ClipboardManager clipboard = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
        if (clipboard != null) clipboard.setPrimaryClip(ClipData.newPlainText("setup", SetupScriptStore.SETUP_SCRIPT));
        Toast.makeText(this, "Copied! Paste in Termux.", Toast.LENGTH_LONG).show();
        setButtonState("جاري الفحص...", 0xFFF0B72F, false);
        TermuxBridge.openTermux(this);
        pollHandler.postDelayed(this::checkInitialStatus, 10000);
    }

    @Override public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == LOC_PERM_CODE && grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) startActivity(new Intent(this, LocalNetworkActivity.class));
    }
}
EOF

# 8. تحديث المانيفست
sed -i 's|</application>|<activity android:name=".AttackActivity" android:exported="false" />\n    </application>|' "$APP/src/main/AndroidManifest.xml"

# 9. البناء والتوقيع
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

# 10. نقل الملفات للمستكشف
echo "⏳ Moving to Explorer..."
mkdir -p "$EXPLORER"
cp "$APK_TMP" "$EXPLORER/NetProbe-v${VERSION}.apk"
cd "$EXPLORER"
zip -q "NetProbe-v${VERSION}.zip" "NetProbe-v${VERSION}.apk"

echo "✅ ALL DONE! NetProbe-v${VERSION}.apk and .zip are in Explorer."
