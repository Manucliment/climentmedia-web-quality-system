// =============================================================================
//  FIXTURE DE CONTENEDOR · MED-03, el control que TIENE que fallar (6-nov-2026)
// =============================================================================
//  El mismo contenedor que contenedor-med03-patron.js, con un patron que NO
//  cubre el evento de la pagina y tres cosas que se parecen a escucharlo y no lo
//  son. Esperado: MED-03 FALLO, nombrando el evento.
//    1 · Una mencion entre comillas ESCAPADAS, dentro de la configuracion de una
//        etiqueta de GA4 (`matchingRules`): es como venia en el contenedor real
//        del 5-nov, y no dispara nada.
//    2 · Un predicado `_cn` que contiene el nombre, pero sobre la variable de la
//        URL (macro 1), no sobre Event: no escucha el evento.
//    3 · Un predicado `_re` sobre Event que lo nombra, NEGADO: es una excepcion,
//        no un activador.
//  Los identificadores son de ejemplo y no corresponden a ninguna cuenta real.
// =============================================================================
var data = {
"resource": {
  "version": "7",
  "macros": [
    {"function": "__e"},
    {"function": "__u", "vtp_component": "PATH", "vtp_enableMultiQueryKeys": false}
  ],
  "tags": [
    {"function": "__googtag", "priority": 10, "vtp_tagId": "G-PATRON0001", "tag_id": 1,
     "vtp_eventSettingsTable": ["list", ["map", "matchingRules", "{\"type\":5,\"args\":[{\"stringValue\":\"devis_envoye\"},{\"contextValue\":{\"namespaceType\":1,\"keyParts\":[\"eventName\"]}}]}"]]},
    {"function": "__gaawe", "vtp_measurementIdOverride": "G-PATRON0001", "vtp_eventName": ["macro", 0], "tag_id": 2}
  ],
  "predicates": [
    {"function": "_eq", "arg0": ["macro", 0], "arg1": "gtm.js"},
    {"function": "_re", "arg0": ["macro", 0], "arg1": "^(phone_click|email_click)$"},
    {"function": "_cn", "arg0": ["macro", 1], "arg1": "devis_envoye"},
    {"function": "_re", "arg0": ["macro", 0], "arg1": "devis_envoye", "negate": true}
  ],
  "rules": [
    [["if", 0], ["add", 0]],
    [["if", 1], ["unless", 3], ["add", 1]],
    [["if", 2], ["add", 1]]
  ]
},
"runtime": []
};
/* fin del contenedor sintetico */
