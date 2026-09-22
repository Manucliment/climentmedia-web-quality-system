#!/usr/bin/env perl
# =============================================================================
#  fake-production.pl · una "produccion" local para los hosts .example
# =============================================================================
#    perl fake-production.pl <raiz-de-sitios> <puerto> <centinela> [<log>]
#
#  🔴 POR QUE EXISTE (22-sep-2026). Casi la mitad de qa-master-tests medía webs
#     que este repositorio no puede traer: capturas de clientes reales (no se
#     publican) y climentmedia.com EN VIVO (cambia sola: varios controles ya
#     habian caducado porque la web se arreglo). Al anonimizar el repo, los
#     hosts pasaron a llamarse `site-a.example`..., que NO RESUELVEN NUNCA
#     (RFC 2606): 89 casos y un bloque de 14 no los podia correr nadie.
#     Este servidor contesta por esos hosts con arboles SINTETICOS del propio
#     repo (`fixtures-sites/<host>/`), con las cabeceras de una produccion de
#     verdad: codigo de estado, tipo, gzip, Cache-Control.
#
#  COMO SE USA: el banco exporta `http_proxy=http://127.0.0.1:<puerto>`, y curl
#     le manda aqui cada peticion HTTP en forma absoluta (`GET http://host/ruta`).
#     El host decide la carpeta. Asi los casos conservan su nombre de host.
#     · Un host sin carpeta     -> 502. Un .example sin fixture no se inventa.
#     · CONNECT (https)         -> 403 al instante. Ningun tercero HTTPS sale a
#                                  internet: el banco entero queda hermetico.
#     · /_centinela-produccion  -> devuelve <centinela>. El banco lo comprueba
#                                  antes de creerse que el puerto es suyo.
#
#  CONFIGURACION POR SITIO (opcional): <raiz>/<host>/_prod.txt, una por linea:
#  (⚠️ .txt y no .conf: el .gitignore de este repo ignora `*.conf` para que las
#   configuraciones privadas no se publiquen, y la primera version se llamaba
#   _prod.conf. El banco pasaba en esta maquina y habria fallado en un clon
#   limpio: los tres ficheros no estaban en git. Medido antes de publicar.)
#     gzip off                      no comprimir nunca (por defecto: SI, si el
#                                   cliente lo acepta y el tipo es de texto)
#     header <ruta> <Nombre: valor> cabecera extra; <ruta> es exacta o termina en *
#     status <ruta> <codigo>        forzar el codigo (el cuerpo se sirve igual)
#  Los ficheros que empiezan por `_` no se sirven nunca.
#
#  Solo modulos del nucleo: en esta maquina no hay python, y en la de quien
#  clone esto puede que tampoco.
# =============================================================================
use strict; use warnings;
use IO::Socket::INET;
use IO::Compress::Gzip qw(gzip $GzipError);

my ($RAIZ, $PUERTO, $CENTINELA, $LOG) = @ARGV;
die "uso: fake-production.pl <raiz-de-sitios> <puerto> <centinela> [<log>]\n"
    unless defined $RAIZ && defined $PUERTO && defined $CENTINELA && -d $RAIZ;

# 🔴 SIN ReuseAddr, A PROPOSITO (misma leccion que receipt-tests/test-server.pl):
#    en Windows deja que DOS procesos escuchen en el mismo puerto sin error, y
#    contesta el que estaba antes. Un puerto ocupado tiene que morir aqui.
my $s = IO::Socket::INET->new(LocalAddr => '127.0.0.1', LocalPort => $PUERTO,
                              Proto => 'tcp', Listen => 32)
    or die "no puedo escuchar en $PUERTO: $!\n";
$| = 1;
print "listo\n";

my %TIPO = (
    html => 'text/html; charset=utf-8', htm => 'text/html; charset=utf-8',
    css  => 'text/css; charset=utf-8',  js  => 'application/javascript; charset=utf-8',
    mjs  => 'application/javascript; charset=utf-8',
    json => 'application/json',         xml => 'application/xml; charset=utf-8',
    txt  => 'text/plain; charset=utf-8', svg => 'image/svg+xml',
    png  => 'image/png', jpg => 'image/jpeg', jpeg => 'image/jpeg', gif => 'image/gif',
    webp => 'image/webp', avif => 'image/avif', ico => 'image/x-icon',
    woff2 => 'font/woff2', woff => 'font/woff', pdf => 'application/pdf',
    php  => 'text/html; charset=utf-8',
);
my %TEXTO = map { $_ => 1 } qw(html htm css js mjs json xml txt svg php);

my %RAZON = (200 => 'OK', 301 => 'Moved Permanently', 302 => 'Found',
             403 => 'Forbidden', 404 => 'Not Found', 405 => 'Method Not Allowed',
             410 => 'Gone', 500 => 'Internal Server Error', 502 => 'Bad Gateway');

sub leer { my ($f) = @_; open my $h, '<:raw', $f or return undef; local $/; my $x = <$h>; close $h; return defined $x ? $x : '' }

