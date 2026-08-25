#!/usr/bin/perl
# =============================================================================
#  sealing-server.pl · un servidor de pruebas que DISTINGUE por query string
# =============================================================================
#    perl sealing-server.pl <DIR> <PUERTO>
#
#  POR QUE NO VALE `test-server.pl`
#  ----------------------------------------
#  Aquel hace `$ruta =~ s/\?.*$//` y sirve lo mismo con query y sin ella. Eso
#  es lo correcto para un servidor de ficheros... y hace IMPOSIBLE reproducir el
#  caso que se quiere probar, que es justo el contrario:
#
#      GET /styles.css            -> copia VIEJA (cache del CDN en la URL desnuda)
#      GET /styles.css?v=abc123   -> copia NUEVA (la que el HTML enlaza de verdad)
#
#  Este emula eso: si la peticion trae query y existe `<DIR>/_sellado/<ruta>`,
#  sirve ESE fichero; si no, sirve `<DIR>/<ruta>`. Asi el fixture puede poner
#  dos bytes distintos en las dos URLs, que es la unica forma de que el caso
#  positivo y el negativo se distingan de verdad.
#
#  Sin dependencias: IO::Socket::INET viene con Perl.
# =============================================================================
use strict;
use warnings;
use IO::Socket::INET;

my $DIR    = shift or die "uso: sealing-server.pl <DIR> <PUERTO>\n";
my $PUERTO = shift or die "uso: sealing-server.pl <DIR> <PUERTO>\n";

my $srv = IO::Socket::INET->new(
    LocalAddr => '127.0.0.1',
    LocalPort => $PUERTO,
    Listen    => 16,
    ReuseAddr => 1,
) or die "no pude abrir el puerto $PUERTO: $!\n";

# El centinela de arranque: quien lanza esto espera esta linea, no un sleep.
print "LISTO $PUERTO\n";
$| = 1;

sub tipo_de {
    my ($f) = @_;
    return 'text/html; charset=utf-8'  if $f =~ /[.]html?$/i;
    return 'text/css; charset=utf-8'   if $f =~ /[.]css$/i;
    return 'application/javascript'    if $f =~ /[.]js$/i;
    return 'application/xml'           if $f =~ /[.]xml$/i;
    return 'application/octet-stream';
}

while (my $c = $srv->accept) {
    my $linea = <$c>;
    unless (defined $linea) { close $c; next; }
    # cabeceras hasta la linea en blanco: se leen y se tiran
    while (defined(my $l = <$c>)) { last if $l =~ /^\r?$/ }

    my ($ruta) = $linea =~ m{^[A-Z]+ (\S+)};
    $ruta = '/' unless defined $ruta;
    my $con_query = ($ruta =~ /[?]/) ? 1 : 0;
    $ruta =~ s/[?].*$//;
    $ruta =~ s{^/}{};
    $ruta = 'index.html' if $ruta eq '';
    $ruta =~ s{[.][.]/}{}g;                       # nada de subir de directorio

    # 🔴 EL PUNTO DE TODO ESTE FICHERO: con query, si hay version sellada, se
    #    sirve ESA. Sin query, siempre la de la raiz (la copia "vieja" del CDN).
    my $f = "$DIR/$ruta";
    if ($con_query && -f "$DIR/_sellado/$ruta") { $f = "$DIR/_sellado/$ruta" }

    if (-f $f) {
        open my $fh, '<:raw', $f or do { print $c "HTTP/1.0 500 Error\r\n\r\n"; close $c; next };
        local $/;
        my $b = <$fh>;
        close $fh;
        $b = '' unless defined $b;
        printf $c "HTTP/1.0 200 OK\r\nContent-Type: %s\r\nContent-Length: %d\r\n\r\n",
               tipo_de($f), length($b);
        print $c $b;
    } else {
        my $b = "no esta: $ruta";
        printf $c "HTTP/1.0 404 Not Found\r\nContent-Type: text/plain\r\nContent-Length: %d\r\n\r\n",
               length($b);
        print $c $b;
    }
    close $c;
}
