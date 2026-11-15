// La calibracion del gcd de banner-probe.js (B9), 15-nov-2026. La llama run.js, en el host de medida.
//
// POR QUE EXISTE. La sonda lee del gcd que llega a Google si ad_user_data y ad_personalization estan puestas y si
// algo va concedido. Esa lectura es una TABLA de letras, y Google no la publica: su ayuda (tag-platform,
// consent-mode y consent-debugging, leidas ese dia) dice que gcd «codifica» la eleccion y que estos campos pueden
// cambiar. Las tablas de terceros no coinciden entre si. Asi que la tabla se mide: el gtag.js de Google, cargado
// con estados de consentimiento CONOCIDOS, y lo que pone en cada peticion. El estado que se espera sale de lo que
// se le dio (el update manda sobre el default), no de la tabla: si Google cambia una letra, esto se pone rojo.
//
// 🔴 ES LA UNICA PARTE DEL BANCO QUE SALE A LA RED, y solo para BAJAR el gtag.js. Todo envio (collect, ccm,
//    pagead, rmkt) se corta antes de salir: a Google no le llega nada. El ID es inventado (G-CALIBRA000) y el
//    dominio, .invalid. Sin red, la calibracion dice N/M, no verde.
const fs = require("fs"), path = require("path");

const D = "denied", G = "granted";
const todas = (v) => ({ ad_storage: v, analytics_storage: v, ad_user_data: v, ad_personalization: v });
// [nombre, default, update]: cada letra de la tabla sale en al menos uno; los dos ultimos fijan el ORDEN.
const CASOS = [
  ["sin Consent Mode", null, null],
  ["solo las senales v1, denegadas", { ad_storage: D, analytics_storage: D }, null],
  ["denegado por defecto", todas(D), null],
  ["concedido por defecto", todas(G), null],
  ["denegado y luego concedido", todas(D), todas(G)],
  ["denegado y luego denegado", todas(D), todas(D)],
  ["solo un update denegado", null, todas(D)],
  ["solo un update concedido", null, todas(G)],
  ["concedido y luego denegado", todas(G), todas(D)],
  ["concedido y luego concedido", todas(G), todas(G)],
  ["mezcla: anuncios y ad_user_data denegados, analitica y ad_personalization concedidas", { ad_storage: D, analytics_storage: G, ad_user_data: D, ad_personalization: G }, null],
  ["solo ad_user_data concedida", { ad_storage: D, analytics_storage: D, ad_user_data: G, ad_personalization: D }, null],
];
const final = (def, upd, s) => (upd && upd[s]) || (def && def[s]) || null;
const estado = (v) => (v === G ? "concedida" : v === D ? "denegada" : "no puesta");
const pagina = (def, upd) => `<!DOCTYPE html><html><head><meta charset="utf-8"><script>
window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments);}
${def ? `gtag('consent','default',${JSON.stringify(def)});` : ""}${upd ? `gtag('consent','update',${JSON.stringify(upd)});` : ""}
gtag('js', new Date()); gtag('config','G-CALIBRA000'); gtag('config','AW-123');
</script><script async src="https://www.googletagmanager.com/gtag/js?id=G-CALIBRA000"></script></head><body><p>calibracion</p></body></html>`;

async function calibrar({ lanzar, ver }) {
  const src = fs.readFileSync(path.join(__dirname, "..", "banner-probe.js"), "utf8");
  const m = (re) => (src.match(re) || [])[1];
  const tGcd = m(/^const GCD = (\{[^\n]+\});$/m), tSen = m(/^const SENALES = (\[[^\n]+\]);$/m), tLee = m(/^const letrasGcd = ([^\n]+);$/m);
  if (!tGcd || !tSen || !tLee) return ver("gcd: la sonda trae su tabla, su orden y su lector", false, "no estan en banner-probe.js como se esperan");
  const GCD = Function(`return ${tGcd}`)(), SENALES = Function(`return ${tSen}`)(), letras = Function(`return ${tLee}`)();

  const b = await lanzar({ executablePath: process.env.CHROME || "/usr/bin/google-chrome", args: ["--no-sandbox", "--disable-dev-shm-usage", "--disable-gpu"] });
  const vistos = [];
  let bajado = 0;
  try {
    for (const [nombre, def, upd] of CASOS) {
      const p = await b.newPage();
      await p.setUserAgent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36");
      await p.setRequestInterception(true);
      const peticiones = [];
      p.on("request", (r) => {
        let u; try { u = new URL(r.url()); } catch (e) { return r.abort(); }
        if (u.hostname === "calibra.invalid") return r.respond({ status: 200, contentType: "text/html; charset=utf-8", body: pagina(def, upd) });
        if (u.hostname === "www.googletagmanager.com" && u.pathname === "/gtag/js") return r.continue();
        const q = u.search + "\n" + (r.postData() || "");
        const gcd = (q.match(/(?:^|[?&\r\n])gcd=([^&\s]+)/) || [])[1], gcs = (q.match(/(?:^|[?&\r\n])gcs=([^&\s]+)/) || [])[1];
        if (gcd || gcs) peticiones.push({ host: u.hostname, gcd: gcd ? decodeURIComponent(gcd) : "", gcs: gcs || "" });
        return r.abort();   // nada sale a Google
      });
      p.on("response", (r) => { if (/googletagmanager\.com\/gtag\/js/.test(r.url()) && r.status() === 200) bajado++; });
      await p.goto("https://calibra.invalid/", { waitUntil: "networkidle2", timeout: 30000 }).catch(() => {});
      await new Promise((r) => setTimeout(r, 2500));
      await p.close();
      vistos.push({ nombre, def, upd, peticiones });
    }
  } finally { await b.close(); }
  if (!bajado) { console.log("  N/M   gcd: NOT MEASURED, no se pudo bajar el gtag.js de Google desde este host"); return; }

  for (const { nombre, def, upd, peticiones } of vistos) {
    const quiero = SENALES.map((s) => estado(final(def, upd, s)));
    const conGcd = peticiones.filter((x) => x.gcd);
    const leidas = conGcd.map((x) => (letras(x.gcd) || []).map((l) => GCD[l] || `«${l}» sin tabla`));
    const bien = conGcd.length > 0 && leidas.every((e) => e.join() === quiero.join());
    ver(`gcd · ${nombre}: ${quiero.join(", ")}`, bien,
      conGcd.length ? `${[...new Set(conGcd.map((x) => x.gcd))].join(" ")} -> ${[...new Set(leidas.map((e) => e.join(", ")))].join(" | ")}` : "ninguna peticion con gcd");
    // gcs: «G1» + anuncios + analitica; sin ninguna de las dos puestas, Google no lo manda.
    const ad = final(def, upd, "ad_storage"), an = final(def, upd, "analytics_storage");
    const conGcs = peticiones.filter((x) => x.gcs);
    if (ad || an) {
      const gcs = `G1${ad === G ? 1 : 0}${an === G ? 1 : 0}`;
      ver(`gcs · ${nombre}: ${gcs}`, conGcs.length > 0 && conGcs.every((x) => x.gcs === gcs), conGcs.map((x) => x.gcs).join(" ") || "ninguna peticion con gcs");
    } else ver(`gcs · ${nombre}: no se manda`, !conGcs.length, conGcs.map((x) => x.gcs).join(" "));
  }
}

module.exports = { calibrar, CASOS };
