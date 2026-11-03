package com.xk.netprobe;

import android.Manifest;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothManager;
import android.bluetooth.le.BluetoothLeScanner;
import android.bluetooth.le.ScanCallback;
import android.bluetooth.le.ScanResult;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.pm.PackageManager;
import android.content.res.ColorStateList;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;
import androidx.annotation.NonNull;
import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.app.ActivityCompat;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.ArrayList;
import java.util.List;

public class Esp32Activity extends AppCompatActivity {

    private Button btnFlashFirmware, btnConnect;
    private android.view.View cardBleSpam, cardWardriving;
    private TextView tvStatus;
    private boolean isConnected = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_esp32);

        btnFlashFirmware = findViewById(R.id.btnFlashFirmware);
        btnConnect = findViewById(R.id.btnConnect);
        cardBleSpam = findViewById(R.id.cardBleSpam);
        cardWardriving = findViewById(R.id.cardWardriving);

        cardBleSpam.setOnClickListener(v -> sendAttackCommand("/attack/ble", "BLE Spam"));
        cardWardriving.setOnClickListener(v -> sendAttackCommand("/attack/wardriving", "Wardriving"));

        tvStatus = findViewById(R.id.tvStatus);

        btnFlashFirmware.setOnClickListener(v -> {
            // 1. استخراج الملف
            if (!extractFirmware()) {
                Toast.makeText(this, "Failed to extract firmware.", Toast.LENGTH_SHORT).show();
                return;
            }
            // 2. كتابة السكربت في ملف مباشر
            if (!prepareScript()) {
                Toast.makeText(this, "Failed to create script.", Toast.LENGTH_SHORT).show();
                return;
            }
            // 3. نسخ سطر صغير جداً للحافظة
            ClipboardManager clipboard = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
            if (clipboard != null) {
                String shortCmd = "bash /sdcard/Android/media/com.xk.netprobe/NetProbe/flash.sh";
                clipboard.setPrimaryClip(ClipData.newPlainText("cmd", shortCmd));
                Toast.makeText(this, "Command copied! Paste in Termux and press Enter.", Toast.LENGTH_LONG).show();
            }
            // 4. فتح تيرمنال
            TermuxBridge.openTermux(this);
        });

        btnConnect.setOnClickListener(v -> showConnectDialog());
    }

    private boolean extractFirmware() {
        try {
            File dir = new File("/sdcard/Android/media/com.xk.netprobe/NetProbe");
            if (!dir.exists()) dir.mkdirs();
            File outFile = new File(dir, "firmware.bin");

            InputStream is = getAssets().open("firmware.bin");
            OutputStream os = new FileOutputStream(outFile);
            byte[] buffer = new byte[1024];
            int length;
            while ((length = is.read(buffer)) > 0) {
                os.write(buffer, 0, length);
            }
            os.flush();
            os.close();
            is.close();
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    private boolean prepareScript() {
        try {
            File dir = new File("/sdcard/Android/media/com.xk.netprobe/NetProbe");
            if (!dir.exists()) dir.mkdirs();
            File outFile = new File(dir, "flash.sh");

            String bashScript = "export DEBIAN_FRONTEND=noninteractive\n" +
                "echo \"====================================\"\n" +
                "echo \"  NetProbe ESP32 Flasher\"\n" +
                "echo \"====================================\"\n\n" +
                "echo \"[*] Step 1/3: Checking dependencies (Please wait)...\"\n" +
                "pkg update -y > /dev/null 2>&1\n" +
                "echo \"[*] Step 2/3: Installing esptool via pkg...\"\n" +
                "pkg install -y python esptool > /dev/null 2>&1\n\n" +
                "echo \"[*] Step 3/3: Searching for USB device...\"\n" +
                "PORT=$(ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null | head -n 1)\n\n" +
                "if [ -z \"$PORT\" ]; then\n" +
                "    echo \"[!] ERROR: No USB device found. Connect ESP32 via OTG.\"\n" +
                "    exit 1\n" +
                "fi\n\n" +
                "echo \"[+] Device found at $PORT\"\n" +
                "FIRMWARE=\"/sdcard/Android/media/com.xk.netprobe/NetProbe/firmware.bin\"\n\n" +
                "if [ ! -f \"$FIRMWARE\" ]; then\n" +
                "    echo \"[!] ERROR: Firmware file not found at $FIRMWARE!\"\n" +
                "    exit 1\n" +
                "fi\n\n" +
                "echo \"[+] Starting Flash Process (This may take a minute)...\"\n" +
                "esptool.py --port $PORT erase_flash\n" +
                "esptool.py --port $PORT write_flash 0x0 \"$FIRMWARE\"\n\n" +
                "echo \"====================================\"\n" +
                "echo \"[+] FLASHING COMPLETED SUCCESSFULLY!\"\n" +
                "echo \"====================================\"\n";

            FileOutputStream fos = new FileOutputStream(outFile);
            fos.write(bashScript.getBytes());
            fos.flush();
            fos.close();
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    private void showConnectDialog() {
        String[] methods = {"Wi-Fi (Token Auth)", "Bluetooth (BLE)"};
        new AlertDialog.Builder(this, android.R.style.Theme_DeviceDefault_Dialog_Alert)
            .setTitle("Select Connection Method")
            .setItems(methods, (dialog, which) -> {
                if (which == 0) {
                    connectWiFi();
                } else {
                    connectBLE();
                }
            })
            .setNegativeButton("Close", null)
            .show();
    }

    private void connectWiFi() {
        isConnected = false;
        updateStatus("Connecting via Wi-Fi...", 0xFFF0B72F);
        new Thread(() -> {
            try {
                URL url = new URL("http://192.168.4.1/connect");
                HttpURLConnection conn = (HttpURLConnection) url.openConnection();
                conn.setRequestMethod("POST");
                conn.setDoOutput(true);
                conn.setConnectTimeout(5000);
                conn.setReadTimeout(5000);
                
                String jsonInputString = "{\"token\":\"NetProbe_Secret_2026\"}";
                try (OutputStream os = conn.getOutputStream()) {
                    byte[] input = jsonInputString.getBytes("utf-8");
                    os.write(input, 0, input.length);
                }
                
                int code = conn.getResponseCode();
                if (code == 200) {
                    markConnected("Wi-Fi", "192.168.4.1");
                } else {
                    updateStatus("Wi-Fi Error: Code " + code, 0xFFF85149);
                }
            } catch (Exception e) {
                updateStatus("Wi-Fi Failed. Connect to ESP32 AP first.", 0xFFF85149);
            }
        }).start();
    }

    private void connectBLE() {
        List<String> permissions = new ArrayList<>();
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            if (checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN) != PackageManager.PERMISSION_GRANTED) permissions.add(Manifest.permission.BLUETOOTH_SCAN);
            if (checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) permissions.add(Manifest.permission.BLUETOOTH_CONNECT);
        }
        if (!permissions.isEmpty()) {
            ActivityCompat.requestPermissions(this, permissions.toArray(new String[0]), 1001);
            return;
        }
        startBleScan();
    }

    private void startBleScan() {
        updateStatus("Scanning for BLE...", 0xFFF0B72F);
        BluetoothManager btManager = (BluetoothManager) getSystemService(Context.BLUETOOTH_SERVICE);
        BluetoothAdapter btAdapter = btManager.getAdapter();
        
        if (btAdapter != null && btAdapter.isEnabled()) {
            BluetoothLeScanner scanner = btAdapter.getBluetoothLeScanner();
            if (scanner == null) { updateStatus("BLE Not Supported", 0xFFF85149); return; }

            ScanCallback callback = new ScanCallback() {
                @Override
                public void onScanResult(int callbackType, ScanResult result) {
                    if (result.getDevice().getName() != null && (result.getDevice().getName().contains("ESP") || result.getDevice().getName().contains("NetProbe"))) {
                        scanner.stopScan(this);
                        markConnected("BLE", result.getDevice().getAddress());
                    }
                }
            };
            
            scanner.startScan(callback);
            new Handler(Looper.getMainLooper()).postDelayed(() -> {
                if (!isConnected) {
                    try { scanner.stopScan(callback); } catch (Exception ignored) {}
                    updateStatus("BLE Failed: No device found", 0xFFF85149);
                }
            }, 5000);
        } else {
            updateStatus("Bluetooth is Disabled", 0xFFF85149);
        }
    }

    private void updateStatus(String text, int color) {
        runOnUiThread(() -> {
            tvStatus.setText("Status: " + text);
            tvStatus.setTextColor(color);
        });
    }

    private void markConnected(String method, String detail) {
        isConnected = true;
        runOnUiThread(() -> {
            btnConnect.setText("Connected via " + method);
            btnConnect.setBackgroundTintList(ColorStateList.valueOf(0xFF3FB950));
            tvStatus.setText("Status: Connected [" + detail + "]");
            tvStatus.setTextColor(0xFF3FB950);
            Toast.makeText(this, "Success: " + method, Toast.LENGTH_SHORT).show();
        });
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == 1001) {
            boolean allGranted = true;
            for (int result : grantResults) {
                if (result != PackageManager.PERMISSION_GRANTED) { allGranted = false; break; }
            }
            if (allGranted) startBleScan();
            else Toast.makeText(this, "Permissions required for BLE", Toast.LENGTH_SHORT).show();
        }
    }

    private void sendAttackCommand(String endpoint, String attackName) {
        Toast.makeText(this, "Sending " + attackName + " command...", Toast.LENGTH_SHORT).show();
        new Thread(() -> {
            try {
                URL url = new URL("http://192.168.4.1" + endpoint);
                HttpURLConnection conn = (HttpURLConnection) url.openConnection();
                conn.setRequestMethod("POST");
                conn.setDoOutput(true);
                conn.setConnectTimeout(3000);
                conn.setReadTimeout(3000);
                
                String jsonInputString = "{\"token\":\"NetProbe_Secret_2026\"}";
                try (OutputStream os = conn.getOutputStream()) {
                    byte[] input = jsonInputString.getBytes("utf-8");
                    os.write(input, 0, input.length);
                }
                
                int code = conn.getResponseCode();
                runOnUiThread(() -> {
                    if (code == 200) {
                        Toast.makeText(Esp32Activity.this, attackName + " Started!", Toast.LENGTH_SHORT).show();
                    } else {
                        Toast.makeText(Esp32Activity.this, "Failed: ESP32 returned " + code, Toast.LENGTH_SHORT).show();
                    }
                });
            } catch (Exception e) {
                runOnUiThread(() -> Toast.makeText(Esp32Activity.this, "Failed to connect to ESP32", Toast.LENGTH_SHORT).show());
            }
        }).start();
    }
}

