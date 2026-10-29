#!/usr/bin/env node
// Render the replay record of an audit's fixes as an ordered production runbook.
//
// A fix applied on a local clone reaches production by one of several routes, and only one
// of them is automatic. Theme files travel with the commit. An option set by WP-CLI, a
// post-meta edit, a wp-config constant, a server rule and a cache purge do not. Each session
// ended with a hand-written "for production" list kept in the conversation. The list was
// rewritten from memory every time, and its server half was written for the wrong server:
// `.htaccess` fixes reported as done for an nginx production, PHP-served endpoints
// (`/llms.txt`, `/.well-known/*`) answering 404 there, and a physical file left in the web
// root that carried the local host.
//
// This script reads `<out>/replay.json` (the contract is in
// skills/wp-audit-run/references/fix.md, "The replay log") and writes
// `<out>/runbook-<YYYY-MM-DD>.md` in this order:
//
//   1. pre-deploy checks   the development host in the database, physical files that shadow
//                          a virtual endpoint, the local host in static files, files to commit
//   2. code                what the commit carries, and the theme activation it assumes
//   3. wp-config           constants, which are not in git
//   4. database            options, then post meta, as WP-CLI with a --url placeholder
//   5. server rules        Apache and nginx, from references/server-rules.md, "not applied"
//   6. post-deploy         recorded steps, flush-css for Elementor, the page-cache purge
//   7. verification        one curl or WP-CLI read per item, against the public URL
//
// The local host never reaches the runbook. Commands are rewritten (`$WP` → `wp`, `--path`
// dropped, `--url` set to the production URL or `<prod-url>`, the local URL replaced) and
// the rendered text is scanned before it is written: a leftover local host is exit 1.
//
// Usage:
//   bin/audit-runbook.mjs [--replay <file>] [--out <dir>] [--root <site-root>]
//                         [--manifest <file>] [--lang en|es] [--prod-url <url>]
//                         [--server nginx|apache|litespeed|caddy|unknown]
//                         [--page-cache <name>] [--builder <name>]
//                         [--local-host <host>]... [--date YYYY-MM-DD]
//
// Defaults: --root is the current directory, --manifest is <root>/.wp-create.json, --out
// follows the same order as audit-report.mjs (--out, WP_AUDIT_OUT_DIR, the manifest's
// audit.out_dir, .wp-audit), and --replay is <out>/replay.json. --prod-url, --server and
// --page-cache default to the manifest's role "prod" environment (`url`, `server`,
// `page_cache`); --builder and the page-cache fallback come from `stack`.
//
// Exit codes (house convention):
//   0  runbook written, including for an empty record
//   1  invalid input: unreadable record, an entry without what its kind needs, an unknown
//      server rule, or a local host that would leak into the runbook
//   3  crash

import { readFileSync, writeFileSync, mkdirSync, existsSync, statSync } from 'node:fs';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const KINDS = ['code', 'db-option', 'post-meta', 'wp-config', 'server', 'post-deploy'];
const SERVERS = ['nginx', 'apache', 'litespeed', 'caddy', 'unknown'];
const RULES_FILE = join(dirname(fileURLToPath(import.meta.url)), '..', 'skills', 'wp-audit-run', 'references', 'server-rules.md');
// Physical files checked in the web root even when no entry names them: both shadow a
// route that an SEO or agentic-surfaces fix commonly serves from PHP.
const DEFAULT_ENDPOINTS = ['/robots.txt', '/llms.txt'];
// Hosts that are never public. Any of these left in the runbook is a leak even when the
// manifest did not name it.
const NON_PUBLIC = /\b[a-z0-9][a-z0-9-]*(?:\.[a-z0-9-]+)*\.(?:local\.com|localhost|local|test)\b/gi;

