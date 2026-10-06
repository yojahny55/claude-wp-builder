# Demo Skeleton

The starting markup for `SKILL.md` § Single-File HTML Structure and § Footer Pattern.

## Contents

- Template Skeleton
- Footer Markup

## Template Skeleton

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Site Name — Page Title</title>

    <!-- Google Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Playfair+Display:wght@400;500;600;700&display=swap" rel="stylesheet">

    <style>
        /* ============ Section: Variables ============ */
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

            /* Other tokens */
            --shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.05);
            --shadow-md: 0 4px 6px rgba(0, 0, 0, 0.07);
            --radius-sm: 0.25rem;
            --radius-md: 0.5rem;
            --radius-lg: 1rem;
            --radius-full: 9999px;
            --transition-base: all 0.3s ease;
            --container-max: 1280px;
        }

        /* ============ Section: Reset ============ */
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
        html { scroll-behavior: smooth; }
        body {
            font-family: var(--font-family-primary);
            font-size: var(--font-size-base);
            line-height: 1.5;
            color: var(--color-text);
            background: var(--color-background);
        }
        img { display: block; max-width: 100%; height: auto; }
        a { color: inherit; text-decoration: none; }
        ul, ol { list-style: none; }

        /* ============ Section: Layout ============ */
        .container {
            width: 100%;
            max-width: var(--container-max);
            margin: 0 auto;
            padding: 0 var(--spacing-md);
        }

        /* ============ Section: Header ============ */
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

    <!-- ============ SECTION: Header ============ -->
    <header class="header">
        <div class="container">
            <div class="header__inner">
                <a href="/" class="header__logo">
                    <img src="https://placehold.co/180x50?text=Logo" alt="Site Name">
                </a>
                <nav class="header__nav">
                    <a href="#" class="nav__link nav__link--active">Home</a>
                    <a href="#services" class="nav__link">Services</a>
                    <a href="pricing.html" class="nav__link">Pricing</a>
                    <a href="#contact" class="nav__link">Contact</a>
                </nav>
                <a href="#contact" class="btn btn--primary">Get Started</a>
                <button class="header__hamburger" aria-label="Toggle menu">
                    <span></span><span></span><span></span>
                </button>
            </div>
        </div>
    </header>
    <!-- ============ END SECTION: Header ============ -->

    <main>
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
                    <img src="https://placehold.co/600x400?text=Hero+Image" alt="Hero image description">
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
    <footer class="footer">
        <div class="container">
            <div class="footer__grid">
                <div class="footer__brand">
                    <img src="https://placehold.co/180x50?text=Logo" alt="Site Name" class="footer__logo">
                    <p class="footer__tagline">Brief company tagline here.</p>
                </div>
                <div class="footer__links">
                    <h3 class="footer__heading">Quick Links</h3>
                    <ul>
                        <li><a href="#">Home</a></li>
                        <li><a href="#">Services</a></li>
                        <li><a href="#">Pricing</a></li>
                        <li><a href="#">Contact</a></li>
                    </ul>
                </div>
                <div class="footer__contact">
                    <h3 class="footer__heading">Contact</h3>
                    <p>email@example.com</p>
                    <p>(555) 123-4567</p>
                </div>
                <div class="footer__social">
                    <h3 class="footer__heading">Follow Us</h3>
                    <!-- Social links -->
                </div>
            </div>
            <div class="footer__bottom">
                <p>&copy; 2025 Site Name. All rights reserved.</p>
                <div class="footer__legal">
                    <a href="#">Privacy Policy</a>
                    <a href="#">Terms & Conditions</a>
                </div>
            </div>
        </div>
    </footer>
    <!-- ============ END SECTION: Footer ============ -->

    <script>
        // Minimal JS for demo interactivity (hamburger toggle, scroll effects)
    </script>

</body>
</html>
```

## Footer Markup

```html
<footer class="footer">
    <div class="container">
        <div class="footer__grid">
            <!-- Column 1: Brand/Logo -->
            <div class="footer__brand">
                <img src="https://placehold.co/180x50?text=Logo" alt="Site Name" class="footer__logo">
                <p class="footer__tagline">Company tagline or brief description.</p>
            </div>

            <!-- Column 2: Quick Links -->
            <div class="footer__links">
                <h3 class="footer__heading">Quick Links</h3>
                <ul>
                    <li><a href="#">Home</a></li>
                    <li><a href="#">Services</a></li>
                    <li><a href="#">Pricing</a></li>
                    <li><a href="#">Contact</a></li>
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
                    <a href="#" aria-label="Facebook">FB</a>
                    <a href="#" aria-label="Instagram">IG</a>
                    <a href="#" aria-label="LinkedIn">LI</a>
                </div>
            </div>
        </div>

        <!-- Footer bottom: copyright + legal -->
        <div class="footer__bottom">
            <p>&copy; 2025 Site Name. All rights reserved.</p>
            <div class="footer__legal">
                <a href="#">Privacy Policy</a>
                <a href="#">Terms & Conditions</a>
            </div>
        </div>
    </div>
</footer>
```
