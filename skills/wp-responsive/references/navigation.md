# Responsive Navigation: Hamburger (Mobile) to Horizontal (Desktop)

The markup, CSS and JavaScript behind `SKILL.md` § Responsive Navigation.

## Contents

- HTML Structure
- CSS
- JavaScript

The open mobile menu is a modal overlay, so it is held to the accessibility audit's
A11Y-031 (`agents/wp-audit-a11y.md`, CRITICAL): Tab is trapped inside it while it is open,
Escape closes it, and focus returns to the button that opened it. Closed, it is
`visibility: hidden`, which takes its links out of the tab order and out of the
accessibility tree together. `aria-hidden="true"` on a menu that is only moved off-screen
does neither job: its links stay focusable while screen readers are told they are not there.

## HTML Structure

```html
<header class="header">
    <div class="container">
        <div class="header__inner">
            <a href="/" class="header__logo">
                <img src="logo.svg" alt="Site Name">
            </a>

            <!-- Desktop navigation -->
            <nav class="header__nav" aria-label="Main">
                <a href="#" class="nav__link nav__link--active">Home</a>
                <a href="#services" class="nav__link">Services</a>
                <a href="/pricing" class="nav__link">Pricing</a>
                <a href="#contact" class="nav__link">Contact</a>
            </nav>

            <!-- CTA button (visible on desktop) -->
            <a href="#contact" class="btn btn--primary header__cta">Get Started</a>

            <!-- Hamburger button (visible on mobile); it stays above the open menu and closes it -->
            <button class="header__hamburger" aria-label="Toggle menu" aria-expanded="false" aria-controls="mobile-menu">
                <span></span>
                <span></span>
                <span></span>
            </button>
        </div>
    </div>

    <!-- Mobile menu overlay -->
    <div class="mobile-menu" id="mobile-menu">
        <nav class="mobile-menu__nav" aria-label="Main">
            <a href="#" class="mobile-menu__link">Home</a>
            <a href="#services" class="mobile-menu__link">Services</a>
            <a href="/pricing" class="mobile-menu__link">Pricing</a>
            <a href="#contact" class="mobile-menu__link">Contact</a>
        </nav>
        <a href="#contact" class="btn btn--primary mobile-menu__cta">Get Started</a>
    </div>
</header>
```

## CSS

```css
/* Mobile: hamburger visible, desktop nav hidden */
.header__nav,
.header__cta {
    display: none;
}

.header__hamburger {
    position: relative;
    z-index: 1000; /* above the open menu, so it can close it */
    display: flex;
    flex-direction: column;
    justify-content: center;
    gap: 5px;
    width: 44px;
    height: 44px;
    background: none;
    border: none;
    cursor: pointer;
    padding: var(--spacing-sm);
}

.header__hamburger span {
    display: block;
    width: 24px;
    height: 2px;
    background: var(--color-text);
    transition: var(--transition-base);
}

/* Mobile menu: closed is off-screen AND visibility: hidden, so its links are not tabbable.
   visibility flips after the slide-out, and immediately on the way in. */
.mobile-menu {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100vh;
    background: var(--color-background);
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: var(--spacing-xl);
    transform: translateX(100%);
    visibility: hidden;
    transition: transform 0.3s ease, visibility 0s linear 0.3s;
    z-index: 999;
}

.mobile-menu.is-open {
    transform: translateX(0);
    visibility: visible;
    transition: transform 0.3s ease, visibility 0s;
}

.mobile-menu__link {
    font-size: var(--font-size-xl);
    font-weight: var(--font-weight-medium);
    padding: var(--spacing-md);
}

/* Desktop (1024px+): show nav, hide hamburger */
@media (min-width: 1024px) {
    .header__nav {
        display: flex;
        align-items: center;
        gap: var(--spacing-lg);
    }

    .header__cta {
        display: inline-flex;
    }

    .header__hamburger {
        display: none;
    }

    .mobile-menu {
        display: none;
    }
}
```

## JavaScript

```js
const toggle = document.querySelector('.header__hamburger');
const menu = document.getElementById('mobile-menu');
const FOCUSABLE = 'a[href], button:not([disabled]), input, select, textarea, [tabindex]:not([tabindex="-1"])';

if (toggle && menu) {
    const isOpen = () => menu.classList.contains('is-open');

    const setOpen = (open, returnFocus = true) => {
        menu.classList.toggle('is-open', open);
        toggle.setAttribute('aria-expanded', String(open));
        document.body.style.overflow = open ? 'hidden' : '';
        if (open) {
            const first = menu.querySelector(FOCUSABLE);
            if (first) first.focus();
        } else if (returnFocus) {
            toggle.focus(); // focus goes back to the control that opened the menu
        }
    };

    toggle.addEventListener('click', () => setOpen(!isOpen()));

    document.addEventListener('keydown', (e) => {
        if (!isOpen()) return;
        if (e.key === 'Escape') {
            setOpen(false);
            return;
        }
        if (e.key !== 'Tab') return;
        // The toggle sits above the overlay and closes it, so it is part of the cycle.
        // Read on every Tab, not once at open: the menu's content can change while it is open.
        const items = [toggle, ...menu.querySelectorAll(FOCUSABLE)];
        const first = items[0];
        const last = items[items.length - 1];
        if (!items.includes(document.activeElement)) {
            e.preventDefault();
            (e.shiftKey ? last : first).focus();
        } else if (e.shiftKey && document.activeElement === first) {
            e.preventDefault();
            last.focus();
        } else if (!e.shiftKey && document.activeElement === last) {
            e.preventDefault();
            first.focus();
        }
    });

    // At 1024px the CSS hides the menu. Close it too, or body stays scroll-locked on desktop.
    window.matchMedia('(min-width: 1024px)').addEventListener('change', (e) => {
        if (e.matches && isOpen()) setOpen(false, false);
    });
}
```
