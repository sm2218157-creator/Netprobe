package com.xk.netprobe;
import java.util.HashMap;
import java.util.Map;
public class MacVendorLookup {
    private static final Map<String, String> vendors = new HashMap<>();
    static {
        // Apple
        vendors.put("A8:42:A1", "Apple"); vendors.put("00:1B:63", "Apple"); vendors.put("00:1C:B3", "Apple");
        vendors.put("BC:92:6B", "Apple"); vendors.put("68:AB:1E", "Apple"); vendors.put("F0:18:98", "Apple");
        vendors.put("AC:BC:32", "Apple"); vendors.put("D0:81:7A", "Apple"); vendors.put("F4:5C:89", "Apple");
        // Samsung
        vendors.put("D8:9E:F3", "Samsung"); vendors.put("B4:79:A7", "Samsung"); vendors.put("64:B5:C6", "Samsung");
        vendors.put("34:23:BA", "Samsung"); vendors.put("C8:19:F7", "Samsung"); vendors.put("78:1F:DB", "Samsung");
        vendors.put("E8:50:8B", "Samsung"); vendors.put("5C:0A:5B", "Samsung");
        // Huawei / Honor
        vendors.put("88:36:6C", "Huawei"); vendors.put("00:E0:FC", "Huawei"); vendors.put("48:DB:50", "Huawei");
        vendors.put("B0:5B:67", "Huawei"); vendors.put("8C:34:FD", "Huawei"); vendors.put("F4:9F:F3", "Huawei");
        // Xiaomi / Redmi
        vendors.put("64:09:80", "Xiaomi"); vendors.put("50:64:2B", "Xiaomi"); vendors.put("68:C6:3A", "Xiaomi");
        vendors.put("78:11:DC", "Xiaomi"); vendors.put("8C:BE:BE", "Xiaomi"); vendors.put("F0:B4:29", "Xiaomi");
        // Google
        vendors.put("00:1A:11", "Google"); vendors.put("F4:F5:D8", "Google"); vendors.put("3C:5A:B4", "Google");
        vendors.put("94:EB:2C", "Google"); vendors.put("CC:32:E5", "Google");
        // Intel
        vendors.put("F4:8C:50", "Intel"); vendors.put("00:1E:67", "Intel"); vendors.put("A4:BB:6D", "Intel");
        vendors.put("34:13:E8", "Intel"); vendors.put("7C:B2:7D", "Intel");
        // Routers & Networking
        vendors.put("54:04:A6", "TP-Link"); vendors.put("F4:F2:6D", "TP-Link"); vendors.put("00:1D:AA", "MikroTik");
        vendors.put("00:11:32", "Synology"); vendors.put("B0:BE:76", "Roku"); vendors.put("00:0C:29", "VMware");
        vendors.put("00:50:56", "VMware"); vendors.put("00:24:36", "Apple"); vendors.put("E0:94:67", "Intel");
        vendors.put("C0:56:27", "Belkin"); vendors.put("00:14:BF", "Cisco-Linksys"); vendors.put("00:1A:70", "Cisco");
        vendors.put("00:0F:B5", "Netgear"); vendors.put("A0:40:A0", "Netgear"); vendors.put("00:05:5D", "D-Link");
        // TV & Smart Devices
        vendors.put("00:17:88", "Philips Hue"); vendors.put("B8:27:EB", "Raspberry Pi"); vendors.put("CC:50:E3", "Espressif");
        vendors.put("3C:71:BF", "Espressif"); vendors.put("A0:20:A6", "Espressif"); vendors.put("DC:4F:22", "Espressif");
        vendors.put("54:27:1E", "Amazon"); vendors.put("F0:27:2D", "Amazon"); vendors.put("68:54:FD", "Amazon");
        vendors.put("C4:3A:35", "Sony"); vendors.put("00:13:A9", "Sony"); vendors.put("FC:0F:E6", "Sony");
        vendors.put("2C:54:91", "Microsoft"); vendors.put("7C:1E:52", "Microsoft");
        // Laptops & PCs
        vendors.put("00:1A:A0", "Dell"); vendors.put("B8:2A:72", "Dell"); vendors.put("3C:52:82", "HP");
        vendors.put("00:1F:29", "HP"); vendors.put("00:25:90", "Super Micro"); vendors.put("E8:6A:64", "Lenovo");
        vendors.put("00:12:FE", "Lenovo"); vendors.put("00:1E:37", "Lenovo"); vendors.put("1C:87:2C", "Asus");
        vendors.put("00:1B:FC", "Asus"); vendors.put("F4:6D:04", "Asus");
        // Realtek / Others
        vendors.put("00:E0:4C", "Realtek"); vendors.put("52:54:00", "QEMU"); vendors.put("08:00:27", "VirtualBox");
    }
    public static String getVendor(String mac) {
        if (mac == null || mac.equals("Unknown") || mac.length() < 8) return "Device";
        String prefix = mac.substring(0, 8).toUpperCase();
        return vendors.getOrDefault(prefix, "Device");
    }
}
