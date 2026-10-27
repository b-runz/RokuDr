// Logs in to DRTV (in a headless browser, with the credentials from .env) and saves the DR session to .session.json.
//   npm run login
// The session is what `npm run personal` / `npm run deploy` bake into the package. Credentials and tokens are never printed.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { drCredentials, root } from './env.mjs';

const claims = (jwt) => { try { return JSON.parse(Buffer.from(jwt.split('.')[1], 'base64url').toString()); } catch { return {}; } };

export async function drLogin({ user, pass }, { headless = true, log = console.log } = {}) {
  if (!user || !pass) throw new Error('No DR login in .env. Add DR_USER and DR_PASS (see .env.example).');
  const { chromium } = await import('playwright');   // loaded lazily so clean builds don't need a browser
  const tokens = new Set();
  const browser = await chromium.launch({ headless });
  try {
    const page = await (await browser.newContext({ locale: 'da-DK' })).newPage();
    page.on('request', (r) => {
      if (!/dr-massive\.com/.test(r.url())) return;
      const t = r.headers()['x-authorization'];
      if (t) tokens.add(t);
    });
    await page.goto('https://www.dr.dk/drtv/', { waitUntil: 'domcontentloaded' });
    await page.getByRole('button', { name: /accepter|tillad alle|accept/i }).first().click({ timeout: 8000 }).catch(() => {});
    await page.getByText(/log ind/i).first().click({ timeout: 15000 }).catch(() => log('could not find the "Log ind" button'));
    await page.waitForURL(/login\.dr\.dk|accounts?\./, { timeout: 30000 }).catch(() => {});
    await page.locator('input[type=email], input[name=username], input[name=email]').first().fill(user, { timeout: 20000 });
    if (!(await page.locator('input[type=password]:visible').count()))     // some flows ask for the password on a second step
      await page.getByRole('button', { name: /fortsæt|næste|continue|next/i }).first().click().catch(() => {});
    await page.locator('input[type=password]').first().fill(pass, { timeout: 20000 });
    await page.locator('button[type=submit]:visible, button:has-text("Log ind"):visible').first().click();
    await page.waitForURL(/dr\.dk\/drtv/, { timeout: 60000 }).catch(() => log('did not return to DRTV (wrong password, MFA or captcha?)'));
    await page.waitForLoadState('networkidle').catch(() => {});
    await page.goto('https://www.dr.dk/drtv/', { waitUntil: 'networkidle' }).catch(() => {});
  } finally {
    await browser.close();
  }

  // pick, per kind, the captured token that lives longest. Profile tokens carry defaultUserProfileId.
  let acc, pro;
  for (const t of tokens) {
    const c = claims(t);
    if (!c.exp) continue;
    const slot = c.defaultUserProfileId ? 'pro' : 'acc';
    const cur = slot === 'pro' ? pro : acc;
    if (!cur || c.exp > cur.exp) (slot === 'pro' ? (pro = { t, exp: c.exp }) : (acc = { t, exp: c.exp }));
  }
  if (!acc || !pro) throw new Error(`Login did not yield both tokens (got ${acc ? 'account' : 'no account'}, ${pro ? 'profile' : 'no profile'}). Check the credentials.`);
  return { accT: acc.t, accE: String(acc.exp), proT: pro.t, proE: String(pro.exp), deviceId: crypto.randomUUID() };
}

export const sessionFile = path.join(root, '.session.json');
export const readSession = () => { try { return JSON.parse(fs.readFileSync(sessionFile, 'utf8')); } catch { return null; } };
export const sessionLeft = (s) => (s && s.proE && s.accE ? Math.min(Number(s.proE), Number(s.accE)) - Date.now() / 1000 : -1);   // seconds

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const s = await drLogin(drCredentials(), { headless: !process.env.HEADFUL });
  fs.writeFileSync(sessionFile, JSON.stringify(s));
  console.log(`Saved .session.json (valid for about ${Math.round(sessionLeft(s) / 3600)} h; the app renews it).`);
}
