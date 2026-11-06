// =============================================================================
//  GATE DE HUELLAS  ·  ¿lleva la pagina las huellas de una pagina hecha en serie?
//  7-nov-2026 · se corre con run-gate.js, a 1366x768 y a 390x844
// =============================================================================
//
//  🔴 POR QUE EXISTE. Hay recursos que salen en cualquier pagina generada, sea del
//  sector que sea, y juntos dicen «plantilla» antes de que se lea nada. Una revision
//  de diseno del 6-nov los busco con un detector externo en 10 webs (5 paginas cada
//  una) y salieron en casi todas: 57 antetitulos encima de un h2, 19 botones con
//  halo de color, 6 cajas redondeadas con un borde grueso en un solo lado, 12
//  titulos que acaban con una palabra sola. Ningun gate de la puerta los veia: miran
//  si algo se rompe, no si la pagina parece de nadie. Y dos de lectura y uno de
//  formulario que tampoco media nadie.
//
//  QUE COMPRUEBA (estilos calculados de lo servido, nunca una captura)
//    HU1  ANTETITULO EN MAYUSCULAS ESPACIADAS ENCIMA DE CADA TITULO. El elemento
//         justo antes de un h2, corto (hasta 8 palabras), en mayusculas y con
//         letter-spacing de 0,04em o mas, mas pequeno que el titulo y pegado a el
//         (menos de 40 px). FALLA con 3 o mas y en la mitad o mas de los h2 de la
//         pagina («encima de cada titulo de seccion»); AVISO con 2. El de encima del
//         H1 NO cuenta: el que lleva la marca o la categoria es un dato, no un adorno.
//         El de encima de un h3 tampoco: en una tarjeta es una etiqueta («MIT»,
//         «Nuevo»); se cuenta en las notas. Secciones en h3 sin h2 es A11Y-08.
//    HU2  TEXTO EN DEGRADADO. background-clip: text con un degradado detras. FALLA.
//    HU3  BORDE GRUESO EN UN SOLO LADO DE UNA CAJA REDONDEADA. Un lado de 2 px o
//         mas, los otros tres de la mitad o menos, y una esquina de 4 px o mas.
//         FALLA. Una cita con su borde a la izquierda y sin radio no es esto: pasa.
//    HU4  HALO DE COLOR. Una sombra (no inset) con color de verdad (no gris ni
//         negro) y un difuminado de 8 px o mas. FALLA. Una sombra gris, pasa.
//    HU5  transition: all CON DURACION. Anima lo que no se queria animar y cuesta
//         en cada cambio. AVISO, con cuantos elementos.
//    HU6  INTERLINEADO POR DEBAJO DE 1,3 en texto corrido de dos lineas o mas (p,
//         li, dd, blockquote, figcaption de 60 caracteres o mas). Con line-height
//         «normal» se mide la distancia real entre lineas. FALLA.
//    HU7  TITULO QUE ACABA CON UNA PALABRA SOLA. Un h1, h2 o h3 de dos lineas o
//         mas, sin text-wrap: balance ni pretty, cuya ultima linea mide menos del
//         35 % de la anterior. AVISO, con cuantos: depende del ancho y del texto.
//    HU8  EL TELEFONO CON MASCARA. En cada campo de telefono se escribe un numero
//         internacional valido (+34 600 12 34 56) con un evento input, sin foco ni
//         envio, y se deja como estaba. Si el campo lo rechaza (un pattern que no lo
//         acepta, un maxlength corto) o se come cifras, FALLA: quien lo escribe a
//         su manera no puede mandarlo. Si solo lo reescribe (otros espacios,
//         parentesis) o tiene atributos o placeholder de mascara, AVISO.
//
//  LO QUE NO MIDE, dicho en cada corrida: hover y foco (una sombra que sale al
//  pasar el raton), las imagenes (el velo de color sobre una foto, el degradado
//  sobre la foto), los numeros de seccion 01/02/03, las tarjetas iguales, la palabra
//  del titular en otro color, las flechas «→» y los datos unidos con «·». Lo que
//  esta en un iframe o en shadow DOM. El salto de nivel de titulo es A11Y-08 de
//  qa-master, las lineas de mas de 80 caracteres son el CPL, el placeholder como
//  etiqueta es forms-gate y el zoom bloqueado es audit.sh: una regla, una copia.
//  No mira si la aparicion al bajar se dispara (eso es visible-gate): por eso lo
//  que esta en opacity 0 tambien cuenta, porque el CSS es el mismo.
//
//  CONFIGURACION (window.__GATE__, por run-gate.js):
//    { "ignorar": ["#chat-widget", …], "telPrueba": "+34 600 12 34 56" }
// =============================================================================
(async () => {
  const CFG = Object.assign({
    anchoPedido: null,
    ignorar: [],
    antetituloMin: 3, antetituloParte: 0.5, antetituloPegado: 40,
    trackingMin: 0.04,
    interlineadoMin: 1.3,
    colaMax: 0.35,
    halo: 8,
    telPrueba: '+34 600 12 34 56'
  }, (typeof window !== 'undefined' && window.__GATE__) || {});

  try { if (document.fonts && document.fonts.ready) await document.fonts.ready; } catch (e) { /* sin fuentes que esperar */ }
  const vw = innerWidth, vh = innerHeight;
  const fallos = [], avisos = [], notas = [], resumen = {};
  const sel = el => {
    if (!el || !el.tagName) return '?';
    let s = el.tagName.toLowerCase();
    if (el.id) return `${s}#${el.id}`;
    const cl = [...el.classList].slice(0, 2);
    return cl.length ? `${s}.${cl.join('.')}` : s;
  };
  const texto = el => ((el && (el.innerText || el.textContent)) || '').replace(/\s+/g, ' ').trim();
  const corto = s => s.length > 40 ? s.slice(0, 40) + '…' : s;
  const ejemplos = els => els.slice(0, 4).map(x => x.ej).join(' · ') + (els.length > 4 ? ` y ${els.length - 4} mas` : '');

  // Lo que no es de la pagina: el aviso de cookies (por sus antecesores, SIN llegar a <body>:
  // un body con `has-consent` es el estado, no el aviso), lo oculto a proposito y lo de `ignorar`.
  const RE_COOKIES = /cookie|consent|gdpr|cmp|onetrust|cookiebot|tarteaucitron|didomi|iubenda|klaro/i;
  const esAviso = el => {
    for (let e = el; e && e !== document.body && e !== document.documentElement; e = e.parentElement)
      if (RE_COOKIES.test(`${e.id || ''} ${typeof e.className === 'string' ? e.className : ''} ${e.getAttribute('aria-label') || ''}`)) return true;
    return false;
  };
  const fuera = el => {
    if (!el.isConnected) return true;
    if (el.closest('[aria-hidden="true"],[hidden],[inert],template,noscript,dialog:not([open])')) return true;
    if (CFG.ignorar.some(s => { try { return el.closest(s); } catch (e) { return false; } })) return true;
    return esAviso(el);
  };
  // Tiene caja: no display:none ni visibility hidden. La opacidad NO se mira (ver la cabecera).
  const conCaja = el => {
    const r = el.getBoundingClientRect();
    if (r.width < 1 || r.height < 1) return false;
    return getComputedStyle(el).visibility !== 'hidden';
  };

  // Los colores, pintados en un lienzo: vale oklch, lab, color() o un nombre.
  const lienzo = document.createElement('canvas'); lienzo.width = lienzo.height = 1;
  const ctx = lienzo.getContext('2d', { willReadFrequently: true });
  const rgba = c => {
    try {
      ctx.clearRect(0, 0, 1, 1); ctx.fillStyle = 'rgba(0,0,0,0)'; ctx.fillStyle = c; ctx.fillRect(0, 0, 1, 1);
      const d = ctx.getImageData(0, 0, 1, 1).data; return { r: d[0], g: d[1], b: d[2], a: d[3] / 255 };
    } catch (e) { return null; }
  };
  const croma = c => c ? (Math.max(c.r, c.g, c.b) - Math.min(c.r, c.g, c.b)) / 255 : 0;
  // Parte una lista de CSS por comas de primer nivel (no las de dentro de rgb(…)).
  const partes = v => { const out = []; let n = 0, cur = ''; for (const ch of v) { if (ch === '(') n++; if (ch === ')') n--; if (ch === ',' && !n) { out.push(cur.trim()); cur = ''; } else cur += ch; } if (cur.trim()) out.push(cur.trim()); return out; };

  // Las lineas de un elemento: los rectangulos de su texto, juntados por altura.
  const lineas = el => {
    const rg = document.createRange(); rg.selectNodeContents(el);
    const rs = [...rg.getClientRects()].filter(r => r.width > 0.5 && r.height > 0.5).sort((a, b) => a.top - b.top || a.left - b.left);
    const L = [];
    for (const r of rs) {
      const u = L[L.length - 1];
      if (u && r.top < u.bottom - Math.min(u.bottom - u.top, r.height) / 2) { u.left = Math.min(u.left, r.left); u.right = Math.max(u.right, r.right); u.bottom = Math.max(u.bottom, r.bottom); }
      else L.push({ top: r.top, bottom: r.bottom, left: r.left, right: r.right });
    }
    return L;
  };

  const todos = [...document.body.querySelectorAll('*')].filter(el => !fuera(el));

  // ── HU1 · el antetitulo ────────────────────────────────────────────────────
  // La proporcion se cuenta sobre los h2: la primera version la contaba sobre h2 y h3 juntos y los h3 de
  // las tarjetas la diluian (una portada con 9 antetitulos en sus 9 secciones salia «9 de 28» y pasaba),
  // mientras la etiqueta de una tarjeta («MIT», «Nuevo», el estado de una ficha) la hacia fallar sin ser
  // un adorno. Lo de encima de un h3 se cuenta aparte y va a las notas (censo del 7-nov, 50 paginas).
  const titulos = [...document.querySelectorAll('h2,h3')].filter(h => !fuera(h) && conCaja(h) && texto(h));
  const antetitulos = [], deTarjeta = [];
  for (const h of titulos) {
    const k = h.previousElementSibling;
    if (!k || /^(H[1-6]|IMG|SVG|PICTURE|FIGURE|UL|OL|TABLE|FORM)$/i.test(k.tagName) || !conCaja(k)) continue;
    const t = texto(k); const palabras = t.split(/\s+/).filter(Boolean).length;
    if (!t || t.length > 70 || palabras > 8 || !/\p{L}/u.test(t)) continue;
    const sk = getComputedStyle(k), sh = getComputedStyle(h);
    const fk = parseFloat(sk.fontSize), fh = parseFloat(sh.fontSize);
    const mayus = sk.textTransform === 'uppercase' || (t === t.toUpperCase() && (t.match(/\p{L}/gu) || []).length >= 3);
    const tracking = sk.letterSpacing === 'normal' ? 0 : parseFloat(sk.letterSpacing) / fk;
    const hueco = h.getBoundingClientRect().top - k.getBoundingClientRect().bottom;
    if (mayus && tracking >= CFG.trackingMin - 1e-6 && fk < fh * 0.8 && hueco < CFG.antetituloPegado)
      (h.tagName === 'H2' ? antetitulos : deTarjeta).push({ ej: `${sel(k)} «${corto(t)}» encima de ${h.tagName.toLowerCase()} «${corto(texto(h))}»` });
  }
  const secciones = titulos.filter(h => h.tagName === 'H2').length, h3s = titulos.length - secciones;
  const parte = secciones ? antetitulos.length / secciones : 0;
  resumen.HU1 = { titulos: secciones, conAntetitulo: antetitulos.length, parte: +parte.toFixed(2), h3: h3s, h3ConAntetitulo: deTarjeta.length };
  if (antetitulos.length >= CFG.antetituloMin && parte >= CFG.antetituloParte)
    fallos.push(`HU1 · ${antetitulos.length} de ${secciones} titulos de seccion (h2) llevan encima un antetitulo en mayusculas espaciadas: ${ejemplos(antetitulos)}. ` +
      'Si no dice nada que el titulo no diga, se quita; si lleva un dato, que no vaya en todos');
  else if (antetitulos.length >= 2)
    avisos.push(`HU1 · ${antetitulos.length} de ${secciones} titulos de seccion (h2) con antetitulo en mayusculas espaciadas: ${ejemplos(antetitulos)}`);
  if (deTarjeta.length)
    notas.push(`Antetitulos encima de un h3: ${deTarjeta.length} de ${h3s}. No cuentan para HU1: en una tarjeta suelen ser una etiqueta con un dato («MIT», «Nuevo», el estado de una ficha): ${ejemplos(deTarjeta)}`);

  // ── HU2 a HU5 · lo que se lee en el estilo de cada elemento ────────────────
  const degradados = [], lados = [], halos = [], transiciones = [];
  const LADOS = ['Top', 'Right', 'Bottom', 'Left'], NOMBRE = { Top: 'arriba', Right: 'a la derecha', Bottom: 'abajo', Left: 'a la izquierda' };
  const radio = v => { const n = parseFloat(v); return isNaN(n) ? 0 : /%/.test(v) ? 99 : n; };
  for (const el of todos) {
    const s = getComputedStyle(el);
    if (s.display === 'none') continue;
    // HU2
    const clip = `${s.backgroundClip} ${s.getPropertyValue('-webkit-background-clip')}`;
    if (/\btext\b/.test(clip) && /gradient/i.test(s.backgroundImage) && texto(el) && conCaja(el))
      degradados.push({ ej: `${sel(el)} «${corto(texto(el))}»` });
    // HU3
    if (!/^(INPUT|SELECT|TEXTAREA|BUTTON|HR|IMG|SVG|TD|TH|TR|TABLE|VIDEO|IFRAME)$/i.test(el.tagName) &&
        !el.closest('header,nav,[role="tablist"],[role="tab"],[aria-current]')) {
      const w = LADOS.map(l => s[`border${l}Style`] === 'none' || s[`border${l}Style`] === 'hidden' ? 0 : parseFloat(s[`border${l}Width`]) || 0);
      const max = Math.max(...w);
      if (max >= 2 && w.filter(x => x === max).length === 1 && w.every(x => x === max || x <= max / 2)) {
        const lado = LADOS[w.indexOf(max)];
        const c = rgba(s[`border${lado}Color`]);
        const rad = Math.max(radio(s.borderTopLeftRadius), radio(s.borderTopRightRadius), radio(s.borderBottomLeftRadius), radio(s.borderBottomRightRadius));
        const r = el.getBoundingClientRect();
        if (c && c.a >= 0.3 && rad >= 4 && r.width >= 40 && r.height >= 24)
          lados.push({ ej: `${sel(el)} (${max} px ${NOMBRE[lado]}, radio ${Math.round(rad)} px)` });
      }
    }
    // HU4
    if (s.boxShadow && s.boxShadow !== 'none') {
      // Calculada, Chrome la da como «<color> <x>px <y>px <difuminado>px <extension>px»: los colores
      // (rgb, oklch, color()) no llevan px, asi que las medidas son los px y el color es el resto.
      for (const sombra of partes(s.boxShadow)) {
        if (/\binset\b/.test(sombra)) continue;
        const nums = sombra.match(/-?[\d.]+px/g) || [];
        const color = sombra.replace(/-?[\d.]+px/g, '').replace(/\binset\b/, '').trim();
        const [x = 0, y = 0, blur = 0] = nums.map(parseFloat);
        const c = color && rgba(color);
        if (c && c.a >= 0.2 && croma(c) >= 0.25 && blur >= CFG.halo && Math.abs(x) <= blur && Math.abs(y) <= blur && conCaja(el)) {
          halos.push({ ej: `${sel(el)} (${color.replace(/\s+/g, ' ')}, ${Math.round(blur)} px)` }); break;
        }
      }
    }
    // HU5
    const props = partes(s.transitionProperty || ''), durs = partes(s.transitionDuration || '').map(d => parseFloat(d) * (/ms/.test(d) ? 1 : 1000));
    if (props.some((p, i) => p === 'all' && (durs[i % (durs.length || 1)] || 0) > 0)) transiciones.push({ ej: sel(el) });
  }
  resumen.HU2 = { degradados: degradados.length };
  resumen.HU3 = { bordesDeUnLado: lados.length };
  resumen.HU4 = { halos: halos.length };
  resumen.HU5 = { transitionAll: transiciones.length };
  if (degradados.length) fallos.push(`HU2 · ${degradados.length} texto(s) en degradado (background-clip: text): ${ejemplos(degradados)}. Un color plano, el de la marca`);
  if (lados.length) fallos.push(`HU3 · ${lados.length} caja(s) redondeada(s) con un borde grueso en un solo lado: ${ejemplos(lados)}. ` +
    'Si la caja tiene que destacar, con su fondo o su titulo; el borde de un lado, sin radio, solo en una cita');
  if (halos.length) fallos.push(`HU4 · ${halos.length} elemento(s) con un halo de color (sombra con color y difuminado de ${CFG.halo} px o mas): ${ejemplos(halos)}. ` +
    'La sombra, gris y corta, o ninguna');
  if (transiciones.length) {
    const grupos = [...new Set(transiciones.map(t => t.ej))];
    avisos.push(`HU5 · ${transiciones.length} elemento(s) con transition: all: ${grupos.slice(0, 5).join(', ')}${grupos.length > 5 ? ` y ${grupos.length - 5} mas` : ''}. Se nombra lo que se anima (color, transform)`);
  }

  // ── HU6 · el interlineado del texto corrido ────────────────────────────────
  const apretados = [];
  for (const el of document.body.querySelectorAll('p,li,dd,blockquote,figcaption')) {
    if (fuera(el) || !conCaja(el) || el.closest('button,nav,header,a.btn,[role="button"]')) continue;
    const t = texto(el); if (t.length < 60) continue;
    // Solo el texto propio: un <li> con un <p> dentro lo mide su <p>.
    if (el.querySelector('p,li,dd,blockquote')) continue;
    const s = getComputedStyle(el), fsz = parseFloat(s.fontSize);
    const L = lineas(el); if (L.length < 2) continue;
    let lh = s.lineHeight === 'normal' ? null : parseFloat(s.lineHeight);
    if (!lh) { const pasos = L.slice(1).map((l, i) => l.top - L[i].top).sort((a, b) => a - b); lh = pasos[Math.floor(pasos.length / 2)]; }
    const ratio = lh / fsz;
    if (ratio < CFG.interlineadoMin - 0.005) apretados.push({ ej: `${sel(el)} (${ratio.toFixed(2)}, ${Math.round(fsz)} px${s.lineHeight === 'normal' ? ', «normal»' : ''})` });
  }
  resumen.HU6 = { parrafosApretados: apretados.length };
  if (apretados.length) fallos.push(`HU6 · ${apretados.length} bloque(s) de texto corrido con el interlineado por debajo de ${CFG.interlineadoMin}: ${ejemplos(apretados)}. line-height: 1.5 en el cuerpo`);

  // ── HU7 · el titulo que acaba con una palabra sola ─────────────────────────
  const colas = [];
  let titulosLargos = 0;
  for (const h of document.querySelectorAll('h1,h2,h3')) {
    if (fuera(h) || !conCaja(h)) continue;
    const s = getComputedStyle(h);
    const wrap = `${s.getPropertyValue('text-wrap')} ${s.getPropertyValue('text-wrap-style')}`;
    const L = lineas(h); if (L.length < 2) continue;
    titulosLargos++;
    // Partido a mano (<br>): el corte lo eligio quien lo escribio.
    if (/balance|pretty/.test(wrap) || h.querySelector('br')) continue;
    const ult = L[L.length - 1], ant = L[L.length - 2];
    const p = (ult.right - ult.left) / Math.max(1, ant.right - ant.left);
    if (p < CFG.colaMax) colas.push({ ej: `${h.tagName.toLowerCase()} «${corto(texto(h))}» (la ultima linea, ${Math.round(p * 100)} % de la anterior)` });
  }
  resumen.HU7 = { titulosDeVariasLineas: titulosLargos, conPalabraSola: colas.length };
  if (colas.length) avisos.push(`HU7 · ${colas.length} titulo(s) acaban con una palabra sola o casi: ${ejemplos(colas)}. text-wrap: balance en h1, h2 y h3`);

  // ── HU8 · el telefono con mascara ──────────────────────────────────────────
  const RE_TEL = /(^|[^a-z])(tel|phone|fono|movil|móvil|mobile|celular|whatsapp|gsm|portable)/i;
  const campos = [...document.querySelectorAll('input')].filter(i => !fuera(i) && !i.disabled && !i.readOnly &&
    (i.type === 'tel' || ((i.type === 'text' || !i.getAttribute('type')) && (RE_TEL.test(`${i.name} ${i.id} ${i.getAttribute('autocomplete') || ''} ${i.getAttribute('aria-label') || ''}`)))));
  const rechazos = [], reescritos = [];
  const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
  const digitos = v => (v.match(/\d/g) || []).join('');
  for (const i of campos) {
    const nombre = `${sel(i)}${i.name ? `[name=${i.name}]` : ''}`;
    const motivos = [];
    // maxlength no se aplica a un valor puesto por script (solo a lo tecleado): se lee del atributo.
    const max = +i.getAttribute('maxlength');
    if (max > 0 && max < CFG.telPrueba.length) motivos.push(`maxlength ${max}, y ${CFG.telPrueba} tiene ${CFG.telPrueba.length}`);
    const antes = i.value;
    let despues = null;
    try {
      setter.call(i, CFG.telPrueba);
      // El pattern lo juzga el navegador, como al enviar (un pattern que no compila lo ignora el y aqui tambien).
      if (i.getAttribute('pattern') && i.validity.patternMismatch) motivos.push(`su pattern «${corto(i.getAttribute('pattern'))}» no acepta ${CFG.telPrueba}`);
      i.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'insertText', data: CFG.telPrueba }));
      await new Promise(r => setTimeout(r, 80));
      despues = i.value;
    } catch (e) { notas.push(`HU8 · ${nombre}: no se pudo escribir (${e.message})`); }
    try { setter.call(i, antes); i.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'deleteContent' })); } catch (e) { /* se deja */ }
    if (despues !== null && digitos(despues).length < digitos(CFG.telPrueba).length) motivos.push(`se come cifras: «${CFG.telPrueba}» queda «${despues}»`);
    if (motivos.length) { rechazos.push({ ej: `${nombre}: ${motivos.join('; ')}` }); continue; }
    const marcas = [...i.attributes].map(a => a.name).filter(n => /^(data-(input)?mask|data-mask-|x-mask|v-mask|data-format|mask)/i.test(n));
    const ph = i.getAttribute('placeholder') || '';
    if (despues !== null && despues !== CFG.telPrueba) reescritos.push({ ej: `${nombre}: «${CFG.telPrueba}» queda «${despues}»` });
    else if (marcas.length || /[_#X]{3,}|\(\d{3}\)|\b0{3}\b/.test(ph)) reescritos.push({ ej: `${nombre}: ${marcas.length ? `atributo ${marcas[0]}` : `placeholder de mascara «${corto(ph)}»`}` });
  }
  resumen.HU8 = { camposDeTelefono: campos.length, rechazan: rechazos.length, reescriben: reescritos.length };
  if (rechazos.length) fallos.push(`HU8 · ${rechazos.length} campo(s) de telefono no dejan escribir un numero valido a su manera: ${ejemplos(rechazos)}. ` +
    'Se acepta cualquier formato (espacios, +, guiones) y se limpia al recibirlo');
  if (reescritos.length) avisos.push(`HU8 · ${reescritos.length} campo(s) de telefono con mascara o que reescriben lo escrito: ${ejemplos(reescritos)}`);

  if (CFG.anchoPedido && vw !== CFG.anchoPedido)
    notas.push(`MEDIDO A ${vw} px cuando se pidieron ${CFG.anchoPedido}. Una medida que no coincide con lo PEDIDO no es un resultado.`);
  notas.push('HU1-HU8 · estilos calculados en reposo. NO mide hover ni foco, las imagenes (el velo de color, el degradado sobre la foto), ' +
    'los numeros de seccion, las tarjetas iguales, la palabra del titular en otro color, las flechas ni los datos unidos con «·»; ' +
    'ni lo que esta en un iframe o en shadow DOM.');

  return JSON.stringify({
    url: location.href, innerWidth: vw, innerHeight: vh,
    coincide: CFG.anchoPedido ? vw === CFG.anchoPedido : null,
    VEREDICTO: fallos.length ? 'FALLA' : 'PASA',
    fallos, avisos, notas, resumen
  }, null, 1);
})()
