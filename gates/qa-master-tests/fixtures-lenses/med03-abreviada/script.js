// Fixture de MED-03 (6-nov-2026): la clave ABREVIADA, `{ event }`, sin dos puntos. Es como empuja sus
// eventos un ayudante `track(event, params)`: el nombre va en la variable. El gate no lo puede cruzar
// con el contenedor, pero tampoco puede decir que el sitio «no emite ningun evento».
// Cuatro push; cuentan como compuestos los dos primeros, y solo esos dos:
// 1 · El ayudante: `event` justo tras la llave, con mas claves y un spread detras.
function track(event, params) {
  window.dataLayer.push({ event, site: "static", ...params });
}
// 2 · La clave abreviada al final, tras un spread.
function avisar(datos) {
  var event = "cm_aviso";
  window.dataLayer.push({ ...datos, event });
}
document.querySelector("form").addEventListener("submit", function (event) {
  // 3 · `event` como VALOR (el evento del DOM), no como clave: no es un evento del dataLayer.
  window.dataLayer.push({ origen: event, pagina: 1 });
  // 4 · Una clave que EMPIEZA por event: no es la clave event.
  var event_id = 7;
  window.dataLayer.push({ event_id, valor: 1 });
  track("cm_presupuesto", { cm_origen: "formulario" });
  avisar({});
});
