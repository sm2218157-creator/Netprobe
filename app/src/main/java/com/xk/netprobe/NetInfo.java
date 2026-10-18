package com.xk.netprobe;
import android.content.Context;
import android.net.wifi.WifiManager;
import java.io.BufferedReader;
import java.io.FileReader;
import java.net.*;
import java.util.*;
public class NetInfo {
    public static String getMyIp(Context ctx) {
        try {
            Enumeration<NetworkInterface> interfaces = NetworkInterface.getNetworkInterfaces();
            while (interfaces.hasMoreElements()) {
                NetworkInterface ni = interfaces.nextElement();
                if (!ni.isUp() || ni.isLoopback()) continue;
                String name = ni.getName().toLowerCase();
                if (name.startsWith("wlan") || name.startsWith("eth")) {
                    Enumeration<InetAddress> addresses = ni.getInetAddresses();
                    while (addresses.hasMoreElements()) {
                        InetAddress addr = addresses.nextElement();
                        if (addr instanceof Inet4Address && !addr.isLoopbackAddress()) return addr.getHostAddress();
                    }
                }
            }
        } catch (Exception ignored) {}
        try {
            WifiManager wifiManager = (WifiManager) ctx.getApplicationContext().getSystemService(Context.WIFI_SERVICE);
            if (wifiManager != null && wifiManager.isWifiEnabled()) {
                int ipAddress = wifiManager.getConnectionInfo().getIpAddress();
                if (ipAddress != 0) return String.format(Locale.US, "%d.%d.%d.%d", (ipAddress & 0xff), (ipAddress >> 8 & 0xff), (ipAddress >> 16 & 0xff), (ipAddress >> 24 & 0xff));
            }
        } catch (Exception ignored) {}
        return null;
    }
    public static String getSubnet(Context ctx) {
        String ip = getMyIp(ctx);
        if (ip != null && ip.lastIndexOf('.') > 0) return ip.substring(0, ip.lastIndexOf('.')) + ".0/24";
        return null;
    }
    public static String getGatewayIp() {
        try (BufferedReader br = new BufferedReader(new FileReader("/proc/net/route"))) {
            String line;
            while ((line = br.readLine()) != null) {
                String[] parts = line.split("\\s+");
                if (parts.length > 2 && parts[1].equals("00000000")) {
                    String hex = parts[2];
                    int ip = Integer.parseInt(hex, 16);
                    return String.format(Locale.US, "%d.%d.%d.%d", (ip & 0xFF), (ip >> 8 & 0xFF), (ip >> 16 & 0xFF), (ip >> 24 & 0xFF));
                }
            }
        } catch (Exception ignored) {}
        return null;
    }
}
