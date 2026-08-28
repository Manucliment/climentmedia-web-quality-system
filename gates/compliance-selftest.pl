#!/usr/bin/env perl
# =============================================================================
#  compliance-selftest.pl  ·  el fixture ROJO y el fixture VERDE de la matriz
# =============================================================================
#  Se corre solo:   perl compliance-selftest.pl
#  O desde el gate: perl compliance.pl --autoprueba
#
#  POR QUE EXISTE
#  --------------
#  Lo exige el propio estandar, 15-estados-y-contenido-real.md:341 (regla ES-12):
#  «Un gate se entrega con un fixture que TIENE que salir en ROJO y otro en
#  VERDE». Un gate que nadie ha visto fallar no prueba nada: prueba que no ha
#  encontrado nada, que es lo mismo que decir que no ha mirado.
#
#  Y hace falta el negativo tanto como el positivo. Un barrido que acusa a todo
#  el mundo tambien «caza» la regresion —y ya nos paso: un patron inventado
#  declaro mudas 3 routines que escribian, e iba a reescribir codigo que
#  funcionaba. Por eso aqui la afirmacion no es «ha visto el fallo» sino
#  **«ha visto EXACTAMENTE el fallo y ninguno mas»**.
#
#  QUE PRUEBA, UNA A UNA
#  ---------------------
#   P1 CONTROL POSITIVO   se rompen 5 cosas a proposito en una COPIA local y la
#                         matriz las pasa de CUMPLE a NO CUMPLE.
#   P2 CONTROL NEGATIVO   ninguna otra regla se mueve. Cero acusaciones de mas.
#   P3 CONTROL NEGATIVO   nada aparece como ARREGLADO ni como PERDIDO: una
#                         comprobacion que desaparece baja el contador de fallos
#                         igual que un arreglo, y eso nunca es una mejora.
#   P4 DETERMINISMO       la misma web medida dos veces da la MISMA matriz. Sin
#                         esto, un diff no significa nada.
#   P5 GUARDIA DE RUTA    con el `modo` mal declarado, la web queda FUERA de la
#                         matriz con su motivo — no dentro con 332 fallos falsos,
#                         que es lo que hacia el auditor viejo con site-a.
#   P6 EL CAMINO REAL     `--retro` entre las dos corridas nombra las 5 roturas.
#
#  NO TOCA NINGUNA WEB VIVA. Copia el repo a un directorio temporal, lo sirve en
#  127.0.0.1 y mide ahi. No hay red hacia fuera, no hay despliegue, y el original
#  no se abre en escritura ni una vez.
# =============================================================================

use strict;
use warnings;
use utf8;
use POSIX qw(strftime);
use File::Path qw(make_path remove_tree);
use File::Basename qw(dirname basename);
use File::Copy qw(copy);
use File::Find ();
use File::Spec;
use IO::Socket::INET;
use JSON::PP;

binmode(STDOUT, ':encoding(UTF-8)');
binmode(STDERR, ':encoding(UTF-8)');

my $DIR   = dirname(File::Spec->rel2abs($0));
my $ORIG  = $ARGV[0] || '/path/to/site-a-web';
my $SELLO = strftime('%Y%m%d-%H%M%S', localtime);
my $WORK  = File::Spec->tmpdir() . "/conformidad-autoprueba-$SELLO";

my ($OK, $KO) = (0, 0);
sub pasa { printf "  [ PASA ] %s\n", $_[0]; $OK++ }
sub falla{ printf "  [ FALLA] %s\n", $_[0]; $KO++ }
sub tit  { print "\n", "-" x 92, "\n  $_[0]\n", "-" x 92, "\n" }

print "=" x 92, "\n  AUTOPRUEBA DE LA MATRIZ DE CONFORMIDAD  ·  ", strftime('%Y-%m-%d %H:%M', localtime), "\n";
print "  origen (solo lectura): $ORIG\n  banco:                 $WORK\n", "=" x 92, "\n";
# exit 3 = NO MEDIDO, la convencion de run-all.sh. Sin repo de origen no se ha
# probado nada, y eso NO es un fallo de la matriz: es un hueco declarado. Con
# exit 2 la bateria lo contaba como banco en rojo y mandaba a buscar un defecto
# que no existe -- en una instalacion limpia este repo NO esta, por diseno.
unless (-d $ORIG) {
  print "\n  NO MEDIDO: no existe el repo de origen ($ORIG).\n";
  print "  Esto NO es un aprobado: sin origen la matriz no se ha probado.\n";
  exit 3;
}

