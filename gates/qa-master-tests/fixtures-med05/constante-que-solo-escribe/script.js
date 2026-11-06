// Fixture: la MISMA constante con el nombre del atributo, pero solo se ESCRIBE con ella.
// Escribir no es leer: data-thanks sigue sin lector y MED-05 tiene que seguir en FALLO.
const ATRIBUTO_GRACIAS = "data-thanks";
document.body.setAttribute(ATRIBUTO_GRACIAS, "thank_you_view");
