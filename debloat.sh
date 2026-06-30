#!/bin/sh
# debloat — disable unnecessary macOS system daemons
#
# SIP prevents `launchctl disable system/...` from persisting past reboot.
# This runtime workaround re-applies the disables on every boot.
# Run via LaunchDaemon: sudo brew services start debloat
#
# === Customising ===
# To change which services are disabled, comment/uncomment `run` lines
# below, then reinstall and restart the service:
#   brew reinstall gretel/sdr/debloat
#   sudo brew services restart debloat

set -eu

_disable() {
  sudo launchctl bootout "system/${1}" 2>/dev/null || true
  sudo launchctl disable "system/${1}"
}

run() {
  for _s in "$@"; do _disable "$_s"; done
}

# ══════════════════════════════════════════════════════════════════════
# Active — disabled on every boot
# ══════════════════════════════════════════════════════════════════════

# --- Analytics / Telemetry ---
run \
  'com.apple.analyticsd' \
  'com.apple.audioanalyticsd' \
  'com.apple.ecosystemanalyticsd' \
  'com.apple.wifianalyticsd'

# --- CoreDuet (device behaviour prediction) ---
run 'com.apple.coreduetd'

# --- Family Controls ---
run 'com.apple.familycontrols'

# --- FTP Proxy ---
run 'com.apple.ftp-proxy'

# --- Game Controller ---
run 'com.apple.GameController.gamecontrollerd'

# --- Location Services ---
run 'com.apple.locationd'

# --- Model Manager ---
run 'com.apple.modelmanagerd'

# --- NetBIOS ---
run 'com.apple.netbiosd'

# --- Trials / A/B Testing ---
run 'com.apple.triald.system'

# ══════════════════════════════════════════════════════════════════════
# Preserved — commented out. Uncomment to disable.
# ══════════════════════════════════════════════════════════════════════

# --- iCloud ---
#run \
#  'com.apple.cloudd'

# --- Time Machine (Backup) ---
#run \
#  'com.apple.backupd' \
#  'com.apple.backupd-helper'

# --- Touch ID / Biometrics ---
#run 'com.apple.biomed'

# --- FindMy ---
#run \
#  'com.apple.findmymac' \
#  'com.apple.findmymacmessenger' \
#  'com.apple.findmy.findmybeaconingd' \
#  'com.apple.icloud.searchpartyd'

# --- Sharing / AirDrop / AirPlay / Handoff ---
#run 'com.apple.rapportd'

# --- Screen Sharing ---
#run 'com.apple.screensharing'

# --- DHCP6 ---
#run 'com.apple.dhcp6d'