# ── copia recursiva en Perl puro ─────────────────────────────────────────────
#  Nada de `cp -r` ni de one-liners de bash: bash NO esta en el PATH de
#  PowerShell en esta maquina, y un script que solo corre desde una consola
#  concreta se deja de correr.
sub copiar_arbol {
    my ($src, $dst) = @_;
    my $n = 0;
    File::Find::find({ no_chdir => 1, wanted => sub {
        my $p = $File::Find::name;
        my $rel = $p; $rel =~ s{^\Q$src\E/?}{};
        return if $rel eq '';
        return if $rel =~ m{(^|/)(\.git|node_modules|_migrate|_deploy)(/|$)};
        if (-d $p) { make_path("$dst/$rel") unless -d "$dst/$rel" }
        else { make_path(dirname("$dst/$rel")) unless -d dirname("$dst/$rel");
               copy($p, "$dst/$rel") and $n++ }
    }}, $src);
    return $n;
}

my $SANO = "$WORK/sano";
my $ROTO = "$WORK/roto";
my $ALCA = "$WORK/alcance";
make_path($SANO, $ROTO, $ALCA);
my $n1 = copiar_arbol($ORIG, $SANO);
my $n2 = copiar_arbol($ORIG, $ROTO);
my $n3 = copiar_arbol($ORIG, $ALCA);
printf "  copiados %d ficheros a sano/, %d a roto/ y %d a alcance/\n", $n1, $n2, $n3;

# ── LAS ROTURAS ──────────────────────────────────────────────────────────────
#  Cada una toca UN sitio y esta elegida porque hoy el sitio la CUMPLE: si el
#  fixture partiera de algo ya roto, el positivo no probaria nada.
#
#  ⚠️ NADA DE LITERALES ACENTUADOS EN LAS ROTURAS. El primer intento duplicaba el
#     <title> escribiendolo a mano en este fichero: `use utf8` lo decodifica, el
#     HTML se escribe en :raw, y el resultado fue «Kin?sith?rapie» — dos titles
#     que NO son iguales, asi que el gate acertaba al no ver duplicado y la
#     prueba acusaba al gate. Se copian los BYTES del fichero de al lado.
sub bytes_de {
    my ($f, $re) = @_;
    open my $h, '<:raw', $f or die "no puedo leer $f\n";
    local $/; my $t = <$h>; close $h;
    return $t =~ $re ? $1 : undef;
}
my $TITULO_HOME = bytes_de("$ORIG/index.html", qr{(<title>.*?</title>)}s)
    or die "no encuentro el <title> de index.html: sin el no hay fixture de duplicado\n";

