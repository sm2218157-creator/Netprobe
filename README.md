# NetProbe 🛡️

[![Download](https://img.shields.io/badge/Download-v37.6.6-blue?style=for-the-badge)](https://raw.githubusercontent.com/sm2218157-creator/Netprobe/main/NetProbe-v37.6.6.apk)
[![Android](https://img.shields.io/badge/Android-7.0%2B-brightgreen?style=for-the-badge)](https://developer.android.com)

**Complete Android security toolkit** — Network scanning, WiFi attacks, ESP32 control, OSINT — one app, Arabic UI.

## Overview
NetProbe turns any Android device (rooted or not) into a portable penetration-testing toolkit for ethical hackers, security researchers, CTF players, and cybersecurity students.

## Features

### Network Recon
- Local network scan — ARP discovery + port scan (18 ports)
- Device analysis — nmap -sV deep scan, MAC vendor lookup
- Shizuku integration — shell-level scanning without root

### WiFi Pentesting
- WiFite3 — modern WPS/PMKID/WPA (auto-install via uv)
- WiFite2 — lightweight legacy WiFi tool
- WiFi Nightmare — rogue AP, Karma, DNS spoofing, MAC flooding
- Bettercap — MITM, ARP spoofing, sniffing

### ESP32 Control
- USB firmware flash (esptool via pip + root/tsu)
- WiFi + BLE connection (192.168.4.1)
- Attack modes: Wardriving, BLE Flood, Deauth, BadUSB, 2.4GHz Jam, Sub-GHz Jam, MouseJack, RC Hijack
- Live terminal — real-time /rf/log polling every 1.5s
- RF Scan/Replay — save up to 50 signals (FIFO)

### OSINT (7 Tools)
Blackbird, Holehe, PhoneInfoga, Subfinder, ExifTool, theHarvester, Nuclei — each runs in interactive Termux shell with auto-install.

### Arabic Guide
Full in-app guide, 6 sections, per-tool options.

## Requirements
| Component | Purpose |
|-----------|---------|
| Termux (from F-Droid) | Runtime for all tools |
| Shizuku | Shell permissions (optional) |
| NetHunter Rootless (~2GB) | Kali for WiFi tools (optional) |
| USB WiFi Adapter | Monitor Mode (needed for WiFi attacks) |
| Rooted device + tsu | ESP32 USB flash |
| USB OTG cable (data) | Connect ESP32 |

## Installation
1. Download [NetProbe-v37.6.6.apk](https://raw.githubusercontent.com/sm2218157-creator/Netprobe/main/NetProbe-v37.6.6.apk)
2. Enable "Install from unknown sources", tap APK (Android 7.0+)
3. Open → SETUP TERMUX → paste in Termux
4. (Optional) Download NetHunter for Kali tools
5. (Optional) ESP32: connect via OTG, tap Flash Firmware

## Build from Source
git clone https://github.com/sm2218157-creator/Netprobe.git
cd Netprobe
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
./gradlew clean assembleDebug

### Architecture
- 8 Activities: Main, LocalNetwork, DeviceDetails, Attack, ESP32, OSINT, Guide
- 16 script constants in SetupScriptStore.java
- Termux integration via TermuxBridge + file-based execution
- NetHunter chroot for WiFi tools (runs as root)

## Legal Notice
**For authorized security testing only.** Use on your own devices and networks, or with explicit written permission. Unauthorized access is illegal in most countries.

## Credits
Termux, Kali NetHunter, Shizuku, ProjectDiscovery, WiFite, Bettercap, WiFi Nightmare, Blackbird, Holehe, PhoneInfoga, ExifTool, theHarvester.

## License
Educational and personal use only. See [LICENSE](LICENSE).

---
⭐ If NetProbe helped you, star this repo — it helps others find it!
