// =============================================================================
//  FIXTURE DE CONTENEDOR · MED-03, el evento lo manda OTRO activador (6-nov-2026)
// =============================================================================
//  Ningun activador de evento escucha lo que la pagina empuja, pero una etiqueta
//  de GA4 lo ENVIA con ese mismo nombre desde otro activador (un clic en enlace).
//  Es la forma de dos webs nuestras medida el 6-nov: el evento llega a GA4, y el
//  push de la pagina no lo escucha nadie. No es la conversion muerta de site-d,
//  y tampoco es un aprobado: hay que mirar que el otro activador cubra el mismo
//  clic. Esperado: MED-03 AVISO, nombrando el evento.
//  Los identificadores son de ejemplo y no corresponden a ninguna cuenta real.
//  (Relleno para pasar el minimo de 1000 bytes que el gate pide a un gtm.js de
//  verdad: por debajo lo toma por una respuesta de error.)
// =============================================================================
var data = {
"resource": {
  "version": "7",
  "macros": [
    {"function": "__e"},
    {"function": "__v", "vtp_name": "gtm.elementUrl", "vtp_dataLayerVersion": 2}
  ],
  "tags": [
    {"function": "__googtag", "priority": 10, "vtp_tagId": "G-PATRON0001", "tag_id": 1},
    {"function": "__gaawe", "vtp_eventName": "devis_envoye", "vtp_measurementIdOverride": "G-PATRON0001", "tag_id": 2}
  ],
  "predicates": [
    {"function": "_eq", "arg0": ["macro", 0], "arg1": "gtm.js"},
    {"function": "_eq", "arg0": ["macro", 0], "arg1": "gtm.linkClick"},
    {"function": "_sw", "arg0": ["macro", 1], "arg1": "mailto:"}
  ],
  "rules": [
    [["if", 0], ["add", 0]],
    [["if", 1, 2], ["add", 1]]
  ]
},
"runtime": []
};
/* fin del contenedor sintetico */
