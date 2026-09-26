/* FIXTURE. La medicion "de la casa": un consent.js PROPIO que declara el Consent
   Mode v2 en `denied` y solo inyecta el contenedor cuando el visitante acepta.
   El id del contenedor vive AQUI y en ninguna pagina.

   Existe para MED-01/02/03/07. Hasta el 26-sep-2026 qa-master buscaba el
   contenedor solo en el HTML servido, asi que sobre esta web decia MED-01 «sin
   medicion ninguna» y los checks que cuelgan del contenedor no corrian nunca.

   🔴 Los ids de este comentario son TRAMPA a proposito: un marcador de plantilla
   (GTM-XXXXXXX) y un contenedor viejo (GTM-VIEJO01) escritos ANTES que el bueno.
   Un gate que lea los comentarios como codigo se queda con el primero que vea.
   Igual el G-XXXXXXXXXX: no es una propiedad que se cargue.

   Todos los identificadores son inventados. */
(function () {
  "use strict";

  // id anterior, retirado: GTM-LINEA02 (comentario de linea, tampoco cuenta)
  var TAG = { type: "gtm", id: "GTM-CASA123" };
  var HOSTS_QUE_MIDEN = ["climentmedia.com"];

  window.dataLayer = window.dataLayer || [];
  function gtag() { window.dataLayer.push(arguments); }
  window.gtag = gtag;

  gtag("consent", "default", {
    ad_storage: "denied",
    ad_user_data: "denied",
    ad_personalization: "denied",
    analytics_storage: "denied"
  });

  var cargado = false;

  function cargarTag() {
    if (cargado) { return; }
    if (HOSTS_QUE_MIDEN.indexOf(window.location.hostname) === -1) { return; }
    cargado = true;
    var s = document.createElement("script");
    s.async = true;
    window.dataLayer.push({ "gtm.start": new Date().getTime(), event: "gtm.js" });
    s.src = "https://www.googletagmanager.com/gtm.js?id=" + TAG.id;
    document.head.appendChild(s);
  }

  function conceder() {
    gtag("consent", "update", { analytics_storage: "granted" });
    cargarTag();
  }

  document.addEventListener("click", function (e) {
    var b = e.target && e.target.closest ? e.target.closest("[data-cc]") : null;
    if (b && b.getAttribute("data-cc") === "si") { conceder(); }
  });
})();
