#!/usr/bin/env perl
# =============================================================================
#  redirects-gate.pl — EL GATE DE UN ARBOL QUE SOLO REDIRIGE
# =============================================================================
#  2-nov-2026 · POR QUE EXISTE. Un dominio viejo se retira: su docroot pasa a ser
#  un robots.txt y un .htaccess que manda cada ruta del mapa a su pagina de la web
#  nueva y TODO lo demas a la portada, con 301. qa-master.pl no tiene nada que
#  medir ahi —no hay ni una pagina—, sus cinco lentes salen NO VERIFICADAS y la
#  puerta rechaza el recibo, con razon: «cinco lentes sin medir» no es un verde.
#  Mientras tanto el WordPress viejo seguia sirviendo /wp-login.php.
#
#  Lo que se hacia para salir del paso era peor que el problema: meter una pagina
#  de relleno para que las lentes midieran algo (hacerle trampa al gate), o subir
#  por fuera de la puerta. Este gate mide LO QUE ESE ARBOL ES:
#
#    RED-01  el .htaccess existe y este programa sabe leer cada directiva
#    RED-02  el arbol no lleva paginas ni nada que se ejecute
#    RED-03  la ULTIMA regla es un comodin sin condiciones que redirige todo
#    RED-04  cada redireccion es 301/308 con L, a https y fuera de este dominio
#    RED-05  cada regla del mapa la alcanza su propia ruta (ninguna de antes la tapa)
#    RED-06  las rutas de WordPress y PHP acaban en una redireccion, no en el disco
#    RED-07  lo que se deja servir es solo el arbol y .well-known/acme-challenge/
#    RED-08  cada fichero del arbol se sirve (ninguna redireccion lo tapa)
#    RED-09  candidato: cada destino contesta 200 (se pide con GET, sin seguir)
#    RED-10  servido:   cada sonda contesta en el dominio lo que dice el .htaccess
#
#  RED-01..08 salen de SIMULAR las reglas en orden, como las aplica el servidor en
#  un .htaccess (ruta sin la barra inicial, primera regla con L que casa gana).
#  🔴 Fail-closed: lo que no se sabe leer es un FALLO, no un aviso. Este gate cubre
#  una forma concreta de arbol; si el .htaccess trae algo mas (RewriteCond,
#  Redirect de mod_alias, reescrituras internas), se dice y no se aprueba.
#
#  uso:
#    perl redirects-gate.pl --repo DIR --sitio URL --candidato   # mide y escribe .qa-recibo
#    perl redirects-gate.pl --repo DIR --sitio URL --servido     # pide las sondas al dominio
#    (alias: --site, --candidate, --served)
#  --permitir-http   solo para los bancos: acepta destinos http://. El recibo lo
#                    lleva escrito bajo el sello y la puerta lo rechaza.
#
#  exit: 0 PASA · 1 FALLA · 2 uso · 3 NO MEDIDO (no se pudo pedir nada)
# =============================================================================
use strict;
use warnings;
use utf8;
use Cwd qw(abs_path);
use File::Basename qw(dirname);

my $MIDIR_RG = dirname(abs_path(__FILE__));
require "$MIDIR_RG/receipt.pl";   # arbol(), receptores(), escribe_recibo(), $UA, binmode

# Lo que un WordPress (o cualquier PHP) deja en el disco y NO puede servirse.
# '' es la portada. La ultima se fabrica en cada corrida: una ruta que no existe.
my @SONDAS_PELIGRO = ('', 'wp-login.php', 'wp-admin/', 'wp-admin/install.php',
                      'xmlrpc.php', 'index.php', 'wp-json/', 'feed/',
                      'wp-content/uploads/qa-sonda.php', 'wp-includes/qa-sonda.php');

my @DIRECTIVAS_INOCUAS = qw(Options DirectoryIndex);

exit(rg_main()) unless caller;

