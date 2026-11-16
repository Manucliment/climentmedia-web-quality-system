<?php
/* =============================================================================
 *  form-handler.php — receptor de formulario para webs de cliente
 * =============================================================================
 *  Sustituye a los iframes de CRM (GoHighLevel/LeadConnector, Typeform...) que
 *  se quedan puestos cuando el cliente da de baja la herramienta y siguen
 *  recogiendo datos QUE NO LLEGAN A NADIE. Es el fallo mas caro que hemos
 *  encontrado en webs de cliente: no da error, y cada persona que rellena cree
 *  que ha contactado.
 *
 *  POR QUE PHP Y NO UN SERVICIO DE FORMULARIOS
 *   · Cero terceros: nada que declarar en la politica de cookies
 *   · Remitente y destinatario comparten dominio -> SPF alineado -> no spam
 *   · Es lo que el cliente YA paga en su hosting compartido
 *
 *  CONFIGURAR: las constantes de arriba y FIELDS. Nada mas.
 *  ⚠️ Comprobar antes que el plan tiene PHP: si /index.php da 404, no lo tiene.
 *
 *  LA FICHA DE LEAD (16-nov-2026 · blueprint/05-forms.md, «The lead card»)
 *  Un aviso que dice «Nombre, Email, ver el panel» no se puede atender desde el
 *  movil: en una web real el dueno recibio un nombre y un correo y tuvo que
 *  sacar de la analitica, dos dias despues, de que web venia y que queria. El
 *  formulario mandaba el mensaje y la pagina; el aviso no los imprimia. Desde
 *  hoy el aviso abre con tres bloques, en este orden:
 *    1 · QUE BUSCA     la opcion que marco y las ~20 primeras palabras del
 *                      mensaje; debajo, TODOS los campos con la etiqueta que vio
 *    2 · DONDE ESTABA  la pagina (titulo y ruta), el bloque que abrio el
 *                      formulario (data-cta) y la pagina anterior del sitio
 *    3 · COMO LLEGO    en palabras: Google Ads, Meta, Google organico, directo...
 *  Despues, quien es y como contestarle; al pie, la web, la referencia y la hoja.
 *  El asunto es el triaje: «[web] <que busca, ≤ 8 palabras> · <como llego>».
 *
 *  PRIMERA FASE: no se guarda NADA en el navegador. Solo lo que hay en el
 *  momento del envio: la pagina, data-cta, document.referrer y los parametros
 *  de la URL. Asi no hace falta consentimiento ni una linea nueva en la
 *  politica. La pagina de entrada y las paginas vistas salen NO MEDIDO hasta la
 *  segunda fase (sessionStorage, solo con consentimiento de analitica, y solo
 *  donde la politica ya lo cubra): entonces el formulario manda `landing` y
 *  `pages`, y este fichero ya los imprime.
 *
 *  LO QUE PONE EL FORMULARIO (campos ocultos, rellenados al enviar):
 *    <form method="post" action="/contact.php" data-cta="hero">
 *      <input type="hidden" name="page">  <input type="hidden" name="ref">
 *      <input type="hidden" name="qs">    <input type="hidden" name="cta">
 *      <input type="hidden" name="lang">  <input type="hidden" name="title">
 *      <input type="hidden" name="ts">    <!-- Math.floor(Date.now()/1000) al cargar -->
 *    <script>
 *    document.addEventListener('submit', function (e) {
 *      var f = e.target, b = f.closest('[data-cta]');
 *      var set = function (n, v) { var i = f.querySelector('input[name="' + n + '"]'); if (i) i.value = v || ''; };
 *      set('page', location.pathname); set('ref', document.referrer); set('qs', location.search);
 *      set('cta', b && b.getAttribute('data-cta')); set('lang', document.documentElement.lang);
 *      set('title', document.title);
 *    }, true);
 *    </script>
 *  Un campo oculto que falte no rompe nada: su linea sale NO MEDIDO.
 *
 *  SE PRUEBA DE VERDAD: al subir, un envio desde una URL con
 *  `?utm_source=prueba` y con la cookie de prueba (TEST_KEY_SHA256). Se lee el
 *  aviso que llega (tres bloques y asunto) y su UID o captura va a la fila de
 *  seguimiento. Sin eso, la linea es NO VERIFICADO.
 *
 *  Banco: form-handler-tests/tests.sh (en el host de medida, con php -S local y
 *  el correo a un fichero: no sale ninguno).
 * ========================================================================== */

