/**
 * Theme JavaScript entry point
 *
 * Compiled by @wordpress/scripts.
 * Add your custom JS here.
 */

import gsap from 'gsap';
import ScrollTrigger from 'gsap/ScrollTrigger';
import { initMotion } from './motion.js';

initMotion(gsap, ScrollTrigger);

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
