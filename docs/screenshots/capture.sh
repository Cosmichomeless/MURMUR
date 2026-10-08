#!/bin/zsh
# Retakes the four README screenshots from the demo mode. Needs Xcode and a booted iOS simulator.
#
#   docs/screenshots/capture.sh [simulator-udid]    # defaults to the booted simulator
#
# Builds the Debug app, launches it with the demo flags (see docs/DEMO.md), captures each screen at
# the device's native size and shrinks the PNGs with optimize.py. Nothing here touches the
# microphone, the real library or App Store Connect.
set -euo pipefail

root="${0:A:h:h:h}"
device="${1:-booted}"
bundle="com.cosmichomeless.murmur"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

echo "Building…"
xcodebuild build -project "$root/MURMUR.xcodeproj" -scheme MURMUR \
  -destination "platform=iOS Simulator,id=${device}" \
  -derivedDataPath "$work/dd" CODE_SIGNING_ALLOWED=NO -quiet
xcrun simctl install "$device" "$work/dd/Build/Products/Debug-iphonesimulator/MURMUR.app"

# A clean, fixed status bar: 9:41, full battery and signal.
xcrun simctl status_bar "$device" override --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3
xcrun simctl ui "$device" appearance light

# name  seconds-to-wait  launch arguments
capture() {
  local name="$1" wait="$2"; shift 2
  xcrun simctl terminate "$device" "$bundle" 2>/dev/null || true
  xcrun simctl launch "$device" "$bundle" "$@" >/dev/null
  sleep "$wait"
  xcrun simctl io "$device" screenshot "$work/$name.png" 2>/dev/null
  python3 "$root/docs/screenshots/optimize.py" "$work/$name.png" "$root/docs/screenshots/$name.png"
  echo "  $name.png"
}

capture 01-library  5 -murmur-demo
capture 02-recorder 9 -murmur-demo -murmur-demo-screen recorder
capture 03-player   6 -murmur-demo -murmur-demo-screen player
capture 04-empty    4 -murmur-demo-empty

xcrun simctl terminate "$device" "$bundle" 2>/dev/null || true
xcrun simctl status_bar "$device" clear
echo "Done."
