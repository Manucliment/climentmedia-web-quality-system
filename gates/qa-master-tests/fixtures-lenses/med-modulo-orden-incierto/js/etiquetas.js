// FIXTURE. La carga del contenedor, en otra funcion exportada; el id, de ./config.js.
import { CONFIG } from './config.js';

export function cargarGtm() {
  const s = document.createElement('script');
  s.async = true;
  window.dataLayer.push({ 'gtm.start': Date.now(), event: 'gtm.js' });
  s.src = 'https://www.googletagmanager.com/gtm.js?id=' + CONFIG.GTM_ID;
  document.head.appendChild(s);
}
