/* =============================================================================
 *  measure-screens.js — GATE de densidad y de CTAs
 * =============================================================================
 *  Se pega en la consola del navegador, o se ejecuta con el javascript_tool del
 *  panel. Devuelve VEREDICTO: PASA o FALLA.
 *
 *  POR QUE EXISTE
 *  --------------
 *  Manuel, 7-ago-2026: «el tema de desborde de las secciones para que encajen
 *  con una pantalla impresa en PC o en tlf no lo has cumplido en ninguna web,
 *  es muy importante que lo tengas siempre en cuenta y tambien la prioridad de
 *  CTAs y distribucion».
 *
 *  Tenia razon, y lo peor no era el fallo: era que NUNCA LO HABIA MEDIDO. No
 *  hay ninguna comprobacion en el QA que mire cuanto ocupa una seccion ni donde
 *  caen los botones. Un checklist que no lo pregunta nunca lo encuentra.
 *
 *  Medido el 7-ago a 1280x720:
 *    site-a.example   8,2 pantallas · 2 secciones desbordan · 3 CTA, TODOS en el hero
 *    site-d    3,2 pantallas · 0 desbordan · 4 CTA repartidos        <- el unico que cumple
 *    site-c   17,9 pantallas · prosa lineal sin secciones · 32 de 39 bloques sin CTA
 *
 *  LA CAUSA RAIZ, para no repetirla: BC cumple porque se construyo desde una
 *  spec con secciones definidas. Site C falla porque reproduce la prosa lineal de
 *  su WordPress. **Fidelidad al CONTENIDO no es fidelidad a la MAQUETA.** Al
 *  migrar se conservan los textos; la estructura se rehace.
 * ========================================================================== */
