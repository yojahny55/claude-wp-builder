/**
 * adopt.mjs: register a WordPress site this plugin did not build, without changing it.
 *
 * /wp-create's Adopt Mode reconfigures an existing install (vhost, SSL, options, languages,
 * permissions). This is the other thing: it only READS the site -- one WP-CLI probe and a
 * look at the files -- and proposes the manifest that lets /wp-audit, /wp-debug and
 * /wp-clone run against it. The operator confirms the proposal; the site is never touched.
 */
import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join, resolve, basename } from 'node:path';
import { CURRENT_VERSION, STACK_KEYS, CODE_HOME_KINDS } from './manifest.mjs';

// Active plugin slug (its directory, or the file for a single-file plugin) -> the name the
// audit agents branch on. First match per concern wins, in this order, so a site running two
// SEO plugins reports the one listed first -- and the probe reports both, see `conflicts`.
export const STACK_SIGNATURES = {
  seo: [
    ['seo-by-rank-math', 'rankmath'], ['seo-by-rank-math-pro', 'rankmath'],
    ['wordpress-seo', 'yoast'], ['wordpress-seo-premium', 'yoast'],
    ['wp-seopress', 'seopress'], ['all-in-one-seo-pack', 'aioseo'], ['all-in-one-seo-pack-pro', 'aioseo'],
    ['autodescription', 'seo-framework'], ['slim-seo', 'slim-seo'], ['squirrly-seo', 'squirrly'],
  ],
  security: [
    ['all-in-one-wp-security-and-firewall', 'aios'], ['wordfence', 'wordfence'],
    ['better-wp-security', 'solid-security'], ['ithemes-security-pro', 'solid-security'],
    ['sucuri-scanner', 'sucuri'], ['wp-cerber', 'cerber'], ['defender-security', 'defender'],
    ['shield-security', 'shield'], ['ninjafirewall', 'ninjafirewall'],
  ],
  fields: [
    ['secure-custom-fields', 'scf'], ['advanced-custom-fields-pro', 'acf'], ['advanced-custom-fields', 'acf'],
    ['meta-box', 'meta-box'], ['pods', 'pods'], ['carbon-fields', 'carbon-fields'],
  ],
  multilingual: [
    ['polylang', 'polylang'], ['polylang-pro', 'polylang'], ['sitepress-multilingual-cms', 'wpml'],
    ['translatepress-multilingual', 'translatepress'], ['weglot', 'weglot'], ['multilingualpress', 'multilingualpress'],
  ],
  builder: [
    ['elementor', 'elementor'], ['elementor-pro', 'elementor'], ['js_composer', 'wpbakery'],
    ['beaver-builder-lite-version', 'beaver-builder'], ['bb-plugin', 'beaver-builder'],
    ['oxygen', 'oxygen'], ['brizy', 'brizy'], ['siteorigin-panels', 'siteorigin'], ['breakdance', 'breakdance'],
  ],
  cache: [
    ['litespeed-cache', 'litespeed'], ['wp-rocket', 'wp-rocket'], ['w3-total-cache', 'w3tc'],
    ['wp-super-cache', 'wp-super-cache'], ['wp-fastest-cache', 'wp-fastest-cache'],
    ['sg-cachepress', 'siteground'], ['breeze', 'breeze'], ['cache-enabler', 'cache-enabler'],
    ['autoptimize', 'autoptimize'], ['perfmatters', 'perfmatters'],
  ],
};

// Themes that ARE page builders; a site on them has no builder plugin to detect. Keys are
// template slugs: Themeco ships X as `x` and its successor Pro as `pro`, both one builder.
const BUILDER_THEMES = { divi: 'divi', bricks: 'bricks', avada: 'avada', x: 'x-pro', pro: 'x-pro' };

