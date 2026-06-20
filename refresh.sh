#!/bin/bash
# Run on the Mac to pull the latest code + rebuild + relaunch the app in the simulator.
set -e
cd "$HOME/firashome-todo"
echo "==> Pulling latest..."
git pull --ff-only

echo "==> Rebuilding..."
WORK=$(mktemp -d)
curl -fsSL -o "$WORK/x.zip" https://github.com/yonaskolb/XcodeGen/releases/latest/download/xcodegen.zip
unzip -q -o "$WORK/x.zip" -d "$WORK/xg"
XGEN=$(find "$WORK/xg" -name xcodegen -type f | head -1); chmod +x "$XGEN"
"$XGEN" generate >/dev/null

SIM=$(xcrun simctl list devices booted | grep -oE '[A-F0-9-]{36}' | head -1)
if [ -z "$SIM" ]; then
  SIM=$(xcrun simctl list devices available | grep -oE 'iPhone [^(]+\([^)]+\)' | head -1 | grep -oE '[A-F0-9-]{36}')
  xcrun simctl bootstatus "$SIM" -b
fi

xcodebuild -scheme Todo -project Todo.xcodeproj -destination "id=$SIM" \
  -derivedDataPath build -skipMacroValidation -skipPackagePluginValidation build >/tmp/tasks-build.log 2>&1 \
  || { echo "BUILD FAILED:"; tail -20 /tmp/tasks-build.log; exit 1; }

APP=$(find build -name "Todo.app" -path "*Debug-iphonesimulator*" | head -1)
xcrun simctl terminate "$SIM" uk.firashome.todo 2>/dev/null || true
xcrun simctl install "$SIM" "$APP"
xcrun simctl launch "$SIM" uk.firashome.todo
open -a Simulator
echo "✅ Updated + relaunched."
