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
const startMotion = () => initMotion(gsap, ScrollTrigger);
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
