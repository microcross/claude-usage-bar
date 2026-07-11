# Contributing

Thanks for your interest in improving claude-usage-bar. It's a small project, so the process is light.

## Getting set up

```bash
git clone https://github.com/microcross/claude-usage-bar.git
cd claude-usage-bar
swift build        # compile
swift test         # run the test suite
./build.sh         # produce UsageWidget.app
```

Requires macOS 13+ and the Swift toolchain (Xcode or the Command Line Tools).

## Project layout

- `Sources/UsageWidgetCore/` — pure, platform-agnostic logic (usage-response parsing, org selection). No AppKit/SwiftUI. This is where most unit-testable code lives.
- `Sources/UsageWidgetUI/` — AppKit/SwiftUI pieces (donut rendering, menu bar icon, key storage).
- `Sources/UsageWidget/` — the executable: app entry point, the menu bar panel, the model, and the WebKit-based fetcher.
- `Tests/UsageWidgetTests/` — XCTest suite.

## Pull requests

- Keep changes focused and small.
- Add or update tests for anything in `UsageWidgetCore` / `UsageWidgetUI`.
- Make sure `swift build -c release` and `swift test` both pass. CI runs both on every push.
- Match the surrounding code style.

## Reporting bugs

Open an issue with your macOS version, what you expected, and what happened. If the usage numbers look wrong, note whether you're on a Pro, Max, or free plan — the response shape can differ.

Please **never** paste your `sessionKey` (or any part of it) into an issue. It's a full-access credential.
