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

Las filas `41.1`–`41.7` y `a11y-*` son **evidencia**, no criterios nuevos: no cuentan en el denominador del porcentaje, para que las cifras sigan siendo comparables con informes anteriores.

## Qué sigue siendo manual

Criterios de juicio humano: 2 (tamaño de campo acorde), 27 (nombre de enlace ~ destino), 30 (icono representa su función), 36 (orden lógico de navegación), 37 (registros innecesarios); y el **número literal de GTmetrix** (Lighthouse es un proxy). El informe los marca como REVISION MANUAL.
