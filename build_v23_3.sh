#!/bin/bash
set -e
PROJ="/workspaces/NetProbe-Final"
APP="$PROJ/app"
PKG="$APP/src/main/java/com/xk/netprobe"
RES="$APP/src/main/res"
EXPLORER="/workspaces/Netprobe"
KS="/workspaces/debug.keystore"
SDK="$HOME/android-sdk"
VERSION="23.3"

export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH="$JAVA_HOME/bin:$PATH"
export ANDROID_HOME="$SDK"

echo "=== Building NetProbe v$VERSION (Side-by-Side Prominent Buttons) ==="

# 1. تحديث الإصدار
sed -i 's/versionCode 55/versionCode 56/' "$APP/build.gradle" || true
sed -i 's/versionName "23.2"/versionName "23.3"/' "$APP/build.gradle" || true
sed -i 's/v23.2/v23.3/' "$RES/layout/activity_main.xml" || true

# 2. تحديث الواجهة (الزرين بجانب بعضهما)
cat > "$RES/layout/activity_main.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<ScrollView xmlns:android="http://schemas.android.com/apk/res/android" xmlns:app="http://schemas.android.com/apk/res-auto"
    android:layout_width="match_parent" android:layout_height="match_parent" android:background="#0D1117" android:fillViewport="true">
    <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="vertical" android:padding="16dp">

        <androidx.cardview.widget.CardView android:layout_width="match_parent" android:layout_height="wrap_content" app:cardBackgroundColor="#161B22" app:cardCornerRadius="12dp" app:cardElevation="0dp" android:layout_marginBottom="16dp">
            <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="vertical" android:padding="20dp" android:gravity="center">
                <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="NetProbe" android:textColor="#58A6FF" android:textSize="24sp" android:textStyle="bold"/>
                <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="v23.3" android:textColor="#8B949E" android:textSize="12sp"/>
                <TextView android:id="@+id/tvSetupStatus" android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="Status: Setup needed" android:textColor="#F85149" android:textSize="14sp" android:textStyle="bold" android:layout_marginTop="10dp"/>
                <Button android:id="@+id/btnSetup" android:layout_width="match_parent" android:layout_height="wrap_content" android:text="SETUP TERMUX" android:textColor="#FFFFFF" android:backgroundTint="#1F6FEB" android:layout_marginTop="16dp"/>
            </LinearLayout>
        </androidx.cardview.widget.CardView>

        <!-- كارت NetHunter مع الزرين بجانب بعض -->
        <androidx.cardview.widget.CardView android:layout_width="match_parent" android:layout_height="wrap_content" app:cardBackgroundColor="#161B22" app:cardCornerRadius="12dp" app:cardElevation="0dp" android:layout_marginBottom="8dp">
            <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="vertical" android:padding="20dp" android:gravity="center">
                <TextView android:layout_width="match_parent" android:layout_height="wrap_content" android:text="NetHunter Rootless\n(~2GB Download) - Auto Minimal" android:textColor="#A371F7" android:textSize="16sp" android:textStyle="bold" android:gravity="center" android:padding="10dp"/>
                
                <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="horizontal" android:layout_marginTop="12dp">
                    <Button android:id="@+id/btnDownloadNethunter" android:layout_width="0dp" android:layout_height="wrap_content" android:layout_weight="1" android:layout_marginEnd="4dp"
                        android:text="تنزيل NetHunter" android:textColor="#FFFFFF" android:backgroundTint="#A371F7"/>
                    
                    <Button android:id="@+id/btnCheckNethunter" android:layout_width="0dp" android:layout_height="wrap_content" android:layout_weight="1" android:layout_marginStart="4dp"
                        android:text="تحقق من NetHunter" android:textColor="#FFFFFF" android:backgroundTint="#F0B72F"/>
                </LinearLayout>
            </LinearLayout>
        </androidx.cardview.widget.CardView>

        <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="vertical" android:padding="16dp" android:layout_marginBottom="16dp" android:background="#161B22">
            <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="للدخول إلى بيئة NetHunter:" android:textColor="#C9D1D9" android:textSize="14sp"/>
            <TextView android:id="@+id/tvCodeEnter" android:layout_width="match_parent" android:layout_height="wrap_content" android:text="nethunter" android:textColor="#3FB950" android:textSize="16sp" android:fontFamily="monospace" android:textStyle="bold" android:padding="8dp" android:background="#0D1117" android:layout_marginTop="4dp" android:layout_marginBottom="12dp" android:clickable="true" android:focusable="true"/>
            
            <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="للخروج من بيئة NetHunter:" android:textColor="#C9D1D9" android:textSize="14sp"/>
            <TextView android:id="@+id/tvCodeExit" android:layout_width="match_parent" android:layout_height="wrap_content" android:text="exit" android:textColor="#F85149" android:textSize="16sp" android:fontFamily="monospace" android:textStyle="bold" android:padding="8dp" android:background="#0D1117" android:layout_marginTop="4dp" android:clickable="true" android:focusable="true"/>
            <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="اضغط على الكود لنسخه" android:textColor="#8B949E" android:textSize="11sp" android:layout_marginTop="4dp"/>
        </LinearLayout>

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

