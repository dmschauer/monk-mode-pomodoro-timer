#!/bin/sh
# Builds MonkModePomodoroTimer.app using only Command Line Tools (no Xcode needed).
set -e
cd "$(dirname "$0")"

APP=build/MonkModePomodoroTimer.app
rm -rf build
mkdir -p "$APP/Contents/MacOS"

swiftc -O -parse-as-library \
    -target arm64-apple-macosx13.0 \
    MonkModePomodoroTimer/*.swift \
    -o "$APP/Contents/MacOS/MonkModePomodoroTimer"

cp MonkModePomodoroTimer/Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
cp MonkModePomodoroTimer/Resources/* "$APP/Contents/Resources/"

# Ad-hoc signature — required for notification permission to work locally
codesign --force --sign - "$APP"

echo "Built $APP — run with: open $APP"