// 🔴 18-ago-2026 · ESTOS VALORES NO PUEDEN PARECER BUENOS. Antes ponia
// `contact@ejemplo.tld`, que es una direccion con forma de direccion: copiar
// esta plantilla sin tocarla ponia en VERDE el check INT-02 de audit-vs-spec.pl
// — el check que existe precisamente porque el formulario de Site A
// llevaba meses enviando a un CRM dado de baja. La plantilla aprobaba el
// examen que la plantilla venia a suspender.
const MAIL_TO      = 'RELLENAR@ejemplo.tld';      // destino de los avisos
const MAIL_FROM    = 'RELLENAR@ejemplo.tld';      // buzon del MISMO dominio
const SITE_NAME    = 'RELLENAR nombre del cliente';
const SITE_HOST    = 'RELLENAR.ejemplo.tld';      // el dominio, sin www: separa la pagina anterior del sitio de un referrer externo
const THANKS_URL   = '/merci';                    // pagina de gracias que ya existe
const LOG_DIR      = __DIR__ . '/../_leads';      // FUERA del directorio publico
const DOCROOT      = __DIR__;                     // donde estan los .html servidos (para leer el <title> de la pagina)
const ALERT_LANG   = 'es';                        // es | fr | en | nl: el idioma del BUZON que lo recibe, no el de la web
const TIMEZONE     = 'Europe/Madrid';             // la hora local del aviso
const SHEET_URL    = '';                          // la hoja o el CRM donde vive el lead, si lo hay (va al pie)

// Modo prueba. Con la cookie `fh_test` cuyo sha256 es TEST_KEY_SHA256, el aviso va
// SOLO a TEST_TO, el asunto y la linea del disco llevan TEST y la respuesta es un
// 200 sin la pagina de gracias: ni conversion en las campanas ni correo al cliente.
// La clave no va en el repo (solo su sha256). Vacio = sin modo prueba: el envio de
// prueba llega a MAIL_TO y se avisa al cliente antes.
const TEST_KEY_SHA256 = '';
const TEST_TO         = '';

// Y si aun asi sube sin configurar, no finge que funciona. Contestar 200 sin
// buzon es el defecto entero: nadie se entera hasta que el cliente pregunta por
// que no le llegan clientes.
foreach (['MAIL_TO' => MAIL_TO, 'MAIL_FROM' => MAIL_FROM, 'SITE_NAME' => SITE_NAME, 'SITE_HOST' => SITE_HOST] as $k => $v) {
    if (strpos($v, 'RELLENAR') !== false || strpos($v, 'ejemplo.tld') !== false) {
        http_response_code(500);
        header('Content-Type: text/plain; charset=utf-8');
        exit("form-handler.php sin configurar: $k sigue con el valor de la plantilla.");
    }
}

// --- campos: nombre del input => la etiqueta QUE VE EL VISITANTE --------------
// Ajustar al formulario real. El orden aqui es el orden del aviso.
const FIELDS = [
    'name'    => 'Nombre',
    'phone'   => 'Telefono',
    'email'   => 'Email',
    'address' => 'Direccion',
    'city'    => 'Municipio',
    'need'    => 'Necesidad',
    'message' => 'Mensaje',
];
const REQUIRED      = ['name', 'phone', 'email', 'city'];
const WANT_FIELDS   = ['need', 'city'];  // la opcion que marco (servicio, plan, zona): abre «Que busca» y el asunto
const MESSAGE_FIELD = 'message';
const FORM_NAME     = 'contacto';        // lo que dice «Que busca» si no marco nada ni escribio
// Lo que manda el formulario y no es una respuesta del visitante. Todo lo demas
// que llegue y no este en FIELDS va a «Otros campos»: nunca se pierde.
const TECH_FIELDS = ['page', 'ref', 'qs', 'cta', 'lang', 'title', 'ts', 'website', 'consent', 'landing', 'pages',
    'consent_analytics', 'gclid', 'gbraid', 'wbraid', 'fbclid', 'msclkid'];

