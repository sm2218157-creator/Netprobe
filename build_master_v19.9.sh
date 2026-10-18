#!/bin/bash
set -e
PROJ="/workspaces/NetProbe-Final"
APP="$PROJ/app"
PKG="$APP/src/main/java/com/xk/netprobe"
RES="$APP/src/main/res"
EXPLORER="/workspaces/Netprobe"
KS="/workspaces/debug.keystore"
SDK="$HOME/android-sdk"
VERSION="19.9"

export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH="$JAVA_HOME/bin:$PATH"
export ANDROID_HOME="$SDK"

echo "=== Building NetProbe v$VERSION (Master Script) ==="

# 0. تجهيز المجلدات وإعدادات Gradle
mkdir -p "$PKG" "$RES/layout" "$RES/values" "$RES/drawable"
echo "org.gradle.jvmargs=-Xmx2g -Dfile.encoding=UTF-8" > "$PROJ/gradle.properties"
echo "android.useAndroidX=true" >> "$PROJ/gradle.properties"
echo "android.nonTransitiveRClass=true" >> "$PROJ/gradle.properties"
echo "org.gradle.java.home=$JAVA_HOME" >> "$PROJ/gradle.properties"

cat > "$PROJ/settings.gradle" << 'EOF'
pluginManagement {
    repositories { maven { url 'https://maven.aliyun.com/repository/gradle-plugin' }; maven { url 'https://maven.aliyun.com/repository/google' }; maven { url 'https://maven.aliyun.com/repository/public' }; google(); mavenCentral(); gradlePluginPortal() }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories { maven { url 'https://maven.aliyun.com/repository/google' }; maven { url 'https://maven.aliyun.com/repository/public' }; google(); mavenCentral() }
}
rootProject.name = "NetProbe"
include ':app'
EOF

