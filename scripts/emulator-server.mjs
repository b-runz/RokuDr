// Self-contained server for the browser emulator (brs-engine). No other project needed.
//   npm run emulator          then open http://localhost:8790/
// Serves the emulator page, the engine libraries from node_modules, the freshly built dist/drtv-dev.zip, and a small
// CORS proxy so the app's calls to DR work from inside the browser.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const nm = (...p) => path.join(root, 'node_modules', ...p);
const FILES = {
  '/': path.join(root, 'emulator', 'index.html'),
  '/index.html': path.join(root, 'emulator', 'index.html'),
  '/lib/brs.api.js': nm('brs-engine', 'lib', 'brs.api.js'),
  '/lib/brs.worker.js': nm('brs-engine', 'lib', 'brs.worker.js'),
  '/lib/brs-sg.js': nm('brs-scenegraph', 'lib', 'brs-sg.js'),
  '/assets/common.zip': nm('brs-scenegraph', 'assets', 'common.zip'),   // the SceneGraph-ready volume (fonts etc.)
  '/drtv-dev.zip': path.join(root, 'dist', 'drtv-dev.zip'),
};
const MIME = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.zip': 'application/zip', '.json': 'application/json' };
const ISOLATION = { 'cross-origin-opener-policy': 'same-origin', 'cross-origin-embedder-policy': 'require-corp' };   // needed for SharedArrayBuffer
const CORS = { 'access-control-allow-origin': '*', 'access-control-allow-headers': '*', 'access-control-allow-methods': 'GET,POST,PUT,DELETE,OPTIONS', 'access-control-expose-headers': '*', 'cross-origin-resource-policy': 'cross-origin', 'access-control-max-age': '600' };
const ALLOWED = /^https:\/\/(prod95[a-z-]*\.dr-massive\.com|[a-z0-9.-]*akamaized\.net|[a-z0-9.-]*\.?dr\.dk)\//;

const send = (res, status, body, headers = {}) => { res.writeHead(status, { 'cache-control': 'no-store', ...headers }); res.end(body); };
const readBody = (req) => new Promise((ok) => { const c = []; req.on('data', (d) => c.push(d)); req.on('end', () => ok(Buffer.concat(c))); });

async function corsProxy(req, res) {
  if (req.method === 'OPTIONS') return send(res, 204, '', CORS);
  const target = req.url.replace(/^\/cors\//, '').replace(/^(https?):\/(?!\/)/, '$1://');
  if (!ALLOWED.test(target)) return send(res, 403, 'host not allowed', CORS);
  const body = ['GET', 'HEAD'].includes(req.method) ? undefined : await readBody(req);
  const headers = { 'user-agent': 'Mozilla/5.0' };
  for (const h of ['x-authorization', 'content-type', 'accept', 'range']) if (req.headers[h]) headers[h] = req.headers[h];
  const r = await fetch(target, { method: req.method, headers, body });
  send(res, r.status, Buffer.from(await r.arrayBuffer()), { ...CORS, 'content-type': r.headers.get('content-type') || 'application/octet-stream' });
}

export function start(port = Number(process.env.EMU_PORT) || 8790) {
  const server = http.createServer(async (req, res) => {
    const url = new URL(req.url, 'http://localhost');
    try {
      if (url.pathname.startsWith('/cors/')) return await corsProxy(req, res);
      if (url.pathname === '/seed.json') {   // optional: start logged in (see README, .session.json)
        const f = path.join(root, '.session.json');
        return send(res, 200, fs.existsSync(f) ? fs.readFileSync(f) : '{}', { 'content-type': 'application/json', ...ISOLATION });
      }
      const file = FILES[url.pathname];
      if (!file || !fs.existsSync(file)) return send(res, 404, 'not found' + (file ? ` (${path.relative(root, file)} - run npm install / npm run build)` : ''), ISOLATION);
      send(res, 200, fs.readFileSync(file), { 'content-type': MIME[path.extname(file)] || 'application/octet-stream', ...ISOLATION });
    } catch (e) { send(res, 500, String(e.message || e), CORS); }
  });
  return new Promise((ok) => server.listen(port, '127.0.0.1', () => ok(server)));
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const s = await start();
  console.log(`Roku emulator on http://localhost:${s.address().port}/  (Ctrl+C to stop; run \`npm run build\` to refresh the app)`);
}
