// =============================================================================
//  FIXTURE DE CONTENEDOR · MED-03, la clave sin comillas (6-nov-2026)
// =============================================================================
//  Un activador de evento personalizado que escucha el evento que la pagina
//  med03-sin-comillas empuja con `event: "..."` (sin comillas en la clave). Con
//  este contenedor el caso PASA, y PASA solo si el gate no cuenta como evento el
//  objeto de libreria (`{ event: "scroll_libreria" }`, fuera de un push), que no
//  lo escucha nadie: es el control de que leer la clave sin comillas no mete en
//  el cruce cualquier `event:` del JS. El nombre compuesto se nombra en el dato,
//  sin cruzar. Con el contenedor de med03-patron (que no lo escucha) el mismo
//  sitio sale FALLO, y con el gate de antes salia «no emite ningun evento».
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
    {"function": "__gaawe", "vtp_measurementIdOverride": "G-PATRON0001", "vtp_eventName": "generate_lead", "tag_id": 2}
  ],
  "predicates": [
    {"function": "_eq", "arg0": ["macro", 0], "arg1": "gtm.js"},
    {"function": "_eq", "arg0": ["macro", 0], "arg1": "cm_presupuesto"}
  ],
  "rules": [
    [["if", 0], ["add", 0]],
    [["if", 1], ["add", 1]]
  ]
},
"runtime": []
};
/* fin del contenedor sintetico */
