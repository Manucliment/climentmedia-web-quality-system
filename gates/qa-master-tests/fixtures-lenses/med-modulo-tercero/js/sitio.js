// FIXTURE. El sitio, importado por el <script type="module"> en linea de la
// pagina: declara el consent default con todo en denied y DESPUES carga el
// contenedor, en este mismo fichero. El id sale de ./config.js.
import { CONFIG } from './config.js';
import { iniciarAnuncios } from './anuncios.js';

window.dataLayer = window.dataLayer || [];
function gtag() { window.dataLayer.push(arguments); }

function ponerDefault() {
  gtag('consent', 'default', {
    ad_storage: 'denied', ad_user_data: 'denied',
    ad_personalization: 'denied', analytics_storage: 'denied',
  });
}

function cargarGtm(id) {
  const s = document.createElement('script');
  s.async = true;
  window.dataLayer.push({ 'gtm.start': Date.now(), event: 'gtm.js' });
  s.src = 'https://www.googletagmanager.com/gtm.js?id=' + id;
  document.head.appendChild(s);
}

export function arrancar() {
  ponerDefault();
  cargarGtm(CONFIG.GTM_ID);
  iniciarAnuncios();
}
