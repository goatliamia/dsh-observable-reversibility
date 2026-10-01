#!/usr/bin/env node
/**
 * preflight — will these plugins actually work *here*?
 *
 *   node preflight.mjs --services services.json [--profile desktop] [--json]
 *   node preflight.mjs --self-test
 *
 * Why: a plugin declares the services it needs (`inject: [...]`), and a composition that does not
 * offer one of them leaves that plugin pending — the failure then shows up as a boot that does
 * not complete. This is a **reachability diagnostic**: for each installed plugin it answers
 * "can this composition reach it at all", before anything is installed.
 *
 * Scope note (per the project's simplification policy): checks of *service presence* and
 * *plugin metadata* do not qualify as an invariant companion — they compare declarations, not
 * independently produced observations that can diverge. So this is a diagnostic aid, not a
 * guard, and it must not be presented as one.
 *
 * Measured 2026-10-01 on a desktop session: the live directory offered `webServer` but not
 * `webRuntime`; of the plugins installed for the `web` profile, all were reachable and exactly
 * one (`dsh-better-sidebar`, which injects lazily) was `optional`.
 *
 * Where the service list comes from: the running session (the official Inspect "Service"
 * provider returns the live directory). Save it to a JSON file and pass it here — this script
 * reads files only; it does not call the runtime.
 *
 * States: ok / pending_here / optional / cannot_check
 */
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const HOME = os.homedir();
const PROFILE_ROOT = path.join(HOME, '.dsh', 'profiles');
const PKG_ROOTS = [
  path.join(HOME, 'AppData/Roaming/npm/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai'),
  path.join(HOME, 'AppData/Local/Programs/DeepSeek Harness/resources/app.asar.unpacked/dsh/node_modules/@deepseek-ai'),
];

const readJson = (p) => { try { return JSON.parse(fs.readFileSync(p, 'utf8').replace(/^\uFEFF/, '')); } catch { return null; } };

/** Names the session currently offers. Accepts the Inspect directory in a couple of shapes. */
export function serviceNames(doc) {
  if (!doc) return null;
  if (Array.isArray(doc)) return new Set(doc.map(String));
  for (const k of ['services', 'entries', 'keys', 'names']) {
    const v = doc[k];
    if (Array.isArray(v)) return new Set(v.map((x) => (typeof x === 'string' ? x : x?.key ?? x?.name)).filter(Boolean).map(String));
  }
  return null;
}

/**
 * Where the service list came from. A bare list is allowed but then the source is unknown —
 * say so rather than implying it was verified.
 */
export function serviceSource(doc, file) {
  if (!doc) return null;
  const src = (typeof doc === 'object' && !Array.isArray(doc) && (doc.source || doc.taken_at))
    ? { source: doc.source ?? null, taken_at: doc.taken_at ?? null }
    : { source: null, taken_at: null };
  return { file: file ?? null, ...src };
}

/**
 * What a plugin's host half asks for. Two spellings are common and both must be read:
 *   `inject: ['webServer']`   (an object/Cordis config)
 *   `export const inject = ['webServer']`   (a module-level export)
 * Missing the second spelling is what the self-test caught on the first try.
 */
