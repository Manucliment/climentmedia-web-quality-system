#!/usr/bin/env node
// =============================================================================
//  pipefail-guard.js · `pipefail` y `| grep -q` no viven en el mismo guion
// =============================================================================
//    node gates/pipefail-guard.js <dir>                   barre los .sh de ese arbol
//    node gates/pipefail-guard.js <dir> --solo-autotest   solo se prueba a si mismo
//
//  POR QUE EXISTE (3-nov-2026). `productor | grep -q X` con `set -o pipefail`
//     devuelve 141 en cuanto el productor sigue escribiendo despues de que grep
//     haya salido: grep -q sale al primer acierto y el productor muere por SIGPIPE.
//     Medido ese dia, 50 corridas por caso, texto de muchas lineas con el acierto
//     en la primera, en el servidor de medicion (Linux) y en Git Bash:
//         30 KB  sin pipefail 0 · con pipefail 0
//         70 KB  sin pipefail 0 · con pipefail 141 en 44 de 50 (servidor), 50 de 50 (local)
//        200 KB  sin pipefail 0 · con pipefail 141 en 50 de 50
//     Un HTML de 70 KB es normal. Y en una guarda «rojo si lo trae»
//     (`... | grep -q X && mal`) ese 141 es un VERDE MUDO: la guarda no dispara.
//     ⚠️ Con UNA sola linea gigante no sale nunca: grep tiene que leerla entera
//     para decidir. Una primera medida asi «refuto» el defecto. Era el instrumento.
//
//  QUE NO HACE. No cambia los 78 `| grep -q` del repo: HOY ningun guion activa
//     pipefail, y sin pipefail el codigo de la tuberia es el de grep, que es el
//     bueno (0 de 400 corridas en falso). Reescribirlos seria un arreglo que no se
//     ve actuar. Lo que si se ve actuar es esto: el dia que alguien ponga pipefail
//     en un guion que lleva un `| grep -q`, se pone ROJO con fichero y linea.
//     La forma buena entonces: `grep -q X <<< "$v"`, o `grep X >/dev/null` (lee hasta el final).
//
//  SALIDA: 0 limpio · 1 hay guiones con las dos cosas · 2 uso · 3 NO MEDIDO (el
//     autotest no pasa, asi que el barrido no se puede creer).
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

