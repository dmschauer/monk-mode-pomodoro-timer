# monk-mode-pomodoro-timer

Dead simple, 100% offline Pomodoro timer that lives in the macOS menu bar.
No accounts, no network, no Dock icon. Settings and session counts are stored
locally in `UserDefaults`.

## Build & run

Requires macOS 13+ and Apple's Command Line Tools (no Xcode needed):

```sh
xcode-select --install   # only if you don't have the tools yet
./build.sh
open build/PomodoroTimer.app
```

The timer appears in the menu bar as `25:00`. Click it for the controls and
task list. Allow notifications when prompted so you get an alert when a
session ends. Quit via the Quit button in the popover (there's no Dock icon).

## Start at login (optional)

System Settings → General → Login Items → **+** → select
`build/PomodoroTimer.app`. Tip: copy the app to `/Applications` first so it
survives a `./build.sh` rebuild wiping `build/`.

## Changing work/break lengths

There's no settings UI yet; the values are persisted in `UserDefaults`:

```sh
defaults write com.dominik.pomodorotimer workMinutes 50
defaults write com.dominik.pomodorotimer breakMinutes 10
```

Restart the app after changing them.
