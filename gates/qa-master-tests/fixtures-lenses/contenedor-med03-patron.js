// =============================================================================
//  FIXTURE DE CONTENEDOR · MED-03 con un activador POR PATRON (6-nov-2026)
// =============================================================================
//  La forma de un gtm.js real (resource / macros / tags / predicates / rules),
//  con valores inventados. Se pasa con `--contenedor`. No se ejecuta en ningun
//  sitio.
//
//  QUE PRUEBA: un activador de «evento personalizado» con «usar coincidencias de
//  expresiones regulares» no escribe el nombre del evento entre comillas, sino
//  dentro de una expresion, en un predicado `_re` sobre la variable Event (la
//  macro con `__e`). Es la forma del contenedor de una web de servicios medido
//  el 5-nov: la pagina emite el evento del presupuesto y el contenedor lo
//  escucha, y MED-03 decia FALLO porque solo buscaba el nombre entre comillas.
//  ⚠️ Por eso el nombre del evento NO aparece en este fichero entre comillas
//     solo: si apareciera, el caso pasaria por la regla de siempre y no
//     probaria nada. Esperado: MED-03 PASA, «por un disparador con patron».
//
//  Los identificadores son de ejemplo y no corresponden a ninguna cuenta real.
//  (Relleno para pasar el minimo de 1000 bytes que el gate pide a un gtm.js de
//  verdad: por debajo lo toma por una respuesta de error.)
// =============================================================================
var data = {
"resource": {
  "version": "7",
  "macros": [
    {"function": "__e"},
    {"function": "__u", "vtp_component": "PATH", "vtp_enableMultiQueryKeys": false}
  ],
  "tags": [
    {"function": "__googtag", "priority": 10, "vtp_tagId": "G-PATRON0001", "tag_id": 1},
    {"function": "__gaawe", "vtp_measurementIdOverride": "G-PATRON0001", "vtp_eventName": ["macro", 0], "tag_id": 2}
  ],
  "predicates": [
    {"function": "_eq", "arg0": ["macro", 0], "arg1": "gtm.js"},
    {"function": "_re", "arg0": ["macro", 0], "arg1": "^(phone_click|email_click|devis_envoye)$"}
  ],
  "rules": [
    [["if", 0], ["add", 0]],
    [["if", 1], ["add", 1]]
  ]
},
"runtime": []
};
/* fin del contenedor sintetico */