// --- textos del aviso, en el idioma del buzon ---------------------------------
const T = [
  'es' => ['want' => 'QUÉ BUSCA', 'where' => 'DÓNDE ESTABA', 'how' => 'CÓMO LLEGÓ', 'who' => 'QUIÉN ES Y CÓMO CONTESTARLE',
    'fields' => 'Lo que rellenó', 'other' => 'Otros campos', 'page' => 'Página', 'block' => 'Bloque del formulario',
    'prev' => 'Página anterior', 'landing' => 'Página de entrada de la visita', 'nm' => 'NO MEDIDO',
    'nm_cta' => 'el formulario no lleva data-cta', 'nm_phase' => 'no se guarda nada en el navegador',
    'nm_consent' => 'sin consentimiento de analítica', 'pages_seen' => 'páginas vistas',
    'prev_none' => 'ninguna (entró directamente en esta página)', 'prev_ext' => 'ninguna en la web (venía de %s)',
    'ads' => 'Google Ads (clic en un anuncio)', 'ms' => 'Microsoft Ads (clic en un anuncio)', 'meta' => 'Meta (Facebook o Instagram)',
    'meta_link' => 'Meta (enlace, sin anuncio)', 'camp' => 'campaña', 'tagged' => 'Enlace marcado', 'org' => 'Google orgánico',
    'bing' => 'Bing orgánico', 'ai' => 'Asistente de IA', 'other_site' => 'otro', 'direct' => 'directo',
    'direct_long' => 'Directo (dirección escrita, favorito o enlace fuera del navegador)',
    'unknown' => 'desconocido', 'unknown_long' => 'Desconocido: la visita empezó en otra página del sitio, y la página de entrada no se guarda',
    'reply' => 'Contestar: responder a este correo (va a %s)', 'reply_phone' => 'Contestar: llamar al %s',
    'lang' => 'idioma de la página', 'device' => 'dispositivo', 'mobile' => 'móvil', 'tablet' => 'tablet',
    'desktop' => 'escritorio', 'dev_unknown' => 'desconocido', 'received' => 'Recibido el %s (hora local)',
    'site' => 'Web', 'ref' => 'ref.', 'sheet' => 'Hoja', 'test' => '*** PRUEBA TÉCNICA: no es un cliente, no hay nada que hacer. ***'],
  'fr' => ['want' => 'CE QU\'IL CHERCHE', 'where' => 'OÙ IL ÉTAIT', 'how' => 'COMMENT IL EST ARRIVÉ', 'who' => 'QUI ET COMMENT RÉPONDRE',
    'fields' => 'Ce qu\'il a rempli', 'other' => 'Autres champs', 'page' => 'Page', 'block' => 'Bloc du formulaire',
    'prev' => 'Page précédente', 'landing' => 'Page d\'entrée de la visite', 'nm' => 'NON MESURÉ',
    'nm_cta' => 'le formulaire n\'a pas de data-cta', 'nm_phase' => 'rien n\'est gardé dans le navigateur',
    'nm_consent' => 'sans consentement analytique', 'pages_seen' => 'pages vues',
    'prev_none' => 'aucune (arrivé directement sur cette page)', 'prev_ext' => 'aucune sur le site (venait de %s)',
    'ads' => 'Google Ads (clic sur une annonce)', 'ms' => 'Microsoft Ads (clic sur une annonce)', 'meta' => 'Meta (Facebook ou Instagram)',
    'meta_link' => 'Meta (lien, sans annonce)', 'camp' => 'campagne', 'tagged' => 'Lien marqué', 'org' => 'Google naturel',
    'bing' => 'Bing naturel', 'ai' => 'Assistant IA', 'other_site' => 'autre', 'direct' => 'direct',
    'direct_long' => 'Direct (adresse tapée, favori ou lien hors navigateur)',
    'unknown' => 'inconnu', 'unknown_long' => 'Inconnu : la visite a commencé sur une autre page du site, et la page d\'entrée n\'est pas gardée',
    'reply' => 'Répondre : répondre à ce mail (va à %s)', 'reply_phone' => 'Répondre : appeler le %s',
    'lang' => 'langue de la page', 'device' => 'appareil', 'mobile' => 'mobile', 'tablet' => 'tablette',
    'desktop' => 'ordinateur', 'dev_unknown' => 'inconnu', 'received' => 'Reçu le %s (heure locale)',
    'site' => 'Site', 'ref' => 'réf.', 'sheet' => 'Feuille', 'test' => '*** TEST TECHNIQUE : pas un vrai client, rien à faire. ***'],
  'en' => ['want' => 'WHAT THEY WANT', 'where' => 'WHERE THEY WERE', 'how' => 'HOW THEY CAME', 'who' => 'WHO THEY ARE AND HOW TO REPLY',
    'fields' => 'What they filled in', 'other' => 'Other fields', 'page' => 'Page', 'block' => 'Form block',
    'prev' => 'Previous page', 'landing' => 'Landing page of the visit', 'nm' => 'NOT MEASURED',
    'nm_cta' => 'the form has no data-cta', 'nm_phase' => 'nothing is kept in the browser',
    'nm_consent' => 'no analytics consent', 'pages_seen' => 'pages seen',
    'prev_none' => 'none (came straight to this page)', 'prev_ext' => 'none on the site (came from %s)',
    'ads' => 'Google Ads (ad click)', 'ms' => 'Microsoft Ads (ad click)', 'meta' => 'Meta (Facebook or Instagram)',
    'meta_link' => 'Meta (link, no ad)', 'camp' => 'campaign', 'tagged' => 'Tagged link', 'org' => 'Google organic',
    'bing' => 'Bing organic', 'ai' => 'AI assistant', 'other_site' => 'other', 'direct' => 'direct',
    'direct_long' => 'Direct (typed address, bookmark or a link outside the browser)',
    'unknown' => 'unknown', 'unknown_long' => 'Unknown: the visit started on another page of the site, and the landing page is not kept',
    'reply' => 'Reply: answer this email (goes to %s)', 'reply_phone' => 'Reply: call %s',
    'lang' => 'page language', 'device' => 'device', 'mobile' => 'mobile', 'tablet' => 'tablet',
    'desktop' => 'desktop', 'dev_unknown' => 'unknown', 'received' => 'Received %s (local time)',
    'site' => 'Site', 'ref' => 'ref.', 'sheet' => 'Sheet', 'test' => '*** TECHNICAL TEST: not a real lead, nothing to do. ***'],
  'nl' => ['want' => 'WAT ZOEKT HIJ', 'where' => 'WAAR WAS HIJ', 'how' => 'HOE KWAM HIJ', 'who' => 'WIE EN HOE ANTWOORDEN',
    'fields' => 'Wat hij invulde', 'other' => 'Andere velden', 'page' => 'Pagina', 'block' => 'Formulierblok',
    'prev' => 'Vorige pagina', 'landing' => 'Instappagina van het bezoek', 'nm' => 'NIET GEMETEN',
    'nm_cta' => 'het formulier heeft geen data-cta', 'nm_phase' => 'er wordt niets in de browser bewaard',
    'nm_consent' => 'geen toestemming voor analytics', 'pages_seen' => 'pagina\'s bekeken',
    'prev_none' => 'geen (kwam direct op deze pagina)', 'prev_ext' => 'geen op de site (kwam van %s)',
    'ads' => 'Google Ads (klik op een advertentie)', 'ms' => 'Microsoft Ads (klik op een advertentie)', 'meta' => 'Meta (Facebook of Instagram)',
    'meta_link' => 'Meta (link, geen advertentie)', 'camp' => 'campagne', 'tagged' => 'Gemarkeerde link', 'org' => 'Google organisch',
    'bing' => 'Bing organisch', 'ai' => 'AI-assistent', 'other_site' => 'andere', 'direct' => 'direct',
    'direct_long' => 'Direct (getypt adres, bladwijzer of link buiten de browser)',
    'unknown' => 'onbekend', 'unknown_long' => 'Onbekend: het bezoek begon op een andere pagina van de site, en de instappagina wordt niet bewaard',
    'reply' => 'Antwoorden: beantwoord deze mail (gaat naar %s)', 'reply_phone' => 'Antwoorden: bel %s',
    'lang' => 'taal van de pagina', 'device' => 'apparaat', 'mobile' => 'mobiel', 'tablet' => 'tablet',
    'desktop' => 'computer', 'dev_unknown' => 'onbekend', 'received' => 'Ontvangen op %s (lokale tijd)',
    'site' => 'Site', 'ref' => 'ref.', 'sheet' => 'Sheet', 'test' => '*** TECHNISCHE TEST: geen echte lead, niets te doen. ***'],
];

