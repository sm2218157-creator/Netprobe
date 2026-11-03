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

    public static final String WIFI_NIGHTMARE_SCRIPT = 
        "nethunter -r -c 'echo \"aWYgY29tbWFuZCAtdiB3aWZpLW5pZ2h0bWFyZSA+L2Rldi9udWxsIDI+JjE7IHRoZW4KICAgIGVjaG8gIlsqXSBTdGFydGluZyBXaS1GaSBOaWdodG1hcmUuLi4iCiAgICB3aWZpLW5pZ2h0bWFyZQplbGlmIFsgLWQgL3Jvb3QvV2lGaS1OaWdodG1hcmUgXTsgdGhlbgogICAgZWNobyAiWypdIFN0YXJ0aW5nIFdpLUZpIE5pZ2h0bWFyZS4uLiIKICAgIGNkIC9yb290L1dpRmktTmlnaHRtYXJlICYmIHB5dGhvbjMgV2lGaS1OaWdodG1hcmUucHkKZWxzZQogICAgZWNobyAiWypdIEluc3RhbGxpbmcgV2ktRmkgTmlnaHRtYXJlLi4uIgogICAgY2QgL3Jvb3QgJiYgZ2l0IGNsb25lIGh0dHBzOi8vZ2l0aHViLmNvbS9Vc2VySm9vOS9XaUZpLU5pZ2h0bWFyZS5naXQgJiYgY2QgV2lGaS1OaWdodG1hcmUgJiYgY2htb2QgK3ggKiAmJiBweXRob24zIFdpRmktTmlnaHRtYXJlLnB5CmZpCg==\" | base64 -d | bash'";

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
