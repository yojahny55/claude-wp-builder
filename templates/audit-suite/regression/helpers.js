// @ts-check
// Logica pura de la suite de regresion: mezcla de configuracion, deteccion de clon,
// lectura de precios, informe y comparacion antes/despues. No abre navegador, asi que
// regression/helpers.selfcheck.js la comprueba sin dependencias instaladas.

const isObj = (v) => v && typeof v === 'object' && !Array.isArray(v);

/** Mezcla en profundidad: los objetos se funden, el resto (listas, cadenas) se sustituye. */
function deepMerge(base, over) {
  if (!isObj(base) || !isObj(over)) return over === undefined ? base : over;
  const out = { ...base };
  for (const k of Object.keys(over)) out[k] = k in base ? deepMerge(base[k], over[k]) : over[k];
  return out;
}

/** true si el host es de desarrollo local: ahi el correo esta anulado y escribir es seguro. */
function isCloneHost(hostname) {
  const h = String(hostname || '').toLowerCase();
  if (!h) return false;
  if (h === 'localhost' || h.endsWith('.localhost') || h.endsWith('.local') || h.endsWith('.test')) return true;
  if (/\.local\./.test(h)) return true; // p. ej. sitio.local.example; 'local.example.com' (publico) no
  // IPs privadas completas: un prefijo no basta ('10.example.com' es un dominio publico)
  if (/^(127|10)(\.\d{1,3}){3}$/.test(h) || /^192\.168(\.\d{1,3}){2}$/.test(h) || /^172\.(1[6-9]|2\d|3[01])(\.\d{1,3}){2}$/.test(h)) return true;
  return false;
}

/** '1.234,50 EUR' / '$1,234.50' -> 1234.5; NaN si no hay numero. */
function parsePrice(text) {
  let s = String(text || '').replace(/[^\d.,]/g, '');
  if (!s) return NaN;
  if (s.includes(',') && s.includes('.')) {
    s = s.lastIndexOf(',') > s.lastIndexOf('.') ? s.replace(/\./g, '').replace(',', '.') : s.replace(/,/g, '');
  } else if (s.includes(',')) {
    s = /,\d{3}$/.test(s) ? s.replace(/,/g, '') : s.replace(',', '.');
  } else if (/^\d{1,3}(\.\d{3})+$/.test(s)) s = s.replace(/\./g, '');
  return parseFloat(s);
}

/** Marca de moneda de un texto de precio: simbolo o codigo ISO. */
function currencyToken(text) {
  const m = String(text || '').match(/[A-Z]{3}\b|[€$£¥₱₽₹]/);
  return m ? m[0] : '';
}

/** Orden esperado: devuelve true si la lista de numeros respeta asc/desc (ignora NaN). */
function isSorted(nums, dir) {
  const v = nums.filter((n) => Number.isFinite(n));
  if (v.length < 2) return false;
  for (let i = 1; i < v.length; i++) if (dir === 'asc' ? v[i] < v[i - 1] : v[i] > v[i - 1]) return false;
  return true;
}

/** Palabra de busqueda de un titulo: la primera de 4+ letras. */
function searchWord(title) {
  const w = String(title || '').split(/[^\p{L}\p{N}]+/u).find((x) => x.length >= 4);
  return w || '';
}

/**
 * Un `mail_failed` de CF7 solo es esperado en un clon aislado; `mail_sent` siempre vale.
 * @returns {{ok:boolean, note:string}}
 */
function judgeMailStatus(status, clone) {
  if (status === 'mail_sent') return { ok: true, note: 'mail_sent' };
  if (status === 'mail_failed' && clone) {
    return { ok: true, note: 'mail_failed (esperado: el clon tiene el correo anulado; la validacion y el envio llegaron al paso de correo)' };
  }
  return { ok: false, note: `estado inesperado "${status}"${status === 'mail_failed' ? ' fuera de un clon aislado: el sitio no puede enviar correo' : ''}` };
}

const ICON = { PASS: 'PASS', FAIL: 'FAIL', SKIP: 'SKIP' };
const esc = (s) => String(s == null ? '' : s).replace(/\|/g, '\\|').replace(/\s*\n\s*/g, ' ');

/**
 * @typedef {{id:string,title:string,project:string,status:'PASS'|'FAIL'|'SKIP',evidence:string,ms:number}} Row
 * @typedef {{url:string,status:number,jsErrors:string[],failed:string[]}} SweepRow
 */

/** Cuenta PASS/FAIL/SKIP. */
function tally(rows) {
  const t = { PASS: 0, FAIL: 0, SKIP: 0 };
  for (const r of rows) t[r.status] = (t[r.status] || 0) + 1;
  return t;
}

