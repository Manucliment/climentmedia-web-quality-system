// ===========================================================================
//  gate-index.js · EL INDICE REGLA -> INSTRUMENTO, DERIVADO Y CON DIENTES
// ===========================================================================
//  19-ago-2026. `standard-rules.json` ya traia un campo `gate` por regla, pero
//  era TEXTO LIBRE escrito a mano: nadie comprobaba que `qa-maestro EST-07`
//  existiera de verdad. Eso no es un indice, es una nota -- y una nota envejece
//  el dia que alguien renombra un check, sin que nada se queje.
//
//  Este programa lee los IDENTIFICADORES QUE CADA INSTRUMENTO EMITE, leyendolos
//  de su codigo, y los cruza con lo que el catalogo dice. Si una regla nombra un
//  check que no existe, sale ROJO. Es la misma medicina que hoy se le dio a
//  `anatomy.tsv` y a `audit.sh`: una fuente, derivada, y un gate que se pone
//  rojo cuando divergen.
//
//    node gate-index.js            EXIT 0 verde · 1 hay referencias muertas
//    node gate-index.js --huecos   ademas, lista lo que NO tiene instrumento
// ===========================================================================
const fs = require('fs'), path = require('path');
const DIR = __dirname;
const HUECOS = process.argv.includes('--huecos');
const leer = f => { try { return fs.readFileSync(path.join(DIR, f), 'utf8'); } catch { return null; } };
// Un instrumento puede vivir en references/ o dentro de su carpeta de pruebas
// (chk-collisions.pl y battery-layout.sh viven en structure-gate-tests/).
// La primera version solo miraba la raiz y los declaro fantasmas: el barrido
// estaba roto, no el catalogo. Se busca en un nivel de subcarpetas.
const existe = f => fs.existsSync(path.join(DIR, f)) ||
  fs.readdirSync(DIR, { withFileTypes: true }).filter(d => d.isDirectory())
    .some(d => fs.existsSync(path.join(DIR, d.name, f)));
const todos = (t, re) => t ? [...new Set([...t.matchAll(re)].map(m => m[1]))] : [];

