#!/usr/bin/perl
# =============================================================================
#  Prueba del guardia R0 · "el rastreo estatico no puede medir este sitio"
# =============================================================================
#    perl "/path/to/web-quality-system/gates/crawl-links-tests/orphans-js.pl"
#
#  🔴 POR QUE EXISTE: un rastreo estatico NO ve los enlaces que pinta el JS, y
#     entonces las paginas a las que solo se llega por ahi parecen HUERFANAS.
#     Acusar de 60 huerfanas a una tienda que funciona es justo el falso
#     positivo que hace que alguien apague el gate en una semana.
#
#  Dos casos, y hacen falta los dos:
#    A · SITE-B  — la tienda entera es una cascara JS (header y footer vacios).
#                   R0 tiene que ABORTAR: 0 enlaces de nav en todo el sitio.
#    B · HIBRIDO  — cascara servida CON su nav estatica, pero la REJILLA de
#                   producto la pinta el JS. Es el patron mas comun (y esta a
#                   un refactor de distancia de site-b). Aqui R0 mira una
#                   media del sitio y se le escapa: sin guardia, el gate acusa
#                   de huerfanas a 12 fichas que existen y se enlazan solas.
#
#  ⚠️ NO toca la red: siembra la cache que crawl-links.pl ya usa.
# =============================================================================
use strict; use warnings;
use JSON::PP; use Digest::MD5 qw(md5_hex); use File::Path qw(make_path);
use File::Temp qw(tempdir);

my $DIR   = $0; $DIR =~ s{[/\\][^/\\]+$}{};
my $CRAWL = "$DIR/../crawl-links.pl";
my $GATE  = "$DIR/../linking-gate.pl";
my ($ok, $ko) = (0, 0);