// Activa pipefail: `set -o pipefail`, `set -euo pipefail`, `bash -o pipefail`,
// un SHELLOPTS que lo exporta. Se mira la linea sin su comentario.
// Con otras opciones delante (`set -u -o pipefail`): la primera version solo
// aceptaba `-o` justo detras de `set`, y su rojo en vivo salio VERDE.
const ACTIVA = /(^|[\s;&|(])(set|bash|sh)\b[^;&|#\n]*\s-[a-zA-Z]*o\s+pipefail\b|SHELLOPTS=[^\s]*pipefail/;
// Una tuberia hacia grep con -q (sola o junta: -q, -qF, -Eq, --quiet).
const GREPQ = /\|\s*grep\s+(-[a-zA-Z]*q[a-zA-Z]*\b|--quiet\b|(-\S+\s+)+-[a-zA-Z]*q[a-zA-Z]*\b)/;

function sinComentario(l) {
  // Quita un `#` que empieza comentario (al principio o tras espacio). Es una
  // aproximacion: un `#` dentro de comillas no se trata aparte, y eso solo puede
  // hacer que se vea MENOS, nunca que acuse de mas.
  return l.replace(/(^|\s)#.*$/, '');
}

function mira(texto) {
  const lineas = texto.split('\n');
  const activa = [], grepq = [];
  lineas.forEach((l, i) => {
    const c = sinComentario(l);
    if (ACTIVA.test(c)) activa.push(i + 1);
    if (GREPQ.test(c)) grepq.push(i + 1);
  });
  return { activa, grepq, mal: activa.length > 0 && grepq.length > 0 };
}

// ── autotest ─────────────────────────────────────────────────────────────────
const CASOS = [
  { nombre: 'pipefail + printf | grep -q', debe: true,
    texto: 'set -euo pipefail\nprintf "%s" "$v" | grep -q X && echo mal\n' },
  { nombre: 'set -u -o pipefail (otra opcion delante)', debe: true,
    texto: 'set -u -o pipefail\nout=$(cmd)\nprintf "%s" "$out" | grep -q "FALLO" && mal\n' },
  { nombre: 'pipefail en bash -o + grep -qF', debe: true,
    texto: '#!/bin/bash\nbash -o pipefail -c x\ncat f | grep -qF -- "$t"\n' },
  { nombre: 'pipefail + grep -E -q separado', debe: true,
    texto: 'set -o pipefail\ngit show HEAD | grep -E -q "^x"\n' },
  { nombre: 'sin pipefail: grep -q en tuberia es correcto', debe: false,
    texto: 'set -u\nprintf "%s" "$v" | grep -q X\n' },
  { nombre: 'pipefail + here-string (la forma buena)', debe: false,
    texto: 'set -o pipefail\ngrep -q X <<< "$v"\n' },
  { nombre: 'pipefail solo en un comentario', debe: false,
    texto: '# aqui NO va set -o pipefail\nprintf x | grep -q x\n' },
];
function autotest() {
  let ok = 0, mal = 0;
  for (const c of CASOS) {
    const r = mira(c.texto).mal;
    if (r === c.debe) ok++; else { mal++; console.log(`  MAL autotest: ${c.nombre} (esperaba ${c.debe}, salio ${r})`); }
  }
  console.log(`  autotest: ${ok} OK · ${mal} MAL`);
  return mal === 0;
}

// ── barrido ──────────────────────────────────────────────────────────────────
const args = process.argv.slice(2);
const soloAuto = args.includes('--solo-autotest');
const raiz = args.find(a => !a.startsWith('--'));
if (!autotest()) { console.log('\n  NO MEDIDO: el autotest no pasa, asi que este barrido no se puede creer.'); process.exit(3); }
if (soloAuto) { console.log('\n  autotest PASA.'); process.exit(0); }
if (!raiz || !fs.existsSync(raiz)) { console.error('uso: node pipefail-guard.js <dir>'); process.exit(2); }

let ficheros;
try {
  ficheros = execFileSync('git', ['-C', raiz, 'ls-files', '--cached', '--others', '--exclude-standard'],
                          { encoding: 'utf8' }).split('\n').filter(f => /\.(sh|bash)$/.test(f));
} catch (e) {
  console.log('  NO MEDIDO: no puedo listar los ficheros con git: ' + e.message); process.exit(3);
}
if (!ficheros.length) { console.log('  NO MEDIDO: 0 guiones .sh en ' + raiz + ' (no es un barrido limpio, es uno vacio)'); process.exit(3); }

const hallazgos = [];
let conGrepq = 0;
for (const f of ficheros) {
  let t; try { t = fs.readFileSync(path.join(raiz, f), 'utf8'); } catch (e) { continue; }
  const r = mira(t);
  if (r.grepq.length) conGrepq++;
  if (r.mal) hallazgos.push(`  ${f}: pipefail en la linea ${r.activa.join(',')} y \`| grep -q\` en ${r.grepq.join(',')}`);
}
console.log(`\nbarridos ${ficheros.length} guiones · ${conGrepq} llevan \`| grep -q\` · con pipefail ademas: ${hallazgos.length}`);
if (hallazgos.length) {
  console.log(hallazgos.join('\n'));
  console.log('\n  FALLA: con pipefail, `| grep -q` da 141 por encima de ~64 KB. Usar `grep -q X <<< "$v"`.');
  process.exit(1);
}
console.log('\n  PASA · ningun guion junta pipefail con `| grep -q`.');
process.exit(0);
