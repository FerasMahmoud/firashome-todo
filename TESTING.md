# Testing the Todo SwiftUI app

The app is generated from `project.yml` via [xcodegen](https://github.com/yonaskolb/XcodeGen);
there is no checked-in `.xcodeproj`. Build + test on a Mac (Xcode 15+, iOS 17 SDK).

## One-time setup

```bash
brew install xcodegen          # if not installed
cd ~/todo                      # (or wherever the repo is on the Mac)
xcodegen generate              # regenerates Todo.xcodeproj from project.yml
```

## Run the logic tests WITHOUT a Mac (Linux / WSL)

The Foundation-only core (NLParser, TaskSort, FilterParser) can be compiled and
tested on Linux via the standalone SwiftPM rig at `~/todo-logic` (Swift 6.0
toolchain at `~/swift`). The parser/sort/filter sources are copied verbatim from
this repo; only the SwiftData `@Model` types are stubbed. This is how the logic
layer is verified on the WSL build box.

```bash
# one-time: Swift toolchain (already at ~/swift on this box) + ncurses shim
export PATH=~/swift/usr/bin:$PATH
export LD_LIBRARY_PATH=~/swift-libs:$LD_LIBRARY_PATH   # libncurses.so.6 → libncursesw.so.6 symlink

cd ~/todo-logic
swift test        # 32 tests, ~0.1s
```

To re-sync after editing logic here: `sed '/^import SwiftData$/d' Sync/FilterParser.swift > ~/todo-logic/Sources/TodoLogic/FilterParser.swift` (NLParser/TaskSort copy verbatim).

**What this rig already caught & fixed (2026-06-23):**
- `Data/Repository.swift` had an extra `}` (compile-blocker) — fixed.
- `FilterParser` didn't parse multi-word date phrases (`no date`, `7 days`, `next 7 days`) because the tokenizer split them — fixed in `Sync/FilterParser.swift` (phrases now resolved before tokenizing).

## Run the unit tests (logic layer)

These verify the parsers, sorters, and recurrence math — the same behavior the
web SPA at `todo.firashome.uk` was verified against.

```bash
xcodebuild test \
  -project Todo.xcodeproj \
  -scheme Todo \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:TodoTests
```

Or open `Todo.xcodeproj` in Xcode → **⌘U** (runs the full Test action, which now
includes `TodoTests` + `TodoScreenshotTests`).

What's covered (`Tests/`):
- **NLParserTests** — quick-add parsing: `p1`–`p4`, `#project`, `@label`,
  today/tomorrow/weekdays, `every day|week|month|year`, `!30m` reminder, and the
  compound Todoist line.
- **TaskSortTests** — priority-then-order, priority-then-due, due-then-order,
  completion-recency.
- **RecurrenceTests** — daily/weekly/monthly/yearly next-occurrence math +
  `notifyAt` day+time combination.

## Run the UI / screenshot tests

```bash
xcodebuild test \
  -project Todo.xcodeproj \
  -scheme Todo \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:TodoScreenshotTests
```

## Audit a build for warnings/errors

```bash
xcodebuild build \
  -project Todo.xcodeproj \
  -scheme Todo \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -quiet 2>&1 | grep -E "error:|warning:"
```

## Static-audit notes (2026-06-23)

- **Fixed**: `Data/Repository.swift` had one extra closing brace (27 `{` vs 28 `}`)
  — a compile-blocker. Now balanced.
- All `.swift` files verified brace-balanced. (Paren counting is unreliable in
  Swift because of parens in doc comments, so it is not used as a gate.)
- `NLParser` is richer than the web parser (also handles `next <weekday>`,
  `jan 5` month-day, and `!30m`/`!1h` reminder shortcuts) and its logic is sound.
- `TodoTask` carries all the fields the web SPA added (`recurrence`, `deadline`,
  `duration`, `scheduledAt`, `reminders`), so feature parity is in place at the
  model layer.

## Verify like a real human (manual)

After `xcodebuild build` + run in Simulator (or on device):
- Quick Add: type `Email John p1 tomorrow #FITech @urgent every week` → confirm
  priority/date/project/labels/recurrence are extracted and the title is clean.
- Complete a recurring task → a new open occurrence appears one interval out.
- Drag-reorder within a section; sort menu per view (date/priority/name/order).
- Board view (columns per section), Calendar view (month grid with task counts).
- Bulk select → Complete / Delete / Priority / Move.
- Settings → Language: العربية flips the UI to RTL.
