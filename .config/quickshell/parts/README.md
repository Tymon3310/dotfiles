# parts

Top-bar pieces extracted from [impasto](https://github.com/andreumassanet/impasto)
(GPL-3.0, see `LICENSE`; headers kept), plus the tray from this repo's own bar.
Nothing here is placed yet: `shell.qml` does not import it, so it costs nothing
until the dashboard uses it.

Folder layout mirrors impasto's, so its relative imports work unchanged.
Import what you need from `shell.qml` or a component:

```qml
import "parts/theme"
import "parts/services"
import "parts/components"
import "parts/bar/modules"
import "parts/bar/widgets"
import "parts/bar/island"
import "parts/bar/island/controls"
```

## What there is

| Piece | File | Notes |
|---|---|---|
| Chip for any module | `bar/modules/ChipFace.qml` | `ChipFace { moduleId: "volume" }` — glyph + figure, `shape: "ring"` for the gauge |
| Module (chip or detail) | `bar/modules/Module.qml` | `Module { moduleId: "network"; compact: false }` — the detail view |
| Ids | | `clock media volume network bluetooth battery brightness stats weather calendar notifications` |
| Workspace dots | `bar/widgets/WorkspacesWidget.qml` | chromeless by default |
| Tray | `bar/widgets/TrayWidget.qml` | emits `menuRequested(menu, centerX)` |
| Tray menu | `bar/island/controls/TrayMenuList.qml` | `TrayMenuList { menu: … }`, submenus, `contentHeight` |
| Power menu | `bar/island/SessionPanel.qml` | big tiles, arrows + Enter, destructive ones ask twice |
| Power row | `bar/island/controls/PowerRow.qml` | compact version, same confirmation |
| Calendar | `bar/island/controls/CalendarCard.qml` | month grid, wheel pages (tasks removed) |
| Notifications | `bar/island/controls/NotificationList.qml`, `bar/island/NotificationLayer.qml` | history list; the one just arrived |
| Weather | `bar/island/controls/WeatherCard.qml`, `bar/modules/WeatherModule.qml` | wttr.in |
| Player | `bar/island/controls/MediaCard.qml`, `bar/modules/MediaModule.qml` | Spotify MPRIS only |
| Notch fillet | `components/NotchFillet.qml` | the curve where the island meets the screen edge |
| Spacer | `components/IslandSpacer.qml` | `kind: "dot" / "line" / "gap"`, between parts in one island |

Chips and cards draw no capsule of their own: the host draws the one black
island (`Theme.island`) and lays the parts out in a Row with `IslandSpacer`s.

## Hookups

- **Notifications** — `services/NotificationService.qml` is impasto's daemon,
  unchanged: it owns `org.freedesktop.Notifications` itself (history, timeouts,
  do-not-disturb, critical ones stay). `bar/island/NotificationLayer.qml` draws
  the current one; `IslandBar` shows it under the row.
- **Settings** — `services/SettingsService.qml` is a stand-in with plain
  properties (bar height 30, clock format, fonts, weather place, chip shape…).
  Not saved; edit the defaults there.
- **Power actions** — `services/SessionService.qml` runs the same commands as
  nwg-bar / hypridle (hyprlock, systemctl, `hl.dsp.exit()`).
- **Scripts** — `parts/scripts/` (stats, weather, network, cava). Services only
  start when something uses them.

## Changes from impasto

- `SettingsService`, `ModuleService` trimmed to what these parts read
- `MediaService` filtered to Spotify (playerctld excluded)
- `SessionService` without impasto's lock screen
- `NetworkService` reads the cable from nmcli (Quickshell 0.3 lists Wi-Fi only)
- `CalendarCard` without the task board
- `Theme.accent` / `Theme.blue` set to the dotfiles blue `#0070D8`
- Script paths under `parts/scripts/`
