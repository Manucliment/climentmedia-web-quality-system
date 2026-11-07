// banner-probe.js <URL> [W H]  ·  el aviso de cookies, mirado como lo vive un visitante
// =============================================================================
// Corre en el host de medida (NAV_HOST, ~/webtools), con el Chrome de run-gate.js:
//   scp gates/banner-probe.js gates/run-gate.js NAV_HOST:webtools/ && ssh NAV_HOST 'cd ~/webtools && node banner-probe.js https://dominio.tld/'
//   (necesita run-gate.js al lado: de ahi saca como servir un arbol). Con GATE_CANDIDATO=<dir> mide ese arbol
//   con la URL de produccion, como la puerta en el paso 1-quater; sin el, lo servido.
// Sale 0 si todo PASA o AVISA, 1 si algo FALLA, 3 si el instrumento no pudo medir.
//
// POR QUE EXISTE (3-nov-2026)
// ---------------------------
// El estandar escribe cinco reglas del aviso (ME-04 a ME-07 en blueprint/04) y el
// nuestro las cumple, pero NINGUN gate las mide: qa-master mira el ORDEN del codigo
// (MED-02) y que la politica diga la verdad (MED-07), no lo que ve la persona. Un
// aviso se puede romper en una web de cliente -un Rechazar convertido en enlace
// gris, un muro que tapa la pagina, el aviso en ingles en una web en frances- y no
// lo veria nadie. Lo pedia, punto por punto, la lista Cookie & CMP de una auditoria
// de medicion de una agencia.
//
// LO QUE MIDE, en un Chrome NUEVO (sin cookies ni almacenamiento: primera visita)
//   B0  antes de decidir, ninguna cookie de medicion o publicidad
//   B1  el aviso se ve en la primera visita (si la pagina carga medicion)
//   B2  Aceptar y Rechazar, los dos, en la PRIMERA capa
//   B3  con el mismo peso: tamano, letra y grosor (un Rechazar sin marco es AVISO)
//   B4  no es un muro: la pagina se ve y se puede usar con el aviso puesto
//   B5  el aviso habla el idioma de la pagina (<html lang>)
//   B6  tras Rechazar, ninguna cookie de medicion o publicidad (MED-14)
//   B7  la decision se recuerda: al recargar, el aviso no vuelve
//   B8  se puede retirar: un control fuera del aviso lo vuelve a abrir (ME-07)
//
// 🔴 NUNCA PULSA ACEPTAR. Una sonda que acepta cuenta como visita en el GA4 del
//    cliente (con su sesion, su fuente y su pais): ya paso, y por eso nuestras
//    sondas rechazan. Que Aceptar CARGUE la medicion no se mide aqui: lo mide la
//    medicion del cliente, que sin aceptaciones no tendria datos.
//
// LO QUE NO VE, DICHO
//   · Un aviso de una CMP dentro de un iframe (OneTrust, Cookiebot en algunos
//     modos): B1 dice NO MEDIDO si la pagina carga una CMP conocida y no encuentra
//     el aviso en el documento.
//   · La tasa de aceptacion: eso es contar personas, y es otra decision.
//   · Si los textos del aviso dicen la verdad: eso es MED-07, contra el contenedor.
// =============================================================================
const puppeteer = require("puppeteer-core");
const fs = require("fs");
const path = require("path");
// Va al lado de run-gate.js (en gates/ y en ~/webtools del host de medida): sin el, no mide.
const { servir, lanzar } = require("./run-gate.js");

const [url, W = "1298", H = "900"] = process.argv.slice(2);
if (!url) { console.error("uso: node banner-probe.js <URL> [W H]"); process.exit(2); }

// Cookies que solo pone la medicion o la publicidad. Las de la propia decision
// (cm_consent, cookie_consent...) y las tecnicas no cuentan.
const RASTREO = /^(_ga|_ga_.+|_gid|_gat.*|_gcl_.+|_fbp|_fbc|_clck|_clsk|_hj.+|_uet.+|_ttp|_tt_.+|IDE|test_cookie|fr|_pin_unauth|li_sugr|bcookie|_scid.*)$/;
const CMP = /cookiebot|onetrust|cookielaw|didomi|iubenda|usercentrics|quantcast|consentmanager|trustarc|termly|cookieyes|complianz/i;

