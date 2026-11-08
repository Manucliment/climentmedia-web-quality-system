// 7-nov-2026 · La copia de ANTES de un cambio, guardada como evidencia en _medicion/: aquí sí se leía
// data-thanks, pero esto ya no se sirve. Un lector en la evidencia no absuelve al árbol que sube.
document.querySelectorAll("[data-thanks]").forEach((el) => window.dataLayer && window.dataLayer.push({ event: el.dataset.thanks }));
