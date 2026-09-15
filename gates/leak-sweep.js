#!/usr/bin/env node
// =============================================================================
//  leak-sweep.js · el barrido de fugas de un repo PUBLICO
// =============================================================================
//    node gates/leak-sweep.js <dir>          barre ese arbol
//    node gates/leak-sweep.js <dir> --solo-autotest   solo se prueba a si mismo
//
//  🔴 POR QUE EXISTE (15-sep-2026). El CLAUDE.md de la casa afirmaba, desde que
//     este repo se hizo publico, que "el repo lleva su propio barrido de fugas".
//     NO LO LLEVABA: no habia CI, ni hooks de git instalados, ni script. Era una
//     regla escrita en prosa -- y una regla no es un guardia. Peor: creer que hay
//     uno es peor que saber que no lo hay, porque se commitea con confianza.
//
//     Lo que se pago, medido ese dia sobre este mismo arbol:
//       · `eldestinodenora.es` dos veces en comentarios de qa-master.pl, commiteado
//         y publicado en GitHub;
//       · y dentro de un fichero de datos de prueba, la MARCA, la CIUDAD, la CALLE
//         y el TELEFONO reales de un cliente.
//
//     El segundo es el que enseña la leccion: alguien ya habia anonimizado este
//     repo -- `site-a.example`, `site-d.example` estan por todas partes. El barrido
//     fue PARCIAL: cambio el DOMINIO y dejo la marca y la direccion dentro de las
//     cadenas entrecomilladas. Un saneado a mano cubre lo que su autor recordo.
//
//  CODIGOS: 0 limpio · 1 hay hallazgos · 2 no se que barrer · 3 NO MEDIDO
//  (el autotest no pasa, asi que el barrido no se puede creer: no es un aprobado).
// =============================================================================

const fs = require('fs'), path = require('path'), os = require('os');
const YO = path.basename(__filename);

// Cada patron dice QUE busca y POR QUE. Sin motivo no entra: un patron sin
// motivo se borra el dia que le molesta a alguien.
const PATRONES = [
  { id: 'cliente',  motivo: 'dominio, marca o direccion de un cliente',
    re: /\b(kineadomicile|kineaanhuis|kine-vlaanderen|tisolve|ti-care|eldestinodenora|mobanho|xpertclinics|oliverservices|bcmadrid|oraculo-web|shrine-theme|Etterbeek|Chauss[e\u00e9]e de Wavre|Braine-l|Bois de Hal)\b/gi },
  { id: 'maquina',  motivo: 'ruta de la maquina de un desarrollador',
    re: /(?:[A-Za-z]:[\\/]Users[\\/][A-Za-z]|\/c\/Users\/[A-Za-z]|\/home\/manu\b|Desktop[\\/]Claude)/g },
  { id: 'servidor', motivo: 'nombre o usuario de un servidor privado',
    re: /\b(ecommgrowthlab|u49\d{7})\b/g },
  { id: 'persona',  motivo: 'correo o cuenta personal',
    re: /[\w.+-]+@(?:ecommgrowthlab|gmail|climentmedia)\.[a-z]{2,}/gi },
  { id: 'ip',       motivo: 'IP de un host propio',
    re: /\b(?:\d{1,3}\.){3}\d{1,3}\b/g },
  { id: 'telefono', motivo: 'telefono que parece real',
    re: /\b0\d{2,3}(?:[ ./-]\d{2}){3}\b/g },
];

// Lo que NO es fuga. Toda exencion va NOMBRADA con su razon, para que el dia que
// alguien la quite sepa que esta quitando.
const EXENTO = [
  { re: /\bclimentmedia\b/gi,                                    por: 'es la marca DUENA del repo' },
  { re: /\b(?:8\.8\.8\.8|1\.1\.1\.1)\b/g,                        por: 'DNS publico, no identifica a nadie' },
  { re: /\b(?:203\.0\.113|192\.0\.2|198\.51\.100)\.\d{1,3}\b/g,  por: 'RFC 5737/6890: reservado para documentacion' },
  { re: /\b(?:0|127)\.0\.0\.(?:0|1)\b/g,                         por: 'bucle local' },
  { re: /\b\d{2,3}\.0\.0\.0\b/g,                                 por: 'version de navegador en un user agent' },
  { re: /\b0[24]\d?(?:[ ./-]0{2}){3}\b|\b0[24]\d?(?:[ ./-]\d{2})*[ ./-]00[ ./-]00\b/g, por: 'telefono fabricado para un fixture (termina en ceros)' },
];

