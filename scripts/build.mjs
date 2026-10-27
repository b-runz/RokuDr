// Builds the sideload package: dist/drtv-dev.zip (compiles + validates with brighterscript).
//   npm run build                build (clean package)
//   npm run personal             personal build (= build --bake): also embeds your DR session so the app starts logged in (logs in with .env when the session is missing/expiring; add --fresh to force)
//   npm run release              bump build_version first, then also write dist/release/drtv-dev-<major.minor.build>.zip
// A baked package contains your DR login tokens - it is for installing on your own Roku only (dist/ is git-ignored).
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const release = process.argv.includes('--release');
const bake = process.argv.includes('--bake');
const manifestPath = path.join(root, 'manifest');
const readManifest = () => fs.readFileSync(manifestPath, 'utf8');
const field = (txt, key) => ((txt.split(/\r?\n/).find((l) => l.startsWith(`${key}=`)) || '=0').split('=')[1] || '0').trim();

if (release) { // bump build_version (00001 -> 00002 ...) so the Roku treats it as a new install
  const txt = readManifest();
  const next = String(Number(field(txt, 'build_version')) + 1).padStart(5, '0');
  fs.writeFileSync(manifestPath, txt.replace(/^build_version=\d+/m, `build_version=${next}`));
}

// --bake: write config/session.json (git-ignored) for the duration of the build only
const bakedFile = path.join(root, 'config', 'session.json');
let baked = false;
if (bake) {
  // The session comes from .session.json. If it is missing or has < 2 h left, log in to DR with the credentials in .env first.
  const { drLogin, readSession, sessionLeft, sessionFile } = await import('./login.mjs');
  const { drCredentials } = await import('./env.mjs');
  const MIN_LEFT = 2 * 3600;
  let s = readSession();
  if (process.argv.includes('--fresh') || sessionLeft(s) < MIN_LEFT) {
    const creds = drCredentials();
    if (creds.user && creds.pass) {
      console.log('Logging in to DR for a fresh session...');
      s = await drLogin(creds);
      fs.writeFileSync(sessionFile, JSON.stringify(s));
    } else if (sessionLeft(s) > 0) {
      console.warn(`Warning: the saved session has only ${Math.round(sessionLeft(s) / 60)} min left and .env has no DR login to refresh it.`);
    } else {
      console.error('--bake needs a DR login: add DR_USER and DR_PASS to .env (see .env.example), or provide a valid .session.json.');
      process.exit(1);
    }
  }
  fs.mkdirSync(path.dirname(bakedFile), { recursive: true });
  fs.writeFileSync(bakedFile, JSON.stringify({ accT: s.accT, accE: s.accE, proT: s.proT, proE: s.proE, deviceId: s.deviceId, bakedAt: Math.floor(Date.now() / 1000) }));
  baked = true;
}

const bsc = path.join(root, 'node_modules', 'brighterscript', 'dist', 'cli.js');
if (!fs.existsSync(bsc)) { console.error('Dependencies missing. Run `npm install` in the roku folder first.'); process.exit(1); }
let out;
try {
  out = execFileSync(process.execPath, [bsc, '--project', path.join(root, 'bsconfig.json')], { encoding: 'utf8', cwd: root });
} catch (e) {
  console.error(String(e.stdout || e.message).split('\n').filter((l) => /error|warning|BS\d+/i.test(l)).join('\n'));
  process.exitCode = 1;
} finally {
  if (baked) fs.rmSync(path.join(root, 'config'), { recursive: true, force: true });   // never leave the session lying in the source tree
}
if (process.exitCode) process.exit(process.exitCode);

const problems = out.split('\n').filter((l) => /error|warning/i.test(l) && !/BS1013/.test(l));
if (problems.length) console.log(problems.join('\n'));
const zip = path.join(root, 'dist', 'drtv-dev.zip');
console.log(`built dist/drtv-dev.zip (${fs.statSync(zip).size} bytes)${baked ? ' - BAKED with your DR session (personal use only)' : ''}`, problems.length ? '- with diagnostics above' : '- no diagnostics');

if (release) {
  const mf = readManifest();
  const v = ['major_version', 'minor_version', 'build_version'].map((k) => field(mf, k)).join('.');
  fs.mkdirSync(path.join(root, 'dist', 'release'), { recursive: true });
  const name = path.join(root, 'dist', 'release', `drtv-dev-${v}${baked ? '-personal' : ''}.zip`);
  fs.copyFileSync(zip, name);
  console.log('release package:', path.relative(root, name));
}