// =============================================================================
header('X-Content-Type-Options: nosniff');
// `?? ''` y no acceso directo: sin el, cualquier invocacion sin REQUEST_METHOD
// -- la CLI, un cron, un healthcheck raro -- suelta un PHP Warning que acaba en
// el log de errores del cliente. Verificado ejecutandolo: el aviso salia.
if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') { http_response_code(405); exit('Method Not Allowed'); }

$L = T[ALERT_LANG] ?? T['es'];

function fail(string $msg, int $code = 400): void {
    http_response_code($code);
    header('Content-Type: text/plain; charset=utf-8');
    exit($msg);
}
function clean(string $s, int $max = 2000): string {
    // ⚠️ U+200B y demas invisibles: llegan de gente que copia y pega desde el
    // movil o desde un documento, y luego rompen filtros y automatizaciones EN
    // SILENCIO. Se limpian aqui, en la puerta, no despues.
    $s = preg_replace('/[\x{200B}-\x{200D}\x{FEFF}]/u', '', $s);
    $s = str_replace(["\r", "\n"], ' ', $s);          // corta inyeccion de cabeceras
    return trim(mb_substr($s, 0, $max));
}
function post(string $k, int $max = 2000): string { return is_string($_POST[$k] ?? null) ? clean($_POST[$k], $max) : ''; }
function words(string $s, int $n): string {
    $w = preg_split('/\s+/u', trim($s), -1, PREG_SPLIT_NO_EMPTY);
    return implode(' ', array_slice($w, 0, $n)) . (count($w) > $n ? '…' : '');
}

