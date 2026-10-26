// Builds the sideload package: dist/drtv-dev.zip (compiles + validates with brighterscript).
//   npm run build                build (clean package)
//   npm run build -- --bake      personal build: also embeds your DR session from .session.json, so the app starts logged in
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
  let s;
  try { s = JSON.parse(fs.readFileSync(path.join(root, '.session.json'), 'utf8')); } catch { /* handled below */ }
  if (!s?.accT || !s?.proT) {
    console.error('--bake needs a DR session in .session.json (see README: "Logging in"). Building without it is `npm run build`.');
    process.exit(1);
  }
  fs.mkdirSync(path.dirname(bakedFile), { recursive: true });
  const exp = Number(s.proE) || 0;
  if (exp && exp < Date.now() / 1000) console.warn(`Warning: the saved session expired ${new Date(exp * 1000).toLocaleString()}; refresh .session.json first.`);
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
