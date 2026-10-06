# Demo Skeleton

The starting markup for `SKILL.md` § Single-File HTML Structure and § Footer Pattern, in
plain mode. It already carries the accessibility rules of `SKILL.md` § Accessibility
Requirements — the skip link, `id="main-content"`, the hamburger's `aria-expanded`, the
`.sr-only` classes and a visible focus style — so a page copied from it starts compliant.

## Contents

- Template Skeleton

## Template Skeleton

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Site Name — Page Title</title>

    <!-- Google Fonts: the one external request a plain demo makes. /wp-init Step 4.5
         self-hosts these families, so the theme never calls fonts.googleapis.com. -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Playfair+Display:wght@400;500;600;700&display=swap" rel="stylesheet">

    <style>
        /* ============ Section: Variables ============ */
        /* Token names are wp-css-system's (references/tokens.md); values are the client's. */
        :root {
            /* Colors */
            --color-primary: #1a5632;
            --color-primary-light: #2d7a4a;
            --color-primary-dark: #0f3d22;
            --color-secondary: #c9a84c;
            --color-neutral-50: #fafafa;
            --color-neutral-100: #f5f5f5;
            --color-neutral-200: #e5e5e5;
            --color-neutral-500: #737373;
            --color-neutral-800: #262626;
            --color-neutral-900: #171717;
            --color-text: var(--color-neutral-800);
            --color-text-light: var(--color-neutral-500);
            --color-text-inverse: #ffffff;
            --color-background: #ffffff;
            --color-background-alt: var(--color-neutral-50);
            --color-border: var(--color-neutral-200);

            /* Spacing */
            --spacing-xs: 0.25rem;
            --spacing-sm: 0.5rem;
            --spacing-md: 1rem;
            --spacing-lg: 1.5rem;
            --spacing-xl: 2rem;
            --spacing-2xl: 3rem;
            --spacing-3xl: 4rem;

            /* Typography */
            --font-family-primary: 'Inter', sans-serif;
            --font-family-secondary: 'Playfair Display', serif;
            --font-size-xs: 0.75rem;
            --font-size-sm: 0.875rem;
            --font-size-base: 1rem;
            --font-size-md: 1.125rem;
            --font-size-lg: 1.25rem;
            --font-size-xl: 1.5rem;
            --font-size-2xl: 2rem;
            --font-size-3xl: 2.5rem;
            --font-size-4xl: 3rem;
            --font-weight-regular: 400;
            --font-weight-medium: 500;
            --font-weight-semibold: 600;
            --font-weight-bold: 700;
            --line-height-tight: 1.2;
            --line-height-normal: 1.5;
            --line-height-relaxed: 1.75;

            /* Other tokens */
            --shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.05);
            --shadow-md: 0 4px 6px rgba(0, 0, 0, 0.07);
            --shadow-lg: 0 10px 15px rgba(0, 0, 0, 0.1);
            --radius-sm: 0.25rem;
            --radius-md: 0.5rem;
            --radius-lg: 1rem;
            --radius-full: 9999px;
            --transition-base: all 0.3s ease;
            --transition-slow: all 0.5s ease;
            --container-max: 1280px;
        }

        /* ============ Section: Reset ============ */
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
        html { scroll-behavior: smooth; }
        body {
            font-family: var(--font-family-primary);
            font-size: var(--font-size-base);
            line-height: var(--line-height-normal);
            color: var(--color-text);
            background: var(--color-background);
        }
        img { display: block; max-width: 100%; height: auto; }
        a { color: inherit; text-decoration: none; }
        ul, ol { list-style: none; }

        /* ============ Section: Accessibility ============ */
        :focus-visible { outline: 2px solid var(--color-primary); outline-offset: 2px; }
        .sr-only {
            position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px;
            overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0;
        }
        .sr-only--focusable:focus {
            position: fixed; top: var(--spacing-sm); left: var(--spacing-sm); z-index: 1001;
            width: auto; height: auto; margin: 0; padding: var(--spacing-sm) var(--spacing-md);
            clip: auto; white-space: normal; background: var(--color-background);
        }
        @media (prefers-reduced-motion: reduce) {
            *, *::before, *::after {
                animation-duration: 0.01ms !important;
                animation-iteration-count: 1 !important;
                transition-duration: 0.01ms !important;
                scroll-behavior: auto !important;
            }
        }

        /* ============ Section: Layout ============ */
        .container {
            width: 100%;
            max-width: var(--container-max);
            margin: 0 auto;
            padding: 0 var(--spacing-md);
        }

        /* ============ Section: Header ============ */
        /* Hamburger and mobile menu: wp-responsive references/navigation.md */
        .header { ... }

        /* ============ Section: Hero ============ */
        .hero { ... }

        /* ============ Section: Services ============ */
        /* Base rules are the phone layout; each min-width step adds to them. The steps
           stay inside the section's own block, so the section's CSS moves to its
           template part whole. */
        .services { ... }
        @media (min-width: 768px) { .services { ... } }
        @media (min-width: 1024px) { .services { ... } }

        /* ... more sections, each with its own min-width steps ... */

        /* ============ Section: Footer ============ */
        .footer { ... }
        @media (min-width: 768px) { .footer { ... } }
    </style>
