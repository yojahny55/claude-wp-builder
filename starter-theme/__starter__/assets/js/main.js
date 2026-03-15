/**
 * __STARTER_NAME__ — Main JavaScript
 * @package __STARTER_NAME__
 */
(function () {
    'use strict';

    document.addEventListener('DOMContentLoaded', function () {

        // ── Language Switcher ─────────────────────────────────────
        (function initLanguageSwitcher() {
            var switchers = document.querySelectorAll('[data-lang-switch]');
            if (!switchers.length) return;

            var data = window.themeData || {};
            var currentLang = data.lang || 'en';
            var langs = data.langs || ['en', 'es'];

            switchers.forEach(function (el) {
                var targetLang = el.getAttribute('data-lang-switch');

                // Mark active
                if (targetLang === currentLang) {
                    el.classList.add('active');
                }

                el.addEventListener('click', function (e) {
                    e.preventDefault();
                    var url = new URL(window.location.href);
                    url.searchParams.set('lang', targetLang);
                    window.location.href = url.toString();
                });
            });
        })();

        // ── Mobile Nav Toggle ─────────────────────────────────────
        (function initMobileNav() {
            var toggle = document.querySelector('[data-mobile-toggle]');
            var nav = document.querySelector('[data-mobile-nav]');
            if (!toggle || !nav) return;

            toggle.addEventListener('click', function () {
                var expanded = toggle.getAttribute('aria-expanded') === 'true';
                toggle.setAttribute('aria-expanded', String(!expanded));
                nav.classList.toggle('is-open');
                document.body.classList.toggle('nav-open');
            });

            // Close on link click
            nav.querySelectorAll('a').forEach(function (link) {
                link.addEventListener('click', function () {
                    toggle.setAttribute('aria-expanded', 'false');
                    nav.classList.remove('is-open');
                    document.body.classList.remove('nav-open');
                });
            });
        })();

        // ── Scroll Reveal Animations ──────────────────────────────
        (function initScrollReveal() {
            var reveals = document.querySelectorAll('[data-reveal]');
            if (!reveals.length || !('IntersectionObserver' in window)) return;

            var observer = new IntersectionObserver(function (entries) {
                entries.forEach(function (entry) {
                    if (entry.isIntersecting) {
                        entry.target.classList.add('is-revealed');
                        observer.unobserve(entry.target);
                    }
                });
            }, {
                threshold: 0.1,
                rootMargin: '0px 0px -50px 0px'
            });

            reveals.forEach(function (el) {
                observer.observe(el);
            });
        })();

        // ── Smooth Scroll for Anchor Links ────────────────────────
        (function initSmoothScroll() {
            document.querySelectorAll('a[href^="#"]').forEach(function (link) {
                link.addEventListener('click', function (e) {
                    var targetId = this.getAttribute('href');
                    if (targetId === '#') return;

                    var target = document.querySelector(targetId);
                    if (!target) return;

                    e.preventDefault();
                    var headerOffset = 80;
                    var elementPosition = target.getBoundingClientRect().top;
                    var offsetPosition = elementPosition + window.pageYOffset - headerOffset;

                    window.scrollTo({
                        top: offsetPosition,
                        behavior: 'smooth'
                    });
                });
            });
        })();

        // ── Sticky Header ─────────────────────────────────────────
        (function initStickyHeader() {
            var header = document.querySelector('[data-sticky-header]');
            if (!header) return;

            var threshold = 100;
            var isSticky = false;

            function onScroll() {
                var scrolled = window.pageYOffset > threshold;
                if (scrolled !== isSticky) {
                    isSticky = scrolled;
                    header.classList.toggle('is-sticky', isSticky);
                }
            }

            window.addEventListener('scroll', onScroll, { passive: true });
            onScroll();
        })();

    });
})();
