// FIXTURE DE CONTENEDOR — lo que googletagmanager devolveria para un contenedor
// que carga SOLO Google. Se pasa con `--contenedor` (alias `--container`).
//
// POR QUE EXISTE
// --------------
// MED-03, MED-05 y MED-07 viven los tres dentro de un unico `if`: "si el
// contenedor se ha podido descargar". Un fixture sintetico declara un id falso
// —como debe ser en un repo publico— y googletagmanager responde 400, asi que los
// tres salian NO VERIFICADO y su unica cobertura posible eran webs VIVAS.
//
// Eso tiene dos problemas, y los dos estan escritos en la cabecera de tests.sh:
// una web viva caduca sola —"arreglar el sitio rompe la prueba"— y no se puede
// congelar en `fixtures-frozen-site/` sin meter los bytes de un cliente en un
// repositorio publico. O sea que no era pereza: no habia forma.
//
// Con este fichero la hay. Es la hermana de `--dom fichero.json`: misma idea
// —desacoplar el instrumento de la red— aplicada al otro insumo que el gate no
// puede fabricar por su cuenta.
//
// QUE DECLARA
// -----------
// Una etiqueta de Google Ads y una propiedad de GA4, y NI UNA LINEA de Meta. Esa
// ausencia es la mitad del caso: el fixture `med-tercero-en-js-propio` carga el
// pixel de Meta desde su PROPIO script.js, asi que la unica forma de que MED-07 lo
// vea es mirando tambien ahi. Antes del 8-sep-2026 solo miraba el contenedor, no
// lo veia, y MED-07b acusaba a una politica que decia la verdad.
//
// Los identificadores son de ejemplo y no corresponden a ninguna cuenta real.

var google_tag_data = google_tag_data || {};

(function () {
  "use strict";

  // Los destinos del contenedor. MED-07 los reconoce por su forma: AW-\d+ para
  // Google Ads, G-[A-Z0-9]{8,} para una propiedad de GA4.
  var destinos = ["AW-1234567890", "G-EXAMPLE123"];

  // Un contenedor real trae aqui la maquinaria de disparadores. Para lo que este
  // fixture prueba basta con que los destinos esten escritos: los checks que lo
  // leen buscan identificadores y nombres de evento, no ejecutan nada.
  var eventos = ["gtm.js", "gtm.dom", "gtm.load"];

  function enviar(destino, evento) {
    // fixture: no manda nada a ninguna parte, y no debe.
    return { destino: destino, evento: evento, enviado: false };
  }

  for (var i = 0; i < destinos.length; i++) {
    for (var j = 0; j < eventos.length; j++) {
      enviar(destinos[i], eventos[j]);
    }
  }
})();
