// @ts-check
// Valores por defecto de la suite de regresion de flujos de comprador (WooCommerce).
// audit.config.js -> `regression` se mezcla ENCIMA de esto (objetos en profundidad,
// listas y cadenas se sustituyen). Todo selector es una lista CSS separada por comas:
// el primero que exista y sea visible gana. Un flujo cuya funcion no existe en el
// sitio se marca SKIP con el motivo; nunca FAIL por ausencia.
module.exports = {
  // Chromium a usar. Vacio -> env CHROMIUM_PATH -> el que traiga Playwright.
  // Nunca instales navegadores desde aqui: apunta a uno que ya exista.
  executablePath: '',
  // Peticiones que no aportan nada y ensucian el informe (regex, sin delimitadores).
  blockRequests: [
    'googletagmanager\\.com', 'google-analytics\\.com', 'analytics\\.google\\.com',
    'doubleclick\\.net', 'connect\\.facebook\\.net', 'hotjar\\.com',
  ],
  // Aislamiento de clon: 'auto' lo deduce del host (.local, .test, localhost, IP
  // privada); true/false lo fuerza. En un clon el correo esta anulado, asi que un
  // `mail_failed` de Contact Form 7 se acepta como esperado.
  clone: 'auto',
  // Flujos que ESCRIBEN (alta en newsletter, envio del formulario de contacto).
  // Fuera de un clon solo corren con allowWrites: true: enviarian correo real.
  allowWrites: false,

  viewports: {
    desktop: { width: 1366, height: 800 },
    mobile: { width: 412, height: 823 },
  },

  // Rutas de las paginas clave. Vacio = se descubre (API Store de WooCommerce) o se
  // usa el slug por defecto. Si el sitio usa otros slugs, fijalos aqui.
  urls: {
    home: '/',
    shop: '/shop/',
    cart: '/cart/',
    checkout: '/checkout/',
    account: '/my-account/',
    contact: '',          // pagina con el formulario de contacto; vacio = SKIP
    category: '',         // archivo de categoria con productos; vacio = el primero que devuelva la API
    product: '',          // producto simple comprable; vacio = el primero que devuelva la API
    variableProduct: '',  // producto variable; vacio = el primero que devuelva la API
    searchTerm: '',       // termino que debe dar resultados; vacio = una palabra de un producto
  },

  selectors: {
    // cabecera, menu movil, busqueda
    header: 'header, .site-header, #masthead',
    main: 'main, #main, #content, .site-content',
    menuToggle: '.menu-toggle, .navbar-toggler, .mobile-menu-toggle, button[aria-controls*="menu" i], button[aria-label*="menu" i], [class*="hamburger"]',
    menuPanel: '.mobile-menu, .offcanvas-menu, [class*="offcanvas"], [class*="mobile-menu"], nav[aria-label*="menu" i], .main-navigation, header nav',
    menuClose: '.mobile-menu-close, [class*="menu-close"], [class*="offcanvas"] [class*="close"], button[aria-label*="close" i], button[aria-label*="cerrar" i]',
    searchToggle: '.search-toggle, button[aria-label*="search" i], button[aria-label*="buscar" i], [class*="search-icon"], [class*="search-toggle"]',
    searchInput: 'input[type="search"], input[name="s"], input.s, input[class*="search"]',
    searchSuggestions: '.dgwt-wcas-suggestions-wrapper, .aws-search-result, .ui-autocomplete, [class*="live-search"], [class*="search-result"], [class*="search-suggest"], [class*="autocomplete"]',
    // catalogo
    productList: 'ul.products > li, .wc-block-product, .wc-block-grid__product',
    productLink: 'ul.products > li a[href], .wc-block-product a[href], .wc-block-grid__product a[href]',
    price: '.price, .wc-block-components-product-price, .wc-block-grid__product-price',
    filterLink: '.woocommerce-widget-layered-nav a, .widget_layered_nav a, .wc-block-product-filters a, .wc-block-attribute-filter a, .product-categories a',
    sortSelect: 'select.orderby, select[name="orderby"]',
    paginationNext: '.woocommerce-pagination a.next, a.page-numbers.next, .wc-block-pagination-next, nav.pagination a.next',
    quickView: '.quickview, .quick-view, [class*="quickview"], [class*="quick-view"], a[class*="quick"], button[class*="quick"]',
    quickViewModal: '.mfp-content, .modal.show, [class*="quickview"][class*="modal"], [class*="quick-view"][class*="modal"], .quickview-wrapper, .quick-view-modal',
    quickViewClose: '.mfp-close, .modal.show .btn-close, [class*="quickview"] [class*="close"], [class*="quick-view"] [class*="close"]',
    wishlistButton: '.add_to_wishlist, .woosw-btn, .wishlist-btn, .tinvwl_add_to_wishlist_button, a[class*="wishlist"], button[class*="wishlist"]',
    // ficha de producto
    gallery: '.woocommerce-product-gallery',
    galleryThumbs: '.flex-control-thumbs img, .woocommerce-product-gallery__thumbs img, .thumbnails img, .product-thumbnails img',
    galleryMain: '.woocommerce-product-gallery__image img, .woocommerce-product-gallery img',
    zoom: '.zoomImg, .zoomWindow, .zoomContainer, .easyzoom, .woocommerce-product-gallery__image--zoom, [class*="elevatezoom"]',
    variationSelect: 'form.variations_form select, table.variations select',
    variationReady: '.single_variation .price, .woocommerce-variation-price',
    addToCart: 'button.single_add_to_cart_button, form.cart button[type="submit"]',
    // carrito y checkout (clasico y bloques)
    cartQty: 'input.qty, input.wc-block-components-quantity-selector__input',
    cartUpdate: 'button[name="update_cart"]',
    cartRemove: 'a.remove, .wc-block-cart-item__remove-link',
    couponInput: '#coupon_code, input[name="coupon_code"], .wc-block-components-totals-coupon input',
    couponToggle: '.wc-block-components-totals-coupon__button, .wc-block-components-panel__button',
    couponSubmit: 'button[name="apply_coupon"], .wc-block-components-totals-coupon__button[type="submit"], .wc-block-components-totals-coupon button[type="submit"]',
    noticeError: '.woocommerce-error, .woocommerce-NoticeGroup-checkout, .wc-block-components-notice-banner.is-error, .wc-block-components-validation-error',
    checkoutForm: 'form.checkout, form.wc-block-checkout__form, .wc-block-checkout',
    checkoutRequired: '.validate-required input, .validate-required select, .wc-block-components-text-input input[required], .wc-block-components-text-input input[aria-required="true"], form.checkout input[required]',
    // cuenta
    loginForm: 'form.woocommerce-form-login, form.login, .woocommerce-form-login',
    loginUser: '#username, input[name="username"]',
    loginPass: '#password, input[name="password"]',
    loginSubmit: 'button[name="login"], form.woocommerce-form-login button[type="submit"]',
    registerForm: 'form.woocommerce-form-register, form.register',
    // formularios del sitio
    contactForm: 'form.wpcf7-form, .wpcf7 form, form.wpforms-form, form.gform_wrapper form, form[class*="contact"]',
    contactSubmit: 'input.wpcf7-submit, input[type="submit"], button[type="submit"]',
    newsletterForm: '.tnp-subscription form, form.tnp-subscription, .mc4wp-form, form[class*="newsletter"], .newsletter form, footer form',
    newsletterEmail: 'input[type="email"], input[name*="email" i]',
    newsletterSubmit: 'input[type="submit"], button[type="submit"], .tnp-submit',
    // cookies/avisos que tapan la pagina: se pulsan si estan visibles
    dismiss: '#onetrust-accept-btn-handler, .cmplz-accept, #cookie_action_close_header, .cc-allow, .cookie-notice-container #cn-accept-cookie',
  },

  currency: {
    // Selector del cambiador de moneda. Vacio de coincidencias y sin urlParam -> SKIP.
    switcher: '.woocommerce-currency-switcher, [class*="currency-switch"], [class*="currency_switch"], select[name*="currency" i], [data-currency]',
    // Si el plugin cambia de moneda con un parametro de URL, su nombre aqui. Con
    // `codes` (al menos dos) la prueba cambia por URL en lugar de pulsar el selector.
    urlParam: '',
    codes: [],
  },

  admin: {
    // Credenciales SOLO por entorno: REGRESSION_ADMIN_USER / REGRESSION_ADMIN_PASS.
    loginPath: '/wp-login.php',
    pages: [
      '/wp-admin/',
      '/wp-admin/edit.php?post_type=product',
      '/wp-admin/admin.php?page=wc-orders',
      '/wp-admin/admin.php?page=wc-settings',
      '/wp-admin/admin.php?page=wc-status',
      '/wp-admin/plugins.php',
      '/wp-admin/update-core.php',
    ],
  },

  sweep: {
    max: 25,        // URLs del barrido final
    urls: [],       // rutas extra que siempre entran
    settleMs: 1200, // espera tras la carga antes de cerrar la medicion
  },

  // Ids de flujo a omitir (p. ej. ['quick-view']). Aparecen como SKIP con el motivo.
  skipFlows: [],
};
