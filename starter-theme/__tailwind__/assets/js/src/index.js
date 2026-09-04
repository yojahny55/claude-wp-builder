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
