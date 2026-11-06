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
//         entera dentro de la pantalla menos el scroll-padding, no la mueve (asi
//         se queda debajo de la cabecera pegada: es el fallo, y sale sobre todo
//         hacia atras); si no, la centra. Asi el arreglo bueno (scroll-padding-top
//         con la altura de la cabecera) pasa. Contrastado con Tab de verdad. Mira 9
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
//  LO QUE NO MIDE, dicho en cada corrida: si el foco se ve (el anillo, su
//  contraste: eso es A11Y-03b), el orden de Tab de un script que lo cambia, lo
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
  // Lo que hace Chrome al llevar el foco con Tab (Blink: «centrar si hace falta», eje por eje): si la caja, con su
  // scroll-margin, ya esta entera dentro del snapport, NO se mueve, aunque quede debajo de una cabecera pegada; si no,
  // la centra en el snapport. Contrastado el 6-nov con Tab y Shift+Tab de verdad (tab-real, 5 paginas de 4 webs):
  // con «nearest», que era lo de antes, el gate contaba tapadas que el navegador no tapa (60 FALLA de 100 medidas).
  const llevaElFoco = el => {
    const r = el.getBoundingClientRect(), m = getComputedStyle(el);
    const top = r.top - px(m.scrollMarginTop, 0), bottom = r.bottom + px(m.scrollMarginBottom, 0);
    const left = r.left - px(m.scrollMarginLeft, 0), right = r.right + px(m.scrollMarginRight, 0);
    const enV = top >= pad.top && bottom <= vh - pad.bottom, enH = left >= pad.left && right <= vw - pad.right;
    if (!enV || !enH) el.scrollIntoView({ block: enV ? 'nearest' : 'center', inline: enH ? 'nearest' : 'center', behavior: 'instant' });
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

  if (CFG.anchoPedido && vw !== CFG.anchoPedido)
    notas.push(`MEDIDO A ${vw} px cuando se pidieron ${CFG.anchoPedido}. Una medida que no coincide con lo PEDIDO no es un resultado.`);
  notas.push('VI1 y VI2 · mira el texto del contenido y el orden de Tab del HTML. NO mide si el anillo de foco se ve (A11Y-03b), ' +
    'el orden que cambia un script, iframes ni shadow DOM, ni las imagenes.');

  return JSON.stringify({
    url: location.href, innerWidth: vw, innerHeight: vh,
    coincide: CFG.anchoPedido ? vw === CFG.anchoPedido : null,
    VEREDICTO: fallos.length ? 'FALLA' : 'PASA',
    fallos, avisos, notas, resumen
  }, null, 1);
})()
