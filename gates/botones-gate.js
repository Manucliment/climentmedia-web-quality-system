// =============================================================================
//  GATE DE BOTONES  ·  ¿un mismo boton se ve igual en toda la pagina?
//  6-nov-2026 · se corre con run-gate.js, a 1366x768 y a 390x844
// =============================================================================
//
//  🔴 POR QUE EXISTE. 2-nov-2026: el recibo de una web daba PASA (0 FALLO) y la
//  puerta 30 de 30 con cinco estilos de boton a la vez. Medido en lo servido (82
//  URL, 1366 y 390, estilos calculados): el primario iba sin borde y medía 53 px,
//  el secundario con borde 55; un `margin-top` bajaba el primario 6,4 px y
//  estiraba a sus vecinos a 59; el secundario tenia dos rellenos; la cabecera y
//  otra seccion llevaban un boton propio cada una. Lo vio el dueño en el movil.
//  Ningun gate comparaba un boton con otro: cada uno mira su pagina por zonas.
//
//  QUE ES UN BOTON AQUI: un <a href> o <button> visible con fondo (color o
//  degradado) o borde, y relleno; o con `btn`, `cta` o `button` en la clase. No
//  cuentan los que abren algo (`aria-expanded`: el menu, un desplegable), los
//  del aviso de cookies ni lo de `ignorar`.
//
//  SU GRUPO: con `familias` en la configuracion, la primera familia cuyo selector
//  casa. Sin ella, sus clases (ordenadas): una variante con nombre (`btn--sm`) es
//  otro grupo, y es lo que se pide. Un boton sin clase no tiene grupo: no se
//  compara (dos <button> sin clase pueden ser cosas distintas), y se cuenta.
//
//  LO QUE SE COMPARA, en estilos calculados, en dos partes:
//    forma    tamaño, peso y familia del tipo, mayusculas, radio, grueso del
//             borde y relleno. Igual en TODA la pagina.
//    pintura  fondo (color o degradado), color del texto y del borde. Igual solo
//             SOBRE EL MISMO FONDO: el boton invertido de una banda oscura es el
//             mismo boton (medido el 6-nov: en una web, el primario azul y su
//             version blanca en la banda oscura daban «dos firmas», y no lo son).
//             El fondo de detras se lee subiendo por los padres: claro, oscuro o
//             imagen. Dos colores a menos de 12 en RGB (y 5 % de opacidad) son
//             el mismo: vale oklch, se pintan en un lienzo.
//  La altura no va en la forma (depende de si el texto parte en dos lineas): se
//  compara aparte, solo entre los de UNA linea.
//
//  QUE COMPRUEBA
//    BT1  Un mismo grupo con dos formas en la pagina. FALLA, con lo que cambia.
//    BT2  Un mismo grupo, sobre el mismo fondo, con dos pinturas. FALLA.
//    BT3  Un mismo grupo y forma, en una linea, con alturas que difieren mas de
//         2 px (el margin-top que estira a los vecinos). FALLA.
//    BT4  Con `familias`: un boton que no es de ninguna. AVISO (un boton propio).
//  Y entre paginas, `botones-sitio.js` compara los `datos.grupos` de varias
//  salidas con las mismas reglas: la puerta lo corre sobre lo que mide.
//
//  LO QUE NO MIDE, a proposito: hover y foco (el contraste en hover es un sin
//  mirar firmado aparte), ni si el boton «convierte» (measure-screens y
//  mobile-gate miran donde caen los CTA). Una sola copia de cada regla.
//
//  CONFIGURACION (window.__GATE__, por run-gate.js):
//    { "familias": { "primario": ".btn-primary, .btn-download", "secundario": ".btn-ghost" },
//      "ignorar": ["#chat-widget", …] }
// =============================================================================
(() => {
  // ── LA COMPARACION, UNA SOLA COPIA ─────────────────────────────────────────
  //  La usan este gate (los botones de una pagina) y `botones-sitio.js` (los de
  //  varias paginas juntas, en node): dos copias de una regla divergen.
  //  botones = [{ grupo, contexto, campos, alto, lineas, texto }]
  //    -> { fallos: [{ regla, clave, msg }], grupos }
  const FORMA = ['tamaño', 'peso', 'tipo', 'mayusculas', 'radio', 'borde', 'relleno'];
  const PINTURA = ['fondo', 'texto', 'color del borde'];
  const compara = (botones, vw) => {
    // Dos pinturas son la misma si cada color esta a <= 12 en RGB y a <= 5 % de opacidad.
    const aRgba = (h) => { const m = /^#([0-9a-f]{6})(?:\/(\d+)%)?$/.exec(h); if (!m) return null;
      return [0, 2, 4].map((i) => parseInt(m[1].slice(i, i + 2), 16)).concat(m[2] ? +m[2] : 100); };
    const mismoColor = (a, b) => { if (a === b) return true; const x = aRgba(a), y = aRgba(b); if (!x || !y) return false;
      return Math.hypot(x[0] - y[0], x[1] - y[1], x[2] - y[2]) <= 12 && Math.abs(x[3] - y[3]) <= 5; };
    const mismaPintura = (a, b) => PINTURA.every((k) => mismoColor(a[k], b[k]));
    // Dos formas son la misma con el tamaño y el radio a <= 1 px y cada relleno a <= 2 px (6-nov: un 14,5
    // frente a un 15 salia como «dos formas», y medio pixel de cuerpo no se ve); lo demas, igual.
    const cerca = (a, b, tol) => { const x = String(a).split(' ').map(parseFloat), y = String(b).split(' ').map(parseFloat);
      return x.length === y.length && x.every((v, i) => Math.abs(v - y[i]) <= tol); };
    const TOL = { 'tamaño': 1, radio: 1, relleno: 2 };
    const igualForma = (k) => (a, b) => (TOL[k] ? cerca(a, b, TOL[k]) : a === b);
    const mismaForma = (a, b) => FORMA.every((k) => igualForma(k)(a[k], b[k]));
    const distintos = (lista, campos, igual) => campos.filter((k) => lista.some((l) => !igual(k)(l.campos[k], lista[0].campos[k])));
    const muestra = (lista, campos) => lista.slice(0, 3).map((l) => `${campos.map((k) => l.campos[k]).join(' / ')} («${l.texto}», ${l.n})`).join(' · ');

    // Se agrupan: grupo → forma → fondo de detras → pinturas (con su tolerancia).
    const arbol = {};
    for (const b of botones) {
      const g = (arbol[b.grupo] = arbol[b.grupo] || []);
      let f = g.find((x) => mismaForma(x.campos, b.campos));
      if (!f) g.push((f = { campos: b.campos, texto: b.texto, n: 0, una: [], ctx: {} }));
      f.n++; if (b.lineas === 1) f.una.push(b);
      const lista = (f.ctx[b.contexto] = f.ctx[b.contexto] || []);
      const p = lista.find((x) => mismaPintura(x.campos, b.campos));
      if (p) p.n++; else lista.push({ campos: b.campos, texto: b.texto, n: 1 });
    }
    const fallos = [], grupos = [];
    for (const [g, fl] of Object.entries(arbol)) {
      // ── BT1 · un grupo, dos formas ─────────────────────────────────────────
      if (fl.length > 1) { const d = distintos(fl, FORMA, igualForma);
        fallos.push({ regla: 'BT1', clave: g, msg: `BT1 · ${g} con ${fl.length} formas a ${vw} px: cambia ${d.join(', ')} · ${muestra(fl, d)}` }); }
      // ── BT2 · un grupo, sobre el mismo fondo, dos pinturas ─────────────────
      const ctxs = {};
      for (const f of fl) for (const [k, ps] of Object.entries(f.ctx)) for (const p of ps) {
        const l = (ctxs[k] = ctxs[k] || []); const ya = l.find((x) => mismaPintura(x.campos, p.campos));
        if (ya) ya.n += p.n; else l.push({ ...p });
      }
      for (const [k, ps] of Object.entries(ctxs)) if (ps.length > 1) { const d = distintos(ps, PINTURA, () => mismoColor);
        fallos.push({ regla: 'BT2', clave: g + ' ' + k, msg: `BT2 · ${g} sobre fondo ${k} con ${ps.length} pinturas a ${vw} px: cambia ${d.join(', ')} · ${muestra(ps, d)}` }); }
      for (const f of fl) {
        // ── BT3 · misma forma, una linea, otra altura ────────────────────────
        const altos = [...new Set(f.una.map((b) => b.alto))].sort((a, b) => a - b);
        if (altos.length > 1 && altos[altos.length - 1] - altos[0] > 2) {
          const bajo = f.una.find((b) => b.alto === altos[0]), alto = f.una.find((b) => b.alto === altos[altos.length - 1]);
          fallos.push({ regla: 'BT3', clave: g, msg: `BT3 · ${g} en una linea mide ${altos[0]} y ${altos[altos.length - 1]} px a ${vw} px con la misma forma ` +
            `(«${bajo.texto}» y «${alto.texto}»): un margen o un flex lo estira` });
        }
        for (const [k, ps] of Object.entries(f.ctx)) for (const p of ps)
          grupos.push({ grupo: g, forma: FORMA.map((x) => p.campos[x]).join(' | '), contexto: k, campos: p.campos, n: p.n, ej: p.texto, altos });
      }
    }
    return { fallos, grupos };
  };
  // En node (`botones-sitio.js`, el banco) solo se exporta la comparacion; en la pagina, se mide.
  if (typeof module === 'object' && module && typeof window === 'undefined') { module.exports = { compara, FORMA, PINTURA }; return; }

  const CFG = window.__GATE__ || {};
  const vw = innerWidth, vh = innerHeight;
  const fallos = [], avisos = [], notas = [];
  const visible = (e) => { const r = e.getBoundingClientRect(); const s = getComputedStyle(e);
    return r.width >= 2 && r.height >= 2 && r.right > 0 && r.left < vw && s.visibility !== 'hidden' && s.display !== 'none' && +s.opacity > 0.05; };
  const lienzo = document.createElement('canvas'); lienzo.width = lienzo.height = 1;
  const cx = lienzo.getContext('2d', { willReadFrequently: true });
  const rgba = (c) => { if (!c || c === 'transparent') return null; cx.clearRect(0, 0, 1, 1); cx.fillStyle = '#000'; cx.fillStyle = c;
    cx.fillRect(0, 0, 1, 1); const d = cx.getImageData(0, 0, 1, 1).data; return d[3] < 13 ? null : [d[0], d[1], d[2], d[3]]; };
  const hex = (x) => x ? '#' + x.slice(0, 3).map((n) => n.toString(16).padStart(2, '0')).join('') + (x[3] < 250 ? '/' + Math.round(x[3] / 2.55) + '%' : '') : 'transparente';
  const px = (v) => String(Math.round(parseFloat(v) * 2) / 2) + 'px';
  // 🔴 6-nov-2026 · EL AVISO DE COOKIES, POR SU CAJA Y NO POR UNA CLASE CUALQUIERA. Una web
  //  pone `has-consent` en el <body> al aceptar, y `closest('[class*=consent]')` casaba con el
  //  body: 0 botones medidos y un PASA vacio. Un aviso no contiene el <main> ni el <h1>.
  const AVISO_COOKIES = '#cookie-consent,[id*=cookie i],[class*=cookie i],[id*=consent i],[class*=consent i],[aria-label*=cookie i]';
  const fuera = [...document.querySelectorAll(AVISO_COOKIES)].filter((x) => x !== document.body && x !== document.documentElement && !x.querySelector('main,h1'));
  for (const sel of Array.isArray(CFG.ignorar) ? CFG.ignorar : []) { try { fuera.push(...document.querySelectorAll(sel)); } catch (x) { notas.push(`ignorar: selector no valido «${sel}»`); } }
  const familias = CFG.familias && typeof CFG.familias === 'object' ? Object.entries(CFG.familias) : [];
  const claseDe = (e) => (typeof e.className === 'string' ? e.className : '').trim().split(/\s+/).filter(Boolean).sort().join('.');
  const texto = (e) => (e.innerText || e.getAttribute('aria-label') || '').replace(/\s+/g, ' ').trim().slice(0, 50);
  // Lineas de texto: las cajas de texto por su «top», juntando las que caen a menos de 0,8 del cuerpo
  // (un icono alineado al medio no es otra linea).
  const lineas = (e, cuerpo) => { const r = document.createRange(); r.selectNodeContents(e);
    const tops = [...r.getClientRects()].filter((q) => q.width > 1 && q.height > 1).map((q) => q.top).sort((a, b) => a - b);
    let n = 0, ult = -1e9; for (const t of tops) { if (t - ult > cuerpo * 0.8) n++; ult = t; } return n; };
  // El fondo de detras: el primer padre con color opaco (claro u oscuro) o con imagen.
  const fondoDe = (e) => { for (let p = e.parentElement; p; p = p.parentElement) { const s = getComputedStyle(p);
      if (s.backgroundImage && s.backgroundImage !== 'none') return 'imagen';
      const c = rgba(s.backgroundColor); if (c && c[3] > 128) { const [r, g, b] = c.slice(0, 3).map((v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; });
        return 0.2126 * r + 0.7152 * g + 0.0722 * b < 0.18 ? 'oscuro' : 'claro'; } }
    return 'claro'; };

  const botones = [], deNadie = {};
  let sinClase = 0;
  for (const e of document.querySelectorAll('a[href], button')) {
    if (!visible(e) || e.hasAttribute('aria-expanded') || fuera.some((x) => x.contains(e))) continue;
    const s = getComputedStyle(e);
    const imagen = s.backgroundImage && s.backgroundImage !== 'none' ? s.backgroundImage : '';
    const fondo = !!rgba(s.backgroundColor) || /gradient/.test(imagen);
    const borde = parseFloat(s.borderTopWidth) > 0 && s.borderTopStyle !== 'none' && !!rgba(s.borderTopColor);
    const relleno = parseFloat(s.paddingLeft) >= 8 && parseFloat(s.paddingTop) >= 4;
    const cls = claseDe(e);
    if (!(((fondo || borde) && relleno) || /(^|[.\-_])(btn|cta|button)([.\-_]|$)/i.test(cls))) continue;
    const fam = familias.find(([, sel]) => { try { return e.matches(sel); } catch (x) { return false; } });
    if (familias.length && !fam) { const k = cls ? '.' + cls : '<' + e.tagName.toLowerCase() + '> sin clase';
      (deNadie[k] = deNadie[k] || { n: 0, ej: texto(e) }).n++; }
    const grupo = fam ? fam[0] : cls ? '.' + cls : null;
    if (!grupo) { sinClase++; continue; }
    const c = {
      'tamaño': px(s.fontSize), peso: s.fontWeight, tipo: s.fontFamily.split(',')[0].trim().replace(/^["']|["']$/g, '').toLowerCase(),
      mayusculas: s.textTransform === 'none' ? 'no' : s.textTransform, radio: px(s.borderTopLeftRadius),
      borde: borde ? `${px(s.borderTopWidth)} ${s.borderTopStyle}` : 'sin borde',
      relleno: [s.paddingTop, s.paddingRight, s.paddingBottom, s.paddingLeft].map(px).join(' '),
      fondo: /gradient/.test(imagen) ? imagen.replace(/\s+/g, ' ').slice(0, 120) : hex(rgba(s.backgroundColor)),
      texto: hex(rgba(s.color)), 'color del borde': borde ? hex(rgba(s.borderTopColor)) : '—',
    };
    // 6-nov-2026 · un borde del MISMO color que el relleno no se ve: el boton blanco con borde blanco
    //  de una banda oscura y el verde sin borde median lo mismo (44 px) y salian «dos formas».
    const cb = rgba(s.borderTopColor), cf = rgba(s.backgroundColor);
    if (borde && cb && cf && Math.hypot(cb[0] - cf[0], cb[1] - cf[1], cb[2] - cf[2]) <= 12 && Math.abs(cb[3] - cf[3]) <= 13) {
      c.borde = 'sin borde'; c['color del borde'] = '—'; }
    const r = e.getBoundingClientRect();
    botones.push({ grupo, contexto: fondoDe(e), campos: c, alto: Math.round(r.height * 10) / 10,
      lineas: lineas(e, parseFloat(s.fontSize) || 16), texto: texto(e) });
  }
  const { fallos: fc, grupos } = compara(botones, vw);
  for (const f of fc) fallos.push(f.msg);

  // ── BT4 · un boton de ninguna familia ──────────────────────────────────────
  const dn = Object.entries(deNadie);
  if (dn.length) avisos.push(`BT4 · ${dn.length} clase(s) de boton fuera de las familias a ${vw} px: ` +
    dn.slice(0, 5).map(([k, v]) => `${k} (${v.n}, «${v.ej}»)`).join(' · '));
  if (!botones.length) notas.push(`BT1-BT3 · NO MEDIDO: ningun boton con grupo a ${vw} px${sinClase ? ` (${sinClase} sin clase)` : ''}`);
  if (sinClase) notas.push(`${sinClase} boton(es) sin clase: no se comparan (sin grupo no se sabe que deberian parecerse)`);
  if (!familias.length) notas.push('BT4 · NO MEDIDO: sin `familias` en la configuracion, no se sabe que boton es «propio»');
  if (vw !== CFG.anchoPedido) notas.push(`MEDIDO A ${vw} px cuando se pidieron ${CFG.anchoPedido}. Una medida que no coincide con lo PEDIDO no es un resultado.`);

  return JSON.stringify({
    url: location.href, innerWidth: vw, innerHeight: vh, coincide: vw === CFG.anchoPedido,
    VEREDICTO: fallos.length ? 'FALLA' : 'PASA',
    fallos, avisos, notas,
    // `lista`: cada boton medido, para que `botones-sitio.js` compare paginas con la MISMA regla.
    datos: { botones: botones.length, sinClase, grupos, lista: botones },
  }, null, 1);
})()
