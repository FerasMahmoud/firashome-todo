# Tasks — native SwiftUI Todoist-style app

Light-theme, SwiftData (on-device SQLite), Todoist-style task manager. Built from WSL2/iPad with **no Mac** — GitHub Actions compiles, screenshots, and ships.

## What this is
A full SwiftUI app: Today / Upcoming / Filters / Projects / Labels views, quick-add, task detail, home-screen **widgets**, and a **Dynamic Island Live Activity**. iOS 26 Liquid Glass styling where available.

## No-Mac workflow
1. Code edited on PC (Claude Code).
2. `git push` → GitHub Actions (public repo = **free macOS runners**).
3. `screenshots` workflow → builds app, renders simulator screenshots on **iPhone 17 Pro Max / iPhone 17 Pro / iPad Pro 13" / iPad mini** → publishes a device-frame gallery.
4. `testflight` workflow → archives + uploads to TestFlight (needs Apple Developer account + API key secret).

## Build locally (if you have a Mac)
```bash
brew install xcodegen
xcodegen generate
open Todo.xcodeproj
```

## Run on simulator with demo data
```bash
xcodegen generate
xcodebuild -scheme Todo -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -runFirstLaunch --seed-demo
# (or launch with argument: --seed-demo)
```

## Project structure
See `project.yml` (XcodeGen) — the `.xcodeproj` is generated from it, never edit by hand.
- `App/` — app entry + root navigation
- `Design/` — `Tokens.swift` (light theme)
- `Models/` — SwiftData `@Model`s (TodoTask, Project, Label)
- `Data/` — Seed + Repository
- `Views/` — all screens
- `Widgets/` — WidgetKit home widgets + Dynamic Island
- `UITests/` — screenshot capture
- `.github/workflows/` — CI

## Brand
Light Todoist-style. White canvas, ink text, single red accent `#E53935`. Restraint over decoration.

---
Built with skill `swiftui-app-kit`. Hosted preview gallery: **todo.firashome.uk**
