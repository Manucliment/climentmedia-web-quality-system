#!/usr/bin/env perl
# d057.pl · LO VIEJO QUE YA ESTA IGUAL EN PRODUCCION NO PARA UNA SUBIDA (D-057)
#
#  La puerta (deploy.sh) lo llama cuando el recibo del CANDIDATO sale FALLA o deja
#  cosas sin mirar. Para cada FALLO y cada sin mirar del recibo contesta UNA
#  pregunta: ¿es viejo y alguien tiene fecha para arreglarlo? Si lo es, pasa,
#  nombrado uno a uno y firmado «D-057». Si no, para. Nada nuevo pasa en rojo.
#
#  POR QUE EXISTE. El 5-nov cinco webs estaban paradas por FALLOs que su subida no
#  tocaba y que la web publicada ya tenia igual: una portada que no se arregla hasta
#  su pieza del plan, un contraste con su fila al 20-nov. `--aun-asi` es para lo
#  SIN MIRAR, no para un FALLO, y aceptado.conf es para lo que decide el cliente. O
#  se esperaba al plan para subir cualquier cosa, o se rodeaba la puerta. La regla
#  (D-045, y D-057 que la pone en la puerta) ya existia; la comprobaba la memoria
#  del chat que subia, y una regla que comprueba la memoria no es un gate.
#
#  QUE MIRA, EN ESTE ORDEN
#    1. El recibo: sellado, de CANDIDATO, con sus hallazgos (HALLAZGO-NNN, que
#       escribe qa-master desde el 5-nov) y medido con el mismo qa-master que hay
#       ahora (QA-MASTER-MD5): si no, produccion no se mediria con la misma regla.
#    2. Lo que D-057 no cubre, que viene marcado en el recibo por qa-master (una
#       sola lista, al lado de la regla): la lente de medicion, cookies y
#       consentimiento, y lo que no se acepta nunca. Un FALLO ahi PARA.
#       MED-13 en una web que declara SIN_GA4_NI_ADS: NO APLICA, con su motivo,
#       si el arbol de verdad no lleva ni GA4 ni Ads (se mira; si lo lleva, PARA).
#    3. Produccion, medida AHORA con el mismo qa-master y la misma regla (la linea
#       QA-REPETIR del recibo): mismo check, mismo estado, y cada instancia del
#       candidato (pagina, texto, selector) tambien en produccion. El candidato
#       puede tener MENOS (arregla parte): es lo que hay que dejar pasar.
#    4. Una fila abierta que lo nombre, con fecha de hoy en adelante y dueño, en
#       _seo/BASE.md, _seo/plan*.md o _diseno/PLAN.md. Vencida, cerrada, sin
#       fecha o sin dueño no vale: es una fila que no arregla nada.
#  Y dice cuantos FALLO de produccion quita esta subida (condicion 2 de D-045).
#  No PARA por eso: una pieza nueva no quita ninguno y Manuel la quiere arriba.
#  La condicion 3 (lo que se podia arreglar, arreglado) no la mide un script: es
#  la revision del Pod Manager antes de subir.
#
#    Lo que sale del DOM (EST-05/06/07, REN-11, marcado dom=si en el recibo) se
#    compara solo con el DOM de produccion (--dom-produccion; en la puerta,
#    D057_DOM_PRODUCCION): de produccion, de la misma pagina, al mismo ancho y
#    alto y de las ultimas 12 h. Sin el, NO MEDIDO: ni viejo ni nuevo.
#
#  USO
#    perl d057.pl --repo DIR [--sin-ga4-ni-ads "motivo"] [--salida FICHERO]
#                 [--dom-produccion JSON] [--produccion JSON] [--hoy AAAA-MM-DD]
#    --dom-produccion  el DOM de la pagina publicada (node gates/run-gate.js
#                  <url> ANCHO ALTO qa.js), para volver a medir lo del DOM
#    --produccion  el JSON de una corrida de produccion ya hecha (en vez de medir)
#    --hoy         la fecha contra la que vence una fila (por defecto, hoy)
#    En ingles: --no-ga4-or-ads · --out · --production-dom · --production · --today
#
#  SALIDA (lineas que lee deploy.sh)
#    D057-RESULTADO: PASA | PARA | NO MEDIDO
#    D057-FALLO / D057-NV / D057-NO-APLICA / D057-PARA / D057-SIGUE: ids
#    D057-QUITA: N
#    D057-RECIBO: el SELLO del recibo juzgado (lo comprueba apuntar-seguimiento)
#  exit 0 = ningun FALLO que pare · 1 = alguno para · 2 = no se ha podido medir.
#  Un sin mirar que D-057 no cubre no para aqui: sigue su camino de siempre en la
#  puerta (paso 2), y sale como SIGUE.
use strict;
use warnings;
use JSON::PP;
use File::Temp qw(tempdir);
use POSIX qw(strftime);

