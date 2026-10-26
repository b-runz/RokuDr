// Builds the sideload package: dist/drtv-dev.zip (compiles + validates with brighterscript).
//   npm run build        build
//   npm run release      bump build_version first, then also write dist/release/drtv-dev-<major.minor.build>.zip
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const release = process.argv.includes('--release');
const manifestPath = path.join(root, 'manifest');
const readManifest = () => fs.readFileSync(manifestPath, 'utf8');
const field = (txt, key) => ((txt.split(/\r?\n/).find((l) => l.startsWith(`${key}=`)) || '=0').split('=')[1] || '0').trim();

if (release) { // bump build_version (00001 -> 00002 ...) so the Roku treats it as a new install
  const txt = readManifest();
  const next = String(Number(field(txt, 'build_version')) + 1).padStart(5, '0');
  fs.writeFileSync(manifestPath, txt.replace(/^build_version=\d+/m, `build_version=${next}`));
}

const bsc = path.join(root, 'node_modules', 'brighterscript', 'dist', 'cli.js');
if (!fs.existsSync(bsc)) { console.error('Dependencies missing. Run `npm install` in the roku folder first.'); process.exit(1); }
let out;
try {
  out = execFileSync(process.execPath, [bsc, '--project', path.join(root, 'bsconfig.json')], { encoding: 'utf8', cwd: root });
} catch (e) {
  console.error(String(e.stdout || e.message).split('\n').filter((l) => /error|warning|BS\d+/i.test(l)).join('\n'));
  process.exit(1);
}
const problems = out.split('\n').filter((l) => /error|warning/i.test(l) && !/BS1013/.test(l));
if (problems.length) console.log(problems.join('\n'));
const zip = path.join(root, 'dist', 'drtv-dev.zip');
console.log(`built dist/drtv-dev.zip (${fs.statSync(zip).size} bytes)`, problems.length ? '- with diagnostics above' : '- no diagnostics');

if (release) {
  const mf = readManifest();
  const v = ['major_version', 'minor_version', 'build_version'].map((k) => field(mf, k)).join('.');
  fs.mkdirSync(path.join(root, 'dist', 'release'), { recursive: true });
  const name = path.join(root, 'dist', 'release', `drtv-dev-${v}.zip`);
  fs.copyFileSync(zip, name);
  console.log('release package:', path.relative(root, name));
}