my @MUT = (
  { gate=>'SEO-06',  fich=>'services.html', que=>'quitar og:image:alt (pagina interior)',
    hacer=>sub { my $t=shift; $t =~ s{<meta\s+property="og:image:alt"[^>]*>\s*\n?}{}i; $t } },
  { gate=>'SEO-09',  fich=>'services.html', que=>'quitar el <h1> (pagina interior)',
    hacer=>sub { my $t=shift; $t =~ s{<h1[^>]*>.*?</h1>}{}si; $t } },
  { gate=>'SEO-02',  fich=>'a-propos.html', que=>'duplicar el <title> de la home',
    hacer=>sub { my $t=shift; $t =~ s{<title>.*?</title>}{$TITULO_HOME}si; $t } },
  { gate=>'A11Y-01', fich=>'index.html',    que=>'quitar lang del <html> (HOME)',
    hacer=>sub { my $t=shift; $t =~ s{<html\s+lang="[^"]*"}{<html}i; $t } },
  { gate=>'A11Y-02', fich=>'index.html',    que=>'quitar el enlace de salto (HOME)',
    hacer=>sub { my $t=shift; $t =~ s{<a\s+class="skip"[^>]*>.*?</a>\s*\n?}{}si; $t } },
);

# Las MISMAS dos roturas de a11y, pero en una pagina INTERIOR y con la home
# intacta. No es un control: es una SONDA DE ALCANCE. Si la lente solo lee la
# home, aqui no se movera nada, y eso hay que saberlo con un numero.
my @SONDA = (
  { gate=>'A11Y-01', fich=>'services.html', que=>'quitar lang solo en /services',
    hacer=>sub { my $t=shift; $t =~ s{<html\s+lang="[^"]*"}{<html}i; $t } },
  { gate=>'A11Y-02', fich=>'services.html', que=>'quitar el salto solo en /services',
    hacer=>sub { my $t=shift; $t =~ s{<a\s+class="skip"[^>]*>.*?</a>\s*\n?}{}si; $t } },
);

sub aplicar {
    my ($raiz, $lista, $etiqueta) = @_;
    for my $m (@$lista) {
        my $f = "$raiz/$m->{fich}";
        open my $fh, '<:raw', $f or die "no puedo leer $f\n";
        local $/; my $t = <$fh>; close $fh;
        my $antes = $t;
        $t = $m->{hacer}->($t);
        die "la rotura '$m->{que}' NO cambio $m->{fich}: el fixture no vale.\n"
          . "   Un fixture que no rompe nada convierte el control positivo en un aprobado gratis.\n"
          if $t eq $antes;
        open my $o, '>:raw', $f or die "no puedo escribir $f\n";
        print $o $t; close $o;
        printf "  %-8s %-8s %-16s %s\n", $etiqueta, $m->{gate}, $m->{fich}, $m->{que};
    }
}
tit('ROTURAS INYECTADAS  (sano/ queda intacto)');
aplicar($ROTO, \@MUT,   'roto');
aplicar($ALCA, \@SONDA, 'alcance');

# ── servidor de medida (embebido: cero dependencias) ─────────────────────────
my %MIME = (html=>'text/html; charset=utf-8', css=>'text/css; charset=utf-8',
  js=>'text/javascript; charset=utf-8', json=>'application/json', svg=>'image/svg+xml',
  png=>'image/png', jpg=>'image/jpeg', jpeg=>'image/jpeg', webp=>'image/webp',
  ico=>'image/x-icon', woff2=>'font/woff2', woff=>'font/woff',
  txt=>'text/plain; charset=utf-8', xml=>'application/xml');

sub puerto_libre {
    my $p = shift // 8791;
    for my $i (0..40) {
        my $s = IO::Socket::INET->new(LocalAddr=>'127.0.0.1', LocalPort=>$p+$i,
                                      Proto=>'tcp', Listen=>1, ReuseAddr=>1);
        if ($s) { close $s; return $p+$i }
    }
    die "no encuentro puerto libre\n";
}

# El mapeo de rutas del servidor imita el .htaccess de site-a: /x -> x.html.
# Si el fixture se cambia por un sitio con otro modo, hay que cambiar esto TAMBIEN,
# y esa es justamente la razon de ser de P5.
sub arrancar {
    my ($root, $port) = @_;
    my $pid = fork();
    die "no puedo fork: $!\n" unless defined $pid;
    return $pid if $pid;
    my $srv = IO::Socket::INET->new(LocalAddr=>'127.0.0.1', LocalPort=>$port,
                                    Proto=>'tcp', Listen=>64, ReuseAddr=>1)
        or die "no puedo escuchar en $port: $!\n";
    while (my $c = $srv->accept) {
        $c->autoflush(1);
        my $req = <$c>; unless (defined $req) { close $c; next }
        while (my $h = <$c>) { last if $h =~ /^\r?\n$/ }
        my ($path) = $req =~ m{^GET\s+(\S+)\s+HTTP} ? ($1) : ('/');
        $path =~ s/[?#].*$//; $path = '/' if $path eq '';
        if ($path =~ /\.\./) { print $c "HTTP/1.0 403 Forbidden\r\nContent-Length: 0\r\n\r\n"; close $c; next }
        my @try = ("$root$path");
        push @try, "$root$path.html" unless $path =~ /\.[a-z0-9]+$/i;
        push @try, "$root/index.html" if $path eq '/';
        my $file; for my $t (@try) { if (-f $t) { $file = $t; last } }
        if (!$file) {
            my $b = -f "$root/404.html" ? do { open my $h,'<:raw',"$root/404.html"; local $/; <$h> } : '';
            print $c "HTTP/1.0 404 Not Found\r\nContent-Type: text/html; charset=utf-8\r\n"
                   . "Content-Length: " . length($b) . "\r\nConnection: close\r\n\r\n$b";
            close $c; next;
        }
        my ($ext) = $file =~ /\.([a-z0-9]+)$/i; $ext = lc($ext || 'txt');
        open(my $fh, '<:raw', $file) or do { print $c "HTTP/1.0 500\r\nContent-Length: 0\r\n\r\n"; close $c; next };
        local $/; my $body = <$fh>; close $fh;
        print $c "HTTP/1.0 200 OK\r\nContent-Type: " . ($MIME{$ext}//'application/octet-stream')
               . "\r\nContent-Length: " . length($body)
               . "\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n";
        print $c $body; close $c;
    }
    exit 0;
}

my $PS = puerto_libre(8791);
my $PR = puerto_libre($PS + 1);
my $PA = puerto_libre($PR + 1);
my $pid_s = arrancar($SANO, $PS);
my $pid_r = arrancar($ROTO, $PR);
my $pid_a = arrancar($ALCA, $PA);
END { kill 'TERM', $_ for grep { $_ } ($pid_s, $pid_r, $pid_a) }
select undef, undef, undef, 0.7;   # que los hijos lleguen a escuchar

sub vivo {
    my $p = shift;
    my $s = IO::Socket::INET->new(PeerAddr=>'127.0.0.1', PeerPort=>$p, Proto=>'tcp', Timeout=>3) or return 0;
    close $s; return 1;
}
for my $par (['sano',$PS], ['roto',$PR], ['alcance',$PA]) {
    die "el servidor de $par->[0]/ no responde en $par->[1]\n" unless vivo($par->[1]);
}
printf "  sano/ :%d   ·   roto/ :%d   ·   alcance/ :%d\n", $PS, $PR, $PA;

# ── .conf de la prueba ───────────────────────────────────────────────────────
sub escribir_conf {
    my ($f, $dom, $repo, $modo) = @_;
    open my $h, '>:encoding(UTF-8)', $f or die "no puedo escribir $f\n";
    print $h "[web]\nnombre = fixture\ndominio = $dom\nrepo = $repo\nmodo = $modo\n"
           . "contacto = /contact\ngracias = /merci\nmax_urls = 25\n";
    close $h;
}
escribir_conf("$WORK/sano.conf",    "http://127.0.0.1:$PS", $SANO, 'plano-sin-ext');
escribir_conf("$WORK/roto.conf",    "http://127.0.0.1:$PR", $ROTO, 'plano-sin-ext');
escribir_conf("$WORK/alcance.conf", "http://127.0.0.1:$PA", $ALCA, 'plano-sin-ext');
escribir_conf("$WORK/malmodo.conf", "http://127.0.0.1:$PS", $SANO, 'dir-barra');

sub correr {
    my ($conf, $json, $salida) = @_;
    my @cmd = ($^X, "$DIR/compliance.pl", '--conf', $conf, '--json', $json,
               '--salida', $salida, '--sin-guardar', '-q');
    my $out = '';
    if (open my $ph, '-|', @cmd) { local $/; $out = <$ph> // ''; close $ph }
    return ($out, $? >> 8);
}
sub leer { my $f=shift; open my $h,'<:raw',$f or return undef; local $/; my $x=<$h>; close $h;
           return eval { JSON::PP->new->utf8->decode($x) } }

tit('MIDIENDO  (dos corridas: sano y roto)');
my ($o1) = correr("$WORK/sano.conf", "$WORK/m-sano.json",  "$WORK/run-sano");
my ($o2) = correr("$WORK/roto.conf", "$WORK/m-roto.json",  "$WORK/run-roto");
my $SA = leer("$WORK/m-sano.json") or die "sin matriz de sano\n";
my $RO = leer("$WORK/m-roto.json") or die "sin matriz de roto\n";
printf "  sano: %d reglas · roto: %d reglas\n", scalar(@{$SA->{reglas}}), scalar(@{$RO->{reglas}});

# ── que se espera que cambie ────────────────────────────────────────────────
#  No se escribe a mano una lista de reglas: se DERIVA de los gates rotos, para
#  que la prueba siga valiendo cuando el estandar cambie de numeracion.
my %gate_roto = map { $_->{gate} => 1 } @MUT;
sub gates_de_texto {
    my $t = shift // ''; my @g;
    push @g, uc($1).'-'.$2.($3//'') while $t =~ /\b(seo|ren|a11y|med|est)-(\d+)([a-z]?)\b/gi;
    return @g;
}
my %ESPERADO;
for my $r (@{ $SA->{reglas} }) {
    next unless grep { $gate_roto{$_} } gates_de_texto($r->{gate});
    next unless ($SA->{matriz}{$r->{id}}{web}{estado} // '') eq 'cumple';
    $ESPERADO{$r->{id}} = $r->{gate};
}

# ── cambios observados ───────────────────────────────────────────────────────
my (%flip, %arreglado, %perdido, %otros);
for my $r (@{ $SA->{reglas} }) {
    my $id = $r->{id};
    my $a = $SA->{matriz}{$id}{web} or next;
    my $b = $RO->{matriz}{$id}{web} or do { $perdido{$id} = 'la regla desaparecio'; next };
    next if $a->{estado} eq $b->{estado};
    if    ($a->{estado} eq 'cumple'     && $b->{estado} eq 'no_cumple')  { $flip{$id} = 1 }
    elsif ($a->{estado} eq 'no_cumple'  && $b->{estado} eq 'cumple')     { $arreglado{$id} = 1 }
    elsif ($a->{estado} =~ /^(cumple|no_cumple|aviso)$/ && $b->{estado} eq 'no_medible') { $perdido{$id} = $b->{motivo} }
    else { $otros{$id} = "$a->{estado} -> $b->{estado}" }
}

tit('P1 · CONTROL POSITIVO  ·  la matriz caza lo que se ha roto');
printf "  gates rotos: %s\n", join(' ', map { $_->{gate} } @MUT);
printf "  reglas del estandar atadas a esos gates y que sano/ CUMPLE: %d\n\n", scalar(keys %ESPERADO);
for my $id (sort keys %ESPERADO) {
    if ($flip{$id}) {
        my ($r) = grep { $_->{id} eq $id } @{ $SA->{reglas} };
        my $d = $RO->{matriz}{$id}{web}{detalle} // '';
        printf "  [ PASA ] %-9s cumple -> NO CUMPLE   %s\n", $id, substr($d, 0, 44);
        printf "           %-9s %s\n", '', substr(($r->{texto}//''), 0, 74);
        $OK++;
    } else {
        printf "  [ FALLA] %-9s NO se movio: sigue en '%s'. La matriz no ve la rotura.\n",
            $id, ($RO->{matriz}{$id}{web}{estado} // '?');
        $KO++;
    }
}
falla("ninguna regla del estandar mira los gates rotos: el fixture no prueba nada") unless %ESPERADO;

tit('P2 · CONTROL NEGATIVO  ·  no acusa a quien cumple');
my @demas = sort grep { !$ESPERADO{$_} } keys %flip;
if (@demas) {
    falla(sprintf("%d reglas se han puesto en rojo SIN que se rompiera su gate: %s", scalar(@demas), join(' ', @demas)));
    for my $id (@demas) { printf "           %-9s gate=%s  detalle=%s\n", $id,
        ($RO->{matriz}{$id}{web}{gate}//'?'), substr(($RO->{matriz}{$id}{web}{detalle}//''),0,50) }
} else {
    pasa(sprintf("0 acusaciones de mas. Se movieron %d reglas y las %d eran las esperadas.",
                 scalar(keys %flip), scalar(keys %ESPERADO)));
}
my $sigue = 0;
for my $r (@{ $SA->{reglas} }) {
    my $id = $r->{id};
    next if $ESPERADO{$id};
    $sigue++ if (($SA->{matriz}{$id}{web}{estado}//'') eq 'cumple'
             &&  ($RO->{matriz}{$id}{web}{estado}//'') eq 'cumple');
}
pasa("$sigue reglas que cumplian siguen cumpliendo, sin tocarlas");

tit('P3 · CONTROL NEGATIVO  ·  ni arreglos fantasma ni comprobaciones perdidas');
if (%arreglado) { falla("la matriz dice que se ARREGLARON reglas que nadie toco: " . join(' ', sort keys %arreglado)) }
else            { pasa("0 arreglos fantasma") }
if (%perdido)   { falla("comprobaciones PERDIDAS (bajan el rojo sin arreglar nada): "
                        . join(' ', map { "$_($perdido{$_})" } sort keys %perdido)) }
else            { pasa("0 comprobaciones perdidas") }
if (%otros)     { printf "  [ nota ] cambios de otro tipo: %s\n", join(' ', map {"$_ $otros{$_}"} sort keys %otros) }

tit('P3-bis · SONDA DE ALCANCE  ·  ¿la lente mira mas alla de la home?');
# La lista de gates «home-only» vive en compliance.pl. Se lee de ahi, no se
# copia: dos copias de la misma lista derivan, y la que deriva es siempre la que
# nadie mira.
my %DECLARADO_HOME;
{
    open my $h, '<:encoding(UTF-8)', "$DIR/compliance.pl" or die "no puedo leer compliance.pl\n";
    local $/; my $src = <$h>; close $h;
    if ($src =~ /my \%HOME_ONLY = map \{ \$_ => 1 \} qw\(([^)]*)\)/s) {
        %DECLARADO_HOME = map { $_ => 1 } split /\s+/, ($1 =~ s/^\s+|\s+$//gr);
    }
    printf "  compliance.pl declara %d gates como home-only.\n", scalar(keys %DECLARADO_HOME);
}
print "  Las MISMAS dos roturas de a11y, ahora solo en /services, con la home intacta.\n";
print "  Si el gate no las ve, el sitio puede tener 12 paginas rotas y salir en verde.\n\n";
my ($oA) = correr("$WORK/alcance.conf", "$WORK/m-alcance.json", "$WORK/run-alcance");
my $AL = leer("$WORK/m-alcance.json");
my $ciegos = 0;
if (!$AL) { falla("la corrida de alcance/ no dejo matriz") }
else {
    my %sonda = map { $_->{gate} => $_ } @SONDA;
    for my $g (sort keys %sonda) {
        my ($est_s, $est_a, $rid);
        for my $r (@{ $SA->{reglas} }) {
            next unless grep { $_ eq $g } gates_de_texto($r->{gate});
            next unless ($SA->{matriz}{$r->{id}}{web}{estado}//'') eq 'cumple';
            $rid = $r->{id};
            $est_s = $SA->{matriz}{$r->{id}}{web}{estado};
            $est_a = $AL->{matriz}{$r->{id}}{web}{estado};
            last;
        }
        next unless $rid;
        if (($est_a//'') eq 'no_cumple') {
            printf "  [ PASA ] %-8s la lente lee tambien las interiores (%s se puso en rojo)\n", $g, $rid;
            $OK++;
            # Si compliance.pl sigue declarandolo home-only, su lista ha caducado.
            if ($DECLARADO_HOME{$g}) {
                falla("compliance.pl declara $g como home-only y ya NO lo es: quitalo de \%HOME_ONLY, "
                    . "o la matriz seguira rebajando un CUMPLE que ya es del sitio entero");
            }
        } else {
            $ciegos++;
            printf "  [HALLAZGO] %-8s PUNTO CIEGO: la rotura esta en /services y el gate sigue en verde.\n", $g;
            printf "             %s\n", $sonda{$g}{que};
            printf "             qa-master.pl · lente_a11y() lee solo \$URLS[0]: la lente de\n";
            printf "             accesibilidad es HOME-ONLY. %s se acredita con 1 pagina de 13.\n", $rid;
            if ($DECLARADO_HOME{$g}) { pasa("  ... y compliance.pl ya lo declara home-only: la matriz lo marca") }
            else { falla("  ... y compliance.pl NO lo declara home-only: anade $g a \%HOME_ONLY") }
        }
    }
}

tit('P4 · DETERMINISMO  ·  medir dos veces lo mismo da lo mismo');
my ($o3) = correr("$WORK/sano.conf", "$WORK/m-sano2.json", "$WORK/run-sano2");
my $SB = leer("$WORK/m-sano2.json");
if (!$SB) { falla("la segunda corrida de sano/ no dejo matriz") }
else {
    my @dif;
    for my $r (@{ $SA->{reglas} }) {
        my $id = $r->{id};
        my $x = $SA->{matriz}{$id}{web}{estado} // '';
        my $y = $SB->{matriz}{$id}{web}{estado} // '';
        push @dif, "$id $x->$y" if $x ne $y;
    }
    if (@dif) { falla(sprintf("%d celdas cambian entre dos medidas identicas: %s", scalar(@dif), join(' ', @dif[0..($#dif>5?5:$#dif)]))) }
    else      { pasa(sprintf("las %d celdas coinciden en las dos corridas", scalar(@{$SA->{reglas}}))) }
}

tit('P5 · GUARDIA DE RUTA  ·  el modo mal declarado deja la web FUERA, no dentro con ruido');
my ($o5, $rc5) = correr("$WORK/malmodo.conf", "$WORK/m-mal.json", "$WORK/run-mal");
my $MM = leer("$WORK/m-mal.json");
my $err = $MM ? ($MM->{detalle_web}{web}{error} // '') : '';
if ($err =~ /modo de ruta/) {
    pasa("declarando 'dir-barra' sobre un sitio 'plano-sin-ext', la web queda fuera:");
    printf "           %s\n", $err;
    my $nc = 0; $nc += ($MM->{recuento}{web}{no_cumple} // 0);
    if ($nc == 0) { pasa("y no se ha inventado ni un solo NO CUMPLE (el auditor viejo se invento 332)") }
    else          { falla("aun asi ha producido $nc celdas en NO CUMPLE") }
    if ($rc5 == 2){ pasa("exit 2 = no se pudo medir, que no es lo mismo que un aprobado") }
    else          { falla("exit $rc5; deberia ser 2") }
} else {
    falla("con el modo mal declarado la web ENTRO en la matriz. error='" . substr($err,0,60) . "'");
}

tit('P6 · EL CAMINO REAL  ·  --retro nombra las roturas');
my @cmd = ($^X, "$DIR/compliance.pl", '--retro', "$WORK/m-sano.json",
           '--historial', $WORK, '--conf', "$WORK/roto.conf");
# --retro compara el ULTIMO snapshot del historial contra el fichero dado; se
# deja el de roto/ como ultimo snapshot del historial de la prueba.
{
    my $j = leer("$WORK/m-roto.json");
    $j->{sello} = strftime('%Y-%m-%d-%H%M', localtime);
    open my $h, '>:raw', "$WORK/conformidad-" . $j->{sello} . ".json";
    print $h JSON::PP->new->utf8->canonical->pretty->encode($j); close $h;
}
my $rout = '';
if (open my $ph, '-|', @cmd) { local $/; $rout = <$ph> // ''; close $ph }
my @nombradas = grep { $rout =~ /^\s+\Q$_\E\s+web\s*$/m } sort keys %ESPERADO;
if (@nombradas == scalar(keys %ESPERADO)) {
    pasa(sprintf("--retro las lista como ROTO: %s", join(' ', @nombradas)));
} else {
    falla(sprintf("--retro nombro %d de %d: %s", scalar(@nombradas), scalar(keys %ESPERADO), join(' ', @nombradas)));
    print map { "           $_\n" } grep { /ROTO|PERDIDO|ARREGLADO/ } split /\n/, $rout;
}

# ── veredicto ────────────────────────────────────────────────────────────────
print "\n", "=" x 92, "\n";
printf "  AUTOPRUEBA: %s      %d pasan  ·  %d fallan\n", ($KO ? 'FALLA' : 'PASA'), $OK, $KO;
# 🔴 18-ago-2026 · La linea de arriba dice «18 pasan · 0 fallan» y `run-all.sh`
#  no sabe leerla: busca «OK n · MAL n» y sus dos variantes. Si este banco se
#  cablea sin esto, el runner imprime «no he sabido leer su recuento» y suma CERO
#  casos -- un cero con cara de aprobado, que es justo lo que su propio comentario
#  dice que ya paso una vez con el banco del hook.
printf "  OK %d · MAL %d\n", $OK, $KO;
printf "  %d PUNTOS CIEGOS MEDIDOS en el instrumento (no son fallos de la matriz: son\n", $ciegos if $ciegos;
printf "  agujeros de qa-master.pl que esta prueba deja escritos con su numero).\n" if $ciegos;
print  "  banco conservado en $WORK\n";
print  "  Ninguna web viva se ha tocado: todo ha ocurrido en 127.0.0.1 sobre una copia.\n";
print  "=" x 92, "\n";
exit($KO ? 1 : 0);
