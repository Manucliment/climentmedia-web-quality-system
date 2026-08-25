/* ===========================================================================
 *  forms-gate.js — GATE del PASO 10: el formulario, mirado en el DOM
 * ===========================================================================
 *  Se ejecuta con `references/run-gate.js` -- que vive EN LA SKILL y se empuja
 *  al servidor en cada corrida-- o se pega en la consola del navegador.
 *  Devuelve VEREDICTO: PASA o FALLA. Hermano de `structure-gate.js` (si esta
 *  maquetado) y `measure-screens.js` (cuanto ocupa y donde caen los CTAs).
 *
 *  POR QUE EXISTE
 *  --------------
 *  17-ago-2026. De los 15 pasos de `16-revision-paso-a-paso.md`, CUATRO no los
 *  miraba ningun programa, y **todos los defectos que encontro Manuel este mes
 *  caen en uno de esos cuatro**. El paso 10 es el unico de los cuatro que
 *  pierde clientes de verdad, asi que es el primero que deja de ser promesa.
 *
 *  LOS TRES DEFECTOS REALES QUE LO MOTIVAN, y cada uno es un check
 *  --------------------------------------------------------------
 *  1 · site-d: **el campo CEPO se veia en pantalla.** El <form> llevaba
 *      `class="lead"`, que en esa hoja es la ENTRADILLA -un parrafo-, asi que
 *      buscar `.lead` en el CSS devolvia una regla y parecia estilado. Sin CSS
 *      propio se pintaba un input que pone literalmente «No rellenar». Un cepo
 *      para robots que un humano ve, lee y rellena: cuando lo hace, **su
 *      solicitud se descarta en silencio**. Es de las pocas cosas que pierde
 *      pacientes sin dejar rastro en ningun sitio.  -> F3
 *  2 · Su web original enviaba por `mailto:`, que abre el cliente de correo del
 *      visitante y no manda nada si no tiene uno configurado.  -> F4
 *  3 · site-a: el formulario **mostraba exito** con el CRM de destino dado de
 *      baja. Nada en el DOM lo delata.  -> F10, y por eso F10 es una NOTA y no
 *      un aprobado: este gate NO PUEDE decir que el correo llega.
 *
 *  LO QUE ESTE GATE NO VE, DICHO
 *  -----------------------------
 *  · **Si el correo LLEGA.** Ningun programa que mire el DOM puede saberlo, y
 *    es el unico defecto de esta lista que ya nos costo un cliente sin avisar.
 *    Se declara en `notas` como NO VERIFICADO, con el gesto exacto que lo
 *    cierra. No verificado NO es aprobado (regla 10 del instrumento).
 *  · **La guarda de doble envio**, salvo que el formulario la declare: medirla
 *    de verdad exige ENVIAR DOS VECES, y eso en una web de cliente viva son dos
 *    correos reales y dos conversiones de mas en su cuenta de Ads.
 *  · Si los textos tienen sentido. El gate dice donde mirar.
 *
 *  CONFIGURACION (window.__GATE__, opcional)
 *  -----------------------------------------
 *  { exigeFormulario: true,          // FALLA si la pagina no tiene ninguno
 *    politica: '/politica-privacidad/'  // ruta que debe enlazar el consentimiento
 *  }
 * ========================================================================== */
