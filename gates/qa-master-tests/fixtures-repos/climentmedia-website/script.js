// Repo sintetico de qa-master-tests. Lee data-plan (su lector de verdad) y
// NO lee data-sec: ese atributo es vocabulario del gate, no del sitio.
document.querySelectorAll('.plan').forEach(function (b) {
  b.addEventListener('click', function () {
    window.location.href = '/contacto?plan=' + encodeURIComponent(b.dataset.plan);
  });
});