export function declaredInjects(pkgDir) {
  const pkg = readJson(path.join(pkgDir, 'package.json'));
  if (!pkg) return null;
  const entry = typeof pkg.exports === 'object' && pkg.exports?.['.']
    ? (pkg.exports['.'].default ?? pkg.exports['.'])
    : (pkg.main ?? 'index.js');
  const candidates = [path.join(pkgDir, String(entry).replace(/^\.\//, '')),
                      ...['index.js', 'lib/index.js', 'dist/index.js', 'index.mjs', 'index.cjs'].map((c) => path.join(pkgDir, c))];
  let text = '';
  let readFrom = null;
  for (const c of candidates) {
    if (fs.existsSync(c)) { try { text = fs.readFileSync(c, 'utf8'); readFrom = c; } catch { /* keep trying */ } }
    if (text) break;
  }
  if (!text) return null;
  const names = new Set();
  const patterns = [
    /\binject\s*[:=]\s*\[([^\]]*)\]/g,      // inject: [...]   /   export const inject = [...]
    /\binject\s*\(\s*\[([^\]]*)\]/g,        // ctx.inject([...], cb)  — the lazy form
  ];
  for (const re of patterns) {
    for (const m of text.matchAll(re)) {
      for (const q of m[1].matchAll(/['"`]([^'"`]+)['"`]/g)) names.add(q[1]);
    }
  }
  const lazy = /\bctx\s*\.\s*inject\s*[([{]/.test(text);
  return { injects: [...names], lazy, read_from: readFrom };
}

/** The decision on its own, so the tests exercise this and not a copy of it. */
export function verdict(declared, services) {
  const missing = declared.injects.filter((x) => !services.has(x));
  if (!declared.injects.length) return { state: 'ok', needs: [], missing: [] };
  if (!missing.length) return { state: 'ok', needs: declared.injects, missing: [] };
  if (declared.lazy) {
    return { state: 'optional', needs: declared.injects, missing,
             why: 'injects lazily, so it may still activate if the missing ones appear later' };
  }
  return { state: 'pending_here', needs: declared.injects, missing,
           why: `not offered by the current session: ${missing.join(', ')}` };
}

/** Installed candidates in a profile: declared dependencies plus @local links. */
export function installedDirs(profile) {
  const dir = path.join(PROFILE_ROOT, profile);
  const pkg = readJson(path.join(dir, 'package.json'));
  const names = new Set(Object.keys(pkg?.dependencies ?? {}));
  const scope = path.join(dir, 'node_modules', '@local');
  if (fs.existsSync(scope)) for (const n of fs.readdirSync(scope)) names.add(`@local/${n}`);
  const out = [];
  for (const n of names) {
    const candidates = [path.join(dir, 'node_modules', n),
                        ...PKG_ROOTS.map((r) => path.join(r, n.replace('@deepseek-ai/', '')))];
    const hit = candidates.find((c) => fs.existsSync(path.join(c, 'package.json')));
    out.push({ name: n, dir: hit ?? null });
  }
  return out;
}

export function check(services, profile, servicesFrom = null) {
  const rows = [];
  for (const { name, dir } of installedDirs(profile)) {
    if (!dir) { rows.push({ plugin: name, state: 'cannot_check', why: 'not found on disk' }); continue; }
    const d = declaredInjects(dir);
    if (!d) { rows.push({ plugin: name, state: 'cannot_check', why: 'no readable entry file' }); continue; }
    const verdictOrUnknown = services
      ? verdict(d, services)
      : { state: 'cannot_check', why: 'no service list given', needs: d.injects };
    rows.push({ plugin: name, ...verdictOrUnknown,
                asked_for_read_from: d.read_from,       // where the plugin's requirements were read
                services_from: servicesFrom });         // who supplied the list of what is available
  }
  return rows;
}

function selfTest() {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'preflight-'));
  let ok = true;
  const chk = (c, what, detail = '') => { ok &&= !!c; console.log(`  ${c ? 'ok  ' : 'FAIL'} ${what}${!c && detail ? `  <- ${detail}` : ''}`); };
  const mk = (name, main, body) => {
    const d = path.join(tmp, name);
    fs.mkdirSync(d, { recursive: true });
    fs.writeFileSync(path.join(d, 'package.json'), JSON.stringify({ name, main }));
    fs.writeFileSync(path.join(d, main), body);
    return d;
  };
  const services = new Set(['webServer', 'sessions']);

  console.log('1. what the plugin asks for is read, in both spellings');
  const a = declaredInjects(mk('a', 'index.js', "export const inject = ['webServer','sessions'];"));
  chk(a?.injects.includes('webServer'), 'export const inject = [...]', JSON.stringify(a));
  const b = declaredInjects(mk('b', 'index.js', "module.exports = { inject: ['webRuntime'] };"));
  chk(b?.injects.includes('webRuntime'), 'inject: [...]', JSON.stringify(b));

  console.log('2. available -> ok');
  const v1 = verdict(a, services);
  chk(v1.state === 'ok', 'no warning', JSON.stringify(v1));

  console.log('3. missing -> pending_here, and it names them');
  const v2 = verdict(b, services);
  chk(v2.state === 'pending_here' && v2.missing.includes('webRuntime'), 'reported with the name', JSON.stringify(v2));

  console.log('4. lazy injection + a missing service -> optional, not a hard failure');
  const c = declaredInjects(mk('c', 'index.js', "ctx.inject(['webRuntime'], () => {});"));
  const v3 = verdict(c, services);
  chk(c?.lazy === true && c.injects.includes('webRuntime'), 'lazy call seen', JSON.stringify(c));
  chk(v3.state === 'optional', 'optional', JSON.stringify(v3));
  chk(verdict(declaredInjects(mk('d', 'index.js', "ctx.inject(['webServer'], () => {});")), services).state === 'ok',
      'lazy but the service is available -> still ok (no warning)', '');

  console.log('5. nothing asked for -> ok; no list -> the caller must say cannot_check');
  chk(verdict({ injects: [], lazy: false }, services).state === 'ok', 'ok');
  chk(serviceNames(null) === null, 'null list');
  chk(serviceNames({ services: ['a', 'b'] })?.has('b'), 'reads a list');

  console.log('6. every answer carries where it came from');
  const e = declaredInjects(mk('e', 'index.js', "export const inject = ['x'];"));
  chk(typeof e.read_from === 'string' && e.read_from.endsWith('index.js'), 'the file it read is named', JSON.stringify(e));
  const src = serviceSource({ services: ['a'], source: 'Inspect Service.listService', taken_at: '2026-09-30' }, 'services.json');
  chk(src.source?.includes('Inspect') && src.taken_at === '2026-09-30' && src.file === 'services.json',
      'the list says who gave it and when', JSON.stringify(src));
  chk(serviceSource(['a'], 'bare.json').source === null,
      'a bare list is allowed but then the source is honestly null', JSON.stringify(serviceSource(['a'], 'bare.json')));

  fs.rmSync(tmp, { recursive: true, force: true });
  console.log(ok ? '\nall good' : '\nFAILURES above');
  return ok ? 0 : 1;
}

if (process.argv.includes('--self-test')) process.exit(selfTest());

const arg = (k, d = null) => { const i = process.argv.indexOf(k); return i > 0 && process.argv[i + 1] ? process.argv[i + 1] : d; };
const profile = arg('--profile', process.env.DSH_PROFILE);
const servicesFile = arg('--services');
const servicesDoc = servicesFile ? readJson(servicesFile) : null;
const services = serviceNames(servicesDoc);
const servicesFrom = serviceSource(servicesDoc, servicesFile);
const rows = check(services, profile, servicesFrom);

if (process.argv.includes('--json')) {
  console.log(JSON.stringify({ profile, services_known: !!services, services_from: servicesFrom, rows }, null, 2));
} else {
  console.log(`profile: ${profile}`);
  if (services) {
    const who = servicesFrom?.source ?? '(not stated)';
    const when = servicesFrom?.taken_at ? ` at ${servicesFrom.taken_at}` : '';
    console.log(`available services: from ${who}${when}${servicesFrom?.file ? ` [${servicesFrom.file}]` : ''}`);
  } else {
    console.log("available services: (none given — nothing can be compared; pass --services with the session's Inspect directory)");
  }
  for (const r of rows) {
    console.log(`  [${r.state}] ${r.plugin}` + (r.missing?.length ? `  missing: ${r.missing.join(', ')}` : '')
      + (r.needs?.length ? `  needs: ${r.needs.join(', ')}` : '') + (r.why ? `  (${r.why})` : ''));
    if (r.asked_for_read_from) console.log(`        read from: ${r.asked_for_read_from}`);
  }
}
