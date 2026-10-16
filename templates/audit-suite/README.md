# Auditoría web automatizada (Playwright + axe-core + Lighthouse)

Suite generada por el skill **web-portal-audit**. Ejecuta gran parte de los 56 criterios en un navegador real y produce un informe por página.

## Requisitos

- Node.js 18+
- Si esta carpeta fue creada con `assets/new-audit.sh`, las dependencias y los navegadores ya están instalados (compartidos vía symlink a `~/.claude/skills/web-portal-audit/runner/`) — no hace falta `npm install` ni `npx playwright install` de nuevo.
- Si estás usando esta plantilla suelta (sin `new-audit.sh`), instálalos una vez:

```bash
npm install
npx playwright install
```

## Configurar

Edita `audit.config.js`:
- `baseURL`, `pages` (ruta, tipo y, en formularios, los campos y el botón de envío).
- `selectors`: **ajústalos al DOM real del sitio** (logo, nav, item activo, buscador, enlace de privacidad, elementos de acción, bloques de texto).
- `thresholds` y `viewports` si necesitas otros umbrales.

## Sitios con clave de acceso (login)

Si el sitio requiere autenticación, copia la plantilla de entorno y rellena las credenciales:

```bash
cp .env.example .env
```

En `.env`:
- `AUTH_TYPE=basic` para autenticación HTTP Basic (ventana usuario/contraseña del navegador).
- `AUTH_TYPE=form` para un formulario de login en una página; ajusta en `audit.config.js` (sección `auth`) `loginPath`, los `selectors` de usuario/contraseña/enviar y un `successSelector` (p. ej. el enlace de "cerrar sesión").
- `SITE_USERNAME` y `SITE_PASSWORD` con las credenciales.

Las credenciales viven **solo en `.env`** (que está en `.gitignore`); nunca en el código ni en el repositorio. Con `form`, el login se hace una vez y la sesión se guarda en `.auth/state.json` para reutilizarla; con `basic`, se aplica automáticamente en cada petición. Si `AUTH_TYPE` es `form`/`basic` y faltan credenciales, la ejecución se detiene con un mensaje pidiéndote completar el `.env`.

## Ejecutar

```bash
# Auditoría DOM + interacción + axe-core, en los 3 navegadores (pauta 40, cross-browser)
npm test

# Solo Chromium
npm run test:a11y

# SEO técnico e indexabilidad (categoría G2, pautas 51–58) — HTTP puro, sin navegador
npm run test:seo

# Rendimiento (Lighthouse, pauta 41) — Chromium y un solo worker.
# Mide cada página DOS veces, en escritorio y en móvil: tarda el doble que una pasada.
npm run test:perf

# Generar el informe a partir de los resultados: Markdown y HTML
npm run audit:build   # -> results/informe.md y results/informe.html
```

## Historico y comparación antes/después

Cada `npm run audit:build` produce el informe en **dos formatos con el mismo contenido**:

- `results/informe.md` — Markdown, para trabajar sobre él y versionarlo.
- `results/informe.html` — un **único archivo autocontenido**: sin CSS, JS ni fuentes externas, así que
  se abre con doble clic, se envía por correo tal cual y se imprime a PDF desde el navegador. Trae índice,
  las páginas plegadas, un filtro para ver solo los incumplimientos y estilos de impresión.

Los dos se copian además a la raíz del proyecto como `resultados-auditoria.md` y `.html`.

En `results/historico/` quedan tres archivos fechados por ejecución: `<fecha>.json` (la instantánea de
todos los criterios), `informe-<fecha>.md` e `informe-<fecha>.html`. No se pisan nunca; los de
`results/` sin fecha son siempre los últimos.

A partir de la segunda ejecución, el informe abre con una sección **Comparativa con la auditoría
anterior**: variación de la puntuación y el detalle de qué criterios empeoraron, cuáles mejoraron
y cuáles son comprobaciones nuevas. Las regresiones van primero, que es lo que hay que mirar.

Para medir el efecto de una corrección: `npm test && npm run test:seo && npm run test:perf`,
después `npm run audit:build`, se aplica el arreglo, y se repite. **Conserva la carpeta del sitio
entre ejecuciones** — si la borras, se pierde el histórico y la siguiente auditoría vuelve a ser
la primera.