(() => {
const CFG = (typeof window !== 'undefined' && window.__GATE__) || {};
const fallos = [], avisos = [], notas = [];

/* ---------- utilidades ---------------------------------------------------- */
// Visibilidad MEDIDA, no deducida del marcado. Es la regla de la casa: un
// `[hidden]` bien puesto se veia igual porque `display:flex` lo anulaba.
const seVe = (e) => {
  if (!e) return false;
  const r = e.getBoundingClientRect();
  const cs = getComputedStyle(e);
  return r.width > 1 && r.height > 1 &&
         r.right > -500 && r.left < innerWidth + 500 &&   // fuera de pantalla = escondido
         cs.display !== 'none' && cs.visibility !== 'hidden' &&
         parseFloat(cs.opacity) > 0.01;
};
const texto = (e) => (e && e.textContent || '').replace(/\s+/g, ' ').trim();
const señas = (c) => [c.name, c.id, c.className, c.getAttribute('autocomplete')]
                     .filter(Boolean).join(' ').toLowerCase();

// La etiqueta de un campo, por las CUATRO vias validas. El `placeholder` NO es
// una de ellas: desaparece al escribir y los lectores de pantalla no lo anuncian
// como nombre en todos los navegadores.
const etiquetaDe = (c) => {
  if (c.getAttribute('aria-label')) return c.getAttribute('aria-label').trim();
  const by = c.getAttribute('aria-labelledby');
  if (by) {
    const t = by.split(/\s+/).map(id => texto(document.getElementById(id))).join(' ').trim();
    if (t) return t;
  }
  if (c.id) { const l = document.querySelector(`label[for="${CSS.escape(c.id)}"]`); if (l) return texto(l); }
  const env = c.closest('label');
  if (env) return texto(env);
  return null;
};

/* ---------- F1 · hay formulario ------------------------------------------- */
const forms = [...document.querySelectorAll('form')];
if (!forms.length) {
  if (CFG.exigeFormulario) {
    fallos.push('F1 · esta pagina deberia tener formulario y no tiene ninguno');
  } else {
    notas.push('F1 · la pagina no tiene formulario; el resto de checks no aplica');
  }
  return JSON.stringify({ innerWidth, VEREDICTO: fallos.length ? 'FALLA' : 'PASA',
                          formularios: 0, fallos, avisos, notas }, null, 1);
}

const detalle = [];
forms.forEach((f, i) => {
  const ref = f.id || f.getAttribute('name') || f.getAttribute('data-form') || `#${i + 1}`;
  const campos = [...f.querySelectorAll('input, textarea, select')]
                 .filter(c => !/^(submit|button|image|reset)$/i.test(c.type));

  /* ---------- F3 · el CEPO no se ve ------------------------------------- */
  // Se busca por TRES vias porque los cepos no se llaman igual en dos sitios:
  // por el nombre del campo, por lo que dice su etiqueta, y por el marcado de
  // ocultacion accesible. Con una sola via, el de site-d -que se llamaba
  // `website`- no habria salido.
  const esCepo = (c) => {
    const s = señas(c);
    if (/trap|honey|hp_|_hp\b|nofill|no-rellenar|bot-?field/.test(s)) return true;
    if (/^website$|^url$|^fax$/.test(c.name || '')) return true;   // clasicos de cepo
    const l = (etiquetaDe(c) || '').toLowerCase();
    if (/no\s+rellenar|ne\s+pas\s+remplir|do\s+not\s+fill|leave\s+(this\s+)?blank/.test(l)) return true;
    if (c.getAttribute('aria-hidden') === 'true') return true;
    if (c.tabIndex === -1 && c.type !== 'hidden') return true;
    return false;
  };
  const cepos = campos.filter(esCepo);
  cepos.forEach(c => {
    const cs = getComputedStyle(c);
    const etq = c.id ? document.querySelector(`label[for="${CSS.escape(c.id)}"]`) : null;
    if (seVe(c) || (etq && seVe(etq))) {
      fallos.push(`F3 · el campo CEPO "${c.name || c.id}" SE VE en ${ref} ` +
                  `(${seVe(c) ? 'el campo' : 'su etiqueta'}). Un humano lo rellena y su ` +
                  `solicitud se descarta en silencio`);
    } else if (cs.display === 'none') {
      // No es un fallo, es un aviso con motivo: hay bots que se saltan los
      // campos con display:none, y entonces el cepo deja de cazar. Se esconde
      // con posicion fuera de pantalla.
      avisos.push(`F3 · el cepo "${c.name || c.id}" de ${ref} usa display:none; ` +
                  `hay bots que ignoran esos campos. Mejor fuera de pantalla`);
    }
  });

  /* ---------- F2 · cada campo con etiqueta ------------------------------ */
  const reales = campos.filter(c => !esCepo(c) && c.type !== 'hidden');
  const sinEtiqueta = reales.filter(c => !etiquetaDe(c));
  if (sinEtiqueta.length) {
    fallos.push(`F2 · ${sinEtiqueta.length} campo(s) sin etiqueta en ${ref}: ` +
                sinEtiqueta.map(c => c.name || c.type).join(', ') +
                ' · el placeholder NO cuenta: desaparece al escribir');
  }

  /* ---------- F8 · un `required` invisible bloquea sin explicar ---------- */
  const reqInvisible = reales.filter(c => c.required && !seVe(c));
  if (reqInvisible.length) {
    fallos.push(`F8 · ${reqInvisible.length} campo(s) OBLIGATORIOS e invisibles en ${ref}: ` +
                reqInvisible.map(c => c.name || c.type).join(', ') +
                ' · el navegador se niega a enviar y no ensena por que');
  }

  /* ---------- F4 · el destino resuelve ---------------------------------- */
  const action = (f.getAttribute('action') || '').trim();
  if (/^mailto:/i.test(action)) {
    fallos.push(`F4 · ${ref} envia por mailto: abre el cliente de correo del ` +
                `visitante y no manda NADA si no tiene uno configurado`);
  } else if (!action || action === '#' || /^javascript:/i.test(action)) {
    // Sin `action` puede ser legitimo si lo maneja JS; no se aprueba, se declara.
    if (!f.getAttribute('data-envio-js')) {
      avisos.push(`F4 · ${ref} no declara action (="${action}"). Si lo envia JS, ` +
                  `marcarlo con data-envio-js para que esto deje de avisar`);
    }
  }

  /* ---------- F5 · boton de envio de verdad ----------------------------- */
  const submit = f.querySelector('button[type="submit"], input[type="submit"], button:not([type])');
  if (!submit) {
    fallos.push(`F5 · ${ref} no tiene boton de envio real (button[type=submit] o ` +
                `input[type=submit]). Con un <div> o un <a>, quien usa teclado no puede enviar`);
  } else if (!seVe(submit)) {
    fallos.push(`F5 · el boton de envio de ${ref} NO SE VE`);
  }

  /* ---------- F6 · consentimiento cuando se piden datos personales ------ */
  const pidePersonales = reales.some(c => /email|tel|phone|telefono|nombre|name/.test(señas(c)) ||
                                          /^(email|tel)$/i.test(c.type));
  const checks = reales.filter(c => c.type === 'checkbox');
  const consent = checks.find(c => {
    const l = (etiquetaDe(c) || '').toLowerCase();
    return /privacidad|proteccion de datos|rgpd|gdpr|politica|confidentialit|privacy|termos|termes/.test(l);
  });
  if (pidePersonales && !consent) {
    fallos.push(`F6 · ${ref} pide datos personales y no tiene casilla de consentimiento ` +
                `con enlace a la politica de privacidad`);
  } else if (consent) {
    const cont = consent.closest('label') || consent.parentElement;
    const enlace = cont && cont.querySelector('a[href]');
    if (!enlace) {
      fallos.push(`F6 · la casilla de consentimiento de ${ref} no ENLAZA la politica; ` +
                  `nombrarla sin enlazarla no es informar`);
    } else if (CFG.politica && !enlace.getAttribute('href').includes(CFG.politica)) {
      avisos.push(`F6 · el consentimiento de ${ref} enlaza "${enlace.getAttribute('href')}" ` +
                  `y se esperaba "${CFG.politica}"`);
    }
  }

  /* ---------- F7 · alguna via de respuesta ------------------------------ */
  const viaRespuesta = reales.some(c => c.type === 'email' || c.type === 'tel' ||
                                        /email|correo|tel|phone|telefono/.test(señas(c)));
  if (!viaRespuesta) {
    fallos.push(`F7 · ${ref} no recoge ninguna via para contestar (ni correo ni telefono)`);
  }

  /* ---------- F9 · guarda de doble envio: se DECLARA o no se sabe ------- */
  if (!f.getAttribute('data-guarda-doble') && submit && !submit.disabled) {
    notas.push(`F9 · ${ref}: la guarda de DOBLE ENVIO no esta verificada. Medirla ` +
               `de verdad exige enviar dos veces, y en una web viva son dos correos ` +
               `reales al cliente y una conversion de mas en su cuenta de Ads. Si el ` +
               `formulario la tiene, declararlo con data-guarda-doble="si"`);
  }

  detalle.push({
    ref, campos: reales.length, cepos: cepos.length,
    action: action || '(sin action)',
    consentimiento: !!consent, botonEnvio: !!submit,
  });
});

/* ---------- F10 · el correo, que es lo unico que importa de verdad -------- */
notas.push('F10 · NO VERIFICADO y no lo puede verificar ningun gate de DOM: ' +
           'QUE EL CORREO LLEGUE. En site-a el formulario mostraba EXITO con el CRM ' +
           'de destino dado de baja. Se cierra a mano: enviar uno de prueba por ' +
           'CADA via declarada y comprobar el mensaje recibido (05-formularios.md)');

return JSON.stringify({
  innerWidth,                       // ⚠️ COMPROBAR ESTE PRIMERO
  VEREDICTO: fallos.length ? 'FALLA' : 'PASA',
  formularios: forms.length,
  detalle,
  fallos,
  avisos,
  notas,
}, null, 1);
})()
