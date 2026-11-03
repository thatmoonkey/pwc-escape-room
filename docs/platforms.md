# Platforms: PWA web, Android APK, VR

One project, three deliveries. What follows is what each build is, how to make
it, and the rules that keep the shared code honest across all three.

## The three presets

`export_presets.cfg` carries two presets:

| Preset | Platform | Output | Notes |
| --- | --- | --- | --- |
| `web_pwa` | Web | `build/web/index.html` | Progressive Web App on, canvas resize, virtual keyboard on for touch devices |
| `android_apk` | Android | `build/android/adamant-verity.apk` | Gradle build, arm64-v8a, OpenXR enabled, package `com.pwc.adamantverity` |

VR is not a separate preset: the desktop and Android presets both run the
OpenXR path when a headset runtime is present, and fall back to the flat game
when it is not (`GameState` and `InputMode` both detect it; the launch screen's
VR chip reports a clean refusal when no runtime exists).

## Web (PWA)

- The export must be served over **https** (or `localhost`). The preset asks for
  cross-origin isolation headers because the audio and XR code can use threads;
  if the host can set headers, send:
  `Cross-Origin-Opener-Policy: same-origin` and
  `Cross-Origin-Embedder-Policy: require-corp`.
- `html/experimental_virtual_keyboard=true` is what raises the on-screen
  keyboard for the leaderboard fields on a phone browser. Do not turn it off.
- The game writes progress to `user://`, which the browser keeps in IndexedDB
  for that origin. Saving progress, the leaderboard and the settings all work
  offline once the PWA is installed.
- PWA icons are left empty, which makes Godot fall back to the project icon.
  Supply `icon_144x144`, `icon_180x180` and `icon_512x512` PNGs before a public
  launch if the client wants a branded install icon.

## Android APK

- Export with **Gradle build** on (an `android/build` directory is committed for
  exactly that) and a release keystore configured in the editor's Android
  settings. The debug keystore is fine for internal testing only.
- Only `arm64-v8a` is built. Add `armeabi-v7a` in the preset if older tablets
  matter.
- `screen/immersive_mode` keeps the navigation bar out of the game; the display
  orientation is fixed to landscape in `project.godot`
  (`display/window/handheld/orientation = 0`).
- Back gesture: `application/run/quit_on_go_back=false` and `game.gd`'s
  `_notification(NOTIFICATION_WM_GO_BACK_REQUEST)` close one layer at a time -
  completion screen, terminal, read-back card, intro, pause menu - before the
  app is allowed to close at the title card.

## VR

- OpenXR is enabled (`xr/openxr/enabled=true`), the XR rig lives at
  `res://scenes/player/xr_rig.tscn`, and `game.gd` swaps it in when the mode
  layer chooses VR. The environment is duplicated for XR with screen-space
  effects (glow, SSAO) switched off, which is what stops them resolving
  differently in each eye.
- **Known limit.** The 2D layer is a set of `CanvasLayer`s drawn over the
  viewport. In a headset the 3D render is the headset's; the flat overlays are
  not a world-space panel yet. The terminal, cards and the completion screen
  are readable on the desktop mirror, and every one of them is drivable by a
  controller ray (E/trigger/pointer), but a true in-headset UI needs the overlay
  rendered into a `SubViewport` and placed on a quad in front of the player.
  That is the next VR milestone, not a regression: nothing in the current
  screens depends on a mouse or a keyboard.
- The completion screen's form is the one place a keyboard is genuinely needed.
  In VR it pre-fills the name from the callsign and accepts a run without a
  contact, so a headset crew can still put their score on the board.

## Code rules that keep the three builds honest

1. **Ask `Platform`, not the OS.** `scripts/systems/platform.gd` answers which
   build is running (`DESKTOP`, `WEB`, `ANDROID`, `VR`), whether the pointer is a
   thumb, and what type scale and touch target that implies. New screens use
   `Platform.ui_scale()` and `Platform.touch_target()` rather than their own
   multipliers.
2. **Every overlay works with a pointer only.** Click, tap or a controller ray.
   ESC is a convenience, never the only way out of a screen.
3. **No keyboard-only step.** A field is allowed to exist; a field that must be
   filled to continue is not. The leaderboard accepts a run without contact
   details when `Platform.can_type()` is false.
4. **The panel caps itself and scrolls inside.** Overlays clamp to the viewport
   and scroll their content, so the same screen survives a 16:9 desktop, a
   portrait phone and a browser window the size of a postcard.
5. **No desktop-only API without a guard.** Anything from `Input.mouse_mode`,
   file dialogs or window management is behind a feature check or harmless on a
   platform that ignores it.
