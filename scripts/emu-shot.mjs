// Runs the app in the browser emulator headlessly, presses keys, and saves screenshots (for quick visual checks).
//   npm run shot -- ArrowDown ArrowDown Enter            screenshots after startup and after each key -> shots/
//   npm run shot -- --noseed                              first-run login screen (ignore .session.json)
// Needs Playwright's Chromium once:  npx playwright install chromium
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { start } from './emulator-server.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
const noseed = args.includes('--noseed');
const keys = args.filter((a) => !a.startsWith('--'));
const outDir = path.join(root, 'shots');
fs.mkdirSync(outDir, { recursive: true });

const server = await start(0);
const url = `http://localhost:${server.address().port}/${noseed ? '?noseed' : ''}`;
const browser = await chromium.launch();
const page = await (await browser.newContext({ viewport: { width: 1700, height: 800 } })).newPage();
const errors = [];
page.on('pageerror', (e) => errors.push(e.message));
await page.goto(url);
await page.waitForTimeout(20000);                       // app start + first data
const screen = page.locator('#display');
const shot = (n) => screen.screenshot({ path: path.join(outDir, `${n}.png`) });
await shot('0-start');
await screen.click({ position: { x: 5, y: 5 } });
for (const [i, k] of keys.entries()) {
  await page.keyboard.press(k);
  await page.waitForTimeout(k === 'Enter' ? 9000 : 500);   // the emulator drops keys that arrive too fast
  await shot(`${i + 1}-${k}`);
}
console.log('status:', await page.textContent('#status'));
console.log('log tail:\n' + (await page.evaluate(() => [...document.querySelectorAll('#log div')].slice(-8).map((d) => d.textContent.slice(0, 160)).join('\n'))));
if (errors.length) console.log('page errors:\n' + errors.join('\n'));
console.log('screenshots in', path.relative(process.cwd(), outDir) || '.');
await browser.close();
server.close();
