// El formulario se arma por partes: la apertura en una cadena, los campos en otra
// y el cierre construido. Leer de la apertura a un cierre que no esta seria leer
// a medias.
const campos = ['name', 'email'].map((n) => '<label>' + n + '<input name="' + n + '"></label>').join('');
let html = '<form class="trozos">';
html += campos;
html += '<button type="submit">Enviar</button></' + 'form>';
document.getElementById('caja').innerHTML = html;
