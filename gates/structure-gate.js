/* =============================================================================
 *  structure-gate.js — GATE de MAQUETA: caza la pagina-prosa antes de desplegar
 * =============================================================================
 *  Se pega en la consola del navegador, o se ejecuta con el javascript_tool del
 *  panel. Devuelve VEREDICTO: PASA o FALLA. Hermano de `measure-screens.js`
 *  (densidad y CTAs) y del gate de CPL de `11-medidas.md §7`. NO los sustituye:
 *  aquel mide CUANTO ocupa, este mide SI ESTA MAQUETADO.
 *
 *  POR QUE EXISTE
 *  --------------
 *  Manuel, 10-ago-2026: «no sabes que secciones tiene que tener cada tipo de
 *  pagina, incluso cuando las disenas muchas veces LO HACES EN TEXTO PLANO COMO
 *  SI FUERA UN ARTICULO DE BLOG».
 *
 *  Medido antes de escribir nada (censo de 35 paginas de climentmedia.com):
 *    · 33 de 35 paginas sin ni un <section>/<article>          (94,3 %)
 *    · longitud de linea mediana 109 caracteres                (rango legible 45-90)
 *    · 34 de 35 paginas fuera de ese rango
 *    · % del texto en <p> sueltos: 0,692 nuestro vs 0,303 en molde ajeno
 *
 *  Y EL PUNTO CIEGO QUE ESTE GATE TAPA (09-tipos-de-pagina.md §6.3):
 *  `measure-screens.js` mide los hijos DIRECTOS de <main>. En una pagina-prosa
 *  cada <p> es un hijo directo, asi que ningun «bloque» supera nunca una
 *  pantalla: una guia de 36 parrafos reporta «0 bloques desbordan» y PASA.
 *  El fallo mas grave era tambien el mas invisible para el gate que ya habia.
 *
 *  COMO SE USA
 *  -----------
 *    window.__GATE__ = { tipo:'guia' };   // opcional; si no, se infiere de la URL
 *    <pegar este fichero>
 *
 *  Parametros (todos opcionales), en `window.__GATE__`:
 *    tipo       home|servicio|ciudad|producto|hub|guia|comparativa|precios|
 *               contacto|gracias|legal|404      (si falta, se infiere de la ruta)
 *    ruta       ruta a usar para inferir el tipo (para medir una copia local)
 *    origen     origen a considerar «interno» (para medir una copia local)
 *    ecommerce  true  -> el hero puede navegar al catalogo (excepcion 09 §3.1)
 * ========================================================================== */
