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
const { spawnSync, spawn } = require("child_process");

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
  <body><main><section class="hero">${o.lienzo ? '<canvas id="neural"></canvas>' : ""}<h1>Portada</h1><p>Texto de la portada.</p></section>
  ${o.casilla ? `<form class="form" action="/contacto.php" method="post"><label for="n">Nombre</label> <input id="n" name="nombre">
    <div class="campo consent"><label><input type="checkbox" name="consentimiento" required> <span>He leido y acepto la <a href="/politica-privacidad/">politica de privacidad</a></span></label></div>
    <button type="submit">Enviar</button></form>` : ""}</main>
  ${o.sinAviso ? "" : o.muro ? `<div class="velo" style="position:fixed;inset:0;background:rgba(0,0,0,.6);z-index:8">${aviso}</div>` : aviso}
  <footer>${o.sinReabrir ? "" : '<button data-cc-act="reopen">Configurar cookies</button>'} <a href="/politica-cookies/">Politica de cookies</a></footer>
  <script>
    var c = document.getElementById("cookie-consent"), velo = document.querySelector(".velo");
    function ver(v){ (velo || c).style.display = v ? "" : "none"; }
    ${o.contador ? 'navigator.sendBeacon("/consent-count.php", "visita");' : ""}
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
  // 6-nov-2026 · la fila «acepto la politica de privacidad» de un formulario va antes del
  // aviso en el documento. El primero, visto en ROJO contra la sonda de antes (B2 FALLA);
  // el tercero tambien (B1 PASA: tomaba la casilla por el aviso). El segundo tiene que
  // seguir fallando: elegir por los botones no puede tapar un aviso sin Rechazar.
  ["casilla de privacidad antes del aviso", { casilla: true }, {}, { B1: "PASA", B2: "PASA" }],
  ["casilla de privacidad y aviso sin Rechazar", { casilla: true, no: "" }, {}, { B2: "FALLA" }],
  ["casilla de privacidad y ningun aviso", { casilla: true, sinAviso: true }, {}, { B1: "FALLA" }],
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
// 6-nov-2026 · EL CANDIDATO Y LA MEDICION. La puerta mide el aviso del arbol que va a subir
// (GATE_CANDIDATO), servido con la URL de produccion por la funcion de run-gate.js; y fuera de
// las fixturas, la sonda aborta el contador del aviso y GA4. El host .invalid no existe: si la
// sonda no sirve el candidato, no hay pagina (visto en ROJO con la sonda sin GATE_CANDIDATO).
const ver = (nom, bien, dato) => { if (bien) { ok++; console.log(`  OK    ${nom}`); } else { mal++; console.log(`  MAL   ${nom}  · ${dato}`); } };
const { MEDICION } = require(path.join(__dirname, "..", "run-gate.js"));
const esMed = (u) => MEDICION(new URL(u));
ver("MEDICION: el contador del aviso y los envios de GA4", esMed("https://fx.test/consent-count.php") && esMed("https://region1.google-analytics.com/g/collect?v=2")
  && esMed("https://www.google-analytics.com/collect") && esMed("https://analytics.google.com/g/collect"), "alguno no se aborta");
ver("MEDICION: ni gtag.js, ni un /collect ajeno, ni doubleclick (sus cookies si se juzgan)", !esMed("https://www.googletagmanager.com/gtag/js?id=G-X")
  && !esMed("https://fx.test/api/collect") && !esMed("https://stats.g.doubleclick.net/g/collect") && !esMed("https://fx.test/consent-count.php.bak"), "alguno se abortaria");
