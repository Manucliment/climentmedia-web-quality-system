// =============================================================================
//  GATE DEL MENU MOVIL  ·  ¿se llega a las paginas desde el telefono?
//  1-nov-2026 · se corre con run-gate.js, a 390x844
// =============================================================================
//
//  🔴 POR QUE EXISTE. Una web de reservas salio con el menu movil hecho de los
//  mismos enlaces de escritorio, saltando de fila en fila por encima del hero.
//  Nadie lo miraba: `mobile-gate.js` mira lo que hay DENTRO de <main> (la
//  cabecera es cromo, a proposito), y qa-master A11Y-13 -«sin trampa en el
//  banner ni en el menu movil»- sale NO VERIFICADO en todas las webs, porque
//  pide una persona con el teclado.
//  Lo que de A11Y-13 se puede medir con el navegador, este gate lo mide. La
//  puerta lo corre sobre el candidato y, si pasa en todas las URLs, da A11Y-13
//  por contestado EN SU PARTE DEL MENU, y lo dice con esas palabras.
//
//  QUE COMPRUEBA
//
//    N1  Sin boton de menu, los enlaces DEL MENU caben en UNA fila (sin contar
//        la marca, los idiomas ni los botones: una cabecera de movil con la marca
//        arriba y el menu debajo esta bien hecha). El menu partido en dos filas o
//        mas a 390 es el menu de escritorio apilado: empuja el hero hacia abajo y
//        no se lee como un menu. FALLA.
//    N1b Ningun enlace de la cabecera asoma cortado por el borde de la pantalla
//        (fuera de una tira con scroll propio, que es un patron legitimo). FALLA.
//    N2  Si hay boton, lleva `aria-expanded` (o es un <summary>, que lo trae de
//        serie). Sin el, un lector de pantalla no sabe si el menu esta abierto.
//        FALLA.
//    N3  El boton ABRE: al pulsarlo aparece al menos un enlace que antes no se
//        veia, y `aria-expanded` pasa a "true". FALLA.
//    N4  El boton se alcanza con el teclado (boton nativo, enlace o tabindex>=0)
//        y tiene nombre accesible. FALLA.
//    N5  Con el menu CERRADO, sus enlaces no se pueden tabular: un cajon movido
//        fuera de pantalla con `transform` sigue en el orden de Tab, y el foco
//        se va a enlaces que nadie ve. Es la «trampa en el menu movil» de
//        A11Y-13. FALLA.
//    N6  Escape cierra el menu abierto. AVISO: es buena practica (patron de
//        divulgacion), no un criterio que falle.
//
//  LO QUE NO MIDE, dicho en cada corrida: el recorrido entero con Tab por la
//  pagina, el foco visible y un lector de pantalla de verdad. Eso sigue siendo
//  de una persona, firmado en _deploy/measured.conf.
//
//  EL CLIC ES UNA ACCION, Y SE ACOTA: solo se pulsa el boton del menu, y un
//  escuchador en captura impide que un enlace con destino navegue (el gate
//  perderia la pagina a media medida). Los manejadores del boton corren igual.
// =============================================================================
(async () => {
  const CFG = Object.assign({
    anchoPedido: 390,
    esperaMs: 1500        // lo que se espera a que el menu termine de abrirse (transiciones)
  }, (typeof window !== 'undefined' && window.__GATE__) || {});

  const esperar = ms => new Promise(r => setTimeout(r, ms));
  const vw = innerWidth, vh = innerHeight;
  scrollTo(0, 0);
  await esperar(150);
  const fallos = [], avisos = [], notas = [];

  // ¿Recorta un ancestro (overflow) la caja entera? Un menu plegado con
  // `max-height:0; overflow:hidden` tiene enlaces con tamano y no se ven.
  const recortado = (el, r) => {
    for (let n = el.parentElement; n && n !== document.documentElement; n = n.parentElement) {
      const cs = getComputedStyle(n);
      if (cs.overflow === 'visible' && cs.overflowX === 'visible' && cs.overflowY === 'visible') continue;
      const a = n.getBoundingClientRect();
      if (r.right <= a.left || r.left >= a.right || r.bottom <= a.top || r.top >= a.bottom) return true;
    }
    return false;
  };
  // Se VE = tiene caja, no esta oculto ni transparente, cae dentro de la pantalla,
  // ningun ancestro lo recorta y el propio motor dice que en su centro esta el.
  const seVe = el => {
    if (!el || !el.getBoundingClientRect) return false;
    const r = el.getBoundingClientRect();
    if (r.width < 2 || r.height < 2) return false;
    if (el.checkVisibility && !el.checkVisibility({ opacityProperty: true, visibilityProperty: true })) return false;
    if (r.right <= 0 || r.left >= vw || r.bottom <= 0 || r.top >= vh) return false;
    if (recortado(el, r)) return false;
    const cx = Math.min(Math.max(r.left + r.width / 2, 1), vw - 1);
    const cy = Math.min(Math.max(r.top + r.height / 2, 1), vh - 1);
    const hit = document.elementFromPoint(cx, cy);
    return !!hit && (el === hit || el.contains(hit) || hit.contains(el));
  };
  // Tabulable = el navegador le daria el foco con Tab: no esta en display:none ni
  // visibility:hidden, no esta dentro de [inert] y su tabIndex no es negativo.
  const tabulable = el => {
    if (el.tabIndex < 0 || el.disabled) return false;
    if (el.closest('[inert]')) return false;
    if (el.checkVisibility && !el.checkVisibility({ visibilityProperty: true })) return false;
    return true;
  };
  const txt = el => ((el && (el.getAttribute('aria-label') || el.innerText || el.textContent)) || '')
    .replace(/\s+/g, ' ').trim().slice(0, 40);

  // --- ¿es esto una pagina? (lo mismo que mobile-gate.js) -------------------
  const cuerpoTxt = (document.body.innerText || '').replace(/\s+/g, ' ').trim();
  const secciones = document.querySelectorAll('main section, main > div, article').length;
  const pareceRoto = cuerpoTxt.length < 200 || (!document.querySelector('h1') && secciones === 0);

  // --- la cabecera ----------------------------------------------------------
  // La primera <header> o [role=banner] que empieza arriba y no es la de un
  // articulo. Sin ninguna, el primer <nav> de arriba.
  const arriba = el => { const r = el.getBoundingClientRect(); return r.top < 160 && r.bottom > 0; };
  let cab = [...document.querySelectorAll('header, [role="banner"]')]
    .find(h => !h.closest('article, main article') && arriba(h)) || null;
  if (!cab) cab = [...document.querySelectorAll('nav')].find(arriba) || null;

  const resumen = { cabecera: cab ? cab.tagName.toLowerCase() + ((cab.className && typeof cab.className === 'string') ? '.' + cab.className.split(' ')[0] : '') : null };
  let boton = null;

  if (pareceRoto) {
    notas.push(`NO MEDIBLE: esto no parece una pagina (${cuerpoTxt.length} caracteres de texto, ` +
      `${secciones} secciones). 404, cascaron que monta JS, o muro anti-bot. NO se juzga el menu de esto.`);
  } else if (!cab) {
    notas.push('N0 · la pagina no tiene cabecera ni <nav> arriba: no hay menu que juzgar (¿landing a proposito?)');
  } else {
    const todos = [...cab.querySelectorAll('a[href]')];
    const vistos = todos.filter(seVe);
    const ocultos = todos.filter(a => !seVe(a));

    // 1-nov-2026 · N1 cuenta las filas del MENU, no las de la cabecera. En el barrido de
    // las webs publicadas dos con el menu en UNA fila salian rojas: la marca y los
    // idiomas van en la fila de arriba y el telefono en la de abajo. Eso es una cabecera
    // de movil bien hecha; lo que empuja el hero es el menu partido. Fuera de la cuenta:
    // la marca (primer enlace a la raiz, o con logo), los idiomas y los botones.
    const clase = a => (typeof a.className === 'string' ? a.className : (a.getAttribute('class') || ''));
    const RAIZ = /^\/([a-z]{2}(-[a-z]{2})?\/?)?$/i;
    const esMarca = a => { let u; try { u = new URL(a.getAttribute('href'), location.href); } catch (e) { return false; }
      return RAIZ.test(u.pathname) && !u.hash && (a === vistos[0] || !!a.querySelector('img, svg') ||
        /logo|brand|marca|nombre|name|home|accueil|inicio/i.test(clase(a) + ' ' + (a.getAttribute('aria-label') || ''))); };
    const esIdioma = a => a.hasAttribute('hreflang') || a.hasAttribute('lang') || /lang|idioma|taal|langue|locale/i.test(clase(a)) ||
      /^(es|en|nl|fr|de|pt|it|ca|english|espa[nñ]ol|nederlands|fran[cç]ais|deutsch|portugu[eê]s|italiano|catal[aà])$/i.test(txt(a).trim());
    const esBotonCab = a => /\bbtn\b|button|cta/i.test(clase(a)) || /^(tel|mailto|sms):|wa\.me|whatsapp/i.test(a.getAttribute('href') || '');
    const menu = vistos.filter(a => !esMarca(a) && !esIdioma(a) && !esBotonCab(a));

    // Filas: un enlace entra en una fila si su centro vertical cae dentro de ella.
    const filas = [];
    for (const r of menu.map(a => a.getBoundingClientRect()).sort((a, b) => a.top - b.top)) {
      const cy = (r.top + r.bottom) / 2;
      const f = filas.find(x => cy >= x.top && cy <= x.bottom);
      if (f) { f.n++; f.top = Math.min(f.top, r.top); f.bottom = Math.max(f.bottom, r.bottom); }
      else filas.push({ top: r.top, bottom: r.bottom, n: 1 });
    }
    // Cortados: asoman por un borde y no viven en una tira con scroll propio.
    const enTiraConScroll = el => { for (let n = el.parentElement; n && n !== cab.parentElement; n = n.parentElement) {
      const o = getComputedStyle(n).overflowX; if (o === 'auto' || o === 'scroll') return true; } return false; };
    const cortados = vistos.filter(a => { const r = a.getBoundingClientRect();
      return ((r.left < vw - 1 && r.right > vw + 1) || (r.left < -1 && r.right > 1)) && !enTiraConScroll(a); });

    // El boton: con aria-expanded y pinta de menu, luego cualquiera con
    // aria-expanded, luego un <summary>, luego lo que se llame menu. Puede vivir
    // fuera de la cabecera (una hamburguesa fija hermana de <header>), arriba.
    const PINTA = /men[uú]|navega|hamburg|burger|toggle|☰|≡|\bnav\b/i;
    const pinta = el => PINTA.test([el.getAttribute('aria-label'), el.getAttribute('title'), el.textContent,
      typeof el.className === 'string' ? el.className : '', el.id, el.getAttribute('aria-controls')].join(' '));
    const SEL_BOTON = 'button, [role="button"], summary, a[aria-controls], [aria-expanded]';
    const enCab = [...cab.querySelectorAll(SEL_BOTON)].filter(seVe);
    const fuera = [...document.querySelectorAll(SEL_BOTON)].filter(b => !cab.contains(b) && arriba(b) && seVe(b) && pinta(b));
    const cands = enCab.concat(fuera);
    boton = cands.find(b => b.hasAttribute('aria-expanded') && pinta(b)) ||
            cands.find(b => b.hasAttribute('aria-expanded')) ||
            cands.find(b => b.tagName === 'SUMMARY') ||
            cands.find(pinta) || null;

    Object.assign(resumen, {
      enlaces: todos.length, enlacesVisibles: vistos.length, enlacesOcultos: ocultos.length,
      enlacesMenu: menu.length, fueraDeLaCuenta: vistos.filter(a => !menu.includes(a)).map(a => `«${txt(a).trim().slice(0, 30)}»`),
      filas: filas.length, enlacesPorFila: filas.map(f => f.n),
      cortados: cortados.map(a => `«${txt(a)}»`)
    });

    if (cortados.length) {
      fallos.push(`N1b · ${cortados.length} enlace(s) de la cabecera asoman CORTADOS por el borde de la pantalla ` +
        `a ${vw}px: ${cortados.slice(0, 4).map(a => `«${txt(a)}»`).join(' · ')}`);
    }

    if (!boton) {
      if (filas.length > 1) {
        fallos.push(`N1 · los ${menu.length} enlaces del menu ocupan ${filas.length} filas a ${vw}px ` +
          `(${filas.map(f => f.n).join(' + ')}; sin contar marca, idiomas ni botones) y no hay boton de menu: ` +
          `es el menu de escritorio apilado`);
      } else if (!vistos.length && ocultos.length) {
        fallos.push(`N1 · la cabecera tiene ${ocultos.length} enlace(s) que no se ven y ningun boton que los abra: ` +
          `en movil no hay menu`);
      } else if (!vistos.length) {
        notas.push('N0 · la cabecera no lleva enlaces: no hay menu que juzgar');
      } else if (!menu.length) {
        notas.push('N0 · la cabecera solo lleva marca, idiomas o botones: no hay menu que juzgar');
      } else if (!cortados.length) {
        notas.push(`N0 · sin boton de menu, y los ${menu.length} enlaces del menu caben en una fila`);
      }
    } else {
      const nativo = boton.tagName === 'SUMMARY';
      const id = boton.getAttribute('aria-controls');
      const panel = id ? document.getElementById(id.split(/\s+/)[0]) : (nativo ? boton.parentElement : null);
      const nombre = (boton.getAttribute('aria-label') ||
        (boton.getAttribute('aria-labelledby') || '').split(/\s+/).map(i => (document.getElementById(i) || {}).textContent || '').join(' ') ||
        boton.innerText || boton.getAttribute('title') ||
        [...boton.querySelectorAll('img[alt], svg title')].map(x => x.getAttribute('alt') || x.textContent).join(' ') || '')
        .replace(/\s+/g, ' ').trim();
      resumen.boton = { el: boton.tagName.toLowerCase(), nombre: nombre.slice(0, 40), ariaExpanded: boton.getAttribute('aria-expanded'),
                        ariaControls: id || null, panelExiste: !!panel };

      // N2
      if (!nativo && !boton.hasAttribute('aria-expanded'))
        fallos.push(`N2 · el boton de menu («${nombre.slice(0, 30) || boton.tagName.toLowerCase()}») no lleva aria-expanded: ` +
          `un lector de pantalla no sabe si el menu esta abierto o cerrado`);
      // N4
      if (!tabulable(boton))
        fallos.push(`N4 · el boton de menu no se alcanza con el teclado (${boton.tagName.toLowerCase()}, tabIndex ${boton.tabIndex}): ` +
          `un <div role="button"> sin tabindex no recibe el foco`);
      if (!nombre)
        fallos.push('N4 · el boton de menu no tiene nombre accesible: ni texto, ni aria-label, ni title');

      // N5 · cerrado, ¿hay enlaces invisibles en el orden de Tab?
      const abierto0 = nativo ? !!boton.parentElement.open : boton.getAttribute('aria-expanded') === 'true';
      const zona = panel || cab;
      const trampa = abierto0 ? [] : [...zona.querySelectorAll('a[href]')].filter(a => !seVe(a) && tabulable(a));
      resumen.cerradoTabulables = trampa.length;
      if (trampa.length)
        fallos.push(`N5 · con el menu cerrado, ${trampa.length} enlace(s) que no se ven siguen en el orden de Tab ` +
          `(${trampa.slice(0, 3).map(a => `«${txt(a)}»`).join(' · ')}): el foco se va a donde nadie lo ve. ` +
          `Al cerrar: display:none, visibility:hidden o inert`);

      // N3 · se pulsa y se espera a que aparezca algo
      const antes = new Set([...document.querySelectorAll('a[href]')].filter(seVe));
      const freno = e => { const a = e.target.closest && e.target.closest('a[href]');
        if (a && !/^#/.test(a.getAttribute('href') || '')) e.preventDefault(); };
      addEventListener('click', freno, true);
      let nuevos = [], expandido = null;
      try {
        if (abierto0) { boton.click(); await esperar(400); }   // estaba abierto: se cierra antes de medir
        boton.click();
        const t0 = Date.now();
        while (Date.now() - t0 < CFG.esperaMs) {
          await esperar(120);
          nuevos = [...document.querySelectorAll('a[href]')].filter(a => !antes.has(a) && seVe(a));
          expandido = nativo ? !!boton.parentElement.open : boton.getAttribute('aria-expanded');
          if (nuevos.length && (nativo || expandido === 'true' || !boton.hasAttribute('aria-expanded'))) break;
        }
      } catch (e) { notas.push('N3 · el clic en el boton dio un error: ' + String(e && e.message || e).slice(0, 80)); }
      resumen.abre = { enlacesNuevos: nuevos.length, ariaExpandedTras: expandido };
      if (!nuevos.length)
        fallos.push(`N3 · el boton de menu NO ABRE: tras pulsarlo y esperar ${CFG.esperaMs} ms no aparece ningun enlace nuevo`);
      else if (!nativo && boton.hasAttribute('aria-expanded') && expandido !== 'true')
        fallos.push(`N3 · el menu se abre pero aria-expanded sigue en «${expandido}»: el lector de pantalla oye «cerrado»`);
      else {
        const sinTab = nuevos.filter(a => !tabulable(a));
        if (sinTab.length === nuevos.length)
          fallos.push(`N4 · el menu abierto muestra ${nuevos.length} enlace(s) y ninguno se alcanza con Tab`);
        // N6 · Escape
        const tecla = new KeyboardEvent('keydown', { key: 'Escape', code: 'Escape', keyCode: 27, bubbles: true });
        (document.activeElement || document.body).dispatchEvent(tecla);
        document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', code: 'Escape', keyCode: 27, bubbles: true }));
        await esperar(500);
        const sigue = nuevos.filter(seVe).length;
        resumen.escapeCierra = !sigue;
        if (sigue) avisos.push('N6 · Escape no cierra el menu abierto (buena practica del patron de divulgacion, no un fallo)');
      }
      removeEventListener('click', freno, true);
    }
  }

  if (vw !== CFG.anchoPedido) {
    notas.push(`MEDIDO A ${vw} px cuando se pidieron ${CFG.anchoPedido}. Una medida que no coincide con lo ` +
      `PEDIDO no es un resultado.`);
  }
  notas.push('A11Y-13 · este gate mide la parte del MENU MOVIL (filas, boton, aria-expanded, que abra, teclado ' +
    'y Tab con el menu cerrado). NO mide el recorrido entero con Tab, el foco visible ni un lector de pantalla.');

  return JSON.stringify({
    url: location.href,
    innerWidth: vw, innerHeight: vh, coincide: vw === CFG.anchoPedido,
    VEREDICTO: fallos.length ? 'FALLA' : 'PASA',
    fallos, avisos, notas, resumen
  }, null, 1);
})()
