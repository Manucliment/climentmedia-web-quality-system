<?php
/* =============================================================================
 *  consent-count.php — counts how many visitors accept or reject the cookie banner
 * =============================================================================
 *  3-nov-2026. Without this nobody knows what share of the visits GA4 never sees:
 *  a drop in leads in GA4 cannot be told apart from a drop in visitors who accept.
 *
 *  IT CARRIES NOTHING ABOUT THE PERSON: no cookie, no IP, no browser, no page,
 *  no time of day, and NO ORDER. The file holds one row per DAY with three
 *  totals, and each choice adds one to today's total:
 *
 *    #date        accept  reject  partial
 *    2026-11-06   41      12      3
 *
 *  6-nov-2026 · WHY TOTALS AND NOT ONE LINE PER CHOICE. Until today it appended
 *  «date TAB choice», one line per choice, and this header said that without the
 *  time a line could not be matched against the server's access log. It could:
 *  the log keeps the IP and the time of every POST to this file IN THE SAME ORDER,
 *  so line N of the counter was request N of the log, and the choice of each IP
 *  could be read back (seen by the site review of 5-nov). A total per day keeps
 *  no order. A file still in the old format is folded into totals the first time
 *  this version writes to it, so the order already on disk goes too.
 *
 *  The banner sends it with navigator.sendBeacon when the visitor chooses, same
 *  origin, no third party:
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
$COL = ['accept' => 0, 'reject' => 1, 'partial' => 2];
if (!array_key_exists($e, $COL)) { http_response_code(400); exit; }

$tz = getenv('CONSENT_TZ') ?: 'Europe/Madrid';
$today = new DateTime('now', new DateTimeZone($tz));
$dir = getenv('CONSENT_DIR') ?: __DIR__ . '/../_leads';
if (!is_dir($dir)) { @mkdir($dir, 0750, true); }
$file = $dir . '/consent-' . $today->format('Y-m') . '.tsv';
$day = $today->format('Y-m-d');

// Read, add one, write back, all under one exclusive lock: two beacons at the
// same moment must not lose a choice, and nobody reads a half-written file.
$ok = false;
$fh = @fopen($file, 'c+');
if ($fh !== false && flock($fh, LOCK_EX)) {
    $days = [];
    while (($line = fgets($fh)) !== false) {
        $line = rtrim($line, "\r\n");
        if ($line === '' || $line[0] === '#') { continue; }
        $f = explode("\t", $line);
        if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $f[0])) { continue; }
        $days[$f[0]] = $days[$f[0]] ?? [0, 0, 0];
        if (count($f) === 4) {                                   // a row of totals
            for ($i = 0; $i < 3; $i++) { $days[$f[0]][$i] += max(0, (int) $f[$i + 1]); }
        } elseif (count($f) === 2 && isset($COL[$f[1]])) {       // the old format: one choice
            $days[$f[0]][$COL[$f[1]]]++;
        }
    }
    $days[$day] = $days[$day] ?? [0, 0, 0];
    $days[$day][$COL[$e]]++;
    ksort($days);
    $out = "#date\taccept\treject\tpartial\n";
    foreach ($days as $d => $n) { $out .= $d . "\t" . implode("\t", $n) . "\n"; }
    $ok = ftruncate($fh, 0) && rewind($fh) && fwrite($fh, $out) === strlen($out) && fflush($fh);
    flock($fh, LOCK_UN);
}
if ($fh !== false) { fclose($fh); }
// A counter that cannot write says so in the server's error log, not to the visitor.
if (!$ok) { error_log('consent-count: cannot write to ' . $dir); }
http_response_code(204);
