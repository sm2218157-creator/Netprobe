package com.xk.netprobe;
import android.content.Context;
import android.content.Intent;
public class TermuxBridge {
    public static void runCommand(Context ctx, String cmd) {
        Intent intent = new Intent();
        intent.setClassName("com.termux", "com.termux.app.RunCommandService");
        intent.setAction("com.termux.RUN_COMMAND");
        intent.putExtra("com.termux.RUN_COMMAND_PATH", "/data/data/com.termux/files/usr/bin/bash");
        intent.putExtra("com.termux.RUN_COMMAND_ARGUMENTS", new String[]{"-c", cmd});
        intent.putExtra("com.termux.RUN_COMMAND_WORKDIR", "/data/data/com.termux/files/home");
        intent.putExtra("com.termux.RUN_COMMAND_BACKGROUND", true);
        try { ctx.startService(intent); } catch (Exception ignored) {}
    }
    public static void openTermux(Context ctx) {
        Intent i = new Intent();
        i.setClassName("com.termux", "com.termux.app.TermuxActivity");
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        ctx.startActivity(i);
    }
}
