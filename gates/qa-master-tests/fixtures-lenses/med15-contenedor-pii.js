// FIXTURE DE CONTENEDOR para MED-15 (3-nov-2026). Un gtm.js real trae su configuracion
// en `var data = {"resource":{...}}`: macros (variables) y tags (etiquetas). MED-15 lee
// que variable usa cada etiqueta. Los identificadores son de ejemplo.
// FALLO: la etiqueta de GA4 manda la variable form.email (macro 2) como user_email.
var data = {"resource":{"version":"1","macros":[{"function":"__e"},{"function":"__v","vtp_name":"location","vtp_dataLayerVersion":2},{"function":"__v","vtp_name":"form.email","vtp_dataLayerVersion":2}],"tags":[{"function":"__gaawe","vtp_eventName":"phone_click","vtp_measurementIdOverride":"G-EXAMPLE123","vtp_eventSettingsTable":["list",["map","parameter","location","parameterValue",["macro",1]],["map","parameter","user_email","parameterValue",["macro",2]]]}]}};
// relleno: el gate descarta un contenedor de menos de 1000 bytes como respuesta vacia
// relleno: el gate descarta un contenedor de menos de 1000 bytes como respuesta vacia
// relleno: el gate descarta un contenedor de menos de 1000 bytes como respuesta vacia
// relleno: el gate descarta un contenedor de menos de 1000 bytes como respuesta vacia
// relleno: el gate descarta un contenedor de menos de 1000 bytes como respuesta vacia
// relleno: el gate descarta un contenedor de menos de 1000 bytes como respuesta vacia
// relleno: el gate descarta un contenedor de menos de 1000 bytes como respuesta vacia
// relleno: el gate descarta un contenedor de menos de 1000 bytes como respuesta vacia
// relleno: el gate descarta un contenedor de menos de 1000 bytes como respuesta vacia
// relleno: el gate descarta un contenedor de menos de 1000 bytes como respuesta vacia
// relleno: el gate descarta un contenedor de menos de 1000 bytes como respuesta vacia
// relleno: el gate descarta un contenedor de menos de 1000 bytes como respuesta vacia
