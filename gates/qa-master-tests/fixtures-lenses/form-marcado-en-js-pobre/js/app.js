// El mismo configurador, con el formulario mal hecho: lo que la lente tiene que cazar.
function pintarFormulario(caja) {
  caja.innerHTML = `
    <form class="lead-form" novalidate>
      <label>Nombre<input name="name" required></label>
      <label>Correo<input name="email" type="email"></label>
      <span aria-hidden="true">*</span><input type="text" name="website" tabindex="-1" autocomplete="off">
      <button type="submit">Pedir presupuesto</button>
    </form>`;
  const f = caja.querySelector('form');
  f.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    await fetch(window.DESTINO_LEADS, { method: 'POST', body: new FormData(f) });
  });
}
pintarFormulario(document.getElementById('cfg'));