cat > "$APP/build.gradle" << 'EOF'
plugins { id 'com.android.application' }
android {
    namespace 'com.xk.netprobe'
    compileSdk 34
    defaultConfig { applicationId "com.xk.netprobe"; minSdk 24; targetSdk 34; versionCode 22; versionName "19.9" }
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
EOF

# 1. تحديث AndroidManifest.xml
cat > "$APP/src/main/AndroidManifest.xml" << 'EOF'
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
        <activity android:name=".DeviceDetailsActivity" android:exported="false" />
        <provider android:name="rikka.shizuku.ShizukuProvider" android:authorities="${applicationId}.shizuku" android:multiprocess="false" android:enabled="true" android:exported="true" android:permission="android.permission.INTERACT_ACROSS_USERS_FULL" />
    </application>
</manifest>
EOF

# 2. ملفات الموارد (XML)
cat > "$RES/values/colors.xml" << 'EOF'
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
EOF

cat > "$RES/values/styles.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="AppTheme" parent="Theme.MaterialComponents.NoActionBar">
        <item name="android:windowBackground">#0D1117</item>
        <item name="android:statusBarColor">#161B22</item>
        <item name="colorPrimary">#58A6FF</item>
    </style>
</resources>
EOF

cat > "$RES/drawable/ic_launcher.xml" << 'EOF'
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
    <path android:fillColor="#0D1117" android:pathData="M0,0h108v108h-108z"/>
    <path android:fillColor="#3FB950" android:pathData="M20,30 L50,30 L50,50 L20,50 Z"/>
    <path android:fillColor="#58A6FF" android:pathData="M20,60 L80,60 L80,80 L20,80 Z"/>
</vector>
EOF

cat > "$RES/drawable/circle_bg.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="oval">
    <solid android:color="#21262D" />
</shape>
EOF

cat > "$RES/layout/activity_main.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android" xmlns:app="http://schemas.android.com/apk/res-auto"
    android:layout_width="match_parent" android:layout_height="match_parent" android:orientation="vertical" android:background="#0D1117" android:padding="16dp">
    <androidx.cardview.widget.CardView android:layout_width="match_parent" android:layout_height="wrap_content" app:cardBackgroundColor="#161B22" app:cardCornerRadius="12dp" app:cardElevation="0dp">
        <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="vertical" android:padding="20dp" android:gravity="center">
            <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="NetProbe" android:textColor="#58A6FF" android:textSize="24sp" android:textStyle="bold"/>
            <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="v19.9" android:textColor="#8B949E" android:textSize="12sp"/>
            <TextView android:id="@+id/tvSetupStatus" android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="Status: Setup needed" android:textColor="#F85149" android:textSize="14sp" android:textStyle="bold" android:layout_marginTop="10dp"/>
            <TextView android:layout_width="match_parent" android:layout_height="wrap_content" android:text="اضغط الزر بالأسفل للذهاب إلى Termux ولصق السكربت لتفعيل الإعدادات." android:textColor="#C9D1D9" android:textSize="12sp" android:gravity="center" android:layout_marginTop="8dp" android:layout_marginBottom="16dp"/>
            <Button android:id="@+id/btnSetup" android:layout_width="match_parent" android:layout_height="wrap_content" android:text="SETUP TERMUX" android:textColor="#FFFFFF" android:backgroundTint="#1F6FEB"/>
        </LinearLayout>
    </androidx.cardview.widget.CardView>
    <TextView android:layout_width="match_parent" android:layout_height="wrap_content" android:text="الأدوات والأقسام" android:textColor="#8B949E" android:layout_marginTop="24dp" android:layout_marginBottom="12dp"/>
    <androidx.cardview.widget.CardView android:id="@+id/cardLocalNetwork" android:layout_width="match_parent" android:layout_height="wrap_content" app:cardBackgroundColor="#161B22" app:cardCornerRadius="12dp" app:cardElevation="0dp">
        <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="horizontal" android:padding="20dp" android:gravity="center_vertical">
            <TextView android:layout_width="0dp" android:layout_height="wrap_content" android:layout_weight="1" android:text="الشبكة المحلية\nاكتشاف الأجهزة المتصلة" android:textColor="#C9D1D9" android:textSize="14sp"/>
            <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="→" android:textSize="24sp" android:textColor="#58A6FF"/>
        </LinearLayout>
    </androidx.cardview.widget.CardView>
</LinearLayout>
EOF

cat > "$RES/layout/activity_local.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android" xmlns:app="http://schemas.android.com/apk/res-auto"
    android:layout_width="match_parent" android:layout_height="match_parent" android:orientation="vertical" android:background="#0D1117" android:padding="16dp">
    <androidx.cardview.widget.CardView android:layout_width="match_parent" android:layout_height="wrap_content" android:layout_marginBottom="16dp" app:cardBackgroundColor="#161B22" app:cardCornerRadius="12dp" app:cardElevation="0dp">
        <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="vertical" android:padding="20dp">
            <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="horizontal" android:gravity="center_vertical">
                <LinearLayout android:layout_width="0dp" android:layout_height="wrap_content" android:layout_weight="1" android:orientation="vertical">
                    <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="NETWORK INFO" android:textColor="#58A6FF" android:textSize="12sp" android:textStyle="bold"/>
                    <TextView android:id="@+id/tvSsid" android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="Wi-Fi Name" android:textColor="#C9D1D9" android:textSize="18sp" android:layout_marginTop="8dp"/>
                </LinearLayout>
                <ImageButton android:id="@+id/btnRescan" android:layout_width="48dp" android:layout_height="48dp" android:background="?attr/selectableItemBackgroundBorderless" android:src="@android:drawable/ic_popup_sync" android:tint="#58A6FF"/>
            </LinearLayout>
            <TextView android:id="@+id/tvMyIp" android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="My IP: 192.168.x.x" android:textColor="#F85149" android:textSize="14sp" android:layout_marginTop="4dp" android:textStyle="bold"/>
            <TextView android:id="@+id/tvSubnet" android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="Subnet: 192.168.1.0/24" android:textColor="#8B949E" android:textSize="12sp" android:layout_marginTop="4dp"/>
            <ProgressBar android:id="@+id/progressBar" android:layout_width="match_parent" android:layout_height="wrap_content" android:layout_marginTop="8dp" style="?android:attr/progressBarStyleHorizontal" android:indeterminate="true" android:indeterminateTint="#58A6FF" android:visibility="gone"/>
            <TextView android:id="@+id/tvStatus" android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="Ready to scan." android:textColor="#3FB950" android:textSize="12sp" android:layout_marginTop="8dp"/>
        </LinearLayout>
    </androidx.cardview.widget.CardView>
    <androidx.recyclerview.widget.RecyclerView android:id="@+id/recyclerDevices" android:layout_width="match_parent" android:layout_height="match_parent"/>
</LinearLayout>
EOF

cat > "$RES/layout/item_device.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<androidx.cardview.widget.CardView xmlns:android="http://schemas.android.com/apk/res/android" xmlns:app="http://schemas.android.com/apk/res-auto"
    android:layout_width="match_parent" android:layout_height="wrap_content" android:layout_marginBottom="8dp" android:clickable="true" android:focusable="true" android:foreground="?attr/selectableItemBackground" app:cardBackgroundColor="#161B22" app:cardCornerRadius="8dp" app:cardElevation="0dp">
    <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="horizontal" android:padding="16dp" android:gravity="center_vertical">
        <TextView android:id="@+id/tvPortCount" android:layout_width="36dp" android:layout_height="36dp" android:background="@drawable/circle_bg" android:gravity="center" android:text="?" android:textColor="#58A6FF" android:textStyle="bold"/>
        <LinearLayout android:layout_width="0dp" android:layout_height="wrap_content" android:layout_weight="1" android:orientation="vertical" android:paddingStart="16dp">
            <TextView android:id="@+id/tvIp" android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="192.168.1.1" android:textColor="#C9D1D9" android:textSize="16sp" android:textStyle="bold"/>
            <TextView android:id="@+id/tvVendor" android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="Device" android:textColor="#8B949E" android:textSize="12sp"/>
        </LinearLayout>
        <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="→" android:textColor="#58A6FF" android:textSize="20sp"/>
    </LinearLayout>
</androidx.cardview.widget.CardView>
EOF

cat > "$RES/layout/activity_device_details.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android" xmlns:app="http://schemas.android.com/apk/res-auto"
    android:layout_width="match_parent" android:layout_height="match_parent" android:orientation="vertical" android:background="#0D1117" android:padding="16dp">
    <androidx.cardview.widget.CardView android:layout_width="match_parent" android:layout_height="wrap_content" android:layout_marginBottom="16dp" app:cardBackgroundColor="#1C2128" app:cardCornerRadius="16dp" app:cardElevation="0dp">
        <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="vertical" android:padding="24dp" android:gravity="center">
            <ImageView android:layout_width="64dp" android:layout_height="64dp" android:src="@android:drawable/ic_dialog_dialer" android:tint="#A371F7"/>
            <TextView android:id="@+id/tvDetailsIp" android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="192.168.1.1" android:textColor="#FFFFFF" android:textSize="24sp" android:textStyle="bold" android:layout_marginTop="8dp"/>
            <TextView android:id="@+id/tvDetailsMac" android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="MAC: 00:00:00:00:00:00" android:textColor="#8B949E" android:textSize="14sp" android:layout_marginTop="4dp"/>
        </LinearLayout>
    </androidx.cardview.widget.CardView>
    <TextView android:layout_width="match_parent" android:layout_height="wrap_content" android:text="OPEN PORTS" android:textColor="#58A6FF" android:textSize="12sp" android:textStyle="bold" android:layout_marginBottom="8dp"/>
    <androidx.recyclerview.widget.RecyclerView android:id="@+id/recyclerPorts" android:layout_width="match_parent" android:layout_height="0dp" android:layout_weight="1"/>
    <TextView android:id="@+id/tvStatus" android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="Ready for Deep Scan." android:textColor="#3FB950" android:layout_gravity="center_horizontal" android:layout_marginTop="8dp"/>
    <Button android:id="@+id/btnDeepScan" android:layout_width="match_parent" android:layout_height="wrap_content" android:text="Deep Scan (Service Versions)" android:textColor="#FFFFFF" android:backgroundTint="#DA3633" android:layout_marginTop="8dp"/>
</LinearLayout>
EOF

cat > "$RES/layout/item_port.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="horizontal" android:padding="12dp" android:background="#161B22" android:layout_marginBottom="4dp" android:gravity="center_vertical">
    <TextView android:id="@+id/tvPortNumber" android:layout_width="60dp" android:layout_height="wrap_content" android:text="80" android:textColor="#3FB950" android:textStyle="bold" android:textSize="16sp"/>
    <TextView android:id="@+id/tvPortService" android:layout_width="0dp" android:layout_height="wrap_content" android:layout_weight="1" android:text="http" android:textColor="#C9D1D9" android:textSize="14sp"/>
</LinearLayout>
EOF

# 3. ملفات الجافا (إنشاء كل ملف من الصفر لضمان عدم وجود أخطاء)
cat > "$PKG/FileHelper.java" << 'EOF'
package com.xk.netprobe;
import android.content.Context;
import java.io.*;
public class FileHelper {
    public static File dir(Context ctx) {
        File[] dirs = ctx.getExternalMediaDirs();
        File base = (dirs != null && dirs.length > 0) ? dirs[0] : ctx.getFilesDir();
        File dir = new File(base, "NetProbe"); if (!dir.exists()) dir.mkdirs(); return dir;
    }
    public static String pathOf(Context ctx, String name) { return new File(dir(ctx), name).getAbsolutePath(); }
    public static boolean exists(Context ctx, String name) { return new File(pathOf(ctx, name)).exists(); }
    public static boolean delete(Context ctx, String name) { return new File(pathOf(ctx, name)).delete(); }
    public static String read(Context ctx, String name) {
        File f = new File(pathOf(ctx, name)); if (!f.exists()) return "";
        StringBuilder sb = new StringBuilder();
        try (BufferedReader br = new BufferedReader(new FileReader(f))) { String l; while ((l = br.readLine()) != null) sb.append(l).append("\n"); } catch (Exception ignored) {}
        return sb.toString();
    }
    public static void write(Context ctx, String name, String data) {
        File target = new File(pathOf(ctx, name)); File tmp = new File(target.getAbsolutePath() + ".tmp");
        try (FileWriter fw = new FileWriter(tmp)) { fw.write(data); } catch (Exception ignored) {}
        tmp.renameTo(target);
    }
}
EOF

cat > "$PKG/TermuxBridge.java" << 'EOF'
package com.xk.netprobe;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
import android.util.Log;
public class TermuxBridge {
    public static final String ACTION_RESULT = "com.xk.netprobe.TERMUX_RESULT";
    public static final String EXTRA_STDOUT = "stdout";
    public static final String EXTRA_STDERR = "stderr";
    public static final String EXTRA_EXIT   = "exit";
    public static boolean isTermuxInstalled(Context ctx) {
        try { ctx.getPackageManager().getPackageInfo("com.termux", 0); return true; } catch (Exception e) { return false; }
    }
    public static boolean runCommand(Context ctx, String cmd, int requestCode) {
        if (!isTermuxInstalled(ctx)) return false;
        Intent intent = new Intent();
        intent.setClassName("com.termux", "com.termux.app.RunCommandService");
        intent.setAction("com.termux.RUN_COMMAND");
        intent.putExtra("com.termux.RUN_COMMAND_PATH", "/data/data/com.termux/files/usr/bin/bash");
        intent.putExtra("com.termux.RUN_COMMAND_ARGUMENTS", new String[]{"-c", cmd});
        intent.putExtra("com.termux.RUN_COMMAND_WORKDIR", "/data/data/com.termux/files/home");
        intent.putExtra("com.termux.RUN_COMMAND_BACKGROUND", false);
        Intent resultIntent = new Intent(ACTION_RESULT).setPackage(ctx.getPackageName());
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= 31) flags |= PendingIntent.FLAG_MUTABLE;
        intent.putExtra("com.termux.RUN_COMMAND_PENDING_INTENT", PendingIntent.getBroadcast(ctx, requestCode, resultIntent, flags));
        try { ctx.startService(intent); return true; } catch (Exception e) { return false; }
    }
    public static void openTermux(Context ctx) {
        Intent i = new Intent(); i.setClassName("com.termux", "com.termux.app.TermuxActivity"); i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        try { ctx.startActivity(i); } catch (Exception ignored) {}
    }
}
EOF

