// Fixture de MED-03 (15-nov-2026): el objeto del evento se arma en una VARIABLE y se empuja la variable,
// `dataLayer.push(payload)`. Es como lo escribe un ayudante que anade las claves en un bucle. Las reglas
// de MED-03 pedian el objeto escrito dentro del `push(` y no lo veian: el sitio salia «no emite ningun
// evento con nombre». Seis push de variable; cuentan los tres primeros, y solo esos tres:
// 1 · El ayudante: el nombre llega en una variable. Cuenta como compuesto.
function empuja(evento, datos) {
  var payload = { event: evento };
  for (var k in datos) { if (datos.hasOwnProperty(k)) { payload[k] = datos[k]; } }
  window.dataLayer.push(payload);
}
// 2 · Un nombre que se compone: el trozo entre comillas no es un nombre. Cuenta como compuesto.
function enviar(nombre) {
  var compuesto = { event: "cm_" + nombre, cm_origen: "variable" };
  window.dataLayer.push(compuesto);
}
document.querySelector("form").addEventListener("submit", function (event) {
  // 3 · El nombre entero entre comillas (la clave sin ellas, como la escribe medio mundo): cuenta como
  //     devis_envoye, y se cruza con el contenedor (que lo escucha por un patron).
  const envio = { event: "devis_envoye", formulario: "presupuesto" };
  window.dataLayer.push(envio);
  // 4 · Un objeto sin la clave event: no es un evento.
  let datos = { valor: 1, pagina: "contacto" };
  window.dataLayer.push(datos);
  // 5 · `event` como VALOR (el evento del DOM), no como clave.
  var ev = { origen: event, pagina: 1 };
  window.dataLayer.push(ev);
  // 6 · Una clave que EMPIEZA por event: no es la clave event.
  var marca = { event_id: 7 };
  window.dataLayer.push(marca);
  empuja("form_submit", { formulario: "presupuesto" });
  enviar("formulario_visto");
});