// Textos de los botones, por idioma. Se comparan ENTEROS (normalizados): una
// frase que contiene «accept» no es el boton Aceptar.
const SI = {
  es: /^(aceptar|aceptar todo|aceptar todas|aceptar cookies|acepto|permitir|permitir todas)$/,
  fr: /^(accepter|tout accepter|j'accepte|accepter tout|accepter et fermer)$/,
  en: /^(accept|accept all|allow|allow all|i accept|agree|accept cookies)$/,
  pt: /^(aceitar|aceitar todos|aceitar todas|aceitar tudo|concordo)$/,
  nl: /^(accepteren|alles accepteren|akkoord|accepteer|alle cookies accepteren)$/,
  de: /^(akzeptieren|alle akzeptieren|zustimmen|einverstanden)$/,
};
const NO = {
  es: /^(rechazar|rechazar todo|rechazar todas|solo necesarias|solo las necesarias|no acepto)$/,
  fr: /^(refuser|tout refuser|continuer sans accepter|refuser tout|uniquement necessaires)$/,
  en: /^(reject|reject all|decline|deny|only necessary|necessary only|refuse)$/,
  pt: /^(recusar|rejeitar|recusar todos|recusar tudo|rejeitar todos|rejeitar tudo|rejeitar todas|apenas necessarios)$/,
  nl: /^(weigeren|alles weigeren|weiger|alleen noodzakelijk)$/,
  de: /^(ablehnen|alle ablehnen|nur notwendige)$/,
};
const REABRE = /cookie|galleta|consent|privacidad|privacy|vie priv|privacit|privacidade|toestemming|datenschutz/i;

const lineas = [];
let falla = 0, nomedido = 0;
const res = (estado, id, texto, dato) => {
  lineas.push({ estado, id, texto, ...(dato !== undefined ? { dato } : {}) });
  if (estado === "FALLA") falla++;
  if (estado === "NO MEDIDO") nomedido++;
};

(async () => {
  // 7-nov-2026 · por lanzar() de run-gate.js: su perfil se borra al salir por donde sea.
  const b = await lanzar({
    executablePath: process.env.CHROME || "/usr/bin/google-chrome",
    args: ["--no-sandbox", "--disable-dev-shm-usage", "--disable-gpu", "--hide-scrollbars"],
  });
  const p = await b.newPage();
  // Mismo UA que run-gate.js, y por el mismo motivo: Hostinger devuelve un muro a HeadlessChrome.
  await p.setUserAgent(+W < 768
    ? "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Mobile Safari/537.36"
    : "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36");
  await p.setViewport({ width: +W, height: +H, deviceScaleFactor: 1 });

  // El arbol del disco, con la funcion de run-gate.js (6-nov-2026: una sola copia; esta
  // tenia la suya, sin 301 ni 404.html):
  //   BANNER_DIR      las fixturas del banco: el origen de la URL sale del disco, y nada a la red
  //   GATE_CANDIDATO  el candidato de la puerta, servido con la URL de produccion (GATE_SITIO,
  //                   o el origen de la URL); lo demas (GTM, fuentes) va a la red, como en run-gate
  //   ninguno         lo servido
  // Fuera de las fixturas se abortan los envios de medicion (el contador del aviso y GA4):
  // esta sonda rechaza el aviso, y ese rechazo contaba como una visita en el contador.
  const DIR = process.env.BANNER_DIR || "", CAND = process.env.GATE_CANDIDATO || "";
  const red = DIR ? await servir(p, { raiz: DIR, sitio: url, fuera: "abortar" })
    : await servir(p, { raiz: CAND, sitio: CAND ? (process.env.GATE_SITIO || url) : "", medicion: true });

  const cdp = await p.target().createCDPSession();
  const cookiesRastreo = async () => {
    const { cookies } = await cdp.send("Network.getAllCookies");
    return [...new Set(cookies.filter((c) => RASTREO.test(c.name)).map((c) => c.name))];
  };
  const espera = (ms) => new Promise((r) => setTimeout(r, ms));

  // El aviso: el elemento VISIBLE mas pequeno que habla de cookies o consentimiento
  // y lleva al menos un boton. Se marca con data-banner-probe para encontrarlo luego.
  const buscar = () => p.evaluate((siSrc, noSrc) => {
    const norm = (t) => (t || "").replace(/\s+/g, " ").trim().toLowerCase()
      .normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/[’]/g, "'");
    const SI = siSrc.map((s) => new RegExp(s)), NO = noSrc.map((s) => new RegExp(s));
    const visible = (e) => {
      const s = getComputedStyle(e), r = e.getBoundingClientRect();
      return s.display !== "none" && s.visibility !== "hidden" && +s.opacity > 0.05 && r.width > 4 && r.height > 4 && !e.closest("[hidden]");
    };
    document.querySelectorAll("[data-banner-probe]").forEach((e) => e.removeAttribute("data-banner-probe"));
    const pal = /cookie|consent|galleta|privacidad|privacy|vie priv|privacidade|analytics|toestemming/i;
    const cands = [...document.querySelectorAll("body *")].filter((e) => {
      if (!/^(DIV|ASIDE|SECTION|DIALOG|FORM|FOOTER|NAV)$/.test(e.tagName)) return false;
      const id = (e.id + " " + e.className + " " + (e.getAttribute("aria-label") || "")).toString();
      return (/cookie|consent|gdpr|rgpd|cc-|cmp/i.test(id) || /dialog|alertdialog|region/.test(e.getAttribute("role") || ""))
        && pal.test(e.innerText || "") && e.querySelector("button,a,[role=button]") && visible(e);
    }).filter((e) => !e.closest("footer") || /cookie|consent/i.test(e.id + e.className));
    // el mas exterior que no sea un contenedor de pagina (menos del 95 % del documento)
    const doc = document.documentElement.scrollHeight * innerWidth;
    const fuera = cands.filter((e) => !cands.some((o) => o !== e && o.contains(e)))
      .filter((e) => { const r = e.getBoundingClientRect(); return r.width * r.height < 0.95 * doc; });
    // 🔴 6-nov-2026 · LA CASILLA DE PRIVACIDAD DE UN FORMULARIO NO ES EL AVISO. Se cogia el
    //    primer candidato en el orden del documento, y la fila «He leido y acepto la politica
    //    de privacidad» de un formulario de contacto (`<div class="campo consent">`, con su
    //    enlace) va ANTES que el aviso, que se pinta al final del body: B2 FALLA en una web
    //    nuestra con su aviso bien. Ahora manda el que lleva Aceptar o Rechazar; si ninguno,
    //    el primero que no esta DENTRO de un formulario; y si todos lo estan, no hay aviso
    //    (una pagina que mide, B1 FALLA, que es lo que es). Banco: los tres casos «casilla».
    const tx = (b) => norm(b.innerText || b.value || b.getAttribute("aria-label"));
    const decide = (e) => [...e.querySelectorAll("button,a,[role=button],input[type=button],input[type=submit]")]
      .filter(visible).some((b) => SI.some((x) => x.test(tx(b))) || NO.some((x) => x.test(tx(b))));
    const enFormulario = (e) => !!(e.parentElement && e.parentElement.closest("form"));
    const caja = fuera.find(decide) || fuera.find((e) => !enFormulario(e));
    if (!caja) return null;
    caja.setAttribute("data-banner-probe", "1");
    const r = caja.getBoundingClientRect();
    const botones = [...caja.querySelectorAll("button,a,[role=button],input[type=button],input[type=submit]")].filter(visible).map((e) => {
      const s = getComputedStyle(e), q = e.getBoundingClientRect();
      const t = norm(e.innerText || e.value || e.getAttribute("aria-label"));
      const lang = (lst) => Object.keys(lst).find((k) => lst[k].test(t));
      const si = SI.findIndex((x) => x.test(t)), no = NO.findIndex((x) => x.test(t));
      return { t, si: si >= 0, no: no >= 0, w: q.width, h: q.height, fs: parseFloat(s.fontSize), fw: +s.fontWeight || 400,
        fondo: !/rgba\(0, 0, 0, 0\)|transparent/.test(s.backgroundColor), marco: parseFloat(s.borderTopWidth) > 0 && s.borderTopStyle !== "none",
        x: q.left + q.width / 2, y: q.top + q.height / 2 };
    });
    // muro: lo que hay en tres puntos de la pantalla, fuera del aviso, ¿es una capa
    // DEL AVISO? Fija, de casi toda la pantalla, y que contiene el aviso, se llama
    // como el o lleva fondo (el velo). 🔴 Sin esa condicion, el lienzo decorativo
    // del hero de una web (canvas absoluto de 1298x900) contaba como muro: 3-nov,
    // un aviso del 3 % de la pantalla salia FALLA.
    const pts = [[innerWidth / 2, innerHeight / 4], [innerWidth / 4, innerHeight / 2], [innerWidth * 0.75, innerHeight / 2]];
    const tapado = pts.filter(([x, y]) => {
      if (x >= r.left && x <= r.right && y >= r.top && y <= r.bottom) return false;
      for (let e = document.elementFromPoint(x, y), n = 0; e && e !== document.body && n < 4; e = e.parentElement, n++) {
        if (/^(CANVAS|VIDEO|IMG|PICTURE|SVG)$/i.test(e.tagName)) return false;
        const q = e.getBoundingClientRect(), s = getComputedStyle(e);
        if (s.position !== "fixed" || q.width < innerWidth * 0.9 || q.height < innerHeight * 0.9) continue;
        const delAviso = e.contains(caja) || /cookie|consent|cmp|gdpr|rgpd|overlay|backdrop|modal|cc-/i.test(e.id + " " + e.className)
          || !/rgba\(0, 0, 0, 0\)|transparent/.test(s.backgroundColor);
        if (delAviso) return true;
      }
      return false;
    }).length;
    const bloq = [document.documentElement, document.body].some((e) => getComputedStyle(e).overflowY === "hidden");
    return { botones, area: (r.width * r.height) / (innerWidth * innerHeight), tapado, bloq,
      texto: norm(caja.innerText).slice(0, 300) };
  }, Object.values(SI).map((r) => r.source), Object.values(NO).map((r) => r.source));
  const idiomaDe = (t) => Object.keys(SI).find((k) => SI[k].test(t) || NO[k].test(t));

  await p.goto(url, { waitUntil: "networkidle2", timeout: 60000 });
  await espera(1500);   // consent.js con defer pinta el aviso despues de la carga
  const iw = await p.evaluate(() => innerWidth);
  const fuente = await p.content();
  const lang = (await p.evaluate(() => document.documentElement.lang || "")).slice(0, 2).toLowerCase();

  const antes = await cookiesRastreo();
  antes.length ? res("FALLA", "B0", "cookies de medicion o publicidad ANTES de decidir", antes.join(", "))
               : res("PASA", "B0", "ninguna cookie de medicion antes de decidir");

  const a = await buscar();
  const mide = /googletagmanager|gtag\(|google-analytics|fbq\(|connect\.facebook|clarity\.ms|hotjar|consent\.js/i.test(fuente);
  if (!a) {
    if (CMP.test(fuente)) res("NO MEDIDO", "B1", "carga una CMP de terceros y su aviso no esta en el documento (iframe o tarde): mirarlo a mano");
    else if (mide) res("FALLA", "B1", "la pagina carga medicion y no se ve ningun aviso de cookies en la primera visita");
    else res("PASA", "B1", "la pagina no carga medicion de terceros: no hace falta aviso");
  } else {
    res("PASA", "B1", "el aviso se ve en la primera visita", a.texto.slice(0, 90));
    const si = a.botones.find((x) => x.si), no = a.botones.find((x) => x.no);
    if (!si || !no) res("FALLA", "B2", `en la primera capa falta ${!si && !no ? "Aceptar y Rechazar" : !si ? "Aceptar" : "Rechazar"}`, a.botones.map((x) => x.t).join(" | "));
    else {
      res("PASA", "B2", "Aceptar y Rechazar en la primera capa", `«${si.t}» · «${no.t}»`);
      // 🔴 El ANCHO no mide el peso: «Refuser» es mas corto que «Tout accepter» con
      //    el mismo boton (3-nov: 77 frente a 115 px, misma altura y letra, salia
      //    FALLA). El alto, la letra y el grosor si; el ancho, solo si es la mitad.
      const alto = Math.min(si.h, no.h) / Math.max(si.h, no.h), ancho = no.w / si.w;
      const dif = [];
      if (no.h < si.h && alto < 0.8) dif.push(`alto ${Math.round(no.h)} frente a ${Math.round(si.h)} px`);
      if (si.fs - no.fs > 1) dif.push(`letra ${no.fs}px frente a ${si.fs}px`);
      if (si.fw - no.fw >= 200) dif.push(`grosor ${no.fw} frente a ${si.fw}`);
      if (dif.length) res("FALLA", "B3", "Rechazar pesa menos que Aceptar", dif.join(" · "));
      else if ((si.fondo || si.marco) && !(no.fondo || no.marco)) res("AVISO", "B3", "Rechazar va sin fondo ni marco y Aceptar con el: mismo tamano, menos visible");
      else if (ancho < 0.5) res("AVISO", "B3", "Rechazar mide menos de la mitad de ancho que Aceptar", `${Math.round(no.w)} frente a ${Math.round(si.w)} px`);
      else res("PASA", "B3", "Aceptar y Rechazar con el mismo peso", `alto ${Math.round(no.h)}/${Math.round(si.h)} px, letra ${si.fs}/${no.fs}px`);
      const li = idiomaDe(si.t) || idiomaDe(no.t);
      if (!lang) res("NO MEDIDO", "B5", "la pagina no declara <html lang>");
      else if (!li) res("NO MEDIDO", "B5", "los botones no dicen en que idioma estan");
      else if (li !== lang) res("FALLA", "B5", `el aviso habla ${li} y la pagina ${lang}`, `«${si.t}» · «${no.t}»`);
      else res("PASA", "B5", `el aviso habla el idioma de la pagina (${lang})`);
    }
    if (a.tapado >= 2 || a.area > 0.6) res("FALLA", "B4", "el aviso es un muro: tapa la pagina hasta decidir", `${Math.round(a.area * 100)} % de la pantalla, ${a.tapado} de 3 puntos tapados`);
    else if (a.bloq) res("AVISO", "B4", "con el aviso puesto la pagina no se puede desplazar (overflow hidden)");
    else res("PASA", "B4", "no es un muro", `${Math.round(a.area * 100)} % de la pantalla`);

    if (no) {
      const pulsado = await p.evaluate((t) => {
        const norm = (x) => (x || "").replace(/\s+/g, " ").trim().toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/[’]/g, "'");
        const caja = document.querySelector("[data-banner-probe]");
        const e = caja && [...caja.querySelectorAll("button,a,[role=button],input[type=button],input[type=submit]")]
          .find((x) => norm(x.innerText || x.value || x.getAttribute("aria-label")) === t);
        if (!e) return false; e.click(); return true;
      }, no.t);
      if (!pulsado) res("NO MEDIDO", "B6", "no se pudo pulsar Rechazar");
      else {
        await espera(2500);
        const tras = await cookiesRastreo();
        tras.length ? res("FALLA", "B6", "tras Rechazar hay cookies de medicion o publicidad", tras.join(", "))
                    : res("PASA", "B6", "tras Rechazar, ninguna cookie de medicion");
        await p.reload({ waitUntil: "networkidle2", timeout: 60000 });
        await espera(1500);
        const otra = await buscar();
        otra ? res("FALLA", "B7", "al recargar, el aviso vuelve: la decision no se recuerda")
             : res("PASA", "B7", "al recargar, la decision se recuerda");
        // B8: un control fuera del aviso que lo reabre. Un enlace a la POLITICA no
        // reabre nada: tiene que ser un boton, o un enlace que no lleva a otra pagina.
        const pulsaReabre = () => p.evaluate((src) => {
          const RE = new RegExp(src, "i");
          const e = [...document.querySelectorAll("button,a,[role=button]")].find((x) => {
            if (!RE.test(x.innerText || x.getAttribute("aria-label") || "")) return false;
            if (x.tagName !== "A") return true;
            const h = x.getAttribute("href") || "";
            return h === "" || h === "#" || /^javascript:/i.test(h) || x.hasAttribute("onclick") || [...x.attributes].some((a) => /^data-/.test(a.name));
          });
          if (!e) return null; const t = (e.innerText || e.getAttribute("aria-label") || "").trim(); e.click(); return t;
        }, REABRE.source);
        let reabre = await pulsaReabre(), donde = "";
        // Si no esta en la pagina, se busca en la politica que enlaza (el pie o el aviso):
        // retirarlo ahi es posible, pero a dos clics y no desde cualquier pagina (ME-07).
        if (!reabre) {
          const pol = await p.evaluate(() => {
            const a = [...document.querySelectorAll("a[href]")].find((x) => /cookie|privac|confidential|datenschutz/i.test(x.getAttribute("href")) && !/^(mailto|tel):/i.test(x.getAttribute("href")));
            return a ? a.href : null;
          });
          if (pol) {
            await p.goto(pol, { waitUntil: "networkidle2", timeout: 60000 }); await espera(800);
            reabre = await pulsaReabre(); donde = new URL(pol).pathname;
          }
        }
        if (!reabre) res("FALLA", "B8", "no hay ningun control para retirar el consentimiento (un boton que reabra el aviso), ni en la pagina ni en su politica");
        else {
          await espera(1000);
          const abierto = await buscar();
          if (!abierto) res("FALLA", "B8", `«${reabre}»${donde ? ` (en ${donde})` : ""} no reabre el aviso`);
          else if (donde) res("AVISO", "B8", `el consentimiento solo se retira desde ${donde}: el pie de las paginas no lo ofrece`, `«${reabre}»`);
          else res("PASA", "B8", "el consentimiento se puede retirar", `«${reabre}» reabre el aviso`);
        }
      }
    } else {
      res("NO MEDIDO", "B6", "sin boton Rechazar no se puede medir lo que pasa al rechazar");
    }
  }

  // `candidato` cuenta lo servido del disco: 0 con GATE_CANDIDATO es que no se midio el candidato.
  console.log(JSON.stringify({ url, pedido: +W, innerWidth: iw, coincide: iw === +W, lang,
    ...(CAND && !DIR ? { candidato: red.servidas } : {}), ...(!DIR ? { medicionAbortada: red.abortadas } : {}) }));
  for (const l of lineas) console.log(`${l.estado.padEnd(9)} ${l.id}  ${l.texto}${l.dato ? `  · ${l.dato}` : ""}`);
  const sinCandidato = CAND && !DIR && !red.servidas;
  const v = iw !== +W ? "NO VALE (el ancho no es el pedido)" : sinCandidato ? "NO VALE (no se sirvio nada del candidato: lo medido es otra cosa)"
    : falla ? `FALLA (${falla})` : nomedido ? `PASA CON ${nomedido} SIN MEDIR` : "PASA";
  console.log(`VEREDICTO: ${v}`);
  await b.close();
  process.exit(iw !== +W || sinCandidato ? 3 : falla ? 1 : 0);
})().catch((e) => { console.error("RUNNER-ERROR " + e.message); process.exit(3); });
