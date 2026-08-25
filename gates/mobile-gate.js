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
//
//    M2  CERO CTAs tapados por cromo flotante, esten donde esten.
//        Regla NUEVA (no estaba escrita en ningun sitio). Se anade tambien a
//        la documentacion: un boton que no se puede pulsar no es un boton.
//
//    M3  El cromo flotante no se come mas de un tercio de la pantalla.
//        AVISO, no fallo: 33% es un tope de sentido comun, NO una medida
//        contra referencias. Mientras no haya banco de referencia, no bloquea.
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
    anchoPedido: 390
  }, (typeof window !== 'undefined' && window.__GATE__) || {});

  const esperar = ms => new Promise(r => setTimeout(r, ms));
  const vw = innerWidth, vh = innerHeight;
  const dentro = (a, b) => a === b || a.contains(b) || b.contains(a);

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
    const cx = r.left + r.width / 2;
    const cy = Math.min(Math.max(r.top + r.height / 2, 1), vh - 1);
    // Solo se puede preguntar por lo que esta EN pantalla. Lo de mas abajo se
    // evalua por su posicion, no por oclusion: tapar algo fuera de vista no es
    // taparlo, y decir que si seria un falso positivo garantizado.
    const enPantalla = r.bottom > 0 && r.top < vh;
    let tapadoPor = null;
    if (enPantalla) {
      const encima = document.elementFromPoint(cx, cy);
      if (!encima || !dentro(el, encima)) {
        tapadoPor = encima ? encima.tagName + '.' + ((encima.getAttribute('class') || '-').split(' ')[0])
                           : '(fuera del arbol)';
      }
    }
    return {
      txt: (el.innerText || el.getAttribute('aria-label') || '').replace(/\s+/g, ' ').trim().slice(0, 30),
      cls: (el.getAttribute('class') || '-').split(' ')[0],
      yDoc: Math.round(r.top + scrollY),
      pantallas: +((r.top + scrollY) / vh).toFixed(2),
      sobrePliegue: (r.top + scrollY) < vh,
      enPantalla, tapadoPor
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
  } else if (!info.length) {
    fallos.push('M1 · la pagina no tiene NI UN CTA: no hay nada que pulsar');
  } else if (!utilesArriba.length) {
    const d = primero ? `el primero util cae a ${primero.pantallas} pantallas ("${primero.txt}")`
                      : 'y ninguno esta libre de estorbos';
    // 🔴 "PROPIA DE LA PAGINA" no es un matiz: se cuenta solo lo que hay DENTRO
    // de <main>. Un boton en la cabecera pegajosa esta sobre el pliegue en las
    // 18 paginas del sitio por igual, asi que contarlo haria que TODAS pasaran
    // y el gate no diria nada. La regla del estandar (09 §3) es sobre el HERO:
    // "un hero que convierte, no uno que enlaza". El cromo no convierte.
    // Se dice en el fallo para que nadie lo lea como un falso positivo mirando
    // el boton del menu.
    fallos.push(`M1 · ninguna accion PROPIA DE LA PAGINA sobre el pliegue: ${d}` +
      ` (los CTA de cabecera/pie no cuentan: son cromo, estan en todas)`);
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
  // ⚠️ Un gate que nunca se puede satisfacer es un gate que alguien apaga. Esto
  // NO es bajar el liston: es apuntarlo a lo que se puede y se debe arreglar.
  if (tapados.length && !pareceRoto) {
    const enHero = c => {
      const el = [...(document.querySelector('main') || document.body).querySelectorAll('a,button')]
        .find(e => (e.innerText || e.getAttribute('aria-label') || '').replace(/\s+/g, ' ').trim().slice(0, 30) === c.txt);
      if (!el) return false;
      const sec = el.closest('[data-sec="hero"], .hero, .lp-hero, section:first-of-type');
      return !!sec;
    };
    const graves = tapados.filter(enHero);
    const leves  = tapados.filter(c => !enHero(c));
    if (graves.length) {
      fallos.push(`M2 · ${graves.length} CTA(s) del HERO TAPADOS por cromo flotante: ` +
        graves.map(c => `"${c.txt}" bajo ${c.tapadoPor}`).join(' · '));
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
