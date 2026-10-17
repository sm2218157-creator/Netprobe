package com.xk.netprobe;

import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Build;
import android.util.Log;

import java.io.BufferedReader;
import java.io.DataOutputStream;
import java.io.InputStreamReader;

public class PrivilegeManager {

    public enum Level { APP, SHELL, ROOT }

    private static final String TAG = "PrivilegeManager";

    public static boolean testRealRoot() {
        Process p = null;
        try {
            p = Runtime.getRuntime().exec("su");
            DataOutputStream os = new DataOutputStream(p.getOutputStream());
            BufferedReader br = new BufferedReader(new InputStreamReader(p.getInputStream()));
            os.writeBytes("id\n");
            os.writeBytes("exit\n");
            os.flush();
            String line = br.readLine();
            if (line != null && line.contains("uid=0")) return true;
            p.waitFor();
        } catch (Exception e) {
            Log.d(TAG, "no su: " + e.getMessage());
        } finally {
            if (p != null) p.destroy();
        }
        return false;
    }

    public static boolean hasShizuku(Context ctx) {
        try {
            ctx.getPackageManager().getPackageInfo("moe.shizuku.privileged.api", 0);
            if (Build.VERSION.SDK_INT >= 23) {
                return ctx.checkSelfPermission("moe.shizuku.manager.permission.API_V23")
                        == PackageManager.PERMISSION_GRANTED;
            }
        } catch (Exception ignored) {}
        return false;
    }

    public static Level detect(Context ctx) {
        if (testRealRoot()) return Level.ROOT;
        if (hasShizuku(ctx)) return Level.SHELL;
        return Level.APP;
    }

    public static String describe(Level l) {
        switch (l) {
            case ROOT:  return "ROOT — full scans available";
            case SHELL: return "SHELL (Shizuku) — most scans";
            default:    return "APP — TCP connect scans";
        }
    }

    public static Process execAsRoot(String cmd) throws Exception {
        Process p = Runtime.getRuntime().exec("su");
        DataOutputStream os = new DataOutputStream(p.getOutputStream());
        os.writeBytes(cmd + "\n");
        os.writeBytes("exit\n");
        os.flush();
        return p;
    }
}