**No ejecutes `npx playwright test` a secas** (sin scope de archivo): correría `tests/performance.spec.js` mezclado con `audit.spec.js` bajo el paralelismo por defecto, y una medición de rendimiento con varios navegadores peleándose por la CPU no vale nada. Usa siempre `npm test`/`npm run test:a11y` (accesibilidad, cualquier paralelismo) y `npm run test:perf` (rendimiento, un solo worker y sin reintentos) por separado — los scripts de `package.json` ya delimitan cada uno a su archivo.

Reporte HTML de Playwright: `npm run test:report`.

## Qué automatiza

- **Playwright (DOM + interacción):** títulos, meta, encabezados, `lang`, `alt`, enlaces rotos, acceso a home, buscador, política de privacidad, menú activo, texto de botones, hover, espaciado, ancho de línea, foco y validación de formularios, responsividad y 404.
- **axe-core:** contraste (4,5:1) y otras incidencias de accesibilidad. Se reportan en dos filas separadas: `a11y-1` (impacto crítico/serio, hay que corregirlo primero) y `a11y-2` (moderado/menor).
- **SEO técnico (`tests/seo-tech.spec.js`, pautas 51–58):** robots.txt (incluido el bloqueo accidental de CSS/JS), descubrimiento del sitemap y muestreo de URLs, canonical, recuento de bloques JSON-LD **por `@type`** (detecta el doble schema de producto), mixed content real (subrecursos, no enlaces), convergencia de las 4 variantes de host (`http/https` × `con/sin www`) en una sola URL final, `noindex` en ambos sentidos y hreflang (set completo, autorreferencia, reciprocidad, códigos válidos). Incluye dos comprobaciones que solo tienen sentido a nivel de sitio: **unicidad de `title` y `meta description`** entre todas las páginas del alcance (criterios 46 y 49) y **`57.1` exposición de staging** (un host tipo `staging.`/`dev.` que responde público e indexable).
- **Lighthouse:** rendimiento/accesibilidad/buenas prácticas/SEO como proxy de GTmetrix (pauta 41). Cada página se mide **dos veces**: **escritorio** (sin ralentizar la CPU, latencia de fibra) y **móvil** (CPU 4× más lenta, red Slow 4G, viewport 412 px). El veredicto del criterio lo manda el peor de los dos. Además de las 4 puntuaciones de cada perfil, se extraen filas de detalle: `41.1`–`41.3` Core Web Vitals de laboratorio (LCP, CLS y TBT — **INP no se puede medir en laboratorio; TBT es su proxy reconocido**) y `41.4`–`41.7` las auditorías que fallan en cada categoría, ordenadas por ahorro estimado.

  El informe trae con eso un **resumen de Lighthouse por página** (una tabla de escritorio y otra de móvil, con las cuatro categorías y los Core Web Vitals) y, en el detalle de cada página, sus **incidencias de Lighthouse a resolver**: un audit fallido por fila, con categoría, severidad, impacto y en cuál de los dos perfiles falla. El HTML navegable de cada medición queda en `results/lighthouse/lh-<página>-<perfil>.html`.

Los fallos de contraste de axe son una decisión de paleta, no un arreglo de código: agrúpalos y genera la propuesta (el tono conforme más cercano por par, con la razón antes y después, y los textos y páginas afectados) con `node bin/contrast-propose.mjs --axe <axe.json>` del plugin, y pásala al cliente. No se cambia ningún color sin su aprobación.

Las filas `41.1`–`41.7` y `a11y-*` son **evidencia**, no criterios nuevos: no cuentan en el denominador del porcentaje, para que las cifras sigan siendo comparables con informes anteriores.

## Regresión de flujos de comprador (WooCommerce)

Suite aparte de la auditoría: no mide calidad, comprueba que **el comercio sigue funcionando**.
Se ejecuta **antes y después** de un trabajo de rendimiento o de una actualización de
núcleo/plugins/tema, y la diferencia demuestra qué se rompió.

```bash
REGRESSION_LABEL=before npm run test:regression   # antes del cambio
# ... se aplica la actualización o la optimización ...
REGRESSION_LABEL=after  npm run test:regression   # después
npm run regression:compare -- before after        # sale con 1 si algo pasó de PASS a FAIL, a SKIP o desapareció (--allow-skips lo rebaja a aviso si las dos ejecuciones tienen distinto alcance)
```