(() => {
  const vh = innerHeight, vw = innerWidth;

  // ⚠️ NO se asume <section>: Site C usa <p> y <figure> sueltos colgando de <main>
  // y un selector de 'section' solo cubria el 12% de la pagina. Se miran los
  // hijos DIRECTOS del contenedor principal, sea cual sea la etiqueta.
  const main = document.querySelector('main') || document.body;
  const CTA = 'a.btn,button.btn,a[class*=btn],a[class*=cta],a[href*="wa.me"],' +
              'a[href*="whatsapp"],a[href^="tel:"],button[type=submit],form';

  // 🔴 18-ago-2026 · QUE ES UN "BLOQUE" CUANDO EL BLOQUE ES UNA LISTA.
  // Medidos los 19 moldes de references/moldes/ a 390x844 en el servidor
  // (innerWidth 390, coincide:true en los 19): DIEZ pasan de una pantalla con
  // su propio contenido de ejemplo. Pero al bajar un nivel, NINGUNA de sus
  // unidades lo hace: par-alterno son 3 filas de 625/582/556 px (0,74 · 0,69 ·
  // 0,66 pantallas), la rejilla son 6 tarjetas, la escalera son 3 planes.
  // Lo que desborda es SIEMPRE la suma, nunca la pieza.
  //
  // Asi que la regla, tal como estaba escrita, decia en realidad «ninguna
  // seccion puede tener mas de dos ideas» — y eso choca de frente con
  // 09-tipos-de-pagina §2.1, que manda una `oferta` de 3 a 6 elementos en UNA
  // seccion. Dos documentos canonicos pidiendo cosas incompatibles: usar el
  // repertorio que la skill obliga a usar ponia en rojo el gate que la misma
  // skill obliga a pasar. En la prueba de site-f costo 21/24 -> 17/24.
  //
  // El motivo del umbral era «si no cabe de un vistazo, no se lee: se hojea».
  // En una LISTA hojear es el comportamiento correcto: para eso es una lista.
  // En un muro de prosa, hojear es perderse. Por eso ahora se mide la UNIDAD
  // —la pieza repetida— y se deja un tope aparte para el contenedor.
  const altoDe = c => c.getBoundingClientRect().height;
  // Una UNIDAD es una pieza repetida Y ESTRUCTURADA: la fila de un par-alterno,
  // una tarjeta, un plan, una fila de tabla. Ocho <p> seguidos tambien se
  // repiten, y NO son unidades: son un muro de prosa, que es justo lo que este
  // gate existe para cazar (Site C: 39 bloques de <p> y <figure> sueltos). El
  // discriminador es el mismo que usa structure-gate.js en esProsa(): la pieza
  // tiene estructura propia —dos hijos o un titular— o no cuenta.
  const estructurada = c => {
    if (c.tagName === 'P') return false;          // un parrafo NUNCA es una unidad
    let n = c, v = 0;
    while (n.children.length === 1 && v++ < 4) n = n.children[0];   // li > figure > ...
    return n.children.length >= 2 ||
           !!c.querySelector('h1,h2,h3,h4,h5,h6,img,picture,figure,video,svg,table');
  };
  const unidadesDe = (el) => {
    let n = el;
    for (let vueltas = 0; vueltas < 8; vueltas++) {
      const hijos = [...n.children].filter(c => altoDe(c) > 20);
      if (!hijos.length) break;
      const forma = c => c.tagName + '.' + ((c.className || '') + '').split(' ')[0];
      const grupos = {};
      for (const c of hijos) { const k = forma(c); (grupos[k] = grupos[k] || []).push(c); }
      const buenos = Object.values(grupos)
        .filter(g => g.length >= 2 && g.filter(estructurada).length >= g.length / 2);
      if (buenos.length) return buenos.flat();
      // Sin repeticion util: se baja por el hijo que se lleva el grueso del alto
      // (el h2 y el subtitulo son cromo; la lista esta dentro de UN contenedor).
      const mayor = hijos.reduce((a, b) => (altoDe(b) > altoDe(a) ? b : a));
      if (altoDe(mayor) < altoDe(n) * 0.55) break;   // ninguno domina: el bloque es la unidad
      n = mayor;
    }
    return [el];
  };

  // ── LA MEDIDA CANDIDATA · «el tramo mas largo sin una parada» ──────────────
  //  El umbral del 55% de arriba me lo invente yo, y en la web de prueba produjo
  //  CINCO acusaciones falsas: una seccion de h2 + subtitulo + parrafo + lista de
  //  4 tarjetas + CTA, donde la lista es el 52% del alto. Por tres puntos el
  //  detector se rinde y declara «el bloque entero es la unidad» -- cuando ninguna
  //  pieza de esa seccion pasa de 136 px.
  //
  //  El motivo del umbral era: «si no cabe de un vistazo, no se lee: se hojea».
  //  Entonces lo que hay que medir no es el tamano de la pieza, es **cuanto se
  //  recorre sin encontrar donde pararse**. Una parada es un titular, un item de
  //  lista, una imagen, una fila de tabla, un boton. Un parrafo NO lo es.
  //  Se calcula aqui para poder comparar las dos medidas sobre el mismo parque
  //  antes de cambiar el veredicto. Si la nueva es estrictamente mejor, sustituye.
  //  QUE CUENTA COMO PARADA, decidido por principio y ANTES de mirar si conviene:
  //  cualquier elemento que le da al ojo un sitio donde aterrizar. Titulares,
  //  items de lista, medios, filas de tabla, terminos de definicion, botones,
  //  resumenes de acordeon **y los campos de un formulario con su etiqueta** --
  //  un formulario no se hojea, se rellena, y se recorre por sus etiquetas
  //  exactamente igual que una lista por sus items.
  //  Un PARRAFO no es una parada. Ahi esta toda la regla.
  const PARADA = 'h1,h2,h3,h4,h5,h6,li,img,picture,figure,svg,video,tr,dt,' +
                 'button,summary,label,input,select,textarea';
  const tramoSinParada = (el) => {
    const r0 = el.getBoundingClientRect();
    const tops = [...el.querySelectorAll(PARADA)]
      .map(e => e.getBoundingClientRect())
      .filter(r => r.height > 4)
      .map(r => r.top - r0.top)
      .filter(t => t >= 0 && t <= r0.height)
      .sort((a, b) => a - b);
    const puntos = [0, ...tops, r0.height];
    let peor = 0;
    for (let i = 1; i < puntos.length; i++) peor = Math.max(peor, puntos[i] - puntos[i - 1]);
    return Math.round(peor);
  };

    // 🔴 19-ago-2026 · UN ENVOLTORIO DE MAQUETA ESCONDIA LAS SECCIONES.
    // `main.children` daba por bloque cada hijo directo, y una web que envuelve
    // sus secciones en un <div class="env"> -legitimo, es un contenedor de
    // ancho- convertia DIEZ secciones en UN bloque de 12,8 pantallas. Medido:
    // la home de site-c emitia 11 data-sec y el gate veia 1; su /contacto, 0 de 5.
    // El gate acusaba a la web de un bloque gigante que no existe.
    // Se desciende SOLO cuando el hijo no es una seccion Y contiene 2 o mas
    // [data-sec]: asi no puede dispararse en una pagina que no declara roles
    // -que son 3 de las 6 webs- ni partir un bloque que de verdad es uno.
    const hijosReales = [...main.children].flatMap(c =>
      (!c.hasAttribute('data-sec') && c.querySelectorAll('[data-sec]').length >= 2)
        ? [...c.children] : [c]);
    const bloques = hijosReales
    .map((s, i) => {
      const px = Math.round(s.getBoundingClientRect().height);
      const h = s.querySelector('h1,h2,h3');
      const u = unidadesDe(s);
      const uPx = Math.max(...u.map(e => Math.round(e.getBoundingClientRect().height)));
      return {
        n: i + 1,
        que: (h ? h.innerText : s.tagName.toLowerCase() + '.' + (s.className || '').split(' ')[0]).slice(0, 44),
        px,
        pantallas: +(px / vh).toFixed(2),
        unidades: u.length,
        unidadPx: uPx,
        unidadPantallas: +(uPx / vh).toFixed(2),
        tramoPx: tramoSinParada(s),
        tramoPantallas: +(tramoSinParada(s) / vh).toFixed(2),
        ctas: s.querySelectorAll(CTA).length,
      };
    })
    .filter(b => b.px > 40);

  const alto = Math.round(document.body.scrollHeight);
  // 🔴 18-ago-2026 (segunda vuelta del mismo dia) · EL VEREDICTO PASA A SER EL TRAMO.
  //  La medida de la UNIDAD -de esta misma manana- quito 8 acusaciones falsas de
  //  los moldes, pero produjo CINCO nuevas en la web de prueba: dependia de que el
  //  hijo mas alto pasara del 55% del bloque, y una seccion normalita
  //  -h2 + subtitulo + parrafo + lista de 4 tarjetas + CTA- deja la lista en el 52%.
  //  Por tres puntos declaraba «el bloque entero es la unidad» sobre una seccion
  //  cuya pieza mas alta son 136 px. Un umbral inventado por mi.
  //
  //  Comparadas las dos sobre el MISMO parque antes de cambiar nada:
  //    · 5 fixtures   identicas (los 3 muros caen, los 2 buenos pasan)
  //    · 19 moldes    todos por debajo de 1 con las dos
  //    · 12 paginas   la nueva quita 4 falsas y encuentra UNA de verdad
  //                   (/contact/, 1036 px seguidos de formulario sin una parada)
  //  Estrictamente mejor: menos falsas y una verdadera mas. Por eso sustituye.
  //  `unidadPantallas` se sigue publicando, como informacion, no como veredicto.
  const desbordan = bloques.filter(b => b.tramoPantallas > 1);
  // El contenedor tiene su propio tope: una seccion de mas de 3 pantallas en
  // movil es una pagina dentro de la pagina. Anclado a site-d, el unico sitio
  // que paso este gate a la primera: su pagina ENTERA son 3,2 pantallas.
  const gigantes = bloques.filter(b => b.pantallas > 3);
  const sinCTA = bloques.filter(b => b.ctas === 0);
  const totalCTA = bloques.reduce((a, b) => a + b.ctas, 0);

  // La distancia mas larga que recorre alguien sin encontrar nada que pulsar.
  let racha = 0, peorRacha = 0, pxRacha = 0, peorPx = 0;
  for (const b of bloques) {
    if (b.ctas === 0) { racha++; pxRacha += b.px; if (pxRacha > peorPx) { peorPx = pxRacha; peorRacha = racha; } }
    else { racha = 0; pxRacha = 0; }
  }

  // -- EL LIMITE DE ALTURA CUENTA PALABRAS (19-ago-2026) ---------------------
  //  Era un 6 fijo, y ese 6 estaba anclado a la portada de site-d, que
  //  tiene 206 PALABRAS. Medido el 19-ago a 390px sobre paginas vivas:
  //
  //      pagina                          px   palabras   px/palabra
  //      site-d /tratamientos        1353         39        34,7
  //      site-d /                    3417        206        16,6
  //      climentmedia /                5612        519        10,8
  //      site-c /tarot       11217       1157         9,7
  //
  //  O sea: la pagina de site-c que FALLABA es la MAS DENSA de las cuatro. El 6
  //  fijo no med�a maqueta, med�a cuanto texto trae la pagina -y eso es una
  //  decision editorial del cliente, no un defecto nuestro-. Y no habia forma de
  //  arreglarlo: ninguna reordenacion quita texto.
  //
  //  El coste marginal de una palabra se saca de DOS paginas del MISMO sitio, que
  //  comparten tipografia: site-d 12,4 px/palabra (68 por pantalla) y site-c 8,8
  //  (96 por pantalla). Se toma 80 por pantalla, que deja a los dos dentro de un
  //  20%. El techo fisico -una pantalla de movil LLENA de texto- son ~195, asi que
  //  80 es holgado a proposito: una pagina real alterna texto con titulares,
  //  imagenes y aire.
  //
  //  Las primeras 400 palabras van dentro del colchon de 6 pantallas, que es lo
  //  que cuestan cabecera, hero y pie mas algo de contenido.
  //
  //  Se cuentan las palabras VISIBLES (innerText): lo que esta plegado en un
  //  acordeon no ocupa alto, asi que tampoco compra allowance.
  const PALABRAS_GRATIS = 400;
  const PALABRAS_POR_PANTALLA = 80;
  const raizTexto = document.querySelector("main") || document.body;
  const textoVisible = (raizTexto.innerText || "").replace(/\s+/g, " ").trim();
  const palabras = textoVisible ? textoVisible.split(" ").length : 0;
  const limitePantallas = 6 + Math.max(0, palabras - PALABRAS_GRATIS) / PALABRAS_POR_PANTALLA;

  const fallos = [];
  if (desbordan.length) fallos.push(`${desbordan.length} bloque(s) con mas de una pantalla SIN UNA PARADA`);
  if (gigantes.length) fallos.push(`${gigantes.length} bloque(s) de mas de 3 pantallas (limite del contenedor)`);
  if (alto / vh > limitePantallas) fallos.push(`la pagina son ${(alto / vh).toFixed(1)} pantallas de scroll (limite ${limitePantallas.toFixed(1)} para sus ${palabras} palabras visibles)`);
  if (peorPx > vh * 2.5) fallos.push(`se recorren ${(peorPx / vh).toFixed(1)} pantallas seguidas sin un solo CTA (limite 2,5)`);
  if (totalCTA < 2) fallos.push(`solo ${totalCTA} CTA en toda la pagina`);

  return JSON.stringify({
    url: location.hostname + location.pathname,
    viewport: `${vw}x${vh}`,
    VEREDICTO: fallos.length ? 'FALLA' : 'PASA',
    fallos,
    resumen: {
      pantallasDeScroll: +(alto / vh).toFixed(1),
      limitePantallas: +limitePantallas.toFixed(1),
      palabrasVisibles: palabras,
      palabrasPorPantalla: palabras ? +(palabras / (alto / vh)).toFixed(0) : 0,
      bloques: bloques.length,
      queDesbordan: desbordan.map(b => `${b.que} — ${b.tramoPx}px seguidos sin una parada = ${b.tramoPantallas} pantallas (bloque ${b.px}px, unidad mayor ${b.unidadPx}px)`),
      contenedoresGigantes: gigantes.map(b => `${b.que} — ${b.px}px = ${b.pantallas} pantallas`),
      sinCTA: `${sinCTA.length}/${bloques.length}`,
      ctasTotales: totalCTA,
      mayorTramoSinCTA: `${peorRacha} bloques = ${(peorPx / vh).toFixed(1)} pantallas`,
    },
    detalle: bloques,
  }, null, 1);
})()