cat > "$PKG/NetInfo.java" << 'EOF'
package com.xk.netprobe;
import android.content.Context;
import android.net.wifi.WifiManager;
import java.net.*;
import java.util.*;
public class NetInfo {
    public static String getMyIp(Context ctx) {
        try {
            Enumeration<NetworkInterface> interfaces = NetworkInterface.getNetworkInterfaces();
            while (interfaces.hasMoreElements()) {
                NetworkInterface ni = interfaces.nextElement();
                if (!ni.isUp() || ni.isLoopback()) continue;
                String name = ni.getName().toLowerCase();
                if (name.startsWith("tun") || name.startsWith("ppp") || name.startsWith("rmnet")) continue;
                if (name.startsWith("wlan") || name.startsWith("ap") || name.startsWith("eth")) {
                    Enumeration<InetAddress> addresses = ni.getInetAddresses();
                    while (addresses.hasMoreElements()) {
                        InetAddress addr = addresses.nextElement();
                        if (addr instanceof Inet4Address && !addr.isLoopbackAddress()) return addr.getHostAddress();
                    }
                }
            }
        } catch (Exception ignored) {}
        try {
            WifiManager wifiManager = (WifiManager) ctx.getApplicationContext().getSystemService(Context.WIFI_SERVICE);
            if (wifiManager != null && wifiManager.isWifiEnabled()) {
                int ipAddress = wifiManager.getConnectionInfo().getIpAddress();
                if (ipAddress != 0) return String.format(Locale.US, "%d.%d.%d.%d", (ipAddress & 0xff), (ipAddress >> 8 & 0xff), (ipAddress >> 16 & 0xff), (ipAddress >> 24 & 0xff));
            }
        } catch (Exception ignored) {}
        return null;
    }
    public static String getSubnet(Context ctx) {
        String ip = getMyIp(ctx);
        if (ip != null && ip.lastIndexOf('.') > 0) return ip.substring(0, ip.lastIndexOf('.')) + ".0/24";
        return null;
    }
}
EOF

