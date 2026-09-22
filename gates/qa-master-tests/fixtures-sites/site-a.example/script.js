/* site-a.example - comportamiento del sitio.
   Fixture SINTETICO de gates/qa-master-tests (contenido inventado).
   Cada atributo data-* que emiten las paginas tiene aqui UN lector, y uno
   solo: los controles negativos del banco quitan ese lector de una copia
   del repo y exigen que MED-05 vuelva a acusar. Un segundo lector los
   dejaria en verde sin probar nada. */
(function () {
  'use strict';

  // Ventana de cita: la abre cualquier enlace a #pop-rdv y la cierra su boton.
  var pop = document.getElementById('pop-rdv');
  document.addEventListener('click', function (ev) {
    if (!pop) { return; }
    if (ev.target.closest('a[href="#pop-rdv"]')) {
      ev.preventDefault();
      pop.hidden = false;
      return;
    }
    if (ev.target.closest('[data-pop-act="close"]')) {
      pop.hidden = true;
    }
  });
  document.addEventListener('keydown', function (ev) {
    if (pop && ev.key === 'Escape') { pop.hidden = true; }
  });

  // Pagina de gracias: la conversion la declara el marcado y se lee aqui.
  var main = document.getElementById('main');
  var gracias = main ? main.getAttribute('data-thanks') : null;
  if (gracias) {
    window.dataLayer = window.dataLayer || [];
    window.dataLayer.push({ event: 'conversion_' + gracias });
  }

  // Formulario: un solo envio. Sin esto, quien no ve respuesta pulsa otra vez.
  var form = document.querySelector('form.form');
  if (form) {
    form.addEventListener('submit', function () {
      var b = form.querySelector('button[type="submit"]');
      if (b) {
        b.disabled = true;
        b.textContent = 'Envoi en cours...';
      }
    });
  }
})();
