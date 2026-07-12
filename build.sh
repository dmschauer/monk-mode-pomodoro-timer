#!/bin/sh
# Builds PomodoroTimer.app using only Command Line Tools (no Xcode needed).
set -e
cd "$(dirname "$0")"

APP=build/PomodoroTimer.app
rm -rf build
mkdir -p "$APP/Contents/MacOS"

swiftc -O -parse-as-library \
    -target arm64-apple-macosx13.0 \
    PomodoroTimer/*.swift \
    -o "$APP/Contents/MacOS/PomodoroTimer"

cp PomodoroTimer/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc signature — required for notification permission to work locally
codesign --force --sign - "$APP"

echo "Built $APP — run with: open $APP"
