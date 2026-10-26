# DRTV (uofficiel) — Roku

Personal, unofficial client for DR's DRTV. SceneGraph / BrightScript, 1920x1080 UI. Plain `.brs` + XML, compiled and validated
with [brighterscript](https://github.com/rokucommunity/brighterscript). This folder is the whole project: source, build, sideload and a browser emulator.

## Set up a new machine
Prerequisites: **Node.js 18+**, **git**, and `curl` (built into Windows 10+/macOS/Linux).
```
git clone <this repo> roku && cd roku
npm install
npx playwright install chromium     # only for `npm run shot` / `npm run art`
cp .env.example .env                # then fill in ROKU_IP and ROKU_PASSWORD (only needed for `npm run deploy`)
```

## Commands
| Command | What it does |
|---|---|
| `npm run build` | Compile + validate -> `dist/drtv-dev.zip` (the sideload package) |
| `npm run release` | Bump `build_version`, build, and also write `dist/release/drtv-dev-<major.minor.build>.zip` |
| `npm run deploy` | Build and install on your Roku over the network (`.env`: `ROKU_IP`, `ROKU_PASSWORD`) |
| `npm run deploy -- --seed` | Same, then start the app already logged in using `.session.json` |
| `npm run emulator` | Browser emulator at http://localhost:8790/ (arrows, Enter = OK, Esc/Backspace = back) |
| `npm run shot -- ArrowDown Enter` | Headless emulator run that presses keys and saves screenshots to `shots/` |
| `npm run art` | Regenerate the placeholder icon/splash PNGs in `images/` |

Manual install without scripts: enable Developer Mode on the Roku, open `http://<roku-ip>`, log in as `rokudev`, upload `dist/drtv-dev.zip`.

### Enable Developer Mode (once per Roku)
On the remote press Home x3, Up x2, then Right, Left, Right, Left, Right. Accept the terms, set a **webserver password**, reboot. The IP is under Settings > Network.

### Logging in
First start shows a 6-character code: in DR's phone app choose "Log ind på TV" and enter it. The emulator keeps its login in the browser.
To skip that (emulator and `deploy --seed`), put a DR session in `.session.json` (git-ignored): `{"accT":"…","accE":"…","proT":"…","proE":"…","deviceId":"…"}`.
With the author's local dev server running: `curl http://localhost:8787/session.json -o .session.json`.

## Layout
- `manifest`, `source/main.brs` — entry point
- `components/lib` — `Util` (helpers), `Api` (DR "Massive" API client, tokens), `Rows` (row/tile building)
- `components/tasks` — `ApiTask`, `MineTask` (all network work runs here, off the UI thread)
- `components/ui` — `DrItem` (tiles), `TopNav`, `ActionBar`, `KeyItem` (keyboard keys)
- `components/screens` — `RowScreen` (base) → `BrowseScreen` / `LiveScreen`; `DetailScreen`, `PlayerScreen`, `LoginScreen`, `SearchScreen`; `components/MainScene`
- `scripts/` — build, deploy, emulator server, screenshot and art tools · `emulator/` — the emulator page

## Screens
FORSIDE (Mine serier banner, Dine serier, one Udforsk row, then DR's editorial rows) · SERIER (Mine serier / Alle / A–Å) · UDFORSK · KATEGORIER · BØRN · ULTRA · LIVE (channel picker, up/down zaps) · SØG (own Danish QWERTY keyboard) · series/episode page (FORTSÆT / NÆSTE AFSNIT, seasons) · player (native captions styled via `captionStyle`, `*` opens the subtitle/language panel, position sync to DR, next-episode card).

## Notes
- The emulator is an approximation of a real Roku (fonts, row spacing, image loading and video differ). It needs a browser with SharedArrayBuffer support (Chrome/Edge/Firefox current versions).
- Gotchas found while building: `Stop`, `next`, `pos` are reserved words in BrightScript; `roArray.SortBy` is replaced by `SortAA` in `Util.brs`; text uses built-in `font:…SystemFont` names (the emulator ignores `<Font>` nodes).
- Not yet verified on a physical Roku: row label spacing, font sizes, `captionStyle` look, first-minutes HLS behaviour.
