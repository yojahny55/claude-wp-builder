/**
 * Tabs — the WAI-ARIA tabs pattern, state included.
 *
 * A build's tabs script only slid the underline marker under the clicked tab: no
 * aria-selected, no panel switch, no keyboard. It looked right in a screenshot and
 * did nothing for anyone reading the panels. This module owns the whole state:
 *
 *   <div data-tabs>
 *     <div role="tablist" aria-label="…">
 *       <button role="tab" id="t-1" aria-controls="p-1" aria-selected="true" class="is-active">
 *         <span data-tab-label>First</span>
 *       </button>
 *       <button role="tab" id="t-2" aria-controls="p-2" aria-selected="false">
 *         <span data-tab-label>Second</span>
 *       </button>
 *       <span data-tabs-marker aria-hidden="true"></span>   (optional underline)
 *     </div>
 *     <div role="tabpanel" id="p-1" aria-labelledby="t-1" tabindex="0">…</div>
 *     <div role="tabpanel" id="p-2" aria-labelledby="t-2" tabindex="0" hidden>…</div>
 *   </div>
 *
 * - The selected tab gets aria-selected="true", `is-active` and tabindex 0; the
 *   others aria-selected="false" and tabindex -1 (roving tabindex). Style the
 *   active state from `aria-selected:` or `.is-active`, never from :focus.
 * - Every panel but the selected one is `hidden`.
 * - ArrowLeft/ArrowRight (ArrowUp/ArrowDown when the tablist is
 *   aria-orientation="vertical"), Home and End move focus and select.
 * - The marker is positioned under the active tab's LABEL, and as wide as the
 *   label, not the whole button: `[data-tab-label]` when present, the tab itself
 *   otherwise. It is re-measured on resize and once the web fonts have loaded,
 *   because a label measured in the fallback font is the wrong width.
 */

const select = (root, tab, { focus = false } = {}) => {
  const tabs = [...root.querySelectorAll('[role="tab"]')];
  tabs.forEach((t) => {
    const on = t === tab;
    t.setAttribute('aria-selected', on ? 'true' : 'false');
    t.classList.toggle('is-active', on);
    t.tabIndex = on ? 0 : -1;
    const panel = document.getElementById(t.getAttribute('aria-controls') || '');
    if (panel) {
      panel.hidden = !on;
    }
  });
  if (focus) {
    tab.focus();
  }
  placeMarker(root);
};

const placeMarker = (root) => {
  const marker = root.querySelector('[data-tabs-marker]');
  const active = root.querySelector('[role="tab"][aria-selected="true"]');
  if (!marker || !active) {
    return;
  }
  const label = active.querySelector('[data-tab-label]') || active;
  const base = marker.offsetParent || root;
  const a = label.getBoundingClientRect();
  const b = base.getBoundingClientRect();
  marker.style.width = `${a.width}px`;
  marker.style.transform = `translateX(${a.left - b.left + base.scrollLeft}px)`;
};

const initOne = (root) => {
  const list = root.querySelector('[role="tablist"]');
  const tabs = [...root.querySelectorAll('[role="tab"]')];
  if (!list || !tabs.length) {
    return;
  }
  const vertical = list.getAttribute('aria-orientation') === 'vertical';
  const initial = tabs.find((t) => t.getAttribute('aria-selected') === 'true') || tabs[0];
  select(root, initial);

  tabs.forEach((tab) => {
    tab.addEventListener('click', () => select(root, tab));
    tab.addEventListener('keydown', (e) => {
      const i = tabs.indexOf(tab);
      const next = vertical ? 'ArrowDown' : 'ArrowRight';
      const prev = vertical ? 'ArrowUp' : 'ArrowLeft';
      let target = null;
      if (e.key === next) target = tabs[(i + 1) % tabs.length];
      else if (e.key === prev) target = tabs[(i - 1 + tabs.length) % tabs.length];
      else if (e.key === 'Home') target = tabs[0];
      else if (e.key === 'End') target = tabs[tabs.length - 1];
      if (target) {
        e.preventDefault();
        select(root, target, { focus: true });
      }
    });
  });

  if ('ResizeObserver' in window) {
    new ResizeObserver(() => placeMarker(root)).observe(list);
  } else {
    window.addEventListener('resize', () => placeMarker(root));
  }
  if (document.fonts && document.fonts.ready) {
    document.fonts.ready.then(() => placeMarker(root));
  }
};

export const initTabs = (scope = document) => {
  scope.querySelectorAll('[data-tabs]').forEach(initOne);
};