cat > "$PKG/NetworkDiscovery.java" << 'EOF'
package com.xk.netprobe;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
public class NetworkDiscovery {
    public interface Callback { void onDeviceFound(String ip); void onFinished(int total); }
    public static void scan(String subnet, Callback callback) {
        if (subnet == null || !subnet.contains(".")) { callback.onFinished(0); return; }
        ExecutorService executor = Executors.newFixedThreadPool(20);
        String base = subnet.substring(0, subnet.lastIndexOf('.'));
        final int[] count = {0};
        for (int i = 1; i <= 254; i++) {
            final String ip = base + "." + i;
            executor.execute(() -> {
                try { if (java.net.InetAddress.getByName(ip).isReachable(800)) { synchronized (count) { count[0]++; } callback.onDeviceFound(ip); } } catch (Exception ignored) {}
            });
        }
        executor.shutdown();
        new Thread(() -> { while (!executor.isTerminated()) { try { Thread.sleep(100); } catch (Exception ignored) {} } callback.onFinished(count[0]); }).start();
    }
}
EOF

cat > "$PKG/DeviceAdapter.java" << 'EOF'
package com.xk.netprobe;
import android.content.Intent;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;
import java.util.ArrayList;
import java.util.List;
public class DeviceAdapter extends RecyclerView.Adapter<DeviceAdapter.VH> {
    static class Device { String ip; String mac; int ports; String rawPorts; Device(String ip, String mac, int ports, String raw) { this.ip = ip; this.mac = mac; this.ports = ports; this.rawPorts = raw; } }
    private final List<Device> devices = new ArrayList<>();
    public void addDevice(String ip) {
        for (Device d : devices) if (d.ip.equals(ip)) return;
        devices.add(new Device(ip, "Unknown", -1, ""));
        notifyItemInserted(devices.size() - 1);
    }
    public void updateDevice(String ip, int ports, String mac, String raw) {
        for (int i = 0; i < devices.size(); i++) {
            if (devices.get(i).ip.equals(ip)) {
                devices.get(i).ports = ports; devices.get(i).mac = mac; devices.get(i).rawPorts = raw;
                notifyItemChanged(i); break;
            }
        }
    }
    public String getIpAt(int index) { return devices.get(index).ip; }
    public void clear() { devices.clear(); notifyDataSetChanged(); }
    @NonNull @Override public VH onCreateViewHolder(@NonNull ViewGroup p, int t) { return new VH(LayoutInflater.from(p.getContext()).inflate(R.layout.item_device, p, false)); }
    @Override public void onBindViewHolder(@NonNull VH h, int i) {
        Device d = devices.get(i);
        h.tvIp.setText(d.ip); h.tvPortCount.setText(d.ports == -1 ? "?" : String.valueOf(d.ports));
        h.tvVendor.setText(d.mac.equals("Unknown") ? "Device" : d.mac);
        h.itemView.setOnClickListener(v -> {
            Intent intent = new Intent(v.getContext(), DeviceDetailsActivity.class);
            intent.putExtra("ip", d.ip); intent.putExtra("mac", d.mac); intent.putExtra("rawPorts", d.rawPorts);
            v.getContext().startActivity(intent);
        });
    }
    @Override public int getItemCount() { return devices.size(); }
    static class VH extends RecyclerView.ViewHolder {
        TextView tvIp, tvPortCount, tvVendor;
        VH(@NonNull View v) { super(v); tvIp = v.findViewById(R.id.tvIp); tvPortCount = v.findViewById(R.id.tvPortCount); tvVendor = v.findViewById(R.id.tvVendor); }
    }
}
EOF

