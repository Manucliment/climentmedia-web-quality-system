#!/usr/bin/env perl
# =============================================================================
#  Controles de cdn_transforma() · G11 y las imagenes que reescribe un CDN
# =============================================================================
#  Extrae las subs REALES de receipt.pl y las evalua: mide el codigo que se
#  despliega, no una copia. Mismo patron que p3-controles.pl.
#
#  POR QUE EXISTE (20-ago-2026). La primera corrida de G11 detras del CDN de
#  Hostinger dio 12 DISTINTO y NINGUNO estaba mal subido: el CDN recomprime los
#  PNG y REDIMENSIONA los JPEG (1726x911 -> 1600x844). Un rojo que sale en cada
#  despliegue y que nadie puede arreglar no protege: enseña a ignorar el gate.
#
#  🔴 LO QUE ESTAS PRUEBAS VIGILAN NO ES QUE TOLERE: ES QUE SIGA ACUSANDO.
#  La tentacion facil era «saltarse las imagenes», y eso habria dejado ciego al
#  gate para el caso que importa. La excepcion solo vale si hay un CDN delante Y
#  lo servido sigue siendo una imagen. Los controles negativos son la mitad que
#  cuenta: sin CDN -> FALLO, y si devuelven HTML -> FALLO.
use strict; use warnings; use utf8;
use File::Basename qw(dirname);
binmode(STDOUT, ':encoding(UTF-8)');

# Derived, not hard-coded. It used to be an absolute path to one machine, which
# is why it broke the moment the tree moved. The battery lives one level below
# the gate it extracts from.
my $SRC = shift(@ARGV) // (dirname($0) . '/../receipt.pl');
my $src = do { open my $f,'<:encoding(UTF-8)',$SRC or die "$SRC: $!"; local $/; <$f> };
my $code = '';
for my $n (qw(cdn_transforma medidas_imagen)) {
    my ($s) = $src =~ /^(sub \Q$n\E\s*\{.*?^\})/ms or die "no encuentro sub $n\n";
    $code .= "$s\n";
}
eval $code; die $@ if $@;

my $PNG_HDR = "\x89PNG\r\n\x1a\n" . pack('N', 13) . 'IHDR' . pack('NN', 1200, 630) . "\x08\x06\x00\x00\x00";
my $PNG     = $PNG_HDR . ('x' x 500);
my $JPEG    = "\xFF\xD8" . "\xFF\xC0" . pack('n', 17) . "\x08" . pack('nn', 844, 1600) . ('y' x 20);
my $GIF     = 'GIF89a' . ('z' x 100);
my $HTML    = '<!DOCTYPE html><html><body>Checking your browser</body></html>';
my $HCDN    = "HTTP/1.1 200 OK\r\nContent-Type: image/png\r\nServer: hcdn\r\nx-hcdn-cache-status: HIT\r\n\r\n";
my $CF      = "HTTP/1.1 200 OK\r\ncf-ray: 8abc123-MAD\r\n\r\n";
my $XCACHE  = "HTTP/1.1 200 OK\r\nx-cache: HIT\r\n\r\n";
my $LIMPIA  = "HTTP/1.1 200 OK\r\nContent-Type: image/png\r\nServer: Apache\r\n\r\n";

#        etiqueta                                              ruta          cuerpo  cabecera  ¿tolera?
my @C = (
 ['PNG detras de hcdn: se tolera y se DECLARA',                'a/x.png',    $PNG,   $HCDN,   1],
 ['JPEG redimensionado detras de hcdn',                        'a/x.jpg',    $JPEG,  $HCDN,   1],
 ['GIF detras de x-cache',                                     'a/x.gif',    $GIF,   $XCACHE, 1],
 ['PNG detras de Cloudflare (cf-ray)',                         'a/x.png',    $PNG,   $CF,     1],
 ['🔴 NEGATIVO · PNG distinto y SIN CDN -> sigue siendo FALLO', 'a/x.png',    $PNG,   $LIMPIA, 0],
 ['🔴 NEGATIVO · el CDN devuelve HTML, no una imagen -> FALLO', 'a/x.png',    $HTML,  $HCDN,   0],
 ['🔴 NEGATIVO · un .css distinto detras del CDN -> FALLO',     'a/x.css',    $PNG,   $HCDN,   0],
 ['🔴 NEGATIVO · un .html distinto detras del CDN -> FALLO',    'a/x.html',   $HTML,  $HCDN,   0],
 ['🔴 NEGATIVO · un .js distinto detras del CDN -> FALLO',      'a/x.js',     $PNG,   $HCDN,   0],
 ['🔴 NEGATIVO · cuerpo vacio -> FALLO',                        'a/x.png',    '',     $HCDN,   0],
 ['🔴 NEGATIVO · sin cabeceras -> FALLO',                       'a/x.png',    $PNG,   '',      0],
);

my ($ok, $ko) = (0, 0);
for my $c (@C) {
    my ($eti, $rel, $b, $h, $esp) = @$c;
    my $r = cdn_transforma($rel, $b, $h);
    my $tolera = defined($r) ? 1 : 0;
    if ($tolera == $esp) { printf "  OK    %-54s %s\n", $eti, ($tolera ? 'tolerado' : 'FALLO'); $ok++ }
    else { printf "  MAL   %-54s esperaba %s y salio %s\n", $eti,
                  ($esp ? 'tolerado' : 'FALLO'), ($tolera ? 'tolerado' : 'FALLO'); $ko++ }
}
# medidas_imagen: solo para el informe, pero si miente el informe miente.
for my $c (['PNG 1200x630', $PNG, '1200x630'], ['JPEG 1600x844', $JPEG, '1600x844'],
           ['no es imagen', $HTML, undef]) {
    my ($eti, $b, $esp) = @$c;
    my $r = medidas_imagen($b);
    my $bien = (defined $esp && defined $r && $r eq $esp) || (!defined $esp && !defined $r);
    if ($bien) { printf "  OK    %-54s %s\n", "medidas · $eti", ($r // 'undef'); $ok++ }
    else { printf "  MAL   %-54s esperaba %s y salio %s\n", "medidas · $eti", ($esp//'undef'), ($r//'undef'); $ko++ }
}
printf "\n  %d OK  ·  %d MAL\n", $ok, $ko;
exit($ko ? 1 : 0);
