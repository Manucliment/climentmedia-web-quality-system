// =============================================================================
//  GATE DE MOVIL  ·  ¿puede el visitante ACTUAR desde el telefono?
//  20-ago-2026 · se corre con run-gate.js, a 390x844
// =============================================================================
//
//  🔴 POR QUE EXISTE. Lo encontro Manuel abriendo site-a.example en su movil:
//  el cromo flotante caia encima de los botones del hero. Ninguno de los gates
//  que teniamos podia verlo, y no por descuido -- por CATEGORIA:
//
//    measure-screens.js  cuenta CTAs      -> gate de PRESENCIA
//    structure-gate.js  mide contraste   -> gate de COLOR
//    qa-maestro A11Y-12  mide el tamano   -> gate de GEOMETRIA
//
//  Los tres contestan que si. Ninguno pregunta SI ENCIMA HAY ALGO. Mi primera
//  medicion dijo "primer CTA a 0,6 pantallas, sobre el pliegue": cierto en el
//  DOM y falso en pantalla. Es la misma familia que los seis botones invisibles
//  del 20-ago (07-trampas §67): un gate de presencia jamas desmiente a otro
//  gate de presencia.
//
//  🔴 Y LA SEGUNDA MITAD: LO QUE TAPA APARECE TARDE. El popup de site-a sale a
//  los 1800 ms (`data-delay`). Un gate que mide al terminar de cargar NO LO VE
//  NUNCA. Este espera a que el cromo flotante se ESTABILICE, y lo declara.
//
//  QUE COMPRUEBA, y de donde sale cada regla:
//
//    M1  Hay una accion sobre el pliegue, y NO esta tapada.
//        Regla del estandar, `09-tipos-de-pagina.md` §2 fila `hero`:
//        "Sin accion sobre el pliegue, el 60% que solo ve esto no tiene que
//        hacer". Estaba escrita y no la comprobaba nadie.
//        🔴 1-nov-2026 · Y TIENE QUE SER LA DE CONVERTIR, ENTERA A LA VISTA. Una
//        web de reservas salio con sus botones por debajo del primer pantallazo
//        y el del hero llevando a otra pagina en vez de a reservar. Este gate
//        daba PASA a cualquier `.btn` cuyo borde SUPERIOR asomara (`top < vh`) y
//        solo se corria a 390. Ahora, en los tipos cuyo hero convierte (los
//        `hero:true` de structure-gate.js: home, servicio, ciudad, ficha,
//        precios, landing) hace falta una accion que CONVIERTA -la regla del
//        bloque CONVIERTE, la misma de structure-gate- con su caja ENTERA dentro
//        del primer pantallazo y sin nada encima. La puerta lo corre a 360x740,
//        390x844, 1366x768 y 1440x900. Lo flotante (fixed/sticky) no cuenta: es
//        cromo, esta en todas las paginas, como el boton de la cabecera.
//
//    M2  CERO CTAs tapados por cromo flotante, esten donde esten.
//        Regla NUEVA (no estaba escrita en ningun sitio). Se anade tambien a
//        la documentacion: un boton que no se puede pulsar no es un boton.
//
//    M3  El cromo flotante no se come mas de un tercio de la pantalla.
//        AVISO, no fallo: 33% es un tope de sentido comun, NO una medida
//        contra referencias. Mientras no haya banco de referencia, no bloquea.
//
//    M4  La pagina no se mueve de lado: si se puede desplazar en horizontal,
//        FALLO, con quien se sale y el arreglo probable. Recortado por overflow
//        oculto, AVISO. Una tabla en su propia caja con scroll, nada.
//
//  EL TESTIGO ES `elementFromPoint`, y se elige a proposito: es exactamente lo
//  que el navegador usa para decidir donde va un dedo. No es una heuristica de
//  rectangulos: es la respuesta del propio motor.
// =============================================================================
(async () => {
  const CFG = Object.assign({
    // 🔴 SUELO DE ESPERA, y esta linea nacio de un fallo de este mismo gate.
    // La primera version solo esperaba a que lo flotante se ESTABILIZARA. En
    // site-a salio estable a los 911 ms -- el banner de cookies ya estaba -- y
    // devolvio PASA sobre el popup, que sale a los 1800 ms. O sea: cazo la
    // mitad del defecto y firmo la otra mitad como buena, que es exactamente
    // lo que el comentario de arriba dice que hay que evitar.
    // "Estable" no significa "terminado" cuando algo esta esperando un reloj.
    esperaMin: 3000,       // por debajo de esto NO se concluye nada
    esperaMax: 8000,       // techo duro
    estableMs: 900,        // sin cambios este rato, PASADO el suelo = terminado
    topeFlotante: 33,      // % de viewport; AVISO, no fallo
    // 🔴 APAGADO A PROPOSITO. Hay DOS visitantes y ven pantallas distintas:
    //    A · primera visita        -> banner de cookies
    //    B · el que ya acepto      -> el popup de conversion, que el banner
    //                                 estaba tapando
    // El defecto que Manuel vio en site-a era el B. Para medirlo hay que PULSAR
    // "aceptar", y eso es una ACCION: un gate que corre en cada despliegue no
    // debe ir aceptando banners de consentimiento por su cuenta. Se enciende a
    // mano cuando se quiere medir ese escenario:
    //    run-gate.js <URL> 390 844 mobile-gate.js '{"trasConsentimiento":true}'
    // ⚠️ Y si esta apagado, el informe DICE que solo ha mirado el escenario A.
    // Un gate que mide media pantalla y no lo declara se lee como si mirara todo.
    trasConsentimiento: false,
    // Ancho que se PIDIO. Lo inyecta `run-gate.js` en cada corrida; el 390 de
    // aqui es solo el que se usa si alguien ejecuta el gate a mano.
    anchoPedido: 390,
    // Lo mismo que en structure-gate.js: una tienda puede llevar el hero al
    // catalogo (09 §3.1), y M1 acepta entonces cualquier accion. La puerta lo
    // pasa si deploy.conf declara ECOMMERCE=1.
    ecommerce: false,
    // Plataformas de reserva propias de la web, ademas de HOSTS_RESERVA_BASE.
    // La puerta las pasa desde HOSTS_RESERVA= de deploy.conf.
    hostsReserva: [],
    origen: null
  }, (typeof window !== 'undefined' && window.__GATE__) || {});

  const esperar = ms => new Promise(r => setTimeout(r, ms));
  const vw = innerWidth, vh = innerHeight;
  const dentro = (a, b) => a === b || a.contains(b) || b.contains(a);
  const BASE   = (document.querySelector('base') || {}).href || location.href;
  const ORIGEN = CFG.origen || (() => { try { return new URL(BASE).origin; }
                                        catch (e) { return location.origin; } })();

// ── CONVIERTE · que accion es un mecanismo de conversion ──────────────────────
//  🔴 BLOQUE IDENTICO en structure-gate.js y mobile-gate.js, de la linea de arriba
//  a la de cierre: el banco de mobile-gate (CONVIERTE-COPIA) los compara byte a
//  byte. Dos copias de una regla divergen (07-trampas §68); hasta que haya una
//  sola fuente, la copia que se aparte de la otra pone el banco en rojo.
//  1-nov-2026 · RESERVAR FUERA ES CONVERTIR. Una barberia que reserva en una
//  plataforma externa tenia su «Reservar» contado como un enlace mas, y su hero
//  como «un hero que ENLAZA»: la regla solo conocia tel:, mailto:, WhatsApp y
//  cuatro agendas. HOSTS_RESERVA_BASE son las plataformas conocidas; cada web
//  anade las suyas con HOSTS_RESERVA= en deploy.conf (llega en __GATE__.hostsReserva).
//  Una palabra sin punto casa con una etiqueta del host (treatwell -> treatwell.nl,
//  widget.treatwell.es); con punto, con ese host o un subdominio suyo.
//  Y LA HOJA DE RESERVA PROPIA: un ancla (#reservar) o un boton que abre un panel
//  (aria-controls, popovertarget, data-target) convierte si lo que abre recoge el
//  dato: un formulario, o un enlace o un iframe que convierten por si mismos.
const RE_CONVIERTE = /^tel:|^mailto:|wa\.me|whatsapp|calendly|cal\.com|typeform|hubspot|^https?:\/\/[^\/]*(book|meet)/i;
const RE_RUTA_CONV = /contact|contacto|audit|auditor|presupuesto|cita|reserv|book|boek|afspraak|offerte|rendez|demo|devis|rdv|quote|empez|start|signup|sign-up|registro|register|checkout|carrito|cart|comprar|apply|candidat|trial|prueba|merci|gracias/i;
const HOSTS_RESERVA_BASE = ['bjootify', 'treatwell', 'salonized', 'fresha', 'planity', 'booksy', 'setmore',
  'simplybook', 'timify', 'acuityscheduling', 'youcanbook', 'doctolib', 'vagaro', 'mindbodyonline',
  'phorest', 'uala', 'zenoti'];
const HOSTS_RESERVA = HOSTS_RESERVA_BASE.concat(
  (Array.isArray(CFG.hostsReserva) ? CFG.hostsReserva : String(CFG.hostsReserva || '').split(/[\s,]+/))
    .map(h => String(h).trim().toLowerCase().replace(/^https?:\/\//, '').replace(/\/.*$/, ''))
    .filter(Boolean));
function esHostReserva (href) {
  let u; try { u = new URL(href, BASE); } catch (e) { return false; }
  if (!/^https?:$/.test(u.protocol)) return false;
  const host = u.hostname.toLowerCase(), etiquetas = host.split('.');
  return HOSTS_RESERVA.some(h => h.includes('.') ? (host === h || host.endsWith('.' + h)) : etiquetas.includes(h));
}
// 1-nov-2026 · «la misma web» es el mismo SITIO, no el mismo origen: el alta de una aplicacion vive en
// app.<dominio>, y el barrido de las webs publicadas la daba por «otra web» (hero que ENLAZA, en falso).
// Dominio registrable aproximado: las dos ultimas etiquetas, o tres tras un sufijo corto de pais (co.uk).
function sitioDe (host) {
  const e = String(host || '').toLowerCase().split('.');
  const n = (e.length > 2 && e[e.length - 1].length === 2 && /^(co|com|org|net|gob|gov|ac|edu)$/.test(e[e.length - 2])) ? 3 : 2;
  return e.slice(-n).join('.');
}
function mismoSitio (u) {
  if (u.origin === ORIGEN) return true;
  let o; try { o = new URL(ORIGEN); } catch (e) { return false; }
  return /^https?:$/.test(u.protocol) && sitioDe(u.hostname) === sitioDe(o.hostname);
}
function convierteSolo (el) {
  if (el.tagName === 'IFRAME') return esHostReserva(el.src || '') || RE_CONVIERTE.test(el.getAttribute('src') || '');
  if (el.tagName === 'BUTTON' || el.tagName === 'INPUT') return !!el.closest('form');
  const h = el.getAttribute('href') || '';
  if (RE_CONVIERTE.test(h) || esHostReserva(h)) return true;
  if (h.charAt(0) === '#') return false;
  // en el mismo origen cuenta la ruta; en un subdominio hermano, tambien la consulta (?entrar=registro)
  try { const u = new URL(el.href, BASE);
        return mismoSitio(u) && RE_RUTA_CONV.test(u.pathname + (u.origin === ORIGEN ? '' : u.search)); }
  catch (e) { return RE_RUTA_CONV.test(h); }
}
function abreA (el) {
  const h = el.getAttribute('href') || '';
  let id = /^#./.test(h) ? h.slice(1) : '';
  if (!id) id = el.getAttribute('aria-controls') || el.getAttribute('popovertarget') ||
                (el.getAttribute('data-target') || el.getAttribute('data-bs-target') || '').replace(/^#/, '');
  if (!id) return null;
  try { return document.getElementById(decodeURIComponent(id.split(/\s+/)[0])); } catch (e) { return null; }
}
function convierte (el) {
  if (convierteSolo(el)) return true;
  const d = abreA(el);
  if (!d || d === el || d.contains(el)) return false;
  return !!(d.matches('form') || d.querySelector('form') ||
            [...d.querySelectorAll('a[href],iframe[src]')].some(convierteSolo));
}
// ── /CONVIERTE ────────────────────────────────────────────────────────────────

  const visible = el => {
    const r = el.getBoundingClientRect();
    if (r.width < 2 || r.height < 2) return false;
    const cs = getComputedStyle(el);
    return cs.visibility !== 'hidden' && cs.display !== 'none' && +cs.opacity > 0.05;
  };

  // Un CTA es lo que el visitante puede PULSAR para avanzar. Se reconoce por
  // clase (btn/button/cta/fab) o por protocolo (tel:/mailto:), que es lo mismo
  // que hace `measure-screens.js`: dos gates que cuentan cosas distintas por
  // "CTA" no se pueden comparar entre si.
  const esCTA = el => {
    const c = (el.getAttribute('class') || '').toLowerCase();
    if (/\b(btn|button|cta|fab)/.test(c)) return true;
    // 🔴 Un <button> DE VERDAD dentro de <main>, con texto y cuerpo, es una
    // accion aunque su clase no se llame `btn`. Salio midiendo
    // `site-b/a-medida.html`: el configurador entero esta hecho de
    // `<button class="choice">` y el gate la acusaba de "no tiene NI UN CTA"
    // teniendo cuatro sobre el pliegue. Una pagina hecha de botones acusada de
    // no tener ninguno.
    // Los filtros existen para no contar el cromo: el abridor del menu vive en
    // el <header> (fuera de <main>), y las cruces de cerrar no llegan a 40px ni
    // llevan texto.
    if (el.tagName === 'BUTTON') {
      const t = (el.innerText || '').replace(/\s+/g, ' ').trim();
      const r = el.getBoundingClientRect();
      if (t.length >= 2 && r.width >= 40) return true;
    }
    const h = (el.getAttribute('href') || '').toLowerCase();
    // 🔴 WhatsApp CUENTA. Se me habia quedado fuera, y en tres de las cinco
    // webs es LA accion de conversion: site-c manda todo a `wa.me`, site-b tiene
    // su enlace de WhatsApp en el hero de la FAQ y site-a lo usa de secundario.
    // Un gate que mide "puede actuar el visitante" y no ve el canal por el que
    // de verdad actua, mide otra cosa. Salio midiendo `site-b/faq.html`:
    // acusada de no tener accion teniendo una, en el hero y subrayada.
    return /^(tel:|mailto:|sms:)/.test(h) || /(wa\.me|api\.whatsapp\.com|web\.whatsapp\.com)/.test(h);
  };

  // Cromo flotante = lo que puede tapar: fixed o sticky, visible y con cuerpo.
  // Solo el ancestro mas alto de cada grupo, o se cuenta el mismo banner tres
  // veces (el div, su caja y sus botones) y el % sale inflado.
  const flotantes = () => {
    const out = [];
    document.querySelectorAll('body *').forEach(el => {
      const cs = getComputedStyle(el);
      if (cs.position !== 'fixed' && cs.position !== 'sticky') return;
      if (!visible(el)) return;
      const r = el.getBoundingClientRect();
      if (r.width * r.height < 400) return;
      // 🔴 SE FILTRA POR LA INTERSECCION REAL, NO SOLO POR LA VERTICAL.
      // La primera version solo miraba `bottom < 0 || top > vh`. Un cajon
      // lateral fuera de pantalla -- site-b tiene DOS, en left:390 con
      // translateX(343px) -- entraba en la lista como 343x844 y aparecia en el
      // informe como si tapara la pantalla entera. El area salia bien porque el
      // recorte ya estaba en el calculo, pero el INFORME mandaba a buscar un
      // overlay que no existe. Un dato de mas en un informe cuesta una tarde.
      const visW = Math.min(r.right, vw) - Math.max(r.left, 0);
      const visH = Math.min(r.bottom, vh) - Math.max(r.top, 0);
      if (visW <= 0 || visH <= 0) return;
      if (out.some(f => f.el.contains(el))) return;
      out.push({ el, cs, r, visW, visH });
    });
    return out;
  };

  // --- esperar a que el cromo flotante deje de cambiar -----------------------
  // Se mide la FIRMA de lo flotante (cuantos y con que geometria). Cuando no
  // cambia durante `estableMs`, ya no va a salir nada mas. Sin esto, el gate
  // mide una pantalla que el visitante nunca ve.
  const firma = () => flotantes().map(f =>
    f.el.tagName + (f.el.getAttribute('class') || '') + '|' +
    Math.round(f.r.top) + 'x' + Math.round(f.r.height)).join(';');
  let f0 = firma(), estableDesde = Date.now(), t0 = Date.now(), esperado = 0;
  const cambios = [];
  while (Date.now() - t0 < CFG.esperaMax) {
    await esperar(150);
    const f1 = firma();
    if (f1 !== f0) {
      cambios.push(Date.now() - t0);   // se apunta CUANDO aparecio cada cosa
      f0 = f1; estableDesde = Date.now();
    } else if (Date.now() - t0 >= CFG.esperaMin && Date.now() - estableDesde >= CFG.estableMs) break;
  }
  esperado = Date.now() - t0;

  // --- escenario B, solo si se pide: el visitante que ya acepto -------------
  let consentimiento = null;
  if (CFG.trasConsentimiento) {
    const btn = [...document.querySelectorAll('button,a')].find(b => {
      const t = (b.innerText || '').toLowerCase();
      return /tout accepter|accepter|aceptar todo|aceptar|accept all|accept|alles accepteren|akkoord/.test(t)
             && visible(b);
    });
    if (btn) {
      consentimiento = (btn.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 26);
      btn.click();
      // se vuelve a esperar entero: lo que el banner tapaba puede tardar
      const t1 = Date.now(); let f1 = firma(), est1 = Date.now();
      while (Date.now() - t1 < CFG.esperaMax) {
        await esperar(150);
        const f2 = firma();
        if (f2 !== f1) { cambios.push(esperado + (Date.now() - t1)); f1 = f2; est1 = Date.now(); }
        else if (Date.now() - t1 >= CFG.esperaMin && Date.now() - est1 >= CFG.estableMs) break;
      }
      esperado += Date.now() - t1;
    } else {
      consentimiento = '(no hay boton de aceptar)';
    }
  }

  // --- medir --------------------------------------------------------------
  const fl = flotantes();
  const pctFlotante = +fl.reduce((s, f) => s + f.visW * f.visH / (vw * vh) * 100, 0).toFixed(1);

  const main = document.querySelector('main') || document.body;
  const todos = [...main.querySelectorAll('a,button')].filter(e => esCTA(e) && visible(e));

  const estado = el => {
    const r = el.getBoundingClientRect();
    // Solo se puede preguntar por lo que esta EN pantalla. Lo de mas abajo se
    // evalua por su posicion, no por oclusion: tapar algo fuera de vista no es
    // taparlo, y decir que si seria un falso positivo garantizado.
    const enPantalla = r.bottom > 0 && r.top < vh;
    // tapadoPor: lo que hay sobre el CENTRO (lo que leen M1 y M2, como siempre).
    // tapadoParte: el centro esta libre pero otro punto del boton no. 1-nov-2026 ·
    // con solo el centro, un boton del hero con su borde de abajo bajo el aviso de
    // cookies (19 px de 78) pasaba. Se mira una rejilla de 3x3 al 20/50/80 % del
    // boton, dentro de la pantalla. En una esquina redonda el punto cae en el
    // fondo, que CONTIENE al boton: dentro() no lo cuenta, y la rejilla no acusa a
    // un boton pildora. Solo lo lee M2 (abajo dice cuando es fallo).
    let tapadoPor = null, tapadoParte = null;
    if (enPantalla) {
      const quien = e => e ? e.tagName + '.' + ((e.getAttribute('class') || '-').split(' ')[0]) : '(fuera del arbol)';
      const xs = [0.2, 0.5, 0.8].map(f => Math.min(Math.max(r.left + r.width * f, 1), vw - 1));
      const ys = [0.2, 0.5, 0.8].map(f => Math.min(Math.max(r.top + r.height * f, 1), vh - 1));
      const tapa = (x, y) => { const e = document.elementFromPoint(x, y); return !e || !dentro(el, e) ? { e } : null; };
      const c = tapa(xs[1], ys[1]);
      if (c) tapadoPor = quien(c.e);
      else {
        const otros = ys.flatMap(y => xs.map(x => tapa(x, y))).filter(Boolean);
        if (otros.length) tapadoParte = `${quien(otros[0].e)} (en parte: ${otros.length} de 9 puntos)`;
      }
    }
    return {
      txt: (el.innerText || el.getAttribute('aria-label') || '').replace(/\s+/g, ' ').trim().slice(0, 30),
      cls: (el.getAttribute('class') || '-').split(' ')[0],
      yDoc: Math.round(r.top + scrollY),
      pantallas: +((r.top + scrollY) / vh).toFixed(2),
      sobrePliegue: (r.top + scrollY) < vh,
      enPantalla, tapadoPor, tapadoParte, convierte: convierte(el)
    };
  };

  const info = todos.map(estado);
  const tapados = info.filter(c => c.tapadoPor);
  const utilesArriba = info.filter(c => c.sobrePliegue && !c.tapadoPor);
  const primero = info.filter(c => !c.tapadoPor).sort((a, b) => a.yDoc - b.yDoc)[0] || null;

  const fallos = [], avisos = [], notas = [];

  // 🔴 EL TIPO DE PAGINA MANDA SOBRE M1, y no es una concesion: es la diferencia
  // entre un gate que se usa y uno que alguien apaga. `site-c/aviso-legal` tiene
  // su primer CTA a 15,5 pantallas y ESTA BIEN -- una politica de privacidad no
  // lleva llamada a la accion. Acusarla seria un falso positivo garantizado, y
  // un gate que acusa en falso dos veces se degrada solo.
  // La pagina DECLARA su tipo (`data-tipo` en <main>), igual que en
  // structure-gate.js; si no lo declara, se infiere de la ruta y se DICE.
  const mainEl = document.querySelector('main');
  let tipo = mainEl && mainEl.getAttribute('data-tipo');
  let tipoDe = 'declarado en el marcado';
  if (!tipo) {
    const p = location.pathname.toLowerCase();
    if (/legal|privac|cookie|condi|terms|mentions|aviso/.test(p)) tipo = 'legal';
    else if (/gracias|merci|thanks|bedankt/.test(p)) tipo = 'gracias';
    // La portada (y la de cada idioma, /en/) es `home`: su hero convierte. Lo demas
    // sin declarar sigue en `otro`, que pide una accion y no que convierta: inferir
    // `servicio` de una ruta cualquiera acusaria a una guia sin `data-tipo`.
    else if (/^\/([a-z]{2}\/)?(index\.html?)?$/.test(p)) tipo = 'home';
    else tipo = 'otro';
    tipoDe = 'inferido de la ruta';
  }
  // 🔴 20-ago-2026 · `recurso` ESTA AQUI POR UN ERROR MIO, Y VALE LA PENA
  // CONTARLO. Primero exime por `noindex`, razonando que "a una noindex no
  // llega nadie desde una busqueda". Medido acto seguido: shop.site-b.example
  // entera es `noindex, nofollow` -- las 13 paginas, tambien en produccion --
  // asi que la regla acababa de eximir UNA TIENDA VIVA COMPLETA, y sus 7
  // paginas rotas pasaron a verde de golpe. El sintoma fue justo ese: siete
  // fallos que desaparecen a la vez sin tocar la web.
  // El razonamiento era estrecho: a una pagina se llega por anuncios, por
  // enlaces y desde la web principal, no solo desde una busqueda.
  // Lo que de verdad hay que eximir es la pagina que NO ES UN DESTINO -- un kit
  // de marca interno, una guia de estilo -- y eso NO se infiere: LO DECLARA la
  // pagina con `data-tipo="recurso"`. Declaracion explicita antes que
  // inferencia, igual que con el resto de `data-tipo`.
  const SIN_CTA_OBLIGATORIO = ['legal', 'gracias', 'recurso'];
  const exigeCTA = !SIN_CTA_OBLIGATORIO.includes(tipo);
  // Los tipos `hero:true` de structure-gate.js: su hero CONVIERTE, no enlaza (09 §3).
  // `empleo` (hero:'accion'), hub, guia, contacto, nosotros y `otro` piden una
  // accion, como antes. Una tienda (ecommerce) puede llevar el hero al catalogo.
  const HERO_CONVIERTE = ['home', 'servicio', 'ciudad', 'producto', 'ficha', 'precios', 'landing', 'quiz'];
  const exigeConversion = exigeCTA && HERO_CONVIERTE.includes(tipo) && !CFG.ecommerce;

  // --- M1 · lo que se ve ENTERO en el primer pantallazo ---------------------
  // Se mide sobre el documento (yDoc), no sobre la pantalla: si algo dejo la pagina
  // desplazada, el primer pantallazo sigue siendo 0..vh. Cuenta todo <a>/<button>
  // de <main> que sea CTA o que convierta (un «Reserveer» en texto llano tambien
  // es la accion), menos lo flotante.
  const flotanteDe = el => { for (let n = el; n && n.nodeType === 1; n = n.parentElement) {
    const p = getComputedStyle(n).position; if (p === 'fixed' || p === 'sticky') return true; } return false; };
  const candM1 = [...main.querySelectorAll('a[href],button,input[type=submit]')]
    .filter(e => visible(e) && !flotanteDe(e) && (esCTA(e) || convierte(e)))
    .map(el => {
      const r = el.getBoundingClientRect();
      const top = r.top + scrollY, bottom = r.bottom + scrollY;
      const e = estado(el);
      return Object.assign(e, {
        convierte: convierte(el),
        destino: (el.getAttribute('href') || (el.closest('form') ? '(formulario)' : '')).slice(0, 60),
        entero: top >= 0 && bottom <= vh && r.left >= 0 && r.right <= vw,
        asoma: top < vh && bottom > vh,
        bordeInferior: Math.round(bottom)
      });
    });
  const m1Validas = candM1.filter(c => c.entero && !c.tapadoPor && (!exigeConversion || c.convierte));

  // 🔴 ¿ES ESTO SIQUIERA UNA PAGINA? Un 404, un cascaron o un muro anti-bot dan
  // `ctas: 0` -- exactamente igual que una pagina real sin botones. Y el fallo
  // es silencioso: manda a arreglar una maqueta que no esta rota.
  // Salio midiendo site-d: mi bucle pidio `index.html/` con barra final, el
  // servidor devolvio 404 y el gate lo conto como FALLA de M1. La home estaba
  // perfecta. Se declara NO MEDIBLE, que no es un aprobado ni una acusacion.
  const cuerpoTxt = (document.body.innerText || '').replace(/\s+/g, ' ').trim();
  const secciones = document.querySelectorAll('main section, main > div, article').length;
  const pareceRoto = cuerpoTxt.length < 200 || (!document.querySelector('h1') && secciones === 0);

  // M1
  if (pareceRoto) {
    notas.push(`NO MEDIBLE: esto no parece una pagina (${cuerpoTxt.length} caracteres de ` +
      `texto, ${secciones} secciones, h1=${!!document.querySelector('h1')}). ` +
      `404, cascaron que monta JS, o muro anti-bot. NO se juzga la maqueta de esto.`);
  } else if (!exigeCTA) {
    notas.push(`M1 no aplica: tipo "${tipo}" (${tipoDe}) no exige accion sobre el pliegue`);
  } else if (!info.length && !candM1.length) {
    fallos.push('M1 · la pagina no tiene NI UN CTA: no hay nada que pulsar');
  } else if (!m1Validas.length) {
    // 🔴 "PROPIA DE LA PAGINA" no es un matiz: se cuenta solo lo que hay DENTRO
    // de <main>. Un boton en la cabecera pegajosa esta sobre el pliegue en las
    // 18 paginas del sitio por igual, asi que contarlo haria que TODAS pasaran
    // y el gate no diria nada. La regla del estandar (09 §3) es sobre el HERO:
    // "un hero que convierte, no uno que enlaza". El cromo no convierte.
    // Se dice en el fallo para que nadie lo lea como un falso positivo mirando
    // el boton del menu.
    // Y el fallo dice CUAL de las tres cosas falta, porque se arreglan distinto:
    // no hay ninguna que convierta (el hero enlaza), la hay pero cae debajo o
    // asoma cortada (la maqueta), o esta tapada (el cromo, que M2 detalla).
    const pantalla = `${vw}x${vh}`;
    const utiles = candM1.filter(c => !exigeConversion || c.convierte).sort((a, b) => a.yDoc - b.yDoc);
    const arribaQueEnlazan = candM1.filter(c => c.entero && !c.tapadoPor && !c.convierte);
    let d;
    if (!utiles.length) {
      d = `ninguna accion de la pagina CONVIERTE` +
          (arribaQueEnlazan.length ? ` (a la vista: ${arribaQueEnlazan.slice(0, 3).map(c => `«${c.txt}» -> ${c.destino}`).join(' · ')})` : '') +
          `: es un hero que ENLAZA, no que convierte (09 §3)`;
    } else {
      const u = utiles[0];
      d = u.tapadoPor ? `la primera que ${exigeConversion ? 'convierte' : 'sirve'}, «${u.txt}», esta TAPADA por ${u.tapadoPor}`
        : u.asoma ? `la primera que ${exigeConversion ? 'convierte' : 'sirve'}, «${u.txt}», ASOMA CORTADA: su borde inferior cae a ${u.bordeInferior}px y la pantalla acaba en ${vh}`
        : `la primera que ${exigeConversion ? 'convierte' : 'sirve'}, «${u.txt}», cae a ${u.pantallas} pantallas`;
    }
    fallos.push(`M1 · ninguna accion ${exigeConversion ? 'DE CONVERSION ' : ''}PROPIA DE LA PAGINA entera a la vista ` +
      `en el primer pantallazo (${pantalla}): ${d}` +
      ` (los CTA de cabecera/pie y lo flotante no cuentan: son cromo, estan en todas)`);
  }

  // M2 · no se juzga lo que no es una pagina
  //
  // 🔴 20-ago-2026 · POR QUE HAY DOS NIVELES, Y ES UNA CONCESION DELIBERADA.
  // La primera version marcaba FALLO cualquier CTA tapado. Medido en las cinco
  // webs, eso condena a TODA web con banner de consentimiento abajo: el banner
  // ocupa la ultima banda del viewport y cualquier boton que caiga ahi al
  // cargar sale tapado -- aunque baste desplazar 200px para descubrirlo, porque
  // el banner es `fixed` y el contenido se mueve por debajo.
  // Ejemplo real: site-d /contacto/ tiene sus dos botones de hero en y=345 y
  // y=408 -- perfectos -- y lo tapado era "Abrir en Google Maps" a y=773.
  //
  // Lo que de verdad importa, y es lo que vio Manuel, es el HERO: si el
  // visitante aterriza y la accion principal esta debajo de una caja, eso es un
  // defecto de conversion. Un boton mas abajo tapado al cargar es molesto, no
  // roto.
  //   FALLO -> el CTA tapado esta en el HERO (la accion principal, al aterrizar)
  //   AVISO -> tapado en cualquier otro sitio
  // 1-nov-2026 · tapado EN PARTE (el centro libre, el borde no; ver estado()):
  //   FALLO -> en el hero y es el que CONVIERTE (un sitio de servicio a domicilio: «Llamar», 19 px bajo el aviso)
  //   AVISO -> en el hero y solo enlaza (un sitio de software: «See pricing», 3 de 9
  //            puntos bajo el aviso): la accion principal no es esa
  //   fuera del hero, en parte, no se dice: ni el tapado entero alli es fallo.
  // ⚠️ Un gate que nunca se puede satisfacer es un gate que alguien apaga. Esto
  // NO es bajar el liston: es apuntarlo a lo que se puede y se debe arreglar.
  const enParte = info.filter(c => c.tapadoParte);
  if ((tapados.length || enParte.length) && !pareceRoto) {
    const enHero = c => {
      const el = [...(document.querySelector('main') || document.body).querySelectorAll('a,button')]
        .find(e => (e.innerText || e.getAttribute('aria-label') || '').replace(/\s+/g, ' ').trim().slice(0, 30) === c.txt);
      if (!el) return false;
      const sec = el.closest('[data-sec="hero"], .hero, .lp-hero, section:first-of-type');
      return !!sec;
    };
    const graves = [...tapados.filter(enHero), ...enParte.filter(c => enHero(c) && c.convierte)];
    const leves  = tapados.filter(c => !enHero(c));
    const parteQueEnlaza = enParte.filter(c => enHero(c) && !c.convierte);
    if (graves.length) {
      fallos.push(`M2 · ${graves.length} CTA(s) del HERO TAPADOS por cromo flotante: ` +
        graves.map(c => `"${c.txt}" bajo ${c.tapadoPor || c.tapadoParte}`).join(' · '));
    }
    if (parteQueEnlaza.length) {
      avisos.push(`M2 · ${parteQueEnlaza.length} enlace(s) del hero tapados EN PARTE al cargar: ` +
        parteQueEnlaza.map(c => `"${c.txt}" bajo ${c.tapadoParte}`).join(' · ') +
        ' (no es la accion que convierte; si lo fuera, seria fallo)');
    }
    if (leves.length) {
      avisos.push(`M2 · ${leves.length} CTA(s) tapados al cargar, fuera del hero: ` +
        leves.map(c => `"${c.txt}" bajo ${c.tapadoPor}`).join(' · ') +
        ' (se descubren al desplazar; el cromo de abajo es `fixed`)');
    }
  }

  // M3
  if (pctFlotante > CFG.topeFlotante) {
    avisos.push(`M3 · el cromo flotante cubre el ${pctFlotante}% de la pantalla ` +
      `(aviso >${CFG.topeFlotante}%; tope de sentido comun, NO medido contra referencias)`);
  }

  // M4 · la pagina NO se mueve de lado. 1-nov-2026 · un sitio real: a 390 la portada media
  // 411 (cinco enlaces del pie en un flex sin wrap) y la puerta dio 32 de 32 PASA:
  // nadie miraba el ancho. Lo que cuenta es lo que hace el visitante: si la pagina
  // se puede desplazar de lado, FALLA. Por eso se prueba a desplazarla y no se
  // compara scrollWidth: un adorno recortado con overflow-x:hidden no se mueve (eso
  // es un AVISO, por si lo recortado era texto), y una tabla en su propia caja con
  // scroll mueve la caja, no la pagina. `instant`: con scroll-behavior:smooth el
  // desplazamiento llega tarde y la prueba pasaria sin haber medido.
  // Y overflow:hidden deja desplazar al SCRIPT, no al visitante: lo que manda es el
  // overflow-x que hereda la vista (el de <html>, o el de <body> si <html> lo deja en
  // visible). Si ese recorta, la pagina no se mueve para quien la usa.
  const sx0 = scrollX, sy0 = scrollY;
  window.scrollTo({ left: sx0 + 400, top: sy0, behavior: 'instant' });
  const ovHtml = getComputedStyle(document.documentElement).overflowX;
  const ovVista = ovHtml !== 'visible' ? ovHtml : (document.body ? getComputedStyle(document.body).overflowX : 'visible');
  const deLado = ['hidden', 'clip'].includes(ovVista) ? 0 : Math.round(scrollX - sx0);
  window.scrollTo({ left: sx0, top: sy0, behavior: 'instant' });
  const anchoDoc = Math.max(document.documentElement.scrollWidth, document.body ? document.body.scrollWidth : 0);
  if (deLado > 0 || anchoDoc > vw + 1) {
    // Quien se sale: el que pasa del borde derecho con un padre que no pasa (ahi empieza).
    const sale = e => { const r = e.getBoundingClientRect(); return r.width > 0 && r.right + scrollX > vw + 1; };
    const nombre = e => `${e.tagName.toLowerCase()}${e.classList[0] ? '.' + e.classList[0] : e.id ? '#' + e.id : ''}`;
    const todos = [...document.body.querySelectorAll('*')];
    // Cada fallo dice el arreglo probable: quien lo lee no tiene que aprender la regla a
    // golpe de rechazo (Asistente, 1-nov).
    let arreglo = 'esa caja tiene un ancho fijo, un min-width o un flex sin wrap: max-width:100%, ' +
      'min-width:0 o flex-wrap:wrap en ella o en su contenedor';
    let origen = todos
      .filter(e => sale(e) && !(e.parentElement && e.parentElement !== document.body && sale(e.parentElement)))
      .slice(0, 4)
      .map(e => `${nombre(e)} (hasta ${Math.round(e.getBoundingClientRect().right + scrollX)} px)`);
    // Si ninguna caja pasa del borde, lo que se sale es su CONTENIDO: una palabra o
    // una direccion que no parte, o un ::before/::after. La caja mide bien y su
    // scrollWidth no (una pagina de contacto, 1-nov: «no se ve quien»). Se nombra la mas honda.
    if (!origen.length) {
      origen = todos.filter(e => {
        if (getComputedStyle(e).overflowX !== 'visible') return false;
        const r = e.getBoundingClientRect();
        return r.width > 0 && r.left + scrollX + e.scrollWidth > vw + 1 && e.scrollWidth > e.clientWidth + 1;
      }).filter((e, _, l) => !l.some(o => o !== e && e.contains(o))).slice(0, 4)
        .map(e => `${nombre(e)} (su contenido llega a ${Math.round(e.getBoundingClientRect().left + scrollX + e.scrollWidth)} px` +
          `${(e.textContent || '').trim() ? ': «' + e.textContent.trim().replace(/\s+/g, ' ').slice(0, 40) + '»' : ''})`);
      arreglo = 'un texto que no parte (un correo, una URL, una palabra larga): overflow-wrap:anywhere en ese ' +
        'texto, o letra mas pequena a este ancho';
    }
    if (deLado > 0) {
      fallos.push(`M4 · la pagina es mas ancha que la pantalla: mide ${anchoDoc} px a ${vw} y se ` +
        `desplaza ${deLado} px de lado. Se sale: ${origen.join(' · ') || 'no se ve quien'}` +
        `${origen.length ? `. Arreglo probable: ${arreglo}` : ''}`);
    } else {
      avisos.push(`M4 · hay contenido de ${anchoDoc} px a ${vw}, recortado (overflow oculto): la ` +
        `pagina no se mueve, pero lo recortado no se ve. ${origen.join(' · ')}`);
    }
  }

  if (vw !== CFG.anchoPedido) {
    notas.push(`MEDIDO A ${vw} px cuando se pidieron ${CFG.anchoPedido}. Chrome clampa en ` +
      `Windows: una medida que no coincide con lo PEDIDO no es un resultado.`);
  }
  if (esperado >= CFG.esperaMax - 200) {
    notas.push(`el cromo flotante NO se estabilizo en ${CFG.esperaMax} ms: puede quedar ` +
      `algo por salir que este gate no ha visto. No es un aprobado.`);
  }
  // Lo que NO se ha mirado, dicho. Sin esta linea, un PASA del escenario A se
  // lee como "en movil esta bien", y en site-a el defecto estaba en el B.
  if (!CFG.trasConsentimiento) {
    notas.push('SOLO se ha medido la PRIMERA VISITA. Lo que salga DESPUES de aceptar ' +
      'cookies -- popups de conversion, chats -- no lo ha visto nadie. Para medirlo: ' +
      "__GATE__ = {\"trasConsentimiento\":true}");
  } else {
    notas.push(`medido TRAS pulsar el consentimiento: ${consentimiento}`);
  }

  const h1 = document.querySelector('h1');
  let cuerpo = null;
  for (const p of main.querySelectorAll('p')) {
    const t = (p.innerText || '').trim();
    if (t.length >= 80 && visible(p)) { cuerpo = parseFloat(getComputedStyle(p).fontSize); break; }
  }

  return JSON.stringify({
    url: location.href,
    innerWidth: vw, innerHeight: vh, coincide: vw === CFG.anchoPedido,
    tipo: tipo + ' (' + tipoDe + ')',
    VEREDICTO: fallos.length ? 'FALLA' : 'PASA',
    fallos, avisos, notas,
    resumen: {
      esperadoMs: esperado,
      // A que ms aparecio o cambio cada pieza de cromo flotante. Si aqui hay un
      // numero alto, ese es el que se te escapa midiendo al cargar.
      cromoAparecioMs: cambios,
      exigeCTAsobrePliegue: exigeCTA,
      exigeConversion,
      // M1, lo que se vio: cada accion con si convierte y si cabe ENTERA arriba
      m1: candM1.slice(0, 8).map(c => ({ txt: c.txt, destino: c.destino, convierte: c.convierte,
            entero: c.entero, tapado: c.tapadoPor || null, pantallas: c.pantallas })),
      ctas: info.length,
      ctasSobrePliegue: info.filter(c => c.sobrePliegue).length,
      ctasUtilesSobrePliegue: utilesArriba.length,
      ctasTapados: tapados.length,
      primerCTAutil: primero ? { txt: primero.txt, pantallas: primero.pantallas } : null,
      pctFlotante,
      flotantes: fl.map(f => ({
        el: f.el.tagName + '.' + ((f.el.getAttribute('class') || '-').split(' ')[0]),
        pos: f.cs.position, z: f.cs.zIndex,
        // el rect COMPLETO y lo que de verdad se ve: si no coinciden, parte
        // esta fuera de pantalla y no tapa nada
        rect: Math.round(f.r.width) + 'x' + Math.round(f.r.height) +
              ' @(' + Math.round(f.r.left) + ',' + Math.round(f.r.top) + ')',
        visible: Math.round(f.visW) + 'x' + Math.round(f.visH),
        pct: +(f.visW * f.visH / (vw * vh) * 100).toFixed(1)
      })),
      // DATO, no regla: no hay banco de referencia para el tamano del titular en
      // movil, asi que se informa y no se juzga. Ver 11-medidas §2.2.
      h1px: h1 ? +parseFloat(getComputedStyle(h1).fontSize).toFixed(1) : null,
      h1lineas: h1 ? Math.max(1, Math.round(h1.getBoundingClientRect().height /
                 (parseFloat(getComputedStyle(h1).lineHeight) || 1))) : null,
      h1altoPct: h1 ? +(h1.getBoundingClientRect().height / vh * 100).toFixed(1) : null,
      cuerpoPx: cuerpo,
      pantallasTotales: +(document.body.scrollHeight / vh).toFixed(1)
    },
    tapados
  }, null, 1);
})()
