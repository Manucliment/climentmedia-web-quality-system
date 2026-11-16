<?php
// Solo para el banco: el php-cli del host de medida no trae mbstring, y el hosting
// de las webs si. Sin esto, cada caso moria en clean() con «Call to undefined
// function mb_substr()», que no es un fallo de la plantilla. Se carga con
// -d auto_prepend_file; si la extension existe, no hace nada.
if (!function_exists('mb_substr')) {
    function mb_substr($s, $start, $len = null, $enc = null) {
        $a = preg_split('//u', (string) $s, -1, PREG_SPLIT_NO_EMPTY);
        return implode('', array_slice($a, $start, $len));
    }
}
