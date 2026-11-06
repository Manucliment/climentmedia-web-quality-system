// Fixture: lee data-thanks por una CONSTANTE con su nombre, como hacen los temas de tienda
// minificados (el nombre del atributo vive en una const y la llamada lleva la const).
// Es lector: la llamada lleva la constante, no el nombre entre comillas.
const ATRIBUTO_GRACIAS="data-thanks",OTRO=["x"];
function objetivos(raiz){const t=[];return raiz.hasAttribute(ATRIBUTO_GRACIAS)&&t.push(raiz),t.push(...raiz.querySelectorAll(`[${ATRIBUTO_GRACIAS}]`)),t}
var ev = document.body && document.body.getAttribute(ATRIBUTO_GRACIAS);
if (ev) { console.log(ev, objetivos(document.body).length); }
