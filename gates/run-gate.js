// run-gate.js <URL> <W> <H> <ficheroGate.js> [jsonGATE]
// Carga la URL en Chrome real, evalua el gate y devuelve su JSON.
//
// 🔴 18-ago-2026 · ESTE FICHERO VIVE AQUI, EN LA SKILL, Y SE EMPUJA EN CADA CORRIDA.
// Antes solo existia en ~/webtools/ del servidor: sin version, sin copia y sin
// nadie que lo vigilara. `forms-gate.js` declaraba en su cabecera que «se
// ejecuta con run-gate.js en el servidor» y `doc-gate D1` no lo cazaba porque
// solo mira rutas `references/...`. O sea: los TRES gates de navegador -maqueta,
// densidad y formulario- dependian de un fichero que no estaba en ninguna parte
// que controlemos, y `deploy.sh` se limitaba a comprobar si estaba y, si no,
// bajaba los tres a NO MEDIDO. Un `rm` en el servidor apagaba media puerta.
// Ahora la fuente es esta y el servidor recibe una copia en cada uso.
// REGLA DE LA CASA: innerWidth SIEMPRE, y `coincide`. Si no coincide, es basura.
const puppeteer = require("puppeteer-core");
const fs = require("fs");
(async () => {
  const [url, w, h, gateFile, gateCfg] = process.argv.slice(2);
  const src = fs.readFileSync(gateFile, "utf8");
  const b = await puppeteer.launch({
    executablePath: "/usr/bin/google-chrome",
    args: ["--no-sandbox", "--disable-dev-shm-usage", "--disable-gpu", "--hide-scrollbars"],
  });
  const p = await b.newPage();
  // 🔴 21-ago-2026 · EL USER-AGENT NO ES COSMETICA: SIN EL, DOS WEBS NO SE PUEDEN
  //  MEDIR. Chrome headless manda un UA que Hostinger responde con «Checking your
  //  browser…», y por eso site-a.example y shop.site-b.example salian NO MEDIDO en
  //  los tres gates de navegador desde el 18-ago. Se diagnostico como «muro
  //  anti-bot del hosting» y se apunto como decision de Manuel: era FALSO. Medido
  //  el 21-ago desde el mismo servidor y el mismo Chrome, cambiando SOLO el UA:
  //  title y h1 correctos, innerWidth 390. El servidor siempre pudo medir site-a;
  //  el que no sabia pedirla era este fichero.
  //  El UA se elige por ANCHO: a menos de 768 px se manda uno de movil, que es lo
  //  que manda un telefono de verdad. NO se tocan `isMobile` ni `hasTouch` a
  //  proposito: eso cambiaria el comportamiento de hover y de los breakpoints en
  //  las cinco webs a la vez, y hoy cuatro se miden bien. Un problema cada vez.
  //  ⚠️ Esto NO sustituye al testigo `sospechoso` de mas abajo, y por eso sigue
  //  ahi: un UA mejor hace que el muro no salga HOY. El dia que vuelva a salir,
  //  lo unico que evita un «cero defectos» falso es la comprobacion, no el UA.
  const UA_ESCRITORIO = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
                        "(KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36";
  const UA_MOVIL      = "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 " +
                        "(KHTML, like Gecko) Chrome/150.0.0.0 Mobile Safari/537.36";
  await p.setUserAgent(+w < 768 ? UA_MOVIL : UA_ESCRITORIO);
  await p.setViewport({ width: +w, height: +h, deviceScaleFactor: 1 });
  // 🔴 1-nov-2026 · EL CANDIDATO, SERVIDO CON LA URL DE PRODUCCION.
  //  Los gates de navegador corrian en el paso 6 de la puerta, DESPUES de subir, y no
  //  bloqueaban: una web salio con 10 FALLA de 16-18 medidas a la vista de todos.
  //  Para medir ANTES hay que servir el arbol del repo, y servirlo en 127.0.0.1 cambia
  //  el origen de la pagina: un enlace absoluto a https://dominio.tld pasa a ser
  //  «externo», el sitemap deja de casar y la pagina ya no es la que vera el visitante.
  //  Por eso no se levanta un servidor: se pide la URL REAL y cada peticion a ese
  //  origen se contesta desde el disco, con las mismas reglas que el servidor del
  //  candidato de qa-master.pl (`/` -> index.html, `x` -> x.html, `dir` -> 301 a
  //  `dir/`, 404 con 404.html). Lo demas (fuentes, GTM) va a la red como siempre.
  //    GATE_CANDIDATO=<dir del arbol>  GATE_SITIO=https://dominio.tld
  //  `candidato` en la linea de diagnostico cuenta las respuestas servidas del disco:
  //  si es 0, lo medido NO es el candidato, y quien llama no puede darlo por medido.
  const CAND = process.env.GATE_CANDIDATO || "", SITIO = process.env.GATE_SITIO || "";
  let servidas = 0;
  if (CAND && SITIO) {
    const path = require("path");
    const origen = new URL(SITIO).origin;
    const TIPOS = { html: "text/html; charset=utf-8", htm: "text/html; charset=utf-8",
      css: "text/css; charset=utf-8", js: "text/javascript; charset=utf-8", mjs: "text/javascript; charset=utf-8",
      json: "application/json; charset=utf-8", xml: "application/xml; charset=utf-8", txt: "text/plain; charset=utf-8",
      svg: "image/svg+xml", png: "image/png", jpg: "image/jpeg", jpeg: "image/jpeg", gif: "image/gif",
      webp: "image/webp", avif: "image/avif", ico: "image/x-icon", woff: "font/woff", woff2: "font/woff2",
      ttf: "font/ttf", otf: "font/otf", mp4: "video/mp4", webm: "video/webm", pdf: "application/pdf",
      webmanifest: "application/manifest+json" };
    const raiz = path.resolve(CAND);
    const esFichero = f => { try { return fs.statSync(f).isFile(); } catch (e) { return false; } };
    const resolver = ruta => {   // -> [fichero|null, redireccion|null]
      let r; try { r = decodeURIComponent(ruta); } catch (e) { r = ruta; }
      if (/(^|\/)\.\.(\/|$)/.test(r)) return [null, null];
      if (r === "/") return [path.join(raiz, "index.html"), null];
      const limpia = r.replace(/\/+$/, "");
      if (esFichero(path.join(raiz, limpia))) return [path.join(raiz, limpia), null];
      if (esFichero(path.join(raiz, limpia + ".html"))) return [path.join(raiz, limpia + ".html"), null];
      if (esFichero(path.join(raiz, limpia, "index.html")))
        return [path.join(raiz, limpia, "index.html"), /\/$/.test(r) ? null : limpia + "/"];
      return [null, null];
    };
    await p.setRequestInterception(true);
    p.on("request", req => {
      let u; try { u = new URL(req.url()); } catch (e) { return req.continue(); }
      if (u.origin !== origen) return req.continue();
      const [f, redir] = resolver(u.pathname);
      servidas++;
      if (redir) return req.respond({ status: 301, headers: { location: origen + redir + u.search }, body: "" });
      if (f) {
        const ext = (f.match(/\.([a-z0-9]+)$/i) || [, ""])[1].toLowerCase();
        return req.respond({ status: 200, contentType: TIPOS[ext] || "application/octet-stream", body: fs.readFileSync(f) });
      }
      const e404 = path.join(raiz, "404.html");
      return req.respond({ status: 404, contentType: "text/html; charset=utf-8",
                           body: esFichero(e404) ? fs.readFileSync(e404) : "" });
    });
  }
  await p.goto(url, { waitUntil: "networkidle2", timeout: 60000 });
  // `anchoPedido` viaja SIEMPRE, lo pida el gate o no. Es la unica forma de que
  // un gate pueda afirmar «lo que medi es lo que se PIDIO» sin cablearse un ancho
  // concreto: `mobile-gate.js` tenia escrito `coincide: vw === 390` y por eso
  // marcaba como basura cualquier medida a 360 -- que es un ancho legitimo y donde
  // justamente aparecia el defecto. Un control de honestidad que solo acepta un
  // valor no comprueba honestidad: comprueba ese valor.
  await p.evaluate((c, aw) => {
    // Va como VALOR POR DEFECTO, no imponiendose: si se pisa desde la linea de
    // comandos, el gate puede probarse en ROJO (pedir 390 y declarar 400 tiene
    // que dar `coincide: false`). Un guardia que no se puede poner en rojo no
    // esta probado, y este ya se equivoco una vez callando un defecto real.
    window.__GATE__ = Object.assign({ anchoPedido: aw }, c ? JSON.parse(c) : {});
  }, gateCfg || null, +w);
  // scroll completo: las animaciones de entrada (IntersectionObserver) dejan
  // opacity:0 en lo que nunca entro en viewport, y eso falsea alturas y contraste
  await p.evaluate(async () => {
    for (let y = 0; y < document.body.scrollHeight; y += 500) {
      scrollTo(0, y); await new Promise(r => setTimeout(r, 40));
    }
    scrollTo(0, 0);
  });
  await new Promise(r => setTimeout(r, 600));
  const iw = await p.evaluate(() => innerWidth);
  // 🔴 18-ago-2026 · `coincide` NO BASTA. Comprueba que el ANCHO es el pedido; no
  //  comprueba que lo medido sea LA PAGINA. Medido ese dia: site-a.example y
  //  shop.site-b.example sirven a este Chrome un muro anti-bot -- «Checking your
  //  browser» con un spinner-- mientras `curl` recibe la web entera (23 KB, 10
  //  secciones, 15 CTAs). El gate media el muro, veia 1 pantalla y 0 CTA, y lo
  //  reportaba como **FALLA**: una acusacion falsa contra dos de las cinco webs,
  //  con `coincide:true` dando confianza.
  //  `crawl-links.pl` ya tenia su R0 («el rastreo es valido») y por eso dijo
  //  «instrumento invalido» en site-b. Esto es su R0.
  const diag = await p.evaluate(() => ({
    titulo: (document.title || '').slice(0, 90),
    main: !!document.querySelector('main'),
    secciones: document.querySelectorAll('section,article').length,
    textoLen: ((document.body && document.body.innerText) || '').length,
  }));
  const RETO = /checking your browser|just a moment|attention required|verifying you are human|enable javascript|ddos|cloudflare/i;
  const sospechoso = RETO.test(diag.titulo) ||
                     (!diag.main && diag.secciones === 0 && diag.textoLen < 400);
  let out;
  try { out = await p.evaluate(src); }
  catch (e) { out = JSON.stringify({ ERROR: String(e && e.message || e) }); }
  console.log(JSON.stringify({
    url, pedido: +w, innerWidth: iw, coincide: iw === +w,
    ...(CAND && SITIO ? { candidato: servidas } : {}),
    titulo: diag.titulo, secciones: diag.secciones, hayMain: diag.main,
    sospechoso,
    ...(sospechoso ? { AVISO: 'esto NO parece la pagina: muro anti-bot o render vacio. La medida NO vale como veredicto.' } : {}),
  }));
  console.log(typeof out === "string" ? out : JSON.stringify(out, null, 1));
  await b.close();
})().catch(e => { console.error("RUNNER-ERROR " + e.message); process.exit(3); });
