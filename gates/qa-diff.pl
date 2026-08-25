#!/usr/bin/env perl
# =============================================================================
#  qa-diff.pl  ·  comparar dos corridas de qa-maestro, y una regla entre webs
# =============================================================================
#  Perl 5 puro (viene con Git Bash). Sin dependencias fuera del core.
#
#  POR QUE EXISTE
#  --------------
#  `qa-master.pl` mide UNA web UNA vez. El CAMINO 2 (mejorar una web que ya
#  existe) necesita dos cosas que no tenia:
#
#    1. DEMOSTRAR que la mejora mejora — la misma medicion antes y despues, con
#       los numeros. Sin esto, «lo he arreglado» es una afirmacion. Y el modo de
#       fallo real no es que no mejore: es que mejore una lente y ROMPA otra sin
#       que nadie lo vea. site-d paso densidad a la primera y tiene la
#       conversion muerta; site-c es la peor de maqueta y la mejor en peso.
#
#    2. RETROPROPAGAR — la enfermedad principal de las 5 webs. `og:image:alt` se
#       arreglo en site-a y no salio de ahi: 4 de 5 webs al 0%, incluida aquella
#       donde vive el estandar. Un arreglo que no se pregunta «¿a quien mas le
#       pasa?» crea deriva en el mismo gesto en que quita un fallo.
#
#  LO QUE ESTE FICHERO PROTEGE, Y QUE NINGUN OTRO MIRA
#  --------------------------------------------------
#  Una comprobacion que DESAPARECE entre las dos corridas baja el contador de
#  FALLO exactamente igual que un arreglo. Es la version de QA del sellado a
#  medias de loja.site-b: el resumen mejora, el instrumento midio menos, y no
#  hay ni un error visible. Aqui eso es FALLO DURO, nunca una mejora.
#
#  USO
#  ---
#    perl qa-diff.pl ANTES.json DESPUES.json
#        Diff de una misma web. Clasifica cada comprobacion y da el veredicto.
#
#    perl qa-diff.pl --regla SEO-06 web1.json web2.json [web3.json ...]
#        La misma regla en varias webs. Es la consulta de retropropagacion:
#        «acabo de arreglar esto aqui, ¿a quien mas le pasa?».
#
#    perl qa-diff.pl --comunes web1.json web2.json [...]
#        Todo lo que falla (o esta sin medir) en 2 o mas webs, ordenado por
#        cuantas. Es la COLA de retropropagacion, y el criterio de prioridad
#        `webs afectadas` sale literalmente de aqui.
#
#    Opciones:
#      --json FICHERO   vuelca el resultado en JSON
#      --forzar         sigue aunque el instrumento no coincida (lo estampa)
#      -q               solo lo que cambia / lo que falla
#
#  EXIT
#  ----
#    0  sin regresiones (diff) · arreglado en todas (--regla) · sin comunes
#    1  hay regresion, o comprobacion desaparecida, o queda alguna web sin
#       arreglar, o hay fallos comunes
#    2  no se pudo comparar (ficheros ilegibles, o webs distintas). NO es un 0.
# =============================================================================

use strict;
use warnings;
use utf8;                 # ⚠️ sin esto los literales de aqui salen doble-codificados
use JSON::PP;

# ⚠️ Sin esto, los titulos que traen comillas angulares o acentos salen como
#    interrogantes: JSON::PP devuelve cadenas de CARACTERES y print las escribe
#    como bytes. Es el mismo fallo que ya obligo a poner `use utf8` en qa-maestro.
binmode(STDOUT, ':encoding(UTF-8)');
binmode(STDERR, ':encoding(UTF-8)');

