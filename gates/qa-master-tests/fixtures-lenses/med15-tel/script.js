document.querySelector("form").addEventListener("submit",function(e){ e.target.querySelector("button").disabled = true; });

/* MED-15 · FIXTURE: un clic al telefono. `link:'tel:+32...'` NO es una clave `tel`:
   si el gate la leyera asi, tumbaria cada web con un enlace al telefono. */
window.dataLayer = window.dataLayer || [];
dataLayer.push({ event: 'phone_click', link: 'tel:+3200000000', location: 'hero' });
