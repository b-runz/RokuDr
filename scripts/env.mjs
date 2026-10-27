// Tiny .env reader shared by the scripts. Values come from the .env file in the roku folder, or from the process environment.
// Never print what this returns.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

export function loadEnv() {
  const env = {};
  try {
    for (const line of fs.readFileSync(path.join(root, '.env'), 'utf8').split(/\r?\n/)) {
      const i = line.indexOf('=');
      if (i > 0 && !line.trim().startsWith('#')) env[line.slice(0, i).trim()] = line.slice(i + 1).trim().replace(/^["']|["']$/g, '');
    }
  } catch { /* no .env file */ }
  for (const k of ['DR_USER', 'DR_PASS', 'ROKU_IP', 'ROKU_PASSWORD']) if (process.env[k]) env[k] ??= process.env[k];
  return env;
}

// DR login: DR_USER / DR_PASS (older files used USER / PASS)
export function drCredentials(env = loadEnv()) {
  return { user: env.DR_USER || env.USER || '', pass: env.DR_PASS || env.PASS || '' };
}
