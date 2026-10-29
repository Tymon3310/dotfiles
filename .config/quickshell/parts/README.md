# QuickShell parts

The building blocks of the shell: services, cards, the notification stack, the
lock screen and the scripts behind them. `../shell.qml` creates the desktop
bars, the notification overlays, the session fade, the lock screen and the
screenshot IPC launcher; QML services are singletons and start their workers
when something uses them.

This folder began as a copy of [impasto](https://github.com/andreumassanet/impasto)
by Andreu Massanet (GPL-3.0, see [LICENSE](LICENSE)). Most of it has since
been rewritten or written here; [Origins](#origins) lists which files still
carry impasto's code. The folder as a whole stays under GPL-3.0.

## Layout

| Location | Responsibility |
|---|---|
| `../components/IslandBar.qml` | Per-monitor island: geometry, menus, OSD, notification popups |
| `../components/IslandMotion.qml` | Startup, lock and unlock choreography |
| `../components/IslandRestRow.qml` | Resting media, spectrum, clock and date |
| `../components/IslandDashboard.qml` | Calendar and clock, media and lyrics, weather, notifications, agents, audio, link, system and session cards |
| `../components/NotificationHeadsUp.qml` | Notification popups over a fullscreen window |
| `bar/island/` | Notification card and stack, agent alert, recording indicator, session panel |
| `bar/island/controls/` | Dashboard cards, power row and tray menus |
| `bar/modules/` | Volume and Bluetooth controls used by the dashboard |
| `bar/widgets/` | Workspace dots and system tray |
| `components/` | Shared controls and visual primitives |
| `lock/` | The lock screen, one part per monitor (see [Lock](#lock)) |
| `services/` | State, workers and their ownership |
| `scripts/` | Workers: lyrics, weather, stats, ping, privacy, agents, Cava config |
| `theme/Theme.qml` | Shell settings applied to the shared design tokens |
| `../shared/` | Design tokens and notch geometry, shared with the screenshot tool |
| `../lock-preview.qml` | Shows the lock screen on one monitor without locking, for design work |

The dashboard instantiates the cards it uses directly; there is no module
catalogue or string-based router.

## Services

- **Notifications:** `NotificationService` owns `org.freedesktop.Notifications`.
  Each notification is a plain entry in one table (`entries`, read through
  `entry(key)`); the live server objects are kept apart, since the server
  deletes them when their application closes them. Two ListModels say what
  is shown, by key, and change in place: `popups` (newest first, three at a
  time, the rest queued) and `groups` (the history, one row per application).
  A replaced notification updates in place. Popups show on the monitor that
  had focus when the first arrived, until the stack empties. The history
  (50 entries) is kept in `$XDG_RUNTIME_DIR` across reloads and restarts.
  `quickshell ipc call notifications dismiss|clear|toggleDnd`.
- **OSD:** `OsdService` owns the island OSD state; `IslandBar` binds to it and
  suspends it while expanded. Producers call `OsdService.requested(...)`:
  volume and mute, lock keys, headset events, and headset-connection notices
  that `NotificationService` turns into an OSD. `OsdService` owns
  `../scripts/osd.py locks` and `HeadsetService` owns `../scripts/osd.py
  headset`; reroutes and flapping connections are debounced.
- **Media:** `MediaService` follows Spotify or MPV over MPRIS. Spotify volume
  uses its PipeWire streams. Position polling (and its 50 ms mode for synced
  lyrics) and Cava run only while something subscribes.
- **Lyrics:** `LyricsService` runs `scripts/lyrics.py` (LRCLIB, cached under
  `~/.cache/quickshell/lyrics`). Synced lyrics with fewer than five lines count
  as a stub, so a fuller record wins.
- **Spotify queue:** `SpotifyQueueService` owns `../scripts/spotify_queue.py`,
  which asks the Web API for the queue on track changes and every 45 s. One
  worker talks to Spotify at a time across every QuickShell running (a lock
  file in `$XDG_RUNTIME_DIR`), and a worker exits with the shell that started
  it. Credentials come from `../scripts/spotify_auth.py`; playback works
  without them.
- **Agents:** `AgentService` runs `scripts/agent_monitor.py`, which reads
  Claude Code sessions (written by the `scripts/claude_status.sh` hook) and
  OpenCode windows (the `scripts/opencode-agent-status` plugin) and reports
  each session's state for the island badge, the dashboard card and the lock.
- **Recording:** `ScreenRecorderService` drives gpu-screen-recorder for the
  island indicator; `scripts/recording-saved.sh` is its save hook.
- **Privacy, ping, stats, weather:** `PrivacyService` (microphone and camera
  in use), `PingService` (`scripts/ping.py`), `StatsService`
  (`scripts/stats.py`) and `WeatherService` (`scripts/weather.py`, wttr.in)
  each run their worker only while subscribed, or on a slow poll.
- **Lock:** `LockService` drives the session lock, the frozen screenshots,
  face unlock (biopass) and the password. `IslandMetrics` gives the lock
  screen the desktop notch size without building a hidden desktop.
- **Hyprland:** `HyprlandService` keeps its own socket requests for the
  workspace and monitor state the native module lacks. Each request is one
  short connection; Hyprland closing it would log a warning, which the shell
  mutes with `--log-rules` at start (see `hypr/conf/autostart.lua`).
- **Settings:** `SettingsService` holds the preferences the parts read, as
  plain properties. Nothing is persisted.

## Lock

`lock/LockScreen.qml` puts a `LockSurface` on every monitor. Each one plays a
part, chosen from which screen you unlock on and the others' order left to
right, so three monitors read as one lock instead of three copies:

- **main**, where you unlock: the clock (`LockClock`) with the date, weather
  and a line for agents and notifications that arrived while locked, the
  password (`LockAccount`) and the power buttons. With a single monitor it
  also shows the music (`LockMedia`, `LockLyrics`).
- **stage** (`LockStage`): the album art, large, with the track, a visualizer
  and synced lyrics; with nothing playing, the day as a calendar page.
- **info** (`LockInfo`): the weather and the hours ahead, the agents, what
  arrived while away (app names only) and the month (`MonthGrid`).

The frozen desktop goes out of focus as the lock arrives (the blur strength
animates) and the clock lines rise in one after another; unlocking plays it
backwards onto the live desktop. `MonthGrid.qml` has a twin in the SDDM theme
(`sddm/themes/nocturne/components/`); keep them the same.

## Screenshots

`../components/ScreenshotLauncher.qml` owns the `screenshot` IPC target and
loads `../screenshot/shell.qml` with fresh state for each request (`trigger`,
`open`, `instant`, `window`, `screen`, `ocr`, `lens`, `ai`). The screenshot
shell coordinates capture, stitching, processing and cleanup;
`CaptureOverlay`, `RegionSelection` and `CaptureToolbar` own the UI. It also
runs standalone with `QS_MODE`, `QS_INSTANT` and `QS_ID`. Per-output capture
and deferred frozen overlays work around Hyprland's screencopy; its theme
extends the same shared tokens.

## Origins

How much of impasto's code each file still carries, measured against
upstream (shared lines, in order, ignoring comments and blank lines; under
about half is common QML boilerplate rather than shared code).

**Mostly impasto** (75% or more):
`components/Sparkline.qml`, `components/Padlock.qml`,
`components/RingIndicator.qml`, `components/UsageBar.qml`,
`components/PillButton.qml`, `components/IconButton.qml`,
`bar/island/controls/WeatherCard.qml`, `bar/island/SessionPanel.qml`,
`lock/LockPower.qml`, `services/BluetoothService.qml`,
`services/WeatherService.qml`, `services/StatsService.qml`,
`services/AudioService.qml`, `scripts/weather.py`, `scripts/cava.conf`,
`scripts/privacy_monitor.py` (from impasto's `privacy.py`).

**Reworked from impasto** (about half kept):
`components/Card.qml`, `components/StatCard.qml`, `components/NotchFillet.qml`,
`components/Avatar.qml`, `bar/island/controls/CalendarCard.qml`,
`lock/LockAccount.qml`, `services/CavaService.qml`,
`services/AccountService.qml`, `services/PrivacyService.qml`,
`scripts/stats.py`.

**Rewritten or written here:** everything else, including the notification
service and cards, the lock surface and its parts, the island, OSD, media,
lyrics, Hyprland, recorder, agent, headset, ping and Spotify services, the
dashboard's media, audio, link, system and agent cards, and the volume and
Bluetooth modules.
