// FIXTURE. Un pixel de Meta y un evento propio, en un modulo que importa
// ./sitio.js (dos import por debajo de la pagina). El contenedor de prueba no
// escucha ese evento y la politica no nombra a Meta.
export function iniciarAnuncios() {
  const p = document.createElement('script');
  p.async = true;
  p.src = 'https://connect.facebook.net/en_US/fbevents.js';
  document.head.appendChild(p);
  document.addEventListener('click', (e) => {
    if (e.target && e.target.closest && e.target.closest('[data-presupuesto]')) {
      window.dataLayer.push({ 'event': 'solicitud_presupuesto' });
    }
  });
}