const candidato = (nom, o) => {
  const dir = path.join(raiz, "cand-" + nom.replace(/\W+/g, "-"));
  fs.mkdirSync(path.join(dir, "politica-cookies"), { recursive: true });
  fs.writeFileSync(path.join(dir, "index.html"), pagina(o));
  fs.writeFileSync(path.join(dir, "politica-cookies", "index.html"), politica());
  const env = { ...process.env, GATE_CANDIDATO: dir, GATE_SITIO: "https://candidato.invalid" }; delete env.BANNER_DIR;
  const r = spawnSync("node", [SONDA, "https://candidato.invalid/"], { env, encoding: "utf8", timeout: 120000 });
  const salida = (r.stdout || "") + (r.stderr || "");
  let j = {}; try { j = JSON.parse(salida.split("\n").find((l) => l.startsWith("{")) || "{}"); } catch (e) { /* sin JSON */ }
  return { salida, j, veredicto: (salida.match(/^VEREDICTO: (.+)$/m) || [])[1] || "AUSENTE", rc: r.status };
};
const c1 = candidato("bueno", {});
ver("candidato: el arbol, servido con la URL de produccion, PASA y dice cuanto sirvio", c1.veredicto === "PASA" && c1.j.candidato > 0, `${c1.veredicto} · candidato ${c1.j.candidato} · ${c1.salida.split("\n")[0].slice(0, 120)}`);
const c2 = candidato("contador", { contador: true });
ver("candidato: el envio al contador del aviso se aborta y se cuenta", c2.j.medicionAbortada >= 1 && c2.veredicto === "PASA", `${c2.veredicto} · medicionAbortada ${c2.j.medicionAbortada}`);

