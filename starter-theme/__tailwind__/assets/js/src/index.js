/**
 * Theme JavaScript entry point
 *
 * Compiled by @wordpress/scripts.
 * Add your custom JS here.
 */

import gsap from 'gsap';
import ScrollTrigger from 'gsap/ScrollTrigger';
import { initMotion } from './motion.js';

// Wrapped in a DOM-ready check: a bundle enqueued before the DOM is parsed
// would find no [data-motion] elements, and motion.js's motionReady guard
// blocks a later retry once it has run once.
// Guarded at the boundary too: the per-section try/catch inside initMotion
// covers the [data-motion] loop, but the counter and pointer-device loops sit
// outside it. On the readyState !== 'loading' path this call runs during module
// evaluation, so an escaping throw would abort the rest of this file and take
// unrelated theme JavaScript (the mobile menu below) down with it.
const startMotion = () => {
  try {
    initMotion(gsap, ScrollTrigger);
  } catch (err) {
    console.warn('[motion] failed to start theme motion:', err);
  }
};
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', startMotion);
} else {
  startMotion();
}

// Mobile menu toggle
document.addEventListener('DOMContentLoaded', () => {
  const menuToggle = document.querySelector('.menu-toggle');
  const mobileMenu = document.querySelector('.mobile-menu');

  if (menuToggle && mobileMenu) {
    menuToggle.addEventListener('click', () => {
      mobileMenu.classList.toggle('hidden');
      const expanded = menuToggle.getAttribute('aria-expanded') === 'true';
      menuToggle.setAttribute('aria-expanded', !expanded);
    });
  }
});

// Decorative CSS backgrounds wait until they are near the viewport.
//
// A `background-image` has no `loading` attribute, so without this the browser
// downloads every decorative section background with the first paint, however
// far below the fold it sits. The declaration is printed by
// __starter___lazy_background_attr() into `data-__starter__-bg`, and repeated
// inside a <noscript><style> block so a visitor without JavaScript sees the same
// page. The hero is never deferred this way: it is the LCP element.
const initLazyBackgrounds = () => {
  const lazyBackgrounds = document.querySelectorAll('[data-__starter__-bg]');
  if (!lazyBackgrounds.length) {
    return;
  }

  const paint = (el) => {
    el.style.cssText += el.getAttribute('data-__starter__-bg');
    el.removeAttribute('data-__starter__-bg');
  };

  // Queried again when it fires, not captured above: a carousel or slider moves
  // these nodes into its own track, so the list taken now can be stale by then.
  const paintIdle = () => {
    window.setTimeout(() => {
      document
        .querySelectorAll('[data-__starter__-bg][data-__starter__-bg-idle]')
        .forEach(paint);
    }, 1200);
  };

  // The readyState test is load-bearing, not defensive. A bundle that runs after
  // the load event has already fired — which is the normal case for a deferred
  // script on a cached page — would never see a `load` listener called, and every
  // idle background would stay unpainted for the rest of the visit.
  if (document.readyState === 'complete') {
    paintIdle();
  } else {
    window.addEventListener('load', paintIdle);
  }

  if (!('IntersectionObserver' in window)) {
    lazyBackgrounds.forEach(paint);
    return;
  }

  // 600px of margin, so the image is requested before the section is on screen
  // and the visitor does not scroll into an empty band.
  const observer = new IntersectionObserver(
    (entries, obs) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          paint(entry.target);
          obs.unobserve(entry.target);
        }
      });
    },
    { rootMargin: '600px 0px' }
  );

  lazyBackgrounds.forEach((el) => {
    if (!el.hasAttribute('data-__starter__-bg-idle')) {
      observer.observe(el);
    }
  });
};

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initLazyBackgrounds);
} else {
  initLazyBackgrounds();
}
