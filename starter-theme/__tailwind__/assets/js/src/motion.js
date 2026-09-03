/**
 * motion.js — the plugin's scroll-motion contract.
 *
 * Reads `data-motion-*` attributes off section markup and drives them with GSAP +
 * ScrollTrigger. Nothing here is page-specific: a demo and the WordPress theme it
 * converts into run the identical file, which is why the attributes survive
 * conversion while inline per-page JS would not.
 *
 * Two entry points on purpose. A demo inlines this file and calls
 * window.WPMotion.init() with GSAP already on window; the theme bundle imports
 * initMotion and passes the modules in.
 */

const REDUCED = () =>
  window.matchMedia('(prefers-reduced-motion: reduce)').matches;
const FINE = () =>
  window.matchMedia('(hover: hover) and (pointer: fine)').matches;

/** Parse `from [to [rampIn [rampOut]]]` into an opacity function of progress. */
function parseCue(value) {
  const n = String(value).trim().split(/\s+/).map(Number);
  const from = isFinite(n[0]) ? n[0] : 0;
  const to = n.length > 1 && isFinite(n[1]) ? n[1] : null; // null = hold to the end
  const span = (to === null ? 1 : to) - from;
  // Ramps default to 30% of the window each. A cue with no plateau touches full
  // opacity for a single instant, which reads as a permanently faded heading.
  const rampIn = n.length > 2 && isFinite(n[2]) ? n[2] : Math.abs(span) * 0.3;
  const rampOut = n.length > 3 && isFinite(n[3]) ? n[3] : Math.abs(span) * 0.3;
  return function opacityAt(p) {
    if (p < from) return rampIn === 0 ? (p >= from ? 1 : 0) : 0;
    if (rampIn > 0 && p < from + rampIn) return (p - from) / rampIn;
    if (to === null) return 1;
    // "0 1 0 0" is the documented greet-and-hold form (devices.md): a cue that
    // ends at 1 with no ramp-out is holding, not fading. Returning 0 here blanked
    // the closing section's cue on the final frame, which is exactly the
    // fade-to-an-empty-stage ending feel.md forbids.
    if (p >= to) return to >= 1 && rampOut === 0 ? 1 : 0;
    if (rampOut > 0 && p > to - rampOut) return Math.max(0, (to - p) / rampOut);
    return 1;
  };
}

/** Format a counter target, inferring decimals and separators from how it is written. */
function formatNum(value, template) {
  const decimals = (template.split('.')[1] || '').length;
  const grouped = template.indexOf(',') !== -1 || Math.abs(Number(template.replace(/,/g, ''))) >= 10000;
  const fixed = value.toFixed(decimals);
  if (!grouped) return fixed;
  const parts = fixed.split('.');
  parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  return parts.join('.');
}

