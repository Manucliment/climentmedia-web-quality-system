#!/usr/bin/env perl
# Servidor HTTP minimo para probar G11 sin tocar ninguna web viva.
# Solo core (IO::Socket::INET): en esta maquina no hay python -m http.server,
# y node no esta en el PATH de Git Bash.
#   perl test-server.pl <raiz> <puerto>
# Sirve /x -> x/index.html o x.html o x, como hacen nuestras webs.
use strict; use warnings;
use IO::Socket::INET;
my ($raiz, $puerto) = @ARGV;
die "uso: test-server.pl <raiz> <puerto>\n" unless $raiz && $puerto;
$| = 1;
# 🔴 SIN ReuseAddr, A PROPOSITO. En Windows SO_REUSEADDR deja que DOS procesos
#    se aten al mismo puerto sin error, y entonces contesta el que estaba antes.
#    Me paso con este mismo fichero: el puerto 8731 ya lo tenia otro servidor de
#    otra sesion sirviendo HTML en frances, mi servidor «arranco» sin quejarse, y
#    las pruebas de G11 estuvieron midiendo una web que no era la del fixture
#    —dos de ellas incluso PASARON, por el motivo equivocado. Es la trampa que
#    ya esta escrita en ~/.claude/CLAUDE.md: no da error, devuelve datos
#    plausibles de otra cosa. Sin ReuseAddr, un puerto ocupado muere aqui.
my $s = IO::Socket::INET->new(LocalAddr=>'127.0.0.1', LocalPort=>$puerto,
                              Proto=>'tcp', Listen=>16)
        or die "no puedo escuchar en $puerto: $!\n";
print "listo\n";
# ── DOS MANERAS DE PORTARSE MAL, A PETICION ─────────────────────────────────
#  Sin estos dos ficheros el servidor se comporta EXACTAMENTE como antes.
#
#    <raiz>/_huella-curl.txt -> 403 a la HUELLA de curl con compresion.
#        Reproduce el WAF de Hostinger que sirve shop.site-b.example y que dejo a
#        G11 devolviendo «95 de 95 NO HALLADO» con exit 0.
#
#        🔴 Medido a mano el 10-ago-2026, 15 peticiones. NO es «le falta la
#           cabecera Accept»: curl SIEMPRE manda «Accept: */*». Lo que se
#           rechaza es la huella exacta de curl, que en el cable acaba asi:
#               ... Accept: */*
#               ... Accept-Encoding: deflate, gzip, br, zstd     <- ultima
#           Basta con que esas dos dejen de ser las dos ultimas para que pase:
#               -H "Accept: text/html,..."  -> curl la manda DESPUES de
#                Accept-Encoding, la huella ya no casa, y contesta 200.
#               -H "X-Nada: 1"              -> tambien 200 (¡el mismo Accept!)
#           Y el User-Agent no pinta nada: sin UA tambien es 403, y con UA pero
#           sin compresion es 200.
#
#        Por que asi y no «403 si no hay Accept»: esa version, que es la que
#        escribi primero, la PASABA el codigo roto —curl manda Accept siempre—.
#        Una prueba que pasa con el arreglo quitado no prueba nada: la unica
#        forma de saberlo fue quitar el arreglo y ver la prueba en ROJO.
#
#    <raiz>/_403.txt         -> 403 a las rutas que liste, una por linea.
#        Para probar la regla de cobertura: mas rechazos que medidas.
sub marcador {
    my ($f) = @_;
    return '' unless -f $f;
    open my $fh, '<', $f or return '';
    local $/; my $x = <$fh>; close $fh;
    return defined $x ? $x : '';
}

while (my $c = $s->accept) {
    my $l = <$c>;
    unless (defined $l) { close $c; next }
    my ($ruta) = $l =~ m{^GET\s+(\S+)};
    my @hdr;   # EN ORDEN: la huella depende del orden, no solo de que esten
    while (defined($l = <$c>) && $l !~ /^\r?$/) {
        push @hdr, [ lc $1, $2 ] if $l =~ /^([A-Za-z-]+):\s*(.*?)\r?$/;
    }
    $ruta = '/' unless defined $ruta;
    $ruta =~ s/\?.*$//;
    $ruta =~ s{^/}{};
    $ruta = 'index.html' if $ruta eq '';

    my $huella_curl = (@hdr >= 2
                       && $hdr[-2][0] eq 'accept' && $hdr[-2][1] eq '*/*'
                       && $hdr[-1][0] eq 'accept-encoding') ? 1 : 0;
    if (-f "$raiz/_huella-curl.txt" && $huella_curl) {
        print $c "HTTP/1.0 403 Forbidden\r\nContent-Length: 24\r\n"
               . "Content-Type: text/html\r\n\r\n<h1>403 Forbidden</h1>\r\n";
        close $c; next;
    }
    if (my $lista = marcador("$raiz/_403.txt")) {
        # se compara SIN la extension .html a los dos lados: G11 prueba primero
        # la URL sin extension («/styles»), asi que una lista escrita con los
        # nombres de fichero no casaria nunca y el 403 no llegaria a fabricarse
        # —una prueba que cree estar probando algo y no prueba nada—.
        my $rn = $ruta; $rn =~ s/\.html$//;
        if (grep { $_ eq $rn }
            map  { my $x=$_; $x =~ s/\r//g; $x =~ s/\.html$//; $x }
            grep { length } split /\n/, $lista) {
            print $c "HTTP/1.0 403 Forbidden\r\nContent-Length: 24\r\n"
                   . "Content-Type: text/html\r\n\r\n<h1>403 Forbidden</h1>\r\n";
            close $c; next;
        }
    }

    my @cand = ("$raiz/$ruta", "$raiz/$ruta/index.html", "$raiz/$ruta.html");
    my ($f) = grep { -f $_ } @cand;
    if ($f) {
        open my $fh, '<:raw', $f; local $/; my $b = <$fh>; close $fh;
        $b = '' unless defined $b;
        print $c "HTTP/1.0 200 OK\r\nContent-Length: " . length($b)
               . "\r\nContent-Type: text/plain\r\n\r\n$b";
    } else {
        print $c "HTTP/1.0 404 Not Found\r\nContent-Length: 3\r\n\r\n404";
    }
    close $c;
}