cat > "$PKG/PortAdapter.java" << 'EOF'
package com.xk.netprobe;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;
import java.util.ArrayList;
import java.util.List;
public class PortAdapter extends RecyclerView.Adapter<PortAdapter.VH> {
    private final List<String[]> ports = new ArrayList<>();
    public void setData(String rawData) {
        ports.clear();
        if (rawData != null) {
            for (String line : rawData.split("\n")) {
                if (line.contains("/tcp") && line.contains("open")) {
                    String[] parts = line.trim().split("\\s+");
                    if (parts.length >= 3) {
                        String port = parts[0].split("/")[0];
                        String service = parts.length >= 4 ? parts[2] + " " + parts[3] : parts[2];
                        ports.add(new String[]{port, service});
                    }
                }
            }
        }
        notifyDataSetChanged();
    }
    @NonNull @Override public VH onCreateViewHolder(@NonNull ViewGroup p, int t) { return new VH(LayoutInflater.from(p.getContext()).inflate(R.layout.item_port, p, false)); }
    @Override public void onBindViewHolder(@NonNull VH h, int i) { h.tvNumber.setText(ports.get(i)[0]); h.tvService.setText(ports.get(i)[1]); }
    @Override public int getItemCount() { return ports.size(); }
    static class VH extends RecyclerView.ViewHolder {
        TextView tvNumber, tvService;
        VH(@NonNull View v) { super(v); tvNumber = v.findViewById(R.id.tvPortNumber); tvService = v.findViewById(R.id.tvPortService); }
    }
}
EOF

