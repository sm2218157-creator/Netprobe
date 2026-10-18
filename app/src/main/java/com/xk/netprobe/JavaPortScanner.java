package com.xk.netprobe;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

public class JavaPortScanner {
    private static final int[] COMMON_PORTS = {21, 22, 23, 25, 53, 80, 110, 135, 139, 143, 443, 445, 993, 995, 1433, 1521, 3306, 3389, 5432, 5900, 8080, 8443};
    
    public interface Callback { void onScanComplete(List<String> openPorts); }

    public static String getServiceName(int port) {
        switch (port) {
            case 21: return "FTP"; case 22: return "SSH"; case 23: return "Telnet";
            case 25: return "SMTP"; case 53: return "DNS"; case 80: return "HTTP";
            case 110: return "POP3"; case 143: return "IMAP"; case 443: return "HTTPS";
            case 445: return "SMB"; case 1433: return "MSSQL"; case 1521: return "Oracle";
            case 3306: return "MySQL"; case 3389: return "RDP"; case 5432: return "PostgreSQL";
            case 5900: return "VNC"; case 8080: return "HTTP-Proxy"; case 8443: return "HTTPS-Alt";
            default: return "Unknown";
        }
    }

    public static void scan(String ip, Callback callback) {
        ExecutorService executor = Executors.newFixedThreadPool(30);
        List<String> results = new ArrayList<>();

        for (int port : COMMON_PORTS) {
            executor.execute(() -> {
                try (Socket socket = new Socket()) {
                    socket.connect(new InetSocketAddress(ip, port), 300);
                    synchronized (results) {
                        results.add(port + " (" + getServiceName(port) + ")");
                    }
                } catch (Exception ignored) {}
            });
        }
        executor.shutdown();
        new Thread(() -> {
            try { executor.awaitTermination(2, TimeUnit.SECONDS); } catch (Exception ignored) {}
            callback.onScanComplete(results);
        }).start();
    }
}
