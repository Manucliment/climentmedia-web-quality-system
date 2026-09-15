#!/usr/bin/env node
// =============================================================================
//  leak-sweep.js · el barrido de fugas de un repo PUBLICO
// =============================================================================
//    node gates/leak-sweep.js <dir>          barre ese arbol
//    node gates/leak-sweep.js <dir> --solo-autotest   solo se prueba a si mismo
//
//  POR QUE EXISTE (15-sep-2026). El CLAUDE.md de la casa afirmaba, desde que
//     este repo se hizo publico, que "el repo lleva su propio barrido de fugas".
//     NO LO LLEVABA: no habia CI, ni hooks de git instalados, ni script. Era una
//     regla escrita en prosa -- y una regla no es un guardia. Peor: creer que hay
//     uno es peor que saber que no lo hay, porque se commitea con confianza.
//
//     Lo que se pago, medido ese dia sobre este mismo arbol: el dominio de un
//     cliente dos veces en los comentarios de qa-master.pl, la marca de otro en
//     seis sitios, y dentro de un fichero de datos de prueba la MARCA, la CIUDAD,
//     la CALLE y el TELEFONO reales de un cliente.
//
//     Lo ultimo es lo que enseña la leccion: alguien ya habia anonimizado este
//     repo -- `site-a.example`, `site-d.example` estan por todas partes. El saneado
//     fue PARCIAL: cambio el DOMINIO y dejo la marca y la direccion dentro de las
//     cadenas entrecomilladas. Un saneado a mano cubre lo que su autor recordo.
//
//  🔴 Y LA PRIMERA VERSION DE ESTE FICHERO COMETIO LA FUGA QUE VENIA A CERRAR,
//     el mismo dia, en el mismo commit. Para poder buscar a los clientes llevaba
//     dentro la LISTA ENTERA -- dominios, marca, ciudad, calle -- y el alias del
//     servidor, y se eximia a si mismo del barrido para no acusarse. O sea que el
//     guardia publico en un repo publico exactamente lo que existe para impedir, y
//     ademas ENUMERADO en una sola linea, que es peor que la fuga suelta: ahorra
//     el trabajo de buscar. Se subio a GitHub antes de verlo.
//
//     El arreglo no es acordarse: los terminos privados viven en
//     `gates/config/leak-terms.local.conf`, que `.gitignore` cubre con `*.conf`, y
//     este fichero solo trae los patrones GENERICOS (rutas de maquina, IPs,
//     telefonos, correos) que no nombran a nadie. Si el fichero privado no esta,
//     el barrido corre con los terminos INVENTADOS del `.example` -- para que el
//     recuento sea el mismo aqui que en un clon limpio -- y NO CALLA: dice en su
//     salida que lo que ha probado es la maquinaria, no el arbol. Y se barre A SI
//     MISMO, con el autotest, exigiendo que no vuelva a
//     aparecer aqui ni un nombre propio -- porque la exencion de abajo lo hace
//     invisible para su propio barrido, y esa exencion es justo como nacio esto.
//
//  CODIGOS: 0 limpio · 1 hay hallazgos · 2 no se que barrer · 3 NO MEDIDO
//  (el autotest no pasa, asi que el barrido no se puede creer: no es un aprobado).
// =============================================================================

const fs = require('fs'), path = require('path'), os = require('os');
const YO = path.basename(__filename);

