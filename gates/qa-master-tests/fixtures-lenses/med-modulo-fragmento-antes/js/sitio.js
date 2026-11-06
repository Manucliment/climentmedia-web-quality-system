// FIXTURE. Como med-modulo, pero aqui solo se declara el default: el contenedor
// lo carga el fragmento clasico que va en linea al final de la pagina.
window.dataLayer = window.dataLayer || [];
function gtag() { window.dataLayer.push(arguments); }

export function arrancar() {
  gtag('consent', 'default', {
    ad_storage: 'denied', ad_user_data: 'denied',
    ad_personalization: 'denied', analytics_storage: 'denied',
  });
}