cat > "$PKG/DeviceDetailsActivity.java" << 'EOF'
package com.xk.netprobe;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
public class DeviceDetailsActivity extends AppCompatActivity {
    private String ip, mac, rawPorts;
    private PortAdapter adapter;
    private TextView tvStatus;
    private Button btnDeepScan;
    @Override protected void onCreate(Bundle b) {
        super.onCreate(b);
        setContentView(R.layout.activity_device_details);
        ip = getIntent().getStringExtra("ip"); mac = getIntent().getStringExtra("mac"); rawPorts = getIntent().getStringExtra("rawPorts");
        TextView tvIp = findViewById(R.id.tvDetailsIp); TextView tvMac = findViewById(R.id.tvDetailsMac);
        tvStatus = findViewById(R.id.tvStatus); btnDeepScan = findViewById(R.id.btnDeepScan);
        tvIp.setText(ip); tvMac.setText("MAC: " + mac);
        RecyclerView recycler = findViewById(R.id.recyclerPorts);
        recycler.setLayoutManager(new LinearLayoutManager(this));
        adapter = new PortAdapter(); recycler.setAdapter(adapter); adapter.setData(rawPorts);
        btnDeepScan.setOnClickListener(v -> performDeepScan());
    }
    private void performDeepScan() {
        tvStatus.setText("Running Deep Scan (Nmap -sV)..."); btnDeepScan.setEnabled(false);
        String outPath = FileHelper.pathOf(this, "deep_ports.txt"); FileHelper.write(this, "deep_ports.txt", "");
        String cmd = "export PATH=/data/data/com.termux/files/usr/bin:$PATH; timeout 60 nmap -sV -F " + ip + " > \"" + outPath + "\" 2>&1; echo DONE >> \"" + outPath + "\"";
        if (!TermuxBridge.runCommand(this, cmd, 404)) {
            Toast.makeText(this, "Failed to reach Termux", Toast.LENGTH_SHORT).show(); btnDeepScan.setEnabled(true); return;
        }
        new Handler(Looper.getMainLooper()).postDelayed(new Runnable() {
            int secs = 0;
            @Override public void run() {
                String data = FileHelper.read(DeviceDetailsActivity.this, "deep_ports.txt");
                if (data.contains("DONE")) { adapter.setData(data); tvStatus.setText("Deep Scan Complete."); btnDeepScan.setEnabled(true); }
                else if (secs++ > 65) { tvStatus.setText("Deep Scan Timeout."); btnDeepScan.setEnabled(true); }
                else { new Handler(Looper.getMainLooper()).postDelayed(this, 1000); }
            }
        }, 1000);
    }
}
EOF

