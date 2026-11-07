// =============================================================================
//  GATE DE LO QUE SE VE  ·  ¿ve el visitante lo que la pagina tiene?
//  6-nov-2026 · se corre con run-gate.js, a 1366x768 y a 390x844
// =============================================================================
//
//  🔴 POR QUE EXISTE. Dos fallos que ningun gate miraba y que cuestan una pagina
//  entera o un visitante con teclado (una revision de diseno del 6-nov, tras cruzar
//  el detector de Impeccable y las guias de Vercel y de GOV.UK: sus puntos 1 y 2).
//
//    VI1  CONTENIDO INVISIBLE AL CARGAR. Una seccion que entra con una aparicion
//         (opacity:0 hasta que un script le pone la clase) no se ve NUNCA si el
//         script falla, llega tarde o mira otra clase. Y en una captura de la
//         pagina recien cargada no se nota: lo que esta por debajo del pliegue
//         tampoco se veria todavia. El gate recorre la pagina entera bajando a
//         pasos de 0,8 pantallas, mira en cada paso lo que esta a la vista, y lo
//         que no se ha visto nunca lo vuelve a poner en el centro y espera. Lo que
//         sigue en opacity 0 o visibility hidden, dentro del contenido, cuenta.
//         FALLA con 200 caracteres o mas, o con un h1 o un h2 invisible; AVISO
//         desde 40. No cuenta lo que esta oculto a proposito: display:none (un
//         acordeon, una pestana), [hidden], [inert], aria-hidden, un <details>
//         cerrado, dialogos, menus, carruseles y el aviso de cookies.
//
//    VI2  EL FOCO TAPADO (WCAG 2.2, 2.4.11, AA). Con el tabulador, el elemento que
//         recibe el foco queda ENTERO debajo de algo fijo: la cabecera pegada
//         arriba, la barra de llamar abajo. Quien usa el teclado no ve donde esta.
//         El gate recorre el orden de Tab dos veces, hacia delante y hacia atras
//         (Shift+Tab), y en cada parada desplaza como Chrome: si la caja ya esta
//         entera dentro de la pantalla menos el scroll-padding, no la mueve; si
//         asoma en parte, la lleva al borde mas cercano; si esta fuera, la centra.
//         Las dos primeras la dejan debajo de la cabecera pegada (es el fallo, y
//         sale hacia atras). El arreglo bueno (scroll-padding-top con la altura de
//         la cabecera) pasa. Contrastado con Tab de verdad, pulsacion a pulsacion. Mira 9
//         puntos de la caja: si los 9 caen en un elemento fijo o pegado que no
//         contiene la parada, esta tapada entera. FALLA. Tapada por el aviso de
//         cookies, AVISO: el visitante lo cierra al decidir. Tapada en mas de la
//         mitad, AVISO (2.4.12, AAA, pide que no se tape nada).
//
//  COMO SE TABULA SIN TECLADO: el gate corre dentro de la pagina. Da el foco a
//  cada parada con focus({preventScroll:true}) y la desplaza el. El orden es el
//  secuencial del HTML (tabindex positivos primero), el mismo que usa
//  mobile-menu-gate.js (copiado de alli, con esta nota: si cambias uno, el otro).
//  Las paradas que viven DENTRO de algo fijo (los enlaces de la propia cabecera)
//  no se miden: no las tapa lo que las contiene.
//
//    VI3  LO QUE SE VE DE UN CONTROL (WCAG 1.4.11, AA, 7-nov-2026). El anillo de
//         foco tiene que llegar a 3:1 con lo que tiene al lado, y un campo del
//         formulario, por su borde o por su fondo, a 3:1 con lo de fuera. Una web
//         nuestra tenia los campos a 2,52:1 y el anillo a 2,77:1, y A11Y-03 pasaba:
//         solo cuenta texto. El gate da el foco a cada parada (todas, tambien las
//         de lo fijo), lee el outline y las sombras sin desenfoque, y los compara
//         con lo que se ve justo fuera, que tiene que estar DETRAS del elemento
//         (un vecino no es su fondo). Un par de dos tonos (un aro blanco debajo de
//         un anillo oscuro) vale si uno de sus cambios llega a 3:1. El anillo del
//         navegador (outline auto) se da por bueno. Sobre una imagen o un
//         degradado, NO MEDIDO. FALLA bajo 3:1. Una parada que no cambia nada al
//         recibir el foco, AVISO (2.4.7): puede ir en un hijo o en ::after.
//
//  LO QUE NO MIDE, dicho en cada corrida: el contraste del TEXTO en hover y en
//  foco (eso es A11Y-03b), el orden de Tab de un script que lo cambia, lo
//  que esta en un iframe o en shadow DOM, y si una aparicion se ve bien a medias.
//  Mira el texto, no las imagenes. El texto de una capa absoluta o fija que se
//  oculta (la de una tarjeta que sale al pasar el raton) no cuenta en VI1: no es
//  una aparicion al bajar, y un script no puede poner el raton encima.
//  El aviso de cookies se busca por los atributos de sus antecesores SIN llegar a
//  <body> (un body con `has-consent` es el estado, no el aviso: botones-gate, 6-nov).
// =============================================================================
(async () => {
  const CFG = Object.assign({
    anchoPedido: null,
    pasoMs: 140,          // lo que se espera en cada paso de bajada
    revisaMs: 900,        // lo que se espera con un contenedor invisible en el centro
    maxPasos: 90,         // pasos de 0,8 pantallas: unas 70 pantallas
    maxRevisa: 25,        // contenedores invisibles que se vuelven a mirar
    minFalla: 200, minAviso: 40,
    maxParadas: 400       // paradas de Tab por pasada
  }, (typeof window !== 'undefined' && window.__GATE__) || {});

  const esperar = ms => new Promise(r => setTimeout(r, ms));
  const vw = innerWidth, vh = innerHeight;
  const html = document.documentElement;
  const fallos = [], avisos = [], notas = [], resumen = {};
  const antesScroll = html.style.scrollBehavior;
  html.style.scrollBehavior = 'auto';
  const alto = () => Math.max(document.body ? document.body.scrollHeight : 0, html.scrollHeight);
  const sel = el => {
    if (!el || !el.tagName) return '?';
    let s = el.tagName.toLowerCase();
    if (el.id) return `${s}#${el.id}`;
    const cl = [...el.classList].slice(0, 2);
    return cl.length ? `${s}.${cl.join('.')}` : s;
  };
  const txt = el => ((el && (el.getAttribute && el.getAttribute('aria-label') || el.innerText || el.textContent)) || '')
    .replace(/\s+/g, ' ').trim().slice(0, 40);
  const RE_COOKIES = /cookie|consent|gdpr|rgpd|cmplz|onetrust|didomi|cookiebot|klaro|iubenda|axeptio|tarteaucitron/i;
  // El aviso de cookies, por sus atributos, sin llegar a <body>: un body con `has-consent` (el estado, no
  // el aviso) apagaba una web entera en botones-gate el 6-nov. Para algo fijo, tambien por su texto.
  const cookiesPorAtributos = el => {
    for (let n = el; n && n !== document.body && n !== html; n = n.parentElement) {
      if (RE_COOKIES.test(`${n.id || ''} ${typeof n.className === 'string' ? n.className : ''} ${n.getAttribute && n.getAttribute('aria-label') || ''}`)) return true;
    }
    return false;
  };
  const esAvisoCookies = el => cookiesPorAtributos(el) || /\bcookies?\b/i.test((el.innerText || '').slice(0, 300));

  // ── VI1 · lo que sigue invisible ─────────────────────────────────────────
  const raiz = document.querySelector('main') || document.querySelector('[role="main"]') || document.body;
  const OCULTO_A_PROPOSITO = 'nav, [role="navigation"], [role="dialog"], [aria-modal="true"], [aria-hidden="true"], ' +
    '[hidden], [inert], [popover], [role="tooltip"], [role="tabpanel"], [role="menu"], [role="listbox"], template, noscript, ' +
    '[aria-roledescription="slide"], [aria-roledescription="carousel"], .swiper, .swiper-slide, .slick-slider, .splide, ' +
    '.glide, .carousel, .flickity-enabled, [data-carousel], .owl-carousel';
  const CROMO_DE_BODY = 'body > header, body > footer, [role="banner"], [role="contentinfo"]';
  const piezas = [];      // { el, n } un elemento con texto propio y cuantos caracteres
  {
    const w = document.createTreeWalker(raiz, NodeFilter.SHOW_TEXT);
    const porEl = new Map();
    for (let t = w.nextNode(); t; t = w.nextNode()) {
      const s = (t.nodeValue || '').replace(/\s+/g, ' ').trim();
      if (s.length < 2) continue;
      const el = t.parentElement;
      if (!el || /^(SCRIPT|STYLE|NOSCRIPT|TEMPLATE|OPTION)$/.test(el.tagName)) continue;
      porEl.set(el, (porEl.get(el) || 0) + s.length);
    }
    for (const [el, n] of porEl) {
      if (el.closest(OCULTO_A_PROPOSITO)) continue;
      if (raiz === document.body && el.closest(CROMO_DE_BODY)) continue;
      const d = el.closest('details');
      if (d && !d.open && !el.closest('summary')) continue;
      if (cookiesPorAtributos(el)) continue;
      piezas.push({ el, n });
    }
  }
  // Visible = tiene caja (no display:none) y ni ella ni un antecesor esta a opacity 0 o visibility hidden.
  const conCaja = el => (el.checkVisibility ? el.checkVisibility() : true) && el.getClientRects().length > 0;
  const seVe = el => !el.checkVisibility || el.checkVisibility({ opacityProperty: true, visibilityProperty: true });
  const aLaVista = el => { const r = el.getBoundingClientRect(); return r.bottom > 0 && r.top < vh && r.right > 0 && r.left < vw; };
  const vistas = new Set();
  let pasos = 0;
  for (let y = 0; pasos < CFG.maxPasos; pasos++) {
    scrollTo(0, y);
    await esperar(CFG.pasoMs);
    for (const p of piezas) if (!vistas.has(p) && conCaja(p.el) && aLaVista(p.el) && seVe(p.el)) vistas.add(p);
    if (y + vh >= alto() - 2) break;
    y += Math.round(vh * 0.8);
  }
  const llegoAbajo = scrollY + vh >= alto() - 2;
  // El contenedor de la aparicion: el antecesor mas alto, dentro del contenido, que se oculta el mismo.
  const ocultoPropio = n => { const cs = getComputedStyle(n); return parseFloat(cs.opacity) === 0 || cs.visibility === 'hidden'; };
  const contenedor = el => {
    let c = el;
    for (let n = el; n && n !== raiz.parentElement && n !== html; n = n.parentElement) if (ocultoPropio(n)) c = n;
    return c;
  };
  // Una capa absoluta o fija que se oculta (la de una tarjeta que se ve al pasar el raton, un desplegable) no es
  // una aparicion al bajar: se queda fuera, y se dice. Una seccion que aparece va en el flujo.
  const grupos = new Map();
  let capas = 0;
  for (const p of piezas) {
    if (vistas.has(p) || !conCaja(p.el) || seVe(p.el)) continue;
    const c = contenedor(p.el);
    if (/^(absolute|fixed)$/.test(getComputedStyle(c).position)) { capas++; continue; }
    if (!grupos.has(c)) grupos.set(c, []);
    grupos.get(c).push(p);
  }
  // Lo que no se ha visto nunca, al centro y a esperar: una aparicion con retraso, o una que solo salta centrada.
  let revisados = 0;
  for (const [c, ps] of [...grupos]) {
    if (revisados >= CFG.maxRevisa) break;
    revisados++;
    c.scrollIntoView({ block: 'center', behavior: 'instant' });
    await esperar(CFG.revisaMs);
    if (ps.every(p => seVe(p.el))) grupos.delete(c);
    else grupos.set(c, ps.filter(p => !seVe(p.el)));
  }
  const sinRevisar = Math.max(0, grupos.size - revisados);
  const invisibles = [...grupos].map(([c, ps]) => {
    const cs = getComputedStyle(c);
    return { c, n: ps.reduce((a, p) => a + p.n, 0), titulo: ps.some(p => /^H[12]$/.test(p.el.tagName) || p.el.closest('h1, h2')),
      como: parseFloat(cs.opacity) === 0 ? 'opacity 0' : cs.visibility === 'hidden' ? 'visibility hidden' : 'un antecesor oculto' };
  }).sort((a, b) => b.n - a.n);
  const nInv = invisibles.reduce((a, x) => a + x.n, 0);
  resumen.VI1 = { piezas: piezas.length, vistas: vistas.size, pasos, llegoAbajo, caracteresInvisibles: nInv, contenedores: invisibles.length, capasAbsolutasFuera: capas };
  if (capas) notas.push(`VI1 · ${capas} texto(s) ocultos en capas absolutas o fijas (las de pasar el raton): no se cuentan como apariciones.`);
  const lista = invisibles.slice(0, 4).map(x => `${sel(x.c)} «${txt(x.c)}» ${x.n} car., ${x.como}`).join(' · ');
  if (!piezas.length) notas.push('VI1 · NO MEDIDO: el contenido no tiene texto que mirar.');
  else if (nInv >= CFG.minFalla || invisibles.some(x => x.titulo))
    fallos.push(`VI1 · ${nInv} caracteres del contenido siguen invisibles tras recorrer la pagina y esperar a las apariciones` +
      `${invisibles.some(x => x.titulo) ? ' (con un titulo h1/h2)' : ''}: ${lista}. Si la aparicion no salta, eso no se ve nunca: ` +
      'que el estado de partida sea el visible y la animacion lo anada (o que la clase la ponga el CSS, no el script)');
  else if (nInv >= CFG.minAviso)
    avisos.push(`VI1 · ${nInv} caracteres del contenido siguen invisibles tras recorrer la pagina: ${lista}`);
  if (!llegoAbajo) notas.push(`VI1 · la pagina no se recorrio entera (${pasos} pasos de 0,8 pantallas): lo de mas abajo, NO MEDIDO.`);
  if (sinRevisar) notas.push(`VI1 · ${sinRevisar} contenedor(es) invisibles sin volver a mirar centrados (tope ${CFG.maxRevisa}): cuentan como invisibles.`);

  // ── VI2 · el foco tapado ──────────────────────────────────────────────────
  // El orden secuencial de Tab del HTML (el de mobile-menu-gate.js: si cambias uno, el otro).
  const tabulable = el => {
    if (el.tabIndex < 0 || el.disabled) return false;
    if (el.closest('[inert]')) return false;
    if (el.checkVisibility && !el.checkVisibility({ visibilityProperty: true })) return false;
    return true;
  };
  const SEL_FOCO = 'a[href], area[href], button, input:not([type="hidden"]), select, textarea, summary, ' +
    'iframe, [tabindex], [contenteditable=""], [contenteditable="true"], audio[controls], video[controls]';
  const enOrden = () => {
    const els = [...document.querySelectorAll(SEL_FOCO)].filter(el => {
      if (!tabulable(el)) return false;
      const d = el.parentElement && el.parentElement.closest('details');
      if (d && !d.open && !(el.tagName === 'SUMMARY' && el.parentElement === d)) return false;
      const r = el.getBoundingClientRect();
      return r.width > 0 || r.height > 0;
    });
    return els.filter(e => e.tabIndex > 0).sort((a, b) => a.tabIndex - b.tabIndex)
      .concat(els.filter(e => e.tabIndex === 0));
  };
  const fijo = n => { const p = getComputedStyle(n).position; return p === 'fixed' || p === 'sticky'; };
  const fijoQueLoContiene = el => { for (let n = el; n && n !== html; n = n.parentElement) if (fijo(n)) return n; return null; };
  const obstaculo = hit => { for (let n = hit; n && n !== html; n = n.parentElement) if (fijo(n)) return n; return null; };
  // Los 9 puntos de la caja, dentro de la pantalla. null si la caja no esta a la vista.
  const tapado = el => {
    const r = el.getBoundingClientRect();
    const x0 = Math.max(r.left, 0) + 1, x1 = Math.min(r.right, vw) - 1, y0 = Math.max(r.top, 0) + 1, y1 = Math.min(r.bottom, vh) - 1;
    if (x1 <= x0 || y1 <= y0) return null;
    let cubiertos = 0; const obs = new Set();
    for (const fx of [0, 0.5, 1]) for (const fy of [0, 0.5, 1]) {
      const hit = document.elementFromPoint(x0 + (x1 - x0) * fx, y0 + (y1 - y0) * fy);
      if (!hit || hit === el || el.contains(hit) || hit.contains(el)) continue;
      const o = obstaculo(hit);
      if (o && !o.contains(el)) { cubiertos++; obs.add(o); }
    }
    return { cubiertos, obs: [...obs] };
  };
  const nombreDe = o => {
    if (esAvisoCookies(o)) return 'el aviso de cookies';
    const r = o.getBoundingClientRect();
    if (r.top <= 2 && r.height < vh * 0.5) return `la cabecera fija (${sel(o)}, ${Math.round(r.height)} px)`;
    if (r.bottom >= vh - 2 && r.height < vh * 0.5) return `la barra fija de abajo (${sel(o)}, ${Math.round(r.height)} px)`;
    return `un elemento fijo (${sel(o)})`;
  };
  // El snapport de la pagina: la pantalla menos el scroll-padding de <html> (el de <body> no cuenta: el del viewport
  // sale del elemento raiz). Un porcentaje, contra la pantalla.
  const px = (v, base) => { const n = parseFloat(v); return isNaN(n) ? 0 : /%$/.test(String(v).trim()) ? n * base / 100 : n; };
  const csHtml = getComputedStyle(html);
  const pad = { top: px(csHtml.scrollPaddingTop, vh), bottom: px(csHtml.scrollPaddingBottom, vh),
    left: px(csHtml.scrollPaddingLeft, vw), right: px(csHtml.scrollPaddingRight, vw) };
  // Lo que hace Chrome al llevar el foco con Tab (Blink, «centrar si hace falta», eje por eje, contra el snapport y con
  // el scroll-margin de la caja): entera dentro, NO se mueve, aunque quede debajo de una cabecera pegada; asomando en
  // parte, al borde mas cercano (y ese borde, sin scroll-padding, es el de la pantalla: debajo de la cabecera); fuera
  // del todo, al centro. Mas grande que el snapport y cubriendolo, no se mueve. Contrastado el 6-nov con Tab y
  // Shift+Tab de verdad (tab-real, con traza de cada pulsacion): un campo que asomaba 2 px por arriba quedo a top 0,
  // con 2 px de desplazamiento. Con «nearest» para todo, que era lo de antes, el gate daba 60 FALLA de 100 medidas.
  const eje = (a, b, lo, hi) => {
    const dentro = Math.min(b, hi) - Math.max(a, lo);
    if (dentro >= b - a - 0.5 || dentro >= hi - lo - 0.5) return null;   // entera dentro, o lo cubre: no se mueve
    return dentro > 0 ? 'nearest' : 'center';
  };
  const llevaElFoco = el => {
    const r = el.getBoundingClientRect(), m = getComputedStyle(el);
    const v = eje(r.top - px(m.scrollMarginTop, 0), r.bottom + px(m.scrollMarginBottom, 0), pad.top, vh - pad.bottom);
    const h = eje(r.left - px(m.scrollMarginLeft, 0), r.right + px(m.scrollMarginRight, 0), pad.left, vw - pad.right);
    if (v || h) el.scrollIntoView({ block: v || 'nearest', inline: h || 'nearest', behavior: 'instant' });
  };
  const orden = enOrden().filter(el => !fijoQueLoContiene(el)).slice(0, CFG.maxParadas);
  const enteras = new Map(), cookies = new Map(), parciales = new Map();
  const porPasada = { adelante: 0, atras: 0 };
  let medidas = 0, fuera = 0;
  const apunta = (m, el, o) => { const k = nombreDe(o); if (!m.has(k)) m.set(k, []); if (!m.get(k).includes(el)) m.get(k).push(el); };
  for (const [nombre, lista2] of [['adelante', orden], ['atras', [...orden].reverse()]]) {
    scrollTo(0, nombre === 'adelante' ? 0 : alto());
    await esperar(60);
    for (const el of lista2) {
      try { el.focus({ preventScroll: true }); } catch (e) { continue; }
      llevaElFoco(el);
      const t = tapado(el);
      if (!t) { fuera++; continue; }
      medidas++;
      if (t.cubiertos === 9) {
        const malo = t.obs.find(o => !esAvisoCookies(o));
        if (malo) { apunta(enteras, el, malo); porPasada[nombre]++; } else apunta(cookies, el, t.obs[0]);
      } else if (t.cubiertos >= 5) apunta(parciales, el, t.obs[0]);
    }
  }

  // ── VI3 · el anillo de foco y el borde de los campos (WCAG 1.4.11, AA) ─────
  // Lo que dice «aqui estas» y «aqui se escribe» tiene que llegar a 3:1 con lo que tiene al lado: el anillo de foco,
  // contra lo que hay detras de el; un campo, por su borde o por su fondo, contra lo de fuera. 6-nov-2026: una web
  // nuestra con los campos a 2,52:1 y el anillo a 2,77:1 pasaba A11Y-03, que solo cuenta texto.
  // Los colores, por el lienzo: cualquier color de CSS (oklch, color-mix) sale en sRGB. Leer los digitos de
  // «oklch(...)» da un numero falso con aplomo (5-nov, una sonda copiada de otra web daba 1:1). Lo que lleva alfa se
  // mezcla con lo de debajo antes de comparar.
  const lienzo = document.createElement('canvas'); lienzo.width = lienzo.height = 1;
  const cx = lienzo.getContext('2d', { willReadFrequently: true });
  const rgba = c => { if (!c || c === 'transparent' || c === 'none') return null; cx.clearRect(0, 0, 1, 1); cx.fillStyle = '#000';
    cx.fillStyle = c; cx.fillRect(0, 0, 1, 1); const d = cx.getImageData(0, 0, 1, 1).data; return d[3] < 3 ? null : [d[0], d[1], d[2], d[3] / 255]; };
  const sobre = (a, b) => a ? [0, 1, 2].map(i => a[i] * a[3] + b[i] * (1 - a[3])) : b;    // a, con su alfa, encima de b
  const lum = c => { const x = c.map(v => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; });
    return 0.2126 * x[0] + 0.7152 * x[1] + 0.0722 * x[2]; };
  const ratio = (a, b) => { const x = lum(a), y = lum(b); return Math.round((Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05) * 100) / 100; };
  // Con su alfa, si la lleva: «#1877d2» a secas por un anillo al 55 % hacia creer que el 2,19:1 era un error (7-nov).
  const hex = c => '#' + c.slice(0, 3).map(n => Math.round(n).toString(16).padStart(2, '0')).join('') +
    (c.length > 3 && c[3] < 0.99 ? ` al ${Math.round(c[3] * 100)} %` : '');
  const MEDIA = /^(IMG|PICTURE|VIDEO|CANVAS|SVG|IFRAME|OBJECT|EMBED)$/;
  // El color de lo que se ve en n: sus fondos y los de sus antecesores, mezclados de fuera adentro hasta el primero
  // opaco. Una imagen, un degradado o un medio en el camino lo hace aproximado: entonces no se juzga, se cuenta.
  const fondoDe = n => {
    const capas = []; let aprox = !!(n && n.tagName && MEDIA.test(n.tagName.toUpperCase()));
    for (; n && n.nodeType === 1 && !aprox; n = n.parentElement) {
      const cs = getComputedStyle(n);
      if (cs.backgroundImage && cs.backgroundImage !== 'none') aprox = true;
      const b = rgba(cs.backgroundColor);
      if (b) { capas.push(b); if (b[3] >= 0.99) break; }
    }
    let c = [255, 255, 255];
    for (let i = capas.length - 1; i >= 0; i--) c = sobre(capas[i], c);
    return { c, aprox };
  };
  // Lo que hay justo fuera de la caja (a `hueco` px): lo primero que se ve en ese punto tiene que estar DETRAS del
  // elemento en su centro (un antecesor, o la seccion que tiene debajo si flota). Un vecino (el boton de al lado) no es
  // su fondo: se prueba el siguiente lado. Sin ninguno, el fondo del padre, y aproximado.
  const fueraDe = (el, hueco) => {
    const r = el.getBoundingClientRect();
    const cxp = Math.min(vw - 1, Math.max(0, r.left + r.width / 2)), cyp = Math.min(vh - 1, Math.max(0, r.top + r.height / 2));
    const enCentro = document.elementsFromPoint(cxp, cyp);
    const i = enCentro.findIndex(k => k === el || el.contains(k));
    const atras = new Set(i >= 0 ? enCentro.slice(i + 1) : []);
    for (const [a, b] of [[r.left - hueco - 2, cyp], [r.right + hueco + 2, cyp], [cxp, r.top - hueco - 2], [cxp, r.bottom + hueco + 2]]) {
      if (a < 0 || a >= vw || b < 0 || b >= vh) continue;
      const hits = document.elementsFromPoint(a, b).filter(k => k !== el && !el.contains(k));
      if (hits.length && atras.has(hits[0])) return fondoDe(hits[0]);
    }
    return Object.assign(fondoDe(el.parentElement), { aprox: true });
  };
  const partirSombras = s => (!s || s === 'none') ? [] : s.split(/,(?![^(]*\))/).map(t => {
    const color = (t.match(/(?:rgba?|hsla?|hwb|lab|lch|oklab|oklch|color)\([^)]*\)|#[0-9a-f]{3,8}\b/i) || [''])[0];
    const n = (t.replace(color, '').match(/-?[\d.]+px/g) || []).map(parseFloat);
    return { color: rgba(color), inset: /\binset\b/.test(t), x: n[0] || 0, y: n[1] || 0, blur: n[2] || 0, spread: n[3] || 0 };
  });
  // El anillo, como bandas desde el borde de la caja hacia fuera: las sombras sin desenfoque ni desplazamiento (la
  // primera de la lista, encima) y el outline, que se pinta sobre ellas. «auto» es el del navegador: dos tonos, vale.
  const anilloDe = cs => {
    const bandas = partirSombras(cs.boxShadow).filter(s => !s.inset && s.color && s.spread > 0 && s.blur <= 1 && !s.x && !s.y)
      .map(s => ({ de: 0, a: s.spread, color: s.color, sombra: true }));
    const ow = parseFloat(cs.outlineWidth) || 0;
    if (cs.outlineStyle !== 'none' && ow > 0) {
      if (cs.outlineStyle === 'auto') return { navegador: true, bandas };
      const off = parseFloat(cs.outlineOffset) || 0, oc = rgba(cs.outlineColor);
      if (oc) bandas.push({ de: off, a: off + ow, color: oc, outline: true });
    }
    return { navegador: false, bandas };
  };
  // Cada cambio de color del perfil, de dentro afuera hasta lo de fuera: el anillo se ve si UNO llega a 3:1 (un anillo
  // claro sobre oscuro, o el oscuro de un par de dos tonos sobre su aro blanco). Dentro de la caja (un outline con
  // offset negativo), lo de debajo es el fondo del propio elemento.
  const mejorBorde = (bandas, fuera, propio) => {
    const hasta = Math.max(...bandas.map(b => b.a)), desde = Math.min(0, ...bandas.map(b => b.de));
    const colorEn = r => {
      const o = bandas.find(b => b.outline && r >= b.de && r < b.a);
      const ss = bandas.filter(b => b.sombra && r >= 0 && r < b.a);
      let c = r < 0 ? propio : fuera;
      for (let k = ss.length - 1; k >= 0; k--) c = sobre(ss[k].color, c);
      return o ? sobre(o.color, c) : c;
    };
    const perfil = [];
    for (let r = desde + 0.25; r < hasta; r += 0.5) perfil.push(colorEn(r));
    perfil.push(fuera);
    let mejor = 1;
    for (let k = 1; k < perfil.length; k++) mejor = Math.max(mejor, ratio(perfil[k - 1], perfil[k]));
    return { v: mejor, anillo: (bandas.find(b => b.outline) || bandas[0]).color };
  };
  // Lo que SE VE del estado, nada mas: `outline: none` no reinicia outline-offset, y el del navegador cambia al recibir
  // el foco sin que se vea nada (7-nov: «no cambia nada» salia como «otro indicador»). Un outline o un borde solo cuentan
  // si tienen estilo y ancho.
  const firmaDe = cs => [
    cs.outlineStyle !== 'none' && parseFloat(cs.outlineWidth) > 0 ? `${cs.outlineStyle} ${cs.outlineWidth} ${cs.outlineColor} ${cs.outlineOffset}` : 'sin outline',
    cs.boxShadow, cs.backgroundColor, cs.color, `${cs.textDecorationLine} ${cs.textDecorationColor}`,
    ['Top', 'Right', 'Bottom', 'Left'].map(l => parseFloat(cs[`border${l}Width`]) > 0 && !/none|hidden/.test(cs[`border${l}Style`])
      ? `${cs[`border${l}Width`]} ${cs[`border${l}Color`]}` : '-').join(',')].join('|');
  const flojos = new Map(), sinCambio = [];
  const vi3 = { medidos: 0, delNavegador: 0, otroIndicador: 0, sobreImagen: 0, sinCambio: 0, flojos: 0 };
  // La pasada hacia atras de VI2 acaba con el foco en la PRIMERA parada: sin soltarlo, su estado «antes» ya es el del
  // foco y sale como «no cambia nada» (7-nov, el banco lo vio en cuatro fixturas). Medido ese dia: tras blur(), el
  // focus() de la pagina sigue pintando :focus-visible, igual que la tecla Tab (55 de 55 paradas).
  if (document.activeElement && document.activeElement.blur) document.activeElement.blur();
  scrollTo(0, 0);
  await esperar(60);
  for (const el of enOrden().slice(0, CFG.maxParadas)) {
    const antes = firmaDe(getComputedStyle(el));
    try { el.focus({ preventScroll: true }); } catch (e) { continue; }
    if (document.activeElement !== el) continue;
    llevaElFoco(el);
    const cs = getComputedStyle(el);
    if (firmaDe(cs) === antes) { vi3.sinCambio++; sinCambio.push(el); continue; }
    const an = anilloDe(cs);
    if (an.navegador) { vi3.delNavegador++; continue; }
    if (!an.bandas.length) { vi3.otroIndicador++; continue; }
    const hueco = Math.max(...an.bandas.map(b => b.a));
    const fu = fueraDe(el, hueco);
    if (fu.aprox) { vi3.sobreImagen++; continue; }
    vi3.medidos++;
    const m = mejorBorde(an.bandas, fu.c, sobre(rgba(cs.backgroundColor), fu.c));
    if (m.v < 3) {
      vi3.flojos++;
      const k = `el anillo ${hex(m.anillo)} sobre ${hex(fu.c)}, ${m.v}:1`;
      if (!flojos.has(k)) flojos.set(k, []);
      flojos.get(k).push(el);
    }
  }
  if (document.activeElement && document.activeElement.blur) document.activeElement.blur();
  // Los campos, en reposo: se distinguen por el borde (o una sombra que hace de borde) o por su fondo. Basta uno.
  const CAMPO = 'input:not([type="hidden"]):not([type="checkbox"]):not([type="radio"]):not([type="range"]):not([type="color"])' +
    ':not([type="file"]):not([type="submit"]):not([type="button"]):not([type="reset"]):not([type="image"]), select, textarea';
  const camposFlojos = new Map();
  const vi3b = { campos: 0, flojos: 0, sobreImagen: 0 };
  for (const f of document.querySelectorAll(CAMPO)) {
    if (f.disabled || !conCaja(f) || !seVe(f) || f.closest('[inert], [aria-hidden="true"]')) continue;
    f.scrollIntoView({ block: 'center', behavior: 'instant' });
    const cs = getComputedStyle(f), fu = fueraDe(f, 0);
    if (fu.aprox || (cs.backgroundImage && cs.backgroundImage !== 'none')) { vi3b.sobreImagen++; continue; }
    vi3b.campos++;
    const suyo = sobre(rgba(cs.backgroundColor), fu.c);
    const vals = [ratio(suyo, fu.c)];
    for (const lado of ['Top', 'Right', 'Bottom', 'Left']) {
      const w = parseFloat(cs[`border${lado}Width`]) || 0, st = cs[`border${lado}Style`];
      const b = rgba(cs[`border${lado}Color`]);
      if (w >= 1 && b && st !== 'none' && st !== 'hidden') vals.push(ratio(sobre(b, suyo), fu.c));
    }
    for (const s of partirSombras(cs.boxShadow))
      if (s.color && s.spread >= 1 && s.blur <= 1) vals.push(ratio(sobre(s.color, s.inset ? suyo : fu.c), fu.c));
    const v = Math.max(...vals);
    if (v < 3) {
      vi3b.flojos++;
      const k = `${v}:1 (borde ${rgba(cs.borderBottomColor) ? hex(sobre(rgba(cs.borderBottomColor), suyo)) : 'ninguno'}, fondo ${hex(suyo)}, fuera ${hex(fu.c)})`;
      if (!camposFlojos.has(k)) camposFlojos.set(k, []);
      camposFlojos.get(k).push(f);
    }
  }
  if (document.activeElement && document.activeElement.blur) document.activeElement.blur();
  scrollTo(0, 0);
  html.style.scrollBehavior = antesScroll;
  const ejemplos = els => els.slice(0, 3).map(e => `${sel(e)} «${txt(e)}»`).join(', ');
  const cuenta = m => [...m.values()].reduce((a, l) => a + l.length, 0);
  resumen.VI2 = { paradas: orden.length, medidas, fueraDeLaPantalla: fuera, tapadasEnteras: cuenta(enteras),
    tapadasPorPasada: porPasada, porElAvisoDeCookies: cuenta(cookies), tapadasEnParte: cuenta(parciales), scrollPadding: pad };
  if (!orden.length) notas.push('VI2 · NO MEDIDO: la pagina no tiene paradas de Tab fuera de lo fijo.');
  for (const [k, els] of enteras)
    fallos.push(`VI2 · ${els.length} parada(s) de Tab quedan tapadas enteras por ${k}: ${ejemplos(els)} (WCAG 2.2, 2.4.11). ` +
      `El arreglo: scroll-padding-${/abajo/.test(k) ? 'bottom' : 'top'} en html con la altura de la barra, o que no sea fija`);
  for (const [k, els] of cookies)
    avisos.push(`VI2 · ${els.length} parada(s) de Tab quedan tapadas enteras por ${k} mientras esta abierto: ${ejemplos(els)}. ` +
      'Se va al decidir; si no se cierra con Escape ni deja la pagina a mano, es un fallo de 2.4.11');
  for (const [k, els] of parciales)
    avisos.push(`VI2 · ${els.length} parada(s) de Tab quedan tapadas en mas de la mitad por ${k}: ${ejemplos(els)} (2.4.12, AAA)`);

  resumen.VI3 = Object.assign({}, vi3, { campos: vi3b.campos, camposFlojos: vi3b.flojos, camposSobreImagen: vi3b.sobreImagen });
  for (const [k, els] of flojos)
    fallos.push(`VI3 · ${els.length} parada(s) de Tab con ${k} (WCAG 1.4.11 pide 3:1 con lo que tiene al lado): ${ejemplos(els)}. ` +
      'El arreglo: un anillo que llegue a 3:1 con ese fondo, o un aro de otro color debajo (box-shadow sin desenfoque) que lo separe');
  for (const [k, els] of camposFlojos)
    fallos.push(`VI3 · ${els.length} campo(s) del formulario no se distinguen de lo de fuera: el mejor de su borde y su fondo da ${k} ` +
      `(WCAG 1.4.11 pide 3:1): ${ejemplos(els)}. El arreglo: un borde que llegue a 3:1 con el fondo de fuera`);
  if (sinCambio.length)
    avisos.push(`VI3 · ${sinCambio.length} parada(s) de Tab no cambian nada al recibir el foco (ni anillo, ni fondo, ni color, ni subrayado): ` +
      `${ejemplos(sinCambio)} (WCAG 2.4.7). Puede ir en un hijo, en ::after o en un antecesor con :focus-within: eso no se mira aqui`);
  if (vi3.sobreImagen || vi3b.sobreImagen)
    notas.push(`VI3 · NO MEDIDO: ${vi3.sobreImagen} anillo(s) y ${vi3b.sobreImagen} campo(s) sobre una imagen, un degradado o un fondo que no se ` +
      'pudo leer. El color de debajo no se sabe por la hoja: se mira a ojo o con una captura del inspector.');
  if (vi3.otroIndicador)
    notas.push(`VI3 · ${vi3.otroIndicador} parada(s) marcan el foco con otra cosa que un anillo (fondo, color, subrayado): su contraste no se mide aqui.`);
  if (vi3.delNavegador) notas.push(`VI3 · ${vi3.delNavegador} parada(s) con el anillo del navegador (outline auto, dos tonos): se da por bueno.`);

  if (CFG.anchoPedido && vw !== CFG.anchoPedido)
    notas.push(`MEDIDO A ${vw} px cuando se pidieron ${CFG.anchoPedido}. Una medida que no coincide con lo PEDIDO no es un resultado.`);
  notas.push('VI1, VI2 y VI3 · mira el texto del contenido, el orden de Tab del HTML, el anillo de foco y el borde de los campos. ' +
    'NO mide el contraste del texto en hover y en foco (A11Y-03b), el orden que cambia un script, iframes ni shadow DOM, ' +
    'las casillas y los botones de opcion (van con el dibujo del navegador), ni las imagenes.');

  return JSON.stringify({
    url: location.href, innerWidth: vw, innerHeight: vh,
    coincide: CFG.anchoPedido ? vw === CFG.anchoPedido : null,
    VEREDICTO: fallos.length ? 'FALLA' : 'PASA',
    fallos, avisos, notas, resumen
  }, null, 1);
})()
