// FIXTURE. El sitio carga gtag.js directo con el id de ./config.js.
import { CONFIG } from './config.js';

window.dataLayer = window.dataLayer || [];
function gtag() { window.dataLayer.push(arguments); }

export function arrancar() {
  gtag('consent', 'default', { analytics_storage: 'denied' });
  const s = document.createElement('script');
  s.async = true;
  s.src = 'https://www.googletagmanager.com/gtag/js?id=' + CONFIG.GA_ID;
  document.head.appendChild(s);
}
