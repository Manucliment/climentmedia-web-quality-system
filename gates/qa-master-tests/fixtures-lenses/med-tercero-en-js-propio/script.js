/* FIXTURE. Una web que carga un tercero DESDE SU PROPIO JAVASCRIPT y no desde el
   contenedor de etiquetas. No es un caso raro: el Consent Mode de Google no
   gobierna un pixel de Meta, asi que meterlo en el contenedor obliga a repartir el
   mismo permiso en dos sitios que pueden divergir; aqui la condicion es una sola.

   Existe para MED-07. Antes del 8-sep-2026 ese check buscaba los proveedores SOLO
   dentro del contenedor, asi que sobre esta pagina no veia a Meta y MED-07b
   avisaba de que "la politica declara un proveedor que el sitio NO carga" sobre
   una politica que dice la verdad. Un aviso falso ensena a ignorar los avisos.

   El identificador es inventado y el dominio es de ejemplo: aqui no entra nada de
   ningun cliente. */
document.querySelector("form").addEventListener("submit", function (e) {
  e.target.querySelector("button").disabled = true;
});

(function () {
  var caja = document.getElementById("cookie-consent");
  if (!caja) { return; }

  function pixelDeMeta(c) {
    if (!c || !c.ads || window.fbq) { return; }
    var n = window.fbq = function () {
      n.callMethod ? n.callMethod.apply(n, arguments) : n.queue.push(arguments);
    };
    if (!window._fbq) { window._fbq = n; }
    n.push = n; n.loaded = true; n.version = "2.0"; n.queue = [];
    var t = document.createElement("script");
    t.async = true;
    t.src = "https://connect.facebook.net/en_US/fbevents.js";
    var s = document.getElementsByTagName("script")[0];
    s.parentNode.insertBefore(t, s);
    window.fbq("init", "000000000000000");
    window.fbq("track", "PageView");
  }

  caja.addEventListener("click", function (ev) {
    var b = ev.target.closest("[data-cc-act]");
    if (!b) { return; }
    pixelDeMeta({ ads: b.getAttribute("data-cc-act") === "all" });
    caja.hidden = true;
  });
})();
