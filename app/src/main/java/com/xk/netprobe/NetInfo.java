package com.xk.netprobe;

import android.content.Context;
import android.net.wifi.WifiManager;
import java.net.*;
import java.util.*;

public class NetInfo {
    public static String getMyIp(Context ctx) {
        // 1. Try WifiManager (Works on 99% of devices if location is granted)
        try {
            WifiManager wifiManager = (WifiManager) ctx.getSystemService(Context.WIFI_SERVICE);
            if (wifiManager != null && wifiManager.isWifiEnabled()) {
                int ipAddress = wifiManager.getConnectionInfo().getIpAddress();
                if (ipAddress != 0) {
                    return String.format(Locale.US, "%d.%d.%d.%d",
                            (ipAddress & 0xff), (ipAddress >> 8 & 0xff),
                            (ipAddress >> 16 & 0xff), (ipAddress >> 24 & 0xff));
                }
            }
        } catch (Exception ignored) {}

        // 2. Try NetworkInterface (wlan0)
        try {
            Enumeration<NetworkInterface> interfaces = NetworkInterface.getNetworkInterfaces();
            while (interfaces.hasMoreElements()) {
                NetworkInterface ni = interfaces.nextElement();
                if (!ni.isUp() || ni.isLoopback()) continue;
                String name = ni.getName().toLowerCase();
                if (name.startsWith("wlan")) {
                    Enumeration<InetAddress> addresses = ni.getInetAddresses();
                    while (addresses.hasMoreElements()) {
                        InetAddress addr = addresses.nextElement();
                        if (addr instanceof Inet4Address && !addr.isLoopbackAddress()) {
                            return addr.getHostAddress();
                        }
                    }
                }
            }
        } catch (Exception ignored) {}

        return "192.168.1.1"; // Default fallback
    }

    public static String getSubnet(Context ctx) {
        String ip = getMyIp(ctx);
        if (ip.lastIndexOf('.') > 0) {
            return ip.substring(0, ip.lastIndexOf('.')) + ".0/24";
        }
        return "192.168.1.0/24";
    }
}