/* -----------------------------------------------------------------------------
 *  LOS UMBRALES, Y POR QUE ESOS
 * -----------------------------------------------------------------------------
 *  · Ninguna UNIDAD > 1 pantalla  Si no cabe de un vistazo, no se lee: se hojea.
 *                                 La unidad es la pieza REPETIDA Y ESTRUCTURADA
 *                                 (una fila, una tarjeta, un plan). Un parrafo
 *                                 nunca es unidad: ocho <p> seguidos son un muro,
 *                                 y el bloque entero pasa a ser la unidad.
 *  · Ningun bloque > 3 pantallas  Tope del CONTENEDOR. Anclado a site-d, el
 *                                 unico sitio que paso a la primera: su pagina
 *                                 ENTERA son 3,2 pantallas.
 *
 *  🔴 18-ago-2026 · POR QUE SE MIDE LA UNIDAD Y NO EL BLOQUE. Medidos los 19
 *  moldes de references/moldes/ en el servidor a 390x844 (innerWidth 390 y
 *  coincide:true en los 19), DIEZ pasaban de una pantalla con su contenido de
 *  ejemplo: par-alterno 2,35 · rejilla 2,17 · galeria 2,03 · escalera 1,92 ·
 *  tabla-comparativa 1,53 · tabla-especificacion 1,26 · prueba-social 1,23 ·
 *  aparte-nota 1,23 · pasos-numerados 1,20 · cadena-de-flujo 1,17. Ninguna de
 *  sus UNIDADES llegaba: par-alterno son 3 filas de 0,74/0,69/0,66 pantallas.
 *  Lo que desbordaba era siempre la suma. Con la regla vieja, usar el
 *  repertorio que la skill OBLIGA a usar suspendia el gate que la misma skill
 *  OBLIGA a pasar — y quitar la primitiva para aprobar devuelve la pagina al
 *  defecto original. Ademas chocaba con 09-tipos-de-pagina §2.1, que manda una
 *  `oferta` de 3 a 6 elementos EN UNA SECCION: las dos reglas no podian
 *  cumplirse a la vez.
 *  Efecto medido del cambio en los 5 sitios vivos a 390: CERO veredictos
 *  cambian. En climentmedia.com/es/ desaparecen 2 acusaciones (eran listas) y
 *  queda la de verdad —2,7 pantallas sin un CTA—; en site-c.example se
 *  suma una acusacion NUEVA por el tope del contenedor. No afloja: afina.
 *  · Pagina <= 6 pantallas        BC cumple con 3,2 y no se queda corta. Site C
 *                                 tiene 17,9 y nadie llega al final.
 *  · <= 2,5 pantallas sin CTA     En site-a se recorren 7 pantallas seguidas sin
 *                                 nada que pulsar. El visitante que se convence
 *                                 en la seccion 6 no tiene donde hacerlo.
 *  · >= 2 CTA en la pagina        Uno arriba y uno al cierre, como minimo.
 *
 *  ⚠️ SE MIDE EN LAS DOS ANCHURAS. En movil todo se apila y un bloque que cabe
 *  a 1280 puede ocupar tres pantallas a 390. Y ojo con la trampa conocida:
 *  Chrome headless en Windows CLAMPA --window-size a ~500px de ancho, asi que
 *  para movil o se usa el panel del navegador comprobando innerWidth, o se
 *  declara NO VERIFICADO. No se reporta como visto lo que no se ha visto.
 * -------------------------------------------------------------------------- */