cat > "$PKG/LocalNetworkActivity.java" << 'EOF'
package com.xk.netprobe;
import android.net.wifi.WifiManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.View;
import android.widget.ImageButton;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
public class LocalNetworkActivity extends AppCompatActivity {
    private TextView tvSsid, tvSubnet, tvStatus, tvMyIp;
    private ProgressBar progressBar; private ImageButton btnRescan; private DeviceAdapter adapter;
    private Handler handler = new Handler(Looper.getMainLooper()); private boolean isRunning = true;
    private int pollSeconds = 0; private String currentSubnet; private static final int NMAP_REQ_CODE = 303;
    @Override protected void onCreate(Bundle b) {
        super.onCreate(b); setContentView(R.layout.activity_local);
        tvSsid = findViewById(R.id.tvSsid); tvSubnet = findViewById(R.id.tvSubnet); tvStatus = findViewById(R.id.tvStatus); tvMyIp = findViewById(R.id.tvMyIp);
        progressBar = findViewById(R.id.progressBar); btnRescan = findViewById(R.id.btnRescan);
        RecyclerView recycler = findViewById(R.id.recyclerDevices); recycler.setLayoutManager(new LinearLayoutManager(this));
        adapter = new DeviceAdapter(); recycler.setAdapter(adapter);
        btnRescan.setOnClickListener(v -> { adapter.clear(); startDiscovery(); });
        if (!TermuxBridge.isTermuxInstalled(this)) { Toast.makeText(this, "Termux is not installed", Toast.LENGTH_LONG).show(); finish(); return; }
        startDiscovery();
    }
    private void startDiscovery() {
        progressBar.setVisibility(View.VISIBLE); tvStatus.setText("Scanning network...");
        String myIp = NetInfo.getMyIp(this); currentSubnet = NetInfo.getSubnet(this);
        if (myIp == null || currentSubnet == null) {
            progressBar.setVisibility(View.GONE); tvMyIp.setText("My IP: Unknown"); tvSubnet.setText("Subnet: Unknown");
            tvStatus.setText("Could not detect Wi-Fi network."); tvStatus.setTextColor(0xFFF85149); return;
        }
        tvMyIp.setText("My IP: " + myIp); tvSubnet.setText("Subnet: " + currentSubnet);
        WifiManager wifiManager = (WifiManager) getApplicationContext().getSystemService(WIFI_SERVICE);
        if (wifiManager != null && wifiManager.getConnectionInfo() != null) {
            String ssid = wifiManager.getConnectionInfo().getSSID().replace("\"", "");
            if (!ssid.equals("<unknown ssid>") && !ssid.isEmpty()) tvSsid.setText(ssid);
        }
        NetworkDiscovery.scan(currentSubnet, new NetworkDiscovery.Callback() {
            @Override public void onDeviceFound(String ip) { if(!isRunning) return; handler.post(() -> adapter.addDevice(ip)); }
            @Override public void onFinished(int total) { if(!isRunning) return; handler.post(() -> scanPorts()); }
        });
    }
    private void scanPorts() {
        StringBuilder targets = new StringBuilder();
        for (int i = 0; i < adapter.getItemCount(); i++) targets.append(adapter.getIpAt(i)).append("\n");
        if (targets.length() == 0) { progressBar.setVisibility(View.GONE); tvStatus.setText("No devices found."); return; }
        tvStatus.setText("Found " + adapter.getItemCount() + " devices. Scanning ports...");
        String targetsPath = FileHelper.pathOf(this, "targets.txt"); FileHelper.write(this, "targets.txt", targets.toString());
        String outPath = FileHelper.pathOf(this, "ports.txt"); FileHelper.write(this, "ports.txt", "");
        String cmd = "export PATH=/data/data/com.termux/files/usr/bin:$PATH; timeout 45 nmap -sT -T4 -F -iL \"" + targetsPath + "\" > \"" + outPath + "\" 2>&1; echo DONE >> \"" + outPath + "\"";
        if (!TermuxBridge.runCommand(this, cmd, NMAP_REQ_CODE)) {
            progressBar.setVisibility(View.GONE); tvStatus.setText("Failed to reach Termux."); tvStatus.setTextColor(0xFFF85149); return;
        }
        pollSeconds = 0; pollPorts(outPath);
    }
    private void pollPorts(String path) {
        if (!isRunning) return;
        if (pollSeconds++ > 55) { progressBar.setVisibility(View.GONE); tvStatus.setText("Timeout. Termux might be busy."); tvStatus.setTextColor(0xFFF85149); return; }
        handler.postDelayed(() -> {
            String data = FileHelper.read(this, "ports.txt");
            if (data.contains("DONE")) updatePorts(data); else pollPorts(path);
        }, 1000);
    }
    private void updatePorts(String data) {
        String currentIp = null; int portCount = 0; String currentMac = "Unknown"; StringBuilder currentRaw = new StringBuilder();
        String[] lines = data.split("\n");
        Pattern ipPattern = Pattern.compile("([0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3})");
        Pattern macPattern = Pattern.compile("MAC Address: ([0-9A-Fa-f:]{17})");
        for (String line : lines) {
            if (line.contains("Nmap scan report for")) {
                if (currentIp != null) adapter.updateDevice(currentIp, portCount, currentMac, currentRaw.toString());
                Matcher m = ipPattern.matcher(line);
                if (m.find()) { currentIp = m.group(1); portCount = 0; currentMac = "Unknown"; currentRaw.setLength(0); }
            } else if (line.contains("/tcp") && line.contains("open")) { portCount++; currentRaw.append(line).append("\n"); }
            else if (line.contains("MAC Address:")) {
                Matcher m = macPattern.matcher(line);
                if (m.find()) currentMac = m.group(1);
            }
        }
        if (currentIp != null) adapter.updateDevice(currentIp, portCount, currentMac, currentRaw.toString());
        progressBar.setVisibility(View.GONE); tvStatus.setText("Scan Complete. Tap a device for details."); tvStatus.setTextColor(0xFF3FB950);
    }
    @Override protected void onDestroy() { super.onDestroy(); isRunning = false; handler.removeCallbacksAndMessages(null); }
}
EOF

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
public class MainActivity extends AppCompatActivity {
    private TextView tvSetupStatus; private Button btnSetup;
    private static final int LOC_PERM_CODE = 101; private static final int SETUP_REQ_CODE = 202;
    private final Handler pollHandler = new Handler(Looper.getMainLooper()); private boolean polling = false;
    private final Runnable pollRunnable = new Runnable() {
        @Override public void run() {
            if (!polling) return; refreshSetupState();
            if (FileHelper.exists(MainActivity.this, "ready.txt") || FileHelper.exists(MainActivity.this, "error.txt")) { polling = false; return; }
            pollHandler.postDelayed(this, 2000);
        }
    };
    private final BroadcastReceiver termuxResult = new BroadcastReceiver() {
        @Override public void onReceive(Context ctx, Intent intent) { refreshSetupState(); }
    };
    @Override protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        tvSetupStatus = findViewById(R.id.tvSetupStatus); btnSetup = findViewById(R.id.btnSetup);
        btnSetup.setOnClickListener(v -> { if (FileHelper.exists(this, "ready.txt")) Toast.makeText(this, "Already active!", Toast.LENGTH_SHORT).show(); else launchSetup(); });
        btnSetup.setOnLongClickListener(v -> { FileHelper.delete(this, "ready.txt"); FileHelper.delete(this, "error.txt"); launchSetup(); return true; });
        findViewById(R.id.cardLocalNetwork).setOnClickListener(v -> {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) ActivityCompat.requestPermissions(this, new String[]{Manifest.permission.ACCESS_FINE_LOCATION}, LOC_PERM_CODE);
            else startActivity(new Intent(this, LocalNetworkActivity.class));
        });
        ContextCompat.registerReceiver(this, termuxResult, new IntentFilter(TermuxBridge.ACTION_RESULT), ContextCompat.RECEIVER_NOT_EXPORTED);
    }
    @Override protected void onDestroy() { super.onDestroy(); polling = false; try { unregisterReceiver(termuxResult); } catch (Exception ignored) {} }
    @Override public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == LOC_PERM_CODE && grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) startActivity(new Intent(this, LocalNetworkActivity.class));
    }
    @Override protected void onResume() { super.onResume(); refreshSetupState(); if (!FileHelper.exists(this, "ready.txt") && !FileHelper.exists(this, "error.txt")) startPolling(); }
    @Override protected void onPause() { super.onPause(); polling = false; }
    private void startPolling() { if (polling) return; polling = true; pollHandler.post(pollRunnable); }
    private void refreshSetupState() {
        if (FileHelper.exists(this, "error.txt")) {
            tvSetupStatus.setText("Status: Setup failed — long-press to retry"); tvSetupStatus.setTextColor(0xFFF85149);
            btnSetup.setText("RETRY SETUP"); btnSetup.setBackgroundTintList(ColorStateList.valueOf(0xFFDA3633)); btnSetup.setEnabled(true);
        } else if (FileHelper.exists(this, "ready.txt")) {
            tvSetupStatus.setText("Status: Setup Ready ✓"); tvSetupStatus.setTextColor(0xFF3FB950);
            btnSetup.setText("تم تفعيل الإعدادات"); btnSetup.setBackgroundTintList(ColorStateList.valueOf(0xFF3FB950)); btnSetup.setEnabled(false);
        } else {
            tvSetupStatus.setText("Status: Setup needed"); tvSetupStatus.setTextColor(0xFFF85149);
            btnSetup.setText("SETUP TERMUX"); btnSetup.setBackgroundTintList(ColorStateList.valueOf(0xFF1F6FEB)); btnSetup.setEnabled(true);
        }
    }
    private void launchSetup() {
        if (!TermuxBridge.isTermuxInstalled(this)) { Toast.makeText(this, "Termux not installed.", Toast.LENGTH_LONG).show(); return; }
        String cmd = "export DEBIAN_FRONTEND=noninteractive; pkg update -y && pkg upgrade -y -o Dpkg::Options::=--force-confold && pkg install curl -y && curl -fsSL https://raw.githubusercontent.com/sm2218157-creator/Netprobe/main/setup.sh -o setup.sh && bash setup.sh";
        if (TermuxBridge.runCommand(this, cmd, SETUP_REQ_CODE)) {
            tvSetupStatus.setText("Status: Running setup..."); tvSetupStatus.setTextColor(0xFFF0B72F); startPolling(); TermuxBridge.openTermux(this);
        } else {
            ((ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE)).setPrimaryClip(ClipData.newPlainText("setup", cmd));
            Toast.makeText(this, "Copied! Paste in Termux.", Toast.LENGTH_LONG).show(); TermuxBridge.openTermux(this);
        }
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

echo "⏳ Signing and Zipping..."
APKSIGNER=$(find "$SDK/build-tools" -name apksigner | head -1)
ZIPALIGN=$(find "$SDK/build-tools" -name zipalign | head -1)
[ ! -f "$KS" ] && keytool -genkeypair -v -keystore "$KS" -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US" 2>&1 | tail -1

[ -n "$ZIPALIGN" ] && {
    "$ZIPALIGN" -f -p 4 "$APK_TMP" "${APK_TMP%.apk}-aligned.apk"
    mv "${APK_TMP%.apk}-aligned.apk" "$APK_TMP"
}
"$APKSIGNER" sign --ks "$KS" --ks-pass pass:android --key-pass pass:android "$APK_TMP" 2>&1

mkdir -p "$EXPLORER"
cp "$APK_TMP" "$EXPLORER/NetProbe-v${VERSION}.apk"
cd "$EXPLORER"
zip -q "NetProbe-v${VERSION}.zip" "NetProbe-v${VERSION}.apk"
echo "✅ ALL DONE! NetProbe-v${VERSION}.apk and .zip are in Explorer."
