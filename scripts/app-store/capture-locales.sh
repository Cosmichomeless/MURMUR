#!/bin/zsh
# Localized iPhone captures (library + player) for the App Store feature art. Output goes to build/app-store/art (gitignored).
set -euo pipefail
repo="${0:A:h:h:h}"
sp="$repo/build/app-store"
app="$sp/dd/Build/Products/Debug-iphonesimulator/MURMUR.app"  # xcodebuild -derivedDataPath build/app-store/dd
bundle="com.cosmichomeless.murmur"
iphone="F4F48520-997A-42C7-816C-F12E0AB775A7"   # iPhone 17 Pro Max

xcrun simctl boot "$iphone" 2>/dev/null || true
xcrun simctl bootstatus "$iphone" -b >/dev/null
xcrun simctl install "$iphone" "$app"
xcrun simctl status_bar "$iphone" override --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3
xcrun simctl ui "$iphone" appearance light

# folder  AppleLanguages  AppleLocale
for entry in "es-ES es es_ES" "en-US en en_US" "fr-FR fr fr_FR" "de-DE de de_DE" "it it it_IT" "pt-BR pt-BR pt_BR"; do
  set -- ${=entry}
  mkdir -p "$sp/art/$1"
  for shot in "01-library:5:" "03-player:6:-murmur-demo-screen player"; do
    name="${shot%%:*}"; rest="${shot#*:}"; wait="${rest%%:*}"; extra="${rest#*:}"
    xcrun simctl terminate "$iphone" "$bundle" 2>/dev/null || true
    xcrun simctl launch "$iphone" "$bundle" -murmur-demo ${=extra} \
      -AppleLanguages "($2)" -AppleLocale "$3" >/dev/null
    sleep "$wait"
    xcrun simctl io "$iphone" screenshot "$sp/art/$1/$name.png" 2>/dev/null
    echo "$1/$name"
  done
done
xcrun simctl terminate "$iphone" "$bundle" 2>/dev/null || true
xcrun simctl status_bar "$iphone" clear
