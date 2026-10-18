#!/bin/bash
set -e
PROJ="/workspaces/NetProbe-Final"
APP="$PROJ/app"
PKG="$APP/src/main/java/com/xk/netprobe"
EXPLORER="/workspaces/Netprobe"
VERSION="19.9"

echo "⏳ [1/3] Creating missing FileHelper.java..."
cat > "$PKG/FileHelper.java" << 'EOF'
package com.xk.netprobe;

import android.content.Context;
import java.io.*;

public class FileHelper {
    public static File dir(Context ctx) {
        File[] dirs = ctx.getExternalMediaDirs();
        File base = (dirs != null && dirs.length > 0) ? dirs[0] : ctx.getFilesDir();
        File dir = new File(base, "NetProbe"); 
        if (!dir.exists()) dir.mkdirs(); 
        return dir;
    }
    public static String pathOf(Context ctx, String name) { return new File(dir(ctx), name).getAbsolutePath(); }
    public static boolean exists(Context ctx, String name) { return new File(pathOf(ctx, name)).exists(); }
    public static boolean delete(Context ctx, String name) { return new File(pathOf(ctx, name)).delete(); }
    
    public static String read(Context ctx, String name) {
        File f = new File(pathOf(ctx, name)); 
        if (!f.exists()) return "";
        StringBuilder sb = new StringBuilder();
        try (BufferedReader br = new BufferedReader(new FileReader(f))) { 
            String l; 
            while ((l = br.readLine()) != null) sb.append(l).append("\n"); 
        } catch (Exception ignored) {}
        return sb.toString();
    }
    
    public static void write(Context ctx, String name, String data) {
        File target = new File(pathOf(ctx, name)); 
        File tmp = new File(target.getAbsolutePath() + ".tmp");
        try (FileWriter fw = new FileWriter(tmp)) { 
            fw.write(data); 
        } catch (Exception ignored) {}
        tmp.renameTo(target);
    }
}
EOF

echo "⏳ [2/3] Building..."
cd "$PROJ"
./gradlew clean assembleDebug

APK_TMP="$APP/build/outputs/apk/debug/app-debug.apk"
if [ ! -f "$APK_TMP" ]; then echo "❌ BUILD FAILED."; exit 1; fi

echo "⏳ [3/3] Copying to Explorer..."
cp "$APK_TMP" "$EXPLORER/NetProbe-v${VERSION}.apk"
cd "$EXPLORER"
zip -q "NetProbe-v${VERSION}.zip" "NetProbe-v${VERSION}.apk"

echo "✅ SUCCESS! Check Explorer."
