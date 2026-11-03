#!/bin/bash
set -e
PROJ="/workspaces/NetProbe-Final"
APP="$PROJ/app"
PKG="$APP/src/main/java/com/xk/netprobe"
RES="$APP/src/main/res"
EXPLORER="/workspaces/Netprobe"
KS="/workspaces/debug.keystore"
SDK="$HOME/android-sdk"
VERSION="21.0"

export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH="$JAVA_HOME/bin:$PATH"
export ANDROID_HOME="$SDK"

echo "=== Building NetProbe v$VERSION (Accordion Device List) ==="

# 1. تحديث تصميم عنصر الجهاز ليدعم القائمة المنسدلة
cat > "$RES/layout/item_device.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android" xmlns:app="http://schemas.android.com/apk/res-auto"
    android:layout_width="match_parent" android:layout_height="wrap_content" android:orientation="vertical" android:layout_marginBottom="8dp">

    <!-- الكارت الأساسي للجهاز -->
    <androidx.cardview.widget.CardView
        android:layout_width="match_parent" android:layout_height="wrap_content"
        android:clickable="true" android:focusable="true" android:foreground="?attr/selectableItemBackground"
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

# 2. تحديث DeviceAdapter لدعم القائمة المنسدلة
cat > "$PKG/DeviceAdapter.java" << 'EOF'
package com.xk.netprobe;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;
import java.util.ArrayList;
import java.util.List;

public class DeviceAdapter extends RecyclerView.Adapter<DeviceAdapter.VH> {
    static class Device { 
        String ip; String mac; String displayName; int ports; String rawPorts; boolean isGateway; 
        Device(String ip, String mac, String displayName, int ports, String raw, boolean gw) { 
            this.ip = ip; this.mac = mac; this.displayName = displayName; this.ports = ports; this.rawPorts = raw; this.isGateway = gw; 
        } 
    }
    
    private final List<Device> devices = new ArrayList<>();
    private String gatewayIp = "";
    private int expandedPosition = -1; // لتتبع العنصر المفتوح حالياً

    public void setGateway(String gw) { this.gatewayIp = gw; }
    
    public void addDevice(String ip) {
        for (Device d : devices) if (d.ip.equals(ip)) return;
        devices.add(new Device(ip, "Unknown", "Unknown", -1, "Scanning...", ip.equals(gatewayIp)));
        notifyItemInserted(devices.size() - 1);
    }
    
    public void updateDevice(String ip, int ports, String mac, String displayName, String raw) {
        for (int i = 0; i < devices.size(); i++) {
            if (devices.get(i).ip.equals(ip)) {
                devices.get(i).ports = ports; 
                devices.get(i).mac = mac; 
                devices.get(i).displayName = displayName;
                devices.get(i).rawPorts = raw;
                notifyItemChanged(i); 
                break;
            }
        }
    }
    
    public String getIpAt(int index) { return devices.get(index).ip; }
    public void clear() { devices.clear(); expandedPosition = -1; notifyDataSetChanged(); }
    
    @NonNull @Override public VH onCreateViewHolder(@NonNull ViewGroup p, int t) { 
        return new VH(LayoutInflater.from(p.getContext()).inflate(R.layout.item_device, p, false)); 
    }
    
    @Override public void onBindViewHolder(@NonNull VH h, int i) {
        Device d = devices.get(i);
        h.tvIp.setText(d.ip); 
        h.tvPortCount.setText(d.ports == -1 ? "?" : String.valueOf(d.ports));
        
        if (d.isGateway) {
            h.tvVendor.setText("Router / Gateway");
        } else if (d.displayName != null && !d.displayName.equals("Unknown")) {
            h.tvVendor.setText(d.displayName);
        } else {
            h.tvVendor.setText(d.mac.equals("Unknown") ? "Device" : d.mac);
        }

        // إعداد حالة القائمة المنسدلة
        if (expandedPosition == i) {
            h.cardExpandable.setVisibility(View.VISIBLE);
            h.tvArrow.setText("▲");
            // تنسيق النص لعرض المنافذ بشكل جميل
            String formattedPorts = d.rawPorts.replace("\n", " • ");
            if (formattedPorts.isEmpty() || formattedPorts.equals("Scanning...")) {
                h.tvPortsList.setText("No open ports found.");
            } else {
                h.tvPortsList.setText(formattedPorts);
            }
        } else {
            h.cardExpandable.setVisibility(View.GONE);
            h.tvArrow.setText("▼");
        }
        
        // حدث الضغط لفتح وإغلاق القائمة
        h.itemView.setOnClickListener(v -> {
            if (expandedPosition == i) {
                expandedPosition = -1; // إغلاق إذا كان مفتوحاً
                notifyItemChanged(i);
            } else {
                int prevExpanded = expandedPosition;
                expandedPosition = i; // فتح هذا العنصر
                notifyItemChanged(i);
                if (prevExpanded != -1) notifyItemChanged(prevExpanded); // إغلاق العنصر السابق
            }
        });
    }
    
    @Override public int getItemCount() { return devices.size(); }
    
    static class VH extends RecyclerView.ViewHolder {
        TextView tvIp, tvPortCount, tvVendor, tvArrow, tvPortsList;
        View cardExpandable;
        VH(@NonNull View v) { 
            super(v); 
            tvIp = v.findViewById(R.id.tvIp); 
            tvPortCount = v.findViewById(R.id.tvPortCount); 
            tvVendor = v.findViewById(R.id.tvVendor); 
            tvArrow = v.findViewById(R.id.tvArrow);
            tvPortsList = v.findViewById(R.id.tvPortsList);
            cardExpandable = v.findViewById(R.id.cardExpandable);
        }
    }
}
EOF

# 3. إزالة شاشة التفاصيل القديمة من المانيفست (اختياري، ولكنه ضروري لمنع الأخطاء إذا أردنا حذف الكلاس لاحقاً)
sed -i '/<activity android:name=".DeviceDetailsActivity" android:exported="false" \/>/d' "$APP/src/main/AndroidManifest.xml" || true

# 4. تحديث الإصدار
sed -i 's/versionCode 33/versionCode 34/' "$APP/build.gradle" || true
sed -i 's/versionName "20.9"/versionName "21.0"/' "$APP/build.gradle" || true
sed -i 's/v20.9/v21.0/' "$RES/layout/activity_main.xml" || true

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