/* --- ANTI-SPAM sin CAPTCHA --------------------------------------------------
 * Un CAPTCHA es otro tercero y estorba justo al publico que mas nos interesa
 * (gente mayor, con prisa, en movil). Dos senales bastan para el 99 % del spam:
 *   1. campo trampa oculto que un humano nunca ve ni rellena
 *   2. tiempo minimo: los bots envian en menos de 2 segundos
 * -------------------------------------------------------------------------- */
if (!empty($_POST['website'] ?? '')) { header('Location: ' . THANKS_URL); exit; }  // trampa: se finge exito
$started = (int) ($_POST['ts'] ?? 0);
if ($started > 0 && (time() - $started) < 2) { fail('Envio demasiado rapido.', 422); }

// --- validacion --------------------------------------------------------------
$data = [];
foreach (FIELDS as $k => $label) { $data[$k] = post($k); }

foreach (REQUIRED as $k) {
    if ($data[$k] === '') { fail('Falta un campo obligatorio: ' . FIELDS[$k], 422); }
}
if (!filter_var($data['email'], FILTER_VALIDATE_EMAIL)) { fail('Email no valido.', 422); }
if (empty($_POST['consent'] ?? '')) { fail('Falta el consentimiento.', 422); }

$test = TEST_KEY_SHA256 !== '' && TEST_TO !== '' && is_string($_COOKIE['fh_test'] ?? null)
    && hash_equals(TEST_KEY_SHA256, hash('sha256', $_COOKIE['fh_test']));