// One probe, everything in it. Each extra `wp` call is a WordPress boot, and on a Docker
// wrapper a container exec -- and a probe split across calls can read two different states.
// Paths are made relative to ABSPATH inside PHP because only PHP knows where the container
// mounted things; the host path and the container path of the same file differ.
// `checked` is never read, for plugins or themes: wp_update_plugins() and wp_update_themes()
// fill it with EVERY installed item's version before asking anyone, so an item listed there
// is merely installed. Only `response` and `no_update` mean an updater answered for it.
export const PROBE_PHP = `
$rel = function ($p) { $a = wp_normalize_path(ABSPATH); $p = wp_normalize_path($p); return strpos($p, $a) === 0 ? ltrim(substr($p, strlen($a)), '/') : null; };
if (!function_exists('get_plugins')) { require_once ABSPATH . 'wp-admin/includes/plugin.php'; }
$up = get_site_transient('update_plugins'); $known = array();
foreach (array('response', 'no_update') as $k) { if (is_object($up) && isset($up->$k) && is_array($up->$k)) { $known = array_merge($known, array_keys($up->$k)); } }
$ut = get_site_transient('update_themes'); $tknown = array();
foreach (array('response', 'no_update') as $k) { if (is_object($ut) && isset($ut->$k) && is_array($ut->$k)) { $tknown = array_merge($tknown, array_keys($ut->$k)); } }
$plugins = array(); $active = (array) get_option('active_plugins', array());
foreach (get_plugins() as $file => $h) {
  $dir = dirname($file);
  $plugins[] = array('file' => $file, 'slug' => $dir === '.' ? basename($file, '.php') : $dir,
    'name' => $h['Name'], 'update_uri' => isset($h['UpdateURI']) ? $h['UpdateURI'] : '',
    'active' => in_array($file, $active, true), 'known_to_updater' => in_array($file, $known, true),
    'path' => $rel(WP_PLUGIN_DIR . '/' . ($dir === '.' ? $file : $dir)));
}
$mu = array(); foreach (array_keys(get_mu_plugins()) as $f) { $mu[] = $f; }
$t = wp_get_theme(); $parent = $t->parent();
$langs = function_exists('pll_languages_list') ? pll_languages_list() : array();
echo '<<WPCB-PROBE>>' . wp_json_encode(array(
  'home' => home_url(), 'blogname' => get_option('blogname'), 'locale' => get_locale(),
  'pll_default' => function_exists('pll_default_language') ? pll_default_language() : null, 'pll_languages' => $langs,
  'multisite' => is_multisite(), 'php' => PHP_VERSION, 'wp' => get_bloginfo('version'),
  'stylesheet' => get_stylesheet(), 'template' => get_template(),
  'theme_path' => $rel(get_stylesheet_directory()), 'parent_path' => $parent ? $rel(get_template_directory()) : null,
  'theme_known_to_updater' => in_array(get_stylesheet(), $tknown, true),
  'parent_known_to_updater' => $parent ? in_array(get_template(), $tknown, true) : null,
  'plugins' => $plugins, 'mu_plugins' => $mu, 'mu_path' => $rel(WPMU_PLUGIN_DIR),
)) . '<<END-WPCB-PROBE>>';
`.replace(/\n/g, ' ');

export function detectWrapper(root) {
  if (existsSync(join(root, '.ddev', 'config.yaml'))) return { wrapper: 'ddev wp', engine: 'ddev', type: 'docker' };
  if (existsSync(join(root, '.lando.yml'))) return { wrapper: 'lando wp', engine: 'lando', type: 'docker' };
  return { wrapper: `wp --path=${root}`, engine: 'native', type: 'native' };
}

