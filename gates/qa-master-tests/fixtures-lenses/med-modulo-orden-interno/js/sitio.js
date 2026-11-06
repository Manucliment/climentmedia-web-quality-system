// FIXTURE. Como med-modulo, con la carga de gtm.js escrita ANTES que el
// consent default en el mismo fichero: el sitio carga el contenedor al arrancar
// y declara el default despues.
import { CONFIG } from './config.js';

window.dataLayer = window.dataLayer || [];
function gtag() { window.dataLayer.push(arguments); }

export function arrancar() {
  const s = document.createElement('script');
  s.async = true;
  window.dataLayer.push({ 'gtm.start': Date.now(), event: 'gtm.js' });
  s.src = 'https://www.googletagmanager.com/gtm.js?id=' + CONFIG.GTM_ID;
  document.head.appendChild(s);
  gtag('consent', 'default', {
    ad_storage: 'denied', ad_user_data: 'denied',
    ad_personalization: 'denied', analytics_storage: 'denied',
  });
}