// --- LA FICHA DE LEAD --------------------------------------------------------
// 1 · Que busca: la opcion que marco y el principio del mensaje.
$opcion = implode(' — ', array_filter(array_map(fn($k) => $data[$k] ?? '', WANT_FIELDS), 'strlen'));
$extracto = ($data[MESSAGE_FIELD] ?? '') !== '' ? words($data[MESSAGE_FIELD], 20) : '';
$busca = $opcion !== '' ? $opcion : ($extracto !== '' ? $extracto : FORM_NAME);
$otros = [];
foreach ($_POST as $k => $v) {
    if (array_key_exists($k, FIELDS) || in_array($k, TECH_FIELDS, true) || !is_string($v) || trim($v) === '') { continue; }
    $otros[clean((string) $k, 40)] = clean($v, 500);
}

// 2 · Donde estaba. El titulo se lee del .html servido; si no esta, el que mando
// el navegador. La pagina anterior solo si es de este sitio; de fuera, el dominio.
$pagina = post('page', 300);
function titulo_de(string $ruta): string {
    if (!preg_match('~^/[A-Za-z0-9/._-]*$~', $ruta) || strpos($ruta, '..') !== false) { return ''; }
    $r = trim($ruta, '/');
    foreach ($r === '' ? ['index.html'] : ["$r.html", "$r/index.html", $r] as $c) {
        $f = DOCROOT . '/' . $c;
        if (substr($c, -5) !== '.html' || !is_file($f)) { continue; }
        $h = (string) @file_get_contents($f, false, null, 0, 16384);
        if (preg_match('~<title[^>]*>(.*?)</title>~si', $h, $m)) {
            return trim(html_entity_decode(strip_tags($m[1]), ENT_QUOTES | ENT_HTML5, 'UTF-8'));
        }
    }
    return '';
}
$titulo = titulo_de($pagina) ?: post('title', 200);
$host = fn(string $u) => preg_replace('/^www\./', '', strtolower((string) (parse_url($u, PHP_URL_HOST) ?? '')));
$refUrl = post('ref', 500);
$refHost = $host($refUrl);
$sitio = preg_replace('/^www\./', '', strtolower(SITE_HOST));
$refPropio = $refHost !== '' && $refHost === $sitio;
$precedente = $refPropio ? (string) (parse_url($refUrl, PHP_URL_PATH) ?: '/') : '';
$cta = post('cta', 60);
$landing = post('landing', 300);
$vistas = (int) post('pages', 6);