/** Informe Markdown: una fila por flujo, una columna por proyecto, mas el barrido. */
function renderMarkdown(run) {
  const rows = run.rows || [];
  const projects = [...new Set(rows.map((r) => r.project))].sort();
  const ids = [...new Set(rows.map((r) => r.id))];
  const L = [];
  L.push(`# Regresion de flujos de comprador${run.label ? ` (${run.label})` : ''}`);
  L.push('');
  L.push(`- Sitio: ${run.baseURL || '-'}`);
  L.push(`- Fecha: ${run.date || '-'}`);
  L.push(`- Aislamiento de clon: ${run.clone ? 'si (el correo esta anulado)' : 'no (los flujos que escriben solo corren con allowWrites)'}`);
  for (const p of projects) {
    const t = tally(rows.filter((r) => r.project === p));
    L.push(`- ${p}: ${t.PASS} PASS, ${t.FAIL} FAIL, ${t.SKIP} SKIP`);
  }
  L.push('');
  L.push(`| Flujo | ${projects.join(' | ')} |`);
  L.push(`|---|${projects.map(() => '---').join('|')}|`);
  for (const id of ids) {
    const cells = projects.map((p) => {
      const r = rows.find((x) => x.id === id && x.project === p);
      return r ? `${ICON[r.status]}` : '-';
    });
    const title = (rows.find((x) => x.id === id) || {}).title || id;
    L.push(`| ${esc(title)} (\`${id}\`) | ${cells.join(' | ')} |`);
  }
  const bad = rows.filter((r) => r.status === 'FAIL');
  if (bad.length) {
    L.push('', '## Fallos', '');
    for (const r of bad) L.push(`- **${r.id}** [${r.project}]: ${esc(r.evidence)}`);
  }
  const skipped = rows.filter((r) => r.status === 'SKIP');
  if (skipped.length) {
    L.push('', '## Omitidos', '');
    for (const r of skipped) L.push(`- ${r.id} [${r.project}]: ${esc(r.evidence)}`);
  }
  const passed = rows.filter((r) => r.status === 'PASS' && r.evidence);
  if (passed.length) {
    L.push('', '## Evidencia de los PASS', '');
    for (const r of passed) L.push(`- ${r.id} [${r.project}]: ${esc(r.evidence)}`);
  }
  const sweep = run.sweep || [];
  if (sweep.length) {
    L.push('', '## Barrido de URLs', '', '| Proyecto | URL | HTTP | Errores JS | Peticiones fallidas |', '|---|---|---|---|---|');
    for (const s of sweep) {
      L.push(`| ${s.project} | ${esc(s.url)} | ${s.status || 'ERR'} | ${s.jsErrors.length} | ${s.failed.length} |`);
    }
    const detail = sweep.filter((s) => s.jsErrors.length || s.failed.length);
    if (detail.length) {
      L.push('', '### Detalle del barrido', '');
      for (const s of detail) {
        for (const e of s.jsErrors.slice(0, 5)) L.push(`- ${s.project} ${esc(s.url)}: JS ${esc(e)}`);
        for (const e of s.failed.slice(0, 5)) L.push(`- ${s.project} ${esc(s.url)}: ${esc(e)}`);
      }
    }
  }
  L.push('');
  return L.join('\n');
}

/**
 * Compara dos ejecuciones (antes/despues). Regresion = PASS -> FAIL, o una URL del
 * barrido que antes cargaba y ahora no. PASS -> SKIP o una fila que desaparece tambien
 * lo son (la funcion puede haberse roto); con { allowSkips } pasan a aviso. Errores JS o peticiones fallidas nuevas en el barrido, tambien.
 */
function compareRuns(before, after, opts = {}) {
  const key = (r) => `${r.project}::${r.id}`;
  const prev = new Map((before.rows || []).map((r) => [key(r), r]));
  const seen = new Set((after.rows || []).map(key));
  const regressions = [], warnings = [], fixed = [];
  // Una funcion que dejo de poder ejercitarse (SKIP, o la fila desaparece) es lo que provoca una
  // actualizacion rota: la API Store que no responde pone en SKIP medio flujo. Solo --allow-skips
  // (comparar ejecuciones de alcance distinto) lo rebaja a aviso.
  const lost = opts.allowSkips ? warnings : regressions;
  for (const r of after.rows || []) {
    const p = prev.get(key(r));
    if (!p) continue;
    if (p.status === 'PASS' && r.status === 'FAIL') regressions.push(`${r.id} [${r.project}]: PASS -> FAIL (${r.evidence})`);
    else if (p.status === 'PASS' && r.status === 'SKIP') lost.push(`${r.id} [${r.project}]: PASS -> SKIP (${r.evidence})`);
    else if (p.status === 'FAIL' && r.status === 'PASS') fixed.push(`${r.id} [${r.project}]`);
  }
  for (const p of before.rows || []) {
    if (p.status === 'PASS' && !seen.has(key(p))) lost.push(`${p.id} [${p.project}]: PASS -> ausente en la segunda ejecucion`);
  }
  const sprev = new Map((before.sweep || []).map((s) => [`${s.project}::${s.url}`, s]));
  const safter = new Set((after.sweep || []).map((s) => `${s.project}::${s.url}`));
  for (const p of before.sweep || []) {
    if (p.status > 0 && p.status < 400 && !safter.has(`${p.project}::${p.url}`)) lost.push(`sweep ${p.url} [${p.project}]: HTTP ${p.status} -> ausente en la segunda ejecucion`);
  }
  for (const s of after.sweep || []) {
    const p = sprev.get(`${s.project}::${s.url}`);
    if (!p) continue;
    if (p.status > 0 && p.status < 400 && (s.status >= 400 || !s.status)) regressions.push(`sweep ${s.url} [${s.project}]: HTTP ${p.status} -> ${s.status || 'ERR'}`);
    const newJs = s.jsErrors.filter((e) => !p.jsErrors.includes(e));
    const newFailed = s.failed.filter((e) => !p.failed.includes(e));
    if (newJs.length) warnings.push(`sweep ${s.url} [${s.project}]: ${newJs.length} error(es) JS nuevo(s): ${newJs[0]}`);
    if (newFailed.length) warnings.push(`sweep ${s.url} [${s.project}]: ${newFailed.length} peticion(es) fallida(s) nueva(s): ${newFailed[0]}`);
  }
  return { regressions, warnings, fixed };
}

module.exports = {
  deepMerge, isCloneHost, parsePrice, currencyToken, isSorted, searchWord,
  judgeMailStatus, tally, renderMarkdown, compareRuns,
};
