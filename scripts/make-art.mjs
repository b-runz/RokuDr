// Regenerates the placeholder channel icon + splash PNGs in images/ (needs Playwright's Chromium).
//   npm run art
import { chromium } from 'playwright';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const out = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', 'images');
const art = (w, h, big, small) => `<html><body style="margin:0;width:${w}px;height:${h}px;background:#ff0018;display:grid;place-items:center;font-family:Segoe UI,Arial,sans-serif;color:#fff;text-align:center"><div><div style="font-size:${big}px;font-weight:800;letter-spacing:2px;line-height:1">DRTV</div><div style="font-size:${small}px;opacity:.9;margin-top:${small * 0.3}px">uofficiel</div></div></body></html>`;
const browser = await chromium.launch();
const page = await browser.newPage();
for (const [name, w, h, big, small] of [['icon_hd', 290, 218, 84, 28], ['icon_sd', 246, 140, 60, 22], ['splash_hd', 1920, 1080, 260, 64]]) {
  await page.setViewportSize({ width: w, height: h });
  await page.setContent(art(w, h, big, small));
  await page.screenshot({ path: path.join(out, `${name}.png`) });
}
await browser.close();
console.log('images/ regenerated');
