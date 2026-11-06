// =============================================================================
//  FIXTURE DE CONTENEDOR · MED-03 con patrones que no se pueden leer (6-nov-2026)
// =============================================================================
//  Un contenedor que tiene activadores por patron («"function":"_re"») pero cuya
//  lista de predicados esta cortada: el gate no puede saber si el evento de la
//  pagina lo escucha alguno. Eso no es «no escucha». Esperado: MED-03 NO
//  VERIFICADO, con el evento nombrado y la razon.
//  Los identificadores son de ejemplo y no corresponden a ninguna cuenta real.
//  (Relleno para pasar el minimo de 1000 bytes que el gate pide a un gtm.js de
//  verdad: por debajo lo toma por una respuesta de error, y este caso no es ese.
//  Un contenedor real no llega asi; puede llegar con una forma que este gate
//  todavia no conoce, que para el es lo mismo.)
// =============================================================================
var data = {
"resource": {
  "version": "7",
  "tags": [
    {"function": "__googtag", "priority": 10, "vtp_tagId": "G-PATRON0001", "tag_id": 1}
  ],
  "predicates": [
    {"function": "_eq", "arg0": ["macro", 0], "arg1": "gtm.js"},
    {"function": "_re", "arg0": ["macro", 0], "arg1": "^(phone_click|email_cl
