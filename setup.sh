#!/data/data/com.termux/files/usr/bin/bash
echo "========================================="
echo "   NetProbe Setup Started"
echo "========================================="

MEDIA="/sdcard/Android/media/com.xk.netprobe/NetProbe"
mkdir -p "$MEDIA"

echo "[*] Requesting storage permission..."
termux-setup-storage || true
sleep 3
if [ ! -d "/sdcard" ]; then
    echo "[-] ERROR: Storage permission denied."
    echo "ERROR" > "$MEDIA/error.txt"
    exit 1
fi
echo "[+] Storage OK"

echo "[*] Updating and upgrading packages (May take a few minutes)..."
pkg update -y || true
pkg update --fix-missing -y || true
pkg upgrade -y -o Dpkg::Options::="--force-confold" || true
echo "[+] Packages updated"

echo "[*] Installing nmap, curl, wget..."
pkg install -y nmap curl wget
echo "[+] Tools installed"

echo "[*] Verifying installation..."
command -v nmap >/dev/null || { echo "[-] nmap not found"; exit 1; }
command -v curl >/dev/null || { echo "[-] curl not found"; exit 1; }

echo "READY" > "$MEDIA/ready.txt"
echo "========================================="
echo " ✅ Setup COMPLETE! Return to NetProbe."
echo "========================================="