**Punto de entrada:** `npm run test:regression` (config `playwright.regression.config.js`, proyectos
`regression-desktop` y `regression-mobile`; también `test:regression:desktop` / `:mobile`). Los tests se
titulan `[<id>] … @regression`. Escribe `results/regression/<etiqueta>.md` y `.json` (sin etiqueta,
`latest`). Un solo worker y sin reintentos globales: los flujos comparten carrito y sesión.

| Flujo (`id`) | Qué comprueba |
|---|---|
| `home` | carga 200, título, cabecera, sin errores PHP ni imágenes rotas |
| `search-live`, `search-results` | sugerencias AJAX (SKIP si el buscador no las tiene) y página de resultados |
| `archive` | categoría con productos, filtros y paginación |
| `sorting` | orden por precio ascendente y descendente |
| `currency` | con un cambiador de moneda: cambia el precio, el símbolo y persiste al navegar |
| `product-page`, `variation` | galería, zoom (solo escritorio) y selección de variación |
| `add-to-cart` | añadir por AJAX y que el carrito crezca |
| `quick-view`, `wishlist` | vista rápida (SKIP en móvil si está oculta) y lista de deseos añadir/quitar |
| `cart` | cantidad, eliminar línea y rechazo de un cupón inexistente |
| `checkout` | renderiza y marca inválido un campo obligatorio vacío, **sin pulsar “Realizar pedido”** |
| `account` | formulario de acceso/registro y rechazo de credenciales falsas |
| `contact-form`, `newsletter` | validación y envío; solo escriben en un clon (ver abajo) |
| `mobile-menu`, `sticky-header` | menú móvil abre/cierra; el contenido no salta al hacer scroll |
| `admin` | acceso y pantallas clave en 200 sin errores PHP |
| `sweep` | recorre N URLs y registra errores JS y peticiones fallidas por carga |

Cada flujo da `PASS`, `FAIL` o `SKIP`. Un flujo cuya función no existe en el sitio (sin lista de deseos,
sin plugin multimoneda, sin vista rápida) sale `SKIP` **con el motivo**, nunca `FAIL`.

**Configurar.** Todo funciona con los valores de `regression/defaults.js` en un comercio WooCommerce
estándar. Lo que no coincida se fija en el bloque `regression` de `audit.config.js` (se mezcla encima):
`urls` (slugs del catálogo, carrito, checkout, cuenta, contacto), `selectors` (solo los que cambien),
`currency` (`urlParam` + `codes` si el plugin cambia de moneda por URL), `skipFlows`, `sweep`. Los
productos, la categoría y el término de búsqueda se descubren con la API Store de WooCommerce.
Credenciales solo por entorno (`.env.example`): `REGRESSION_ADMIN_USER/PASS`, `REGRESSION_CUSTOMER_USER/PASS`.
El navegador es el de `CHROMIUM_PATH` o `regression.executablePath`; no se instala ninguno.

**Reglas que no se saltan**
- **Nunca hace pedidos ni envía correo real.** El checkout se valida sin enviarlo y se aborta cualquier
  POST de pedido. El formulario de contacto y la newsletter solo se envían si el host es un clon
  (`.local`, `.test`, `localhost`, IP privada; `regression.clone` lo fuerza) o con `allowWrites: true`.
- **Ejecútala contra el clon, no contra producción.** En un clon con el correo anulado, un `mail_failed`
  de Contact Form 7 es lo esperado y cuenta como PASS; fuera de un clon es un FAIL.
- **La primera petición al admin tras una actualización puede agotar el tiempo** (migraciones, caché
  fría): el flujo `admin` reintenta una vez antes de dar FAIL.
- **Los carruseles con orden aleatorio** cambian de contenido en cada carga: la suite no compara
  contenido de carruseles, solo que cargan y no rompen; no añadas aserciones sobre su primer elemento.
- La newsletter deja un suscriptor `regression-…@example.com` en el clon: bórralo al terminar.
- Los errores JS y las peticiones fallidas del `sweep` no bloquean por sí solos: se registran y
  `regression:compare` avisa de los **nuevos** respecto a la ejecución anterior.

## Qué sigue siendo manual

Criterios de juicio humano: 2 (tamaño de campo acorde), 27 (nombre de enlace ~ destino), 30 (icono representa su función), 36 (orden lógico de navegación), 37 (registros innecesarios); y el **número literal de GTmetrix** (Lighthouse es un proxy). El informe los marca como REVISION MANUAL.