my %opt = (json => '', forzar => 0, q => 0, regla => '', comunes => 0);
my @files;
{
    my @a = @ARGV;

    # English aliases. Additive; both spellings work. See gates/README.md.
    my %ALIAS = ('--rule' => '--regla', '--common' => '--comunes',
                 '--force' => '--forzar');
    @a = map { $ALIAS{$_} // $_ } @a;

    while (@a) {
        my $x = shift @a;
        if    ($x eq '--json')    { $opt{json}  = shift @a // '' }
        elsif ($x eq '--regla')   { $opt{regla} = shift @a // '' }
        elsif ($x eq '--comunes') { $opt{comunes} = 1 }
        elsif ($x eq '--forzar')  { $opt{forzar} = 1 }
        elsif ($x eq '-q')        { $opt{q} = 1 }
        elsif ($x =~ /^-h$|^--help$/) {
            exec($^X, '-e',
                'open my $f,"<",$ARGV[0]; while(<$f>){ last unless /^#/; print substr($_,2) }', $0);
        }
        elsif ($x =~ /^-/) { die "opcion desconocida: $x  (--help)\n" }
        else { push @files, $x }
    }
}

# ── carga ────────────────────────────────────────────────────────────────────
sub cargar {
    my $f = shift;
    open my $fh, '<:raw', $f or do { warn "NO SE PUEDE LEER: $f ($!)\n"; return undef };
    local $/; my $raw = <$fh>; close $fh;
    my $j = eval { JSON::PP->new->utf8->decode($raw) };
    if (!$j) { warn "NO ES JSON VALIDO: $f\n"; return undef }
    if (ref $j ne 'HASH' || !$j->{comprobaciones}) {
        warn "NO ES UNA SALIDA DE qa-maestro --json: $f\n"; return undef;
    }
    my %by;
    for my $c (@{ $j->{comprobaciones} }) { $by{ $c->{id} } = $c }
    $j->{_by} = \%by;
    $j->{_file} = $f;
    return $j;
}

sub etiqueta {
    my $j = shift;
    my $s = $j->{sitio} // '?';
    $s =~ s{^https?://}{}; $s =~ s{/$}{};
    return $s;
}

sub inst {
    my $j = shift;
    my $i = $j->{instrumento} || {};
    my $dom = defined $i->{dom} ? 'DOM' : 'sin DOM';
    my $w   = defined $i->{innerWidth} ? $i->{innerWidth} : '?';
    return "$dom · innerWidth=$w · perl " . ($i->{perl} // '?');
}

my $ORDEN = { FALLO => 0, AVISO => 1, NV => 2, PASA => 3 };
sub peor { my ($a,$b) = @_; return ($ORDEN->{$a}//9) < ($ORDEN->{$b}//9) ? $a : $b }

# =============================================================================
#  MODO 2 y 3 · varias webs
# =============================================================================
if ($opt{regla} ne '' || $opt{comunes}) {
    @files >= 2 or die "hacen falta 2 o mas JSON  (--help)\n";
    my @cargados;
    for my $f (@files) {
        my $j = cargar($f) or exit 2;
        push @cargados, $j;
    }

    # ── DEDUPE POR SITIO ─────────────────────────────────────────────────────
    # 🔴 `--comunes "$REPO"/_qa/*.json ../*/_qa/*.json` mete el repo actual DOS
    #    veces, y `W` (a cuantas webs afecta) es el numero del que cuelga toda la
    #    prioridad del CAMINO 2: un duplicado convierte un defecto de una web en
    #    uno de dos. Se queda la corrida MAS RECIENTE de cada sitio, y se dice.
    my (%mejor, @dup);
    for my $j (@cargados) {
        my $s = $j->{sitio} // $j->{_file};
        if (my $y = $mejor{$s}) {
            my ($viejo, $nuevo) = (($y->{generado} // ''), ($j->{generado} // ''));
            if ($nuevo ge $viejo) { push @dup, $y->{_file}; $mejor{$s} = $j }
            else                  { push @dup, $j->{_file} }
        } else { $mejor{$s} = $j }
    }
    my @sitios = sort { ($a->{sitio}//'') cmp ($b->{sitio}//'') } values %mejor;

    print "\n  WEBS CARGADAS (", scalar(@sitios), "): ",
          join(' · ', map { etiqueta($_) } @sitios), "\n";
    if (@dup) {
        print "  DESCARTADAS por duplicado de sitio (", scalar(@dup), "): ",
              join(' · ', @dup), "\n";
        print "  Se queda la corrida mas reciente de cada web.\n";
    }
    if (@sitios < 2) {
        print "\n  NO SE PUEDE COMPARAR: despues de quitar duplicados queda 1 sola web.\n";
        print "  Revisa el patron de ficheros. Ojo: `*-web` NO casa con\n";
        print "  climentmedia-website. Usa `../*/_qa/ANTES-*.json`.\n";
        exit 2;
    }
    print "  ⚠ Son ", scalar(@sitios), " webs y tenemos 5. Las que falten NO cuentan\n"
        . "    como aprobadas: cuentan como no medidas.\n" if @sitios < 5;

    my @salida;
    my $rc = 0;

    if ($opt{regla} ne '') {
        my $id = uc $opt{regla};
        print "\n", "=" x 78, "\n";
        print "  RETROPROPAGACION  ·  regla $id  ·  ", scalar(@sitios), " webs\n";
        print "=" x 78, "\n";
        my ($ok, $mal, $ausente) = (0, 0, 0);
        for my $j (@sitios) {
            my $c = $j->{_by}{$id};
            my $sitio = etiqueta($j);
            if (!$c) {
                printf "  %-28s %-9s %s\n", $sitio, 'AUSENTE',
                    'esta corrida no emitio la comprobacion (instrumento menor, o no aplica)';
                $ausente++;
                push @salida, { sitio => $sitio, estado => 'AUSENTE' };
                next;
            }
            printf "  %-28s %-9s %s\n", $sitio, $c->{estado}, ($c->{titulo} // '');
            printf "  %-28s %-9s %s\n", '', '', 'DATO  ' . $c->{dato} if $c->{dato};
            if ($c->{estado} eq 'PASA') { $ok++ } else { $mal++ }
            push @salida, { sitio => $sitio, estado => $c->{estado}, dato => $c->{dato} };
        }
        print "-" x 78, "\n";
        printf "  PASA %d  ·  NO PASA %d  ·  AUSENTE %d\n", $ok, $mal, $ausente;
        if ($mal || $ausente) {
            print "  1 ARREGLADA EN UNA WEB NO ES ARREGLADA. Quedan $mal por arreglar";
            print " y $ausente sin medir" if $ausente;
            print ".\n";
            print "  Es exactamente como og:image:alt se quedo solo en site-a.\n";
            $rc = 1;
        } else {
            print "  Arreglado en TODAS las webs medidas.\n";
        }
        print "=" x 78, "\n";
    }

    if ($opt{comunes}) {
        my %cuenta; my %quien; my %titulo; my %peor;
        for my $j (@sitios) {
            my $sitio = etiqueta($j);
            for my $id (keys %{ $j->{_by} }) {
                my $c = $j->{_by}{$id};
                next if $c->{estado} eq 'PASA';
                $cuenta{$id}++;
                push @{ $quien{$id} }, "$sitio(" . $c->{estado} . ")";
                $titulo{$id} = $c->{titulo} // '';
                $peor{$id} = defined $peor{$id} ? peor($peor{$id}, $c->{estado}) : $c->{estado};
            }
        }
        my @ids = sort {
            $cuenta{$b} <=> $cuenta{$a}
            or ($ORDEN->{$peor{$a}}//9) <=> ($ORDEN->{$peor{$b}}//9)
            or $a cmp $b
        } grep { $cuenta{$_} >= 2 } keys %cuenta;

        print "\n", "=" x 78, "\n";
        print "  COLA DE RETROPROPAGACION  ·  falla en 2 o mas de ", scalar(@sitios), " webs\n";
        print "=" x 78, "\n";
        if (!@ids) {
            print "  Nada falla en dos webs a la vez. (Comprueba que has pasado varias webs\n";
            print "  y no la misma dos veces: eso tambien da esta salida.)\n";
        }
        for my $id (@ids) {
            printf "  [%d/%d] %-9s %-9s %s\n", $cuenta{$id}, scalar(@sitios),
                   $peor{$id}, $id, $titulo{$id};
            printf "          %s\n", join(' · ', @{ $quien{$id} });
            push @salida, { id => $id, n => $cuenta{$id}, peor => $peor{$id},
                            titulo => $titulo{$id}, webs => $quien{$id} };
        }
        print "-" x 78, "\n";
        printf "  %d reglas incumplidas en 2 o mas webs.\n", scalar(@ids);
        print "  ESTA es la lista que se arregla en el GENERADOR o en el TOKEN, no a mano\n";
        print "  web por web. Lo que aparece en 4 o 5 webs casi nunca es un fallo de esa\n";
        print "  web: es un defecto del esqueleto del que salieron todas.\n";
        print "=" x 78, "\n";
        $rc = 1 if @ids;
    }

    if ($opt{json} ne '') {
        open my $jf, '>:raw', $opt{json} or die "no puedo escribir $opt{json}: $!\n";
        print $jf JSON::PP->new->utf8->canonical->pretty->encode({
            modo => ($opt{regla} ne '' ? 'regla' : 'comunes'),
            regla => $opt{regla}, webs => [ map { etiqueta($_) } @sitios ],
            resultado => \@salida,
        });
        close $jf;
    }
    exit $rc;
}

# =============================================================================
#  MODO 1 · antes / despues de la MISMA web
# =============================================================================
@files == 2 or die "uso: perl qa-diff.pl ANTES.json DESPUES.json  (--help)\n";
my $A = cargar($files[0]) or exit 2;
my $B = cargar($files[1]) or exit 2;

if (($A->{sitio} // '') ne ($B->{sitio} // '')) {
    print "\nNO SE PUEDE COMPARAR: son webs distintas.\n";
    print "  antes:   ", $A->{sitio} // '?', "\n";
    print "  despues: ", $B->{sitio} // '?', "\n";
    print "Para comparar DOS WEBS usa --regla o --comunes, que es otra pregunta.\n";
    exit 2;
}

my $instA = inst($A);
my $instB = inst($B);
my $mismo_instrumento = ($instA eq $instB) ? 1 : 0;

print "\n", "=" x 78, "\n";
print "  QA DIFF  ·  ", etiqueta($A), "\n";
print "=" x 78, "\n";
printf "  ANTES    %s   (%s)\n", ($A->{generado} // '?'), $A->{_file};
printf "  DESPUES  %s   (%s)\n", ($B->{generado} // '?'), $B->{_file};
printf "  INSTRUMENTO  %s\n", $instA;
if (!$mismo_instrumento) {
    printf "               %s   <-- DISTINTO\n", $instB;
    print "\n";
    print "  ATENCION: las dos corridas NO se hicieron con el mismo instrumento.\n";
    print "  Una diferencia de instrumento produce una diferencia de resultado que\n";
    print "  NO es una mejora. Antes de creerte este diff, vuelve a medir el ANTES\n";
    print "  con las mismas banderas que el DESPUES.\n";
    if (!$opt{forzar}) {
        print "  (--forzar para seguir de todas formas; quedara estampado)\n";
        print "=" x 78, "\n";
        exit 2;
    }
    print "  --forzar: se sigue, pero este diff NO es evidencia.\n";
}

my %ids = map { $_ => 1 } (keys %{ $A->{_by} }, keys %{ $B->{_by} });
my (@arreglado, @medido, @regresion, @desaparecido, @nuevo, @igual, @otro);

for my $id (sort keys %ids) {
    my $a = $A->{_by}{$id};
    my $b = $B->{_by}{$id};
    if ($a && !$b) { push @desaparecido, { id => $id, antes => $a->{estado}, titulo => $a->{titulo} }; next }
    if (!$a && $b) { push @nuevo,        { id => $id, despues => $b->{estado}, titulo => $b->{titulo} }; next }
    my ($ea, $eb) = ($a->{estado}, $b->{estado});
    my $reg = { id => $id, antes => $ea, despues => $eb,
                titulo => ($b->{titulo} // $a->{titulo}), dato_antes => $a->{dato},
                dato_despues => $b->{dato} };
    if ($ea eq $eb) { push @igual, $reg; next }
    if ($eb eq 'PASA' && ($ea eq 'FALLO' || $ea eq 'AVISO')) { push @arreglado, $reg; next }
    if ($ea eq 'NV'   && $eb ne 'NV')                        { push @medido,    $reg; next }
    if (($ORDEN->{$eb} // 9) < ($ORDEN->{$ea} // 9))         { push @regresion, $reg; next }
    push @otro, $reg;
}

sub bloque {
    my ($titulo, $lista, $fmt) = @_;
    return unless @$lista;
    print "\n", "-" x 78, "\n  $titulo (", scalar(@$lista), ")\n", "-" x 78, "\n";
    for my $r (@$lista) { $fmt->($r) }
}

bloque('ARREGLADO  ·  estaba mal, ahora PASA', \@arreglado, sub {
    my $r = shift;
    printf "  %-9s %s -> %s   %s\n", $r->{id}, $r->{antes}, $r->{despues}, $r->{titulo} // '';
    printf "            antes: %s\n", $r->{dato_antes} if $r->{dato_antes};
});

bloque('AHORA MEDIDO  ·  estaba NO VERIFICADO', \@medido, sub {
    my $r = shift;
    printf "  %-9s NV -> %-5s %s\n", $r->{id}, $r->{despues}, $r->{titulo} // '';
    printf "            %s\n", $r->{dato_despues} if $r->{dato_despues};
});

bloque('REGRESION  ·  estaba mejor antes', \@regresion, sub {
    my $r = shift;
    printf "  %-9s %s -> %s   %s\n", $r->{id}, $r->{antes}, $r->{despues}, $r->{titulo} // '';
    printf "            ahora: %s\n", $r->{dato_despues} if $r->{dato_despues};
});

bloque('DESAPARECIDO  ·  estaba en el ANTES y el DESPUES no la emite', \@desaparecido, sub {
    my $r = shift;
    printf "  %-9s %s -> (nada)   %s\n", $r->{id}, $r->{antes}, $r->{titulo} // '';
});

bloque('NUEVO  ·  no estaba en el ANTES', \@nuevo, sub {
    my $r = shift;
    printf "  %-9s (nada) -> %s   %s\n", $r->{id}, $r->{despues}, $r->{titulo} // '';
});

bloque('OTRO CAMBIO', \@otro, sub {
    my $r = shift;
    printf "  %-9s %s -> %s   %s\n", $r->{id}, $r->{antes}, $r->{despues}, $r->{titulo} // '';
});

if (!$opt{q} && @igual) {
    my %n; $n{ $_->{despues} }++ for @igual;
    print "\n", "-" x 78, "\n  SIN CAMBIO (", scalar(@igual), "): ",
          join(' · ', map { "$_ $n{$_}" } sort keys %n), "\n";
}

# ── resumen ──────────────────────────────────────────────────────────────────
my $ra = $A->{resumen} || {}; my $rb = $B->{resumen} || {};
sub d { my ($x,$y) = @_; my $v = ($y//0) - ($x//0); return sprintf('%+d', $v) }

print "\n", "=" x 78, "\n";
printf "  %-16s %8s %8s %8s\n", '', 'ANTES', 'DESPUES', 'DELTA';
printf "  %-16s %8d %8d %8s\n", 'FALLO',         $ra->{fallo}//0,         $rb->{fallo}//0,         d($ra->{fallo},$rb->{fallo});
printf "  %-16s %8d %8d %8s\n", 'AVISO',         $ra->{aviso}//0,         $rb->{aviso}//0,         d($ra->{aviso},$rb->{aviso});
printf "  %-16s %8d %8d %8s\n", 'NO VERIFICADO', $ra->{no_verificado}//0, $rb->{no_verificado}//0, d($ra->{no_verificado},$rb->{no_verificado});
printf "  %-16s %8d %8d %8s\n", 'PASA',          $ra->{pasa}//0,          $rb->{pasa}//0,          d($ra->{pasa},$rb->{pasa});
printf "  %-16s %8s %8s\n", 'VEREDICTO', $A->{veredicto}//'?', $B->{veredicto}//'?';
print "=" x 78, "\n";

my $rc = 0;
if (@desaparecido) {
    $rc = 1;
    print "  FALLO DURO: ", scalar(@desaparecido), " comprobaciones han DESAPARECIDO.\n";
    print "  Una comprobacion que deja de emitirse baja el contador de FALLO igual que\n";
    print "  un arreglo. O el cambio borro lo que se medía, o el DESPUES se corrio con\n";
    print "  menos instrumento (menos URLs, sin --repo, sin --dom). Las dos son motivo\n";
    print "  de no cerrar. No es una mejora.\n";
}
if (@regresion) {
    $rc = 1;
    print "  FALLO DURO: ", scalar(@regresion), " regresiones.\n";
    print "  Cada web ha ganado una lente y perdido otra: es el patron medido en las 5.\n";
    print "  Un arreglo que rompe otra cosa no es un arreglo, es un cambio.\n";
}
if (!@arreglado && !@medido && !@regresion && !@desaparecido) {
    print "  NADA HA CAMBIADO. Si venias de tocar algo: o no se desplego (mira EST-09),\n";
    print "  o estas midiendo cache. Un diff vacio despues de un arreglo es un aviso.\n";
}
if (@arreglado || @medido) {
    printf "  %d arregladas · %d que antes no habia mirado nadie.\n",
        scalar(@arreglado), scalar(@medido);
    print "  SIGUIENTE PASO OBLIGATORIO: por cada una, `--regla <ID>` contra las otras\n";
    print "  webs. Un arreglo que no se pregunta a quien mas le pasa CREA la deriva.\n";
}
print "=" x 78, "\n";

if ($opt{json} ne '') {
    open my $jf, '>:raw', $opt{json} or die "no puedo escribir $opt{json}: $!\n";
    print $jf JSON::PP->new->utf8->canonical->pretty->encode({
        modo => 'diff', sitio => $A->{sitio},
        antes => { fichero => $A->{_file}, generado => $A->{generado}, resumen => $ra,
                   veredicto => $A->{veredicto} },
        despues => { fichero => $B->{_file}, generado => $B->{generado}, resumen => $rb,
                     veredicto => $B->{veredicto} },
        mismo_instrumento => ($mismo_instrumento ? JSON::PP::true : JSON::PP::false),
        arreglado => \@arreglado, medido => \@medido, regresion => \@regresion,
        desaparecido => \@desaparecido, nuevo => \@nuevo, sin_cambio => scalar(@igual),
    });
    close $jf;
}
exit $rc;