// 7-nov-2026 · EL PERFIL DE CHROME (lanzar() de run-gate.js, el que usan las dos sondas). El disco
// del servidor llego al 100 % con 120 perfiles de sondas muertas en /tmp. Cada caso mide en una
// carpeta propia (GATE_PERFILES). Contra el run-gate.js de antes, los de SIGKILL, SIGTERM y el
// barrido salen en ROJO: aquel nunca escribia en esa carpeta ni barria nada.
const RG = path.join(__dirname, "..", "run-gate.js");
const gateJs = path.join(raiz, "gate-minimo.js");
fs.writeFileSync(gateJs, '({ VEREDICTO: "PASA" })');
const fxDir = path.join(raiz, "perfil-fx");
fs.mkdirSync(fxDir, { recursive: true });
fs.writeFileSync(path.join(fxDir, "index.html"), '<!DOCTYPE html><html lang="es"><head><meta charset="utf-8"><title>Perfil</title></head><body><main><h1>Perfil</h1><p>Texto de la pagina.</p></main></body></html>');
const perfiles = (d) => fs.readdirSync(d).sort();
const nueva = (n) => { const d = path.join(raiz, "perfiles-" + n); fs.mkdirSync(d); return d; };
const envRG = (d) => ({ ...process.env, GATE_PERFILES: d, GATE_CANDIDATO: fxDir, GATE_SITIO: "https://perfil.invalid" });
const medir = (d, env) => spawnSync("node", [RG, "https://perfil.invalid/", "1366", "768", gateJs], { env: env || envRG(d), encoding: "utf8", timeout: 120000 });
const esperar = (ms) => new Promise((r) => setTimeout(r, ms));
// Lanza run-gate, espera a que Chrome haya escrito en su perfil y le manda la senal.
async function cortar(d, senal) {
  const c = spawn("node", [RG, "https://perfil.invalid/", "1366", "768", gateJs], { env: envRG(d), stdio: "ignore" });
  const fin = new Promise((r) => c.on("exit", (code, sig) => r({ code, sig })));
  let visto = null;
  for (let i = 0; i < 400 && !visto; i++) {
    await esperar(25);
    const p = perfiles(d).find((n) => n.startsWith("wqs-chrome-" + c.pid + "-"));
    try { if (p && fs.readdirSync(path.join(d, p)).length) visto = p; } catch (e) { /* aun no */ }
  }
  c.kill(senal);
  return { visto, ...(await fin), quedan: perfiles(d) };
}
(async () => {
  const d1 = nueva("bien"), r1 = medir(d1);
  ver("perfil: la medida que acaba bien no deja el suyo", r1.status === 0 && /"candidato":[1-9]/.test(r1.stdout) && !perfiles(d1).length,
    `rc ${r1.status} · quedan [${perfiles(d1)}] · ${(r1.stderr || "").slice(0, 120)}`);
  const d2 = nueva("error"), r2 = medir(d2, { ...process.env, GATE_PERFILES: d2 });   // nada.invalid no existe: el goto falla
  ver("perfil: un goto que falla (sale por process.exit(3)) no deja el suyo", r2.status === 3 && !perfiles(d2).length, `rc ${r2.status} · quedan [${perfiles(d2)}]`);
  const d3 = nueva("kill"), r3 = await cortar(d3, "SIGKILL");
  ver("perfil: un SIGKILL lo deja, con su nombre y el pid de su sonda", !!r3.visto && r3.quedan.join() === r3.visto, `visto ${r3.visto} · quedan [${r3.quedan}]`);
  // Quien tiene el perfil abierto se mira con un cotejo PROPIO (la ruta en cualquier sitio del
  // cmdline): con el de run-gate, un cotejo ciego daba «no queda ninguno» y el caso pasaba en vacio.
  const ruta4 = r3.visto ? path.join(d3, r3.visto) : "";
  const conRuta = (ruta) => fs.readdirSync("/proc").filter((x) => /^\d+$/.test(x) && +x !== process.pid).filter((x) => {
    try { return fs.readFileSync(`/proc/${x}/cmdline`, "latin1").includes(ruta); } catch (e) { return false; } }).map(Number);
  const { procesosCon } = require(RG);
  const vivos3 = ruta4 ? conRuta(ruta4) : [], vistos3 = ruta4 ? procesosCon(ruta4) : [];
  ver("perfil: tras el SIGKILL su Chrome sigue vivo, y run-gate ve cada proceso que lo tiene", vivos3.length > 0 && vivos3.every((p) => vistos3.includes(p)),
    `vivos ${vivos3.length} [${vivos3.slice(0, 6)}] · run-gate ve ${vistos3.length}`);
  const r4 = medir(d3);
  ver("perfil: la sonda siguiente se lo lleva, y para el Chrome que lo tenia abierto", r4.status === 0 && !perfiles(d3).length && vivos3.length > 0 && !(ruta4 && conRuta(ruta4).length),
    `rc ${r4.status} · quedan [${perfiles(d3)}] · antes ${vivos3.length} · despues ${ruta4 ? conRuta(ruta4) : "-"}`);
  const d5 = nueva("term"), r5 = await cortar(d5, "SIGTERM");
  await esperar(500);   // lo que siguiera vivo tendria tiempo de volver a escribir
  const q5 = perfiles(d5), v5 = r5.visto ? conRuta(path.join(d5, r5.visto)) : [];
  ver("perfil: un SIGTERM (un timeout; un ssh que cae es SIGHUP) no lo deja, ni deja a su Chrome", !!r5.visto && r5.code === 3 && !r5.quedan.length && !q5.length && !v5.length,
    `visto ${r5.visto} · rc ${r5.code} · quedan [${r5.quedan}] · a los 500 ms [${q5}] · procesos [${v5}]`);
  const d6 = nueva("ajenos");
  const muerto = spawnSync("node", ["-e", "process.stdout.write(String(process.pid))"], { encoding: "utf8" }).stdout.trim();
  fs.mkdirSync(path.join(d6, `wqs-chrome-${process.pid}-vivo`));       // su sonda vive (este banco)
  fs.mkdirSync(path.join(d6, "puppeteer_dev_chrome_profile-ajeno"));    // no es nuestro
  fs.mkdirSync(path.join(d6, `wqs-chrome-${muerto}-muerto`));           // su sonda ya no existe
  const r6 = medir(d6), q6 = perfiles(d6).join();
  ver("perfil: el barrido deja el de una sonda viva y el ajeno, y se lleva el de la muerta", r6.status === 0 && q6 === ["puppeteer_dev_chrome_profile-ajeno", `wqs-chrome-${process.pid}-vivo`].sort().join(), `rc ${r6.status} · quedan [${q6}]`);

  fs.rmSync(raiz, { recursive: true, force: true });
  console.log(`\n  OK ${ok}  ·  MAL ${mal}`);
  process.exit(mal ? 1 : 0);
})();
