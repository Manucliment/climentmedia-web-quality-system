document.querySelector("form").addEventListener("submit",function(e){ e.target.querySelector("button").disabled = true; });

/* MED-15 · FIXTURE: la web mete el correo de la persona en el evento. Va a GA4
   tal cual: sus condiciones lo prohiben y no se puede borrar despues. */
window.dataLayer = window.dataLayer || [];
dataLayer.push({ event: 'phone_click', location: 'hero', email: 'x' });