sub rg_main {
    my %o;
    my %ALIAS = ('--site' => '--sitio', '--candidate' => '--candidato',
                 '--served' => '--servido', '--allow-http' => '--permitir-http');
    my @a = map { $ALIAS{$_} // $_ } @ARGV;
    while (@a) {
        my $x = shift @a;
        if    ($x =~ /^--(repo|sitio|horas)$/)          { $o{$1} = shift @a }
        elsif ($x =~ /^--(candidato|servido|permitir-http)$/) { $o{$1} = 1 }
        else  { print "opcion no reconocida: $x\n"; return 2 }
    }
    unless ($o{repo} && -d $o{repo} && $o{sitio} && ($o{candidato} xor $o{servido})) {
        print "uso: perl redirects-gate.pl --repo DIR --sitio URL (--candidato | --servido)\n";
        return 2;
    }
    my $repo  = main::norm_ruta($o{repo});
    my $sitio = $o{sitio}; $sitio =~ s{/+$}{};
    # host y puerto: el mismo host en otro puerto es otro sitio (lo usan los bancos)
    my ($host_sitio) = $sitio =~ m{^https?://([^/?#]+)}i;
    unless ($host_sitio) { print "--sitio tiene que ser una URL entera: $sitio\n"; return 2 }

    print "==============================================================================\n";
    printf "  REDIRECCIONES · %s · %s\n", $sitio, ($o{candidato} ? 'CANDIDATO' : 'SERVIDO');
    print "==============================================================================\n";

    my (@fallos, @nv, %pasa);
    my $falla = sub { my ($id, $t) = @_; push @fallos, [$id, $t] };

    # ── RED-01 · leer ────────────────────────────────────────────────────────
    my $ht = rg_htaccess($repo);
    unless ($ht) {
        $falla->('RED-01', 'no hay .htaccess: ni en la raiz del arbol ni declarado en PHP_EN_PRODUCCION como «…:.htaccess»');
        return rg_cierra(\%o, $repo, $sitio, \@fallos, \@nv, \%pasa, undef);
    }
    my ($reglas, $no_leo) = rg_lee($ht->{ruta});
    $falla->('RED-01', $_) for @$no_leo;
    $pasa{'RED-01'} = 1 unless @$no_leo;
    printf "  .htaccess   %s  (%d reglas)\n", $ht->{repo}, scalar(@$reglas);

    # ── RED-02 · el arbol no lleva paginas ───────────────────────────────────
    my ($man) = main::arbol($repo);
    my @fich  = map { $_->[0] } @$man;
    my @pag   = main::paginas_ejecutables($man);
    my @otros = grep { $_->{prod} ne '.htaccess' } main::receptores($repo);
    $falla->('RED-02', "el arbol lleva una pagina o algo que se ejecuta: $_") for @pag;
    $falla->('RED-02', "receptor que no es el .htaccess: $_->{repo} -> $_->{prod}") for @otros;
    $pasa{'RED-02'} = 1 unless @pag || @otros;
    printf "  arbol       %d fichero%s: %s\n", scalar(@fich), (@fich == 1 ? '' : 's'),
           (@fich ? join(' ', @fich[0 .. ($#fich > 5 ? 5 : $#fich)]) . (@fich > 6 ? ' …' : '') : '(vacio)');

    # Las reglas ilegibles no se simulan: no se sabe que hacen.
    if (@$no_leo) {
        return rg_cierra(\%o, $repo, $sitio, \@fallos, \@nv, \%pasa, undef);
    }

    # ── RED-04 · cada redireccion, de una en una ─────────────────────────────
    my $ok04 = 1;
    for my $r (grep { $_->{tipo} eq 'redirige' } @$reglas) {
        my $donde = "linea $r->{linea}";
        if ($r->{codigo} !~ /^30[18]$/) {
            $falla->('RED-04', "$donde: redirige con $r->{codigo}, temporal: los buscadores no pasan la autoridad"); $ok04 = 0;
        }
        unless ($r->{L}) {
            $falla->('RED-04', "$donde: redireccion sin L; el servidor sigue aplicando reglas sobre su resultado"); $ok04 = 0;
        }
        my ($esq, $h) = $r->{destino} =~ m{^(https?)://([^/?#]+)}i;
        if (!$esq) {
            $falla->('RED-04', "$donde: el destino no es una URL entera: $r->{destino}"); $ok04 = 0;
        } else {
            if (lc $esq ne 'https' && !$o{'permitir-http'}) {
                $falla->('RED-04', "$donde: destino sin https: $r->{destino}"); $ok04 = 0;
            }
            if (lc $h eq lc $host_sitio) {
                $falla->('RED-04', "$donde: redirige a este mismo dominio ($h): un arbol que solo redirige no tiene paginas propias"); $ok04 = 0;
            }
        }
    }
    $pasa{'RED-04'} = 1 if $ok04;

    # ── RED-03 · el comodin ──────────────────────────────────────────────────
    my $ultima = $reglas->[-1];
    my $azar   = 'qa-ruta-que-no-existe-' . time();
    my @todo   = (@SONDAS_PELIGRO, $azar, 'x', 'a/b/c.php', 'robots.txt.bak');
    if (!$ultima || $ultima->{tipo} ne 'redirige') {
        $falla->('RED-03', 'la ultima regla no es una redireccion: lo que no case con el mapa se sirve del disco');
    } elsif (my @no = grep { !rg_casa($ultima, $_) } @todo) {
        $falla->('RED-03', "la ultima regla (linea $ultima->{linea}) no casa con todo: no casa «/$no[0]»");
    } else {
        $pasa{'RED-03'} = 1;
    }

    # ── RED-05 y RED-07 · el mapa y lo que se deja servir ────────────────────
    my (@sondas, $ok05, $ok07);
    $ok05 = $ok07 = 1;
    for my $i (0 .. $#$reglas) {
        my $r = $reglas->[$i];
        next if $r == $ultima;
        if ($r->{tipo} eq 'sirve') {
            if ($r->{patron} =~ m{^\^?\\?\.well-known/acme-challenge/$}) { next }
            my $ej = rg_ejemplo($r);
            if (!defined $ej) {
                $falla->('RED-07', "linea $r->{linea}: deja servir «$r->{patron}», que no es una ruta fija: no se sabe que mas deja pasar");
                $ok07 = 0; next;
            }
            unless (grep { $_ eq $ej } @fich) {
                $falla->('RED-07', "linea $r->{linea}: deja servir /$ej, que no esta en el arbol: se serviria lo que quede en el disco");
                $ok07 = 0;
            }
            next;
        }
        my $ej = rg_ejemplo($r);
        if (!defined $ej) {
            $falla->('RED-05', "linea $r->{linea}: no se fabricar una ruta de ejemplo para «$r->{patron}»: esta regla no se puede comprobar");
            $ok05 = 0; next;
        }
        my $res = rg_simula($reglas, $ej);
        if (($res->{regla} // -1) != $i) {
            $falla->('RED-05', sprintf("linea %d: /%s no llega a su regla; la tapa la linea %s", $r->{linea}, $ej,
                                       defined $res->{regla} ? $reglas->[$res->{regla}]{linea} : '(ninguna)'));
            $ok05 = 0; next;
        }
        push @sondas, { ruta => $ej, espera => $res, por => 'mapa' };
    }
    $pasa{'RED-05'} = 1 if $ok05;
    $pasa{'RED-07'} = 1 if $ok07;

    # ── RED-06 · WordPress y PHP no llegan al disco ──────────────────────────
    my $ok06 = 1;
    for my $p (@SONDAS_PELIGRO, $azar) {
        my $res = rg_simula($reglas, $p);
        if ($res->{tipo} ne 'redirige') {
            $falla->('RED-06', sprintf("/%s %s", $p,
                     $res->{tipo} eq 'sirve' ? "lo deja servir la linea $reglas->[$res->{regla}]{linea}"
                                             : 'no lo coge ninguna regla: se serviria del disco'));
            $ok06 = 0; next;
        }
        push @sondas, { ruta => $p, espera => $res, por => 'peligro' } unless $p eq $azar;
    }
    $pasa{'RED-06'} = 1 if $ok06;

    # ── RED-08 · cada fichero del arbol se sirve ─────────────────────────────
    my $ok08 = 1;
    for my $f (@fich) {
        my $res = rg_simula($reglas, $f);
        if ($res->{tipo} ne 'sirve') {
            $falla->('RED-08', "/$f esta en el arbol y no se serviria: " .
                     ($res->{tipo} eq 'redirige' ? "lo redirige la linea $reglas->[$res->{regla}]{linea}" : 'ninguna regla lo deja pasar'));
            $ok08 = 0; next;
        }
        push @sondas, { ruta => $f, espera => $res, por => 'arbol' };
    }
    $pasa{'RED-08'} = 1 if $ok08;

    my %medida = (reglas => scalar(grep { $_->{tipo} eq 'redirige' } @$reglas) - ($ultima && $ultima->{tipo} eq 'redirige' ? 1 : 0),
                  comodin => ($pasa{'RED-03'} ? 'SI' : 'NO'),
                  sondas => scalar(@sondas), htaccess => $ht->{repo});
    printf "  simulado    %d reglas del mapa + comodin · %d sondas\n", $medida{reglas}, $medida{sondas};

    # ── RED-09 / RED-10 · lo que solo contesta la red ────────────────────────
    if ($o{candidato}) {
        my %dest;
        $dest{ $_->{espera}{location} } = 1 for grep { $_->{espera}{tipo} eq 'redirige' } @sondas;
        my ($ok, $cad, @mal) = (0, 0);
        for my $u (sort keys %dest) {
            my ($c, $loc) = rg_pide($u);
            if ($c eq '200') { $ok++; next }
            if ($c =~ /^30[1278]$/ && $loc && rg_host($loc) eq rg_host($u)) {
                my ($c2) = rg_pide($loc);
                if ($c2 eq '200') { $ok++; $cad++; print "  ⚠ cadena   $u -> $loc (dos saltos; mejor apuntar al final)\n"; next }
                push @mal, "$u -> $c $loc -> $c2"; next;
            }
            if ($c eq '000') { push @nv, ['RED-09', "$u no contesta (red caida o host que no existe)"]; next }
            push @mal, "$u contesta $c" . ($loc ? " -> $loc" : '');
        }
        $falla->('RED-09', "destino roto: $_") for @mal;
        $pasa{'RED-09'} = 1 if !@mal && $ok == keys %dest;
        @medida{qw(destinos destinos_ok cadenas)} = (scalar(keys %dest), $ok, $cad);
        printf "  destinos    %d de %d contestan 200%s\n", $ok, scalar(keys %dest), ($cad ? " ($cad con un salto)" : '');
    } else {
        my ($ok, @mal) = (0);
        for my $s (@sondas) {
            my $url = "$sitio/$s->{ruta}";
            my ($c, $loc) = rg_pide($url);
            if ($c eq '000') { push @nv, ['RED-10', "/$s->{ruta} no contesta"]; next }
            my $e = $s->{espera};
            if ($e->{tipo} eq 'sirve') {
                if ($c eq '200') { $ok++ } else { push @mal, "/$s->{ruta} tenia que servirse (200) y contesta $c" . ($loc ? " -> $loc" : '') }
                next;
            }
            if ($c eq $e->{codigo} && rg_misma_url($loc, $e->{location})) { $ok++; next }
            push @mal, "/$s->{ruta} tenia que dar $e->{codigo} -> $e->{location} y da $c" . ($loc ? " -> $loc" : '');
        }
        $falla->('RED-10', $_) for @mal;
        $pasa{'RED-10'} = 1 if !@mal && $ok == @sondas;
        printf "  servido     %d de %d sondas contestan lo que dice el .htaccess\n", $ok, scalar(@sondas);
    }

    return rg_cierra(\%o, $repo, $sitio, \@fallos, \@nv, \%pasa, \%medida);
}

# ── el veredicto, y el recibo si es el candidato ─────────────────────────────
sub rg_cierra {
    my ($o, $repo, $sitio, $fallos, $nv, $pasa, $m) = @_;
    print "\n";
    printf "  🔴 %s  %s\n", @$_ for @$fallos;
    printf "  ⚠  %s  NO MEDIDO · %s\n", @$_ for @$nv;
    my %ids_f = map { $_->[0] => 1 } @$fallos;
    my %ids_n = map { $_->[0] => 1 } @$nv;
    my $lente = %ids_f ? 'FALLA' : %ids_n ? 'NO VERIFICADA' : 'PASA';
    my $ver   = %ids_f ? 'FALLA' : %ids_n ? 'NO VERIFICADO' : 'PASA';
    printf "\n  VEREDICTO: %s · %d comprobacion%s en verde, %d en rojo, %d sin medir\n", $ver,
           scalar(keys %$pasa), (keys %$pasa == 1 ? '' : 'es'), scalar(keys %ids_f), scalar(keys %ids_n);

    if ($o->{candidato}) {
        $m //= {};
        my $r = eval {
            main::escribe_recibo(
                repo => $repo, sitio => $sitio, horas => $o->{horas},
                instrumento => "perl $] · redirects-gate.pl · curl",
                medido_contra => 'CANDIDATO', medido_en => 'el .htaccess simulado y sus destinos',
                fallo => scalar(keys %ids_f), aviso => ($m->{cadenas} // 0),
                nv => scalar(keys %ids_n), pasa => scalar(keys %$pasa),
                veredicto => $ver,
                fallo_ids => [ sort keys %ids_f ], nv_ids => [ sort keys %ids_n ],
                redirecciones => {
                    lente    => $lente,
                    reglas   => $m->{reglas} // 0,
                    comodin  => $m->{comodin} // 'NO',
                    sondas   => $m->{sondas} // 0,
                    destinos => $m->{destinos} // 0,
                    destinos_ok => $m->{destinos_ok} // 0,
                    cadenas  => $m->{cadenas} // 0,
                    htaccess => $m->{htaccess} // '',
                    prueba   => ($o->{'permitir-http'} ? 'SI' : ''),
                });
        };
        if ($r) { printf "\n  RECIBO escrito: %s\n  arbol %s · %d ficheros\n", $r->{salida}, $r->{hash}, $r->{ficheros} }
        else    { print "\n  ⚠ NO he podido escribir el recibo: $@\n    Sin recibo la puerta no despliega.\n"; return 1 }
    }
    return %ids_f ? 1 : %ids_n ? 3 : 0;
}

# ── donde esta el .htaccess ──────────────────────────────────────────────────
sub rg_htaccess {
    my ($repo) = @_;
    for my $r (main::receptores($repo)) {
        return { repo => $r->{repo}, ruta => "$repo/$r->{repo}" }
            if $r->{prod} eq '.htaccess' && -f "$repo/$r->{repo}";
    }
    return { repo => '.htaccess', ruta => "$repo/.htaccess" } if -f "$repo/.htaccess";
    return undef;
}

# ── leer las reglas ──────────────────────────────────────────────────────────
#  Devuelve ([reglas], [lo que no se sabe leer]). Una regla:
#    { linea, patron, re, tipo => 'sirve'|'redirige', destino, codigo, L, NC }
sub rg_lee {
    my ($ruta) = @_;
    my (@r, @no);
    open my $fh, '<:raw', $ruta or return ([], ["no puedo leer $ruta: $!"]);
    my $n = 0;
    my $motor = 0;
    while (my $l = <$fh>) {
        $n++;
        $l =~ s/\r?\n\z//;
        utf8::decode($l);
        $l =~ s/^\s+|\s+$//g;
        next if $l eq '' || $l =~ /^#/;
        my ($dir, $resto) = $l =~ /^(\S+)\s*(.*)$/;
        if ($dir =~ m{^</?IfModule\b}i) { next }
        if (grep { lc $_ eq lc $dir } @DIRECTIVAS_INOCUAS) { next }
        if (lc $dir eq 'rewriteengine') {
            if (lc $resto eq 'on') { $motor = 1 } else { push @no, "linea $n: RewriteEngine $resto" }
            next;
        }
        if (lc $dir eq 'rewritebase') {
            push @no, "linea $n: RewriteBase $resto (solo se sabe leer «/»)" unless $resto eq '/';
            next;
        }
        if (lc $dir eq 'rewritecond') {
            push @no, "linea $n: RewriteCond hace condicional la regla siguiente; cuando no se cumple, se sirve lo que haya en el disco";
            next;
        }
        if ($dir =~ /^Redirect(Match|Permanent|Temp)?$/i) {
            push @no, "linea $n: $dir es de mod_alias; este gate lee RewriteRule (el orden entre los dos lo decide el servidor, no el fichero)";
            next;
        }
        if (lc $dir ne 'rewriterule') {
            push @no, "linea $n: no se leer la directiva $dir";
            next;
        }
        my ($pat, $dest, $fl) = $resto =~ /^(\S+)\s+(\S+)(?:\s+\[([^\]]*)\])?\s*$/;
        unless (defined $dest) { push @no, "linea $n: RewriteRule que no se partir: $resto"; next }
        if ($pat =~ /^!/) { push @no, "linea $n: patron negado ($pat)"; next }
        my %f;
        for my $x (split /,/, ($fl // '')) {
            $x =~ s/^\s+|\s+$//g;
            next if $x eq '';
            if    ($x =~ /^(L|END)$/i)              { $f{L} = 1 }
            elsif ($x =~ /^NC$/i)                   { $f{NC} = 1 }
            elsif ($x =~ /^(QSA|QSD|NE)$/i)         { }
            elsif ($x =~ /^R(?:=(\w+))?$/i)         {
                my $c = lc($1 // '302');
                $f{R} = $c eq 'permanent' ? '301' : $c eq 'temp' ? '302' : $c;
            }
            else { push @no, "linea $n: no se leer el flag [$x]"; $f{raro} = 1 }
        }
        next if $f{raro};
        my $re = eval { $f{NC} ? qr/$pat/i : qr/$pat/ };
        unless ($re) { push @no, "linea $n: el patron no compila: $pat"; next }
        my %regla = (linea => $n, patron => $pat, re => $re, L => $f{L} ? 1 : 0, NC => $f{NC} ? 1 : 0);
        if ($dest eq '-') {
            push @no, "linea $n: deja servir sin L; las reglas de despues la redirigen igual" unless $f{L};
            push @r, { %regla, tipo => 'sirve' };
        } elsif (defined $f{R}) {
            push @r, { %regla, tipo => 'redirige', destino => $dest, codigo => $f{R} };
        } else {
            push @no, "linea $n: reescritura interna a $dest: sirve otra cosa del disco en vez de redirigir";
        }
    }
    close $fh;
    push @no, "falta «RewriteEngine On»: ninguna regla se aplicaria" if @r && !$motor;
    push @no, "no hay ninguna RewriteRule" unless @r || @no;
    return (\@r, \@no);
}

sub rg_casa { my ($r, $p) = @_; return $p =~ $r->{re} }

#  Aplica las reglas en orden a una ruta sin barra inicial, como el servidor en un
#  .htaccess. Devuelve { tipo => 'sirve'|'redirige'|'disco', regla, codigo, location }.
sub rg_simula {
    my ($reglas, $p) = @_;
    for my $i (0 .. $#$reglas) {
        my $r = $reglas->[$i];
        my @c = ($p =~ $r->{re});
        next unless $p =~ $r->{re};
        return { tipo => 'sirve', regla => $i } if $r->{tipo} eq 'sirve';
        my $loc = $r->{destino};
        # $1..$9 del patron; $0 no se usa en los mapas
        @c = () if @c == 1 && $c[0] eq '1' && $r->{patron} !~ /\(/;
        $loc =~ s/\$(\d)/defined $c[$1 - 1] ? $c[$1 - 1] : ''/ge;
        return { tipo => 'redirige', regla => $i, codigo => $r->{codigo}, location => $loc };
    }
    return { tipo => 'disco' };
}

#  Una ruta que casa con la regla, fabricada de su patron. Solo patrones de ruta
#  fija (lo que sale de un mapa de sitemaps): ^a/b\.html/?$ -> a/b.html
#  undef si el patron tiene cualquier otra cosa: no se adivina.
sub rg_ejemplo {
    my ($r) = @_;
    my $p = $r->{patron};
    $p =~ s/^\^//;
    $p =~ s/\$$//;
    $p =~ s{/\?$}{};
    $p =~ s/\\([.\-_~])/$1/g;
    return undef if $p =~ /[\\\[\](){}*+?|^\$]/;
    return undef unless $p =~ $r->{re};
    return $p;
}

# ── la red ───────────────────────────────────────────────────────────────────
#  GET sin seguir redirecciones. Devuelve (codigo, location). '000' = no contesta.
sub rg_pide {
    my ($u) = @_;
    (my $q = $u) =~ s/"/%22/g;
    my $ua = do { no warnings 'once'; $main::UA } // 'Mozilla/5.0';
    my $out = `curl -sS -o /dev/null --max-time 20 -A "$ua" -w "%{http_code}\t%{redirect_url}" "$q" 2>/dev/null`;
    $out = '' unless defined $out;
    my ($c, $loc) = split /\t/, $out, 2;
    $c = '000' unless defined $c && $c =~ /^\d{3}$/;
    $loc //= '';
    $loc =~ s/\s+$//;
    return ($c, $loc);
}

sub rg_host { my ($u) = @_; my ($h) = ($u // '') =~ m{^https?://([^/:?#]+)}i; return lc($h // '') }

# La misma URL salvo la barra final de la raiz (https://x.com y https://x.com/).
sub rg_misma_url {
    my ($a, $b) = @_;
    for ($a, $b) { $_ //= ''; s{^(https?://[^/?#]+)$}{$1/}i }
    return $a eq $b;
}

1;
