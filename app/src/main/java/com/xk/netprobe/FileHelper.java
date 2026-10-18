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
    public static boolean write(Context ctx, String name, String data) {
        File target = new File(pathOf(ctx, name)); File tmp = new File(target.getAbsolutePath() + ".tmp");
        try (FileWriter fw = new FileWriter(tmp)) { fw.write(data); } catch (Exception e) { return false; }
        return tmp.renameTo(target);
    }
}
