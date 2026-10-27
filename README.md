# DRTV (uofficiel) — Roku

Personal, unofficial client for DR's DRTV. SceneGraph / BrightScript, 1920x1080 UI. Plain `.brs` + XML, compiled and validated
with [brighterscript](https://github.com/rokucommunity/brighterscript). This folder is the whole project: source, build, sideload and a browser emulator.

## Set up a new machine
Prerequisites: **Node.js 18+**, **git**, and `curl` (built into Windows 10+/macOS/Linux).
```
git clone <this repo> roku && cd roku
npm install
npx playwright install chromium     # only for `npm run shot` / `npm run art`
cp .env.example .env                # then fill in DR_USER / DR_PASS (personal build) and ROKU_IP / ROKU_PASSWORD (deploy)
```

## Commands
| Command | What it does |
|---|---|
| `npm run build` | Compile + validate -> `dist/drtv-dev.zip` (the sideload package) |
| `npm run release` | Bump `build_version`, build, and also write `dist/release/drtv-dev-<major.minor.build>.zip` |
| `npm run personal` | **Personal build:** like `build`, but bakes your DR session into the package so the app starts logged in. Logs in to DR with the credentials in `.env` when the saved session is missing or has < 2 h left (`-- --fresh` forces a new login) |
| `npm run login` | Just log in to DR with `.env` and save the session to `.session.json` |
| `npm run deploy` | Personal build + install on your Roku over the network (`.env`: `ROKU_IP`, `ROKU_PASSWORD`). `-- --no-bake` installs a clean package instead |
| `npm run emulator` | Browser emulator at http://localhost:8790/ (arrows, Enter = OK, Esc/Backspace = back) |
| `npm run shot -- ArrowDown Enter` | Headless emulator run that presses keys and saves screenshots to `shots/` |
| `npm run art` | Regenerate the placeholder icon/splash PNGs in `images/` |

Manual install without scripts: enable Developer Mode on the Roku, open `http://<roku-ip>`, log in as `rokudev`, upload `dist/drtv-dev.zip`.

### Enable Developer Mode (once per Roku)
On the remote press Home x3, Up x2, then Right, Left, Right, Left, Right. Accept the terms, set a **webserver password**, reboot. The IP is under Settings > Network.

### Logging in
Put your DR login in `.env` (`DR_USER` / `DR_PASS`; the older `USER` / `PASS` names also work) and run **`npm run personal`** (or `npm run deploy`).
The script logs in to DR in a headless browser, saves the session to `.session.json`, and embeds it in the package as `config/session.json`, so the app starts logged in.
- The app applies the baked session only when it is **newer than the one already on the device**, so **Log ud** really logs out and a newer build brings a fresher session. The app renews the session by itself (tokens last about 11-12 h before renewal).
- A second `npm run personal` reuses `.session.json` while it has more than 2 h left; no new DR login is made.
- **A personal package contains your DR login tokens. Install it only on your own devices and never share or commit it.** `.env`, `.session.json`, `config/` and `dist/` are git-ignored.
- The raw password is **not** put in the package - only the session tokens derived from it.
- **Clean build** (`npm run build`, or `deploy -- --no-bake`): the first start shows a 6-character code to enter on the DR side (device-code login). The emulator keeps its login in the browser.

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