# 3. تحديث MainActivity (منطق الألوان الجديد)
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
    private TextView tvSetupStatus; 
    private Button btnSetup;
    private Button btnDownloadNethunter;
    private Button btnCheckNethunter;
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
        tvSetupStatus = findViewById(R.id.tvSetupStatus); 
        btnSetup = findViewById(R.id.btnSetup);
        btnDownloadNethunter = findViewById(R.id.btnDownloadNethunter);
        btnCheckNethunter = findViewById(R.id.btnCheckNethunter);

        btnSetup.setOnClickListener(v -> {
            if (btnSetup.getText().toString().equals("تم تفعيل الإعدادات")) openLocalNetwork();
            else launchSetup();
        });

        findViewById(R.id.cardLocalNetwork).setOnClickListener(v -> openLocalNetwork());
        findViewById(R.id.cardAttack).setOnClickListener(v -> startActivity(new Intent(this, AttackActivity.class)));
        
        btnDownloadNethunter.setOnClickListener(v -> {
            ClipboardManager clipboard = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
            if (clipboard != null) clipboard.setPrimaryClip(ClipData.newPlainText("nethunter", SetupScriptStore.NETHUNTER_SCRIPT));
            Toast.makeText(this, "Copied! Paste in Termux to install NetHunter.", Toast.LENGTH_LONG).show();
            TermuxBridge.openTermux(this);
        });

        btnCheckNethunter.setOnClickListener(v -> {
            ClipboardManager clipboard = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
            if (clipboard != null) clipboard.setPrimaryClip(ClipData.newPlainText("check", SetupScriptStore.NETHUNTER_CHECK_SCRIPT));
            Toast.makeText(this, "Copied check script. Paste in Termux.", Toast.LENGTH_SHORT).show();
            TermuxBridge.openTermux(this);
        });

        findViewById(R.id.tvCodeEnter).setOnClickListener(v -> copyToClipboard("nethunter"));
        findViewById(R.id.tvCodeExit).setOnClickListener(v -> copyToClipboard("exit"));

        try { Shizuku.addRequestPermissionResultListener(permListener); } catch (Exception ignored) {}
        checkInitialStatus();
    }
    
    private void copyToClipboard(String text) {
        ClipboardManager clipboard = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
        if (clipboard != null) {
            clipboard.setPrimaryClip(ClipData.newPlainText("code", text));
            Toast.makeText(this, "Copied: " + text, Toast.LENGTH_SHORT).show();
        }
    }

    @Override protected void onResume() { 
        super.onResume(); 
        checkInitialStatus(); 
        checkNethunterStatus();
    }
    
    private void checkNethunterStatus() {
        String status = FileHelper.read(this, "nethunter_status.txt").trim();
        if (status.equals("READY")) {
            btnCheckNethunter.setText("مثبت وجاهز");
            btnCheckNethunter.setBackgroundTintList(ColorStateList.valueOf(0xFF3FB950)); // Green
            btnCheckNethunter.setEnabled(false);
            
            btnDownloadNethunter.setEnabled(false);
            btnDownloadNethunter.setAlpha(0.5f); // Baha
        } else if (status.equals("MISSING")) {
            btnCheckNethunter.setText("غير مثبت");
            btnCheckNethunter.setBackgroundTintList(ColorStateList.valueOf(0xFFF85149)); // Red
            btnCheckNethunter.setEnabled(true);
            
            btnDownloadNethunter.setEnabled(true);
            btnDownloadNethunter.setAlpha(1.0f); // Bariz
        } else {
            btnCheckNethunter.setText("تحقق من NetHunter");
            btnCheckNethunter.setBackgroundTintList(ColorStateList.valueOf(0xFFF0B72F)); // Orange
            btnCheckNethunter.setEnabled(true);
            
            btnDownloadNethunter.setEnabled(true);
            btnDownloadNethunter.setAlpha(1.0f); // Bariz
        }
    }

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

# 4. البناء والتوقيع
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

# 5. نقل الملفات للمستكشف
echo "⏳ Moving to Explorer..."
mkdir -p "$EXPLORER"
cp "$APK_TMP" "$EXPLORER/NetProbe-v${VERSION}.apk"
cd "$EXPLORER"
zip -q "NetProbe-v${VERSION}.zip" "NetProbe-v${VERSION}.apk"

echo "✅ ALL DONE! NetProbe-v${VERSION}.apk and .zip are in Explorer."
