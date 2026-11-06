// =============================================================================
//  BOTONES ENTRE PAGINAS  ·  6-nov-2026
//  node gates/botones-sitio.js <salida de run-gate con botones-gate.js>…
// =============================================================================
//
//  `botones-gate.js` mira los botones de UNA pagina. El 2-nov los cinco estilos
//  de boton de una web estaban repartidos: cada pagina, sola, podia ser
//  coherente y el sitio no. Esto junta la `datos.lista` de varias salidas (por
//  ancho) y les pasa LA MISMA comparacion (`compara`, del propio gate: una sola
//  copia de la regla). Solo cuenta lo que sale al juntarlas: lo que ya falla en
//  una pagina sola lo dice esa pagina.
//
//  Una salida que no vale (sin el JSON del gate, `coincide` false, `sospechoso`,
//  sin `lista`) no se junta y se nombra: NO MEDIDO, no PASA. Con menos de dos
//  paginas validas en un ancho, ese ancho es NO MEDIDO.
//
//  Imprime una linea por hallazgo y al final `VEREDICTO PASA | FALLA | NO MEDIDO`.
//  Sale con 0 (PASA), 1 (FALLA) o 3 (NO MEDIDO). La puerta lo corre sobre las
//  paginas que mide; un barrido de todo el sitio, sobre las que se le den.
// =============================================================================
const fs = require('fs');
const path = require('path');
const { compara } = require(path.join(__dirname, 'botones-gate.js'));

const lee = (f) => {
  let t; try { t = fs.readFileSync(f, 'utf8'); } catch (e) { return { f, mal: 'no se lee el fichero' }; }
  const lineas = t.split('\n');
  let diag = {}; try { diag = JSON.parse(lineas[0]); } catch (e) { /* abajo */ }
  let g = null; try { g = JSON.parse(lineas.slice(1).join('\n')); } catch (e) { /* abajo */ }
  if (!g || !g.VEREDICTO) return { f, mal: 'sin el JSON del gate' };
  if (diag.sospechoso) return { f, mal: 'no parece la pagina (sospechoso)' };
  if (g.coincide !== true || (diag.coincide !== undefined && diag.coincide !== true)) return { f, mal: 'el ancho no coincide' };
  if (!g.datos || !Array.isArray(g.datos.lista)) return { f, mal: 'sin datos.lista (¿otro gate o una version vieja?)' };
  let ruta = g.url || diag.url || f; try { ruta = new URL(ruta).pathname; } catch (e) { /* se queda */ }
  return { f, ruta, ancho: g.innerWidth, lista: g.datos.lista, fallos: g.fallos || [] };
};

if (require.main === module) {
  const fich = process.argv.slice(2);
  if (!fich.length) { console.error('uso: node gates/botones-sitio.js <salida.out>…'); process.exit(2); }
  const ok = [], malas = [];
  for (const f of fich) { const r = lee(f); (r.mal ? malas : ok).push(r); }
  for (const m of malas) console.log(`  NO MEDIDO  ${path.basename(m.f)}: ${m.mal}`);
  let fallaAlgo = false, medido = false;
  for (const ancho of [...new Set(ok.map((r) => r.ancho))].sort((a, b) => b - a)) {
    const paginas = ok.filter((r) => r.ancho === ancho);
    if (paginas.length < 2) { console.log(`  ${ancho} px: NO MEDIDO entre paginas (1 pagina valida: ${paginas[0].ruta})`); continue; }
    medido = true;
    // Lo que ya falla en una pagina sola, por su clave: eso lo dice el gate de esa pagina.
    const solas = new Set();
    for (const p of paginas) for (const x of compara(p.lista, ancho).fallos) solas.add(x.regla + ' ' + x.clave);
    const juntas = paginas.flatMap((p) => p.lista.map((b) => ({ ...b, texto: `${b.texto} · ${p.ruta}` })));
    const nuevos = compara(juntas, ancho).fallos.filter((x) => !solas.has(x.regla + ' ' + x.clave));
    console.log(`  ${ancho} px: ${paginas.length} paginas, ${juntas.length} botones · ${nuevos.length ? nuevos.length + ' FALLA entre paginas' : 'PASA entre paginas'}`);
    for (const x of nuevos) console.log(`    ${x.msg.replace(/^(BT\d) ·/, '$1 (entre paginas) ·')}`);
    if (nuevos.length) fallaAlgo = true;
  }
  const v = fallaAlgo ? 'FALLA' : medido ? 'PASA' : 'NO MEDIDO';
  console.log(`VEREDICTO ${v}`);
  process.exit(v === 'PASA' ? 0 : v === 'FALLA' ? 1 : 3);
}
module.exports = { lee };
