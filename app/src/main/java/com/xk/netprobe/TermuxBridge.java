package com.xk.netprobe;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
public class TermuxBridge {
    public static final String ACTION_RESULT = "com.xk.netprobe.TERMUX_RESULT";
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
        try { ctx.startService(intent); return true; } catch (Exception e) { return false; }
    }
    public static void openTermux(Context ctx) {
        Intent i = new Intent(); i.setClassName("com.termux", "com.termux.app.TermuxActivity"); i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        try { ctx.startActivity(i); } catch (Exception ignored) {}
    }
}
