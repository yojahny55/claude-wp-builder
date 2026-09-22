/**
 * Accordion — disclosure buttons, grouped or standalone.
 *
 *   <div data-accordion="single">                     (a FAQ list: one open at a time)
 *     <div data-accordion-item>
 *       <h3>
 *         <button type="button" data-accordion-trigger aria-expanded="false"
 *                 aria-controls="faq-1" class="group …">
 *           Question
 *           <span class="icon-… group-aria-expanded:rotate-180" aria-hidden="true"></span>
 *         </button>
 *       </h3>
 *       <div id="faq-1" data-accordion-panel hidden>Answer</div>
 *     </div>
 *   </div>
 *
 * - A group is its closest `[data-accordion]`, so two FAQ lists on one page never
 *   close each other. `data-accordion="single"` (the default for a group, and
 *   what a FAQ list uses) keeps at most one item open; `"multiple"` lets every
 *   item toggle on its own.
 * - A trigger outside any group is a standalone fold block (a detail page's
 *   "Experience", "Education"…). It toggles independently and rests OPEN unless
 *   its markup says aria-expanded="false".
 * - The state lives on the trigger's aria-expanded; the panel gets `hidden`, the
 *   item gets `is-open`. Rotate the icon from the BUTTON's state
 *   (`group` on the button, `group-aria-expanded:rotate-180` on the icon), never
 *   from an attribute on the icon, which never changes.
 */

const panelOf = (trigger) => document.getElementById(trigger.getAttribute('aria-controls') || '');

const setOpen = (trigger, open) => {
  trigger.setAttribute('aria-expanded', open ? 'true' : 'false');
  const panel = panelOf(trigger);
  if (panel) {
    panel.hidden = !open;
  }
  const item = trigger.closest('[data-accordion-item]');
  if (item) {
    item.classList.toggle('is-open', open);
  }
};

const groupOf = (trigger) => trigger.closest('[data-accordion]');

// Triggers that belong to this group and not to a group nested inside it.
const membersOf = (group) =>
  [...group.querySelectorAll('[data-accordion-trigger]')].filter((t) => groupOf(t) === group);

export const initAccordions = (scope = document) => {
  scope.querySelectorAll('[data-accordion-trigger]').forEach((trigger) => {
    const group = groupOf(trigger);
    const declared = trigger.getAttribute('aria-expanded');
    setOpen(trigger, declared === null ? !group : declared === 'true');

    trigger.addEventListener('click', () => {
      const open = trigger.getAttribute('aria-expanded') !== 'true';
      if (open && group && (group.getAttribute('data-accordion') || 'single') === 'single') {
        membersOf(group).forEach((t) => t !== trigger && setOpen(t, false));
      }
      setOpen(trigger, open);
    });
  });

  // A single-open group rendered with several items open keeps only the first.
  scope.querySelectorAll('[data-accordion]').forEach((group) => {
    if ((group.getAttribute('data-accordion') || 'single') !== 'single') {
      return;
    }
    membersOf(group)
      .filter((t) => t.getAttribute('aria-expanded') === 'true')
      .slice(1)
      .forEach((t) => setOpen(t, false));
  });
};
