// Fixture: al enviar, un evento con nombre al dataLayer. MED-03 lo busca en el contenedor.
document.querySelector("form").addEventListener("submit", function () { window.dataLayer.push({ "event": "devis_envoye" }); });
