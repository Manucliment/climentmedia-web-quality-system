<?php
/* =============================================================================
 *  consent-count.php — counts how many visitors accept or reject the cookie banner
 * =============================================================================
 *  3-nov-2026. Without this nobody knows what share of the visits GA4 never sees:
 *  a drop in leads in GA4 cannot be told apart from a drop in visitors who accept.
 *
 *  IT CARRIES NOTHING ABOUT THE PERSON: no cookie, no IP, no browser, no page,
 *  no time of day. One line per choice: the DATE (no time, so a line cannot be
 *  matched against the server's access log) and the choice. The banner sends it
 *  with navigator.sendBeacon when the visitor chooses, same origin, no third party:
 *
 *    navigator.sendBeacon('/consent-count.php', new URLSearchParams({ e: 'accept' }));
 *
 *  Choices: accept, reject, partial (accepted some categories, not all).
 *  It goes to disk OUTSIDE the docroot: ../_leads/consent-YYYY-MM.tsv.
 *  Answers 204 to a valid POST (a beacon does not read the answer), 400 to an
 *  invalid one, 405 to anything that is not a POST.
 *
 *  Copy it to `_deploy/consent-count.php` and list it in PHP_EN_PRODUCCION
 *  (`_deploy/consent-count.php:consent-count.php`). Bench: consent-count-tests/.
 *  Say it in the cookie policy: «we count, without any cookie or personal data,
 *  how many visitors accept or reject this notice».
 * ========================================================================== */

header('X-Content-Type-Options: nosniff');
header('Cache-Control: no-store');
if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') { http_response_code(405); exit; }

$e = (string) ($_POST['e'] ?? '');
if (!in_array($e, ['accept', 'reject', 'partial'], true)) { http_response_code(400); exit; }

$tz = getenv('CONSENT_TZ') ?: 'Europe/Madrid';
$today = new DateTime('now', new DateTimeZone($tz));
$dir = getenv('CONSENT_DIR') ?: __DIR__ . '/../_leads';
if (!is_dir($dir)) { @mkdir($dir, 0750, true); }

$ok = @file_put_contents(
    $dir . '/consent-' . $today->format('Y-m') . '.tsv',
    $today->format('Y-m-d') . "\t" . $e . "\n",
    FILE_APPEND | LOCK_EX
);
// A counter that cannot write says so in the server's error log, not to the visitor.
if ($ok === false) { error_log('consent-count: cannot write to ' . $dir); }
http_response_code(204);
