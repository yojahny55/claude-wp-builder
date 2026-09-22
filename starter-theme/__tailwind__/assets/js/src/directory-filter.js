/**
 * Directory filter — text and select filters over a list the server already rendered.
 *
 * One directory on a build had a results count and a "clear filters" control and two
 * others did not, because each filter bar was written by hand for its own template.
 * Every directory (a CPT archive, a Page listing terms) uses this one module:
 *
 *   <div data-directory>
 *     <input type="search" data-filter-text aria-label="…">
 *     <select data-filter="branch" data-filter-param="location" aria-label="…">
 *       <option value="">…all…</option>
 *       <option value="north">North</option>
 *     </select>
 *     <button type="button" data-filter-clear hidden>…clear filters…</button>
 *
 *     <p data-filter-count aria-live="polite" hidden
 *        data-count-template="{count} results" data-count-template-one="1 result"></p>
 *
 *     <ul>
 *       <li data-filter-item data-filter-search="name role …" data-branch="north south">…</li>
 *     </ul>
 *     <p data-filter-empty hidden>…no results…</p>
 *   </div>
 *
 * - Text: `[data-filter-text]` matches each item's `data-filter-search` (or its text),
 *   case- and accent-insensitive.
 * - Selects: `[data-filter="<key>"]` matches the item's `data-<key>`, a space-separated
 *   list of slugs. An empty value means "all". A custom combobox takes part by carrying
 *   `data-filter` on the element that holds its `value` (a hidden input) and listening
 *   for `directory-filter:reset` to reset its visible label.
 * - Count: every string comes from the template, printed through the theme's i18n
 *   helper, so this file carries no literal. `{count}` is replaced; the `-one` variant
 *   is used for exactly one result. The line is hidden while nothing is filtered.
 * - Clear: resets the text, every select and combobox, and hides itself. When the
 *   page was loaded already filtered by the URL (`data-filter-param` names the GET
 *   parameter a control mirrors, so the server-filtered list matches), clearing
 *   reloads the archive without those parameters: the rendered list is the filtered
 *   one, and showing "everything" means asking the server again.
 *
 * A GET parameter name must never be a public query var. A CPT or taxonomy slug
 * (`branch`, `province`) is one: WordPress reads `?<slug>=x` as a query for that
 * object and answers with its archive or a 404 before the template runs. Name the
 * parameter something no registered type or taxonomy uses.
 */

const norm = (s) =>
  (s || '')
    .toString()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .trim();

const initOne = (root) => {
  const text = root.querySelector('[data-filter-text]');
  const selects = [...root.querySelectorAll('[data-filter]')];
  const clear = root.querySelector('[data-filter-clear]');
  const count = root.querySelector('[data-filter-count]');
  const empty = root.querySelector('[data-filter-empty]');
  const items = [...root.querySelectorAll('[data-filter-item]')];

  const params = new URLSearchParams(window.location.search);
  const urlParams = [text, ...selects]
    .map((el) => el && el.getAttribute('data-filter-param'))
    .filter((name) => name && params.has(name));
  [text, ...selects].forEach((el) => {
    const name = el && el.getAttribute('data-filter-param');
    if (name && params.has(name)) {
      el.value = params.get(name);
    }
  });

  const apply = () => {
    const q = norm(text && text.value);
    const active = selects.filter((s) => s.value !== '');
    let shown = 0;
    items.forEach((item) => {
      const haystack = norm(item.getAttribute('data-filter-search') || item.textContent);
      const okText = !q || haystack.includes(q);
      const okSelects = active.every((s) => {
        const key = s.getAttribute('data-filter');
        const values = (item.getAttribute(`data-${key}`) || '').split(/\s+/);
        return values.includes(s.value);
      });
      const visible = okText && okSelects;
      item.hidden = !visible;
      if (visible) shown++;
    });

    const filtered = q !== '' || active.length > 0 || urlParams.length > 0;
    if (count) {
      const one = count.getAttribute('data-count-template-one');
      const tpl = shown === 1 && one ? one : count.getAttribute('data-count-template') || '{count}';
      count.textContent = tpl.replace('{count}', String(shown));
      count.hidden = !filtered;
    }
    if (clear) {
      clear.hidden = !filtered;
    }
    if (empty) {
      empty.hidden = shown !== 0;
    }
  };

  if (text) {
    text.addEventListener('input', apply);
  }
  selects.forEach((s) => s.addEventListener('change', apply));

  if (clear) {
    clear.addEventListener('click', () => {
      if (urlParams.length) {
        const url = new URL(window.location.href);
        urlParams.forEach((name) => url.searchParams.delete(name));
        url.searchParams.delete('paged');
        window.location.assign(url.toString());
        return;
      }
      if (text) {
        text.value = '';
      }
      selects.forEach((s) => {
        s.value = '';
        s.dispatchEvent(new CustomEvent('directory-filter:reset', { bubbles: true }));
      });
      apply();
      (text || selects[0] || root).focus();
    });
  }

  apply();
};

export const initDirectoryFilters = (scope = document) => {
  scope.querySelectorAll('[data-directory]').forEach(initOne);
};