// 3 · Como llego, en palabras: [la frase del aviso, la palabra corta del asunto].
parse_str(ltrim(post('qs', 2000), '?'), $qs);
$qv = fn(string $k) => is_string($qs[$k] ?? null) ? clean($qs[$k], 120) : post($k, 120);
$utm = [];
foreach (['utm_source', 'utm_medium', 'utm_campaign'] as $k) { if (($v = $qv($k)) !== '') { $utm[$k] = $v; } }
function llegada(array $L, callable $qv, array $utm, string $refHost, bool $refPropio): array {
    $camp = isset($utm['utm_campaign']) ? " · {$L['camp']} {$utm['utm_campaign']}" : '';
    $src = strtolower($utm['utm_source'] ?? '');
    if ($qv('gclid') !== '' || $qv('gbraid') !== '' || $qv('wbraid') !== '') { return [$L['ads'] . $camp, 'Google Ads']; }
    if ($qv('msclkid') !== '') { return [$L['ms'] . $camp, 'Microsoft Ads']; }
    if ($qv('fbclid') !== '' || preg_match('/^(facebook|instagram|meta|fb|ig)\b/', $src)) { return [$L['meta'] . $camp, 'Meta']; }
    if ($src !== '') { return ["{$L['tagged']}: " . implode(' / ', $utm), $utm['utm_source']]; }
    if ($refHost !== '' && !$refPropio) {
        if (preg_match('/(^|\.)google\.[a-z.]+$/', $refHost)) { return [$L['org'], $L['org']]; }
        if (preg_match('/(^|\.)bing\.com$/', $refHost)) { return [$L['bing'], 'Bing']; }
        if (preg_match('/(^|\.)(facebook|instagram)\.com$|^(l|lm)\.facebook\.com$/', $refHost)) { return [$L['meta_link'], 'Meta']; }
        if (preg_match('/(chatgpt\.com|openai\.com|perplexity\.ai|gemini\.google\.com|copilot\.microsoft\.com|claude\.ai)$/', $refHost)) {
            return ["{$L['ai']}: $refHost", $L['ai']];
        }
        return ["{$L['other_site']}: $refHost", "{$L['other_site']}: $refHost"];
    }
    if ($refPropio) { return [$L['unknown_long'], $L['unknown']]; }
    return [$L['direct_long'], $L['direct']];
}
[$llegada, $llegadaCorta] = llegada($L, $qv, $utm, $refHost, $refPropio);

// Quien es y como contestarle.
$ua = (string) ($_SERVER['HTTP_USER_AGENT'] ?? '');
$dispositivo = preg_match('/iPad|Tablet/i', $ua) ? $L['tablet']
    : (preg_match('/Mobi|Android|iPhone/i', $ua) ? $L['mobile'] : ($ua === '' ? $L['dev_unknown'] : $L['desktop']));
$idioma = post('lang', 12);
$refLead = date('ymd') . '-' . bin2hex(random_bytes(3));
$hora = (new DateTime('now', new DateTimeZone(TIMEZONE)))->format('d/m/Y H:i');

// --- 1) COPIA EN DISCO, ANTES DE ENVIAR --------------------------------------
// Se guarda PRIMERO. Si el correo falla algun dia, el lead NO se pierde — que es
// exactamente lo que ha pasado con los CRM dados de baja. Y lleva la ficha
// entera: un correo perdido deja un lead que se puede leer.
// ⚠️ LOG_DIR va FUERA del directorio publico. Si no se puede, protegerlo con
// .htaccess: un fichero de leads accesible por web es una brecha de datos.
@mkdir(LOG_DIR, 0750, true);
$row = array_merge(
    ['fecha' => date('c'), 'ip' => $_SERVER['REMOTE_ADDR'] ?? '', 'origen' => $pagina],
    $data,
    ['ref_lead' => $refLead, 'busca' => $busca, 'extracto' => $extracto, 'titulo' => $titulo, 'bloque' => $cta,
     'precedente' => $precedente, 'ref_externo' => $refPropio ? '' : $refHost, 'landing' => $landing, 'paginas' => $vistas,
     'llegada' => $llegada, 'llegada_corta' => $llegadaCorta, 'utm' => $utm, 'gclid' => $qv('gclid'),
     'idioma' => $idioma, 'dispositivo' => $dispositivo, 'otros' => $otros]
);
if ($test) { $row['prueba'] = true; }
@file_put_contents(
    LOG_DIR . '/leads-' . date('Y-m') . '.jsonl',
    json_encode($row, JSON_UNESCAPED_UNICODE) . "\n",
    FILE_APPEND | LOCK_EX
);

