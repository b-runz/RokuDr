// Builds and sideloads dist/drtv-dev.zip onto a Roku that is in developer mode.
//   npm run deploy                 build + install. If .session.json exists the build is BAKED with your DR session (starts logged in);
//                                  if the local dev server is running, the session is refreshed from it first.
//   npm run deploy -- --no-bake    install a clean package (log in with the TV code)
//   npm run deploy -- --seed       additionally launch via ECP with the session (only needed for a clean package)
// Reads ROKU_IP and ROKU_PASSWORD from the environment or from .env in this folder. The password is never printed.
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const env = { ...process.env };
try {
  for (const line of fs.readFileSync(path.join(root, '.env'), 'utf8').split(/\r?\n/)) {
    const i = line.indexOf('=');
    if (i > 0 && !line.trim().startsWith('#')) env[line.slice(0, i).trim()] ??= line.slice(i + 1).trim().replace(/^["']|["']$/g, '');
  }
} catch { /* no .env */ }
const ip = env.ROKU_IP, pass = env.ROKU_PASSWORD;
if (!ip || !pass) {
  console.error('Copy .env.example to .env and fill in ROKU_IP and ROKU_PASSWORD (the developer-mode webserver password), then run again.');
  process.exit(1);
}

const sessionFile = path.join(root, '.session.json');
const wantBake = !process.argv.includes('--no-bake') && fs.existsSync(sessionFile);
if (wantBake) { // freshest session if the author's dev server is up; otherwise keep the saved one
  try {
    const r = await fetch(env.SESSION_URL || 'http://localhost:8787/session.json', { signal: AbortSignal.timeout(2500) });
    const j = r.ok ? await r.json() : null;
    if (j?.accT && j?.proT) { fs.writeFileSync(sessionFile, JSON.stringify(j)); console.log('Refreshed .session.json from the dev server.'); }
  } catch { /* dev server not running: use the saved session */ }
}
execFileSync(process.execPath, [path.join(root, 'scripts', 'build.mjs'), ...(wantBake ? ['--bake'] : [])], { stdio: 'inherit' });

// Roku's installer uses HTTP digest auth, user "rokudev". Credentials go to curl on stdin, not on the command line.
const curl = process.platform === 'win32' ? 'curl.exe' : 'curl';
const out = execFileSync(curl, ['-s', '--digest', '--config', '-', '-F', 'mysubmit=Install', '-F', `archive=@${path.join(root, 'dist', 'drtv-dev.zip')}`, `http://${ip}/plugin_install`],
  { input: `user = "rokudev:${pass}"\n`, encoding: 'utf8' });
const ok = /Install Success|Identical to previous version|Application Received/i.test(out);
console.log(ok ? `Installed on ${ip}.` : 'Install did not report success. Check the IP, the password, and that Developer Mode is enabled.\n' + out.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').slice(0, 400));

if (ok && process.argv.includes('--seed')) {
  let s;
  try { s = JSON.parse(fs.readFileSync(path.join(root, '.session.json'), 'utf8')); } catch { console.error('No .session.json - skipping --seed.'); process.exit(0); }
  const q = new URLSearchParams(Object.fromEntries(['accT', 'accE', 'proT', 'proE', 'deviceId'].map((k) => [k, String(s[k] ?? '')])));
  const r = await fetch(`http://${ip}:8060/launch/dev?${q}`, { method: 'POST' });
  console.log(r.ok ? 'Launched, logged in with the saved DR session.' : `Launch failed (${r.status}).`);
}
