# QuickShell parts

Shell components derived from [impasto](https://github.com/andreumassanet/impasto),
licensed under GPL-3.0 (see [LICENSE](LICENSE)). Upstream attribution is retained
in the derived sources. The tray and the shell integration come from this repository.

These parts are used by the running shell. The root `../shell.qml` creates the
desktop bars, notification overlays, session fade, lock screen and screenshot
IPC launcher. QML services are singletons and start their workers when used.

## Layout

| Location | Responsibility |
|---|---|
| `../components/IslandBar.qml` | Per-monitor panel geometry, menus and OSD |
| `../components/IslandMotion.qml` | Startup, lock and unlock choreography |
| `../components/IslandRestRow.qml` | Resting media, spectrum, clock and date |
| `../components/IslandDashboard.qml` | Calendar, media/lyrics, weather, notifications, volume, link statistics, Bluetooth, system and session cards |
| `bar/modules/` | Volume and Bluetooth controls used directly by the dashboard |
| `bar/widgets/` | Workspace dots and system tray |
| `bar/island/` | Notification stack and session panel |
| `bar/island/controls/` | Dashboard cards, power controls and tray menus |
| `components/` | Shared controls and visual primitives |
| `lock/` | Session lock surfaces, authentication and account controls |
| `services/` | Application state, notifications and worker ownership |
| `scripts/` | Lyrics, weather, system/link statistics, ping and Cava configuration |
| `theme/Theme.qml` | Shell settings applied to the common design tokens |
| `../shared/` | Design tokens and notch geometry shared with screenshots |

The dashboard instantiates the controls it uses directly. There is no separate
chip catalogue or string-based module router.

## Services

- **Media:** `MediaService` selects Spotify or MPV through native MPRIS.
  Spotify volume uses its PipeWire streams; MPV uses MPRIS volume. Position
  polling and Cava run while subscribed UI needs them.
- **Spotify queue:** `SpotifyQueueService` owns `../scripts/spotify_queue.py`.
  The worker watches Spotify metadata changes and polls the Web API queue
  every eight seconds. It emits only changed queue snapshots. Credentials
  retain the format and paths written by `../scripts/spotify_auth.py`.
  Queue retrieval is optional; playback controls do not require Web API credentials.
- **Notifications:** `NotificationService` owns
  `org.freedesktop.Notifications`, tracks live objects separately from history,
  and maintains up to three shown banners plus a waiting queue. It restores
  banner deadlines during reloads within the same QuickShell instance.
  The root shell stops swaync so the name can be acquired.
- **Settings:** `SettingsService` contains the preferences currently used by
  the shell. They are not persisted. Do Not Disturb belongs to
  `NotificationService`, alongside notification lifecycle state.
- **Lock:** `LockService` coordinates native session locking and authentication.
  `IslandMetrics` provides desktop notch dimensions to the lock screen without
  constructing a hidden copy of the desktop UI.
- **Hyprland:** `HyprlandService` retains its socket and batched hyprctl
  workaround for incomplete native monitor/workspace state.

## Screenshots

`../components/ScreenshotLauncher.qml` owns the `screenshot` IPC target and
loads `../screenshot/shell.qml` with fresh state for each request. Existing
`trigger`, `open`, `instant`, `window`, `screen`, `ocr`, `lens` and `ai`
methods are retained.

The screenshot shell coordinates capture, stitching, processing and cleanup.
`CaptureOverlay`, `RegionSelection` and `CaptureToolbar` own the screen UI.
The tool can also run standalone, using its existing `QS_MODE`, `QS_INSTANT`
and `QS_ID` environment interface. IPC requests use their supplied parameters
instead of inheriting standalone launch overrides.

Per-output capture and deferred frozen overlays preserve the Hyprland
screencopy workaround. Screenshot theme defaults extend the same shared tokens
as the desktop, with their existing larger notch corner.