export function initMotion(gsap, ScrollTrigger) {
  if (!gsap || !ScrollTrigger) return;
  if (document.documentElement.dataset.motionReady === '1') return;
  document.documentElement.dataset.motionReady = '1';
  gsap.registerPlugin(ScrollTrigger);

  const reduced = REDUCED();
  const fine = FINE() && !reduced;

  document.querySelectorAll('[data-motion]').forEach((el) => {
    const kind = el.getAttribute('data-motion');
    const span = parseFloat(el.getAttribute('data-motion-span')) || 0;

    // Cue elements belong to the section's own progress, so they are collected
    // once and driven from onUpdate rather than each owning a ScrollTrigger.
    const cued = Array.prototype.map.call(
      el.querySelectorAll('[data-motion-cue]'),
      (node) => ({ node: node, at: parseCue(node.getAttribute('data-motion-cue')) })
    );
    const rise = reduced ? 0 : 14;

    const drive = (p) => {
      // devices.md documents --motion-p as the seam bespoke CSS drives off via
      // calc(), and the usual use is a transform. Publishing live progress under
      // reduced motion would keep animating position through that seam and
      // defeat the floor, so freeze it at the end state the way every other
      // device here does (wipe reveals, kinetic shows, count writes its final
      // value). Cue opacity below still reads the real p, so meaning is kept.
      el.style.setProperty('--motion-p', reduced ? '1' : p.toFixed(4));
      cued.forEach((c) => {
        const o = Math.max(0, Math.min(1, c.at(p)));
        c.node.style.opacity = String(o);
        c.node.style.transform = 'translate3d(0,' + ((1 - o) * rise).toFixed(2) + 'px,0)';
      });
    };

    if (kind === 'pin' || kind === 'pan' || kind === 'kinetic' || kind === 'wipe' || kind === 'drift') {
      // A pinned section's travel is max(height - viewport, 1). Below a span of
      // about 1.2 that is a handful of pixels and every cue snaps instead of running.
      if (span && span < 1.2 && kind === 'pin') {
        // ponytail: warn rather than correct — the author picked the span on purpose,
        // and silently rewriting it hides the finding from /wp-demo-verify.
        console.warn('[motion] pin span below 1.2 will snap:', el);
      }
      ScrollTrigger.create({
        trigger: el,
        start: 'top top',
        end: 'bottom bottom',
        scrub: true,
        onUpdate: (self) => drive(self.progress),
      });
      drive(0);
    }

    if (kind === 'pan') {
      const rail = el.querySelector('[data-motion-rail]') || el.firstElementChild;
      if (rail) {
        // The rail's own container, not the window, is what bounds its visible
        // width: a rail inside a narrower wrapper overflows that wrapper, not
        // necessarily the viewport, so window.innerWidth under-reports or
        // zeroes the travel there.
        const container = rail.parentElement || el;
        const travel = () => Math.max(0, rail.scrollWidth - container.clientWidth);
        if (reduced) {
          // The rail IS the navigation here, so zeroing the transform would strand
          // every item past the fold. Hand it back as a native scroll region.
          rail.style.overflowX = 'auto';
          rail.style.scrollSnapType = 'x proximity';
        } else {
          ScrollTrigger.create({
            trigger: el,
            start: 'top top',
            end: 'bottom bottom',
            scrub: true,
            onUpdate: (self) => {
              rail.style.transform = 'translate3d(' + (-travel() * self.progress).toFixed(2) + 'px,0,0)';
            },
          });
        }
      }
    }

    if (kind === 'reveal') {
      const stagger = (parseFloat(el.getAttribute('data-motion-stagger')) || 70) / 1000;
      const kids = el.children.length ? el.children : [el];
      if (reduced) {
        // Zeroing the rise alone was not enough: the children still started at
        // opacity 0 and played a timed, staggered fade on scroll entry, which is
        // a scroll-triggered animation whatever its property. Cue opacity stays
        // live under reduced motion because it is scrubbed (it tracks the wheel
        // directly), but this is a 0.62s one-shot, so it snaps to visible.
        gsap.set(kids, { opacity: 1, y: 0 });
      } else {
        gsap.set(kids, { opacity: 0, y: rise });
        ScrollTrigger.create({
          trigger: el,
          start: 'top 88%',
          once: true, // content that re-hides on the way back up is a defect, not an effect
          onEnter: () =>
            gsap.to(kids, {
              opacity: 1,
              y: 0,
              duration: 0.62,
              ease: 'power3.out',
              stagger: stagger,
            }),
        });
      }
    }

    if (kind === 'wipe') {
      const dir = el.getAttribute('data-motion-dir') || 'up';
      const shapes = {
        up: (p) => 'inset(' + ((1 - p) * 100).toFixed(2) + '% 0 0 0)',
        down: (p) => 'inset(0 0 ' + ((1 - p) * 100).toFixed(2) + '% 0)',
        left: (p) => 'inset(0 ' + ((1 - p) * 100).toFixed(2) + '% 0 0)',
        right: (p) => 'inset(0 0 0 ' + ((1 - p) * 100).toFixed(2) + '%)',
        iris: (p) => 'circle(' + (p * 75).toFixed(2) + '% at 50% 50%)',
      };
      // An unrecognised direction falls back rather than leaving shape undefined:
      // a TypeError thrown from inside the forEach stops every later element
      // from initialising, so one bad attribute would kill motion page-wide.
      const shape = shapes[dir] || shapes.up;
      // Set the closed state up front, the same way the pin branch calls
      // drive(0): without it the element renders fully revealed until the
      // first onUpdate fires, so the wipe has nothing left to reveal.
      el.style.clipPath = shape(reduced ? 1 : 0);
      ScrollTrigger.create({
        trigger: el,
        start: 'top 85%',
        end: 'center center',
        scrub: true,
        onUpdate: (self) => {
          el.style.clipPath = shape(reduced ? 1 : self.progress);
        },
      });
    }

    if (kind === 'kinetic') {
      // ponytail: word-split only, real line-box splitting is out of scope.
      // The split rebuilds the element from its words (textContent = ''), which
      // destroys any nested inline markup, so skip elements that have any.
      if (el.querySelector('*')) {
        console.warn('[motion] kinetic: element has child markup, skipping split to avoid destroying it:', el);
      } else {
      // Line boxes are measured, so the split has to wait for the real face.
      const run = () => {
        const words = (el.textContent || '').trim().split(/\s+/);
        el.textContent = '';
        const units = words.map((w) => {
          const mask = document.createElement('span');
          mask.style.cssText = 'display:inline-block;overflow:hidden;vertical-align:bottom;padding-bottom:0.12em';
          const inner = document.createElement('span');
          inner.style.display = 'inline-block';
          inner.textContent = w;
          mask.appendChild(inner);
          el.appendChild(mask);
          el.appendChild(document.createTextNode(' '));
          return inner;
        });
        // Reduced motion keeps the opacity that carries meaning and drops the
        // position change, per taste.md: visible immediately, not faded in on
        // a scroll-triggered delay that still counts as motion.
        gsap.set(units, { yPercent: reduced ? 0 : 110, opacity: reduced ? 1 : 0 });
        ScrollTrigger.create({
          trigger: el,
          start: 'top 85%',
          once: true,
          onEnter: () =>
            gsap.to(units, {
              yPercent: 0,
              opacity: 1,
              duration: 0.7,
              ease: 'power3.out',
              stagger: 0.05,
            }),
        });
      };
      if (document.fonts && document.fonts.ready) document.fonts.ready.then(run);
      else run();
      }
    }

    if (kind === 'parallax') {
      const rate = parseFloat(el.getAttribute('data-motion-rate')) || 0;
      if (!reduced && rate) {
        ScrollTrigger.create({
          trigger: el.parentElement || el,
          start: 'top bottom',
          end: 'bottom top',
          scrub: true,
          onUpdate: (self) => {
            // Rate is in hundreds of pixels, so total travel is rate * 100 px and
            // does not change with screen height.
            el.style.transform =
              'translate3d(0,' + (rate * (self.progress - 0.5) * 100).toFixed(2) + 'px,0)';
          },
        });
      }
    }

    if (kind === 'drift') {
      const color = el.getAttribute('data-motion-drift');
      if (color) {
        // Under reduced motion the ground still changes, it just stops being a
        // 0.8s crossfade: the design intent survives, the animation does not.
        const apply = () => {
          if (reduced) document.body.style.backgroundColor = color;
          else gsap.to(document.body, { backgroundColor: color, duration: 0.8 });
        };
        ScrollTrigger.create({
          trigger: el,
          start: 'top center',
          end: 'bottom center',
          onEnter: apply,
          onEnterBack: apply,
        });
      }
    }
  });

  // Counters. Only real figures ever reach this attribute; see devices.md.
  document.querySelectorAll('[data-motion-count]').forEach((el) => {
    const raw = el.getAttribute('data-motion-count').trim().split(/\s+/);
    const from = Number(String(raw[0]).replace(/,/g, ''));
    const targetText = raw[1] || raw[0];
    const to = Number(String(targetText).replace(/,/g, ''));
    const ms = parseFloat(el.getAttribute('data-motion-count-ms')) || 1400;
    el.style.fontVariantNumeric = 'tabular-nums';
    if (reduced) {
      el.textContent = formatNum(to, targetText);
      return;
    }
    const state = { v: from };
    ScrollTrigger.create({
      trigger: el,
      start: 'top 50%',
      once: true,
      onEnter: () =>
        gsap.to(state, {
          v: to,
          duration: ms / 1000,
          ease: 'power3.out',
          onUpdate: () => {
            el.textContent = formatNum(state.v, targetText);
          },
        }),
    });
  });

  if (!fine) return;

  document.querySelectorAll('[data-motion="tilt"]').forEach((el) => {
    const deg = parseFloat(el.getAttribute('data-motion-rate')) || 6;
    el.addEventListener('pointermove', (e) => {
      const r = el.getBoundingClientRect();
      const x = (e.clientX - r.left) / r.width - 0.5;
      const y = (e.clientY - r.top) / r.height - 0.5;
      gsap.to(el, { rotateY: x * deg, rotateX: -y * deg, duration: 0.4, ease: 'power2.out' });
    });
    el.addEventListener('pointerleave', () =>
      gsap.to(el, { rotateY: 0, rotateX: 0, duration: 0.6, ease: 'power2.out' })
    );
  });

  document.querySelectorAll('[data-motion="magnet"]').forEach((el) => {
    const k = parseFloat(el.getAttribute('data-motion-rate')) || 0.28;
    el.addEventListener('pointermove', (e) => {
      const r = el.getBoundingClientRect();
      gsap.to(el, {
        x: (e.clientX - (r.left + r.width / 2)) * k,
        y: (e.clientY - (r.top + r.height / 2)) * k,
        duration: 0.4,
        ease: 'power2.out',
      });
    });
    el.addEventListener('pointerleave', () =>
      gsap.to(el, { x: 0, y: 0, duration: 0.5, ease: 'power2.out' })
    );
  });

  document.querySelectorAll('[data-motion="spotlight"]').forEach((el) => {
    el.addEventListener('pointermove', (e) => {
      const r = el.getBoundingClientRect();
      el.style.setProperty('--motion-mx', ((e.clientX - r.left) / r.width).toFixed(4));
      el.style.setProperty('--motion-my', ((e.clientY - r.top) / r.height).toFixed(4));
    });
  });
}

// Inline-in-a-demo entry: GSAP is already a global there.
window.WPMotion = {
  init: () => initMotion(window.gsap, window.ScrollTrigger),
};
if (document.readyState !== 'loading') {
  if (window.gsap && window.ScrollTrigger) window.WPMotion.init();
} else {
  document.addEventListener('DOMContentLoaded', () => {
    if (window.gsap && window.ScrollTrigger) window.WPMotion.init();
  });
}
