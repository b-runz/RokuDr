# DRTV (uofficiel) — Roku dev build

Personal, unofficial client for DR's DRTV. SceneGraph / BrightScript, 1920x1080 UI. Plain `.brs` + XML (validated with `brighterscript`).

## Build
This repository contains only the Roku app. From this folder:
```
npm install
npm run build        # compiles with brighterscript -> dist/drtv-dev.zip (the sideload package)
```
(`dist/` and `node_modules/` are git-ignored.) The surrounding workspace also has helper scripts - `tools/build-roku.mjs` (`--release` bumps `build_version` and writes `dist/release/drtv-dev-<version>.zip`),
`tools/deploy-roku.mjs` (sideload over the network) and a browser emulator - but those live outside this repo.

## Try it in the browser emulator (no Roku needed)
```
node server/server.mjs           # then open http://localhost:8787/emulator/
```
Arrow keys, Enter = OK, Esc/Backspace = back. The emulator starts you logged in with the dev server's DR session; use
`http://localhost:8787/emulator/?noseed` to see the first-run device-code login. It is an approximation of a real Roku
(fonts, row spacing, image loading and video differ).

## Run it on your Roku
1. **Enable developer mode** (once): on the Roku remote press Home x3, Up x2, Right, Left, Right, Left, Right. Accept the terms, set a **webserver password**, reboot. Note the Roku's IP (Settings > Network).
2. Put two lines in `.env` (git-ignored): `ROKU_IP=...` and `ROKU_PASSWORD=...`
3. `node tools/deploy-roku.mjs` installs and starts it. Or open `http://<roku-ip>` in a browser, log in as `rokudev`, upload `dist/drtv-dev.zip`.
4. **Log in** on first start: the TV shows a 6-character code. In DR's phone app choose "Log ind på TV" and enter it.
   Shortcut: `node tools/deploy-roku.mjs --seed` launches the app already logged in with the local dev server's DR session.
5. Debug log: `telnet <roku-ip> 8085`.

## Screens
FORSIDE (Mine serier banner, Dine serier, one Udforsk row, then DR's editorial rows) · SERIER (Mine serier / Alle / A–Å) · UDFORSK · KATEGORIER · BØRN · ULTRA · LIVE (channel picker, up/down zaps) · SØG · series/episode page (FORTSÆT / NÆSTE AFSNIT, seasons) · player (native captions styled via `captionStyle`, press `*` for the subtitle/language panel, position sync to DR, next-episode card).

## Layout
`source/main.brs` entry · `components/lib` (Util, Api, Rows) · `components/tasks` (ApiTask, MineTask: all network work) · `components/ui` (DrItem, TopNav, ActionBar) · `components/screens` (RowScreen base, BrowseScreen, DetailScreen, PlayerScreen, LiveScreen, LoginScreen, SearchScreen) · `components/MainScene`.

## Not verified on a real device yet
Row label spacing in RowList, built-in font sizes, `captionStyle` look, HLS start-up behaviour (the first-minutes choppiness), device-code login with a Roku-specific device type.