(() => {
'use strict';
const CFG = Object.assign({ tipo:null, ruta:null, origen:null, ecommerce:false },
                          window.__GATE__ || {});

/* ---------------------------------------------------------------------------
 * 0 · Contexto: raiz del cuerpo, origen interno, tipo de pagina
 * ------------------------------------------------------------------------- */
const CROMO = 'nav,header,footer';
const esCromo = el => !!(el && el.closest && el.closest(CROMO));

const raiz = document.querySelector('main') ||
             document.querySelector('[role="main"]') || document.body;

const BASE   = (document.querySelector('base') || {}).href || location.href;
const ORIGEN = CFG.origen || (() => { try { return new URL(BASE).origin; }
                                      catch (e) { return location.origin; } })();
const RUTA = (CFG.ruta || (() => { try { return new URL(BASE).pathname; }
                                   catch (e) { return location.pathname; } })()).toLowerCase();

// El tipo decide QUE se exige. Un aviso legal es prosa a proposito; una guia no.
function inferirTipo () {
  const h1 = document.querySelector('h1');
  const rotulo = ((document.title || '') + ' ' + (h1 ? h1.innerText : '')).toLowerCase();
  if (/(^|\D)404(\D|$)|not found|no encontrad|introuvable|pagina no existe/.test(rotulo)) return '404';
  if (/legal|privac|cookie|terms|termino|condicion|mentions|rgpd|gdpr|impressum/.test(RUTA)) return 'legal';
  if (/gracias|thank|merci|obrigad|danke/.test(RUTA))            return 'gracias';
  if (/contact|contacto|kontakt/.test(RUTA))                     return 'contacto';
  if (/pricing|precio|tarif|planes|plans/.test(RUTA))            return 'precios';
  if (/compare|comparativ|[-\/]vs[-\/]|versus/.test(RUTA))       return 'comparativa';
  if (/learn|blog|guia|guide|article|notes|recursos|insight|academy|docs|documentation|reference|manual|ayuda|soporte/.test(RUTA)) return 'guia';
  if (/^\/(index\.html?)?$/.test(RUTA))                          return 'home';
  return 'servicio';
}
/* 🔴 18-ago-2026 · LO DECLARADO GANA A LA RUTA, como en qa-master.pl.
 * Este gate NUNCA miraba `data-tipo`: inferia el tipo de la URL y auditaba la
 * pagina contra la anatomia equivocada. Medido en vivo sobre
 * climentmedia.com/agents/linkedin-engine/, que declara `ficha`: el gate la
 * tomaba por `servicio` y le reclamaba `calificacion` y `proceso`, que una ficha
 * no lleva. Acusacion falsa, y de las silenciosas -- el informe decia
 * «inferido de la ruta» en una linea que nadie lee.
 * La validacion del valor NO se hace aqui: `ANATOMIA` se declara mas abajo y
 * leerla antes seria un ReferenceError. Se hace donde se usa (bloque 5). */
function tipoDeclarado () {
  const el = document.querySelector('[data-tipo]');
  const t = el ? ((el.getAttribute('data-tipo') || '') + '').trim().toLowerCase() : '';
  return /^[a-z0-9]+$/.test(t) ? t : '';
}
const TIPO_DECL = tipoDeclarado();
const TIPO = CFG.tipo || TIPO_DECL || inferirTipo();
const TIPO_FUENTE = CFG.tipo ? 'dado' : (TIPO_DECL ? 'declarado en el marcado' : 'inferido de la ruta');

/* Perfil por tipo. `estructura:false` = la pagina puede ser prosa legitimamente.
 * minPrim / minEnlaces: ver la tabla de umbrales al final del fichero.       */
// `lectura:false` = esta pagina NO tiene por que tener parrafos largos, y
// exigirselos es acusarla por ser lo que es. 24-ago-2026: /contacto/ de site-c
// arrastraba «mediana de cpl NO calculada: 0 parrafos de lectura (>=200
// caracteres), hacen falta 3» y, con el aviso de imagenes, ya sumaba los DOS
// que bastan para fallar. O sea que ninguna pagina de contacto podia aprobar
// este gate hiciera lo que hiciera, y eso es un gate que alguien acaba
// apagando. Es el mismo razonamiento que ya llevo a poner el suelo de 4
// bloques para las legales -ver la linea del aviso de imagenes-, aplicado a
// medias: /contacto/ tiene 5 bloques y le entraba igual.
const PERFIL = {
  home:        { estructura:true,  minPrim:4, minEnlaces:3, cierre:true,  hero:true,  lectura:true  },
  servicio:    { estructura:true,  minPrim:4, minEnlaces:3, cierre:true,  hero:true  },
  ciudad:      { estructura:true,  minPrim:4, minEnlaces:3, cierre:true,  hero:true  },
  producto:    { estructura:true,  minPrim:4, minEnlaces:3, cierre:true,  hero:true  },
  hub:         { estructura:true,  minPrim:3, minEnlaces:4, cierre:true,  hero:false },
  guia:        { estructura:true,  minPrim:4, minEnlaces:3, cierre:true,  hero:false },
  comparativa: { estructura:true,  minPrim:4, minEnlaces:3, cierre:true,  hero:false },
  precios:     { estructura:true,  minPrim:4, minEnlaces:2, cierre:true,  hero:true  },
  contacto:    { estructura:true,  minPrim:2, minEnlaces:0, cierre:false, hero:false, lectura:false },
  // 🔴 28-ago-2026 · `quiz` (lead magnet). Y esta linea existe por lo que pasa SIN
  //    ella: esta tabla NO se genera desde anatomy.tsv -- solo el bloque ANATOMIA
  //    de mas abajo-, y termina en un `|| {...}` que da el perfil de una pagina de
  //    SERVICIO a cualquier tipo que no este escrito aqui. Anadir un tipo al TSV
  //    lo deja, en silencio, midiendose contra un perfil que no es el suyo.
  //    Para una landing de captacion ese default es activamente malo: le exigiria
  //    `minEnlaces:3`, o sea TRES enlaces de cuerpo que sacan de la unica pagina
  //    cuyo trabajo es que no te vayas. `minEnlaces:0` es lo mismo que ya hace
  //    `contacto`, y por la misma razon.
  quiz:        { estructura:true,  minPrim:3, minEnlaces:0, cierre:true,  hero:true,  lectura:false },
  gracias:     { estructura:false, minPrim:2, minEnlaces:0, cierre:true,  hero:false, lectura:false },
  legal:       { estructura:false, minPrim:0, minEnlaces:0, cierre:false, hero:false, lectura:true  },
  '404':       { estructura:false, minPrim:0, minEnlaces:3, cierre:false, hero:false, lectura:false },
}[TIPO] || { estructura:true, minPrim:4, minEnlaces:3, cierre:true, hero:true, lectura:true };

/* ---------------------------------------------------------------------------
 * 1 · BLOQUES — el paso que hace medible la pagina-prosa
 * ---------------------------------------------------------------------------
 * Cascada de tres niveles, y el tercero es el que importa:
 *   A. [data-sec]            la convencion de 09-tipos-de-pagina.md §1
 *   B. <section> / <article> lo que ya usan site-a y site-d
 *   C. FALLBACK POR <h2>     si hay titulares FUERA de toda seccion, se
 *      sintetiza un bloque por titular. Un <h2> es una etiqueta, NO un limite
 *      de seccion (09 §2.6) — pero para MEDIR hay que fabricar el limite, y
 *      entonces esos bloques salen clasificados como prosa, que es el hecho.
 * Sin C, una pagina de 36 <p> colgando de <main> tiene 0 secciones, 0 % de
 * secciones-prosa, y PASA. Con C tiene N bloques y el 100 % son prosa.
 * ------------------------------------------------------------------------- */
const SEL_SEC = 'section,article,[data-sec]';
const alto = el => { const r = el.getBoundingClientRect(); return r.height; };

let secciones = [...raiz.querySelectorAll(SEL_SEC)]
  .filter(el => !esCromo(el))
  .filter(el => !(el.parentElement && el.parentElement.closest(SEL_SEC)))
  .filter(el => alto(el) > 40 || (el.innerText || '').trim().length > 40);

const titulares = [...raiz.querySelectorAll('h1,h2')]
  .filter(el => !esCromo(el))
  .filter(h => !secciones.some(s => s.contains(h)));

// Sube el titular hasta el hijo directo de la raiz, que es donde se puede cortar.
const subir = el => { let n = el; while (n.parentElement && n.parentElement !== raiz) n = n.parentElement; return n; };

const bloques = [];
secciones.forEach(s => bloques.push({ els:[s], fuente: s.hasAttribute('data-sec') ? 'data-sec' : 'section',
                                      rol: s.getAttribute('data-sec') || null }));

if (titulares.length) {
  const anclas = [];
  titulares.forEach(h => { const top = subir(h); if (!anclas.includes(top)) anclas.push(top); });
  const hijos = [...raiz.children];
  anclas.forEach((top, i) => {
    const desde = hijos.indexOf(top);
    if (desde < 0) return;                       // el titular no cuelga de la raiz
    const hasta = i + 1 < anclas.length ? hijos.indexOf(anclas[i + 1]) : hijos.length;
    const els = hijos.slice(desde, hasta < 0 ? hijos.length : hasta)
                     .filter(e => !e.matches(CROMO) && !e.querySelector(CROMO));
    if (els.length) bloques.push({ els, fuente:'h2-sintetico', rol:null });
  });
}
if (!bloques.length) bloques.push({ els:[raiz], fuente:'pagina-entera', rol:null });

/* PREAMBULO — lo que va ANTES del primer bloque no puede quedar huerfano.
 * ---------------------------------------------------------------------------
 * Los bloques sinteticos empiezan en el primer titular, y los <section> en la
 * primera seccion: todo lo anterior no pertenecia a NINGUN bloque y el gate lo
 * declaraba inexistente. Medido en la home de site-c (10-ago-2026, 1422x804):
 *   · <p class="cta-inline"> con el boton CONTACTA -> wa.me  en Y=724
 *   · primer <h2>, donde arrancaba `bloques[0]`,            en Y=841
 *   · pliegue (innerHeight)                                  en 804
 * El boton esta SOBRE EL PLIEGUE y el gate reportaba «HERO · sin ninguna accion
 * sobre el pliegue» con `heroAcciones: 0`. Ese es el falso positivo que mas
 * papeletas tiene de que alguien apague el gate: acusa de faltar algo que se ve
 * en pantalla.
 */
(() => {
  const hijos = [...raiz.children];
  const cubierto = new Set();
  bloques.forEach(b => b.els.forEach(e => { const t = subir(e); if (t) cubierto.add(t); }));
  const previos = [];
  for (const h of hijos) {
    if (cubierto.has(h)) break;
    if (h.matches(CROMO) || h.querySelector(CROMO)) continue;
    previos.push(h);
  }
  if (previos.length) bloques.unshift({ els:previos, fuente:'preambulo', rol:null });
})();

bloques.sort((a, b) => (a.els[0].compareDocumentPosition(b.els[0]) & 4) ? -1 : 1);

// Consulta acotada AL BLOQUE. El barrido del diagnostico se salia de la seccion
// y devolvia la repeticion de la pagina entera (34/49/21 identicos): por eso
// aqui nada consulta `document`.
const q = (b, sel) => b.els.reduce((acc, e) => {
  if (e.matches && e.matches(sel)) acc.push(e);
  acc.push(...e.querySelectorAll(sel));
  return acc;
}, []);
const texto = b => b.els.map(e => e.innerText || '').join(' ').replace(/\s+/g, ' ').trim();

/* ---------------------------------------------------------------------------
 * 2 · La firma de una PAGINA-PROSA, bloque a bloque
 * ---------------------------------------------------------------------------
 * Es PROSA si se cumplen LAS CUATRO a la vez:
 *   1. no hay grupo de hermanos repetido (>=3)
 *   2. no hay NINGUNA estructura (2D, tabla, acordeon, dl)
 *   3. hay al menos un <p>
 *   4. >=50 % del texto vive en <p> sueltos
 * ------------------------------------------------------------------------- */

// (1) Grupo repetido. Se excluyen <p> y titulares A PROPOSITO: una tirada de
// parrafos hermanos es la senal de prosa, no evidencia de maqueta. Y un grupo de
// <div> sin clase tampoco cuenta: sin clase no hay componente, hay envoltorio.
const IGNORA_GRUPO = /^(P|H1|H2|H3|H4|H5|H6|BR|HR|SCRIPT|STYLE|TEMPLATE)$/;
const TAG_ESTRUCTURAL = /^(LI|ARTICLE|FIGURE|DETAILS|DT|DD|TR|BLOCKQUOTE)$/;
function grupoRepetido (b) {
  let max = 0;
  const padres = new Set();
  b.els.forEach(e => { padres.add(e); e.querySelectorAll('*').forEach(x => padres.add(x)); });
  for (const p of padres) {
    const cuenta = {};
    for (const c of p.children) {
      if (IGNORA_GRUPO.test(c.tagName)) continue;
      const cls = (c.getAttribute && c.getAttribute('class')) || '';
      if (!cls && !TAG_ESTRUCTURAL.test(c.tagName)) continue;
      const k = c.tagName + '.' + cls;
      cuenta[k] = (cuenta[k] || 0) + 1;
      if (cuenta[k] > max) max = cuenta[k];
    }
  }
  return max;
}

// (2) Estructura. ⚠️ `wrappers == 0` NO significa prosa: los moldes 04, 08, 15 y
// 18 dan CERO contenedores grid/flex en escritorio y son maqueta pura. Una
// <table> real es display:table y un grupo de <details> no es ni grid ni flex.
// (10-vocabulario-de-maqueta.md §9.1 — esta correccion evita marcar como
// pagina-prosa la primitiva mas honesta del catalogo.)
function contenedor2D (el) {
  const d = getComputedStyle(el).display;
  if (!/(^|-)(grid|flex)$/.test(d)) return false;
  const cs = [...el.children].filter(c => { const r = c.getBoundingClientRect(); return r.width > 0 && r.height > 0; });
  if (cs.length < 2) return false;
  // COLUMNAS de verdad. Un `flex-direction:column` apilando h2+p+p da 1 columna
  // y NO es maqueta 2D: si se contara, media web moderna quedaria exonerada.
  const xs = new Set(cs.map(c => Math.round(c.getBoundingClientRect().left)));
  return xs.size >= 2;
}
// Cuantas COLUMNAS tiene una maqueta 2D. Es `contenedor2D` devolviendo el numero
// en vez de un si/no, porque el si/no no basta: ver enCeldaDeRejilla.
function columnasDe (el) {
  const d = getComputedStyle(el).display;
  if (!/(^|-)(grid|flex)$/.test(d)) return 0;
  const cs = [...el.children].filter(c => { const r = c.getBoundingClientRect(); return r.width > 0 && r.height > 0; });
  if (cs.length < 2) return 0;
  return new Set(cs.map(c => Math.round(c.getBoundingClientRect().left))).size;
}
// Un <p> dentro de una celda de una rejilla de >=3 COLUMNAS no es una columna de
// lectura: su ancho lo decide la maqueta y ronda los 280px por diseno.
//
// 🔴 EL UMBRAL DE COLUMNAS NO ES DECORATIVO, y la primera version no lo tenia:
//    excluia CUALQUIER celda, y un par-alterno -texto a un lado, imagen al
//    otro- es exactamente eso. Medido en la pagina que motivo el arreglo, los
//    parrafos de lectura pasaron de 12 a CERO: el aviso desaparecio, pero no
//    porque la pagina estuviera bien, sino porque el gate habia dejado de
//    mirar. Es el mismo modo de fallo que ANCHO-MIN el 24-ago por la manana.
//    Con >=3 columnas, el <p> de 493px del par-alterno SIGUE contando -que es
//    lo que hay que medir- y las 10 tarjetas de testimonio de 286px no.
function enCeldaDeRejilla (el) {
  for (let n = el.parentElement; n && n !== raiz; n = n.parentElement) {
    if (n.parentElement && columnasDe(n.parentElement) >= 3) return true;
  }
  return false;
}
function estructura (b) {
  const ev = [];
  if (b.els.some(e => contenedor2D(e)) || q(b, '*').some(e => contenedor2D(e))) ev.push('2D');
  if (q(b, 'table').some(t => t.rows.length >= 2 && t.rows[0].cells.length >= 2)) ev.push('tabla');
  const padres = new Set(q(b, 'details').map(d => d.parentElement));
  if ([...padres].some(p => p && p.querySelectorAll(':scope > details').length >= 3)) ev.push('acordeon');
  if (q(b, 'dl').some(d => d.querySelectorAll(':scope > dt').length >= 3)) ev.push('dl');
  return ev;
}

// (4) Texto en <p> sueltos — fuera de li/figure/blockquote/details/table/dl.
function ratioProsa (b) {
  const t = texto(b).length; if (!t) return 0;
  const sueltos = q(b, 'p').filter(p => !p.closest('li,figure,blockquote,details,table,dl'));
  const tp = sueltos.map(p => (p.innerText || '')).join(' ').replace(/\s+/g, ' ').trim().length;
  return tp / t;
}

/* Etiqueta gruesa de primitiva. NO pretende distinguir las 19 del vocabulario:
 * distingue CLASES de maqueta, que es lo que mide variedad real.             */
function primitiva (b, i) {
  const ev = estructura(b), grp = grupoRepetido(b);
  const medias = q(b, 'img,svg,video,picture,canvas').length;
  const acciones = accionesDe(b).length;
  if (i === 0 && q(b, 'h1').length && acciones) return 'hero';
  if (q(b, 'form').length)            return 'formulario';
  if (ev.includes('tabla'))           return 'tabla';
  if (ev.includes('acordeon'))        return 'acordeon';
  if (ev.includes('dl'))              return 'definiciones';
  if (ev.includes('2D') && grp >= 3)  return 'rejilla';
  if (ev.includes('2D'))              return 'par-alterno';
  if (grp >= 3 && medias >= 3)        return 'galeria';
  if (grp >= 3)                       return 'lista-estructurada';
  if (medias >= 1 && texto(b).length < 400) return 'media';
  if (esProsa(b))                     return 'prosa';
  return 'otro';
}
/* Un bloque CORTO no es prosa, por mucho que sea texto.
 * ---------------------------------------------------------------------------
 * Sin este suelo, el hero y el cierre —los dos bloques que 10-vocabulario §6
 * declara OBLIGATORIOS en TODA pagina («toda pagina empieza por 01 y acaba por
 * 11»)— se contaban como prosa. En una pagina de 7 bloques eso es un 28,6 %
 * regalado, pegado al umbral del 30 %: el gate habria acusado a cualquier
 * pagina bien construida. Lo cazo el control frontera F2.
 *
 * Los dos suelos salen del hueco MEDIDO en los 6 controles, no de mi criterio:
 *   bloques legitimos cortos : 84, 125, 169, 191, 198, 231, 235, 256, 264,
 *                              303, 317, 329, 341, 446 caracteres · 0-2 <p>
 *   bloques de prosa de verdad: 802, 896, 901, 903, 904, 1113, 1229, 1431,
 *                              1437, 1637, 1792, 3523 caracteres  · 4-25 <p>
 * El hueco 446 -> 802 y el hueco 2 -> 4 son limpios. 600 y 3 caen dentro.
 *
 * ⚠️ Coste asumido: una pagina de 8 secciones de DOS parrafos cortos no la coge
 * PROSA-3. La cogen PROSA-1, PROSA-2 y VARIEDAD, que no dependen de esto.
 */
const PROSA_MIN_CHARS = 600, PROSA_MIN_PS = 3;
function esProsa (b) {
  const sueltos = q(b, 'p').filter(p => !p.closest('li,figure,blockquote,details,table,dl'));
  if (texto(b).length < PROSA_MIN_CHARS || sueltos.length < PROSA_MIN_PS) return false;
  return grupoRepetido(b) < 3 && estructura(b).length === 0 && ratioProsa(b) >= 0.5;
}

/* ---------------------------------------------------------------------------
 * 3 · Acciones, hero y enlaces
 * ------------------------------------------------------------------------- */
const SEL_ACC = 'a[href],button,input[type=submit],input[type=button]';
const visible = el => { const r = el.getBoundingClientRect(); return r.width > 0 && r.height > 0; };
const accionesDe = b => q(b, SEL_ACC).filter(visible);

const RE_CONVIERTE = /^tel:|^mailto:|wa\.me|whatsapp|calendly|cal\.com|typeform|hubspot|^https?:\/\/[^\/]*(book|meet)/i;
const RE_RUTA_CONV = /contact|contacto|audit|auditor|presupuesto|cita|reserva|book|demo|devis|rdv|quote|empez|start|signup|sign-up|registro|register|checkout|carrito|cart|comprar|apply|candidat|trial|prueba|merci|gracias/i;
function convierte (el) {
  if (el.tagName === 'BUTTON' || el.tagName === 'INPUT') return !!el.closest('form');
  const h = el.getAttribute('href') || '';
  if (RE_CONVIERTE.test(h)) return true;
  try { const u = new URL(el.href, BASE); return u.origin === ORIGEN && RE_RUTA_CONV.test(u.pathname); }
  catch (e) { return RE_RUTA_CONV.test(h); }
}
// «Primaria» = accion con relleno propio. Dos rellenas del mismo peso es el
// hero-que-enlaza descrito en 09 §3: el visitante elige la opcion mas barata,
// que es irse.
function primaria (el) {
  const s = getComputedStyle(el);
  const bg = s.backgroundColor || '';
  const m = bg.match(/rgba?\(([^)]+)\)/);
  if (!m) return false;
  const p = m[1].split(',').map(Number);
  if (p.length > 3 && p[3] < 0.5) return false;
  const claro = p[0] > 240 && p[1] > 240 && p[2] > 240;   // blanco = fantasma
  return !claro;
}

const enlacesInternos = (() => {
  const vistos = new Set();
  bloques.forEach(b => q(b, 'a[href]').filter(visible).forEach(a => {
    const h = a.getAttribute('href') || '';
    if (/^(#|javascript:|mailto:|tel:)/i.test(h)) return;
    let u; try { u = new URL(a.href, BASE); } catch (e) { return; }
    if (u.origin !== ORIGEN) return;
    const dest = u.pathname.replace(/\/index\.html?$/, '/');
    if (dest === RUTA.replace(/\/index\.html?$/, '/')) return;   // a si misma
    vistos.add(dest);
  }));
  return [...vistos];
})();

/* ---------------------------------------------------------------------------
 * 4 · Medidas (H3 «lo del ancho») y escala
 * ------------------------------------------------------------------------- */
/* MEDIDA REAL DE LA LINEA, no la teorica.
 * ---------------------------------------------------------------------------
 * El metodo de canvas (ancho / ancho medio de caracter) da los caracteres que
 * CABRIAN. La linea real rompe en un espacio, asi que siempre es mas corta.
 * Verificado a mano en 13 parrafos de 3 paginas: canvas 89-90 donde la linea
 * real era 77-87, y canvas 84-85 donde era 73-83. Hasta 13 caracteres de mas,
 * SIEMPRE al alza — es decir, acusando de mas.
 * Aqui se busca por biseccion el caracter en el que cambia la coordenada Y:
 * ~9 llamadas por parrafo y el numero es el que se ve en pantalla.
 * (El gate de 11-medidas §7 usa canvas: sus cifras son el techo, no la linea.)
 */
function cplReal (p) {
  const nodo = [...p.childNodes].find(n => n.nodeType === 3 && n.textContent.trim().length > 60);
  if (!nodo) return null;
  const t = nodo.textContent, r = document.createRange();
  const yDe = i => { r.setStart(nodo, i - 1); r.setEnd(nodo, i);
                     const c = r.getBoundingClientRect(); return c.height ? c.top : null; };
  const xDe = i => { r.setStart(nodo, i - 1); r.setEnd(nodo, i);
                     const c = r.getBoundingClientRect(); return c.height ? c.left : null; };
  // 🔴 20-ago-2026 · SE MIDE DESDE EL PRINCIPIO DE UNA LINEA, NO DEL NODO.
  //    Este bloque cogia el primer nodo de texto suelto y media desde su primer
  //    caracter. Si el parrafo empieza con un elemento en linea -- `<strong>`,
  //    `<a>`, `<em>` -- ese nodo arranca A MITAD DE LINEA, y lo que se medi­a era
  //    el TROZO que quedaba hasta el salto: no una linea.
  //    Medido en la portada de climentmedia: un parrafo de 544px de ancho, con
  //    ~73 cpl reales, devolvia **2**. Con tres parrafos asi, la mediana bajaba
  //    a 43 y el gate acusaba de "linea demasiado corta" a una pagina correcta.
  //    Y el falso positivo NO es simetrico: hunde la mediana, nunca la sube, o
  //    sea que siempre acusa de lo mismo. Fixture: `cpl-strong-inicial.html`,
  //    que es `guia-maquetada.html` con el mismo texto envuelto en <strong>.
  const cs = getComputedStyle(p), pr = p.getBoundingClientRect();
  const izquierda = pr.left + parseFloat(cs.paddingLeft || 0) + parseFloat(cs.borderLeftWidth || 0);
  const TOL = 4;
  let i0 = 1, x0 = null;
  while (i0 < t.length) { x0 = xDe(i0); if (x0 !== null && x0 <= izquierda + TOL) break; i0++; }
  if (i0 >= t.length || x0 === null) return null;   // el nodo no llega a empezar ninguna linea
  const y0 = yDe(i0);
  if (y0 === null) return null;
  const tope = Math.min(t.length, 2000);
  const yFin = yDe(tope);
  if (yFin === null || yFin <= y0 + 2) return null;      // cabe en una linea: no mide nada
  let lo = i0, hi = tope;
  while (lo + 1 < hi) { const mid = (lo + hi) >> 1; const y = yDe(mid);
                        if (y === null || y <= y0 + 2) lo = mid; else hi = mid; }
  // ⚠️ `lo` es un indice en el texto FUENTE, y el HTML lleva saltos de linea e
  // indentacion que en pantalla colapsan a UN espacio. Contarlos daba 90
  // caracteres a un parrafo que solo tiene 95 en total. Se cuenta el texto
  // RENDERIZADO, que es el unico que ve el lector.
  return t.slice(i0 - 1, lo).replace(/\s+/g, ' ').trim().length;
}

const cvs = document.createElement('canvas'), ctx = cvs.getContext('2d');
const cpls = [];
// ⚠️ SOLO BLOQUES DE TEXTO HOJA. Un <li> que CONTIENE <p> no es una linea de
// texto, es un envoltorio: medir su ancho contra el texto concatenado de sus
// hijos da un numero inventado. Medido: `li.hito` del molde 17 daba 97 cpl
// mientras su <p> de dentro, que es lo que se lee, estaba en 52ch. Falso
// positivo del instrumento, no defecto de la pagina.
const BLOQUE_DENTRO = 'p,div,ul,ol,li,table,figure,blockquote,section,article,h1,h2,h3,h4,h5,h6';
for (const p of raiz.querySelectorAll('p,li')) {
  const t = (p.innerText || '').trim();
  if (t.length < 90 || esCromo(p)) continue;
  if (p.querySelector(BLOQUE_DENTRO)) continue;
  const r = p.getBoundingClientRect(); if (r.width < 60) continue;
  const s = getComputedStyle(p);
  ctx.font = `${s.fontStyle} ${s.fontWeight} ${s.fontSize} ${s.fontFamily}`;
  const m = t.replace(/\s+/g, ' ').slice(0, 400);
  const anchoMedio = ctx.measureText(m).width / m.length;
  if (!anchoMedio) continue;
  const real = cplReal(p);
  cpls.push({ cpl: real !== null ? real : Math.round(r.width / anchoMedio),
              metodo: real !== null ? 'linea real' : 'canvas (estimado, techo)',
              enCelda: enCeldaDeRejilla(p),
              em: +(r.width / parseFloat(s.fontSize)).toFixed(1),
              tag: p.tagName, len: t.length,
              sel: p.tagName.toLowerCase() + '.' + ((p.getAttribute('class') || '—').split(' ')[0]),
              txt: t.slice(0, 40) });
}
const mediana = a => { if (!a.length) return null; const s = [...a].sort((x, y) => x - y);
                       return s.length % 2 ? s[(s.length - 1) / 2] : (s[s.length / 2 - 1] + s[s.length / 2]) / 2; };
// La MEDIANA se calcula solo sobre COLUMNAS DE LECTURA. El rango 45-90 gobierna
// texto corrido, NO celdas de rejilla: una celda de `pasos-numerados` a 4
// columnas da 33 cpl y esta bien, es una etiqueta (10-vocabulario §3).
// Mezclarlas hundia la mediana de una pagina correcta a 34,5.
//
// 🔴 24-ago-2026 · EL FILTRO ERA `len >= 200`, QUE ES UNA PROXY Y SE ROMPE.
//    Daba por hecho que una celda de rejilla lleva texto corto. Un TESTIMONIO
//    no: son 200-400 caracteres dentro de una tarjeta de 286px, y por ahi se
//    colaban 10 de los 12 "parrafos de lectura" de una pagina.
//    Medido en site-c.example/hipnosis-para-recuperar-a-tu-pareja-en-san-diego
//    a 1298px: cplMediana 34 y aviso de "linea demasiado corta", cuando el
//    UNICO parrafo de prosa real medi­a 493px a 17px = ~65 cpl, que esta bien.
//    Mismo aviso en las 5 paginas de ciudad y en /recuperar-el-amor/: seis
//    paginas acusadas, cinco de ellas destino de sus anuncios.
//    El discriminador no es cuanto texto tiene: es DONDE VIVE. `contenedor2D`
//    ya sabe distinguir una rejilla con columnas de verdad, y es un hecho de
//    la maqueta, no una suposicion sobre la longitud.
//    (la funcion enCeldaDeRejilla vive junto a contenedor2D, que es de donde
//    sale su criterio.)
const lectura = cpls.filter(c => c.tag === 'P' && c.len >= 200 && !c.enCelda).map(c => c.cpl);
const cplMediana = mediana(lectura);
const cplMalos = cpls.filter(c => c.cpl > 80).sort((a, b) => b.cpl - a.cpl);

const textoPropio = el => [...el.childNodes].some(n => n.nodeType === 3 && n.textContent.trim().length > 1);
const fuentes = new Set(), espaciados = new Set();
for (const el of raiz.querySelectorAll('*')) {
  if (esCromo(el) || !visible(el)) continue;
  const s = getComputedStyle(el);
  if (textoPropio(el)) fuentes.add(Math.round(parseFloat(s.fontSize) * 10) / 10);
  ['marginTop', 'marginBottom', 'paddingTop', 'paddingBottom', 'rowGap'].forEach(k => {
    const v = Math.round(parseFloat(s[k]) || 0); if (v > 0) espaciados.add(v);
  });
}
// Solo la BANDA DE TEXTO (11-28px): es donde el ojo distingue ~4-5 niveles.
// Un h1 de 44px y un pie de 10px no compiten entre si.
const banda = [...fuentes].filter(v => v >= 11 && v <= 28).sort((a, b) => a - b);
let saltosCiegos = 0;
for (let i = 1; i < banda.length; i++) if (banda[i] / banda[i - 1] < 1.08) saltosCiegos++;

/* ---------------------------------------------------------------------------
 * 4b · ANCHO-MIN — el contenedor REAL contra el declarado, y la celda
 * ---------------------------------------------------------------------------
 * POR QUE SE ANADIO (control positivo F2, 10-ago-2026):
 * `molde-home-roto.html` (fixture congelado) daba `VEREDICTO: PASA · fallos: [] · cplMediana: null`
 * estando VISIBLEMENTE rota: 4 de sus 7 secciones a 568px en vez de 1120, y la
 * rejilla en columnas de 188,7px. La causa es que los 19 moldes comparten el
 * nombre de clase `.sec__in` y al concatenar sus <style> gana el ultimo, que la
 * fija a `var(--texto)` (62ch = 568,172px) en vez de `var(--ancho)` (1120px).
 *
 * El gate no lo veia porque SOLO MEDIA LINEAS DEMASIADO LARGAS. Ningun parrafo
 * de esa pagina llega a 200 caracteres, asi que `cplMediana` salio `null`: la
 * unica medida de anchura que habia NO LLEGO A EJECUTARSE. Un control positivo
 * que aprueba en vacio no calibra el gate, lo exime.
 *
 * Se mide lo contrario de lo que ya se medía: no que la linea sea larga, sino
 * que el CONTENEDOR sea estrecho — que es como se ve el mismo defecto cuando el
 * texto es corto.
 * ------------------------------------------------------------------------- */
const VIEWPORT_ANCHO = 1200;   // por debajo NO se juzga anchura: manda el aparato
const RATIO_WRAP     = 0.75;   // 🟡 PROVISIONAL — ver tabla de umbrales
const CELDA_MIN      = 240;    // px · MEDIDO — ver tabla de umbrales
const juzgaAncho     = innerWidth >= VIEWPORT_ANCHO;

// Sonda unica: resuelve longitudes CSS (px, rem, ch, vw...) y colores usando el
// motor del navegador, sin reimplementar ninguna conversion a mano.
const sonda = document.createElement('div');
sonda.style.cssText = 'position:absolute;left:-9999px;top:0;visibility:hidden;height:0';
document.body.appendChild(sonda);
function resolverPx (valor) {
  sonda.style.width = ''; sonda.style.width = valor;
  const w = sonda.getBoundingClientRect().width;
  return w > 0 ? w : null;
}

// El ancho declarado por el sitio. NO se infiere de las medidas: si no hay token,
// se dice que no se ha comprobado. Un cero de busqueda es un no-match, no una
// ausencia — inventar aqui un `wrap` a partir del maximo medido convertiria un
// diseno legitimo de hero ancho + cuerpo estrecho en un fallo.
const WRAP = (() => {
  const cs = getComputedStyle(document.documentElement);
  for (const n of ['--ancho', '--wrap', '--contenedor', '--container',
                   '--max-ancho', '--maxw', '--medida', '--content-width']) {
    const v = (cs.getPropertyValue(n) || '').trim();
    if (!v) continue;
    const px = resolverPx(v);
    if (px && px >= 600) return { token:n, valor:v, px:Math.round(px) };
  }
  return null;
})();

const mote = el => el.tagName.toLowerCase() + '.' +
                   ((el.getAttribute('class') || '—').split(' ')[0]);

// Contenedor del bloque = el descendiente MAS ANCHO con `max-width` distinto de
// `none`. Es el elemento que decide hasta donde llega la seccion.
function contenedorDe (b) {
  let mejor = null, w = 0;
  b.els.forEach(e => [e, ...e.querySelectorAll('*')].forEach(x => {
    if (!visible(x) || getComputedStyle(x).maxWidth === 'none') return;
    const r = x.getBoundingClientRect();
    if (r.width > w) { w = r.width; mejor = x; }
  }));
  return mejor ? { w: Math.round(w), sel: mote(mejor) } : null;
}

// Celda de rejilla = hijo directo de un contenedor 2D de >=2 COLUMNAS que lleva
// texto propio. Se exige texto (>=20 caracteres) a proposito: una tira de logos
// o una fila de iconos son legitimamente estrechas y no son celdas de tarjeta.
function celdasDe (b) {
  const out = [];
  b.els.forEach(e => [e, ...e.querySelectorAll('*')].forEach(x => {
    if (!/(^|-)(grid|flex)$/.test(getComputedStyle(x).display)) return;
    // 24-ago-2026 · UNA FILA DE BOTONES NO ES UNA REJILLA, y ANCHO-MIN la
    // acusaba como tal. El filtro de «>=20 caracteres» existe para excluir
    // logos e iconos, pero un CTA LLEVA TEXTO -«Escribirme por WhatsApp» son
    // 23 caracteres-, asi que dos botones en un flex pasaban por dos celdas de
    // tarjeta y su contenedor -510px- salia acusado de estrecho. Es estrecho A
    // PROPOSITO: unos botones centrados no deben medir 1120px.
    // Medido en site-c.example: ANCHO-MIN saltaba en /recuperar-el-amor/ y
    // /vidente-.../ señalando «bloque 7, p.banda-btns a 510px» en las dos, y
    // ninguna de las dos tenia una rejilla ahi. Es el falso positivo que apaga
    // un gate: acusa de algo que esta bien y no se puede arreglar sin empeorar.
    const hijos = [...x.children].filter(visible)
                                 // Solo se excluye el hijo que ES una accion, NO el que CONTIENE
                                 // una. La primera version anadio ademas
                                 // !c.querySelector(SEL_ACC + ':only-child'), y eso se llevaba por
                                 // delante las tarjetas de verdad: una tarjeta cuyo titulo es un
                                 // enlace lo cumple. Con eso `celdasDe` devolvia vacio, `conRejilla`
                                 // salia false y ANCHO-MIN DEJABA DE MIRAR — el arreglo del falso
                                 // positivo se habia comido la regla entera, y en produccion parecia
                                 // funcionar. Lo caza `rejilla-estrujada.html`: para eso existe un
                                 // caso rojo y no solo casos que tienen que pasar.
                                 .filter(c => !c.matches(SEL_ACC))
                                 .filter(c => (c.innerText || '').trim().length >= 20);
    if (hijos.length < 2) return;
    const xs = new Set(hijos.map(c => Math.round(c.getBoundingClientRect().left)));
    if (xs.size < 2) return;                    // 1 columna apilada: no es rejilla
    hijos.forEach(c => out.push({ w: Math.round(c.getBoundingClientRect().width), sel: mote(c) }));
  }));
  return out;
}

const anchoBloques = bloques.map((b, i) => {
  const c = contenedorDe(b), cel = celdasDe(b).sort((x, y) => x.w - y.w);
  return { n:i + 1, contW: c ? c.w : null, contSel: c ? c.sel : null,
           conRejilla: cel.length > 0,
           celdaMin: cel.length ? cel[0].w : null,
           celdaSel: cel.length ? cel[0].sel : null };
});

/* ---------------------------------------------------------------------------
 * 4c · CONTRASTE — texto sobre COLOR PLANO, AA 4,5:1
 * ---------------------------------------------------------------------------
 * Sin canvas: el canvas solo hace falta para leer el pixel de una FOTO. Sobre
 * color plano basta componer los fondos y aplicar WCAG 2.1 SC 1.4.3.
 * ⚠️ `getComputedStyle` NO devuelve rgb() cuando el autor escribio el color en
 * oklch/oklab/lab/display-p3: devuelve el mismo espacio de origen
 * (`oklch(0.62 0.21 258)`). Comparar cadenas o hacer parseInt ahi da basura.
 * Se resuelve con `color-mix(in srgb, VALOR 100%, transparent 0%)`, que obliga
 * al navegador a convertir a sRGB y devuelve `color(srgb r g b)`.
 * Verificado en este Chrome con los 7 sintaxis: hex, rgb, hsl, oklch, oklab,
 * lab y display-p3 — los 7 salen en `color(srgb ...)`.
 * ------------------------------------------------------------------------- */
const memoColor = new Map();
function aSRGB (valor) {
  const v = String(valor || '').trim();
  if (!v || v === 'transparent' || v === 'none') return null;
  if (memoColor.has(v)) return memoColor.get(v);
  sonda.style.color = 'rgb(1, 2, 3)';                       // centinela
  sonda.style.color = `color-mix(in srgb, ${v} 100%, transparent 0%)`;
  const c = getComputedStyle(sonda).color;
  let r = null;
  if (c !== 'rgb(1, 2, 3)') {
    const n = (c.match(/-?[\d.]+(?:e[-+]?\d+)?/g) || []).map(Number);
    if (n.length >= 3) {
      const k = x => Math.min(1, Math.max(0, x));           // fuera de gama -> recorta
      r = /^color\(/i.test(c)
        ? { r:k(n[0]), g:k(n[1]), b:k(n[2]), a: n.length > 3 ? n[3] : 1 }
        : { r:k(n[0]/255), g:k(n[1]/255), b:k(n[2]/255), a: n.length > 3 ? n[3] : 1 };
    }
  }
  memoColor.set(v, r);
  return r;
}
const BLANCO = { r:1, g:1, b:1, a:1 };
const componer = (frente, fondo) => ({
  r: frente.r * frente.a + fondo.r * (1 - frente.a),
  g: frente.g * frente.a + fondo.g * (1 - frente.a),
  b: frente.b * frente.a + fondo.b * (1 - frente.a), a:1 });
const luminancia = c => { const f = x => x <= 0.03928 ? x / 12.92 : Math.pow((x + 0.055) / 1.055, 2.4);
                          return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b); };
const contraste = (a, b) => { const L1 = luminancia(a), L2 = luminancia(b);
                              return +((Math.max(L1, L2) + 0.05) / (Math.min(L1, L2) + 0.05)).toFixed(2); };

// Fondo efectivo: se sube apilando fondos translucidos hasta el primero opaco.
// Si por el camino hay imagen o degradado, NO ES MEDIBLE — y no medible NO es
// aprobado: se cuenta aparte y se dice.
function fondoDe (el) {
  const pila = [];
  for (let n = el; n && n.nodeType === 1; n = n.parentElement) {
    const cs = getComputedStyle(n);
    if (cs.backgroundImage && cs.backgroundImage !== 'none') return { foto:true };
    const c = aSRGB(cs.backgroundColor);
    if (c && c.a > 0.02) { pila.push(c); if (c.a >= 0.99) break; }
  }
  let f = BLANCO;                       // el lienzo del navegador es blanco
  for (let i = pila.length - 1; i >= 0; i--) f = componer(pila[i], f);
  return { color:f };
}

const malContraste = [];
let contrasteSobreFoto = 0, contrasteMedidos = 0;
for (const el of raiz.querySelectorAll('*')) {
  if (esCromo(el) || !visible(el) || !textoPropio(el)) continue;
  const cs = getComputedStyle(el);
  if (parseFloat(cs.opacity) < 0.5) continue;
  const t = [...el.childNodes].filter(n => n.nodeType === 3)
                              .map(n => n.textContent).join(' ').replace(/\s+/g, ' ').trim();
  if (t.length < 3) continue;
  const r = el.getBoundingClientRect();
  if (r.height < 6 || r.width < 12) continue;          // sr-only / recortado
  const fg0 = aSRGB(cs.color); if (!fg0) continue;
  const f = fondoDe(el);
  if (f.foto) { contrasteSobreFoto++; continue; }
  contrasteMedidos++;
  const fg = fg0.a >= 0.99 ? fg0 : componer(fg0, f.color);
  const px = parseFloat(cs.fontSize), peso = parseInt(cs.fontWeight, 10) || 400;
  // WCAG 2.1 SC 1.4.3: texto grande (>=24px, o >=18,66px en negrita) baja a 3:1.
  const min = (px >= 24 || (px >= 18.66 && peso >= 700)) ? 3 : 4.5;
  const cr = contraste(fg, f.color);
  if (cr < min) malContraste.push({ ratio:cr, min, px:Math.round(px), sel:mote(el), txt:t.slice(0, 32) });
}
malContraste.sort((a, b) => a.ratio - b.ratio);
sonda.remove();

/* >>> ANATOMIA-GENERADA · sale de anatomy.tsv · no editar a mano
 * Regenerar:  perl anatomy.pl --regenerar-js
 * Comprobar:  perl anatomy.pl --gate   (lo corre run-all.sh)
 * La tabla humana es 09-tipos-de-pagina.md §2 */
const ANATOMIA = {
  home:         ['hero', 'prueba', 'oferta', 'proceso', 'cierre'],
  servicio:     ['hero', 'oferta', 'calificacion', 'proceso', 'objeciones', 'hermanos', 'cierre'],
  ciudad:       ['hero', 'mapa', 'oferta', 'objeciones', 'hermanos', 'cierre'],
  ficha:        ['hero', 'oferta', 'prueba', 'objeciones', 'hermanos', 'cierre'],
  hub:          ['hero', 'catalogo', 'calificacion', 'cierre'],
  guia:         ['hero', 'objeciones', 'hermanos', 'cierre'],
  comparativa:  ['hero', 'alternativas', 'objeciones', 'hermanos', 'cierre'],
  precios:      ['hero', 'oferta', 'prueba', 'proceso', 'objeciones', 'cierre'],
  contacto:     ['hero', 'prueba'],
  gracias:      ['hero', 'proceso', 'cierre'],
  quiz:         ['hero', 'formulario', 'oferta', 'calificacion', 'proceso', 'objeciones', 'cierre'],
};
/* Sin anatomia, a proposito: 09 §2.11 */
const ANATOMIA_SIN = ['legal', '404'];
const ANATOMIA_ALIAS = { producto: 'ficha' };
/* >>> FIN-ANATOMIA-GENERADA <<< */
const rolesDeclarados = bloques.map(b => b.rol).filter(Boolean);
const TIPO_ANAT = ANATOMIA_ALIAS[TIPO] || TIPO;
const anatomiaEsperada = ANATOMIA[TIPO_ANAT] || null;
/* Un `data-tipo` que no existe en la tabla no se acepta en silencio: si se
 * aceptara, cualquiera esquiva la anatomia que le moleste escribiendo una
 * palabra nueva. `legal` y `404` son validos y no llevan roles. */
const TIPO_RARO = (TIPO_DECL && !ANATOMIA[TIPO_ANAT] && !ANATOMIA_SIN.includes(TIPO_ANAT)) ? TIPO_DECL : '';
const rolesFaltan = (rolesDeclarados.length && anatomiaEsperada)
  ? anatomiaEsperada.filter(r => !rolesDeclarados.includes(r)) : [];

/* ---------------------------------------------------------------------------
 * 6 · Recuento y VEREDICTO
 * ------------------------------------------------------------------------- */
const ficha = bloques.map((b, i) => ({
  n: i + 1,
  fuente: b.fuente,
  rol: b.rol || null,
  que: ((q(b, 'h1,h2,h3')[0] || {}).innerText || b.els[0].tagName.toLowerCase()).slice(0, 44),
  primitiva: primitiva(b, i),
  prosa: esProsa(b),
  grupoMax: grupoRepetido(b),
  estructura: estructura(b),
  medias: q(b, 'img,svg,video,picture').length,
  ctas: accionesDe(b).length,
  chars: texto(b).length,
  psSueltos: q(b, 'p').filter(p => !p.closest('li,figure,blockquote,details,table,dl')).length,
  ratioP: +ratioProsa(b).toFixed(2),
}));

let maxHermanosP = 0;
const padres = new Set([raiz, ...raiz.querySelectorAll('*')]);
for (const p of padres) {
  if (esCromo(p)) continue;
  const n = [...p.children].filter(c => c.tagName === 'P').length;
  if (n > maxHermanosP) maxHermanosP = n;
}

const nProsa      = ficha.filter(f => f.prosa).length;
const pctProsa    = bloques.length ? nProsa / bloques.length : 0;
const primitivas  = [...new Set(ficha.map(f => f.primitiva).filter(p => p !== 'prosa' && p !== 'otro'))];
const conEstruct  = ficha.filter(f => f.estructura.length || f.grupoMax >= 3).length;
const sinMedia    = ficha.filter(f => f.medias === 0).length;
const hero        = ficha[0];
const ultimo      = ficha[ficha.length - 1];

/* EL HEROE ES LA PRIMERA ALTURA DE VIEWPORT, NO `bloques[0]`.
 * ---------------------------------------------------------------------------
 * «Sobre el pliegue» es una medida de PANTALLA. Medirla sobre el primer bloque
 * del arbol es medir otra cosa: en site-c el primer bloque empieza en Y=841 y el
 * pliegue esta en 804, asi que el boton de Y=724 caia fuera de los dos.
 * Ahora se toma TODA accion visible de la raiz cuyo borde superior cae dentro
 * de la primera altura de viewport.
 * Se excluyen `position:fixed|sticky` a proposito: un boton flotante de
 * WhatsApp acompana toda la pagina, no es la propuesta del heroe — contarlo
 * exoneraria a cualquier sitio que lleve uno.
 */
const fijo = el => { for (let n = el; n && n.nodeType === 1; n = n.parentElement) {
                       const p = getComputedStyle(n).position;
                       if (p === 'fixed' || p === 'sticky') return true; } return false; };
const accHero = [...raiz.querySelectorAll(SEL_ACC)]
  .filter(visible).filter(el => !esCromo(el)).filter(el => !fijo(el))
  .filter(el => el.getBoundingClientRect().top + scrollY < innerHeight);
const accBloque1 = bloques.length ? accionesDe(bloques[0]) : [];

const fallos = [], avisos = [];

/* ⚠️ EN MOVIL NO SE JUZGA LA ESTRUCTURA, Y NO ES UNA CONCESION.
 * `contenedor2D` exige >=2 COLUMNAS. A 390px un par-alterno correcto colapsa a
 * una columna por diseno, asi que su estructura desaparece de la medida: medido,
 * la pagina compuesta de moldes baja de 4 primitivas a 3 (par-alterno deja de
 * detectarse) solo por cambiar la anchura. Juzgar PROSA-2/PROSA-3/VARIEDAD a 390
 * seria acusar a una pagina por hacer bien el movil.
 * Lo que SI se juzga a 390, porque no depende de la anchura: PROSA-1 (parrafos
 * hermanos), ANCHO, HERO, ANATOMIA y ENLACES. */
const MOVIL = innerWidth < 640;
const avisosMovil = [];   // se informan aparte y NO cuentan para la regla de 2 avisos
const estructural = (msg) => {
  if (MOVIL) avisosMovil.push(msg + ' [no cuenta: medido a <640px, la maqueta 2D colapsa por diseno]');
  else fallos.push(msg);
};

/* --- E1 · PROSA-1 · tirada de <p> hermanos ------------------------------- */
if (PERFIL.estructura && maxHermanosP >= 8)
  fallos.push(`PROSA-1 · ${maxHermanosP} <p> hermanos bajo un mismo padre (limite 8). ` +
              `Es la firma literal del articulo de blog`);

/* --- E2 · PROSA-3 · proporcion de bloques que son prosa ------------------ */
if (PERFIL.estructura && pctProsa >= 0.30)
  estructural(`PROSA-3 · ${(pctProsa * 100).toFixed(1)} % de los bloques son prosa pura ` +
              `(${nProsa}/${bloques.length}, limite 30 %)`);

/* --- E3 · PROSA-2 (corregido) · ni una estructura en toda la pagina ------ */
if (PERFIL.estructura && conEstruct === 0 && bloques.length >= 4)
  estructural(`PROSA-2 · ${bloques.length} bloques y NINGUNO tiene estructura ` +
              `(ni rejilla, ni tabla, ni acordeon, ni grupo repetido)`);

/* --- E4 · variedad de maqueta -------------------------------------------- */
if (primitivas.length < PERFIL.minPrim)
  estructural(`VARIEDAD · ${primitivas.length} primitivas distintas [${primitivas.join(', ') || '—'}], ` +
              `minimo ${PERFIL.minPrim} para tipo «${TIPO}»`);

/* --- E5 · longitud de linea (H3, «lo del ancho») ------------------------- */
if (cplMalos.length)
  fallos.push(`ANCHO · ${cplMalos.length} parrafo(s) por encima de 80 caracteres por linea ` +
              `(peor: ${cplMalos[0].cpl} cpl = ${cplMalos[0].em} em, ${cplMalos[0].sel})`);

/* --- E5b · ANCHO-MIN · contenedor estrecho y celda estrecha -------------- */
if (juzgaAncho && WRAP) {
  // Solo se juzga la seccion que LLEVA REJILLA. Una seccion de solo texto puede
  // ser estrecha a proposito y debe serlo: el molde 08 (acordeon-faq) lo dice
  // por escrito — «un FAQ a 1120px da lineas de 140 caracteres». Acusarla seria
  // el falso positivo que apaga el gate.
  const angostos = anchoBloques.filter(a => a.conRejilla && a.contW !== null &&
                                            a.contW < RATIO_WRAP * WRAP.px);
  if (angostos.length)
    fallos.push(`ANCHO-MIN · ${angostos.length} seccion(es) CON REJILLA cuyo contenedor no llega al ` +
                `${Math.round(RATIO_WRAP * 100)} % del ancho que declara el propio sitio ` +
                `(${WRAP.token}: ${WRAP.px}px, suelo ${Math.round(RATIO_WRAP * WRAP.px)}px). ` +
                `Peor: bloque ${angostos[0].n}, ${angostos[0].contSel} a ${angostos[0].contW}px`);
}
if (juzgaAncho) {
  const celdasMalas = anchoBloques.filter(a => a.celdaMin !== null && a.celdaMin < CELDA_MIN)
                                  .sort((a, b) => a.celdaMin - b.celdaMin);
  if (celdasMalas.length)
    fallos.push(`ANCHO-MIN · ${celdasMalas.length} rejilla(s) con celdas por debajo de ${CELDA_MIN}px ` +
                `(peor: bloque ${celdasMalas[0].n}, ${celdasMalas[0].celdaSel} a ${celdasMalas[0].celdaMin}px). ` +
                `La celda mas estrecha de los 19 moldes son 250px`);
}

/* --- E9 · CONTRASTE (AA) -------------------------------------------------- */
if (malContraste.length)
  fallos.push(`CONTRASTE · ${malContraste.length} elemento(s) de texto por debajo de AA ` +
              `(peor: ${malContraste[0].ratio}:1 en ${malContraste[0].sel}, ` +
              `${malContraste[0].px}px, minimo ${malContraste[0].min}:1, «${malContraste[0].txt}»)`);

/* --- E6 · anatomia -------------------------------------------------------- */
if (rolesFaltan.length)
  fallos.push(`ANATOMIA · faltan roles obligatorios de «${TIPO}»: ${rolesFaltan.join(', ')}`);
if (TIPO_RARO)
  fallos.push(`ANATOMIA · data-tipo="${TIPO_RARO}" no esta en la tabla (references/anatomy.tsv): ` +
              `no se ha comprobado NINGUNA anatomia`);
if (PERFIL.cierre && ultimo && ultimo.ctas === 0)
  fallos.push(`ANATOMIA · el ultimo bloque («${ultimo.que}») no tiene ninguna accion: ` +
              `falta el rol «cierre», obligatorio en las 11 anatomias`);

/* --- E7 · hero que convierte, no que enlaza ------------------------------ */
if (PERFIL.hero) {
  if (!accHero.length) {
    fallos.push(`HERO · sin ninguna accion en la primera altura de viewport ` +
                `(pliegue en ${innerHeight}px; ${accBloque1.length} accion(es) en el bloque 1)`);
  } else {
    const conv = accHero.filter(convierte);
    const prim = accHero.filter(primaria);
    if (!conv.length && !CFG.ecommerce)
      fallos.push(`HERO · ${accHero.length} accion(es) y ninguna es mecanismo de conversion: ` +
                  `es un hero que ENLACA, no que convierte`);
    if (prim.length >= 2)
      fallos.push(`HERO · ${prim.length} acciones primarias del mismo peso visual (maximo 1)`);
  }
}

/* --- E8 · enlaces internos contextuales ---------------------------------- */
if (enlacesInternos.length < PERFIL.minEnlaces)
  fallos.push(`ENLACES · ${enlacesInternos.length} enlace(s) internos de CUERPO ` +
              `(minimo ${PERFIL.minEnlaces} para «${TIPO}»). El nav no cuenta`);

/* --- AVISOS · 2 o mas hacen FALLA ---------------------------------------- */
if (banda.length > 12)    avisos.push(`${banda.length} tamanos de fuente en la banda de texto 11-28px (aviso >12; el contrato son 6)`);
// >2, no >0: en las 12 referencias medidas la mediana es 0 pero basecamp tiene 1
// y anthropic 2. Avisar a partir de 1 marcaria sitios mejores que el nuestro.
// Nuestra mediana es 7 y site-b llega a 15, asi que >2 separa igual.
if (saltosCiegos > 2)     avisos.push(`${saltosCiegos} saltos tipograficos <1,08x: imperceptibles y hay que mantenerlos (aviso >2)`);
if (espaciados.size > 20) avisos.push(`${espaciados.size} valores de espaciado distintos (aviso >20; el contrato son 6)`);
// El suelo de 45 cpl es una regla de ESCRITORIO. A 390px la columna la fija el
// aparato: medido, una guia correcta da 40 cpl en movil y eso no es un defecto,
// es un telefono. En movil solo se vigila el techo.
if (cplMediana !== null && lectura.length >= 3 && (cplMediana > 90 || (!MOVIL && cplMediana < 45)))
  avisos.push(`longitud de linea mediana ${cplMediana} cpl en ${lectura.length} parrafos de lectura, ` +
              `fuera del rango ${MOVIL ? '(techo 90, movil)' : '45-90'}`);
// ⚠️ NO MEDIDO NO ES APROBADO. Antes esto era una `nota` y no dejaba rastro en
// el veredicto: `molde-home-roto.html` salia PASA con `cplMediana: null` estando
// rota, porque ningun parrafo suyo llega a 200 caracteres y la unica medida de
// anchura que habia no llego a correr. Una pagina no supera la medida de H3 por
// esquivarla. Es AVISO y no FALLO a proposito: hay paginas legitimamente sin
// columna de lectura (una home de tarjetas), y ahi ANCHO-MIN es quien mide.
// `legal` se queda en `lectura:true` a proposito: una politica de privacidad
// SI es prosa larga, y si no tiene parrafos de lectura es que esta a medias.
if (PERFIL.lectura !== false && lectura.length < 3)
  avisos.push(`mediana de cpl NO calculada: ${lectura.length} parrafo(s) de lectura (>=200 caracteres), ` +
              `hacen falta 3. El techo de 80 cpl si se ha medido, sobre ${cpls.length} bloque(s) de texto` +
              (cpls.length === 0
                 ? ' — es decir, sobre NINGUNO: la pagina no ha superado la medida de H3, se la ha esquivado entera'
                 : ''));
// bloques>=4: con 1 o 2 bloques el cociente es 100 % por construccion y no
// informa de nada. Sin este suelo, TODA pagina de un solo bloque (un aviso
// legal) arrancaba con un aviso regalado — y con el aviso nuevo de arriba
// sumaba 2 y fallaba sin tener un solo defecto.
if (bloques.length >= 4 && sinMedia / bloques.length >= 0.75)
  avisos.push(`${sinMedia}/${bloques.length} bloques sin una sola imagen ni svg (aviso >=75 %)`);
if (primitivas.length <= 2 && PERFIL.estructura)
  avisos.push(`variedad efectiva de ${primitivas.length} primitivas`);

if (avisos.length >= 2) fallos.push(`AVISOS · ${avisos.length} avisos simultaneos (2 bastan para fallar)`);

// NOTAS: se informan, NO cuentan para el veredicto. Un aviso que salta en el
// 100 % de la poblacion no aporta informacion, solo ruido — y hoy NINGUNA
// pagina nuestra declara `data-sec` (09 §«pendiente»). Si contase, el gate
// fallaria por eso solo en todas partes y se desactivaria en una semana.
const notas = [];
if (PERFIL.estructura && !rolesDeclarados.length)
  notas.push('sin `data-sec`: la anatomia por ROL no se ha comprobado (solo el cierre). ' +
             'Es informativo, no cuenta para el veredicto');
if (document.querySelector('main') === null) notas.push('la pagina no tiene <main>: se ha medido <body> menos nav/header/footer');
// TODA regla que NO se ejecuta se dice. Ese fue el defecto que trajo ANCHO-MIN:
// una comprobacion que no corre se lee igual que una que aprueba.
if (!juzgaAncho)
  notas.push(`ANCHO-MIN NO comprobado: innerWidth ${innerWidth} < ${VIEWPORT_ANCHO}px. ` +
             `A esta anchura una rejilla correcta ya ha colapsado y la celda estrecha es el aparato`);
else if (!WRAP)
  notas.push('ANCHO-MIN (contenedor) NO comprobado: el sitio no declara ningun token de ancho ' +
             '(--ancho/--wrap/--contenedor/...). La regla de CELDA si se ha comprobado');
if (contrasteSobreFoto)
  notas.push(`CONTRASTE: ${contrasteSobreFoto} elemento(s) sobre imagen o degradado, NO MEDIBLES sin ` +
             `leer el pixel (measure-contrast-on-photo.py). No medible NO es aprobado`);

/* ------------------------------------------------------------------------ */
return JSON.stringify({
  url: (location.protocol === 'file:' ? '(copia local) ' : '') + ORIGEN + RUTA,
  innerWidth,                      // ⚠️ COMPROBAR ESTE PRIMERO. Si no es el que
  innerHeight,                     //    se pidio, la medicion se tira entera.
  tipo: TIPO + ' (' + TIPO_FUENTE + ')',
  VEREDICTO: fallos.length ? 'FALLA' : 'PASA',
  // La pregunta de Manuel («esto es un articulo de blog disfrazado de pagina»)
  // se contesta SOLA, sin leer la lista de fallos. Separarla importa: un aviso
  // legal a 85 cpl falla por ANCHO y NO es una pagina-prosa; una guia con la
  // columna perfecta y 36 parrafos sueltos SI lo es.
  // Solo PROSA-*. VARIEDAD queda FUERA a proposito: un repertorio pobre (3
  // primitivas) es otro defecto, no «un articulo de blog disfrazado de pagina».
  // Meterlas juntas hacia que la home de site-d saliera marcada como prosa
  // sin tener un solo bloque de prosa.
  esPaginaProsa: !!(PERFIL.estructura &&
                    (maxHermanosP >= 8 || pctProsa >= 0.30 ||
                     (conEstruct === 0 && bloques.length >= 4))),
  fallos,
  avisos,
  avisosMovil,
  notas,
  resumen: {
    bloques: bloques.length,
    comoSeDetectaron: bloques.reduce((a, b) => (a[b.fuente] = (a[b.fuente] || 0) + 1, a), {}),
    bloquesProsa: `${nProsa}/${bloques.length} = ${(pctProsa * 100).toFixed(1)} %`,
    maxHermanosP,
    primitivas,
    bloquesConEstructura: `${conEstruct}/${bloques.length}`,
    bloquesSinMedia: `${sinMedia}/${bloques.length}`,
    cplMediana, parrafosDeLectura: lectura.length, parrafosMedidos: cpls.length,
    parrafosSobre80: cplMalos.length, peoresCPL: cplMalos.slice(0, 3),
    anchoDeclarado: WRAP ? `${WRAP.token}: ${WRAP.valor} = ${WRAP.px}px` : null,
    anchoSuelo: (juzgaAncho && WRAP) ? Math.round(RATIO_WRAP * WRAP.px) : null,
    contenedoresPorBloque: anchoBloques.map(a => a.contW),
    celdaMasEstrecha: anchoBloques.reduce((m, a) => a.celdaMin !== null &&
                                    (m === null || a.celdaMin < m) ? a.celdaMin : m, null),
    contrasteMedidos, contrasteSobreFoto,
    peoresContrastes: malContraste.slice(0, 3),
    tamanosDeFuenteEnBanda: banda.length, saltosCiegos, valoresDeEspaciado: espaciados.size,
    pliegue: innerHeight,
    heroAcciones: accHero.length, accionesDelBloque1: accBloque1.length,
    heroConversion: accHero.filter(convierte).map(a => a.getAttribute('href') || a.tagName),
    enlacesInternosDeCuerpo: enlacesInternos.length,
    rolesDeclarados,
  },
  bloques: ficha,
}, null, 1);
})()

/* =============================================================================
 *  LOS UMBRALES, Y DE DONDE SALE CADA UNO
 * =============================================================================
 *  Un umbral inventado convierte el gate en una opinion con autoridad falsa.
 *  Los que son juicio mio van marcados PROVISIONAL, no disfrazados de medida.
 *
 *  | id       | umbral                        | de donde sale                     |
 *  |----------|-------------------------------|-----------------------------------|
 *  | PROSA-1  | <8 <p> hermanos               | MEDIDO. Paginas-prosa: 55 y 36    |
 *  |          |                               | (climentmedia /learn/, site-c).     |
 *  |          |                               | Maquetadas: 1, 2, 3, 4 y 7. El    |
 *  |          |                               | hueco entre 7 y 36 es la frontera |
 *  | PROSA-3  | <30 % de bloques-prosa,       | MEDIDO. site-c 53,8 · learn-roas    |
 *  |          | contando como prosa solo los  | 37,5 · site-a-services 28,6 · site-a- |
 *  |          | bloques de >=600 caracteres   | home 27,3 · cm-home 0 · cm-ads 0  |
 *  |          | Y >=3 <p> sueltos             | · mob-home 0. El 30 % cae en el   |
 *  |          |                               | hueco 28,6→37,5. Deja pasar a     |
 *  |          |                               | site-a A PROPOSITO: un gate que     |
 *  |          |                               | falla todo se desactiva.          |
 *  |          |                               | ⚠️ Los suelos 600/3 se anadieron  |
 *  |          |                               | tras el control F2: sin ellos el  |
 *  |          |                               | hero y el cierre —OBLIGATORIOS en |
 *  |          |                               | toda pagina— contaban como prosa  |
 *  |          |                               | y regalaban un 28,6 % a cualquier |
 *  |          |                               | pagina bien hecha. Hueco medido:  |
 *  |          |                               | legitimos 84-446 car. / 0-2 <p> · |
 *  |          |                               | prosa real 802-3523 / 4-25        |
 *  | PROSA-2  | >=1 bloque con estructura     | MEDIDO. ads-assistant 0/4 y       |
 *  |          |   si hay >=4 bloques          | learn-roas 0/8 wrappers.          |
 *  |          |                               | ⚠️ CORREGIDO: cuentan tambien     |
 *  |          |                               | <table> 2x2, >=3 <details> y <dl> |
 *  |          |                               | de >=3 — si no, los moldes 04,    |
 *  |          |                               | 08, 15 y 18 (maqueta pura) darian |
 *  |          |                               | falso positivo                    |
 *  | VARIEDAD | >=4 primitivas distintas      | 🟡 PROVISIONAL. Es la regla       |
 *  |          |   (2-3 en tipos textuales)    | escrita en 10-vocabulario §2.3.   |
 *  |          |                               | El DATO que la sostiene es que    |
 *  |          |                               | prosa+grid-tarjetas = 44 % de     |
 *  |          |                               | nuestras secciones y la variedad  |
 *  |          |                               | efectiva era 2 en 5 de 7 paginas. |
 *  |          |                               | Que el suelo sea 4 y no 3 o 5 es  |
 *  |          |                               | JUICIO MIO, no una medicion.      |
 *  |          |                               | ⚠️ Se usa solo como SUELO, nunca  |
 *  |          |                               | como exoneracion: site-c-home tiene |
 *  |          |                               | 6 primitivas y es la peor del     |
 *  |          |                               | lote. Por eso VARIEDAD no puede   |
 *  |          |                               | cancelar PROSA-1 ni PROSA-3       |
 *  | ANCHO    | 0 parrafos >80 cpl,           | NORMA. WCAG 2.1 SC 1.4.8 (AAA):   |
 *  |          | midiendo la LINEA REAL        | «no more than 80 characters».     |
 *  |          | (biseccion sobre el salto de  | Butterick: 45-90. Mismo UMBRAL    |
 *  |          | linea), no la teorica         | que el gate de 11-medidas §7,     |
 *  |          |                               | a proposito — pero MEJOR METODO:  |
 *  |          |                               | aquel usa canvas (ancho / ancho   |
 *  |          |                               | medio de caracter), que da los    |
 *  |          |                               | caracteres que CABRIAN. La linea  |
 *  |          |                               | real rompe en un espacio y es mas |
 *  |          |                               | corta: verificado en 13 parrafos  |
 *  |          |                               | de 3 paginas, canvas daba hasta   |
 *  |          |                               | 13 caracteres de mas, SIEMPRE al  |
 *  |          |                               | alza. Las cifras de 11-medidas    |
 *  |          |                               | §7 son el TECHO, no la linea      |
 *  |          |                               | ⚠️ Hay que contar el texto        |
 *  |          |                               | RENDERIZADO: los saltos de linea  |
 *  |          |                               | e indentacion del HTML colapsan   |
 *  |          |                               | en pantalla pero cuentan en el    |
 *  |          |                               | indice del nodo de texto (daban   |
 *  |          |                               | 90 caracteres a un parrafo de 95) |
 *  | ANCHO-MIN| celda de rejilla >=240px       | MEDIDO. Se midio la celda mas    |
 *  | (celda)  |   con innerWidth >=1200px      | estrecha de LOS 19 MOLDES a      |
 *  |          |                               | 1422px, contando como celda solo  |
 *  |          |                               | la que lleva >=20 caracteres de   |
 *  |          |                               | texto (una tira de logos es       |
 *  |          |                               | legitimamente estrecha):          |
 *  |          |                               |   250 (05-pasos, 4 col)           |
 *  |          |                               |   250 (06-banda, 4 col)           |
 *  |          |                               |   256 (11-cierre)                 |
 *  |          |                               |   357 (09, 10, 16 · 3 col)        |
 *  |          |                               |   372-373 (03, 14, 01)            |
 *  |          |                               |   528-540 (02, 07 · 2 col)        |
 *  |          |                               | y la rota `molde-home-roto`:      |
 *  |          |                               |   173 (li.tj) y 189 (article.cel) |
 *  |          |                               | El hueco 189 -> 250 es limpio y   |
 *  |          |                               | 240 cae dentro. La aritmetica del |
 *  |          |                               | contrato coincide: a --wrap 1120  |
 *  |          |                               | con gap --e3 24px, 4 columnas dan |
 *  |          |                               | (1120-72)/4 = 262px, y el         |
 *  |          |                               | repertorio no pasa de 4 columnas  |
 *  |          |                               | en escritorio.                    |
 *  |          |                               | ⚠️ MARGEN CORTO: solo 10px por    |
 *  |          |                               | debajo del suelo legitimo. Si     |
 *  |          |                               | algun molde futuro baja de 250,   |
 *  |          |                               | hay que volver a medir, no subir  |
 *  |          |                               | el umbral a ojo                   |
 *  | ANCHO-MIN| contenedor >=75 % del ancho    | 🟡 PROVISIONAL EN EL RATIO.       |
 *  | (contene-|   que declara el propio sitio, | MEDIDO: la home rota da 568px de  |
 *  |  dor)    |   y SOLO en secciones con      | contenedor contra 1120 declarados  |
 *  |          |   rejilla                     | = 0,507. Correcta: 1,00. Cualquier|
 *  |          |                               | corte entre 0,51 y 1,00 separa    |
 *  |          |                               | los dos casos, asi que QUE SEA    |
 *  |          |                               | 0,75 ES JUICIO MIO, no una        |
 *  |          |                               | medicion.                         |
 *  |          |                               | Dos cautelas deliberadas:         |
 *  |          |                               | (a) exige un TOKEN declarado      |
 *  |          |                               | (--ancho/--wrap/...). Sin token   |
 *  |          |                               | se dice «no comprobado»: inferir  |
 *  |          |                               | el ancho del maximo medido        |
 *  |          |                               | convertiria en fallo el diseno    |
 *  |          |                               | legitimo de hero ancho + cuerpo   |
 *  |          |                               | estrecho.                         |
 *  |          |                               | (b) solo juzga secciones CON      |
 *  |          |                               | REJILLA. Una seccion de solo      |
 *  |          |                               | texto debe ser estrecha: el molde |
 *  |          |                               | 08 lo dice por escrito («un FAQ   |
 *  |          |                               | a 1120px da lineas de 140         |
 *  |          |                               | caracteres»). Verificado: en la   |
 *  |          |                               | home arreglada el FAQ se queda a  |
 *  |          |                               | 544px y NO se le acusa            |
 *  | CONTRASTE| >=4,5:1 texto normal,         | NORMA. WCAG 2.1 SC 1.4.3 (AA),    |
 *  |          | >=3:1 texto grande            | incluida la excepcion de texto    |
 *  |          | (>=24px, o >=18,66px negrita) | grande. Solo sobre COLOR PLANO:   |
 *  |          |                               | sobre foto o degradado se cuenta  |
 *  |          |                               | aparte como NO MEDIBLE, que no    |
 *  |          |                               | es lo mismo que aprobado.         |
 *  |          |                               | VERIFICADO contra valores         |
 *  |          |                               | publicados en                     |
 *  |          |                               | `contraste-control.html`:         |
 *  |          |                               | #999999/blanco = 2,85:1 y         |
 *  |          |                               | #6b7280/blanco = 4,83:1 (gray-500 |
 *  |          |                               | de Tailwind). Los dos coinciden.  |
 *  |          |                               | ⚠️ El control tiene los 4 casos   |
 *  |          |                               | que DEBEN fallar y los 4 que      |
 *  |          |                               | DEBEN pasar, y se ha visto en     |
 *  |          |                               | ROJO: una regla que solo se ha    |
 *  |          |                               | visto en verde no prueba nada     |
 *  | ESCALA   | aviso >12 tamanos en banda,   | MEDIDO. Mediana de 12 sitios de   |
 *  |          | aviso >20 espaciados,         | referencia: 5 escalones y 0       |
 *  |          | aviso >2 saltos <1,08x        | saltos ciegos, PERO basecamp      |
 *  |          |                               | tiene 1 y anthropic 2: avisar a   |
 *  |          |                               | partir de 1 marcaria sitios       |
 *  |          |                               | mejores que el nuestro.           |
 *  |          |                               | Nuestra mediana: 10,5 y 7.        |
 *  |          |                               | site-b: 18 y 15.                 |
 *  |          |                               | El contrato de `_tokens.css` son  |
 *  |          |                               | 6 y 6; el gate avisa a 12 y 20    |
 *  |          |                               | (aviso, no falla) porque la       |
 *  |          |                               | cuenta en runtime incluye         |
 *  |          |                               | defaults del navegador y no es    |
 *  |          |                               | comparable 1:1 con la del CSS     |
 *  | ANATOMIA | roles OBL de 09 §2            | DOCUMENTADO. Solo se comprueba    |
 *  |          |                               | si la pagina declara `data-sec`;  |
 *  |          |                               | si no, se dice que NO se ha       |
 *  |          |                               | comprobado (hoy no lo declara     |
 *  |          |                               | ninguna pagina nuestra). Lo que   |
 *  |          |                               | SI se comprueba siempre: que el   |
 *  |          |                               | ultimo bloque tenga accion        |
 *  | HERO     | >=1 accion, >=1 de conversion,| DOCUMENTADO + MEDIDO. 09 §3 con   |
 *  |          | <=1 primaria                  | los 5 heroes: cm ✅ · bc ✅ ·      |
 *  |          |                               | site-c ✅ · site-a ⚠️ · site-b ❌     |
 *  |          |                               | (sus dos acciones son navegacion).|
 *  |          |                               | `ecommerce:true` exime, y         |
 *  |          |                               | entonces la obligacion la hereda  |
 *  |          |                               | el catalogo (09 §3, excepcion 1)  |
 *  | ENLACES  | >=3 internos de cuerpo        | 🟡 PROVISIONAL, y DELIBERADAMENTE |
 *  |          |                               | POR DEBAJO del modelo. 12-enlazado|
 *  |          |                               | pide 1 al hub + 2-5 hermanos + 1  |
 *  |          |                               | a conversion = 4-7. El gate exige |
 *  |          |                               | 3 porque es un SUELO, no el       |
 *  |          |                               | objetivo. `web-page-standard      |
 *  |          |                               | §PASO 0.3` («minimo dos, el nav   |
 *  |          |                               | no cuenta») habla de ENTRANTES,   |
 *  |          |                               | que este gate no puede ver: una   |
 *  |          |                               | sola pagina no sabe quien la      |
 *  |          |                               | enlaza. Eso lo mide               |
 *  |          |                               | `linking-gate.pl`                |
 *  | AVISOS   | 2 avisos = FALLA              | MEDIDO (marco del diagnostico).   |
 *  |          |                               | Ninguno basta solo: los seis son  |
 *  |          |                               | senales debiles y cualquiera da   |
 *  |          |                               | falsos positivos por su cuenta    |
 *
 *  QUE SE JUZGA A 390px Y QUE NO
 *  -----------------------------
 *  Con `innerWidth < 640`, PROSA-2, PROSA-3 y VARIEDAD pasan a `avisosMovil` y
 *  NO cuentan para el veredicto (ni para la regla de los 2 avisos). Motivo
 *  medido, no prudencia: `contenedor2D` exige >=2 COLUMNAS, y a 390 un
 *  par-alterno correcto colapsa a una — la pagina compuesta de moldes baja de 4
 *  primitivas a 3 solo por estrechar la ventana. Juzgar ahi seria penalizar
 *  hacer bien el movil.
 *  SI se juzgan a 390, porque no dependen de la anchura: PROSA-1, ANCHO,
 *  ANATOMIA, HERO y ENLACES. Verificado: la pagina-prosa fabricada FALLA
 *  tambien a 390 (33 <p> hermanos), y las tres bien maquetadas PASAN.
 *  El suelo de 45 cpl no se aplica en movil: a 390 una guia correcta da 40 cpl
 *  y eso es el aparato, no un defecto. En movil solo se vigila el techo de 90.
 *
 *  EXIMIR POR TIPO NO ES UNA CONCESION, ES EL DISENO
 *  -------------------------------------------------
 *  `legal` y `404` tienen `estructura:false`: un aviso legal es prosa a
 *  proposito (09 §2.11 — «sin anatomia y sin CTAs»). Acusarlo de ser prosa
 *  seria el falso positivo que desactiva un gate para siempre.
 *  Lo que NO se exime a nadie es el ANCHO: la legibilidad no depende del tipo,
 *  y un aviso legal a 110 cpl es igual de ilegible que una guia.
 *
 *  LO QUE ESTE GATE NO VE, DICHO
 *  -----------------------------
 *  · Enlaces ENTRANTES y huerfanas → `crawl-links.pl` + `linking-gate.pl`.
 *  · Cuanto ocupa y donde caen los CTAs → `measure-screens.js`.
 *  · Contraste SOBRE FOTO O DEGRADADO: hay que leer el pixel
 *    (`measure-contrast-on-photo.py`). Aqui se cuentan y se declaran NO
 *    MEDIBLES en `notas` — no medible NO es aprobado. Sobre color plano SI se
 *    mide (§4c), resolviendo el color con `color-mix(in srgb, ...)` porque
 *    `getComputedStyle` devuelve el espacio de origen (`oklch(...)`) cuando el
 *    autor no escribio el color en rgb/hex.
 *  · Si lo que pone TIENE SENTIDO. El gate dice donde mirar, no si esta bien.
 *  · Paginas que montan el cuerpo con JS (shop.site-b.example): si se mide el HTML
 *    servido, las rejillas salen vacias y la pagina parece prosa. Medir el DOM
 *    renderizado, o declararlo no medible. Un cero puede ser del instrumento.
 *
 *  ⚠️ SE MIDE EN LAS DOS ANCHURAS, y `innerWidth` va lo primero en la salida a
 *  proposito. Chrome headless en Windows CLAMPA `--window-size` a ~500px: para
 *  medir a 390 hay que cargar la pagina en un <iframe width=390> (con
 *  `--allow-file-access-from-files`) o declararlo NO VERIFICADO.
 * ========================================================================== */