sub seed {
    my ($cache, $url, $code, $body, $ctype) = @_;
    my $k = md5_hex($url);
    open my $m, '>', "$cache/$k.meta" or die $!;
    print $m "$code|$url|0|" . ($ctype // 'text/html; charset=utf-8'); close $m;
    open my $b, '>:raw', "$cache/$k.body" or die $!; print $b ($body // ''); close $b;
}

# construye un sitio de mentira y devuelve (json_del_crawl, salida_del_gate)
sub monta {
    my (%o) = @_;
    my $host  = $o{host};
    my $tmp   = tempdir(CLEANUP => 1);
    my $cache = "$tmp/c"; make_path($cache);
    my $out   = "$tmp/g.json";
    my @prod  = map { "p$_" } (1 .. 12);

    # el nav estatico que comparten las paginas normales
    my $nav = '<header><nav aria-label="Principal">'
            . '<a href="/">Inicio</a><a href="/a">A</a><a href="/b">B</a><a href="/tienda">Tienda</a>'
            . '</nav></header>';
    my $pie = '<footer><nav aria-label="Legal"><a href="/aviso">Aviso</a></nav></footer>';

    my $sm = join '', map { "<url><loc>https://$host$_</loc></url>" }
             ('/', '/a', '/b', '/aviso', '/tienda', map { "/$_" } @prod);
    seed($cache, "https://$host/sitemap.xml", 200,
         qq{<?xml version="1.0"?><urlset>$sm</urlset>}, 'application/xml');

    my $pag = sub {
        my ($t, $cuerpo, $con_chrome) = @_;
        return "<!DOCTYPE html><html lang=\"es\"><head><title>$t</title></head><body>"
             . ($con_chrome ? $nav : '')
             . "<main><h1>$t</h1>$cuerpo</main>"
             . ($con_chrome ? $pie : '') . "</body></html>";
    };

    seed($cache, "https://$host/",       200, $pag->('Inicio', '<p>Ver la <a href="/tienda">tienda</a> y la <a href="/a">pagina A</a>.</p>', 1));
    seed($cache, "https://$host/a",      200, $pag->('A', '<p>Volver a <a href="/b">B</a>.</p>', 1));
    seed($cache, "https://$host/b",      200, $pag->('B', '<p>Volver a <a href="/a">A</a>.</p>', 1));
    seed($cache, "https://$host/aviso",  200, $pag->('Aviso', '<p>Texto legal.</p>', 1));

    # LA TIENDA: rejilla vacia, la monta el JS. Calcado de shop.site-b.example/loja.html
    my $shell = '<main class="grow"><div id="shop"><div class="skeleton" style="height:60vh"></div></div></main>'
              . '<script type="module">import { initShop } from "./js/shop.js"; initShop(document.getElementById("shop"));</script>';
    if ($o{tienda_estatica}) {
        # control negativo: la rejilla viene servida... pero solo con 2 fichas.
        # Las otras 10 no las enlaza nadie: huerfanas de verdad.
        $shell = '<main><h1>Tienda</h1><ul>'
               . join('', map { qq{<li><a href="/$_">Ficha $_</a></li>} } @prod[0..1])
               . '</ul></main>';
    }
    seed($cache, "https://$host/tienda", 200,
         $o{chrome_en_tienda}
           ? "<!DOCTYPE html><html lang=\"es\"><head><title>Tienda</title></head><body>$nav$shell$pie</body></html>"
           : "<!DOCTYPE html><html lang=\"es\"><head><title>Tienda</title></head><body><div id=\"app-header\"></div>$shell<div id=\"app-footer\"></div></body></html>");

    # las fichas: existen y se sirven bien. Nadie las enlaza en HTML porque
    # quien las enlaza es la rejilla que pinta el JS.
    for my $p (@prod) {
        seed($cache, "https://$host/$p", 200,
             $o{chrome_en_tienda}
               ? $pag->("Ficha $p", '<p>Descripcion.</p>', 1)
               : "<!DOCTYPE html><html lang=\"es\"><head><title>Ficha $p</title></head><body><div id=\"app-header\"></div><main><h1>Ficha $p</h1></main><div id=\"app-footer\"></div></body></html>");
    }

    system(qq{perl "$CRAWL" "https://$host/" "$cache" "$out" 60 >/dev/null 2>&1});
    my $g = `perl "$GATE" "$out" 2>&1`;
    my $j = JSON::PP->new->decode(do { local $/; open my $h, '<', $out or die $!; <$h> });
    return ($j, $g);
}

sub linea { my ($g, $r) = @_; my ($l) = grep { /^\s*(PASA|FALLA|AVISO|NOVERIF)\s+$r\b/ } split /\n/, $g; return $l // "(ausente)"; }

sub comprueba {
    my ($eti, $cond, $detalle) = @_;
    if ($cond) { printf "  OK    %-56s %s\n", $eti, $detalle // ''; $ok++ }
    else       { printf "  MAL   %-56s %s\n", $eti, $detalle // ''; $ko++ }
}

print "\n== CASO A · cascara JS completa (site-b): R0 tiene que abortar\n";
{
    my ($j, $g) = monta(host => 'tiendajs.test', chrome_en_tienda => 0);
    my $r0 = linea($g, 'R0');
    print "     $r0\n";
    comprueba('R0 corta y NO se leen los hallazgos', $r0 =~ /^NOVERIF/, '');
    comprueba('NO acusa: el veredicto es NO VERIFICADO, no FALLA',
              $g =~ /VEREDICTO: NO VERIFICADO/, '');
    comprueba('no llega a acusar de huerfanas (R4 ni se imprime)', $g !~ /R4/, '');
}

print "\n== CASO B · cascara servida + rejilla JS: el hueco que R0 no ve\n";
{
    my ($j, $g) = monta(host => 'hibrido.test', chrome_en_tienda => 1);
    my $p = $j->{pages};
    my $tienda = $p->{'https://hibrido.test/tienda'};
    printf "     tienda: a_href_total=%s  js_shell=%s\n",
           ($tienda->{a_href_total} // 'AUSENTE'), ($tienda->{js_shell} ? 'si' : 'no');
    print "     ", linea($g, 'R0'), "\n";
    print "     ", linea($g, 'R4'), "\n";

    comprueba('la tienda se marca como js_shell', ($tienda->{js_shell} ? 1 : 0), '');
    comprueba('R0 sigue en PASA (por eso hace falta el guardia por pagina)',
              linea($g,'R0') =~ /^PASA/, '');
    # 12 fichas: antes salian acusadas en R2 y en R4 (24 lineas)
    my @acu = $g =~ m{^\s+- (https://hibrido\.test/p\d+)\b}gm;
    comprueba('R4 NO acusa de huerfanas: dice que no puede medirlo',
              linea($g, 'R4') =~ /^NOVERIF/, linea($g,'R4') =~ /^NOVERIF/ ? '' : scalar(@acu)." acusadas");
    comprueba('el veredicto NO es PASA (no se cuela por la puerta)',
              $g !~ /VEREDICTO: PASA/, '');
}

print "\n== CASO C · NEGATIVO DURO · huerfanas de verdad, sin JS de por medio\n";
print "   Si el guardia nuevo apagase esto, seria peor que el bug que arregla.\n";
{
    # mismo sitio, pero la tienda enlaza sus fichas en HTML... salvo 12 que
    # nadie enlaza. Sin cascara JS: no hay excusa, son huerfanas de verdad.
    my ($j, $g) = monta(host => 'estatico.test', chrome_en_tienda => 1, tienda_estatica => 1);
    my $tienda = $j->{pages}{'https://estatico.test/tienda'};
    printf "     tienda: a_href_total=%s  js_shell=%s\n",
           ($tienda->{a_href_total} // 'AUSENTE'), ($tienda->{js_shell} ? 'si' : 'no');
    print "     ", linea($g, 'R4'), "\n";
    comprueba('la tienda estatica NO se marca js_shell', !($tienda->{js_shell}), '');
    comprueba('R4 SIGUE acusando (FALLA) a las huerfanas reales',
              linea($g, 'R4') =~ /^FALLA/, linea($g,'R4'));
}

printf "\n-----------------------------------------------------------------\n";
printf "  OK %-3d  ·  MAL %d\n", $ok, $ko;
exit($ko ? 1 : 0);