const STRINGS = {
  en: {
    title: 'Production runbook',
    intro: 'Generated from %replay% (%n% entries). Run the steps in order. A step marked `not applied` is not done on production until its verification passes there.',
    target: 'Target: %url% · server: %server% · page cache: %cache% · builder: %builder%',
    serverUnknown: 'The production web server is not recorded. Every server step below is given for nginx and Apache. Record it with `node bin/wp-config.mjs env-set <site-root> --name=prod --role=prod --url=<prod-url> --server=nginx|apache`.',
    pre: '1. Pre-deploy checks',
    code: '2. Code (travels with the commit)',
    wpconfig: '3. wp-config.php (not in git)',
    db: '4. Database (WP-CLI on production)',
    dbOptions: 'Options',
    dbMeta: 'Post meta',
    server: '5. Server rules (need the server owner)',
    post: '6. Post-deploy',
    verify: '7. Verification',
    none: 'Nothing recorded.',
    devHost: 'The development host is not in the production database. Run on production with the local host as the needle (it is in the manifest\'s `wordpress.url`, and deliberately not written here). Expect no rows outside `home` and `siteurl`:',
    found: 'FOUND',
    shadow: '`%file%` exists in the web root and shadows the dynamic `%endpoint%`. Delete it on production, or keep it out of the deploy.',
    shadowHost: '`%file%` contains the development host.',
    shadowNone: 'No physical file shadows %list% in the local web root. Check production too:',
    staticHost: '`%file%` contains the development host. Replace it before the commit.',
    staticGrep: 'No local host found in the recorded files. Search the rest of the editable code:',
    committed: 'Every recorded file is committed (each must print its path, not an error):',
    hostRewritten: '%n% recorded command(s) contained the development host. It was replaced by the production URL here: review each value before running it.',
    theme: 'The commit carries files of the theme `%slug%`. It only takes effect if that theme is active on production:',
    themeActivate: 'If it is not, activate it and copy its customizer settings from the local site:',
    revert: 'revert',
    backup: 'backup',
    already: 'already applied on production',
    ids: 'The IDs come from the local database. Confirm they are the same rows on production before running.',
    selector: 'Re-select them on production with:',
    notApplied: 'not applied',
    needsOwner: 'These rules need the server owner. Nothing in this run applied them to production.',
    noRule: 'No vetted nginx equivalent for this fix. The server owner translates `%file%`.',
    caddy: 'No vetted Caddy snippets. The server owner translates the Apache rule.',
    flushCss: 'Regenerate the Elementor CSS (stack: builder=elementor):',
    rewrite: 'Flush the rewrite rules (the record adds PHP-served endpoints):',
    purge: 'Purge the page cache (%cache%) last:',
    purgeServer: 'The server owner empties the directory set by `fastcgi_cache_path`, or runs the purge plugin\'s command (Nginx Helper: `wp nginx-helper purge-all`).',
    purgeGeneric: 'Use its own control.',
    tmpTables: 'No sync temp tables are left (the record shows an EnvSync site). Drop them only once no sync is running:',
    expect: 'expect',
  },
  es: {
    title: 'Guía de despliegue a producción',
    intro: 'Generada a partir de %replay% (%n% entradas). Sigue los pasos en orden. Un paso marcado `no aplicado` no está hecho en producción hasta que su verificación pase allí.',
    target: 'Destino: %url% · servidor: %server% · caché de página: %cache% · constructor: %builder%',
    serverUnknown: 'No consta el servidor web de producción. Cada paso de servidor se da para nginx y para Apache. Regístralo con `node bin/wp-config.mjs env-set <site-root> --name=prod --role=prod --url=<prod-url> --server=nginx|apache`.',
    pre: '1. Comprobaciones previas',
    code: '2. Código (viaja con el commit)',
    wpconfig: '3. wp-config.php (no está en git)',
    db: '4. Base de datos (WP-CLI en producción)',
    dbOptions: 'Opciones',
    dbMeta: 'Metadatos de entradas',
    server: '5. Reglas de servidor (las aplica quien gestiona el servidor)',
    post: '6. Después del despliegue',
    verify: '7. Verificación',
    none: 'Nada registrado.',
    devHost: 'El host de desarrollo no está en la base de datos de producción. Ejecútalo en producción con el host local como aguja (está en `wordpress.url` del manifiesto y a propósito no se escribe aquí). No debe salir ninguna fila fuera de `home` y `siteurl`:',
    found: 'ENCONTRADO',
    shadow: '`%file%` existe en la raíz web y tapa la ruta dinámica `%endpoint%`. Bórralo en producción o déjalo fuera del despliegue.',
    shadowHost: '`%file%` contiene el host de desarrollo.',
    shadowNone: 'Ningún fichero físico tapa %list% en la raíz web local. Compruébalo también en producción:',
    staticHost: '`%file%` contiene el host de desarrollo. Cámbialo antes del commit.',
    staticGrep: 'No hay host local en los ficheros registrados. Busca en el resto del código editable:',
    committed: 'Cada fichero registrado está en el commit (cada línea debe imprimir su ruta, no un error):',
    hostRewritten: '%n% comando(s) registrados contenían el host de desarrollo. Aquí se sustituyó por la URL de producción: revisa cada valor antes de ejecutarlo.',
    theme: 'El commit lleva ficheros del tema `%slug%`. Solo tienen efecto si ese tema está activo en producción:',
    themeActivate: 'Si no lo está, actívalo y copia sus ajustes del personalizador desde el sitio local:',
    revert: 'revertir',
    backup: 'copia',
    already: 'ya aplicado en producción',
    ids: 'Los ID salen de la base de datos local. Confirma que son las mismas filas en producción antes de ejecutarlo.',
    selector: 'Vuelve a seleccionarlas en producción con:',
    notApplied: 'no aplicado',
    needsOwner: 'Estas reglas las aplica quien gestiona el servidor. Esta ejecución no aplicó ninguna en producción.',
    noRule: 'No hay equivalente nginx revisado para este cambio. Quien gestiona el servidor traduce `%file%`.',
    caddy: 'No hay fragmentos revisados para Caddy. Quien gestiona el servidor traduce la regla de Apache.',
    flushCss: 'Regenera el CSS de Elementor (stack: builder=elementor):',
    rewrite: 'Vacía las reglas de reescritura (el registro añade rutas servidas por PHP):',
    purge: 'Purga la caché de página (%cache%) al final:',
    purgeServer: 'Quien gestiona el servidor vacía el directorio de `fastcgi_cache_path`, o ejecuta el comando del plugin de purga (Nginx Helper: `wp nginx-helper purge-all`).',
    purgeGeneric: 'Usa su propio control.',
    tmpTables: 'No quedan tablas temporales de sincronización (el registro indica un sitio con EnvSync). Bórralas solo cuando no haya ninguna sincronización en curso:',
    expect: 'resultado esperado',
  },
};

