// =============================================================================
//  fold-page-standard.js · CONGELADO. Generaba el estandar de pagina desde el catalogo
// =============================================================================
//  19-ago-2026. Las 30 reglas WPS colgaban de `web-page-standard/SKILL.md`, una
//  skill que YA NO EXISTE: 30 reglas del estandar apuntando a un documento
//  borrado. Folded into the paths.
//
//  SE GENERA, NO SE ESCRIBE. Si el documento se escribiera a mano habria dos
//  sitios donde vive la misma regla -el catalogo y el .md- y divergirian, que
//  es exactamente el fallo que hoy costo 4 copias del auditor y 363 falsos
//  positivos. El catalogo manda; el documento es su lectura para humanos.
//
//  Y en la misma pasada se reescribe `doc` y `linea` en el catalogo, para que
//  la referencia apunte a donde la regla vive DE VERDAD.
// =============================================================================
//  🔴 CONGELADO EL 2-sep-2026 · ABORTA A PROPOSITO, Y NO ES UN OLVIDO
// =============================================================================
//  Escribia en `gates/18-estandar-de-pagina.md`: el nombre de antes de la
//  unificacion al ingles del 25-ago. Ese fichero NO EXISTE en el repo, asi que
//  cada ejecucion lo CREABA como un duplicado sin rastrear, mientras el
//  documento vivo -- `blueprint/18-page-standard.md` -- llevaba desde el 25-ago
//  sin regenerarse. Y ese documento sigue diciendo en su cabecera que lo genera
//  este script. O sea: se presentaba como generado por un programa que escribia
//  en otro sitio.
//
//  🔑 POR QUE NO BASTA CON REPUNTAR `OUT`, que es lo obvio: MEDIDO ese dia, el
//     catalogo esta ENTERO EN CASTELLANO (192 reglas claramente en castellano, 0
//     en ingles) y el documento vivo esta EN INGLES, traducido a mano. Apuntar
//     `OUT` al documento vivo no lo regenera: lo DESTRUYE, y lo sustituye por la
//     version castellana que sale de este catalogo. El arreglo comodo habria
//     borrado la traduccion sin que nada se pusiera rojo.
//
//  Se congela con un `exit` y no con un comentario porque un generador que ya
//  no es la fuente es PEOR que un fichero a mano: parece autoridad. Es
//  literalmente el caso `_ds_page_gen.ps1` que este mismo sistema documenta, y
//  alli la leccion fue la misma -- «el aviso no se deja en un comentario, se
//  deja en un exit».
//
//  QUE HACE FALTA PARA DESCONGELARLO, y es una decision de idioma de todo el
//  repo, no de este fichero:
//    1. Decidir en que idioma vive el CATALOGO. Hoy es castellano; el resto del
//       repo es ingles desde el 25-ago.
//    2. Si se pasa el catalogo a ingles: traducir los `texto` de las 256 reglas
//       -- no solo las 30 WPS, o el catalogo queda mestizo -- y traducir tambien
//       los literales de este generador (los GRUPOS y el cuerpo del documento).
//    3. Apuntar OUT a `../blueprint/18-page-standard.md`, regenerar, y DIFERENCIAR
//       contra el documento vivo antes de aceptar el resultado: lo que salga
//       distinto es deriva escrita a mano que hay que devolver al catalogo
//       primero. Un generador que pisa correcciones a mano las borra en silencio.
//    4. Quitar este bloque y devolver a `blueprint/18-page-standard.md` su
//       cabecera de «esto se genera».
//  Mientras tanto, `blueprint/18-page-standard.md` SE MANTIENE A MANO y su
//  cabecera lo dice.
console.error([
  '  CONGELADO: este generador no es la fuente de blueprint/18-page-standard.md.',
  '  Escribia en una ruta muerta (gates/18-estandar-de-pagina.md) y el documento',
  '  vivo esta en ingles mientras el catalogo esta en castellano: regenerar lo',
  '  destruiria. Los cuatro pasos para descongelarlo estan en la cabecera.',
  '  Que el catalogo apunte a documentos que existen lo vigila doc-gate D7.',
].join('\n'));
process.exit(2);

/* eslint-disable no-unreachable */
const fs = require('fs'), path = require('path');
const DIR = __dirname;
const CAT = path.join(DIR, 'standard-rules.json');
// Cuando se descongele, esta es la ruta buena. Se deja escrita para que el que
// venga no tenga que volver a averiguarla.
const OUT = path.join(DIR, '..', 'blueprint', '18-page-standard.md');

