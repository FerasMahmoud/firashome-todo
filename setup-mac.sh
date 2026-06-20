#!/bin/bash
# Firashome "Tasks" — ONE paste on a Mac and the app launches in the simulator.
# No Xcode clicking needed. No admin needed (works on MacinCloud $25 plan).
set -e
cd "$HOME"
APPDIR="$HOME/firashome-todo"

echo "==> 1/5 Download the app from GitHub..."
if [ -d "$APPDIR/.git" ]; then cd "$APPDIR" && git pull --ff-only; else git clone https://github.com/FerasMahmoud/firashome-todo.git "$APPDIR" && cd "$APPDIR"; fi

echo "==> 2/5 Download XcodeGen (admin-free)..."
WORK=$(mktemp -d)
curl -fsSL -o "$WORK/x.zip" https://github.com/yonaskolb/XcodeGen/releases/latest/download/xcodegen.zip
unzip -q -o "$WORK/x.zip" -d "$WORK/xg"
XGEN=$(find "$WORK/xg" -name xcodegen -type f | head -1); chmod +x "$XGEN"

echo "==> 3/5 Generate Xcode project..."
"$XGEN" generate >/dev/null

echo "==> 4/5 Pick an iPhone simulator + build the app..."
SIM=$(xcrun simctl list devices available | grep -oE 'iPhone [^(]+\([^)]+\)' | head -1 | grep -oE '[A-F0-9-]{36}')
echo "    using simulator: $SIM"
xcrun simctl bootstatus "$SIM" -b
xcodebuild -scheme Todo -project Todo.xcodeproj \
  -destination "id=$SIM" -derivedDataPath build \
  -skipMacroValidation -skipPackagePluginValidation build \
  >/tmp/tasks-build.log 2>&1 || { echo "BUILD FAILED — last lines:"; tail -20 /tmp/tasks-build.log; exit 1; }
APP=$(find build -name "Todo.app" -path "*Debug-iphonesimulator*" | head -1)

echo "==> 5/5 Install + launch in the simulator..."
xcrun simctl install "$SIM" "$APP"
xcrun simctl launch "$SIM" uk.firashome.todo
open -a Simulator

echo ""
echo "✅ The Tasks app is now running in the iPhone Simulator window. You should see it."
echo "   (Seed demo: Today/Inbox/Upcoming/Filters/Projects are all populated.)"
echo ""
echo "👉 Next, to put it on your REAL iPhone: tell me and I'll give you the TestFlight steps."
