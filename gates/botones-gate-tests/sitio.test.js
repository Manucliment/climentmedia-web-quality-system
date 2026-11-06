// Banco de `botones-sitio.js` (los botones ENTRE paginas) · 6-nov-2026 · sin red ni navegador:
// salidas de run-gate escritas a mano, con la forma que da `botones-gate.js`.
//   node gates/botones-gate-tests/sitio.test.js
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const GATES = path.join(__dirname, '..');
const SITIO = path.join(GATES, 'botones-sitio.js');
const { compara } = require(path.join(GATES, 'botones-gate.js'));
const T = fs.mkdtempSync(path.join(os.tmpdir(), 'botones-sitio-'));
let ok = 0, mal = 0;
const ver = (n, c, d = '') => { if (c) { ok++; console.log(`  OK    ${n}`); } else { mal++; console.log(`  MAL   ${n} ${d}`); } };

const BASE = { 'tamaño': '16px', peso: '600', tipo: 'inter', mayusculas: 'no', radio: '8px', borde: 'sin borde',
  relleno: '12px 24px 12px 24px', fondo: '#1d5b7a', texto: '#ffffff', 'color del borde': '—' };
const boton = (cambia = {}, extra = {}) => ({ grupo: '.btn.btn-primary', contexto: 'claro', campos: { ...BASE, ...cambia },
  alto: 48, lineas: 1, texto: 'Pedir cita', ...extra });
let k = 0;
// salida <ruta> <ancho> <lista> [diag extra] [gate extra] -> fichero
const salida = (ruta, ancho, lista, diag = {}, gate = {}) => {
  const f = path.join(T, `${++k}.out`);
  const url = 'https://web.invalid' + ruta;
  const r = compara(lista, ancho);
  fs.writeFileSync(f, JSON.stringify({ url, pedido: ancho, innerWidth: ancho, coincide: true, sospechoso: false, ...diag }) + '\n' +
    JSON.stringify({ url, innerWidth: ancho, coincide: true, VEREDICTO: r.fallos.length ? 'FALLA' : 'PASA', fallos: r.fallos.map((x) => x.msg),
      avisos: [], notas: [], datos: { botones: lista.length, sinClase: 0, grupos: r.grupos, lista }, ...gate }, null, 1));
  return f;
};
const corre = (...f) => { const r = spawnSync(process.execPath, [SITIO, ...f], { encoding: 'utf8' }); return { rc: r.status, s: (r.stdout || '') + (r.stderr || '') }; };

// 1 · dos paginas con el mismo boton
let r = corre(salida('/', 1366, [boton(), boton()]), salida('/precios/', 1366, [boton()]));
ver('mismo boton en dos paginas: PASA (rc 0)', r.rc === 0 && /VEREDICTO PASA/.test(r.s), r.s);
// 2 · el mismo grupo con otro cuerpo en otra pagina: solo se ve juntandolas
r = corre(salida('/', 1366, [boton()]), salida('/contacto/', 1366, [boton({ 'tamaño': '19px' }, { texto: 'Enviar' })]));
ver('otro cuerpo en otra pagina: FALLA entre paginas, con la pagina nombrada', r.rc === 1 && /BT1 \(entre paginas\) · \.btn\.btn-primary con 2 formas a 1366 px: cambia tamaño/.test(r.s) && /Enviar · \/contacto\//.test(r.s), r.s);
// 3 · lo que ya falla en una pagina sola no se repite entre paginas
r = corre(salida('/', 1366, [boton(), boton({ 'tamaño': '19px' })]), salida('/b/', 1366, [boton()]));
ver('lo que ya dice la pagina sola no se repite: PASA entre paginas', r.rc === 0 && !/entre paginas\) ·/.test(r.s), r.s);
// 4 · los anchos no se mezclan
r = corre(salida('/', 1366, [boton()]), salida('/b/', 1366, [boton()]), salida('/', 390, [boton({ 'tamaño': '14px' })]), salida('/b/', 390, [boton({ 'tamaño': '14px' })]));
ver('los anchos no se mezclan: 16 px a 1366 y 14 px a 390 es PASA', r.rc === 0 && /1366 px: 2 paginas/.test(r.s) && /390 px: 2 paginas/.test(r.s), r.s);
// 5 · la pintura, solo sobre el mismo fondo
const inv = { fondo: '#ffffff', texto: '#12384b' };
r = corre(salida('/', 1366, [boton()]), salida('/banda/', 1366, [boton(inv, { contexto: 'oscuro' })]));
ver('el invertido sobre fondo oscuro en otra pagina: PASA', r.rc === 0, r.s);
r = corre(salida('/', 1366, [boton()]), salida('/banda/', 1366, [boton(inv)]));
ver('el invertido sobre fondo claro en otra pagina: FALLA BT2', r.rc === 1 && /BT2 \(entre paginas\) · \.btn\.btn-primary sobre fondo claro/.test(r.s), r.s);
// 6 · la altura en una linea, entre paginas
r = corre(salida('/', 1366, [boton()]), salida('/b/', 1366, [boton({}, { alto: 56 })]));
ver('la misma forma, 48 y 56 px en una linea en dos paginas: FALLA BT3', r.rc === 1 && /BT3 \(entre paginas\)/.test(r.s), r.s);
// 7 · una salida que no vale no se junta y se dice
r = corre(salida('/', 1366, [boton()]), salida('/muro/', 1366, [boton({ 'tamaño': '30px' })], { sospechoso: true }));
ver('una salida «sospechosa» es NO MEDIDO y no se junta: 1 pagina valida, NO MEDIDO (rc 3)', r.rc === 3 && /NO MEDIDO .*sospechoso/.test(r.s) && /VEREDICTO NO MEDIDO/.test(r.s), r.s);
r = corre(salida('/', 1366, [boton()]), salida('/b/', 1366, [boton({ 'tamaño': '30px' })], {}, { coincide: false }));
ver('una salida con coincide false no se junta', r.rc === 3 && /el ancho no coincide/.test(r.s), r.s);
const roto = path.join(T, 'roto.out'); fs.writeFileSync(roto, 'RUNNER-ERROR net::ERR_CONNECTION_CLOSED\n');
r = corre(salida('/', 1366, [boton()]), salida('/b/', 1366, [boton()]), roto);
ver('un RUNNER-ERROR se nombra y las otras dos se comparan', r.rc === 0 && /NO MEDIDO  roto\.out: sin el JSON del gate/.test(r.s), r.s);
const viejo = path.join(T, 'viejo.out');
fs.writeFileSync(viejo, JSON.stringify({ coincide: true }) + '\n' + JSON.stringify({ VEREDICTO: 'PASA', coincide: true, innerWidth: 1366, datos: { botones: 1 } }));
r = corre(salida('/', 1366, [boton()]), viejo);
ver('una salida sin datos.lista (otro gate o una version vieja) no cuenta', r.rc === 3 && /sin datos\.lista/.test(r.s), r.s);
// 8 · la regla es UNA: botones-sitio usa la compara del gate, no una copia
ver('botones-sitio.js no lleva una copia de la regla (require del gate)', /require\(path\.join\(__dirname, 'botones-gate\.js'\)\)/.test(fs.readFileSync(SITIO, 'utf8')) &&
  !/mismaForma|mismoColor/.test(fs.readFileSync(SITIO, 'utf8')));

fs.rmSync(T, { recursive: true, force: true });
console.log(`\n  ${ok} OK · ${mal} MAL`);
process.exitCode = mal ? 1 : 0;
