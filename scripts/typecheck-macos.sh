#!/bin/zsh
# Typechecks the app's Swift code against the macOS SDK (macOS 14 ≈ iOS 17 APIs).
# Useful without Xcode installed, or as a fast check. The real build is the iOS one in Xcode.
set -euo pipefail
ROOT="${0:A:h:h}"
cd "$ROOT/Packages/LessonKit"
swift build -q
MODULES="$(swift build --show-bin-path)/Modules"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
cd "$ROOT"
xcrun swiftc -typecheck -parse-as-library -swift-version 5 \
  -target arm64-apple-macos14.0 -sdk "$SDK" -I "$MODULES" \
  $(find App -name '*.swift' | sort)
echo "✓ App typechecks (macOS 14 target)"
