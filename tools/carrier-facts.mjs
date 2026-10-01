#!/usr/bin/env node
/**
 * carrier-facts — print where this session is actually running.
 *
 *   node carrier-facts.mjs          # human-readable
 *   node carrier-facts.mjs --json   # machine-readable
 *
 * Why: a session's orientation text comes from the surface bundle (`dsh-web-app`), and the
 * desktop app loads that same bundle — so the text says "Web GUI" even when the session runs
 * inside the Electron desktop shell. Nothing in that text can say which carrier, which
 * profile, or which plugins are live. This script reads those facts from the machine.
 *
 * Reads only.
 */
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

const HOME = os.homedir();
const json = process.argv.includes('--json');

function readJson(p) {
  try { return JSON.parse(fs.readFileSync(p, 'utf8').replace(/^\uFEFF/, '')); } catch { return null; }
}

/** 1-2: which profile this session belongs to. */
function profileFacts() {
  const name = process.env.DSH_PROFILE || null;
  const dir = process.env.DSH_PROFILE_DIR || (name ? path.join(HOME, '.dsh', 'profiles', name) : null);
  let bundles = [], deps = [];
  if (dir) {
    const j = readJson(path.join(dir, 'package.json'));
    bundles = j?.dsh?.profile?.bundles ?? [];
    deps = Object.keys(j?.dependencies ?? {});
  }
  return { profile: name, profile_dir: dir, bundles, dependencies: deps };
}

/** 3: what is carrying this process. Electron sets ELECTRON_RUN_AS_NODE for RunAsNode children. */
function carrierFacts() {
  const electron = process.env.ELECTRON_RUN_AS_NODE === '1';
  const ancestry = [];
  if (process.platform === 'win32') {
    try {
      let pid = process.ppid;
      for (let i = 0; i < 6 && pid; i++) {
        const out = execFileSync('powershell', ['-NoProfile', '-Command',
          `$p=Get-CimInstance Win32_Process -Filter "ProcessId=${pid}"; if($p){"$($p.ProcessId)|$($p.Name)|$($p.ExecutablePath)|$($p.ParentProcessId)"}`],
          { encoding: 'utf8' }).trim();
        if (!out) break;
        const [id, name, exe, parent] = out.split('|');
        ancestry.push({ pid: Number(id), name, exe });
        pid = Number(parent);
      }
    } catch { /* ancestry is best-effort */ }
  }
  const app = ancestry.find((a) => /DeepSeek Harness|electron/i.test(a.name || ''));
  return {
    electron_run_as_node: electron,
    carrier: app ? app.name : (electron ? 'electron (unknown app)' : 'node'),
    carrier_exe: app?.exe ?? null,
    ancestry: ancestry.map((a) => `${a.name}#${a.pid}`),
  };
}

/** 4: the UI this session's user is looking at. */
async function surfaceFacts() {
  const url = process.env.DSH_WEB_URL || null;
  let status = null;
  if (url) {
    try {
      const r = await fetch(url, { method: 'GET' });
      status = r.status;
    } catch (e) { status = `error: ${String(e.message || e).slice(0, 40)}`; }
  }
  return { url, http_status: status, needs_auth: status === 401 || status === 403 };
}

/** 5: what is actually live here = the profile's bundles + installed external packages. */
function livePlugins() {
  const { bundles, dependencies } = profileFacts();
  return { live: [...bundles], external_installed: [...dependencies] };
}

/** 6: other dsh runtimes / profiles on this machine (so "is it installed?" has an answer). */
function otherWorlds() {
  const roots = [
    path.join(HOME, 'AppData/Roaming/npm/node_modules/@deepseek-ai/dsh'),
    path.join(HOME, 'AppData/Local/Programs/DeepSeek Harness/resources/app.asar.unpacked/dsh'),
    '/usr/local/lib/node_modules/@deepseek-ai/dsh',
    '/usr/lib/node_modules/@deepseek-ai/dsh',
  ];
  const runtimes = [];
  for (const r of roots) {
    const j = readJson(path.join(r, 'package.json'));
    if (j) runtimes.push({ where: r, version: j.version ?? '?' });
    else if (fs.existsSync(r)) runtimes.push({ where: r, version: 'unknown (packaged)' });
  }
  const pdir = path.join(HOME, '.dsh', 'profiles');
  const profiles = fs.existsSync(pdir)
    ? fs.readdirSync(pdir).filter((n) => fs.existsSync(path.join(pdir, n, 'package.json')))
    : [];
  return { runtimes, profiles };
}

/** The text an agent should be able to read at the start of a session. */
export function carrierPromptText(f = gather()) {
  return [
    `This session runs in profile "${f.profile}" (${f.profile_dir}).`,
    `It is carried by ${f.carrier}${f.carrier_exe ? ` (${f.carrier_exe})` : ''}${f.electron_run_as_node ? ', Electron RunAsNode' : ''}.`,
    `The user's UI is ${f.surface.url}${f.surface.needs_auth ? ' (authenticated: direct fetches answer 401/403)' : ''}.`,
    `Live plugins in this profile: ${f.live.live.join(', ') || '(none)'}.`,
    `Installed but not live here: ${f.live.external_installed.join(', ') || '(none)'}.`,
    `Other dsh runtimes on this machine: ${f.other.runtimes.map((r) => `${r.version} @ ${r.where}`).join('; ') || '(none found)'}.`,
    `Other profiles: ${f.other.profiles.join(', ') || '(none)'}.`,
    'Installed, running, and usable are three different things: say which one you mean, and name the profile.',
  ].join('\n');
}

function gather() {
  return { ...profileFacts(), ...carrierFacts(), live: livePlugins(), other: otherWorlds() };
}

const facts = gather();
const surface = await surfaceFacts();
const out = { ...facts, surface };
if (json) {
  console.log(JSON.stringify(out, null, 2));
} else {
  console.log(carrierPromptText({ ...facts, surface }));
}
