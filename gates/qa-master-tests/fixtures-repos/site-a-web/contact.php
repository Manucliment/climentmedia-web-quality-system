<?php
// Receptor del formulario de contacto de site-a.example.
// Fixture SINTETICO de gates/qa-master-tests: nunca se ejecuta en el banco.
// Solo acepta POST: a un GET contesta 405 -lo que mide MED-10 contra
// produccion-, y contra el candidato no se ejecuta nada, por eso MED-10 sale
// NO VERIFICADO alli. Los datos van a _leads/, que cierra el HOST (MED-12).
if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'POST') {
    http_response_code(405);
    header('Allow: POST');
    echo '<!doctype html><html lang="fr"><head><meta charset="utf-8"><title>405</title></head><body><p>Methode non autorisee.</p></body></html>' . "\n";
    exit;
}

$lead = [
    'fecha'   => gmdate('c'),
    'nom'     => trim((string)($_POST['nom'] ?? '')),
    'email'   => trim((string)($_POST['email'] ?? '')),
    'message' => trim((string)($_POST['message'] ?? '')),
];
if ($lead['nom'] === '' || !filter_var($lead['email'], FILTER_VALIDATE_EMAIL)) {
    http_response_code(400);
    exit('Donnees incompletes.');
}

$dir = __DIR__ . '/_leads';
if (!is_dir($dir)) { mkdir($dir, 0700, true); }
file_put_contents($dir . '/' . gmdate('Y-m') . '.jsonl',
    json_encode($lead, JSON_UNESCAPED_UNICODE) . "\n", FILE_APPEND | LOCK_EX);

// La purga de lo que tiene mas de dos meses la hace un cron del servidor,
// que es el plazo que declara la politica de confidentialite.
header('Location: /merci', true, 303);
