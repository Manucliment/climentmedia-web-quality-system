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
 *  CONFIGURAR: las 4 constantes de abajo. Nada mas.
 *  ⚠️ Comprobar antes que el plan tiene PHP: si /index.php da 404, no lo tiene.
 * ========================================================================== */

// 🔴 18-ago-2026 · ESTOS VALORES NO PUEDEN PARECER BUENOS. Antes ponia
// `contact@ejemplo.tld`, que es una direccion con forma de direccion: copiar
// esta plantilla sin tocarla ponia en VERDE el check INT-02 de audit-vs-spec.pl
// — el check que existe precisamente porque el formulario de Site A a Domicile
// llevaba meses enviando a un CRM dado de baja. La plantilla aprobaba el
// examen que la plantilla venia a suspender.
const MAIL_TO      = 'RELLENAR@ejemplo.tld';      // destino de los avisos
const MAIL_FROM    = 'RELLENAR@ejemplo.tld';      // buzon del MISMO dominio
const SITE_NAME    = 'RELLENAR nombre del cliente';
const THANKS_URL   = '/merci';                    // pagina de gracias que ya existe
const LOG_DIR      = __DIR__ . '/../_leads';      // FUERA del directorio publico

// Y si aun asi sube sin configurar, no finge que funciona. Contestar 200 sin
// buzon es el defecto entero: nadie se entera hasta que el cliente pregunta por
// que no le llegan clientes.
foreach (['MAIL_TO' => MAIL_TO, 'MAIL_FROM' => MAIL_FROM, 'SITE_NAME' => SITE_NAME] as $k => $v) {
    if (strpos($v, 'RELLENAR') !== false || strpos($v, 'ejemplo.tld') !== false) {
        http_response_code(500);
        header('Content-Type: text/plain; charset=utf-8');
        exit("form-handler.php sin configurar: $k sigue con el valor de la plantilla.");
    }
}

// --- campos: nombre del input => etiqueta en el email ------------------------
// Ajustar al formulario real. El orden aqui es el orden del email.
const FIELDS = [
    'name'    => 'Nombre',
    'phone'   => 'Telefono',
    'email'   => 'Email',
    'address' => 'Direccion',
    'city'    => 'Municipio',
    'need'    => 'Necesidad',
    'message' => 'Mensaje',
];
const REQUIRED = ['name', 'phone', 'email', 'city'];

// =============================================================================
header('X-Content-Type-Options: nosniff');
// `?? ''` y no acceso directo: sin el, cualquier invocacion sin REQUEST_METHOD
// -- la CLI, un cron, un healthcheck raro -- suelta un PHP Warning que acaba en
// el log de errores del cliente. Verificado ejecutandolo: el aviso salia.
if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') { http_response_code(405); exit('Method Not Allowed'); }

function fail(string $msg, int $code = 400): void {
    http_response_code($code);
    header('Content-Type: text/plain; charset=utf-8');
    exit($msg);
}
function clean(string $s): string {
    // ⚠️ U+200B y demas invisibles: llegan de gente que copia y pega desde el
    // movil o desde un documento, y luego rompen filtros y automatizaciones EN
    // SILENCIO. Se limpian aqui, en la puerta, no despues.
    $s = preg_replace('/[\x{200B}-\x{200D}\x{FEFF}]/u', '', $s);
    $s = str_replace(["\r", "\n"], ' ', $s);          // corta inyeccion de cabeceras
    return trim(mb_substr($s, 0, 2000));
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
foreach (FIELDS as $k => $label) { $data[$k] = clean((string) ($_POST[$k] ?? '')); }

foreach (REQUIRED as $k) {
    if ($data[$k] === '') { fail('Falta un campo obligatorio: ' . FIELDS[$k], 422); }
}
if (!filter_var($data['email'], FILTER_VALIDATE_EMAIL)) { fail('Email no valido.', 422); }
if (empty($_POST['consent'] ?? '')) { fail('Falta el consentimiento.', 422); }

// --- 1) COPIA EN DISCO, ANTES DE ENVIAR --------------------------------------
// Se guarda PRIMERO. Si el correo falla algun dia, el lead NO se pierde — que es
// exactamente lo que ha pasado con los CRM dados de baja.
// ⚠️ LOG_DIR va FUERA del directorio publico. Si no se puede, protegerlo con
// .htaccess: un fichero de leads accesible por web es una brecha de datos.
@mkdir(LOG_DIR, 0750, true);
$row = array_merge(
    ['fecha' => date('c'), 'ip' => $_SERVER['REMOTE_ADDR'] ?? '', 'origen' => $_POST['page'] ?? ''],
    $data
);
@file_put_contents(
    LOG_DIR . '/leads-' . date('Y-m') . '.jsonl',
    json_encode($row, JSON_UNESCAPED_UNICODE) . "\n",
    FILE_APPEND | LOCK_EX
);

// --- 2) EMAIL ----------------------------------------------------------------
$subject = sprintf('[%s] Nuevo contacto — %s', SITE_NAME, $data['city'] ?: 'sin municipio');

$body = "Nuevo contacto desde la web.\n\n";
foreach (FIELDS as $k => $label) {
    if ($data[$k] !== '') { $body .= sprintf("%-12s %s\n", $label . ':', $data[$k]); }
}
$body .= "\n--\nRecibido: " . date('d/m/Y H:i') . "\nPagina: " . ($_POST['page'] ?? '-') . "\n";
$body .= "Responder a este correo contesta directamente a la persona.\n";

$headers = [
    'From: ' . SITE_NAME . ' <' . MAIL_FROM . '>',
    // Reply-To = quien escribe. Responder es UN clic, sin copiar la direccion.
    'Reply-To: ' . $data['name'] . ' <' . $data['email'] . '>',
    'Content-Type: text/plain; charset=UTF-8',
    'X-Mailer: PHP/' . phpversion(),
];

$sent = @mail(MAIL_TO, '=?UTF-8?B?' . base64_encode($subject) . '?=', $body, implode("\r\n", $headers));

// --- 3) RESPUESTA ------------------------------------------------------------
// Si el correo falla, el lead YA esta en disco: se da exito al visitante (su
// dato esta a salvo) y se registra el fallo para revisarlo.
if (!$sent) {
    @file_put_contents(LOG_DIR . '/errores.log', date('c') . " fallo mail() a " . MAIL_TO . "\n", FILE_APPEND);
}
header('Location: ' . THANKS_URL);
exit;
