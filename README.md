# monk-mode-pomodoro-timer

Dead simple, 100% offline Pomodoro timer that lives in the macOS menu bar.
No accounts, no network, no Dock icon. Settings and session counts are stored
locally in `UserDefaults`.

## Build & run

Requires macOS 13+ and Apple's Command Line Tools (no Xcode needed):

```sh
xcode-select --install   # only if you don't have the tools yet
./build.sh
open build/MonkModePomodoroTimer.app
```

The timer appears in the menu bar as `25:00`. Click it for the popover;
click the ring to start or pause. Allow notifications when prompted so you
get an alert when a session ends. Right-click the menu bar timer to quit
(there's no Dock icon).

# Install in Launchpad

`cp -R build/MonkModePomodoroTimer.app /Applications/`

## Start at login (optional)

System Settings → General → Login Items → **+** → select
`build/MonkModePomodoroTimer.app`. Tip: copy the app to `/Applications` first so it
survives a `./build.sh` rebuild wiping `build/`.

## Settings

Click the gear in the popover: work/rest lengths, sessions per set,
light/dark/auto appearance, and whether your working title shows next to the
countdown in the menu bar. Everything persists in `UserDefaults`.