// --- 1 · que emite cada instrumento, LEIDO DE SU CODIGO --------------------
const EMITE = {
  'qa-master.pl':    todos(leer('qa-master.pl'),    /id\s*=>\s*'([A-Z][A-Z0-9]*-[0-9]+[a-z]?)'/g),
  'audit.sh':         todos(leer('audit.sh'),         /\b(?:ok|bad|warn|skip)\s+"(S[0-9]+\.[0-9]+)/g),
  'linking-gate.pl': todos(leer('linking-gate.pl'), /\b(R[0-9]+)\b/g),
  'audit-vs-spec.pl': todos(leer('audit-vs-spec.pl'), /id\s*=>\s*'([A-Z]+-[0-9]+[a-z]?)'/g),
};
// instrumentos sin identificadores propios: basta con que el fichero exista
const SIN_IDS = ['structure-gate.js','measure-screens.js','forms-gate.js','qa-final.sh',
                 'audit-vs-source.sh','crawl-links.pl','compliance.pl','receipt.pl',
                 'deploy.sh','doc-gate.pl','same-text.pl','anatomy.pl','history-gate.pl'];
const TODOS_IDS = new Set(Object.values(EMITE).flat());

// --- 2 · el catalogo -------------------------------------------------------
const reglas = JSON.parse(fs.readFileSync(path.join(DIR, 'standard-rules.json'), 'utf8')).reglas;

// --- 3 · cruce -------------------------------------------------------------
const muertas = [], ficheroFantasma = [], sinInstrumento = [];
for (const r of reglas) {
  const g = String(r.gate || '');
  if (/^NINGUNO/i.test(g)) { sinInstrumento.push(r); continue; }
  // ficheros nombrados que tienen que existir
  for (const f of g.match(/[a-z0-9-]+\.(?:pl|sh|js)/gi) || [])
    if (!existe(f)) ficheroFantasma.push({ id: r.id, f, gate: g });
  // identificadores nombrados que tienen que emitirse
  for (const id of g.match(/\b(?:[A-Z][A-Z0-9]{1,5}-[0-9]+[a-z]?|S[0-9]+\.[0-9]+|R[0-9]+)\b/g) || [])
    if (!TODOS_IDS.has(id)) muertas.push({ id: r.id, ref: id, gate: g });
}

// --- 4 · informe -----------------------------------------------------------
const pad = (s, n) => String(s).padEnd(n);
console.log('='.repeat(78));
console.log('  INDICE REGLA -> INSTRUMENTO   ·   ' + reglas.length + ' reglas del estandar');
console.log('='.repeat(78));
console.log();
console.log('  LO QUE EMITE CADA INSTRUMENTO (leido de su codigo, no escrito aqui)');
for (const [k, v] of Object.entries(EMITE)) console.log('    ' + pad(k, 22) + String(v.length).padStart(3) + ' identificadores');
console.log('    ' + pad('(sin ids propios)', 22) + String(SIN_IDS.length).padStart(3) + ' instrumentos, solo se comprueba que existan');
console.log();

let rc = 0;
if (muertas.length) {
  rc = 1;
  console.log('  🔴 REFERENCIAS MUERTAS: la regla nombra un check que NINGUN instrumento emite');
  for (const m of muertas) console.log('     ' + pad(m.id, 10) + '-> ' + pad(m.ref, 10) + '  (gate: "' + m.gate.slice(0, 46) + '")');
  console.log();
}
if (ficheroFantasma.length) {
  rc = 1;
  console.log('  🔴 FICHEROS QUE NO EXISTEN: la regla nombra un instrumento que no esta');
  for (const m of ficheroFantasma) console.log('     ' + pad(m.id, 10) + '-> ' + m.f);
  console.log();
}
if (!muertas.length && !ficheroFantasma.length)
  console.log('  ✅ toda referencia del catalogo apunta a un check que existe de verdad.\n');

// --- 5 · la cobertura, que es la pregunta de negocio -----------------------
const cuenta = (arr, m) => arr.filter(r => String(r.comprobable_maquina) === m).length;
const con = reglas.filter(r => !/^NINGUNO/i.test(String(r.gate || '')));
console.log('  COBERTURA');
console.log('    con instrumento ......... ' + String(con.length).padStart(4) + '   (' + Math.round(con.length / reglas.length * 100) + '%)');
console.log('    SIN instrumento ......... ' + String(sinInstrumento.length).padStart(4));
console.log('       medibles por maquina . ' + String(cuenta(sinInstrumento, 'si')).padStart(4) + '   <- se pueden escribir');
console.log('       parciales ............ ' + String(cuenta(sinInstrumento, 'parcial')).padStart(4));
console.log('       juicio humano ........ ' + String(cuenta(sinInstrumento, 'no')).padStart(4) + '   <- ningun gate las medira, y no es un fallo');
const techo = con.length + cuenta(sinInstrumento, 'si') + cuenta(sinInstrumento, 'parcial');
console.log('    TECHO ALCANZABLE ........ ' + String(techo).padStart(4) + '   (' + Math.round(techo / reglas.length * 100) + '%)');
console.log('    Decir 100% seria mentir: el propio estandar marca ' + cuenta(reglas, 'no') + ' reglas como');
console.log('    no comprobables por maquina. Esas van al bloque B de 08-qa-final.md.');
console.log();

if (HUECOS) {
  console.log('  LO QUE NO MIDE NADIE Y SI SE PODRIA MEDIR (' + cuenta(sinInstrumento, 'si') + ')');
  for (const r of sinInstrumento.filter(r => String(r.comprobable_maquina) === 'si'))
    console.log('     ' + pad(r.id, 10) + String(r.texto || '').replace(/\s+/g, ' ').slice(0, 84));
  console.log();
}
// run-all.sh lee `OK <n>` y `MAL <n>`. Sin esta linea el banco salia con
// «no he sabido leer su recuento», que cuenta como CERO y se lee como aprobado.
// Cada referencia del catalogo validada contra el codigo es un caso.
console.log('  OK ' + con.length + '  ·  MAL ' + (muertas.length + ficheroFantasma.length));
console.log('  ' + (rc ? '🔴 EL INDICE Y LOS INSTRUMENTOS NO CUADRAN' : 'El indice cuadra con los instrumentos.'));
console.log('  Lo que este gate NO dice: si el check que existe mide BIEN la regla.');
console.log('  Solo dice que la referencia no esta muerta.');
process.exit(rc);
