// Fixture de MED-03 (6-nov-2026): solo nombres que construye el JS. El gate no puede cruzarlos con
// el contenedor, y tampoco puede decir que el sitio «no emite ningun evento». Si tomara el trozo
// entre comillas por un nombre, cruzaria «cm_», que no existe, y saldria un FALLO falso.
function enviar(nombre, datos) {
  window.dataLayer.push({ event: "cm_" + nombre, cm_datos: datos });
}
document.querySelector("form").addEventListener("submit", function () {
  var ev = "cm_presupuesto";
  window.dataLayer.push({ event: ev });
  enviar("formulario_visto", {});
});
