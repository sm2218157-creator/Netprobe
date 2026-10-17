package com.xk.netprobe;

import android.content.Context;
import android.util.Log;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.List;

public class NmapRunner {

    public interface Listener {
        void onLine(String line);
        void onExit(int code);
        void onError(String message);
    }

    private final Context ctx;
    private final PrivilegeManager.Level level;
    private Process process;
    private volatile boolean cancelled = false;

    public NmapRunner(Context ctx, PrivilegeManager.Level level) {
        this.ctx = ctx;
        this.level = level;
    }

    public void cancel() {
        cancelled = true;
        if (process != null) {
            try { process.destroy(); } catch (Exception ignored) {}
            process = null;
        }
    }

    public File ensureBinary() throws Exception {
        File out = new File(ctx.getFilesDir(), "nmap");
        if (out.exists() && out.length() > 0) {
            try { out.setExecutable(true, false); } catch (Exception ignored) {}
            return out;
        }
        try (InputStream in = ctx.getAssets().open("nmap");
             OutputStream os = new FileOutputStream(out)) {
            byte[] buf = new byte[65536];
            int n;
            while ((n = in.read(buf)) > 0) os.write(buf, 0, n);
        }
        out.setExecutable(true, false);
        try {
            Runtime.getRuntime().exec(new String[]{
                "chmod", "755", out.getAbsolutePath()
            }).waitFor();
        } catch (Exception ignored) {}
        return out;
    }

    public void run(File nmapBin, List<String> userArgs, Listener listener) {
        new Thread(() -> {
            try {
                List<String> args = adaptForPrivileges(userArgs);
                if (level == PrivilegeManager.Level.ROOT) {
                    runAsRoot(nmapBin, args, listener);
                } else {
                    runDirect(nmapBin, args, listener);
                }
            } catch (Exception e) {
                Log.e("NmapRunner", "error", e);
                listener.onError("Runner error: " + e.getMessage());
            }
        }).start();
    }

    private List<String> adaptForPrivileges(List<String> userArgs) {
        List<String> out = new ArrayList<>(userArgs);
        switch (level) {
            case APP:
                for (int i = out.size() - 1; i >= 0; i--) {
                    String a = out.get(i);
                    if (a.equals("-sS") || a.equals("-O") || a.equals("-sU")) {
                        out.remove(i);
                    }
                }
                if (!out.contains("--unprivileged")) out.add("--unprivileged");
                break;
            case SHELL:
                if (!out.contains("--unprivileged")) out.add("--unprivileged");
                for (int i = out.size() - 1; i >= 0; i--) {
                    String a = out.get(i);
                    if (a.equals("-sS") || a.equals("-O")) out.remove(i);
                }
                break;
            case ROOT:
                break;
        }
        if (!out.contains("-Pn")) out.add(0, "-Pn");
        if (!hasAnyT(out)) out.add("-T4");
        return out;
    }

    private boolean hasAnyT(List<String> args) {
        for (String a : args) if (a.startsWith("-T")) return true;
        return false;
    }

    private void runDirect(File nmapBin, List<String> args, Listener listener)
            throws Exception {
        List<String> cmd = new ArrayList<>();
        cmd.add(nmapBin.getAbsolutePath());
        cmd.addAll(args);
        ProcessBuilder pb = new ProcessBuilder(cmd);
        pb.redirectErrorStream(true);
        pb.environment().put("PATH", ctx.getFilesDir().getAbsolutePath()
                + ":/system/bin:/system/xbin");
        pb.directory(ctx.getFilesDir());
        process = pb.start();
        stream(process, listener);
    }

    private void runAsRoot(File nmapBin, List<String> args, Listener listener)
            throws Exception {
        StringBuilder cmd = new StringBuilder();
        cmd.append(nmapBin.getAbsolutePath());
        for (String a : args) cmd.append(' ').append(shellEscape(a));
        process = PrivilegeManager.execAsRoot(cmd.toString());
        stream(process, listener);
    }

    private void stream(Process p, Listener listener) {
        try {
            BufferedReader br = new BufferedReader(new InputStreamReader(p.getInputStream()));
            String line;
            while ((line = br.readLine()) != null) {
                if (cancelled) break;
                listener.onLine(line);
            }
            int code = p.waitFor();
            listener.onExit(code);
        } catch (Exception e) {
            listener.onError("stream error: " + e.getMessage());
        }
    }

    private String shellEscape(String s) {
        if (s.matches("[a-zA-Z0-9_/.:=-]+")) return s;
        return "'" + s.replace("'", "'\\''") + "'";
    }

    public static List<String> buildArgs(String target, String extra) {
        List<String> out = new ArrayList<>();
        if (extra != null && !extra.trim().isEmpty()) {
            for (String tok : extra.trim().split("\\s+")) {
                if (!tok.isEmpty()) out.add(tok);
            }
        }
        if (target != null && !target.trim().isEmpty()) out.add(target.trim());
        return out;
    }
}
