/* =============================================================================
 *  measure-layout.js — la sonda: anchos reales, contraste medido y CPL
 * =============================================================================
 *  Se inyecta al final de la pagina y deja el resultado en un <pre id="__M">.
 *  Lo lanza `measure-layout.sh` con Chrome headless local.
 *
 *  ⚠️ `innerWidth` va EL PRIMERO a proposito. Chrome headless en Windows clampa
 *     `--window-size` a ~500px y descuenta la barra de scroll: si el numero no es
 *     el que se pidio, la medicion entera se tira. Ha costado dos diagnosticos.
 *
 *  ⚠️ El contraste NO se lee de una captura. Se calcula: color efectivo del texto
 *     (con la opacidad heredada ya aplicada) contra el primer fondo opaco que
 *     haya por encima, y ratio WCAG 2.1 con luminancia relativa.
 * ========================================================================== */
(function () {
  var R = { innerWidth: window.innerWidth, clientWidth: document.documentElement.clientWidth,
            dpr: window.devicePixelRatio };

  /* ── color ─────────────────────────────────────────────────────────────── */
  var probe = document.createElement("canvas");
  probe.width = probe.height = 1;
  var pctx = probe.getContext("2d", { willReadFrequently: true });

  function parseColor(s) {
    if (!s) return null;
    var m = s.match(/^rgba?\(\s*([\d.]+)[\s,]+([\d.]+)[\s,]+([\d.]+)(?:[\s,/]+([\d.%]+))?\s*\)$/i);
    if (m) {
      var a = m[4] === undefined ? 1 : (/%$/.test(m[4]) ? parseFloat(m[4]) / 100 : parseFloat(m[4]));
      return [+m[1], +m[2], +m[3], a];
    }
    if (s === "transparent") return [0, 0, 0, 0];
    // color() / oklab() / lab(): que lo resuelva el motor pintando 1 pixel.
    try {
      pctx.clearRect(0, 0, 1, 1); pctx.fillStyle = "#000"; pctx.fillRect(0, 0, 1, 1);
      pctx.fillStyle = s; pctx.fillRect(0, 0, 1, 1);
      var d = pctx.getImageData(0, 0, 1, 1).data;
      return [d[0], d[1], d[2], d[3] / 255];
    } catch (e) { return null; }
  }
  function over(fg, bg) {                       // composicion en sRGB, como el compositor
    var a = fg[3];
    return [fg[0] * a + bg[0] * (1 - a), fg[1] * a + bg[1] * (1 - a), fg[2] * a + bg[2] * (1 - a), 1];
  }
  function lin(c) { c /= 255; return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); }
  function lum(c) { return 0.2126 * lin(c[0]) + 0.7152 * lin(c[1]) + 0.0722 * lin(c[2]); }
  function ratio(a, b) { var x = lum(a), y = lum(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); }
  function hex(c) { return "#" + [0,1,2].map(function (i) { return ("0" + Math.round(c[i]).toString(16)).slice(-2); }).join(""); }

  function fondoDe(el) {                        // primer fondo opaco hacia arriba
    var acc = [0, 0, 0, 0], n = el, img = false;
    while (n && n.nodeType === 1) {
      var cs = getComputedStyle(n);
      if (cs.backgroundImage && cs.backgroundImage !== "none") img = true;
      var c = parseColor(cs.backgroundColor);
      if (c && c[3] > 0) {
        acc = acc[3] === 0 ? c : over(acc, c);
        if (acc[3] >= 0.999) return { c: acc, img: img };
      }
      n = n.parentElement;
    }
    return { c: acc[3] > 0 ? over(acc, [255, 255, 255, 1]) : [255, 255, 255, 1], img: img };
  }
  function opacidadHeredada(el) {
    var o = 1, n = el;
    while (n && n.nodeType === 1) { o *= parseFloat(getComputedStyle(n).opacity || 1); n = n.parentElement; }
    return o;
  }

  /* ── 1 · secciones y anchos reales ─────────────────────────────────────── */
  R.secciones = [].map.call(document.querySelectorAll("section, header, footer > *"), function (s, i) {
    // `.sec__in` es el contenedor canonico. El fallback a cualquier `*__in` sirve
    // para medir paginas VIEJAS (que usaban .hero__in / .banda__in / .cierre__in)
    // con el mismo instrumento: comparar antes y despues con reglas distintas no
    // es comparar.
    var inn = s.querySelector(".sec__in") || s.querySelector('[class*="__in"]');
    var r = s.getBoundingClientRect();
    return {
      i: i,
      dataSec: s.getAttribute("data-sec") || "(sin data-sec)",
      clase: (s.className || "").trim(),
      anchoSeccion: Math.round(r.width * 10) / 10,
      claseIn: inn ? (inn.className || "").trim() : null,
      anchoIn: inn ? Math.round(inn.getBoundingClientRect().width * 10) / 10 : null
    };
  });

  /* ── 2 · desborde horizontal ───────────────────────────────────────────── */
  var lim = document.documentElement.clientWidth;
  R.desborde = [];
  [].forEach.call(document.querySelectorAll("body *"), function (el) {
    var r = el.getBoundingClientRect();
    if (r.width === 0 && r.height === 0) return;
    if (r.right > lim + 1 || r.left < -1) {
      var p = el.parentElement, sc = false;
      while (p) { var o = getComputedStyle(p).overflowX; if (o === "auto" || o === "scroll" || o === "hidden") { sc = true; break; } p = p.parentElement; }
      if (!sc) R.desborde.push({ sel: el.tagName.toLowerCase() + "." + (el.className || "").split(/\s+/)[0],
                                 izq: Math.round(r.left), der: Math.round(r.right) });
    }
  });

  /* ── 3 · contraste, elemento a elemento ────────────────────────────────── */
  var vistos = [];
  [].forEach.call(document.querySelectorAll("body *"), function (el) {
    var texto = "";
    for (var k = 0; k < el.childNodes.length; k++)
      if (el.childNodes[k].nodeType === 3) texto += el.childNodes[k].nodeValue;
    texto = texto.replace(/\s+/g, " ").trim();
    if (!texto) return;
    var cs = getComputedStyle(el);
    if (cs.visibility === "hidden" || cs.display === "none") return;
    var r = el.getBoundingClientRect();
    if (r.width === 0 || r.height === 0) return;

    var bg = fondoDe(el);
    var fg = parseColor(cs.color); if (!fg) return;
    var op = opacidadHeredada(el);
    fg = [fg[0], fg[1], fg[2], (fg[3] === undefined ? 1 : fg[3]) * op];
    var fgc = over(fg, bg.c);

    var fs = parseFloat(cs.fontSize);
    var fw = parseInt(cs.fontWeight, 10) || 400;
    var grande = fs >= 24 || (fs >= 18.66 && fw >= 700);
    var min = grande ? 3 : 4.5;
    var rt = ratio(fgc, bg.c);

    vistos.push({
      sel: el.tagName.toLowerCase() + (el.className ? "." + String(el.className).trim().split(/\s+/).join(".") : ""),
      texto: texto.slice(0, 34),
      color: hex(fgc), fondo: hex(bg.c),
      px: Math.round(fs * 10) / 10, peso: fw, grande: grande,
      minimo: min, ratio: Math.round(rt * 100) / 100,
      pasa: rt >= min - 0.0001,
      fondoConImagen: bg.img
    });
  });
  vistos.sort(function (a, b) { return (a.ratio - a.minimo) - (b.ratio - b.minimo); });
  R.contraste = { medidos: vistos.length, fallan: vistos.filter(function (v) { return !v.pasa; }).length,
                  peor: vistos.slice(0, 4) };

  /* ── 4 · caracteres por linea (aprox. calibrada por canvas) ────────────── */
  var cctx = document.createElement("canvas").getContext("2d");
  var cpl = [];
  [].forEach.call(document.querySelectorAll("p, li, dd, dt, blockquote, figcaption"), function (el) {
    // Un <li> que contiene <h3> + <p> NO es un bloque de texto: es un contenedor,
    // y medir su textContent entero da un CPL inventado (me dio 92 en el molde 17
    // sumando titulo, fecha y parrafo de tres lineas distintas).
    if (el.querySelector("p,li,h1,h2,h3,h4,h5,h6,dl,dt,dd,blockquote,figcaption,ul,ol,table,div")) return;
    var t = (el.textContent || "").replace(/\s+/g, " ").trim();
    if (t.length < 40) return;
    var cs = getComputedStyle(el);
    cctx.font = cs.fontStyle + " " + cs.fontWeight + " " + cs.fontSize + " " + cs.fontFamily;
    var w = cctx.measureText(t).width;
    if (!w) return;
    var anchoChar = w / t.length;
    var caja = el.getBoundingClientRect().width
             - parseFloat(cs.paddingLeft) - parseFloat(cs.paddingRight);
    // DOS numeros, y hacen falta los dos:
    //  cplCaja  = cuantos caracteres CABEN en el ancho del bloque. Es lo que mide
    //             si el contenedor esta bien acotado, aunque hoy lleve poco texto.
    //  cplReal  = lo que un lector ve de verdad. Si el texto no llega a llenar la
    //             caja, la linea mas larga es el texto entero, no la caja.
    // Ordenar solo por cplCaja acusa pies de foto de 50 caracteres metidos en una
    // caja ancha (me dio 173 en uno que se lee en una linea).
    var caben = Math.round(caja / anchoChar);
    cpl.push({ sel: el.tagName.toLowerCase() + (el.className ? "." + String(el.className).trim().split(/\s+/)[0] : ""),
               px: Math.round(caja), cplCaja: caben, cplReal: Math.min(caben, t.length) });
  });
  cpl.sort(function (a, b) { return b.cplReal - a.cplReal || b.cplCaja - a.cplCaja; });
  R.cpl = { medidos: cpl.length,
            maxReal: cpl.length ? cpl[0].cplReal : 0,
            maxCaja: cpl.reduce(function (m, x) { return Math.max(m, x.cplCaja); }, 0),
            peores: cpl.slice(0, 3) };

  return JSON.stringify(R);
})()