// Purge commands for page caches that have a WP-CLI command of their own. Anything else is
// purged with its own control; a server-level FastCGI cache needs the server owner.
const PURGE = {
  'litespeed-cache': 'wp litespeed-purge all',
  'w3-total-cache': 'wp w3-total-cache flush all',
  'wp-super-cache': 'wp super-cache flush',
  'nginx-helper': 'wp nginx-helper purge-all',
};

function die(code, message) {
  console.error(`audit-runbook: ${message}`);
  process.exit(code);
}

function fill(template, values) {
  return template.replace(/%(\w+)%/g, (_, k) => (values[k] === undefined ? `%${k}%` : String(values[k])));
}

function parseArgs(argv) {
  const opts = { localHost: [], lang: 'en' };
  const single = ['--replay', '--out', '--root', '--manifest', '--lang', '--prod-url', '--server', '--page-cache', '--builder', '--date'];
  for (let i = 0; i < argv.length; i += 1) {
    const flag = argv[i];
    const value = argv[i + 1];
    if (flag !== '--local-host' && !single.includes(flag)) die(1, `unknown argument: ${flag}`);
    if (value === undefined || value.startsWith('--')) die(1, `${flag} needs a value`);
    if (flag === '--local-host') opts.localHost.push(value);
    else opts[flag.slice(2).replace(/-(\w)/g, (_, c) => c.toUpperCase())] = value;
    i += 1;
  }
  if (!STRINGS[opts.lang]) die(1, `--lang must be one of ${Object.keys(STRINGS).join(', ')} (got: ${opts.lang})`);
  if (opts.server && !SERVERS.includes(opts.server)) die(1, `--server must be one of ${SERVERS.join(', ')} (got: ${opts.server})`);
  if (opts.date && !/^\d{4}-\d{2}-\d{2}$/.test(opts.date)) die(1, `--date must be YYYY-MM-DD (got: ${opts.date})`);
  if (opts.prodUrl && !/^https?:\/\/[^\s/]+/.test(opts.prodUrl)) die(1, `--prod-url must be an http(s) URL (got: ${opts.prodUrl})`);
  return opts;
}