</head>
<body>

    <a href="#main-content" class="sr-only sr-only--focusable">Skip to content</a>

    <!-- ============ SECTION: Header ============ -->
    <header class="header">
        <div class="container">
            <div class="header__inner">
                <a href="index.html" class="header__logo">
                    <img src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 180 50'%3E%3Crect width='180' height='50' fill='%23e5e5e5'/%3E%3C/svg%3E" width="180" height="50" alt="Site Name">
                </a>
                <nav class="header__nav" aria-label="Main">
                    <a href="index.html" class="nav__link nav__link--active">Home</a>
                    <a href="#services" class="nav__link">Services</a>
                    <a href="pricing.html" class="nav__link">Pricing</a>
                    <a href="#contact" class="nav__link">Contact</a>
                </nav>
                <!-- Language switcher: one link per language configured for the project -->
                <nav class="header__lang" aria-label="Language">
                    <a href="#" class="header__lang-link header__lang-link--active" lang="en">EN</a>
                    <a href="#" class="header__lang-link" lang="es">ES</a>
                </nav>
                <a href="#contact" class="btn btn--primary header__cta">Get Started</a>
                <button class="header__hamburger" aria-label="Toggle menu" aria-expanded="false" aria-controls="mobile-menu">
                    <span></span><span></span><span></span>
                </button>
            </div>
        </div>
        <div class="mobile-menu" id="mobile-menu">
            <!-- the same links as .header__nav, plus the language links -->
        </div>
    </header>
    <!-- ============ END SECTION: Header ============ -->

    <main id="main-content">
        <!-- ============ SECTION: Hero ============ -->
        <section class="hero">
            <div class="container">
                <div class="hero__content">
                    <span class="hero__label">Welcome to Site Name</span>
                    <h1 class="hero__title">Your Compelling Headline Here</h1>
                    <p class="hero__subtitle">A brief supporting description that explains the value proposition in one or two sentences.</p>
                    <div class="hero__cta">
                        <a href="#contact" class="btn btn--primary btn--large">Primary Action</a>
                        <a href="#services" class="btn btn--secondary btn--large">Secondary Action</a>
                    </div>
                </div>
                <div class="hero__image">
                    <!-- The hero is the LCP image: fetchpriority, never loading="lazy" -->
                    <img src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 600 400'%3E%3Crect width='600' height='400' fill='%23e5e5e5'/%3E%3C/svg%3E" width="600" height="400" alt="Hero image description" fetchpriority="high">
                </div>
            </div>
        </section>
        <!-- ============ END SECTION: Hero ============ -->

        <!-- ============ SECTION: Services ============ -->
        <section class="services section section--alt" id="services">
            <div class="container">
                <span class="section__label">What We Do</span>
                <h2 class="section__title">Our Services</h2>
                <div class="services__grid">
                    <!-- Service cards here -->
                </div>
            </div>
        </section>
        <!-- ============ END SECTION: Services ============ -->

        <!-- ... more sections ... -->

        <!-- ============ SECTION: Contact ============ -->
        <section class="contact section" id="contact">
            <div class="container">
                <!-- Contact content -->
            </div>
        </section>
        <!-- ============ END SECTION: Contact ============ -->
    </main>

    <!-- ============ SECTION: Footer ============ -->
    <!-- /wp-seed reads .footer__description and .footer__copyright; keep both class names -->
    <footer class="footer">
        <div class="container">
            <div class="footer__grid">
                <!-- Column 1: Brand/Logo -->
                <div class="footer__brand">
                    <img src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 180 50'%3E%3Crect width='180' height='50' fill='%23e5e5e5'/%3E%3C/svg%3E" width="180" height="50" alt="Site Name" class="footer__logo" loading="lazy">
                    <p class="footer__description">Company tagline or brief description.</p>
                </div>

                <!-- Column 2: Quick Links -->
                <div class="footer__links">
                    <h3 class="footer__heading">Quick Links</h3>
                    <ul>
                        <li><a href="index.html">Home</a></li>
                        <li><a href="#services">Services</a></li>
                        <li><a href="pricing.html">Pricing</a></li>
                        <li><a href="#contact">Contact</a></li>
                    </ul>
                </div>

                <!-- Column 3: Contact Info -->
                <div class="footer__contact">
                    <h3 class="footer__heading">Contact</h3>
                    <p>info@example.com</p>
                    <p>(555) 123-4567</p>
                    <p>123 Main St, City, ST 12345</p>
                </div>

                <!-- Column 4: Social -->
                <div class="footer__social">
                    <h3 class="footer__heading">Follow Us</h3>
                    <div class="footer__social-links">
                        <a href="#" class="footer__social-link" aria-label="Facebook">FB</a>
                        <a href="#" class="footer__social-link" aria-label="Instagram">IG</a>
                        <a href="#" class="footer__social-link" aria-label="LinkedIn">LI</a>
                    </div>
                </div>
            </div>

            <!-- Footer bottom: copyright + legal -->
            <div class="footer__bottom">
                <p class="footer__copyright">&copy; Site Name. All rights reserved.</p>
                <div class="footer__legal">
                    <a href="#">Privacy Policy</a>
                    <a href="#">Terms &amp; Conditions</a>
                </div>
            </div>
        </div>
    </footer>
    <!-- ============ END SECTION: Footer ============ -->

    <script>
        // Hamburger toggle with focus trap, Escape and focus return:
        // copy the JavaScript in wp-responsive references/navigation.md.
    </script>

</body>
</html>
```
