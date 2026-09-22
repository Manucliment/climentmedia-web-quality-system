/* Clinica Dental Ejemplo · sitio ficticio del banco de pruebas de qa-master */
(function () {
  'use strict';
  window.dataLayer = window.dataLayer || [];
  // Cada enlace con data-event empuja su nombre al dataLayer al pulsarlo.
  document.addEventListener('click', function (ev) {
    var el = ev.target.closest('[data-event]');
    if (el) window.dataLayer.push({ event: el.getAttribute('data-event') });
  });
  // La pagina de gracias declara su evento en el marcado.
  var gracias = document.querySelector('[data-thanks]');
  if (gracias) window.dataLayer.push({ event: gracias.getAttribute('data-thanks') });
  // Banner de cookies: lee las casillas y actualiza el consentimiento.
  var cc = document.querySelector('.cc');
  if (cc) {
    cc.querySelector('.cc__btn').addEventListener('click', function () {
      var elegido = {};
      cc.querySelectorAll('[data-cc]').forEach(function (c) { elegido[c.dataset.cc] = c.checked; });
      gtag('consent', 'update', {
        analytics_storage: elegido.analitica ? 'granted' : 'denied',
        ad_storage: elegido.publicidad ? 'granted' : 'denied'
      });
      cc.hidden = true;
    });
  }
  // Formulario: el boton se deshabilita mientras se envia.
  var form = document.querySelector('form.contacto');
  if (form) {
    form.addEventListener('submit', function () {
      var b = form.querySelector('button[type=submit]');
      b.disabled = true;
      b.textContent = 'Enviando...';
    });
  }
})();