// --- 2) EL AVISO -------------------------------------------------------------
// El asunto es el triaje: de un vistazo en la bandeja, cliente, proveedor o venta.
$subject = sprintf('[%s] %s · %s', SITE_NAME, words($busca, 8), $llegadaCorta) . ($test ? ' · TEST' : '');

$nm = fn(string $porque) => "{$L['nm']} ($porque)";
$body = $test ? $L['test'] . "\n\n" : '';
$body .= $L['want'] . "\n" . $busca . "\n";
if ($extracto !== '' && $extracto !== $busca) { $body .= '« ' . $extracto . " »\n"; }
$body .= "\n" . $L['fields'] . ":\n";
foreach (FIELDS as $k => $label) {
    if ($data[$k] !== '') { $body .= sprintf("  %-14s %s\n", $label . ':', $data[$k]); }
}
if ($otros) {
    $body .= "  {$L['other']}:\n";
    foreach ($otros as $k => $v) { $body .= "    $k: $v\n"; }
}
$body .= "\n" . $L['where'] . "\n";
$body .= "{$L['page']}: " . ($titulo !== '' ? "$titulo ($pagina)" : ($pagina !== '' ? $pagina : $nm('page'))) . "\n";
$body .= "{$L['block']}: " . ($cta !== '' ? $cta : $nm($L['nm_cta'])) . "\n";
$body .= "{$L['prev']}: " . ($precedente !== '' ? $precedente
    : ($refHost !== '' ? sprintf($L['prev_ext'], $refHost) : $L['prev_none'])) . "\n";
$body .= "{$L['landing']}: " . ($landing !== '' ? $landing . ($vistas > 0 ? " · $vistas {$L['pages_seen']}" : '')
    : $nm(post('consent_analytics', 12) === 'denied' ? $L['nm_consent'] : $L['nm_phase'])) . "\n";
$body .= "\n" . $L['how'] . "\n" . $llegada . "\n";
$body .= "\n" . $L['who'] . "\n";
$body .= $data['email'] !== '' ? sprintf($L['reply'], $data['email']) . "\n"
    : (($data['phone'] ?? '') !== '' ? sprintf($L['reply_phone'], $data['phone']) . "\n" : '');
$body .= sprintf($L['received'], $hora) . " · {$L['device']}: $dispositivo · {$L['lang']}: "
    . ($idioma !== '' ? $idioma : $L['nm']) . "\n";
$body .= "\n" . str_repeat('-', 46) . "\n";
$body .= "{$L['site']}: " . SITE_HOST . " · {$L['ref']} $refLead\n";
if (SHEET_URL !== '') { $body .= "{$L['sheet']}: " . SHEET_URL . "\n"; }

$headers = [
    'From: ' . SITE_NAME . ' <' . MAIL_FROM . '>',
    // Reply-To = quien escribe. Responder es UN clic, sin copiar la direccion.
    'Reply-To: ' . $data['name'] . ' <' . $data['email'] . '>',
    'Content-Type: text/plain; charset=UTF-8',
    'X-Mailer: PHP/' . phpversion(),
];

$sent = @mail($test ? TEST_TO : MAIL_TO, '=?UTF-8?B?' . base64_encode($subject) . '?=', $body, implode("\r\n", $headers));

// --- 3) RESPUESTA ------------------------------------------------------------
// Si el correo falla, el lead YA esta en disco: se da exito al visitante (su
// dato esta a salvo) y se registra el fallo para revisarlo.
if (!$sent) {
    @file_put_contents(LOG_DIR . '/errores.log', date('c') . " fallo mail() a " . ($test ? TEST_TO : MAIL_TO) . "\n", FILE_APPEND);
}
if ($test) {
    // Sin la pagina de gracias: una prueba no puede contar como conversion.
    header('Content-Type: text/plain; charset=utf-8');
    exit("TEST recibido · ref. $refLead · aviso a " . TEST_TO . ($sent ? '' : ' (mail() fallo: mirar errores.log)'));
}
header('Location: ' . THANKS_URL);
exit;
