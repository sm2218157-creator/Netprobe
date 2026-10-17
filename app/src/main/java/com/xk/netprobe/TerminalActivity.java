package com.xk.netprobe;

import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.widget.Button;
import android.widget.ProgressBar;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import java.io.File;
import java.io.FileOutputStream;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.List;
import java.util.Locale;

public class TerminalActivity extends AppCompatActivity {

    private TextView tvCommand, tvOutput;
    private ScrollView scrollOutput;
    private ProgressBar progressBar;
    private NmapRunner runner;
    private final Handler ui = new Handler(Looper.getMainLooper());
    private final StringBuilder buffer = new StringBuilder();
    private final NmapOutputParser parser = new NmapOutputParser();
    private String commandShown = "";

    @Override
    protected void onCreate(Bundle s) {
        super.onCreate(s);
        setContentView(R.layout.activity_terminal);

        tvCommand = findViewById(R.id.tvCommand);
        tvOutput = findViewById(R.id.tvOutput);
        scrollOutput = findViewById(R.id.scrollOutput);
        progressBar = findViewById(R.id.progressBar);

        Button btnStop = findViewById(R.id.btnStop);
        Button btnClear = findViewById(R.id.btnClear);
        Button btnSave = findViewById(R.id.btnSave);

        PrivilegeManager.Level level = PrivilegeManager.detect(this);
        appendLine("[*] privilege: " + PrivilegeManager.describe(level));

        String target = getIntent().getStringExtra("target");
        String extra = getIntent().getStringExtra("extra");

        List<String> args = NmapRunner.buildArgs(target, extra);
        commandShown = "nmap " + joinArgs(args);
        tvCommand.setText("$ " + commandShown);

        btnStop.setOnClickListener(v -> {
            if (runner != null) runner.cancel();
            appendLine("[!] cancelled");
            progressBar.setVisibility(ProgressBar.GONE);
        });
        btnClear.setOnClickListener(v -> { buffer.setLength(0); tvOutput.setText(""); });
        btnSave.setOnClickListener(v -> saveOutput());

        runner = new NmapRunner(this, level);
        progressBar.setVisibility(ProgressBar.VISIBLE);

        new Thread(() -> {
            try {
                File bin = runner.ensureBinary();
                ui.post(() -> appendLine("[*] binary: " + bin.getAbsolutePath()));
                runner.run(bin, args, new NmapRunner.Listener() {
                    @Override public void onLine(String line) {
                        parser.feed(line);
                        ui.post(() -> appendLine(line));
                    }
                    @Override public void onExit(int code) {
                        NmapOutputParser.Result r = parser.finish();
                        String summary = NmapOutputParser.summary(r);
                        ui.post(() -> {
                            appendLine("");
                            appendLine("[*] exit code " + code);
                            appendLine("");
                            appendLine(summary);
                            progressBar.setVisibility(ProgressBar.GONE);
                        });
                    }
                    @Override public void onError(String message) {
                        ui.post(() -> {
                            appendLine("[!] " + message);
                            progressBar.setVisibility(ProgressBar.GONE);
                        });
                    }
                });
            } catch (Exception e) {
                ui.post(() -> {
                    appendLine("[!] nmap binary missing");
                    appendLine("[!] ضع nmap في app/src/main/assets/nmap");
                    progressBar.setVisibility(ProgressBar.GONE);
                });
            }
        }).start();
    }

    private void appendLine(String line) {
        buffer.append(line).append('\n');
        tvOutput.setText(buffer.toString());
        scrollOutput.post(() -> scrollOutput.fullScroll(ScrollView.FOCUS_DOWN));
    }

    private void saveOutput() {
        try {
            File dir = new File(getFilesDir(), "reports");
            if (!dir.exists() && !dir.mkdirs()) throw new RuntimeException("mkdir");
            String ts = new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(new Date());
            File f = new File(dir, "nmap_" + ts + ".txt");
            try (FileOutputStream fos = new FileOutputStream(f)) {
                fos.write(("$ " + commandShown + "\n\n" + buffer.toString()).getBytes("UTF-8"));
            }
            Toast.makeText(this, "حُفظ: " + f.getName(), Toast.LENGTH_LONG).show();
        } catch (Exception e) {
            Toast.makeText(this, "فشل: " + e.getMessage(), Toast.LENGTH_LONG).show();
        }
    }

    private static String joinArgs(List<String> args) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < args.size(); i++) {
            if (i > 0) sb.append(' ');
            sb.append(args.get(i));
        }
        return sb.toString();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (runner != null) runner.cancel();
    }
}
