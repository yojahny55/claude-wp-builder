# Responsive Navigation: Hamburger (Mobile) to Horizontal (Desktop)

The markup, CSS and JavaScript behind `SKILL.md` § Responsive Navigation.

## Contents

- HTML Structure
- CSS
- JavaScript (Minimal)

## HTML Structure

```html
<header class="header">
    <div class="container">
        <div class="header__inner">
            <a href="/" class="header__logo">
                <img src="logo.svg" alt="Site Name">
            </a>

            <!-- Desktop navigation -->
            <nav class="header__nav" id="main-nav">
                <a href="#" class="nav__link nav__link--active">Home</a>
                <a href="#services" class="nav__link">Services</a>
                <a href="/pricing" class="nav__link">Pricing</a>
                <a href="#contact" class="nav__link">Contact</a>
            </nav>

            <!-- CTA button (visible on desktop) -->
            <a href="#contact" class="btn btn--primary header__cta">Get Started</a>

            <!-- Hamburger button (visible on mobile) -->
            <button class="header__hamburger" aria-label="Toggle menu" aria-expanded="false">
                <span></span>
                <span></span>
                <span></span>
            </button>
        </div>
    </div>

    <!-- Mobile menu overlay -->
    <div class="mobile-menu" id="mobile-menu" aria-hidden="true">
        <nav class="mobile-menu__nav">
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

/* Mobile menu (hidden by default) */
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
    transition: transform 0.3s ease;
    z-index: 999;
}

.mobile-menu.is-open {
    transform: translateX(0);
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

## JavaScript (Minimal)

```js
const hamburger = document.querySelector('.header__hamburger');
const mobileMenu = document.getElementById('mobile-menu');

if (hamburger && mobileMenu) {
    hamburger.addEventListener('click', () => {
        const isOpen = mobileMenu.classList.toggle('is-open');
        hamburger.setAttribute('aria-expanded', isOpen);
        mobileMenu.setAttribute('aria-hidden', !isOpen);
        document.body.style.overflow = isOpen ? 'hidden' : '';
    });
}
```
