// Builds and sideloads dist/drtv-dev.zip onto a Roku that is in developer mode.
//   npm run deploy                 personal build (your DR session baked in, from .env) + install
//   npm run deploy -- --no-bake    install a clean package (log in with the TV code)
//   npm run deploy -- --seed       additionally launch via ECP with .session.json (only useful with --no-bake)
// Reads ROKU_IP and ROKU_PASSWORD from the environment or from .env in this folder. The password is never printed.
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadEnv } from './env.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const env = loadEnv();
const ip = env.ROKU_IP, pass = env.ROKU_PASSWORD;
if (!ip || !pass) {
  console.error('Copy .env.example to .env and fill in ROKU_IP and ROKU_PASSWORD (the developer-mode webserver password), then run again.');
  process.exit(1);
}

// Personal build by default: the package carries your DR session (see build.mjs). `--no-bake` installs a clean package instead.
const wantBake = !process.argv.includes('--no-bake');
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