function readJson(path) {
  try {
    return JSON.parse(readFileSync(path, 'utf8'));
  } catch {
    return null;
  }
}

// Same order as audit-report.mjs: --out > WP_AUDIT_OUT_DIR > audit.out_dir > .wp-audit
function resolveOutDir(flag, manifest) {
  if (flag) return flag;
  if (process.env.WP_AUDIT_OUT_DIR) return process.env.WP_AUDIT_OUT_DIR;
  const dir = manifest?.audit?.out_dir;
  if (typeof dir === 'string' && dir !== '') return dir;
  return '.wp-audit';
}

function hostOf(url) {
  try {
    return new URL(url).host.toLowerCase();
  } catch {
    return null;
  }
}

// The server-rules reference is the table: one "### `<id>`" section per rule with a
// Verify: line, an apache block and an nginx block.
function loadRules(file = RULES_FILE) {
  const text = readFileSync(file, 'utf8');
  const rules = {};
  const parts = text.split(/^### `([a-z0-9-]+)`\s*$/m);
  for (let i = 1; i < parts.length; i += 2) {
    const body = parts[i + 1];
    const verify = body.match(/^Verify: `([^`]+)`(.*)$/m);
    const apache = body.match(/```apache\n([\s\S]*?)```/);
    const nginx = body.match(/```nginx\n([\s\S]*?)```/);
    if (!verify || !apache || !nginx) throw new Error(`server-rules.md: rule ${parts[i]} lacks a Verify line, an apache block or an nginx block`);
    rules[parts[i]] = { verify: verify[1], expect: verify[2].trim().replace(/^prints\s+/, ''), apache: apache[1].trimEnd(), nginx: nginx[1].trimEnd() };
  }
  return rules;
}

function inferKind(entry) {
  const resource = String(entry.resource ?? '');
  if (/^(option|wp_options)[:.]/.test(resource)) return 'db-option';
  if (/^(post|postmeta|term)[:.]/.test(resource)) return 'post-meta';
  if (/^\s*(\$WP|wp)\s+config\s+set\b/.test(String(entry.command ?? ''))) return 'wp-config';
  if (entry.command) return 'db-option';
  return null;
}

function filesOf(entry) {
  if (Array.isArray(entry.file)) return entry.file.filter((f) => typeof f === 'string' && f);
  return typeof entry.file === 'string' && entry.file ? [entry.file] : [];
}

function validate(entries, rules) {
  const problems = [];
  entries.forEach((entry, i) => {
    const at = `entry ${i + 1}${entry && entry.check ? ` (${entry.check})` : ''}`;
    if (!entry || typeof entry !== 'object' || Array.isArray(entry)) { problems.push(`${at} is not an object`); return; }
    if (!entry.kind) {
      entry.kind = inferKind(entry);
      entry.kind_inferred = true;
    }
    if (!KINDS.includes(entry.kind)) { problems.push(`${at}: kind must be one of ${KINDS.join(', ')} (got: ${JSON.stringify(entry.kind)})`); return; }
    const needsCommand = ['db-option', 'post-meta', 'wp-config', 'post-deploy'].includes(entry.kind);
    if (needsCommand && (typeof entry.command !== 'string' || !entry.command.trim())) problems.push(`${at}: a ${entry.kind} entry needs the exact command`);
    if (['code', 'server'].includes(entry.kind) && !filesOf(entry).length) problems.push(`${at}: a ${entry.kind} entry needs the file it changed`);
    if (entry.server_rule != null && !rules[entry.server_rule]) problems.push(`${at}: unknown server_rule ${JSON.stringify(entry.server_rule)} (see references/server-rules.md)`);
    if (entry.endpoint != null && (typeof entry.endpoint !== 'string' || !entry.endpoint.startsWith('/'))) problems.push(`${at}: endpoint must be a path starting with /`);
    if (/^virtual-endpoint/.test(entry.server_rule ?? '') && !entry.endpoint) problems.push(`${at}: ${entry.server_rule} needs the endpoint it routes`);
  });
  return problems;
}

function main() {
  const opts = parseArgs(process.argv.slice(2));
  const root = resolve(opts.root ?? '.');
  const manifestPath = opts.manifest ?? join(root, '.wp-create.json');
  const manifest = existsSync(manifestPath) ? readJson(manifestPath) : null;
  const S = STRINGS[opts.lang];

  const envs = manifest && typeof manifest.environments === 'object' && manifest.environments ? Object.values(manifest.environments) : [];
  const prod = envs.find((e) => e && e.role === 'prod') ?? {};
  const stack = manifest?.stack ?? {};
  const prodUrl = (opts.prodUrl ?? prod.url ?? null)?.replace(/\/+$/, '') ?? null;
  const urlRef = prodUrl ?? '<prod-url>';
  const server = opts.server ?? (SERVERS.includes(prod.server) ? prod.server : 'unknown');
  const pageCache = opts.pageCache ?? prod.page_cache ?? (stack.cache && stack.cache !== 'none' ? stack.cache : 'none');
  const builder = opts.builder ?? stack.builder ?? 'none';
  const envsync = envs.some((e) => e?.sync?.tool === 'envsync');

  // Every host the runbook must never carry.
  const localHosts = new Set(opts.localHost.map((h) => h.toLowerCase()));
  for (const u of [manifest?.wordpress?.url, ...envs.filter((e) => e?.role === 'local').map((e) => e.url)]) {
    const h = hostOf(u);
    if (h) localHosts.add(h);
  }
  if (typeof manifest?.project?.domain === 'string' && manifest.project.domain) localHosts.add(manifest.project.domain.toLowerCase());
  const prodHost = prodUrl ? hostOf(prodUrl) : null;
  if (prodHost) localHosts.delete(prodHost);

  const outDir = resolveOutDir(opts.out, manifest);
  const replayPath = opts.replay ?? join(outDir, 'replay.json');
  if (!existsSync(replayPath)) die(1, `no replay record at ${resolve(replayPath)}; fix.md's replay log writes it as each fix lands`);
  const record = readJson(replayPath);
  if (record === null) die(1, `${resolve(replayPath)} is not valid JSON`);
  const entries = Array.isArray(record) ? record : record.entries;
  if (!Array.isArray(entries)) die(1, `${resolve(replayPath)} must be {"replay_version": 1, "entries": [...]} or an array of entries`);

  let rules;
  try {
    rules = loadRules();
  } catch (error) {
    die(1, error.message);
  }
  const problems = validate(entries, rules);
  if (problems.length) die(1, `invalid replay record:\n  ${problems.join('\n  ')}`);

  // --- rewriting: a command recorded on the clone, made safe to run on production -------
  let rewritten = 0;
  const escapeRe = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  function scrubHosts(text) {
    let out = text;
    for (const h of localHosts) {
      const withScheme = new RegExp(`https?:(\\\\?/){2}${escapeRe(h)}`, 'gi');
      out = out.replace(withScheme, (m) => (m.includes('\\/') ? urlRef.replace(/\//g, '\\/') : urlRef));
      out = out.replace(new RegExp(escapeRe(h), 'gi'), prodHost ?? '<prod-host>');
    }
    return root === '/' ? out : out.split(root).join('<wp-root>');
  }
  function prodCommand(command) {
    let c = command.trim().replace(/^bash -c\s+(["'])(.*)\1$/s, '$2');
    c = c.replace(/^\$WP\b/, 'wp').replace(/(^|\s)--path=\S+/g, '');
    const scrubbed = scrubHosts(c);
    if (scrubbed !== c) rewritten += 1;
    c = scrubbed;
    if (/^wp\s/.test(c)) {
      c = /(^|\s)--url=\S+/.test(c) ? c.replace(/(^|\s)--url=\S+/, `$1--url=${urlRef}`) : `${c} --url=${urlRef}`;
    }
    return c;
  }
  const short = (v) => {
    const s = typeof v === 'string' ? v : JSON.stringify(v);
    return s.length > 160 ? `${s.slice(0, 157)}...` : s;
  };
  const tick = (e) => (e.applied_on && e.applied_on.prod === true ? '[x]' : '[ ]');
  const label = (e) => `${e.check ? `**${e.check}**` : ''}${e.resource ? ` \`${e.resource}\`` : ''}`.trim();
  const fence = (lang, body) => ['', `\`\`\`${lang}`, body, '```', ''];

  const lines = [];
  const push = (...l) => lines.push(...l);
  const verifyLines = [];
  const date = opts.date ?? new Date().toISOString().slice(0, 10);

  push(`# ${S.title} — ${date}`, '', fill(S.intro, { replay: '`replay.json`', n: entries.length }), '');
  push(fill(S.target, { url: urlRef, server, cache: pageCache, builder }), '');
  if (server === 'unknown') push(`> ${S.serverUnknown}`, '');

  const byKind = (k) => entries.filter((e) => e.kind === k);
  const endpoints = [...new Set(entries.map((e) => e.endpoint).filter(Boolean))];

  // --- 1. pre-deploy -------------------------------------------------------------------
  push(`## ${S.pre}`, '');
  push(`- [ ] ${S.devHost}`, ...fence('bash', `wp db search '<local-host>' --all-tables --url=${urlRef}`));
  const shadowTargets = [...new Set([...DEFAULT_ENDPOINTS, ...endpoints.filter((p) => !p.endsWith('/'))])];
  const found = [];
  for (const endpoint of shadowTargets) {
    const file = endpoint.replace(/^\/+/, '');
    const path = join(root, file);
    if (existsSync(path) && statSync(path).isFile()) {
      found.push(endpoint);
      push(`- [ ] **${S.found}** ${fill(S.shadow, { file, endpoint })}`);
      const body = readFileSync(path, 'utf8').toLowerCase();
      if ([...localHosts].some((h) => body.includes(h))) push(`  ${fill(S.shadowHost, { file })}`);
    }
  }
  const unshadowed = shadowTargets.filter((e) => !found.includes(e));
  if (unshadowed.length) {
    push(`- [ ] ${fill(S.shadowNone, { list: unshadowed.map((e) => `\`${e}\``).join(', ') })}`,
      ...fence('bash', unshadowed.map((e) => `ls -l <wp-root>${e}`).join('\n')));
  }
  const codeFiles = [...new Set([...byKind('code'), ...byKind('server')].flatMap(filesOf))];
  const hostFiles = codeFiles.filter((f) => {
    const p = join(root, f);
    if (!existsSync(p) || !statSync(p).isFile()) return false;
    const body = readFileSync(p, 'utf8').toLowerCase();
    return [...localHosts].some((h) => body.includes(h));
  });
  for (const f of hostFiles) push(`- [ ] **${S.found}** ${fill(S.staticHost, { file: f })}`);
  const themeDirs = [...new Set(byKind('code').flatMap(filesOf).map((f) => f.match(/^(wp-content\/(?:themes|plugins|mu-plugins)\/[^/]+)\//)?.[1]).filter(Boolean))];
  if (!hostFiles.length) {
    push(`- [ ] ${S.staticGrep}`, ...fence('bash', `git grep -n -F '<local-host>' -- ${themeDirs.length ? themeDirs.join(' ') : 'wp-content/themes'}`));
  }
  const committed = byKind('code').flatMap(filesOf);
  if (committed.length) {
    push(`- [ ] ${S.committed}`, ...fence('bash', [...new Set(committed)].map((f) => `git ls-files --error-unmatch -- ${f}`).join('\n')));
  }

  // --- 2. code -------------------------------------------------------------------------
  push(`## ${S.code}`, '');
  if (!byKind('code').length) push(S.none, '');
  for (const e of byKind('code')) {
    push(`- ${tick(e)} ${label(e)} ${filesOf(e).map((f) => `\`${f}\``).join(', ')}${e.applied_on?.prod ? ` (${S.already})` : ''}`);
    if (e.endpoint) verifyLines.push(endpointVerify(e));
  }
  if (byKind('code').length) push('');
  const themes = [...new Set(byKind('code').flatMap(filesOf).map((f) => f.match(/^wp-content\/themes\/([^/]+)\//)?.[1]).filter(Boolean))];
  for (const slug of themes) {
    push(`- [ ] ${fill(S.theme, { slug })}`, ...fence('bash', `wp option get stylesheet --url=${urlRef}   # ${S.expect}: ${slug}`));
    push(`  ${S.themeActivate}`, ...fence('bash', [
      `wp option get theme_mods_${slug} --format=json > theme_mods.json        # local`,
      `wp theme activate ${slug} --url=${urlRef}`,
      `wp option update theme_mods_${slug} --format=json --url=${urlRef} < theme_mods.json`,
    ].join('\n')));
    verifyLines.push({ cmd: `wp option get stylesheet --url=${urlRef}`, expect: slug });
  }

  // --- 3/4. wp-config and database -----------------------------------------------------
  const commandItem = (e) => {
    push(`- ${tick(e)} ${label(e)}${e.applied_on?.prod ? ` (${S.already})` : ''}`, ...fence('bash', prodCommand(e.command)));
    const notes = [];
    if (e['previous value'] !== undefined) notes.push(`${S.revert}: \`${short(scrubHosts(e['previous value'] === null || e['previous value'] === '' ? JSON.stringify(e['previous value']) : typeof e['previous value'] === 'string' ? e['previous value'] : JSON.stringify(e['previous value'])))}\``);
    if (e.backup) notes.push(`${S.backup}: \`${scrubHosts(String(e.backup))}\``);
    if (notes.length) push(`  ${notes.join(' · ')}`, '');
    if (Array.isArray(e.ids) && e.ids.length) {
      push(`  ${S.ids}`);
      if (e.selector) push(`  ${S.selector}`, ...fence('bash', prodCommand(e.selector)));
      else push('');
    }
    if (e.verify) verifyLines.push({ cmd: prodCommand(e.verify), expect: e.expect ?? '' });
  };
  push(`## ${S.wpconfig}`, '');
  if (!byKind('wp-config').length) push(S.none, '');
  byKind('wp-config').forEach(commandItem);

  push(`## ${S.db}`, '');
  if (!byKind('db-option').length && !byKind('post-meta').length) push(S.none, '');
  if (byKind('db-option').length) { push(`### ${S.dbOptions}`, ''); byKind('db-option').forEach(commandItem); }
  if (byKind('post-meta').length) { push(`### ${S.dbMeta}`, ''); byKind('post-meta').forEach(commandItem); }

  // --- 5. server rules -----------------------------------------------------------------
  push(`## ${S.server}`, '');
  const serverEntries = entries.filter((e) => e.kind === 'server' || e.needs_server_rule === true || e.server_rule);
  if (!serverEntries.length) push(S.none, '');
  else push(`> ${S.needsOwner}`, '');
  const order = server === 'apache' || server === 'litespeed' ? ['apache', 'nginx'] : ['nginx', 'apache'];
  for (const e of serverEntries) {
    const ruleId = e.server_rule
      ?? (e.endpoint ? (e.endpoint.endsWith('/') ? 'virtual-endpoint-prefix' : 'virtual-endpoint') : null);
    const files = filesOf(e);
    push(`- [ ] ${label(e)}${e.endpoint ? ` \`${e.endpoint}\`` : ''}${files.length ? ` (${files.map((f) => `\`${f}\``).join(', ')})` : ''} — **${S.notApplied}**`);
    const rule = ruleId ? rules[ruleId] : null;
    if (!rule) {
      push(`  ${fill(S.noRule, { file: files[0] ?? '.htaccess' })}`, '');
      continue;
    }
    const sub = (s) => s.split('<endpoint>').join(e.endpoint ?? '<endpoint>').split('<prod-url>').join(urlRef);
    for (const lang of order) push(...fence(lang, sub(rule[lang])));
    if (server === 'caddy') push(`  ${S.caddy}`, '');
    verifyLines.push({ cmd: sub(rule.verify), expect: sub(rule.expect) });
  }

  // --- 6. post-deploy ------------------------------------------------------------------
  push(`## ${S.post}`, '');
  byKind('post-deploy').forEach(commandItem);
  if (endpoints.length) push(`- [ ] ${S.rewrite}`, ...fence('bash', `wp rewrite flush --url=${urlRef}`));
  if (builder === 'elementor') push(`- [ ] ${S.flushCss}`, ...fence('bash', `wp elementor flush-css --url=${urlRef}`));
  if (envsync) push(`- [ ] ${S.tmpTables}`, ...fence('bash', `wp db tables --all-tables --url=${urlRef} | grep ixes_tmp_   # ${S.expect}: nothing`));
  if (pageCache && pageCache !== 'none') {
    const key = String(pageCache).toLowerCase();
    if (PURGE[key]) push(`- [ ] ${fill(S.purge, { cache: pageCache })}`, ...fence('bash', `${PURGE[key]} --url=${urlRef}`));
    else if (/fastcgi/.test(key)) push(`- [ ] ${fill(S.purge, { cache: pageCache })} ${S.purgeServer}`, '');
    else push(`- [ ] ${fill(S.purge, { cache: pageCache })} ${S.purgeGeneric}`, '');
  }
  if (!byKind('post-deploy').length && !endpoints.length && builder !== 'elementor' && !envsync && (!pageCache || pageCache === 'none')) push(S.none, '');

  // --- 7. verification -----------------------------------------------------------------
  push(`## ${S.verify}`, '');
  verifyLines.unshift({ cmd: `curl -s -o /dev/null -w '%{http_code}\\n' ${urlRef}/`, expect: '200' });
  const seen = new Set();
  for (const v of verifyLines) {
    if (seen.has(v.cmd)) continue;
    seen.add(v.cmd);
    push(`- [ ] \`${v.cmd}\`${v.expect ? ` — ${S.expect}: ${v.expect}` : ''}`);
  }
  push('');
  if (rewritten) lines.splice(lines.indexOf(`## ${S.code}`), 0, `> ${fill(S.hostRewritten, { n: rewritten })}`, '');

  function endpointVerify(e) {
    const rule = rules[e.endpoint.endsWith('/') ? 'virtual-endpoint-prefix' : 'virtual-endpoint'];
    const sub = (s) => s.split('<endpoint>').join(e.endpoint).split('<prod-url>').join(urlRef);
    return { cmd: sub(rule.verify), expect: sub(rule.expect) };
  }

  const md = `${lines.join('\n').replace(/\n{3,}/g, '\n\n').trimEnd()}\n`;

  // --- leak gate: nothing local leaves in the runbook ----------------------------------
  const lower = md.toLowerCase();
  const leaks = [...localHosts].filter((h) => lower.includes(h));
  for (const m of md.matchAll(NON_PUBLIC)) if (!leaks.includes(m[0].toLowerCase())) leaks.push(m[0].toLowerCase());
  if (md.includes(root) && root !== '/') leaks.push(root);
  if (leaks.length) die(1, `the runbook would carry a local host or path (${leaks.join(', ')}); correct the replay entry that holds it`);

  mkdirSync(outDir, { recursive: true });
  const outPath = join(outDir, `runbook-${date}.md`);
  writeFileSync(outPath, md);
  console.log(`audit-runbook: wrote ${resolve(outPath)}`);
  process.exit(0);
}

try {
  main();
} catch (error) {
  console.error(`audit-runbook: ${error.stack || error.message}`);
  process.exit(3);
}
