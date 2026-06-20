#!/bin/bash
# Run this on a Mac (MacinCloud / MacStadium / your Mac). Sets up + opens the app.
set -e
echo "==> Checking for Homebrew..."
if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
echo "==> Installing XcodeGen..."
brew install xcodegen || true
echo "==> Cloning the app..."
git clone https://github.com/FerasMahmoud/firashome-todo.git 2>/dev/null || true
cd firashome-todo
echo "==> Generating Xcode project..."
xcodegen generate
echo "==> Opening in Xcode..."
open Todo.xcodeproj
echo ""
echo "✅ Xcode is open. Press Cmd+R (or the ▶️ button) to run in the iPhone Simulator."
echo "   To put it on your iPhone: Product menu → Archive → Distribute App → TestFlight."
