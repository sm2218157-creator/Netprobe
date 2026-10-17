package com.xk.netprobe;

import android.app.Activity;
import android.content.Context;
import android.content.pm.PackageManager;
import android.util.Log;

import java.io.BufferedReader;
import java.io.DataOutputStream;
import java.io.InputStreamReader;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;

import rikka.shizuku.Shizuku;

public class PrivilegeManager {

    public enum Level { APP, SHELL, ROOT }

    public static final int SHIZUKU_REQUEST_CODE = 4213;

    private static final String TAG = "PrivilegeManager";

    public interface PermissionListener {
        void onResult(boolean granted);
    }

    private static Shizuku.OnRequestPermissionResultListener permListener;

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

    public static boolean isShizukuInstalled(Context ctx) {
        try {
            ctx.getPackageManager().getPackageInfo("moe.shizuku.privileged.api", 0);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    public static boolean isShizukuAvailable(Context ctx) {
        if (!isShizukuInstalled(ctx)) return false;
        try {
            return Shizuku.pingBinder();
        } catch (Throwable t) {
            return false;
        }
    }

    public static boolean hasShizuku(Context ctx) {
        if (!isShizukuAvailable(ctx)) return false;
        try {
            if (Shizuku.isPreV11()) return true;
            return Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED;
        } catch (Throwable t) {
            return false;
        }
    }

    public static void requestShizukuPermission(Activity activity, PermissionListener listener) {
        if (!isShizukuAvailable(activity)) {
            listener.onResult(false);
            return;
        }
        try {
            if (Shizuku.isPreV11()
                    || Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED) {
                listener.onResult(true);
                return;
            }
            if (Shizuku.shouldShowRequestPermissionRationale()) {
                listener.onResult(false);
                return;
            }
            if (permListener != null) {
                try { Shizuku.removeRequestPermissionResultListener(permListener); }
                catch (Throwable ignored) {}
            }
            permListener = (requestCode, grantResult) -> {
                boolean ok = grantResult == PackageManager.PERMISSION_GRANTED;
                try { Shizuku.removeRequestPermissionResultListener(permListener); }
                catch (Throwable ignored) {}
                permListener = null;
                listener.onResult(ok);
            };
            Shizuku.addRequestPermissionResultListener(permListener);
            Shizuku.requestPermission(SHIZUKU_REQUEST_CODE);
        } catch (Throwable t) {
            listener.onResult(false);
        }
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

    /**
     * Executes a process via Shizuku using reflection so that the code
     * compiles against any Shizuku API version (some versions expose
     * Shizuku.newProcess directly, others route it through the service).
     */
    public static Process execAsShizuku(String[] cmd, String[] env, String dir)
            throws Exception {
        if (!Shizuku.pingBinder()) {
            throw new IllegalStateException("Shizuku binder not available");
        }
        if (!Shizuku.isPreV11()
                && Shizuku.checkSelfPermission() != PackageManager.PERMISSION_GRANTED) {
            throw new SecurityException("Shizuku permission not granted");
        }

        Exception lastError = null;

        // Attempt 1: Shizuku.newProcess(String[], String[], String)
        try {
            Method m = Shizuku.class.getMethod(
                    "newProcess", String[].class, String[].class, String.class);
            Object result = m.invoke(null, (Object) cmd, (Object) env, dir);
            if (result instanceof Process) return (Process) result;
            lastError = new IllegalStateException("newProcess returned unexpected type");
        } catch (NoSuchMethodException e) {
            lastError = e;
        } catch (InvocationTargetException e) {
            Throwable cause = e.getCause();
            if (cause instanceof Exception) throw (Exception) cause;
            lastError = e;
        }

        // Attempt 2: through ShizukuService.newProcess(...)
        try {
            Object service = getShizukuService();
            if (service != null) {
                Method m = service.getClass().getMethod(
                        "newProcess", String[].class, String[].class, String.class);
                Object result = m.invoke(service, (Object) cmd, (Object) env, dir);
                if (result instanceof Process) return (Process) result;
            }
        } catch (Exception e) {
            lastError = e;
        }

        throw new UnsupportedOperationException(
                "Shizuku.newProcess unavailable in this API version",
                lastError);
    }

    private static Object getShizukuService() {
        try {
            Method getBinder = Shizuku.class.getDeclaredMethod("getBinder");
            getBinder.setAccessible(true);
            Object binder = getBinder.invoke(null);
            if (binder == null) return null;

            Class<?> stubClass = Class.forName("rikka.shizuku.IShizukuService$Stub");
            Method asInterface = stubClass.getMethod("asInterface", android.os.IBinder.class);
            return asInterface.invoke(null, binder);
        } catch (Throwable t) {
            Log.d(TAG, "getShizukuService failed: " + t.getMessage());
            return null;
        }
    }
}