my ($MIDIR57) = $0 =~ m{^(.*)[\\/][^\\/]+$};
$MIDIR57 = '.' unless defined $MIDIR57 && $MIDIR57 ne '';
require "$MIDIR57/receipt.pl";   # lee_recibo, hash_estandar, solo_ascii
# receipt.pl pone la salida en UTF-8 al cargarse, y este fichero escribe bytes que
# ya son UTF-8: sin esto, cada «·» sale «Â·».
binmode(STDOUT, ':raw');

my %o = (repo => '', ga4 => '', salida => '', produccion => '', hoy => '', dom => '');
{
    my %AL = ('--no-ga4-or-ads' => '--sin-ga4-ni-ads', '--out' => '--salida',
              '--production' => '--produccion', '--today' => '--hoy',
              '--production-dom' => '--dom-produccion');
    my @a = map { $AL{$_} // $_ } @ARGV;
    while (@a) {
        my $x = shift @a;
        if    ($x eq '--repo')            { $o{repo} = shift(@a) // '' }
        elsif ($x eq '--sin-ga4-ni-ads')  { $o{ga4} = shift(@a) // '' }
        elsif ($x eq '--salida')          { $o{salida} = shift(@a) // '' }
        elsif ($x eq '--produccion')      { $o{produccion} = shift(@a) // '' }
        elsif ($x eq '--dom-produccion')  { $o{dom} = shift(@a) // '' }
        elsif ($x eq '--hoy')             { $o{hoy} = shift(@a) // '' }
        elsif ($x eq '-h' || $x eq '--help') {
            open my $f, '<', $0 or exit 2;
            while (<$f>) { next if $. == 1; last unless /^#/; print substr($_, 2) }
            exit 0;
        }
        else { print "opcion no reconocida: $x\n"; exit 2 }
    }
}
my $HOY = $o{hoy} ne '' ? $o{hoy} : strftime('%Y-%m-%d', localtime);
my @OUT;
sub d57_di { push @OUT, @_; print "$_\n" for @_ }
sub d57_fin {
    my ($rc) = @_;
    if ($o{salida} ne '' && open my $s, '>:raw', $o{salida}) {
        print $s "# gates/d057.pl · " . strftime('%Y-%m-%d %H:%M', localtime) . "\n";
        print $s "$_\n" for @OUT;
        close $s;
    }
    exit $rc;
}
sub d57_no_medido {
    d57_di("  NO MEDIDO: $_[0]", "D057-RESULTADO: NO MEDIDO");
    d57_fin(2);
}
sub d57_des { my $s = shift; $s =~ s/%([0-9A-F]{2})/chr hex $1/ge; return $s }

d57_di("  D-057 · lo viejo igual en produccion (gates/d057.pl)");
d57_no_medido("falta --repo") unless $o{repo} ne '' && -d $o{repo};
my $REPO = $o{repo};

# ── 1 · el recibo ─────────────────────────────────────────────────────────────
my ($R, $err) = main::lee_recibo("$REPO/.qa-recibo");
d57_no_medido($err) unless $R;
d57_no_medido("el SELLO del recibo no cuadra") unless $R->{_sello_ok};
d57_no_medido("el recibo es de " . ($R->{'MEDIDO-CONTRA'} // 'PRODUCCION')
              . ": D-057 compara el CANDIDATO con produccion (mide con --candidato)")
    unless ($R->{'MEDIDO-CONTRA'} // '') eq 'CANDIDATO';
unless (defined $R->{HALLAZGOS}) {
    d57_no_medido("el recibo es de antes de D-057 (no lleva HALLAZGO-NNN): vuelve a medir el candidato")
        if ($R->{FALLO} // 0) > 0 || ($R->{'NO-VERIFICADO'} // 0) > 0;
}
# La misma regla = el mismo qa-master: produccion se mide con el de AHORA, y si no
# son los mismos bytes que midieron el candidato, la comparacion no vale. Solo el
# programa: un README nuevo en gates/ no cambia ninguna regla.
if (defined $R->{HALLAZGOS}) {
    my $ahora = eval { open my $q, '<:raw', "$MIDIR57/qa-master.pl" or die; local $/;
                       require Digest::MD5; Digest::MD5::md5_hex(<$q>) } // '';
    my $antes = $R->{'QA-MASTER-MD5'} // '';
    d57_no_medido("qa-master ha cambiado desde el recibo (" . ($antes || 'sin md5') . " -> $ahora): produccion"
                  . " no se mediria con la misma regla; vuelve a medir el candidato")
        unless $antes ne '' && $antes eq $ahora;
}
my %NVC = map { $_ => 1 } split /\s+/, ($R->{'NV-POR-CANDIDATO'} // '');
my @H;
for my $i (1 .. ($R->{HALLAZGOS} // 0)) {
    my $k = sprintf('HALLAZGO-%03d', $i);
    my ($est, $id, $lente, $n, $d, $dom) = split /\s+/, ($R->{$k} // '');
    d57_no_medido("el recibo no trae $k entero") unless defined $d && $d =~ /^d057=(.+)$/;
    my $fuera = $1 eq 'si' ? '' : ($1 =~ s/^no://r =~ s/_/ /gr);
    my @ins = map { $R->{sprintf('%s-I-%03d', $k, $_)} // '' } 1 .. $n;
    push @H, { estado => $est, id => $id, lente => $lente, fuera => $fuera, ins => \@ins,
               dom => (($dom // '') eq 'dom=si') };
}

# ── 2 · lo que D-057 no cubre, y MED-13 sin GA4 ni Ads ────────────────────────
sub d57_ga4_en_arbol {
    for my $m (@{ $R->{_manifiesto} || [] }) {
        my $rel = $m->[0];
        next unless $rel =~ /\.(?:html?|js|php)$/i;
        open my $f, '<:raw', "$REPO/$rel" or next;
        local $/; my $t = <$f> // ''; close $f;
        $t =~ s/<!--.*?-->//gs;
        return "$rel: $1" if $t =~ /(googletagmanager\.com|google-analytics\.com|googleadservices\.com|gtag\s*\(|\bG-[A-Z0-9]{6,}\b|\bAW-\d{6,}\b)/;
    }
    return '';
}
my (@lin, %res);
my @pendientes;   # los que necesitan produccion y fila
for my $h (@H) {
    next if $h->{estado} eq 'NV' && $NVC{$h->{id}};
    if ($h->{id} eq 'MED-13' && $o{ga4} ne '') {
        my $hay = d57_ga4_en_arbol();
        if ($hay eq '') { $h->{r} = 'NO-APLICA'; $h->{por} = "la web no lleva GA4 ni Ads por decision: $o{ga4}"; }
        else { $h->{r} = 'PARA'; $h->{por} = "deploy.conf dice SIN_GA4_NI_ADS y el arbol lleva $hay"; }
        next;
    }
    if ($h->{fuera} ne '' || $h->{lente} eq 'MEDICION') {
        my $m = $h->{fuera} || 'medicion';
        $h->{r}   = $h->{estado} eq 'FALLO' ? 'PARA' : 'SIGUE';
        $h->{por} = "D-057 no cubre $m" . ($h->{estado} eq 'FALLO' ? ': un FALLO aqui para aunque sea viejo' : '');
        next;
    }
    push @pendientes, $h;
}

# ── 3a · lo que sale del DOM: produccion, con el suyo ─────────────────────────
#  EST-05/06/07 y REN-11 salen del DOM que se le dio al candidato (--dom). Sin el
#  de produccion, alli salen sin medir (EST-06) o ni salen (EST-07): ni viejo ni
#  nuevo. Con el, tiene que ser de produccion, de la misma pagina, al mismo ancho
#  y alto (la huella de EST-06 los lleva) y de las ultimas 12 h: uno de otro dia
#  no dice como esta produccion hoy.
my $dom_mal = '';
my @dom_arg;
if (($R->{'ALCANCE-DOM'} // '') ne '' && grep { $_->{dom} } @pendientes) {
    my $al = $R->{'ALCANCE-DOM'};
    my ($cw) = $al =~ /innerWidth=(\d+)/;
    my ($ch) = $al =~ /innerHeight=(\d+)/;
    my ($cp) = $al =~ /pagina=(\S+?)\)\s*$/;
    my $sitio_de = sub { my $u = lc(shift // ''); $u =~ s{^[a-z]+://}{}; $u =~ s{[?#].*$}{}; $u =~ s{/+$}{}; $u =~ s{/index\.html?$}{}; return $u };
    if (!defined $cw || !defined $ch || !defined $cp) {
        $dom_mal = "el recibo no dice a que ancho, alto y pagina se midio el DOM del candidato (ALCANCE-DOM: $al): vuelve a medir el candidato";
    } elsif ($o{dom} eq '') {
        $dom_mal = "se midio con el DOM del candidato y produccion no trae el suyo: D057_DOM_PRODUCCION en deploy.conf"
                 . " (o --dom-produccion), capturado en $cp a ${cw}x$ch";
    } else {
        my $j = eval { open my $f, '<:raw', $o{dom} or die "no puedo abrir $o{dom}\n"; local $/;
                       JSON::PP->new->utf8->relaxed->decode(<$f>) };
        my $edad;
        if ($j && ($j->{ts} // '') =~ /^(\d{4})-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)/) {
            require Time::Local;
            $edad = (time - Time::Local::timegm($6, $5, $4, $3, $2 - 1, $1)) / 3600;
        } elsif ($j) { $edad = (-M $o{dom}) * 24 }
        if (!$j) { ($dom_mal = "el DOM de produccion no se puede leer: " . ($@ || 'no es JSON')) =~ s/\s+$// }
        elsif (($j->{innerWidth} // '') ne $cw || ($j->{innerHeight} // '') ne $ch) {
            $dom_mal = sprintf('el DOM de produccion es de innerWidth=%s innerHeight=%s y el del candidato de %sx%s: tienen que ser el mismo',
                               $j->{innerWidth} // '?', $j->{innerHeight} // '?', $cw, $ch);
        }
        elsif (($j->{url} // '') =~ m{^[a-z]+://(?:127\.0\.0\.1|localhost|\[::1\])(?::\d+)?/}i) {
            $dom_mal = "el DOM de produccion es de $j->{url}: es el del candidato, no el de produccion";
        }
        elsif ($sitio_de->($j->{url}) ne $sitio_de->($cp)) {
            $dom_mal = 'el DOM de produccion es de ' . ($j->{url} // 'una pagina sin url') . " y el del candidato se juzga como $cp: otra pagina";
        }
        elsif (!defined $edad || $edad > 12 || $edad < -0.5) {
            $dom_mal = defined $edad ? sprintf('el DOM de produccion es de hace %.0f h (mas de 12): vuelve a capturarlo', $edad)
                                     : 'el DOM de produccion no dice cuando se capturo';
        }
        else { @dom_arg = ('--dom', $o{dom}) }
    }
}

# ── 3 · produccion, con la misma regla ────────────────────────────────────────
my $para_ya = grep { ($_->{r} // '') eq 'PARA' } @H;
my (%PROD, $prod_mal);
if ((grep { !$_->{dom} || $dom_mal eq '' } @pendientes) && !$para_ya) {
    my $json = $o{produccion};
    if ($json eq '') {
        my @args = map { d57_des($_) } split /\s+/, ($R->{'QA-REPETIR'} // '');
        if (!@args) { $prod_mal = 'el recibo no dice como volver a medir (QA-REPETIR)' }
        else {
            my $tmp = tempdir('d057-XXXXXX', TMPDIR => 1, CLEANUP => 1);
            $json = "$tmp/produccion.json";
            my @cmd = ($^X, "$MIDIR57/qa-master.pl", @args, @dom_arg, '--repo', $REPO, '--sin-recibo', '--json', $json);
            d57_di("  produccion: " . join(' ', 'perl qa-master.pl', @args, @dom_arg, '--repo', $REPO, '--sin-recibo'));
            if (open my $ph, '-|', @cmd) {
                my @log = <$ph>; close $ph;
                my $qrc = $? >> 8;
                # 0 = PASA, 1 = FALLA: produccion medida. 3 = NO MEDIDO (no contesta, o
                # una lente corrio y no midio nada) y 2 = no arranco: con eso, todo lo
                # del candidato «saldria nuevo», que es mentira. Se dice que no se midio.
                if ($qrc > 1) {
                    my ($ult) = grep { /\S/ && !/^\s*[-=]+\s*$/ } reverse grep { /no contesta|NO MEDIDO|no responde|error|502|503/i } @log;
                    $prod_mal = "qa-master sobre produccion salio con $qrc (no medido)"
                              . (defined $ult ? ': ' . solo_ascii($ult =~ s/^\s+|\s+$//gr) : '');
                }
            }
        }
    }
    if (!$prod_mal) {
        my $j = eval { open my $f, '<:raw', $json or die "no hay $json\n"; local $/; decode_json(<$f>) };
        if (!$j) { $prod_mal = 'qa-master no dejo el JSON de produccion' . ($@ ? ": $@" : '') ; $prod_mal =~ s/\s+$//; }
        elsif (($j->{medido_contra} // 'PRODUCCION') ne 'PRODUCCION') { $prod_mal = 'el JSON de produccion es de un CANDIDATO' }
        else {
            for my $c (@{ $j->{comprobaciones} || [] }) {
                next unless ($c->{estado} // '') =~ /^(FALLO|NV)$/;
                unless ($c->{instancias}) { $prod_mal = 'el JSON de produccion es de un qa-master de antes de D-057'; last }
                $PROD{$c->{id}}{$c->{estado}}{$_} = 1 for @{ $c->{instancias} };
            }
        }
    }
}

# ── 4 · la fila del plan ──────────────────────────────────────────────────────
my %MES = (ene=>1, feb=>2, mar=>3, abr=>4, may=>5, jun=>6, jul=>7, ago=>8, sep=>9, oct=>10, nov=>11, dic=>12);
sub d57_fecha {
    my ($s) = @_;
    return sprintf('%04d-%02d-%02d', $1, $2, $3) if $s =~ /(\d{4})-(\d{2})-(\d{2})/;
    if ($s =~ /\b(\d{1,2})-(ene|feb|mar|abr|may|jun|jul|ago|sep|oct|nov|dic)[a-z]*\.?(?:-(\d{4}))?/i) {
        my ($d, $m, $a) = ($1, $MES{lc $2}, $3);
        unless (defined $a) {   # sin año: el de hoy, o el siguiente si el mes ya quedo muy atras
            my ($ah, $mh) = $HOY =~ /^(\d{4})-(\d{2})/;
            $a = $ah + ($m < $mh - 6 ? 1 : 0);
        }
        return sprintf('%04d-%02d-%02d', $a, $m, $d);
    }
    return undef;
}
sub d57_celdas { my $t = shift; $t =~ s/^\s*\|//; $t =~ s/\|\s*$//; return map { s/^\s+|\s+$//gr } split /\|/, $t }
my @FILAS;
{
    my %visto;
    my @f = grep { -f $_ && !$visto{lc $_}++ }
            ("$REPO/_seo/BASE.md", sort(glob("$REPO/_seo/plan*.md")), sort(glob("$REPO/_seo/PLAN*.md")),
             "$REPO/_diseno/PLAN.md");
    for my $f (@f) {
        open my $fh, '<:raw', $f or next;
        my @l = <$fh>; close $fh;
        s/\r?\n\z// for @l;
        (my $rel = $f) =~ s{^\Q$REPO\E[\\/]?}{};
        my %col;
        for my $i (0 .. $#l) {
            my $t = $l[$i];
            if ($t !~ /^\s*\|/) { %col = (); next }
            next if $t =~ /^\s*\|\s*:?-{3,}/;
            if ($i < $#l && $l[$i + 1] =~ /^\s*\|\s*:?-{3,}/) {
                %col = ();
                my @c = d57_celdas($t);
                for my $k (0 .. $#c) {
                    my $n = lc $c[$k]; $n =~ s/[*_`]//g; $n =~ s/\xC3\xB1/n/g; $n =~ s/^\s+|\s+$//g;
                    $col{$n} //= $k;
                }
                next;
            }
            next unless %col;
            push @FILAS, { rel => $rel, linea => $i + 1, texto => $t, c => [ d57_celdas($t) ],
                           # `? 1 : 0`: en lista, un match que falla no da NADA, y el hash
                           # quedaba impar («Odd number of elements», una vez por fila de
                           # una tabla que no es BASE.md: 19 en una web el 6-nov)
                           col => { %col }, base => ($rel =~ m{^_seo[\\/]BASE\.md$} ? 1 : 0) };
        }
    }
}
sub d57_fila_de {
    my ($id) = @_;
    my (@vencida, @cerrada, @sin_fecha, @sin_dueno);
    for my $f (@FILAS) {
        (my $s = $f->{texto}) =~ s/~~.*?~~//g;
        next unless $s =~ /(?<![A-Za-z0-9])\Q$id\E(?![A-Za-z0-9])/;
        my $donde = "$f->{rel}:$f->{linea}";
        my %c = %{ $f->{col} };
        my $cel = sub { my $k = shift; defined $c{$k} ? ($f->{c}[$c{$k}] // '') : undef };
        my $estado = $cel->('estado');
        if (defined $estado) {
            (my $e = $estado) =~ s/[*_`~]//g;
            if ($e =~ /^\W*(?:hech[oa]|cerrad[oa]|resuelt[oa]|arreglad[oa]|descartad[oa])\b/i || $e =~ /^\s*\xE2\x9C\x85/) {
                push @cerrada, $donde; next;
            }
        }
        my $fc = $cel->('fecha');
        my $fecha = defined $fc ? d57_fecha($fc) : undef;
        unless (defined $fecha) { push @sin_fecha, $donde; next }
        my $dueno = $cel->('dueno');
        $dueno = '' if defined $dueno && $dueno =~ /^[\s\-\x{2014}]*$|^\xE2\x80\x94$/;
        if (!defined $dueno || $dueno eq '') {
            # 6-nov: «espera X» da dueño solo al PRINCIPIO del Estado. En cualquier sitio, «la portada
            # espera la lectura…» daba «dueño: espera la» (una web, 6-nov). «espera a X» vale.
            (my $e0 = $estado // '') =~ s/[*_`~]//g;
            if ($e0 =~ /^\W*espera\s+(?:al?\s+)?([^\s(,;.]+)/i) { $dueno = "espera $1" }
            elsif ($f->{base}) { $dueno = 'el chat de la web (BASE.md)' }
            else { push @sin_dueno, $donde; next }
        }
        if ($fecha lt $HOY) { push @vencida, "$donde (vencio el $fecha)"; next }
        return (1, sprintf('fila %s · %s · dueno: %s', $donde, $fecha, solo_ascii($dueno)));
    }
    return (0, "su fila vencio: $vencida[0]; se arregla o se cambia la fecha en el plan") if @vencida;
    return (0, "su fila no tiene fecha: $sin_fecha[0]")                                    if @sin_fecha;
    return (0, "su fila no tiene dueno: $sin_dueno[0]")                                     if @sin_dueno;
    return (0, "su fila esta cerrada ($cerrada[0]) y sigue fallando: la fila no dice la verdad") if @cerrada;
    return (0, "ninguna fila de _seo/BASE.md ni del plan nombra $id");
}

for my $h (@pendientes) {
    my $es_f = $h->{estado} eq 'FALLO';
    if ($para_ya) { $h->{r} = $es_f ? 'PARA' : 'SIGUE'; $h->{por} = 'no se mide: otro FALLO ya para la subida'; next }
    if ($h->{dom} && $dom_mal ne '') { $h->{r} = $es_f ? 'NO-MEDIDO' : 'SIGUE'; $h->{por} = "sale del DOM: $dom_mal"; next }
    if ($prod_mal) { $h->{r} = $es_f ? 'NO-MEDIDO' : 'SIGUE'; $h->{por} = "produccion no medida: $prod_mal"; next }
    my $p = $PROD{$h->{id}}{$h->{estado}};
    if (!$p && $es_f && $PROD{$h->{id}}{NV} && !$PROD{$h->{id}}{FALLO}) {
        # produccion no lo pudo mirar: ni viejo ni nuevo, sin medir
        $h->{r} = 'NO-MEDIDO'; $h->{por} = 'en produccion sale NO VERIFICADO: no se puede decir si es viejo';
        next;
    }
    unless ($p) {
        my @otro = sort keys %{ $PROD{$h->{id}} || {} };
        $h->{r} = $es_f ? 'PARA' : 'SIGUE';
        $h->{por} = 'solo en el candidato: en produccion ' . (@otro ? "sale $otro[0]" : 'no sale') . ' (es NUEVO)';
        next;
    }
    my @nuevas = grep { !$p->{$_} } @{ $h->{ins} };
    if (@nuevas) {
        $h->{r} = $es_f ? 'PARA' : 'SIGUE';
        $h->{por} = sprintf('%d de %d NUEVO en el candidato, que produccion no tiene: %s', scalar(@nuevas),
                            scalar(@{ $h->{ins} }), solo_ascii(substr(d57_des($nuevas[0]), 0, 90)));
        next;
    }
    my ($ok, $fila) = d57_fila_de($h->{id});
    unless ($ok) { $h->{r} = $es_f ? 'PARA' : 'SIGUE'; $h->{por} = $fila; next }
    $h->{r} = 'D-057';
    $h->{por} = sprintf('igual en produccion (%d de %d, produccion tiene %d) · %s', scalar(@{ $h->{ins} }),
                        scalar(@{ $h->{ins} }), scalar(keys %$p), $fila);
}

# ── la cuenta y la salida ─────────────────────────────────────────────────────
my $quita = 0;
unless ($prod_mal || !%PROD) {
    my %cand;
    for my $h (grep { $_->{estado} eq 'FALLO' } @H) { $cand{$h->{id}}{$_} = 1 for @{ $h->{ins} } }
    for my $id (keys %PROD) {
        next unless $PROD{$id}{FALLO};
        $quita += grep { !$cand{$id}{$_} } keys %{ $PROD{$id}{FALLO} };
    }
}
my %por;
for my $h (grep { defined $_->{r} } @H) {
    d57_di(sprintf('    %-9s %-5s %-9s %s', $h->{r}, $h->{estado}, $h->{id}, $h->{por}));
    my $k = $h->{r} eq 'D-057' ? ($h->{estado} eq 'FALLO' ? 'FALLO' : 'NV') : $h->{r};
    push @{ $por{$k} }, $h->{id};
}
d57_di('    (ningun FALLO ni sin mirar que decidir)') unless %por;
my $rc = $por{PARA} ? 1 : $por{'NO-MEDIDO'} ? 2 : 0;
d57_di('', 'D057-RESULTADO: ' . ($rc == 1 ? 'PARA' : $rc == 2 ? 'NO MEDIDO' : 'PASA'));
for my $k (qw(FALLO NV NO-APLICA PARA SIGUE NO-MEDIDO)) {
    d57_di("D057-$k: " . join(' ', @{ $por{$k} })) if $por{$k};
}
d57_di("D057-QUITA: $quita") unless $prod_mal || !%PROD;
# El recibo que se juzgo: scripts que leen este fichero despues (la fila de
# SEGUIMIENTO-14D) comprueban que es el de la subida, no el de otra puerta.
{
    my ($sello) = eval { open my $f, '<:raw', "$REPO/.qa-recibo" or die; local $/; my $t = <$f> // '';
                         $t =~ s/\r\n/\n/g; $t =~ /^SELLO:\s*([0-9a-f]{32})\s*$/m };
    d57_di("D057-RECIBO: $sello") if defined $sello;
}
d57_fin($rc);