// The wrapper is split on whitespace and run without a shell: the probe is PHP full of `$`
// and quotes, and passing it as one argv entry is the only way it arrives intact. Wrappers
// are commands like `docker exec my-wp wp --allow-root`, never quoted strings.
export function runProbe(wrapper) {
  const [bin, ...args] = wrapper.trim().split(/\s+/);
  const r = spawnSync(bin, [...args, 'eval', PROBE_PHP], { encoding: 'utf8', timeout: 120000 });
  if (r.error) return { ok: false, reason: `could not run ${bin}: ${r.error.code ?? r.error.message}` };
  if (r.status !== 0) return { ok: false, reason: `${wrapper} eval exited ${r.status}: ${(r.stderr || r.stdout).trim().split('\n').pop()}` };
  return parseProbeOutput(r.stdout, wrapper);
}

// A plugin that prints on boot (deprecation notices, a logger flushing at shutdown) puts text
// before and after the probe's JSON, so the JSON travels between sentinels and only that
// region is parsed. Output without sentinels (an older probe, a fake) falls back to its last
// line, which is what this function read before the sentinels existed.
export function parseProbeOutput(stdout, wrapper = 'the wrapper') {
  const m = /<<WPCB-PROBE>>([\s\S]*?)<<END-WPCB-PROBE>>/.exec(stdout);
  const text = m ? m[1] : stdout.trim().split('\n').pop();
  try {
    return { ok: true, probe: JSON.parse(text) };
  } catch {
    return { ok: false, reason: `${wrapper} eval did not print the probe's JSON between its sentinels` };
  }
}

// Compare a registered manifest with the site as it is now. A blank scaffold restored over by
// a real site validates (the schema is satisfied) and describes the wrong site, so validation
// cannot catch it. Returns one line per disagreement; empty means the manifest still fits.
export function manifestDrift(manifest, probe, root) {
  const out = [];
  const slug = manifest.theme?.slug;
  if (slug && !existsSync(join(root, 'wp-content', 'themes', slug))) {
    out.push(`theme.slug "${slug}" has no directory under wp-content/themes`);
  }
  if (slug && probe.stylesheet && slug !== probe.stylesheet) {
    out.push(`theme.slug "${slug}" is not the active theme "${probe.stylesheet}"`);
  }
  const active = probe.plugins.filter((p) => p.active).map((p) => p.slug);
  const claimed = manifest.plugins?.installed ?? [];
  // A plugin the operator turned off on purpose (a security plugin disabled on a local copy)
  // is recorded in plugins.intentionally_inactive and is not a disagreement.
  const parked = manifest.plugins?.intentionally_inactive ?? [];
  const missing = active.filter((x) => !claimed.includes(x));
  const extra = claimed.filter((x) => !active.includes(x) && !parked.includes(x));
  if (missing.length) out.push(`${missing.length} active plugin(s) not in plugins.installed: ${missing.slice(0, 8).join(', ')}${missing.length > 8 ? ', …' : ''}`);
  if (extra.length) out.push(`${extra.length} plugin(s) in plugins.installed that are not active: ${extra.slice(0, 8).join(', ')}${extra.length > 8 ? ', …' : ''}`);
  // A plugin that was deleted leaves its path behind in the scope lists, and the generated
  // block would keep listing it. Plugin paths are measured fact (refresh prunes them); any
  // other missing path means the scope was written for another tree.
  const gone = scopePaths(manifest).filter((x) => !existsSync(join(root, x)));
  const gonePlugins = gone.filter((x) => x.startsWith('wp-content/plugins/'));
  const goneOther = gone.filter((x) => !x.startsWith('wp-content/plugins/') && x !== `wp-content/themes/${slug}`);
  if (gonePlugins.length) out.push(`${gonePlugins.length} plugin path(s) in code_scope no longer on disk: ${gonePlugins.slice(0, 8).join(', ')}${gonePlugins.length > 8 ? ', …' : ''}`);
  if (goneOther.length) out.push(`${goneOther.length} path(s) in code_scope no longer on disk: ${goneOther.slice(0, 8).join(', ')}`);
  if (manifest.project?.source === 'blank' && active.length) out.push('project.source is "blank" but the site has active plugins');
  return out;
}