// --- los terminos privados, que NO se commitean -----------------------------
// Formato, una directiva por linea:   patron <id> <fragmento de regex>
//                                     ejemplo <id> <texto que TIENE que disparar>
// El ejemplo va aqui y no en el codigo por lo mismo: un caso de prueba que
// contiene un nombre de cliente es tan publico como el patron que lo busca.
const CONF = path.join(__dirname, 'config', 'leak-terms.local.conf');
const CONF_EJ = path.join(__dirname, 'config', 'leak-terms.conf.example');
// 🔑 Si no esta el privado se cargan los del `.example`, que son inventados. NO es
//    para maquillar el rojo: es que el recuento del banco tiene que ser el MISMO en
//    un clon limpio que aqui, o el numero que el README promete a quien clone no se
//    cumple -- y eso es lo que D6 existe para impedir. Con los de ejemplo el
//    autotest sigue probando la MAQUINARIA (que los patrones se construyen y
//    disparan); lo que no hace es proteger de nada, y por eso se dice en voz alta.
function cargaPrivados() {
  const cual = fs.existsSync(CONF) ? CONF : (fs.existsSync(CONF_EJ) ? CONF_EJ : null);
  if (!cual) return null;
  const out = { patron: {}, ejemplo: {}, fichero: cual, real: cual === CONF };
  for (const l of fs.readFileSync(cual, 'utf8').split(/\r?\n/)) {
    if (/^\s*#/.test(l)) continue;
    const m = l.match(/^\s*(patron|ejemplo)\s+([a-z]+)\s+(.+?)\s*$/);
    if (!m) continue;
    (out[m[1]][m[2]] = out[m[1]][m[2]] || []).push(m[3]);
  }
  return out;
}
const PRIV = cargaPrivados();
const priv = (clase, id) => (PRIV && PRIV[clase][id] ? PRIV[clase][id] : []);

// Cada patron dice QUE busca y POR QUE. Sin motivo no entra: un patron sin
// motivo se borra el dia que le molesta a alguien.
const PATRONES = [
  { id: 'maquina',  motivo: 'ruta de la maquina de un desarrollador',
    re: /(?:[A-Za-z]:[\\/]Users[\\/][A-Za-z]|\/c\/Users\/[A-Za-z]|\/home\/[a-z]{3,8}\b|Desktop[\\/]Claude)/g },
  { id: 'persona',  motivo: 'correo o cuenta personal',
    re: new RegExp('[\\w.+-]+@(?:' + ['gmail', 'climentmedia'].concat(priv('patron', 'persona')).join('|') + ')\\.[a-z]{2,}', 'gi') },
  { id: 'ip',       motivo: 'IP de un host propio',
    re: /\b(?:\d{1,3}\.){3}\d{1,3}\b/g },
  { id: 'telefono', motivo: 'telefono que parece real',
    re: /\b0\d{2,3}(?:[ ./-]\d{2}){3}\b/g },
];
// Los que nombran a alguien solo existen si el fichero privado los trae.
for (const [id, motivo, banderas] of [
  ['cliente',  'dominio, marca o direccion de un cliente', 'gi'],
  ['servidor', 'nombre o usuario de un servidor privado',  'g'],
]) {
  const t = priv('patron', id);
  if (t.length) PATRONES.push({ id, motivo, re: new RegExp('\\b(?:' + t.join('|') + ')\\b', banderas) });
}

// Lo que NO es fuga. Toda exencion va NOMBRADA con su razon, para que el dia que
// alguien la quite sepa que esta quitando.
const EXENTO = [
  { re: /\bclimentmedia\b/gi,                                    por: 'es la marca DUENA del repo' },
  { re: /\b(?:8\.8\.8\.8|1\.1\.1\.1)\b/g,                        por: 'DNS publico, no identifica a nadie' },
  { re: /\b(?:203\.0\.113|192\.0\.2|198\.51\.100)\.\d{1,3}\b/g,  por: 'RFC 5737/6890: reservado para documentacion' },
  { re: /\b(?:0|127)\.0\.0\.(?:0|1)\b/g,                         por: 'bucle local' },
  { re: /\b\d{2,3}\.0\.0\.0\b/g,                                 por: 'version de navegador en un user agent' },
  { re: /\b0[24]\d?(?:[ ./-]0{2}){3}\b|\b0[24]\d?(?:[ ./-]\d{2})*[ ./-]00[ ./-]00\b/g, por: 'telefono fabricado para un fixture (termina en ceros)' },
  // El patron de `maquina` dejo de nombrar a un usuario concreto (`/home/manu`) el
  // 15-sep: ese nombre se fue al fichero privado como todo lo demas. Al generalizarlo
  // empezo a acusar los marcadores de posicion que los `.example` usan para ENSEÑAR
  // la forma de una ruta, que es lo contrario de una fuga.
  { re: /\/home\/(?:you|user|usuario|username|me)\b/g, por: 'marcador de posicion de un .example, no la ruta de nadie' },
];

// Lo unico que este fichero puede llevar dentro y que se PARECE a una fuga: sus
// propios casos de prueba. Van declarados UNO A UNO, con su motivo, porque el
// autocontrol de mas abajo se barre a si mismo y sin esto sale rojo por ellos.
// 🔴 Aqui NO se anade nada para callar un rojo: si el autocontrol acusa algo que
//    no esta en esta lista, es que ha entrado un dato de verdad. Se quita el dato,
//    no se amplia la lista -- ampliarla es reabrir a mano el agujero del 15-sep.
const FABRICADOS = [
  { s: '198.18.0.42', por: 'RFC 2544: rango reservado para pruebas, no es de nadie' },
  { s: '198.18.0.0',  por: 'la misma, citada en el comentario que la explica' },
  { s: 'alguien@gmail.com', por: 'buzon inventado, el caso positivo del patron persona' },
  { s: '081 23 45 67', por: 'telefono inventado, el caso positivo del patron telefono' },
];

// Un fichero de terminos LISTA lo que se busca, asi que casa consigo mismo entero.
// Es la misma exencion que la de este programa, y por el mismo motivo: el texto que
// declara una firma la contiene. El privado no llega aqui igualmente -- .gitignore
// lo cubre, y la lista sale de git -- pero el `.example` si se publica.
const SALTA_FICHERO = /^leak-terms\./;
const SALTA_DIR = new Set(['.git', 'node_modules']);
const BINARIO = /\.(png|jpe?g|webp|gif|ico|pdf|zip|tgz|gz|woff2?|ttf|mp4|svg)$/i;
const redacta = (s) => s.length <= 4 ? '***' : s.slice(0, 2) + '*'.repeat(Math.max(3, s.length - 4)) + s.slice(-2);

function hitsEn(texto) {
  const out = [];
  texto.split('\n').forEach((l, i) => {
    for (const pat of PATRONES) {
      pat.re.lastIndex = 0;
      for (const m of l.matchAll(pat.re)) {
        if (EXENTO.some((x) => { x.re.lastIndex = 0; return x.re.test(m[0]); })) continue;
        out.push({ n: i + 1, id: pat.id, motivo: pat.motivo, hit: m[0] });
      }
    }
  });
  return out;
}

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
  const mete = (rel, t) => {
    ficheros++;
    lineas += t.split('\n').length;
    for (const h of hitsEn(t)) hallazgos.push({ f: rel, n: h.n, id: h.id, motivo: h.motivo, hit: h.hit });
  };
  const soloEstos = listaGit(raiz);
  if (soloEstos) {
    for (const rel of soloEstos) {
      const e = path.basename(rel);
      if (BINARIO.test(e) || e === YO || SALTA_FICHERO.test(e) || SALTA_DIR.has(rel.split('/')[0])) continue;
      let t; try { t = fs.readFileSync(path.join(raiz, rel), 'utf8'); } catch { continue; }
      mete(rel, t);
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
      if (BINARIO.test(e.name) || SALTA_FICHERO.test(e.name)) continue;
      // 🔑 Este fichero lleva dentro los patrones de RUTA que busca (`/home/...`,
      //    `Desktop/Claude`), asi que sin esta linea se acusa a si mismo: el texto
      //    que explica una firma la contiene. Lo que ya NO lleva dentro es un solo
      //    nombre propio -- y de que siga siendo verdad se encarga el autotest, no
      //    esta exencion, que es justo lo que dejo pasar la fuga del 15-sep.
      if (e.name === YO) continue;
      let t; try { t = fs.readFileSync(path.join(d, e.name), 'utf8'); } catch { continue; }
      mete(path.relative(raiz, path.join(d, e.name)).replace(/\\/g, '/'), t);
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

  // Los casos genericos se escriben aqui porque no nombran a nadie. La IP es la
  // 198.18.0.0/15 de la RFC 2544 -- reservada para pruebas, asi que no es de
  // nadie, y a proposito NO esta entre las exenciones para que siga disparando.
  const casos = [
    ['maquina',  'C:/Users/Alguien/Desktop/Claude/x'],
    ['persona',  'alguien@gmail.com'],
    ['ip',       'servidor 198.18.0.42'],
    ['telefono', 'Rendez-vous au 081 23 45 67'],
  ];
  // Y los que SI nombran a alguien salen del fichero privado, o no se corren.
  for (const id of ['cliente', 'servidor', 'persona']) {
    for (const txt of priv('ejemplo', id)) casos.push([id, txt]);
  }
  fs.writeFileSync(path.join(tmp, 'sucio.md'), casos.map((c) => c[1]).join('\n'));
  r = barrer(tmp);
  const fallan = casos.filter(([id, txt]) => !r.hallazgos.some((h) => h.id === id && txt.includes(h.hit)));

  // 🔴 El barrido SOBRE SI MISMO, sin la exencion que lo hace invisible. Solo
  //    puede disparar por `maquina`, que son sus propios patrones de ruta citados
  //    como codigo. Un nombre de cliente, un correo o una IP aqui dentro es la
  //    fuga del 15-sep repitiendose, y este caso es lo unico que la ve.
  const mios = hitsEn(fs.readFileSync(__filename, 'utf8'))
    .filter((h) => h.id !== 'maquina')
    .filter((h) => !FABRICADOS.some((x) => x.s === h.hit));
  const limpioYo = mios.length === 0;

  fs.rmSync(tmp, { recursive: true, force: true });
  console.log('  autotest NEGATIVO (arbol limpio -> 0 hallazgos): ' + (neg ? 'OK' : 'MAL, dio ' + r.hallazgos.length));
  console.log('  autotest POSITIVO (' + casos.length + ' casos, cada uno debe disparar): ' + (fallan.length ? 'MAL' : 'OK'));
  fallan.forEach(([id, txt]) => console.log('     no disparo · ' + id + ' :: ' + txt));
  console.log('  el propio barrido, sin su exencion (0 nombres propios dentro): ' +
    (limpioYo ? 'OK' : 'MAL, ' + mios.map((h) => h.id + ':' + h.n).join(' ')));
  if (!PRIV || !PRIV.real) {
    console.log('  ⚠️  NO MEDIDO · cliente, servidor y persona: falta gates/config/leak-terms.local.conf.');
    console.log('      Los casos de arriba han corrido con los terminos INVENTADOS del .example, asi');
    console.log('      que prueban que la maquinaria dispara, y NO que aqui no haya un nombre real.');
    console.log('      Copia gates/config/leak-terms.conf.example y rellenalo. NO se commitea.');
  }
  const ok = (neg ? 1 : 0) + (limpioYo ? 1 : 0) + casos.length - fallan.length;
  // 🔑 El recuento va en uno de los formatos que run-all.sh sabe leer. Sin esto el
  //    lanzador dice «no he sabido leer su recuento» y el banco aporta CERO al total:
  //    corre, pasa, y no cuenta -- que es medio invisible.
  console.log('\n  ' + ok + ' OK · ' + ((neg ? 0 : 1) + (limpioYo ? 0 : 1) + fallan.length) + ' MAL');
  return neg && limpioYo && !fallan.length;
}

const soloAuto = process.argv.includes('--solo-autotest');
const ok = autotest();
if (!ok) { console.log('\n  NO MEDIDO: el autotest no pasa, asi que este barrido no se puede creer.'); process.exit(3); }
if (soloAuto) { console.log('\n  autotest PASA.'); process.exit(0); }

const raiz = process.argv[2] && !process.argv[2].startsWith('--') ? process.argv[2] : path.join(__dirname, '..');
if (!fs.existsSync(raiz)) { console.error('uso: node leak-sweep.js <dir>'); process.exit(2); }
const { hallazgos, ficheros, lineas, via } = barrer(raiz);
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
