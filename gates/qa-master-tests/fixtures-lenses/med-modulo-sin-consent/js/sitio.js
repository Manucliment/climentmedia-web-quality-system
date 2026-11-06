// FIXTURE. Como med-modulo, sin el consent default: el sitio carga el
// contenedor en cuanto arranca, y nadie ha dicho «denied» antes.
import { CONFIG } from './config.js';

window.dataLayer = window.dataLayer || [];

function cargarGtm(id) {
  const s = document.createElement('script');
  s.async = true;
  window.dataLayer.push({ 'gtm.start': Date.now(), event: 'gtm.js' });
  s.src = 'https://www.googletagmanager.com/gtm.js?id=' + id;
  document.head.appendChild(s);
}

export function arrancar() {
  cargarGtm(CONFIG.GTM_ID);
}
