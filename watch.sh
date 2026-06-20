#!/bin/bash
# Live auto-update. Run ONCE on the Mac, leave it. The simulator refreshes
# whenever a new commit lands on GitHub. Press Ctrl+C to stop.
cd "$HOME/firashome-todo" || { echo "Run setup-mac.sh first"; exit 1; }
while true; do
  if git fetch --quiet && [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/master)" ]; then
    echo "==> New update detected — rebuilding..."
    git pull --ff-only --quiet
    bash refresh.sh 2>&1 | tail -3
  fi
  sleep 20
done
