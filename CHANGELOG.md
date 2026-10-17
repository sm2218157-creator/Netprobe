# NetProbe Changelog

## v20.0 — Major Rewrite

### Fixed
- NetworkDiscovery: Runtime.exec fails on Android 10+ → InetAddress.isReachable()
- TermuxBridge: added PendingIntent to receive stdout/stderr/exit
- MainActivity: polling on ready.txt/error.txt + retry
- FileHelper: added delete(), atomic write, error logging
- setup.sh: set -e, error.txt on failure, nmap/curl verification
- NetInfo: NetworkInterface first, returns null on failure
- LocalNetworkActivity: Termux check, 55s polling
- MainActivity launchSetup: auto-installs curl before first run

### Changed
- versionCode: 19 → 20
- versionName: "19.0" → "20.0"
- Discovery threads: 50 → 20
