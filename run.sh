#!/data/data/com.termux/files/usr/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${1:-$HOME/Netprobe}"

[ -f "$SCRIPT_DIR/netprobe_v20.sh" ] || { echo "✗ netprobe_v20.sh not found in $SCRIPT_DIR"; exit 1; }
[ -d "$PROJECT_DIR/.git" ] || { echo "✗ $PROJECT_DIR is not a git repo"; echo "  git clone https://github.com/sm2218157-creator/Netprobe.git $PROJECT_DIR"; exit 1; }

bash "$SCRIPT_DIR/netprobe_v20.sh" "$PROJECT_DIR"
