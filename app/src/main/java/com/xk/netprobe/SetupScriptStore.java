package com.xk.netprobe;
public class SetupScriptStore {
    public static final String SETUP_SCRIPT = 
        "export DEBIAN_FRONTEND=noninteractive; " +
        "termux-setup-storage; " +
        "sleep 2; " +
        "echo 'deb https://mirrors.tuna.tsinghua.edu.cn/termux/apt/termux-main stable main' > $PREFIX/etc/apt/sources.list; " +
        "pkg update -y > /dev/null 2>&1; " +
        "pkg install nmap curl wget -y > /dev/null 2>&1; " +
        "mkdir -p /sdcard/Android/media/com.xk.netprobe/NetProbe; " +
        "echo 'READY_CF' > /sdcard/Android/media/com.xk.netprobe/NetProbe/ready.txt; " +
        "echo '✅ Setup COMPLETE! Return to NetProbe.'";

    public static final String WPS_INSTALL_SCRIPT = 
        "export DEBIAN_FRONTEND=noninteractive; " +
        "set -e; " +
        "echo '[*] Updating package lists...'; " +
        "pkg update -y; " +
        "pkg upgrade -y -o Dpkg::Options::=--force-confold; " +
        "echo '[*] Adding root-repo...'; " +
        "pkg install root-repo -y; " +
        "echo '[*] Refreshing lists after root-repo...'; " +
        "pkg update -y; " +
        "echo '[*] Installing WPS tools...'; " +
        "pkg install aircrack-ng reaver iw -y; " +
        "command -v aircrack-ng >/dev/null || { echo '[-] aircrack-ng missing'; exit 1; }; " +
        "command -v reaver >/dev/null || { echo '[-] reaver missing'; exit 1; }; " +
        "command -v iw >/dev/null || { echo '[-] iw missing'; exit 1; }; " +
        "echo '✅ All WPS tools installed successfully. You can close Termux.'";

    public static final String WPS_RUN_SCRIPT = 
        "export DEBIAN_FRONTEND=noninteractive; " +
        "echo '[*] Detecting adapter...'; " +
        "IFACE=$(iw dev | awk '$1==\"Interface\"{print $2}' | grep -v wlan0 | head -n 1); " +
        "if [ -z \"$IFACE\" ]; then echo '[-] No external adapter found!'; exit 1; fi; " +
        "echo \"[+] Found: $IFACE\"; " +
        "echo '[*] Starting Monitor Mode...'; " +
        "airmon-ng check kill > /dev/null 2>&1; " +
        "airmon-ng start $IFACE > /dev/null 2>&1; " +
        "MON_IFACE=$(iw dev | awk '$1==\"Interface\"{print $2}' | grep mon | head -n 1); " +
        "if [ -z \"$MON_IFACE\" ]; then echo '[-] Monitor mode failed.'; exit 1; fi; " +
        "echo '[*] Scanning for WPS...'; " +
        "wash -i $MON_IFACE";

    public static final String NETHUNTER_SCRIPT = 
        "export DEBIAN_FRONTEND=noninteractive; " +
        "set -e; " +
        "MEDIA=\"/sdcard/Android/media/com.xk.netprobe/NetProbe\"; " +
        "echo '[*] Updating system (fixes broken curl)...'; " +
        "apt update -y; " +
        "apt full-upgrade -y -o Dpkg::Options::=--force-confold; " +
        "echo '[*] Installing dependencies...'; " +
        "pkg install wget curl -y -o Dpkg::Options::=--force-confold; " +
        "pkg install openssl -y -o Dpkg::Options::=--force-confold; " +
        "echo '[*] Downloading NetHunter Installer...'; " +
        "wget -O install-nethunter-termux https://offs.ec/2MceZWr; " +
        "chmod +x install-nethunter-termux; " +
        "echo '[*] Auto-selecting Minimal (2)...'; " +
        "echo '2' | ./install-nethunter-termux; " +
        "command -v nethunter >/dev/null || { echo '[-] NetHunter installation failed.'; exit 1; }; " +
        "echo '[*] Fixing DNS and Updating packages...'; " +
        "nethunter -r -c \"echo 'nameserver 8.8.8.8' > /etc/resolv.conf && apt update\"; " +
        "echo 'READY' > $MEDIA/nethunter_status.txt; " +
        "echo '✅ NetHunter Installed & Network Fixed.'";

    public static final String NETHUNTER_CHECK_SCRIPT =
        "export DEBIAN_FRONTEND=noninteractive; " +
        "MEDIA=\"/sdcard/Android/media/com.xk.netprobe/NetProbe\"; " +
        "mkdir -p $MEDIA; " +
        "if command -v nethunter >/dev/null 2>&1; then " +
        "echo 'READY' > $MEDIA/nethunter_status.txt; " +
        "echo '✅ NetHunter is installed.'; " +
        "else " +
        "echo 'MISSING' > $MEDIA/nethunter_status.txt; " +
        "echo '[-] NetHunter is NOT installed.'; " +
        "fi; " +
        "echo 'Press Enter to return to NetProbe...'; " +
        "read dummy";
}
