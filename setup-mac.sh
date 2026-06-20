#!/bin/bash
# Firashome "Tasks" app — one-command setup on any Mac (no admin/root needed).
# Works on MacinCloud Managed ($25/mo, no-admin) plan.
set -e

cd "$HOME"
APPDIR="$HOME/firashome-todo"

echo "==> Downloading the app from GitHub..."
if [ -d "$APPDIR/.git" ]; then
  cd "$APPDIR" && git pull --ff-only
else
  git clone https://github.com/FerasMahmoud/firashome-todo.git "$APPDIR"
  cd "$APPDIR"
fi

echo "==> Downloading XcodeGen binary (no Homebrew/admin needed)..."
WORK=$(mktemp -d)
curl -fsSL -o "$WORK/xcodegen.zip" https://github.com/yonaskolb/XcodeGen/releases/latest/download/xcodegen.zip
unzip -q -o "$WORK/xcodegen.zip" -d "$WORK/xg"
XGEN=$(find "$WORK/xg" -name xcodegen -type f | head -1)
chmod +x "$XGEN"

echo "==> Generating the Xcode project..."
"$XGEN" generate

echo "==> Opening in Xcode..."
open "$APPDIR/Todo.xcodeproj"

echo ""
echo "✅ Done. Xcode is opening."
echo "   ▶  Press Cmd+R (or the play button) to run in the iPhone Simulator."
echo "   ▶  For your real iPhone: Xcode menu → Product → Archive → Distribute App → TestFlight."
