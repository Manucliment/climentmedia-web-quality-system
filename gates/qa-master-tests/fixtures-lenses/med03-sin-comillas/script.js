// Fixture de MED-03 (6-nov-2026): las tres formas que el gate tiene que distinguir.
// 1 · El evento del envio, con la clave SIN comillas: es como lo escribe medio mundo, y el gate
//     viejo no lo leia (decia «no emite ningun evento»).
// 2 · Un evento con nombre COMPUESTO: el trozo entre comillas no es un nombre, se cuenta aparte.
// 3 · Un objeto de libreria con una clave event que NO va al dataLayer: no es un evento.
var opciones = { event: "scroll_libreria", passive: true };
function enviar(nombre, datos) {
  window.dataLayer.push({ event: "cm_" + nombre, cm_datos: datos });
}
document.querySelector("form").addEventListener("submit", function () {
  window.dataLayer.push({ event: "cm_presupuesto", cm_origen: "formulario" });
  enviar("formulario_visto", {});
});
