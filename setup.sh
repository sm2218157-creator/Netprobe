#!/data/data/com.termux/files/usr/bin/bash

echo -e "\033[36m[*] 1. Setting up Cloudflare mirror...\033[0m"
mkdir -p "$PREFIX/etc/apt"
echo "deb https://packages-cf.termux.dev/apt/termux-main stable main" > "$PREFIX/etc/apt/sources.list"

echo -e "\033[36m[*] 2. Requesting Storage Permission (Please Allow)...\033[0m"
termux-setup-storage
sleep 3

MEDIA="/sdcard/Android/media/com.xk.netprobe/NetProbe"
mkdir -p "$MEDIA"

echo -e "\033[36m[*] 3. Updating and upgrading packages...\033[0m"
pkg update -y
# إضافة أمر يمنع التوقف عند التحديثات
pkg upgrade -y -o Dpkg::Options::="--force-confold"

echo -e "\033[36m[*] 4. Allowing external apps...\033[0m"
mkdir -p "$HOME/.termux"
grep -q "allow-external-apps=true" "$HOME/.termux/termux.properties" || echo "allow-external-apps=true" >> "$HOME/.termux/termux.properties"
termux-reload-settings 2>/dev/null || true

echo -e "\033[36m[*] 5. Installing tools (Watch progress)...\033[0m"
# إزالة إخفاء النصوص لكي يظهر شريط التقدم
pkg install -y nmap curl wget dnsutils

echo "READY" > "$MEDIA/ready.txt"
echo -e "\033[32m✅ Setup COMPLETE!\033[0m"
echo -e "\033[33m👉 Return to NetProbe App.\033[0m"