const SALTA_DIR = new Set(['.git', 'node_modules']);
const BINARIO = /\.(png|jpe?g|webp|gif|ico|pdf|zip|tgz|gz|woff2?|ttf|mp4|svg)$/i;
const redacta = (s) => s.length <= 4 ? '***' : s.slice(0, 2) + '*'.repeat(Math.max(3, s.length - 4)) + s.slice(-2);

// 🔑 Se barre LO QUE SE PUBLICA, no el disco. Si el arbol es un repo, la lista sale
//    de git (rastreados + sin rastrear que NO esten ignorados): un fichero que
//    `.gitignore` cubre no puede llegar a GitHub, y marcarlo es llorar sin motivo --
//    y un guardia que llora sin motivo se acaba apagando.
function listaGit(raiz) {
  try {
    const { execFileSync } = require('child_process');
    const out = execFileSync('git', ['-C', raiz, 'ls-files', '--cached', '--others', '--exclude-standard'],
      { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], maxBuffer: 32 * 1024 * 1024 });
    const l = out.split('\n').map((x) => x.trim()).filter(Boolean);
    return l.length ? l : null;
  } catch { return null; }
}

function barrer(raiz) {
  const hallazgos = [];
  let ficheros = 0, lineas = 0;
  const soloEstos = listaGit(raiz);
  if (soloEstos) {
    for (const rel of soloEstos) {
      const e = path.basename(rel);
      if (BINARIO.test(e) || e === YO || SALTA_DIR.has(rel.split('/')[0])) continue;
      const p = path.join(raiz, rel);
      let t; try { t = fs.readFileSync(p, 'utf8'); } catch { continue; }
      ficheros++;
      t.split('\n').forEach((l, i) => {
        lineas++;
        for (const pat of PATRONES) {
          pat.re.lastIndex = 0;
          for (const m of l.matchAll(pat.re)) {
            if (EXENTO.some((x) => { x.re.lastIndex = 0; return x.re.test(m[0]); })) continue;
            hallazgos.push({ f: rel, n: i + 1, id: pat.id, motivo: pat.motivo, hit: m[0] });
          }
        }
      });
    }
    return { hallazgos, ficheros, lineas, via: 'git' };
  }
  (function walk(d) {
    let ents; try { ents = fs.readdirSync(d, { withFileTypes: true }); } catch { return; }
    for (const e of ents) {
      // 🔑 `.git` se salta SIEMPRE, sea directorio o fichero: en un worktree es un
      //    FICHERO (`gitdir: ...`) con la ruta absoluta de la maquina dentro. Es el
      //    mismo defecto que `_respaldo/revisar.sh` tuvo el 4-sep, cometido aqui el
      //    dia que se escribio este barrido.
      if (SALTA_DIR.has(e.name)) continue;
      if (e.isDirectory()) { walk(path.join(d, e.name)); continue; }
      if (BINARIO.test(e.name)) continue;
      // 🔑 Este fichero LLEVA DENTRO los nombres que busca. Sin esta linea se
      //    acusa a si mismo: el texto que explica una firma la contiene.
      if (e.name === YO) continue;
      const p = path.join(d, e.name);
      let t; try { t = fs.readFileSync(p, 'utf8'); } catch { continue; }
      ficheros++;
      t.split('\n').forEach((l, i) => {
        lineas++;
        for (const pat of PATRONES) {
          pat.re.lastIndex = 0;
          for (const m of l.matchAll(pat.re)) {
            if (EXENTO.some((x) => { x.re.lastIndex = 0; return x.re.test(m[0]); })) continue;
            hallazgos.push({ f: path.relative(raiz, p).replace(/\\/g, '/'), n: i + 1, id: pat.id, motivo: pat.motivo, hit: m[0] });
          }
        }
      });
    }
  })(raiz);
  return { hallazgos, ficheros, lineas, via: 'disco' };
}