// A drift line that only says the plugin list changed (an owner deactivated or installed
// plugins) is measured fact the probe can refresh; every other line says the manifest
// describes another site, which only a re-adoption answers.
export function isPluginListDrift(line) {
  return /^\d+ active plugin\(s\) not in plugins\.installed|^\d+ plugin\(s\) in plugins\.installed that are not active|^\d+ plugin path\(s\) in code_scope no longer on disk/.test(line);
}

function scopePaths(manifest) {
  const s = manifest.code_scope ?? {};
  return [...(Array.isArray(s.editable) ? s.editable : []), ...(Array.isArray(s.read_only) ? s.read_only : [])]
    .filter((x) => typeof x === 'string');
}

// What `refresh` writes: the measured facts (active plugins, stack, versions) and nothing
// the operator decided. Plugins recorded as intentionally inactive stay in the list while
// they are still on disk, and still count toward the stack: the stack describes the site,
// not this machine's switches. Plugin paths that no longer exist leave code_scope, so the
// generated block stops listing a deleted plugin as read-only code.
export function refreshManifest(manifest, probe, root) {
  const next = structuredClone(manifest);
  const onDisk = new Set(probe.plugins.map((p) => p.slug));
  const parked = (next.plugins?.intentionally_inactive ?? []).filter((x) => onDisk.has(x));
  const active = probe.plugins.filter((p) => p.active).map((p) => p.slug);
  next.plugins = { ...next.plugins, installed: [...new Set([...active, ...parked])] };
  if (next.plugins.intentionally_inactive !== undefined) next.plugins.intentionally_inactive = parked;
  if (next.stack !== undefined || next.origin === 'adopted') {
    const probeForStack = { ...probe, plugins: probe.plugins.map((p) => ({ ...p, active: p.active || parked.includes(p.slug) })) };
    next.stack = detectStack(probeForStack).stack;
  }
  if (next.environment && probe.php) next.environment.php_version = probe.php;
  if (next.wordpress && probe.wp) next.wordpress.version = probe.wp;
  const pruned = [];
  if (next.code_scope) {
    for (const list of ['editable', 'read_only']) {
      if (!Array.isArray(next.code_scope[list])) continue;
      next.code_scope[list] = next.code_scope[list].filter((x) => {
        const gone = typeof x === 'string' && x.startsWith('wp-content/plugins/') && !existsSync(join(root, x));
        if (gone) pruned.push(x);
        return !gone;
      });
    }
  }
  return { next, pruned };
}

// Plugins that exist to move or inspect the site, not to carry its behavior. An editable
// scope holding only these has no home for the fixes an audit proposes.
export const TOOLING_PLUGINS = ['ix-wp-envsync'];
export { CODE_HOME_KINDS };

