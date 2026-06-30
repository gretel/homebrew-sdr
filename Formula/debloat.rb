# typed: false
# frozen_string_literal: true

# Disable unnecessary macOS system daemons without disabling SIP.
#
# SIP protects the system-domain disabled.plist — with SIP enabled,
# `launchctl disable system/<service>` does not persist past reboot.
# This formula provides a LaunchDaemon that re-applies the disables
# on every boot (and hourly).
#
# === Customising ===
# Edit debloat.sh in the tap repo and reinstall:
#   brew reinstall gretel/sdr/debloat
# Then restart the service:
#   sudo brew services restart debloat
#
# Usage:
#   brew install gretel/sdr/debloat
#   sudo brew services start debloat
#
# Preserved services (not disabled):
#   iCloud, TimeMachine, AirPlay, Handoff, ScreenSharing, FindMy, Touch ID, DHCP6
class Debloat < Formula
  desc "Disable unnecessary macOS system daemons (no SIP disable needed)"
  homepage "https://github.com/gretel/homebrew-sdr"
  url "https://raw.githubusercontent.com/gretel/homebrew-sdr/main/debloat.sh"
  version "1.0.0"
  sha256 "9df049c437c382acf1643fb94f97fee189c4307ec9febf63427450771196d068"
  license "MIT"

  depends_on macos: :ventura

  def install
    bin.install "debloat.sh" => "debloat"
  end

  service do
    run [opt_bin/"debloat"]
    run_type :interval
    interval 3600       # re-check every hour
    run_at_load true    # run on boot — catches SIP persistence gap
    log_path var/"log/debloat.log"
    error_log_path var/"log/debloat.log"
    require_root true   # /Library/LaunchDaemons/, runs as root
  end

  def caveats
    <<~EOS
      LaunchDaemon (re-applies on every boot):
        sudo brew services start debloat

      The disables don't survive reboot with SIP on, so the
      LaunchDaemon re-runs at boot and hourly to re-apply them.

      To customise which services are disabled, edit:
        #{tap.path}/debloat.sh
      Then reinstall: brew reinstall gretel/sdr/debloat && sudo brew services restart debloat
    EOS
  end

  test do
    system "sh", "-n", "#{bin}/debloat"
  end
end
