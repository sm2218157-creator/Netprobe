package com.xk.netprobe;
import android.content.Context;
import android.net.wifi.WifiManager;
import android.util.Log;
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
            WifiManager wm = (WifiManager) ctx.getApplicationContext().getSystemService(Context.WIFI_SERVICE);
            if (wm != null && wm.isWifiEnabled()) {
                int ip = wm.getConnectionInfo().getIpAddress();
                if (ip != 0) return String.format(Locale.US, "%d.%d.%d.%d", (ip & 0xff), (ip >> 8 & 0xff), (ip >> 16 & 0xff), (ip >> 24 & 0xff));
            }
        } catch (Exception ignored) {}
        return null;
    }
    public static String getSubnet(Context ctx) {
        String ip = getMyIp(ctx); if (ip == null) return null;
        int lastDot = ip.lastIndexOf('.'); if (lastDot <= 0) return null;
        return ip.substring(0, lastDot) + ".0/24";
    }
}
