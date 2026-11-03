// Banco de banner-probe.js (3-nov-2026). Corre en el host de medida, donde esta Chrome:
//   bash gates/banner-probe-tests/tests.sh        (copia esto y la sonda, y lo lanza alli)
// Cada caso es una pagina de mentira con UN defecto, servida del disco con un origen
// inventado (BANNER_DIR): no sale nada a la red. Los identificadores son de ejemplo.
//
// 🔑 Los dos casos que PASAN y valen tanto como los que fallan son los falsos positivos
//    del primer dia, medidos contra webs reales: un lienzo decorativo del hero, absoluto
//    y de toda la pantalla, que se leia como muro; y un «Rechazar» mas estrecho que
//    «Aceptar todo» solo porque su texto es mas corto, que se leia como menos peso.
const fs = require("fs"), os = require("os"), path = require("path");
const { spawnSync } = require("child_process");

const SONDA = path.join(__dirname, "..", "banner-probe.js");
const raiz = fs.mkdtempSync(path.join(os.tmpdir(), "banner-probe-"));

// Un aviso propio minimo, del mismo tipo que los nuestros: localStorage, dos botones,
// y un boton en el pie con data-cc-act="reopen". Cada caso cambia UNA pieza.
function pagina(o = {}) {
  const lang = o.lang || "es";
  const si = o.si === undefined ? "Aceptar" : o.si, no = o.no === undefined ? "Rechazar" : o.no;
  const btnNo = o.noEnlace
    ? `<a href="#" data-cc-act="none" style="font-size:11px;color:#999">${no}</a>`
    : no ? `<button data-cc-act="none" class="b">${no}</button>` : "";
  const aviso = `<div id="cookie-consent" role="dialog" style="position:fixed;bottom:16px;left:16px;right:16px;background:#fff;border:1px solid #ccc;padding:12px;z-index:9">
      <p>Usamos cookies de medicion solo si aceptas.</p>
      ${si ? `<button data-cc-act="all" class="b">${si}</button>` : ""} ${btnNo} <button data-cc-act="config" class="l">Configurar</button></div>`;
  return `<!DOCTYPE html><html lang="${lang}"><head><meta charset="utf-8"><title>Fixture</title>
  <style>body{margin:0;font:16px sans-serif} .b{font:16px sans-serif;padding:10px 18px;border:1px solid #333;background:#eee} .l{background:none;border:0;text-decoration:underline}
  .hero{position:relative;height:900px} canvas{position:absolute;inset:0;width:100%;height:100%}</style>
  <script>/* gtag( para que la sonda sepa que la pagina mide */ window.dataLayer=[];${o.cookieAntes ? 'document.cookie="_ga=GA1.1.1.1;path=/";' : ""}</script></head>
  <body><main><section class="hero">${o.lienzo ? '<canvas id="neural"></canvas>' : ""}<h1>Portada</h1><p>Texto de la portada.</p></section></main>
  ${o.muro ? `<div class="velo" style="position:fixed;inset:0;background:rgba(0,0,0,.6);z-index:8">${aviso}</div>` : aviso}
  <footer>${o.sinReabrir ? "" : '<button data-cc-act="reopen">Configurar cookies</button>'} <a href="/politica-cookies/">Politica de cookies</a></footer>
  <script>
    var c = document.getElementById("cookie-consent"), velo = document.querySelector(".velo");
    function ver(v){ (velo || c).style.display = v ? "" : "none"; }
    ${o.olvida ? "" : 'if (localStorage.getItem("cc")) ver(false);'}
    document.addEventListener("click", function (e) {
      var b = e.target.closest("[data-cc-act]"); if (!b) return; var a = b.getAttribute("data-cc-act");
      if (a === "none") { localStorage.setItem("cc", "no"); ${o.rechazoFalso ? 'document.cookie="_fbp=fb.1.1.1;path=/";' : ""} ver(false); }
      if (a === "reopen") { e.preventDefault(); ver(true); }
    });
  </script></body></html>`;
}
const politica = (o = {}) => `<!DOCTYPE html><html lang="es"><head><meta charset="utf-8"><title>Politica</title></head><body><main><h1>Politica de cookies</h1>
  ${o.reabre ? '<button id="cookie-settings" onclick="var c=document.getElementById(\'cookie-consent\');c.style.display=\'\'">Cambiar mis preferencias de cookies</button>' : ""}</main>
  <div id="cookie-consent" role="dialog" style="position:fixed;bottom:0;left:0;right:0;background:#fff;display:none"><p>Cookies</p><button>Aceptar</button> <button>Rechazar</button></div>
  <script>if(!localStorage.getItem("cc")) document.getElementById("cookie-consent").style.display="";</script></body></html>`;

