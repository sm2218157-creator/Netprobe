#!/data/data/com.termux/files/usr/bin/bash
set -e
MEDIA="/sdcard/Android/media/com.xk.netprobe/NetProbe"
LOG="$MEDIA/setup.log"
mkdir -p "$MEDIA"
exec > >(tee -a "$LOG") 2>&1

log()  { echo -e "\033[36m[*] $1\033[0m"; }
ok()   { echo -e "\033[32m[+] $1\033[0m"; }
fail() { echo -e "\033[31m[!] $1\033[0m"; echo "ERROR: $1" > "$MEDIA/error.txt"; exit 1; }

rm -f "$MEDIA/error.txt" "$MEDIA/ready.txt"

log "1. Setting up Cloudflare mirror..."
mkdir -p "$PREFIX/etc/apt"
echo "deb https://packages-cf.termux.dev/apt/termux-main stable main" > "$PREFIX/etc/apt/sources.list"
ok "mirror set"

log "2. Requesting storage permission..."
termux-setup-storage || true
sleep 3
[ -d "/sdcard" ] || fail "storage permission denied"
mkdir -p "$MEDIA"
ok "storage ready"

log "3. Updating package index..."
pkg update -y || fail "pkg update failed"
ok "index updated"

log "4. Allowing external apps..."
mkdir -p "$HOME/.termux"
grep -q "allow-external-apps=true" "$HOME/.termux/termux.properties" \
    || echo "allow-external-apps=true" >> "$HOME/.termux/termux.properties"
termux-reload-settings 2>/dev/null || true
ok "external apps allowed"

log "5. Installing tools..."
pkg install -y nmap curl wget || fail "tool install failed"
ok "tools installed"

log "6. Verifying..."
command -v nmap >/dev/null || fail "nmap not found"
command -v curl >/dev/null || fail "curl not found"
ok "verification passed"

echo "READY" > "$MEDIA/ready.txt"
ok "Setup COMPLETE — return to NetProbe App."
