// =============================================================================
//  repoint-rule-docs.js · repunta el campo `doc` del catalogo a rutas VIVAS
// =============================================================================
//  2-sep-2026. Medido: 235 de las 256 reglas de standard-rules.json declaraban
//  un `doc` que NO EXISTE. Son los nombres de antes de la unificacion al ingles
//  del 25-ago: `09-tipos-de-pagina.md`, `14-accesibilidad.md`, `02-diseno.md`...
//  El renombrado fue de todo el repo y el catalogo se quedo atras.
//
//  🔴 POR QUE IMPORTA, y no es cosmetico: `rule-instrument-index.pl` AGRUPA POR
//     `doc` las reglas que no tiene ningun instrumento -- o sea, el indice que
//     dice «esta regla no la mide nadie, leela aqui» mandaba a 235 ficheros que
//     no existen. Un puntero muerto en un indice no da error: manda a la nada y
//     el que lo sigue concluye que la regla no esta documentada.
//
//  🔑 EL MAPEO NO SE INVENTA: cada destino se comprueba contra el disco antes
//     de escribir, y si UNO solo no resuelve, no se escribe NADA. Un repunte a
//     medias deja el catalogo peor que antes, porque mezcla rutas vivas y
//     muertas y ya no se puede distinguir cual es cual de un vistazo.
//
//  Se ejecuta UNA vez. Es idempotente: sobre un catalogo ya repuntado no
//  encuentra nada que cambiar y lo dice.
const fs = require('fs'), path = require('path');
const DIR = __dirname;
const RAIZ = path.join(DIR, '..');
const CAT = path.join(DIR, 'standard-rules.json');

// Nombre de antes de la unificacion -> ruta viva, relativa a la raiz del repo.
// Los dos ultimos NO son un simple renombrado de idioma y por eso se anotan:
// el de QA final se movio a checklists/ y el de trampas a docs/.
const MAPA = {
  '00-intake.md':                                     'blueprint/00-intake.md',
  '01-origen.md':                                     'blueprint/01-source.md',
  '02-diseno.md':                                     'blueprint/02-design.md',
  '03-contenido-y-seo.md':                            'blueprint/03-content-and-seo.md',
  '04-medicion.md':                                   'blueprint/04-measurement.md',
  '05-formularios.md':                                'blueprint/05-forms.md',
  '06-publicar.md':                                   'blueprint/06-publishing.md',
  '07-trampas.md':                                    'docs/traps.md',
  '08-qa-final.md':                                   'checklists/final-qa.md',
  '09-tipos-de-pagina.md':                            'blueprint/09-page-types.md',
  '10-vocabulario-de-maqueta.md':                     'blueprint/10-layout-vocabulary.md',
  '11-medidas.md':                                    'blueprint/11-measurements.md',
  '12-enlazado-interno.md':                           'blueprint/12-internal-linking.md',
  '13-rendimiento.md':                                'blueprint/13-performance.md',
  '14-accesibilidad.md':                              'blueprint/14-accessibility.md',
  '15-estados-y-contenido-real.md':                   'blueprint/15-real-content-states.md',
  'web-quality-system/gates/18-estandar-de-pagina.md': 'blueprint/18-page-standard.md',
};

const j = JSON.parse(fs.readFileSync(CAT, 'utf8'));

// ── 1 · TODO destino del mapeo tiene que existir, ANTES de tocar nada ────────
const rotos = Object.entries(MAPA).filter(([, d]) => !fs.existsSync(path.join(RAIZ, d)));
if (rotos.length) {
  console.error('  FALLO: el mapeo apunta a ficheros que no existen:');
  for (const [v, d] of rotos) console.error('    ' + v + ' -> ' + d);
  process.exit(2);
}

// ── 2 · repuntar ────────────────────────────────────────────────────────────
let cambiadas = 0, yaVivas = 0;
const sinMapa = new Map();
for (const r of j.reglas) {
  const d = String(r.doc || '');
  if (MAPA[d]) { r.doc = MAPA[d]; cambiadas++; continue; }
  if (fs.existsSync(path.join(RAIZ, d))) { yaVivas++; continue; }
  sinMapa.set(d, (sinMapa.get(d) || 0) + 1);
}

// ── 3 · nada a medias: si queda una sola sin resolver, no se escribe ─────────
if (sinMapa.size) {
  console.error('  FALLO: quedan `doc` que no resuelven y no estan en el mapeo:');
  for (const [d, n] of sinMapa) console.error('    ' + String(n).padStart(4) + '  ' + d);
  console.error('  No se ha escrito nada. Anade su destino al MAPA o corrige el catalogo.');
  process.exit(1);
}

// ── 4 · releer del disco y CONTAR, que el programa diga que escribio no basta ─
if (cambiadas) fs.writeFileSync(CAT, JSON.stringify(j, null, 2), 'utf8');
const rel = JSON.parse(fs.readFileSync(CAT, 'utf8'));
const muertas = rel.reglas.filter(r => !fs.existsSync(path.join(RAIZ, String(r.doc || ''))));
if (muertas.length) {
  console.error('  FALLO releido: ' + muertas.length + ' reglas siguen con `doc` muerto');
  process.exit(1);
}
console.log('  repuntadas: ' + cambiadas + ' · ya vivas: ' + yaVivas +
            ' · total ' + rel.reglas.length);
console.log('  releido del disco: las ' + rel.reglas.length + ' resuelven a un fichero real');