const j = JSON.parse(fs.readFileSync(CAT, 'utf8'));
const wps = j.reglas.filter(r => /^WPS-/.test(String(r.id || '')));
if (wps.length !== 30) { console.error('esperaba 30 reglas WPS, hay ' + wps.length); process.exit(2); }

const GRUPOS = [
  ['Antes de crearla', ['WPS-01','WPS-02','WPS-03']],
  ['Cabeza: lo que leen las maquinas', ['WPS-04','WPS-05','WPS-06','WPS-07','WPS-08','WPS-09']],
  ['Navegacion y accesibilidad', ['WPS-10','WPS-11','WPS-12','WPS-19']],
  ['Cuerpo: lo que la hace citable', ['WPS-13','WPS-14','WPS-15','WPS-16','WPS-18','WPS-21','WPS-23','WPS-24']],
  ['Datos estructurados', ['WPS-17','WPS-20','WPS-25','WPS-26','WPS-27']],
  ['Peso y entrega', ['WPS-22','WPS-28','WPS-29']],
  ['Y al final, la unica que no automatiza nadie', ['WPS-30']],
];
const vistos = new Set(GRUPOS.flatMap(g => g[1]));
for (const r of wps) if (!vistos.has(r.id)) { console.error('regla sin grupo: ' + r.id); process.exit(2); }

const marca = m => m === 'si' ? '🟢 gate' : m === 'parcial' ? '🟡 parcial' : '🔴 humano';
const L = [];
L.push('# 18 · El estandar de PAGINA (las 30 reglas WPS)');
L.push('');
L.push('> 🔴 **ESTE FICHERO SE GENERA. No se edita a mano.**');
L.push('> `node gates/fold-page-standard.js` lo reescribe desde `standard-rules.json`,');
L.push('> que es donde viven las reglas. Editar aqui crea un segundo sitio donde vive');
L.push('> la misma verdad, y eso siempre acaba divergiendo.');
L.push('');
L.push('Las 30 vivian en la skill `web-page-standard`, **que ya no existe**: eran 30');
L.push('reglas del estandar apuntando a un documento borrado, y por eso nadie las');
L.push('miraba al construir una pagina. Se pliegan aqui el 19-ago-2026.');
L.push('');
L.push('| Marca | Que significa |');
L.push('|---|---|');
L.push('| 🟢 gate | la mide un instrumento: si falla, sale en rojo solo |');
L.push('| 🟡 parcial | el instrumento ve una parte; el resto lo mira una persona |');
L.push('| 🔴 humano | **ningun gate la medira nunca.** Va al bloque B de `08-qa-final.md` |');
L.push('');
const linea = {};
for (const [titulo, ids] of GRUPOS) {
  L.push('## ' + titulo);
  L.push('');
  for (const id of ids) {
    const r = wps.find(x => x.id === id);
    linea[id] = L.length + 1;
    L.push('- **' + id + '** · ' + marca(String(r.comprobable_maquina)) + ' — ' +
           String(r.texto || '').replace(/\s+/g, ' ').trim());
    const g = String(r.gate || 'NINGUNO');
    L.push('  <br>`' + (/^NINGUNO/i.test(g) ? 'sin instrumento' : g) + '`');
  }
  L.push('');
}
const n = m => wps.filter(r => String(r.comprobable_maquina) === m).length;
L.push('---');
L.push('');
L.push('**Reparto:** ' + n('si') + ' con gate · ' + n('parcial') + ' parciales · ' + n('no') + ' humanas.');
L.push('Las humanas **no son un hueco que llenar**: el estandar dice que las juzga una');
L.push('persona. Lo que si es un hueco es contarlas como aprobadas.');
L.push('');
fs.writeFileSync(OUT, L.join('\n'), 'utf8');

for (const r of j.reglas) if (/^WPS-/.test(String(r.id || ''))) {
  r.doc = 'blueprint/18-page-standard.md';
  r.linea = linea[r.id];
}
fs.writeFileSync(CAT, JSON.stringify(j, null, 2), 'utf8');
console.log('  generado blueprint/18-page-standard.md (' + L.length + ' lineas)');
console.log('  catalogo: 30 reglas repuntadas a su doc y su linea reales');
