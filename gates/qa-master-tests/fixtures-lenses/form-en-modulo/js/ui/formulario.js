import { CONFIG } from '../config.js';

export function pintarFormulario(caja) {
  caja.innerHTML = `
    <form class="lead-form" novalidate>
      <label>Nombre<input name="name" required autocomplete="name"></label>
      <label>Correo<input name="email" type="email" autocomplete="email"></label>
      <p class="lead-form__trap" aria-hidden="true"><label>No rellenar<input type="text" name="website" tabindex="-1" autocomplete="off"></label></p>
      <p class="lead-form__msg" role="status" aria-live="polite"></p>
      <button type="submit">Pedir presupuesto</button>
    </form>`;
  const f = caja.querySelector('form');
  f.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    f.querySelector('button').disabled = true;
    await fetch(CONFIG.LEAD_ENDPOINT, { method: 'POST', body: new FormData(f) });
  });
}
