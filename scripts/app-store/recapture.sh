#!/bin/zsh
set -euo pipefail
repo="${0:A:h:h:h}"
sp="$repo/build/app-store"
bundle="com.cosmichomeless.murmur"; iphone="F4F48520-997A-42C7-816C-F12E0AB775A7"
shoot() { # folder lang locale name wait extra...
  local dir="$1" lang="$2" loc="$3" name="$4" wait="$5"; shift 5
  xcrun simctl terminate "$iphone" "$bundle" 2>/dev/null || true
  sleep 2
  xcrun simctl launch "$iphone" "$bundle" -murmur-demo "$@" -AppleLanguages "($lang)" -AppleLocale "$loc" >/dev/null
  sleep "$wait"
  xcrun simctl io "$iphone" screenshot "$sp/art/$dir/$name.png" 2>/dev/null
  echo "$dir/$name"
}
xcrun simctl status_bar "$iphone" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
shoot en-US en en_US 03-player 12 -murmur-demo-screen player
shoot fr-FR fr fr_FR 01-library 12
shoot fr-FR fr fr_FR 03-player 12 -murmur-demo-screen player
xcrun simctl terminate "$iphone" "$bundle" 2>/dev/null || true
xcrun simctl status_bar "$iphone" clear