// True when nothing in the editable scope is code the site owns: no theme, no mu-plugin
// directory, and no plugin beyond the tooling ones. The operator is then asked once where
// site-owned code lives, instead of every fix inventing an answer.
export function needsCodeHome(manifest) {
  if (manifest.code_home) return false;
  const editable = manifest.code_scope?.editable ?? [];
  return !editable.some((x) => {
    if (x.startsWith('wp-content/themes/') || x.startsWith('wp-content/mu-plugins')) return true;
    const slug = x.replace(/^wp-content\/plugins\//, '').replace(/\.php$/, '');
    return !TOOLING_PLUGINS.includes(slug);
  });
}

// The planned location of the site's own code. Nothing is created here: adoption never
// writes to the site. `created` says whether the path exists yet; the fix flow checks it.
export function planCodeHome(kind, probe, root, wanted) {
  const parent = probe.template || probe.stylesheet;
  const path = wanted
    || (kind === 'child-theme' ? `wp-content/themes/${probe.parent_path ? probe.stylesheet : `${parent}-child`}`
      : kind === 'site-plugin' ? `wp-content/plugins/${basename(root).toLowerCase().replace(/[^a-z0-9-]+/g, '-')}-site`
        : probe.mu_path || 'wp-content/mu-plugins');
  const home = { kind, path, created: existsSync(join(root, path)) };
  if (kind === 'child-theme') home.parent = parent;
  return home;
}

// The WP-CLI that moves the parent theme's Customizer settings (menus, colors, logo, widget
// area assignments) to a new child theme. theme_mods are stored per stylesheet, so activating
// the child without this resets them. Run it BEFORE `theme activate`.
export function themeModsSteps(parent, child, wrapper = 'wp') {
  return [
    `${wrapper} option get theme_mods_${parent} --format=json | ${wrapper} option update theme_mods_${child} --format=json`,
    `${wrapper} theme activate ${child}`,
  ];
}

// A blank scaffold carries no operator decisions worth keeping: it was never an adoption or a
// real build, or a real site was restored over it. Same two signals manifestDrift uses.
export function isScaffoldManifest(manifest, root, activeTheme) {
  if (manifest?.project?.source === 'blank') return true;
  const slug = manifest?.theme?.slug;
  if (!slug) return false;
  // Another active theme means the decisions were made for another site, even if the old
  // theme's directory is still on disk.
  if (activeTheme && slug !== activeTheme) return true;
  return !existsSync(join(root, 'wp-content', 'themes', slug));
}

// What a re-adoption keeps from the manifest it replaces: audit history, the store block, and
// the operator's decisions as defaults (an explicit flag still wins, applied by the caller).
// Scope paths that no longer exist on disk are dropped; paths in neither old list are new
// and keep the proposal's placement.
export function carryOver(old, manifest, root, flags = {}) {
  const notes = [];
  if (old.audit !== undefined) { manifest.audit = old.audit; notes.push('audit'); }
  if (old.store !== undefined) { manifest.store = old.store; notes.push('store'); }
  if (old.environments !== undefined) { manifest.environments = old.environments; notes.push('environments'); }
  if (old.code_home !== undefined && manifest.code_home === undefined) { manifest.code_home = old.code_home; notes.push('code_home'); }
  if (old.plugins?.intentionally_inactive !== undefined) { manifest.plugins.intentionally_inactive = old.plugins.intentionally_inactive; notes.push('plugins.intentionally_inactive'); }
  if (old.project?.adopted) manifest.project.adopted = old.project.adopted;
  if (!flags.prefix && typeof old.project?.prefix === 'string' && old.project.prefix) {
    manifest.project.prefix = old.project.prefix;
    notes.push('project.prefix');
  }
  if (!flags.industry && typeof old.project?.industry === 'string' && old.project.industry) {
    manifest.project.industry = old.project.industry;
    notes.push('project.industry');
  }
  const oldScope = old.code_scope ?? {};
  const known = new Set([...(oldScope.editable ?? []), ...(oldScope.read_only ?? [])]);
  const live = (l) => (Array.isArray(l) ? l : []).filter((x) => existsSync(join(root, x)));
  const fresh = (l) => l.filter((x) => !known.has(x));
  const proposed = manifest.code_scope;
  const kept = {};
  if (flags.editable === undefined && Array.isArray(oldScope.editable)) {
    kept.editable = [...live(oldScope.editable), ...fresh(proposed.editable)];
    notes.push('code_scope.editable');
  }
  if (flags['read-only'] === undefined && Array.isArray(oldScope.read_only)) {
    kept.read_only = [...live(oldScope.read_only), ...fresh(proposed.read_only)];
    notes.push('code_scope.read_only');
  }
  manifest.code_scope = { ...proposed, ...kept };
  return notes;
}

// A wrapper that points into a temp directory is a one-run helper (a script that filters
// plugin noise), not how this site is reached. Persisting it breaks the next command.
export function isTransientWrapper(wrapper, tmp = tmpdir()) {
  const bin = resolve(wrapper.trim().split(/\s+/)[0].replace(/^["']|["']$/g, ''));
  return [tmp, '/tmp', '/var/tmp', '/dev/shm'].some((d) => bin.startsWith(`${d}/`));
}

export function detectStack(probe) {
  const active = new Set(probe.plugins.filter((p) => p.active).map((p) => p.slug));
  const stack = {};
  const conflicts = [];
  for (const key of STACK_KEYS) {
    const hits = [...new Set(STACK_SIGNATURES[key].filter(([slug]) => active.has(slug)).map(([, name]) => name))];
    stack[key] = hits[0] ?? 'none';
    if (hits.length > 1) conflicts.push(`${key}: ${hits.join(' + ')} are both active`);
  }
  if (stack.builder === 'none') {
    const t = BUILDER_THEMES[probe.template?.toLowerCase()];
    if (t) stack.builder = t;
  }
  return { stack, conflicts };
}

// Most frequent `xxx_` prefix among the functions a theme declares. A child theme of a
// commercial theme usually has a handful; the answer is a proposal the operator confirms.
export function inferPrefix(root, themePath, fallbackSlug) {
  const counts = new Map();
  const dir = themePath ? join(root, themePath) : null;
  const files = [];
  const walk = (d, depth) => {
    if (depth > 3 || !existsSync(d)) return;
    // A live site's files can vanish or be unreadable mid-walk (a deploy, a cache purge,
    // another owner's permissions). The prefix is a proposal, so a skipped file costs a
    // vote, while an exception would abort an adoption whose probe already succeeded.
    let entries;
    try { entries = readdirSync(d); } catch { return; }
    for (const e of entries) {
      if (e === 'node_modules' || e === 'vendor' || e.startsWith('.')) continue;
      const f = join(d, e);
      let st;
      try { st = statSync(f); } catch { continue; }
      if (st.isDirectory()) walk(f, depth + 1);
      else if (e.endsWith('.php')) files.push(f);
    }
  };
  if (dir) walk(dir, 0);
  // One- and two-segment candidates both count: a child theme's `parent_child_*` functions
  // all share `parent_`, which is the PARENT's prefix -- proposing it would name new
  // functions into the vendor's namespace. The longer candidate wins when it covers at
  // least 80% of what the shorter one does.
  for (const f of files) {
    let src;
    try { src = readFileSync(f, 'utf8'); } catch { continue; }
    for (const m of src.matchAll(/^\s*function\s+([a-z][a-z0-9]*_)([a-z0-9]+_)?[a-z0-9_]*\s*\(/gim)) {
      const one = m[1].toLowerCase();
      counts.set(one, (counts.get(one) ?? 0) + 1);
      if (m[2]) {
        const two = `${one}${m[2].toLowerCase()}`;
        counts.set(two, (counts.get(two) ?? 0) + 1);
      }
    }
  }
  const byCount = (a, b) => b[1] - a[1];
  const ones = [...counts.entries()].filter(([p]) => p.split('_').length === 2).sort(byCount);
  let best = ones[0];
  if (best) {
    const two = [...counts.entries()].filter(([p]) => p.startsWith(best[0]) && p !== best[0]).sort(byCount)[0];
    if (two && two[1] >= 0.8 * best[1]) best = two;
  }
  if (best) return { prefix: best[0], source: `${best[1]} function(s) in ${themePath}` };
  return { prefix: `${fallbackSlug.replace(/[^a-z0-9]+/gi, '_').replace(/^_+|_+$/g, '').toLowerCase()}_`, source: 'theme slug (no prefixed functions found)' };
}

// Own code vs vendor code. The signal is the updater: WordPress keeps every plugin and
// theme it can update -- from wp.org or from a vendor's licensed updater that hooks the
// same transient -- in update_plugins / update_themes. Code no updater knows about is
// almost always the site's own. It is a proposal: the operator confirms every line, and
// an empty transient (a site that never checked for updates) makes everything "unknown".
export function proposeScope(probe) {
  const editable = [];
  const readOnly = [];
  const reasons = {};
  const put = (list, path, why) => {
    if (!path || editable.includes(path) || readOnly.includes(path)) return;
    list.push(path);
    reasons[path] = why;
  };
  if (probe.parent_path) {
    put(editable, probe.theme_path, 'active child theme');
    put(readOnly, probe.parent_path, probe.parent_known_to_updater ? 'parent theme, updated by an updater' : 'parent theme');
  } else if (probe.theme_known_to_updater) {
    put(readOnly, probe.theme_path, 'active theme, updated by an updater -- a commercial or wp.org theme');
  } else {
    put(editable, probe.theme_path, 'active theme, unknown to any updater');
  }
  for (const p of probe.plugins.filter((x) => x.active)) {
    const own = !p.known_to_updater || p.update_uri === 'false';
    put(own ? editable : readOnly, p.path, own
      ? (p.update_uri === 'false' ? 'plugin with "Update URI: false"' : 'active plugin unknown to any updater')
      : 'active plugin updated by an updater');
  }
  if (probe.mu_plugins.length && probe.mu_path) put(editable, probe.mu_path, `${probe.mu_plugins.length} mu-plugin(s)`);
  return { editable, read_only: readOnly, reasons };
}

export function buildManifest(root, probe, detected, overrides = {}) {
  const { stack, conflicts } = detectStack(probe);
  const scope = proposeScope(probe);
  const prefix = inferPrefix(root, probe.theme_path, probe.stylesheet);
  // Polylang slugs may be `en-us` or `pt-br`; the manifest holds two-letter codes. Every
  // slug is normalised the same way BEFORE comparing, or the default language (`en-us`)
  // survives the filter against its own truncation (`en`) and is listed as additional.
  const lang = (l) => String(l).slice(0, 2).toLowerCase();
  const primary = lang(probe.pll_default ?? probe.locale ?? 'en');
  const additional = [...new Set((probe.pll_languages ?? []).map(lang))].filter((l) => l !== primary);
  const slug = basename(root).toLowerCase().replace(/[^a-z0-9-]+/g, '-');
  let domain = '';
  try { domain = new URL(probe.home).host; } catch { /* reported by validate as a bad url */ }
  const manifest = {
    manifest_version: CURRENT_VERSION,
    origin: 'adopted',
    project: {
      name: overrides.name ?? probe.blogname ?? slug,
      slug,
      domain,
      path: root,
      prefix: overrides.prefix ?? prefix.prefix,
      industry: overrides.industry ?? 'unknown',
      adopted: new Date().toISOString().slice(0, 10),
    },
    environment: {
      type: overrides.type ?? detected.type,
      engine: overrides.engine ?? detected.engine,
      php_version: probe.php,
    },
    wordpress: { url: probe.home, version: probe.wp },
    languages: { primary, additional, default: primary },
    plugins: { profile: 'none', installed: probe.plugins.filter((p) => p.active).map((p) => p.slug) },
    theme: { slug: probe.stylesheet, parent: probe.template !== probe.stylesheet ? probe.template : null, initialized: false },
    wp_cli: { wrapper: overrides.wrapper ?? detected.wrapper, path_flag: '' },
    code_scope: {
      editable: overrides.editable ?? scope.editable,
      read_only: overrides.read_only ?? scope.read_only,
    },
    stack,
    'i18n strategy': stack.multilingual === 'polylang' ? 'polylang' : 'none',
  };
  return { manifest, reasons: scope.reasons, prefixSource: prefix.source, conflicts };
}

// wp-load.php marks the root; wp-config.php may sit one directory above it, as WordPress allows.
export function isWordPressRoot(root) {
  return existsSync(join(root, 'wp-load.php'))
    && (existsSync(join(root, 'wp-config.php')) || existsSync(join(resolve(root, '..'), 'wp-config.php')));
}
