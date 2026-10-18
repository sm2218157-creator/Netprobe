package com.xk.netprobe;
public class SetupScriptStore {
    public static final String SETUP_SCRIPT = 
        "export DEBIAN_FRONTEND=noninteractive; " +
        "termux-setup-storage; " +
        "sleep 2; " +
        "echo 'deb https://packages-cf.termux.dev/apt/termux-main stable main' > $PREFIX/etc/apt/sources.list; " +
        "pkg update -y; " +
        "pkg upgrade -y -o Dpkg::Options::=--force-confold; " +
        "pkg install nmap curl wget -y; " +
        "mkdir -p /sdcard/Android/media/com.xk.netprobe/NetProbe; " +
        "echo 'READY' > /sdcard/Android/media/com.xk.netprobe/NetProbe/ready.txt; " +
        "echo '✅ Setup COMPLETE! Return to NetProbe.'";
}