// --- el autotest: un gate que no se puede ver en ROJO no vale nada
function autotest() {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'leak-'));
  fs.writeFileSync(path.join(tmp, 'limpio.md'),
    '# gate\nMide el sitio contra su spec. climentmedia es la marca duena.\n' +
    'localhost 127.0.0.1 - DNS 8.8.8.8 - doc 203.0.113.10 - Chrome/150.0.0.0\n' +
    'constantes OKLab: 0.2158037573 y 0.0894841775\n' +
    'telefono de fixture: +34 600 00 00 00 y 02 000 00 00\n');
  let r = barrer(tmp);
  const neg = r.hallazgos.length === 0;
  const casos = [
    ['cliente',  'lo destapo eldestinodenora.es al poner su pixel'],
    ['cliente',  'Ti-Care, centre a Etterbeek (Chaussee de Wavre 489)'],
    ['maquina',  'C:/Users/Alguien/Desktop/Claude/x'],
    ['servidor', 'ssh ecommgrowthlab'],
    ['persona',  'alguien@ecommgrowthlab.com'],
    ['ip',       'servidor 89.116.53.53'],
    ['telefono', 'Rendez-vous au 067 49 31 21'],
  ];
  fs.writeFileSync(path.join(tmp, 'sucio.md'), casos.map((c) => c[1]).join('\n'));
  r = barrer(tmp);
  const fallan = casos.filter(([id, txt]) => !r.hallazgos.some((h) => h.id === id && txt.includes(h.hit)));
  fs.rmSync(tmp, { recursive: true, force: true });
  console.log('  autotest NEGATIVO (arbol limpio -> 0 hallazgos): ' + (neg ? 'OK' : 'MAL, dio ' + r.hallazgos.length));
  console.log('  autotest POSITIVO (' + casos.length + ' casos, cada uno debe disparar): ' + (fallan.length ? 'MAL' : 'OK'));
  fallan.forEach(([id, txt]) => console.log('     no disparo · ' + id + ' :: ' + txt));
  // 🔑 El recuento va en uno de los formatos que run-all.sh sabe leer. Sin esto el
  //    lanzador dice «no he sabido leer su recuento» y el banco aporta CERO al total:
  //    corre, pasa, y no cuenta -- que es medio invisible.
  const ok = (neg ? 1 : 0) + casos.length - fallan.length;
  console.log('\n  ' + ok + ' OK · ' + ((neg ? 0 : 1) + fallan.length) + ' MAL');
  return neg && !fallan.length;
}

const soloAuto = process.argv.includes('--solo-autotest');
const ok = autotest();
if (!ok) { console.log('\n  NO MEDIDO: el autotest no pasa, asi que este barrido no se puede creer.'); process.exit(3); }
if (soloAuto) { console.log('\n  autotest PASA.'); process.exit(0); }

const raiz = process.argv[2] && !process.argv[2].startsWith('--') ? process.argv[2] : path.join(__dirname, '..');
if (!fs.existsSync(raiz)) { console.error('uso: node leak-sweep.js <dir>'); process.exit(2); }
const { hallazgos, ficheros, lineas } = barrer(raiz);
const { via } = barrer(raiz);
console.log('\nbarridos ' + ficheros + ' ficheros · ' + lineas + ' lineas · hallazgos: ' + hallazgos.length +
  '  (lista: ' + (via === 'git' ? 'git, o sea lo que se PUBLICA' : 'disco: el arbol no es un repo') + ')');
const porId = {};
for (const h of hallazgos) (porId[h.id] = porId[h.id] || []).push(h);
for (const id of Object.keys(porId)) {
  console.log('\n== ' + id + '  (' + porId[id][0].motivo + ')  ·  ' + porId[id].length);
  // el hallazgo va REDACTADO: un barrido que escupe la fuga entera la copia al
  // log de CI, que tambien es publico.
  for (const h of porId[id]) console.log('   ' + h.f + ':' + h.n + '  ' + redacta(h.hit));
}
if (!hallazgos.length) console.log('\n  PASA · ni un nombre de cliente, ni una ruta de maquina, ni un dato personal.');
process.exit(hallazgos.length ? 1 : 0);
