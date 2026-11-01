// =============================================================================
//  GATE DE MARCA  ·  ¿la pagina lleva la marca entera, y solo la marca?
//  1-nov-2026 · se corre con run-gate.js, a 1366x768 y a 390x844
// =============================================================================
//
//  🔴 POR QUE EXISTE. Medido en diez webs reales el 1-nov-2026: siete sin icono
//  de iPhone, ninguna con manifest, iconos de navegador que a 16 px no se
//  distinguen o que no salen del logo (una inicial en Arial), dos cabeceras sin
//  logo (solo texto). Ningun gate lo miraba: la puerta media la maqueta, las
//  pantallas, el movil y el menu, y la identidad quedaba a ojo. Y los colores y
//  los tipos se iban de la paleta pagina a pagina sin que nadie lo contara
//  (`blueprint`, la regla de las fichas de diseno: ningun valor fuera de ellas).
//
//  QUE COMPRUEBA
//
//    B1  La marca en la cabecera: una imagen o un SVG en la cabecera, con señas
//        de logo (alt, clase, el enlace a la portada). Sin nada, FALLA. Si la
//        marca esta hecha con texto y CSS (unas iniciales en una caja y el
//        nombre), AVISO: es marca, pero no un logo del que salgan los iconos.
//    B2  Los iconos, declarados Y QUE CARGAN: SVG para la pestaña; PNG o .ico de
//        32 px o mas (los navegadores sin SVG; un 48x48 vale); apple-touch-icon
//        (el iPhone); manifest que se lee como JSON y nombra 192 y 512, que
//        cargan. Lo que falta o no carga, FALLA, cada uno con su linea.
//    B3  `<meta name="theme-color">`. FALLA.
//    B4  Ningun color fuera de la paleta (`colores` en la configuracion: la
//        lista de #hex del fichero de marca de la web). Se cuentan el color del
//        texto, el fondo y el borde de lo que se ve, pasados a sRGB pintandolos
//        en un lienzo (vale oklch y color()); distancia RGB <= 12 cuenta como el
//        mismo. FALLA con los de fuera, cuantas veces y un ejemplo de donde.
//    B5  Ningun tipo fuera de la marca (`tipos`: los nombres de familia). Las
//        genericas (serif, sans-serif, system-ui…) no cuentan. FALLA.
//
//  Sin `colores` o sin `tipos`, B4 o B5 no se miden y la nota lo dice: un gate
//  que no tiene contra que comparar no puede decir PASA de eso.
//
//  LO QUE NO MIDE, a proposito: la imagen social. Que exista el fichero la mide
//  S2.9 de audit.sh, su alt SEO-06 y que haya una por tipo SEO-08, en qa-master.
//  Dos copias de una regla divergen; aqui no hay otra. Tampoco si un icono «se
//  lee» a 16 px: eso se mira en una hoja, a su tamaño de verdad.
//
//  CONFIGURACION (window.__GATE__, por run-gate.js):
//    { "colores": ["#1a1a2e", …], "tipos": ["Inter", …], "marca": "Nombre",
//      "ignorar": ["#chat-widget", …] }      ignorar = selectores de terceros
//
//  `datos` lleva todo lo medido (logo, iconos, colores y tipos contados) para
//  quien puntua encima: la nota de diseno de 0 a 100 lee ESTE gate, no una copia.
// =============================================================================
(async () => {
  const CFG = window.__GATE__ || {};
  const vw = innerWidth, vh = innerHeight;
  const fallos = [], avisos = [], notas = [];
  const q = (s) => document.querySelector(s);
  const abs = (h) => { try { return h ? new URL(h, location.href).href : null; } catch (e) { return null; } };
  const visible = (e) => { const r = e.getBoundingClientRect(); const s = getComputedStyle(e);
    return r.width > 0 && r.height > 0 && s.visibility !== 'hidden' && s.display !== 'none' && +s.opacity > 0.05; };
  const HOME = /^(\/|\.\/|index\.html|\/[a-z]{2}\/?)$/;

  // ── B1 · la marca en la cabecera ───────────────────────────────────────────
  const cab = q('header') || q('[role="banner"]') || q('nav');
  let logo = null;
  if (cab) {
    const marca = String(CFG.marca || '').toLowerCase();
    const cand = [...cab.querySelectorAll('img,svg,picture')].filter((e) => { const r = e.getBoundingClientRect();
      return visible(e) && r.width >= 16 && r.height >= 12 && r.top < 220; });
    const esLogo = (e) => { const a = e.closest('a');
      const t = [e.getAttribute('alt'), e.getAttribute('aria-label'), e.getAttribute('title'), e.getAttribute('class'), e.id,
        e.getAttribute('src'), a && a.getAttribute('aria-label'), a && a.getAttribute('class'), a && a.getAttribute('title')].join(' ').toLowerCase();
      return /logo|brand|marca|wordmark/.test(t) || (marca && t.includes(marca)) || (a && HOME.test(a.getAttribute('href') || '')); };
    const l = cand.find(esLogo);
    if (l) logo = { tag: l.tagName.toLowerCase(), ancho: Math.round(l.getBoundingClientRect().width),
      firma: l.tagName.toLowerCase() === 'svg' ? 'svg:' + l.innerHTML.replace(/\s+/g, '').length : (l.currentSrc || l.getAttribute('src') || '').replace(/\?.*$/, '') };
    if (!logo) {
      const a = [...cab.querySelectorAll('a[href]')].find((x) => { const r = x.getBoundingClientRect();
        const t = [x.getAttribute('class'), x.getAttribute('aria-label'), x.id].join(' ').toLowerCase();
        return visible(x) && r.top < 220 && (x.innerText || '').trim().split(/\s+/).length <= 4 &&
          (/logo|brand|marca|wordmark/.test(t) || HOME.test(x.getAttribute('href') || '')); });
      if (a && (a.innerText || '').trim()) logo = { tag: 'texto', firma: 'texto:' + a.innerText.replace(/\s+/g, ' ').trim(), ancho: Math.round(a.getBoundingClientRect().width) };
    }
  }
  if (!logo) fallos.push(`B1 · sin marca en la cabecera a ${vw} px: ni un logo (imagen o SVG) ni el nombre en el enlace a la portada`);
  else if (logo.tag === 'texto') avisos.push(`B1 · la marca de la cabecera esta hecha con texto y CSS («${logo.firma.slice(6, 60)}»), no es un logo en SVG o imagen del que salgan los iconos`);

  // ── B2 · los iconos, declarados y que cargan ───────────────────────────────
  // Una imagen se prueba cargandola (vale de otro origen y data:); el manifest,
  // pidiendolo (es JSON). Un icono declarado que no carga no es un icono.
  const carga = (u) => new Promise((ok) => { const i = new Image(); const t = setTimeout(() => ok(false), 10000);
    i.onload = () => { clearTimeout(t); ok(i.naturalWidth > 0); }; i.onerror = () => { clearTimeout(t); ok(false); }; i.src = u; });
  const iconos = [...document.querySelectorAll('link[rel]')].filter((l) => /(^|\s)(icon|apple-touch-icon|manifest|mask-icon)(\s|$)/i.test(l.rel))
    .map((l) => ({ rel: l.rel.toLowerCase(), href: abs(l.getAttribute('href')), sizes: l.getAttribute('sizes') || '', type: l.getAttribute('type') || '' }));
  for (const i of iconos) if (i.rel !== 'manifest') i.carga = i.href ? await carga(i.href) : false;
  const lado = (i) => Math.max(0, ...i.sizes.split(/\s+/).map((s) => parseInt(s, 10) || 0));
  const deIcono = iconos.filter((i) => /(^|\s)icon(\s|$)/.test(i.rel) && !/apple/.test(i.rel));
  const esSvg = (i) => /svg/.test(i.type) || /\.svg(\?|$)/i.test(i.href || '') || /^data:image\/svg/.test(i.href || '');
  const es32 = (i) => /\.ico(\?|$)/i.test(i.href || '') || /icon/.test(i.type) ||
    ((/png/.test(i.type) || /\.png(\?|$)/i.test(i.href || '')) && (!i.sizes || lado(i) >= 32));
  // `b2` resume cada comprobacion ('ok' | 'falta' | 'no carga' | …): quien puntua encima lo
  // lee de aqui y no vuelve a decidir que es un icono valido (una sola copia de la regla).
  const b2 = {};
  const comprueba = (k, que, lista) => {
    if (!lista.length) { fallos.push(`B2 · sin ${que}`); b2[k] = 'falta'; return; }
    if (!lista.some((i) => i.carga)) { fallos.push(`B2 · ${que} declarado y NO carga: ${lista.map((i) => (i.href || '').slice(0, 80)).join(', ')}`); b2[k] = 'no carga'; return; }
    b2[k] = 'ok';
  };
  comprueba('svg', 'icono SVG para la pestaña (<link rel="icon" type="image/svg+xml">)', deIcono.filter(esSvg));
  comprueba('png32', 'icono PNG o .ico de 32 px o mas (los navegadores sin SVG)', deIcono.filter(es32));
  comprueba('apple', 'apple-touch-icon (la pantalla de inicio del iPhone; sin el sale una captura de la pagina)', iconos.filter((i) => /apple-touch-icon/.test(i.rel)));
  const man = iconos.find((i) => i.rel === 'manifest');
  let manifest = null;
  if (!man) { fallos.push('B2 · sin manifest (<link rel="manifest">) con los iconos de 192 y 512'); b2.manifest = 'falta'; }
  else {
    let j = null, st = 0;
    try { const r = await fetch(man.href, { signal: AbortSignal.timeout(10000) }); st = r.status; j = JSON.parse(await r.text()); } catch (e) { /* abajo */ }
    manifest = { href: man.href, status: st, iconos: [] };
    if (!j) { fallos.push(`B2 · el manifest declarado no se lee como JSON (${st ? 'HTTP ' + st : 'no carga'}): ${man.href}`); b2.manifest = 'no carga'; }
    else {
      for (const ic of (Array.isArray(j.icons) ? j.icons : [])) {
        const u = abs(new URL(ic.src || '', man.href).href);
        manifest.iconos.push({ src: u, sizes: String(ic.sizes || ''), carga: u ? await carga(u) : false });
      }
      const mal = [];
      for (const t of ['192x192', '512x512']) {
        const ic = manifest.iconos.filter((x) => x.sizes.split(/\s+/).includes(t));
        if (!ic.length) { fallos.push(`B2 · el manifest no nombra un icono de ${t}`); mal.push(`sin ${t}`); }
        else if (!ic.some((x) => x.carga)) { fallos.push(`B2 · el icono de ${t} del manifest NO carga: ${ic[0].src.slice(0, 80)}`); mal.push(`${t} no carga`); }
      }
      b2.manifest = mal.length ? mal.join(', ') : 'ok';
    }
  }

  // ── B3 · theme-color ───────────────────────────────────────────────────────
  const themeColor = (q('meta[name="theme-color"]') || {}).content || null;
  if (!themeColor) fallos.push('B3 · sin <meta name="theme-color"> (el color de la barra del navegador en el movil)');

  // ── B4 y B5 · colores y tipos, contados en lo que se ve ────────────────────
  const lienzo = document.createElement('canvas'); lienzo.width = lienzo.height = 1;
  const cx = lienzo.getContext('2d', { willReadFrequently: true });
  const rgba = (c) => { if (!c || c === 'transparent') return null; cx.clearRect(0, 0, 1, 1); cx.fillStyle = '#000'; cx.fillStyle = c;
    cx.fillRect(0, 0, 1, 1); const d = cx.getImageData(0, 0, 1, 1).data; return d[3] < 13 ? null : [d[0], d[1], d[2]]; };
  const hex = (x) => '#' + x.map((n) => n.toString(16).padStart(2, '0')).join('');
  const donde = (e) => (e.tagName.toLowerCase() + (e.id ? '#' + e.id : '') + (typeof e.className === 'string' && e.className.trim() ? '.' + e.className.trim().split(/\s+/)[0] : '')).slice(0, 50);
  const colores = {}, tipos = {};
  const suma = (o, k, uso, e) => { if (!k) return; o[k] = o[k] || { n: 0, usos: {}, ej: donde(e) }; o[k].n++; o[k].usos[uso] = (o[k].usos[uso] || 0) + 1; };
  const ignorar = (CFG.ignorar || []).join(',');
  let n = 0;
  for (const e of document.body.querySelectorAll('*')) {
    if (n > 2500) break;
    if (['SCRIPT', 'STYLE', 'NOSCRIPT', 'TEMPLATE', 'META', 'LINK'].includes(e.tagName) || !visible(e)) continue;
    if (ignorar && e.closest(ignorar)) continue;
    n++;
    const s = getComputedStyle(e);
    if ([...e.childNodes].some((c) => c.nodeType === 3 && c.textContent.trim())) {
      const c = rgba(s.color); if (c) suma(colores, hex(c), 'texto', e);
      suma(tipos, s.fontFamily.split(',')[0].trim().replace(/^["']|["']$/g, '').toLowerCase(), 'texto', e);
    }
    const f = rgba(s.backgroundColor); if (f) suma(colores, hex(f), 'fondo', e);
    if (parseFloat(s.borderTopWidth) > 0 && s.borderTopStyle !== 'none') { const c = rgba(s.borderTopColor); if (c) suma(colores, hex(c), 'borde', e); }
  }
  const aRgb = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16));
  const norm = (h) => { h = String(h).toLowerCase().replace(/^#/, ''); return '#' + (h.length === 3 ? h.split('').map((c) => c + c).join('') : h); };
  const fueraColores = [], fueraTipos = [];
  if (Array.isArray(CFG.colores) && CFG.colores.length) {
    const pal = CFG.colores.map(norm).filter((h) => /^#[0-9a-f]{6}$/.test(h)).map(aRgb);
    for (const [h, v] of Object.entries(colores)) if (!pal.some((p) => Math.hypot(...p.map((x, i) => x - aRgb(h)[i])) <= 12)) fueraColores.push([h, v]);
    fueraColores.sort((a, b) => b[1].n - a[1].n);
    if (fueraColores.length) fallos.push(`B4 · ${fueraColores.length} color(es) fuera de la paleta a ${vw} px: ` +
      fueraColores.slice(0, 6).map(([h, v]) => `${h} (${v.n}, ${Object.keys(v.usos).join('/')}, p. ej. ${v.ej})`).join(' · '));
  } else notas.push('B4 · NO MEDIDO: sin `colores` en la configuracion (la paleta del fichero de marca de la web)');
  const GENERICOS = ['serif', 'sans-serif', 'monospace', 'system-ui', '-apple-system', 'blinkmacsystemfont', 'ui-sans-serif', 'ui-serif', 'ui-monospace', 'cursive', 'fantasy', 'emoji'];
  if (Array.isArray(CFG.tipos) && CFG.tipos.length) {
    const marcaT = CFG.tipos.map((t) => String(t).trim().toLowerCase());
    for (const [t, v] of Object.entries(tipos)) if (!marcaT.includes(t) && !GENERICOS.includes(t)) fueraTipos.push([t, v]);
    fueraTipos.sort((a, b) => b[1].n - a[1].n);
    if (fueraTipos.length) fallos.push(`B5 · ${fueraTipos.length} tipo(s) fuera de la marca a ${vw} px: ` +
      fueraTipos.slice(0, 4).map(([t, v]) => `${t} (${v.n}, p. ej. ${v.ej})`).join(' · '));
  } else notas.push('B5 · NO MEDIDO: sin `tipos` en la configuracion (las familias del fichero de marca de la web)');

  if (vw !== CFG.anchoPedido) notas.push(`MEDIDO A ${vw} px cuando se pidieron ${CFG.anchoPedido}. Una medida que no coincide con lo PEDIDO no es un resultado.`);
  notas.push('La imagen social no se mide aqui: el fichero, S2.9 de audit.sh; su alt, SEO-06; una por tipo, SEO-08 (qa-master).');

  return JSON.stringify({
    url: location.href, innerWidth: vw, innerHeight: vh, coincide: vw === CFG.anchoPedido,
    VEREDICTO: fallos.length ? 'FALLA' : 'PASA',
    fallos, avisos, notas,
    datos: { logo, b2, iconos, manifest, themeColor, colores, tipos, contados: n,
      paleta: Array.isArray(CFG.colores) && CFG.colores.length > 0, deMarca: Array.isArray(CFG.tipos) && CFG.tipos.length > 0,
      fueraColores: fueraColores.map(([h, v]) => ({ hex: h, n: v.n })), fueraTipos: fueraTipos.map(([t, v]) => ({ tipo: t, n: v.n })) }
  }, null, 1);
})()