const CASOS = [
  // [nombre, opciones de la portada, opciones de la politica, { comprobacion: estado esperado }]
  ["bueno", {}, {}, { B0: "PASA", B1: "PASA", B2: "PASA", B3: "PASA", B4: "PASA", B5: "PASA", B6: "PASA", B7: "PASA", B8: "PASA" }],
  ["lienzo decorativo no es un muro", { lienzo: true }, {}, { B4: "PASA" }],
  ["muro con velo", { muro: true }, {}, { B4: "FALLA" }],
  ["Rechazar corto, mismo boton", { si: "Aceptar todas", no: "Rechazar" }, {}, { B3: "PASA" }],
  ["Rechazar como enlace gris", { noEnlace: true }, {}, { B3: "FALLA" }],
  ["sin Rechazar en la primera capa", { no: "" }, {}, { B2: "FALLA" }],
  ["aviso en espanol en una pagina en frances", { lang: "fr" }, {}, { B5: "FALLA" }],
  ["cookie de medicion antes de decidir", { cookieAntes: true }, {}, { B0: "FALLA" }],
  ["Rechazar pone una cookie de Meta", { rechazoFalso: true }, {}, { B6: "FALLA" }],
  ["la decision se olvida al recargar", { olvida: true }, {}, { B7: "FALLA" }],
  ["sin forma de retirar", { sinReabrir: true }, {}, { B8: "FALLA" }],
  ["solo se retira desde la politica", { sinReabrir: true }, { reabre: true }, { B8: "AVISO" }],
];

let ok = 0, mal = 0;
for (const [nom, o, pol, espera] of CASOS) {
  const dir = path.join(raiz, nom.replace(/\W+/g, "-"));
  fs.mkdirSync(path.join(dir, "politica-cookies"), { recursive: true });
  fs.writeFileSync(path.join(dir, "index.html"), pagina(o));
  fs.writeFileSync(path.join(dir, "politica-cookies", "index.html"), politica(pol));
  const r = spawnSync("node", [SONDA, "https://fx.test/"], { env: { ...process.env, BANNER_DIR: dir }, encoding: "utf8", timeout: 120000 });
  const salida = (r.stdout || "") + (r.stderr || "");
  for (const [id, quiero] of Object.entries(espera)) {
    const m = salida.match(new RegExp(`^(PASA|FALLA|AVISO|NO MEDIDO)\\s+${id}\\b.*$`, "m"));
    const real = m ? m[1] : "AUSENTE";
    if (real === quiero) { ok++; console.log(`  OK    ${nom.padEnd(44)} ${id} -> ${real}`); }
    else { mal++; console.log(`  MAL   ${nom.padEnd(44)} ${id} esperaba ${quiero} y salio ${real}`); console.log("        " + (m ? m[0] : salida.split("\n").slice(0, 3).join(" | "))); }
  }
}
fs.rmSync(raiz, { recursive: true, force: true });
console.log(`\n  OK ${ok}  ·  MAL ${mal}`);
process.exit(mal ? 1 : 0);
