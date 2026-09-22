// =============================================================================
//  _gtm.js · contenedor de GTM SINTETICO de site-d.example (GTM-SITED01)
// =============================================================================
//  El gate lo descargaria de googletagmanager.com por HTTPS, y este banco no
//  sale a internet: se le pasa con `--contenedor` (la costura que el gate tiene
//  para esto). fake-production.pl no lo sirve nunca (empieza por `_`).
//
//  Reproduce el contenedor VIEJO de la clinica:
//    · carga Google Ads (AW-) y Google Analytics (G-). La politica de cookies
//      del sitio no nombra a ninguno de los dos -> MED-07.
//    · sus disparadores escuchan click_cita, envio_formulario y la conversion
//      de gracias con el nombre de la guia (thank_you_view). La pagina de
//      gracias emite OTRO nombre, asi que las etiquetas de conversion no
//      disparan nunca -> MED-03. (Ese otro nombre no se cita aqui a proposito:
//      MED-03 busca cada evento emitido ENTRE COMILLAS dentro de este fichero.)
//  Forma inspirada en la de un gtm.js real (resource/macros/tags/predicates/
//  rules), con valores inventados. No se ejecuta en ningun sitio.
// =============================================================================
var data = {
"resource": {
  "version": "12",
  "macros": [
    {"function": "__e"},
    {"function": "__v", "vtp_name": "gtm.elementUrl", "vtp_dataLayerVersion": 2},
    {"function": "__u", "vtp_component": "PATH", "vtp_enableMultiQueryKeys": false}
  ],
  "tags": [
    {"function": "__googtag", "priority": 10, "vtp_tagId": "AW-100000001", "tag_id": 1},
    {"function": "__googtag", "priority": 10, "vtp_tagId": "G-SITED00001", "tag_id": 2},
    {"function": "__awct", "vtp_conversionId": "100000001", "vtp_conversionLabel": "cita-confirmada", "vtp_enableConversionLinker": true, "tag_id": 3},
    {"function": "__awct", "vtp_conversionId": "100000001", "vtp_conversionLabel": "formulario-enviado", "vtp_enableConversionLinker": true, "tag_id": 4},
    {"function": "__awct", "vtp_conversionId": "100000001", "vtp_conversionLabel": "gracias-vista", "vtp_enableConversionLinker": true, "tag_id": 5},
    {"function": "__gaawe", "vtp_measurementIdOverride": "G-SITED00001", "vtp_eventName": "click_cita", "tag_id": 6},
    {"function": "__gaawe", "vtp_measurementIdOverride": "G-SITED00001", "vtp_eventName": "envio_formulario", "tag_id": 7}
  ],
  "predicates": [
    {"function": "_eq", "arg0": ["macro", 0], "arg1": "gtm.js"},
    {"function": "_eq", "arg0": ["macro", 0], "arg1": "click_cita"},
    {"function": "_eq", "arg0": ["macro", 0], "arg1": "envio_formulario"},
    {"function": "_eq", "arg0": ["macro", 0], "arg1": "thank_you_view"}
  ],
  "rules": [
    [["if", 0], ["add", 0, 1]],
    [["if", 1], ["add", 2, 5]],
    [["if", 2], ["add", 3, 6]],
    [["if", 3], ["add", 4]]
  ]
},
"runtime": []
};
/* fin del contenedor sintetico */