sub conf {
    my ($raiz) = @_;
    my %c = (gzip => 1, header => [], status => {});
    my $t = leer("$raiz/_prod.txt");
    return \%c unless defined $t;
    for my $l (split /\r?\n/, $t) {
        next if $l =~ /^\s*(#|$)/;
        if    ($l =~ /^\s*gzip\s+off\s*$/i)                  { $c{gzip} = 0 }
        elsif ($l =~ /^\s*header\s+(\S+)\s+(.+?)\s*$/i)      { push @{$c{header}}, [$1, $2] }
        elsif ($l =~ /^\s*status\s+(\S+)\s+(\d{3})\s*$/i)    { $c{status}{$1} = $2 }
    }
    return \%c;
}

sub casa { my ($patron, $ruta) = @_; return $patron =~ /^(.*)\*$/ ? index($ruta, $1) == 0 : $patron eq $ruta }

sub responder {
    my ($c, $cod, $cab, $cuerpo, $head) = @_;
    my $r = $RAZON{$cod} // 'Status';
    my $h = "HTTP/1.1 $cod $r\r\nConnection: close\r\nContent-Length: " . length($cuerpo) . "\r\n";
    $h .= "$_\r\n" for @$cab;
    print $c $h . "\r\n" . ($head ? '' : $cuerpo);
}

sub anotar {
    return unless defined $LOG;
    if (open my $l, '>>', $LOG) { print $l join("\t", @_), "\n"; close $l }
}

while (my $c = $s->accept) {
    my $linea = <$c>;
    unless (defined $linea) { close $c; next }
    $linea =~ s/\r?\n\z//;
    my ($met, $obj) = split /\s+/, $linea;
    my %h;
    while (defined(my $x = <$c>)) {
        last if $x =~ /^\r?\n\z/;
        $h{lc $1} = $2 if $x =~ /^([A-Za-z0-9-]+):\s*(.*?)\r?\n?\z/;
    }
    $met //= ''; $obj //= '/';
    if ($met eq 'CONNECT') {
        anotar('CONNECT', $obj, 403);
        responder($c, 403, ['Content-Type: text/plain'], "https no se sirve aqui\n", 0);
        close $c; next;
    }
    my ($host, $ruta);
    if ($obj =~ m{^http://([^/]+)(/.*)?\z}i) { ($host, $ruta) = ($1, $2 // '/') }
    else                                      { ($host, $ruta) = ($h{host} // '', $obj) }
    $host = lc $host; $host =~ s/:\d+\z//;
    my $head = ($met eq 'HEAD') ? 1 : 0;

    (my $sinq = $ruta) =~ s/[?#].*\z//s;
    $sinq =~ s/%([0-9A-Fa-f]{2})/chr(hex $1)/ge;
    if ($sinq eq '/_centinela-produccion') {
        responder($c, 200, ['Content-Type: text/plain'], $CENTINELA, $head); close $c; next;
    }
    my $raiz = "$RAIZ/$host";
    if ($host eq '' || $host =~ m{[/\\]} || $host =~ /^\./ || !-d $raiz) {
        anotar($host, $ruta, 502);
        responder($c, 502, ['Content-Type: text/plain'], "sin fixture para el host '$host'\n", $head);
        close $c; next;
    }
    my $cf = conf($raiz);

    my $rel = $sinq; $rel =~ s{^/+}{};
    my $f;
    unless ($rel =~ m{(^|/)\.\.(/|\z)} || $rel =~ m{(^|/)_}) {
        my @cand = $rel eq '' ? ("$raiz/index.html")
                 : ("$raiz/$rel", "$raiz/$rel/index.html", "$raiz/$rel.html");
        ($f) = grep { -f $_ } @cand;
    }
    my ($cod, $cuerpo, $ext);
    if (defined $f) {
        $cod = 200; $cuerpo = leer($f) // '';
        ($ext) = $f =~ /\.([A-Za-z0-9]+)\z/; $ext = lc($ext // '');
    } else {
        $cod = 404;
        my $p404 = leer("$raiz/404.html");
        if (defined $p404) { $cuerpo = $p404; $ext = 'html' } else { $cuerpo = "Not Found\n"; $ext = 'txt' }
    }
    for my $p (keys %{$cf->{status}}) { $cod = $cf->{status}{$p} if casa($p, $sinq) }

    my @cab = ('Content-Type: ' . ($TIPO{$ext} // 'application/octet-stream'));
    my $acepta = $h{'accept-encoding'} // '';
    if ($cf->{gzip} && $TEXTO{$ext} && $acepta =~ /\bgzip\b/i && length $cuerpo) {
        my $z;
        if (gzip(\$cuerpo => \$z)) { $cuerpo = $z; push @cab, 'Content-Encoding: gzip', 'Vary: Accept-Encoding' }
    }
    for my $hh (@{$cf->{header}}) { push @cab, $hh->[1] if casa($hh->[0], $sinq) }
    anotar($host, $ruta, $cod);
    responder($c, $cod, \@cab, $cuerpo, $head);
    close $c;
}
