// =============================================================================
// CONFIGURACION POR SITIO  —  /wp-audit --suite rellena esto por proyecto.
// Inspecciona el DOM real del sitio antes de fijar los selectores: cada tema/CMS
// usa clases distintas. Los valores de abajo son un EJEMPLO generico.
// =============================================================================
module.exports = {
  siteName: 'Example',
  baseURL: 'https://example.com',

  // Autenticacion (sitios con clave de acceso). El tipo tambien puede fijarse
  // con AUTH_TYPE en .env; las CREDENCIALES van SIEMPRE en .env, nunca aqui.
  //   type: 'none' | 'basic' | 'form'
  auth: {
    type: 'none',
    loginPath: '/login',            // solo para 'form'
    selectors: {                    // solo para 'form' — AJUSTAR al sitio
      username: '#username, input[name="username"], input[name="email"], input[type="email"]',
      password: '#password, input[name="password"], input[type="password"]',
      submit: 'button[type="submit"], input[type="submit"]',
    },
    successSelector: '',            // p. ej. 'a[href*="logout"]' o el avatar tras iniciar sesion
  },

  // Selectores especificos del sitio. AJUSTAR tras inspeccionar el HTML.
  selectors: {
    header: 'header, .site-header',
    logo: 'header img[src*="logo"]',
    logoLink: 'header a[href="https://example.com/"], header a[href="/"]',
    nav: 'header nav, header .menu',
    navActive: '.current-menu-item, [aria-current="page"], .active',
    search: 'input[type="search"], [role="search"], form.search-form',
    privacyLink: 'a[href*="privacy"], a[href*="privacidad"], a[href*="privac"]',
    // Elementos de accion cuya separacion se mide (pauta 9)
    actionElements: 'a.button, button, .btn, [role="button"]',
    // Bloques de texto para medir ancho de linea (pautas 6 y 7)
    textBlocks: 'main p, article p, .content p',
  },

  thresholds: {
    titleMin: 64, titleMax: 70,          // pauta 46 (convencion de la casa)
    titleSerpCut: 60,                    // pauta 46: a partir de aqui Google lo recorta -> aviso
    metaDescMin: 150, metaDescMax: 160,  // pauta 49
    lineWarnChars: 85,                   // pauta 6: por encima de aqui, advertencia
    lineMaxChars: 100,                   // pauta 6: por encima de aqui, no cumple
    blockMinLines: 5, blockMaxLines: 8,  // pauta 7
    contrastRatio: 4.5,                  // pauta 45
    actionGapPx: 8,                      // pauta 9 (separacion minima entre acciones)
    // pauta 41 (Lighthouse como proxy de GTmetrix)
    lighthouse: { performance: 90, seo: 90, accessibility: 90, 'best-practices': 90 },
    lighthousePerfWarn: 85,              // performance 85-89 => ADVERTENCIA (no fallo)
    lighthouseTopAudits: 6,              // cuantos audits fallidos se RESUMEN por categoria
    // Idioma de los titulos de los audits: el informe esta en espanol y las
    // incidencias de cada pagina salen de ahi. 'en-US' para dejarlos en ingles.
    lighthouseLocale: 'es',
    // Core Web Vitals de laboratorio (umbral "good" de Google). INP no se puede
    // medir en lab (necesita interaccion real): TBT es su proxy reconocido.
    cwv: {
      'largest-contentful-paint': 2500,  // ms
      'cumulative-layout-shift': 0.1,
      'total-blocking-time': 200,        // ms
    },
  },

  // SEO tecnico (categoria G2, criterios 51-58)
  seo: {
    sitemapSample: 5,   // cuantas URLs del sitemap se comprueban (200 sin redirect)
  },

  // Viewports para responsividad (pauta 39)
  viewports: [
    // El nombre sale tal cual en el informe (pautas 6 y 39): que se lea solo.
    { name: 'movil (390px)', width: 390, height: 844 },
    { name: 'tablet (768px)', width: 768, height: 1024 },
    { name: 'escritorio (1440px)', width: 1440, height: 900 },
  ],

  // Paginas a auditar. type: 'home' | 'service' | 'form' | 'content' | ...
  // noindex: true  -> marca las paginas que NO deben indexarse (carrito,
  //   checkout, mi cuenta, resultados de busqueda interna). El criterio 57 las
  //   exige con noindex; a todas las demas les aplica la comprobacion inversa
  //   (que no lleven noindex heredado de staging por error).
  pages: [
    { path: '/', type: 'home', name: 'Home' },
    { path: '/services/', type: 'service', name: 'Services' },
    {
      path: '/contact/', type: 'form', name: 'Contact',
      form: {
        formSelector: 'form',
        submit: 'button[type="submit"], input[type="submit"], .wpcf7-submit',
        fields: [
          { selector: 'input[name*="name" i]', label: 'Full Name', required: true, kind: 'text' },
          { selector: 'input[type="email"], input[name*="email" i]', label: 'Email', required: true, kind: 'email' },
          { selector: 'textarea', label: 'Message', required: true, kind: 'text' },
        ],
      },
    },
    // En una tienda WooCommerce, anadir tambien las transaccionales:
    // { path: '/carrito/',  type: 'content', name: 'Carrito',  noindex: true },
    // { path: '/finalizar-compra/', type: 'content', name: 'Checkout', noindex: true },
    // { path: '/mi-cuenta/', type: 'content', name: 'Mi cuenta', noindex: true },
    // { path: '/?s=prueba', type: 'content', name: 'Busqueda interna', noindex: true },
  ],

  // URL inexistente para comprobar la 404 personalizada (pauta 50)
  notFoundPath: '/pagina-inexistente-xyz-audit-404/',
};
