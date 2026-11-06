// FIXTURE. El consent default, en una funcion exportada que la pagina llama.
window.dataLayer = window.dataLayer || [];
function gtag() { window.dataLayer.push(arguments); }

export function ponerDefault() {
  gtag('consent', 'default', {
    ad_storage: 'denied', ad_user_data: 'denied',
    ad_personalization: 'denied', analytics_storage: 'denied',
  });
}
