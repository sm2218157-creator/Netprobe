#!/bin/bash
set -e
PROJ="/workspaces/NetProbe-Final"

echo "⏳ Updating setup.sh to include the Cloudflare Mirror..."

cat > "$PROJ/setup.sh" << 'EOF'
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

echo "[*] Setting up Cloudflare mirror (Bypass KSA block)..."
mkdir -p "$PREFIX/etc/apt"
echo "deb https://packages-cf.termux.dev/apt/termux-main stable main" > "$PREFIX/etc/apt/sources.list"
echo "[+] Mirror set"

echo "[*] Updating and upgrading packages (May take a few minutes)..."
pkg update -y || true
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
EOF

echo "⏳ Pushing to GitHub..."
cd "$PROJ"
git add setup.sh
git commit -m "fix: add cloudflare mirror back to setup.sh" || true
git push origin main --force || true

echo "✅ ALL DONE! setup.sh on GitHub is now fixed with the mirror."
