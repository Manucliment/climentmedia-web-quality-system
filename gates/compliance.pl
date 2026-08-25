#!/usr/bin/env perl
# =============================================================================
#  compliance.pl  ·  la matriz REGLA x WEB, generada. Nunca escrita a mano.
# =============================================================================
#  Perl 5 puro (viene con Git Bash). Sin dependencias fuera del core.
#
#  POR QUE EXISTE
#  --------------
#  Hoy nadie puede contestar «¿que webs cumplen el estandar ACTUAL?» sin volver
#  a medirlo todo a mano. Por eso la deriva se descubre un ano tarde, y por eso
#  `og:image:alt` se arreglo en site-a el 5-ago y el 10-ago seguia al 0%
#  en las otras cuatro —incluida climentmedia.com, donde vive el estandar.
#
#  Un informe de conformidad escrito a mano caduca el dia que se escribe. Este
#  se REGENERA: se corre uno, mide las webs del .conf con los gates que ya
#  existen, y cruza el resultado contra el estandar entero.
#
#  LO QUE MIRA QUE NINGUN OTRO MIRA
#  --------------------------------
#  `qa-master.pl` contesta «¿esta web pasa los gates?». Contesta bien, pero solo
#  puede hablar de lo que alguien cableo. La pregunta que nadie tenia contestada
#  es la de al lado: **¿cuanto del estandar tiene gate?** Aqui las reglas SIN
#  instrumento no desaparecen: salen como NO MEDIBLE, que es el estado que hacia
#  falta inventar. Un hueco que no se cuenta se lee como un aprobado, y ese es
#  literalmente el meta-patron de las 5 webs: el 404 esta especificado en
#  09 §2.11 y 08-qa-final lo menciona 0 veces; `data-sec` lo exige 09 §1 y hay
#  0 de 121 paginas.
#
#  LOS CINCO ESTADOS, Y POR QUE CINCO Y NO CUATRO
#  ---------------------------------------------
#    .  CUMPLE      el gate lo midio y esta bien
#    X  NO CUMPLE   el gate lo midio y esta mal
#    !  AVISO       el gate lo midio, hay que mirarlo, no bloquea por si solo
#    -  NO APLICA   declarado en el .conf CON un porque
#    ?  NO MEDIBLE  nadie lo ha mirado, y se dice por que:
#                     sin-gate ................ el estandar lo exige y no hay
#                                               instrumento. EL AGUJERO.
#                     no-comprobable-maquina .. el propio estandar lo marca asi
#                     instrumento-no-corrido .. hay gate, pero no en esta corrida
#                     gate-no-emitido ......... el gate existe y no dijo nada de
#                                               esta web (o no hay pagina de ese
#                                               tipo, o la lente no llego)
#  El AVISO es el quinto porque contarlo como CUMPLE esconde y contarlo como
#  NO CUMPLE convierte la matriz en una alarma. Se cuenta aparte.
#
#  DE DONDE SALE CADA COSA (nada de esto se reescribe aqui)
#  -------------------------------------------------------
#    el estandar ....... standard-rules.json (256 reglas atomicas con su
#                        doc:linea, su fecha y su gate). Es el INDICE de los 16
#                        references + SKILL.md + web-page-standard, no una copia.
#    la medida ......... qa-master.pl (74 comprobaciones, 5 lentes)
#    el enlazado ....... crawl-links.pl + linking-gate.pl (con --con-enlazado)
#    el diff de gates .. qa-diff.pl  <- NO se duplica aqui. qa-diff compara
#                        CORRIDAS a nivel de gate; esto compara ESTANDAR a nivel
#                        de regla, y ve lo que qa-diff no puede ver: una regla
#                        que no tiene gate no aparece en ninguna corrida.
#
#  USO
#  ---
#    perl compliance.pl                     mide las webs del .conf y genera la
#                                            matriz de hoy (y guarda el snapshot)
#    perl compliance.pl --webs site-a,bc      solo esas
#    perl compliance.pl --usar DIR          no vuelve a medir: usa los JSON de
#                                            qa-maestro que ya hay en DIR
#    perl compliance.pl --con-enlazado      suma el gate de enlazado (mas lento)
#
#    perl compliance.pl --desde 2026-08-05
#        RETROPROPAGACION SIN SNAPSHOT PREVIO. Reglas del estandar escritas
#        despues de esa fecha, y que web no las cumple todavia. Funciona el
#        primer dia, que es cuando hace falta: un diff que exige una corrida
#        anterior no sirve el dia que se estrena.
#
#    perl compliance.pl --retro [ANTES.json]
#        Compara con el snapshot anterior. Responde las tres preguntas:
#          · que reglas son NUEVAS en el estandar y quien no las cumple
#          · que se arreglo en una web y sigue roto en las demas  <- og:image:alt
#          · que comprobacion DESAPARECIO (baja el contador de fallos igual que
#            un arreglo; aqui es FALLO DURO, nunca una mejora)
#
#    perl compliance.pl --donde-mas SE-06
#        «Acabo de arreglar esto aqui, ¿a quien mas le pasa?» en un comando.
#        Acepta un id del estandar (SE-06) o un id de gate (SEO-06).
#
#    perl compliance.pl --autoprueba
#        Control positivo y negativos sobre una COPIA local. No toca ninguna web.
#
#    Opciones:
#      --conf F        (por defecto compliance.conf.example junto a este script)
#      --reglas F      (por defecto standard-rules.json junto a este script)
#      --historial DIR (por defecto historial/ junto a este script)
#      --json F        vuelca la matriz completa
#      --salida DIR    donde deja los JSON de qa-maestro de esta corrida
#      --todo          imprime tambien las filas que cumplen en todas
#      --sin-guardar   no escribe snapshot (pruebas)
#      --max-urls N    tope por web (manda sobre el .conf)
#      -q              solo lo que falla o no se ha medido
#
#  EXIT
#  ----
#    0  ninguna web incumple ninguna regla medida
#    1  hay incumplimientos (o, en --retro, hay regresion o comprobacion perdida)
#    2  no se pudo generar la matriz. NO es lo mismo que un 0.
#
#  🔴 REGLA DE PUBLICACION: en rojo no se despliega (SKILL.md · 06-publicar.md).
#     Esta matriz no despliega nada y no arregla nada. Solo hace imposible decir
#     «no lo sabiamos».
# =============================================================================

use strict;
use warnings;
use utf8;                  # sin esto los literales de aqui salen doble-codificados
use POSIX qw(strftime);
use File::Path qw(make_path);
use File::Basename qw(dirname basename);
use File::Spec;
use Digest::MD5 qw(md5_hex);
use JSON::PP;

binmode(STDOUT, ':encoding(UTF-8)');
binmode(STDERR, ':encoding(UTF-8)');

my $DIR = dirname(File::Spec->rel2abs($0));

# =============================================================================
#  0 · ARGUMENTOS
# =============================================================================
my %opt = (
    conf       => "$DIR/compliance.conf.example",
    reglas     => "$DIR/standard-rules.json",
    historial  => "$DIR/historial",
    webs       => '',
    usar       => '',
    salida     => '',
    json       => '',
    desde      => '',
    'donde-mas'=> '',
    retro      => undef,
    'max-urls' => 0,
    todo       => 0,
    'sin-guardar' => 0,
    'con-enlazado'=> 0,
    autoprueba => 0,
    q          => 0,
);
{
    my @a = @ARGV;
    while (@a) {
        my $x = shift @a;
        if ($x =~ /^--(conf|reglas|historial|webs|usar|salida|json|desde|donde-mas|max-urls)$/) {
            $opt{$1} = shift(@a) // '';
        } elsif ($x eq '--retro') {
            # el fichero es opcional: --retro [ANTES.json]
            if (@a && $a[0] !~ /^-/) { $opt{retro} = shift @a } else { $opt{retro} = '' }
        } elsif ($x =~ /^--(todo|sin-guardar|con-enlazado|autoprueba)$/) {
            $opt{$1} = 1;
        } elsif ($x eq '-q') { $opt{q} = 1 }
        elsif  ($x =~ /^(-h|--help)$/) {
            open my $f, '<:encoding(UTF-8)', $0 or die; while (<$f>) { last unless /^#/; print substr($_,2) } exit 0;
        } else { die "opcion desconocida: $x\n" }
    }
}

my $SELLO = strftime('%Y-%m-%d-%H%M', localtime);
my $FECHA = strftime('%Y-%m-%d %H:%M', localtime);
my $HOY   = strftime('%Y-%m-%d', localtime);

# =============================================================================
#  1 · EL ESTANDAR: standard-rules.json
# =============================================================================
#  Este fichero NO es documentacion nueva: es el indice maquinable de la que ya
#  hay. Cada regla trae su doc:linea, su fecha y el gate al que esta atada (o
#  NINGUNO). Si no esta, la matriz sigue corriendo pero solo sabe hablar de los
#  74 gates —y lo DICE, porque callarlo es exactamente el fallo que venimos a
#  matar: reportar como cubierto lo que nadie ha mirado.
# -----------------------------------------------------------------------------
sub leer_json {
    my ($f) = @_;
    open my $fh, '<:raw', $f or return undef;
    local $/; my $raw = <$fh>; close $fh;
    return eval { JSON::PP->new->utf8->relaxed->decode($raw) };
}
sub huella {
    my ($f) = @_;
    open my $fh, '<:raw', $f or return 'ausente';
    local $/; my $x = <$fh>; close $fh;
    return md5_hex($x // '');
}
sub escribir_json {
    my ($f, $data) = @_;
    make_path(dirname($f)) unless -d dirname($f);
    open my $fh, '>:raw', $f or die "no puedo escribir $f: $!\n";
    print $fh JSON::PP->new->utf8->canonical->pretty->encode($data);
    close $fh;
}

my (@REGLAS, %REGLA);
my $CATALOGO_OK = 0;
{
    my $j = leer_json($opt{reglas});
    if ($j && ref($j->{reglas}) eq 'ARRAY') {
        @REGLAS = @{ $j->{reglas} };
        $REGLA{$_->{id}} = $_ for @REGLAS;
        $CATALOGO_OK = 1;
    }
}

# gate (texto libre) -> ids de instrumento atados
#   "qa-maestro REN-09 / REN-12"      -> QAM:REN-09, QAM:REN-12
#   "linking-gate.pl R5"             -> ENL:R5
#   "linking-gate.pl"                -> ENL:*        (todo el gate)
#   "NINGUNO", "NINGUNO en qa-maestro"-> nada
#   "structure-gate.js", "qa-final.sh", "audit-vs-source.sh", "gate de CPL",
#   "measure-screens.js", "battery-layout.sh" -> OTRO:<nombre>  (no lo corre
#   este script: queda NO MEDIBLE / instrumento-no-corrido, dicho con nombre)
sub gates_de {
    my ($txt, $rid, $rtexto) = @_;
    $txt //= '';
    my (@qam, @enl, @otros);
    push @qam, uc($1).'-'.$2.($3//'')
        while $txt =~ /\b(seo|ren|a11y|med|est)-(\d+)([a-z]?)\b/gi;
    # 🔴 Los R solo se leen si el texto NOMBRA el gate de enlazado. Con
    #    /\b(r\d+)\b/ suelto, cualquier «R2» de cualquier frase entraba como
    #    regla del gate. Un patron demasiado ancho no da un fallo: da una
    #    atribucion plausible y falsa, que es peor.
    my $menciona_enl = ($txt =~ /enlazado-gate|crawl-enlaces/i) ? 1 : 0;
    push @enl, uc($1) while $menciona_enl && $txt =~ /\b(r\d+)\b/gi;
    # La regla ES una de las del gate: lo dice su propio id (EN-R5) o su texto
    # ("R5: el hub enlaza a TODOS sus hijos"). Sin esto, las 11 reglas EN-R*
    # colgaban del gate ENTERO y las 11 salian con la MISMA prueba —una sola
    # acusacion repetida once veces, que es justo lo que un barrido no debe hacer.
    if (!@enl) {
        if    (defined $rid    && $rid    =~ /^EN-(R\d+)$/i)   { @enl = (uc $1) }
        elsif (defined $rtexto && $rtexto =~ /^\s*(R\d+)\s*:/i){ @enl = (uc $1) }
    }
    for my $n (['linking-gate.pl','enlazado'], ['crawl-links.pl','enlazado'],
               ['structure-gate.js','structure-gate.js'],
               ['measure-screens.js','measure-screens.js'],
               ['qa-final.sh','qa-final.sh'],
               ['audit-vs-origen','audit-vs-origen'],
               ['bateria-maqueta','battery-layout.sh'],
               ['gate de CPL','gate de CPL'],
               # 19-ago-2026 · «audit.sh» sin guion bajo: el auditor SUBIO A LA
               # SKILL ese dia y cambio de nombre. La entrada vieja (`_audit.sh`)
               # dejo de casar y WPS-29 volvio a contar como «sin gate» -o sea
               # que renombrar un fichero desato una regla en silencio-. La
               # cadena sin guion casa las DOS formas, que es lo que se quiere.
               ['audit.sh','audit.sh']) {
        push @otros, $n->[1] if index(lc $txt, lc $n->[0]) >= 0;
    }
    # Nombra el gate de enlazado pero no se puede saber QUE regla suya: no se le
    # aplica el gate entero (eso repetia una acusacion en 11 reglas). Se queda
    # como instrumento sin cablear, con nombre, que es la verdad.
    # Las comprobaciones del auditor se nombran S1.6, S5.3... Antes no las leia
    # nadie: el auditor emite 32 y el catalogo no referenciaba NI UNA, asi que
    # su cobertura no contaba en la matriz. Se exige que el texto nombre TAMBIEN
    # el programa, por la misma razon que con las R del enlazado: un \bS\d suelto
    # casaria cualquier «S5» de cualquier frase, y un patron demasiado ancho no
    # da un fallo: da una atribucion plausible y falsa, que es peor.
    if (index(lc $txt, 'audit.sh') >= 0) {
        push @otros, "audit.sh $1" while $txt =~ /\b(S\d+\.\d+)\b/g;
    }
    my $sin_r = (grep { $_ eq 'enlazado' } @otros) && !@enl;
    my %v; @otros = grep { !$v{$_}++ && $_ ne 'enlazado' } @otros;
    push @otros, 'linking-gate.pl (sin regla R concreta en el estandar)' if $sin_r;
    my %w; @qam   = grep { !$w{$_}++ } @qam;
    my %x; @enl   = grep { !$x{$_}++ } @enl;
    return (\@qam, \@enl, \@otros);
}

# =============================================================================
#  2 · LAS WEBS: compliance.conf.example
# =============================================================================
sub leer_conf {
    my ($f) = @_;
    open my $fh, '<:encoding(UTF-8)', $f or die "no puedo leer $f: $!\n";
    my (@orden, %web, $cur);
    while (my $l = <$fh>) {
        chomp $l; $l =~ s/\r$//;
        next if $l =~ /^\s*(#|$)/;
        if ($l =~ /^\s*\[([^\]]+)\]\s*$/) { $cur = $1; push @orden, $cur; $web{$cur} = { clave=>$cur, no_aplica=>{} }; next }
        next unless $cur;
        my ($k,$v) = $l =~ /^\s*([a-z_]+)\s*=\s*(.*?)\s*$/ or next;
        if ($k eq 'no_aplica') {
            # EXIGE porque. Una exclusion sin motivo es donde se esconde la deriva.
            my ($ids,$porque) = $v =~ /^(.+?)\s*:\s*(.+)$/
                or die "conf [$cur]: no_aplica sin porque -> '$v'\n"
                     . "   Escribe  no_aplica = ID[,ID] : el motivo\n";
            $web{$cur}{no_aplica}{$_} = $porque for split /\s*,\s*/, $ids;
        } else { $web{$cur}{$k} = $v }
    }
    close $fh;
    return (\@orden, \%web);
}

# ── modo de ruta: URL <-> fichero del repo ───────────────────────────────────
#  🔴 Aqui es donde el auditor viejo se invento 332 fallos. No se adivina y no
#     se ignora: se declara en el .conf y se COMPRUEBA contra el repo. Si el
#     modo declarado no resuelve, esa web no entra en la matriz. Una web fuera
#     se ve; una web medida con el mapeo equivocado, no.
my %MODOS = (
    'plano-ext'     => sub { my ($p)=@_; $p =~ s{^/}{}; $p eq '' ? 'index.html' : $p },
    'plano-sin-ext' => sub { my ($p)=@_; $p =~ s{^/}{}; $p =~ s{/$}{};
                             $p eq '' ? 'index.html' : ($p =~ /\.[a-z0-9]+$/i ? $p : "$p.html") },
    'dir-barra'     => sub { my ($p)=@_; $p =~ s{^/}{}; $p =~ s{/$}{};
                             $p eq '' ? 'index.html' : ($p =~ /\.[a-z0-9]+$/i ? $p : "$p/index.html") },
    'dir-sin-barra' => sub { my ($p)=@_; $p =~ s{^/}{}; $p =~ s{/$}{};
                             $p eq '' ? 'index.html' : ($p =~ /\.[a-z0-9]+$/i ? $p : "$p/index.html") },
);
sub ruta_de_url {
    my ($url, $modo) = @_;
    my ($p) = $url =~ m{^https?://[^/]+(/.*)?$}; $p //= '/';
    $p =~ s/[?#].*$//;
    my $f = $MODOS{$modo} or die "modo de ruta desconocido: $modo\n";
    return $f->($p);
}
# cuantas URLs resuelve cada modo contra el repo (para acusar al modo, no a la web)
sub tanteo_modos {
    my ($urls, $repo) = @_;
    my %n;
    for my $m (keys %MODOS) {
        my $ok = 0;
        for my $u (@$urls) { my $r = ruta_de_url($u, $m); $ok++ if -f "$repo/$r" }
        $n{$m} = $ok;
    }
    return \%n;
}

sub urls_de_web {
    my ($w) = @_;
    my $sm = "$w->{repo}/sitemap.xml";
    my @u;
    if (open my $fh, '<:raw', $sm) {
        local $/; my $x = <$fh>; close $fh;
        while ($x =~ m{<loc>\s*([^<\s]+)\s*</loc>}gi) { push @u, $1 }
    }
    # El sitemap es la lista AUTORIZADA de rutas; el host manda el .conf. Se
    # rehostea en vez de fabricar URLs a partir de nombres de fichero: fabricar
    # es exactamente lo que produjo 332 fallos falsos en site-a.
    my $dom = $w->{dominio} // ''; $dom =~ s{/+$}{};
    my (%v, @o); my $ajenas = 0;
    for my $x (@u) {
        my ($host, $path) = $x =~ m{^https?://([^/]+)(/.*)?$} ? ($1, $2 // '/') : ('', $x);
        $ajenas++ if $host ne '' && $dom ne '' && "https://$host" ne $dom && "http://$host" ne $dom;
        my $full = $dom ne '' ? "$dom$path" : $x;
        my $k = $full; $k =~ s/\?.*$//;
        next if $v{$k}++;
        push @o, $k;
    }
    $w->{aviso_sitemap} = "$ajenas de ".scalar(@u)." <loc> del sitemap apuntan a otro host que el declarado en el .conf"
        if $ajenas;
    return @o;
}

# =============================================================================
#  3 · CORRER LOS INSTRUMENTOS
# =============================================================================
sub correr_qa_maestro {
    my ($w, $dir) = @_;
    my $out  = "$dir/$w->{clave}.json";
    my $urlf = "$dir/$w->{clave}-urls.txt";
    my $cach = "$dir/cache-$w->{clave}";
    make_path($cach) unless -d $cach;

    my @urls = urls_de_web($w);
    unless (@urls) { return { error => "sin sitemap legible en $w->{repo}/sitemap.xml" } }

    # ── guardia del modo de ruta ─────────────────────────────────────────────
    my $t = tanteo_modos(\@urls, $w->{repo});
    my ($mejor) = sort { $t->{$b} <=> $t->{$a} || $a cmp $b } keys %$t;
    my $decl = $w->{modo} // '';
    my $res_decl = $t->{$decl} // -1;
    my $total = scalar @urls;
    if ($res_decl < $total * 0.5) {
        return { error => "modo de ruta '$decl' resuelve $res_decl/$total ficheros del repo"
                        . " (el que mas resuelve es '$mejor' con $t->{$mejor}).",
                 modo_tanteo => $t };
    }
    if ($t->{$mejor} > $res_decl) {
        # no aborta, pero lo estampa: puede ser legitimo (paginas sin fichero)
        $w->{aviso_modo} = "declarado '$decl' resuelve $res_decl/$total; '$mejor' resuelve $t->{$mejor}";
    }

    my $max = $opt{'max-urls'} || $w->{max_urls} || 25;
    @urls = @urls[0 .. ($max-1)] if @urls > $max;
    open my $fh, '>:raw', $urlf or die "no puedo escribir $urlf\n";
    print $fh "$_\n" for @urls; close $fh;

    my @cmd = ($^X, "$DIR/qa-master.pl", "\@$urlf",
               '--json', $out, '--cache', $cach, '--repo', $w->{repo},
               # 19-ago-2026 · SIN ESTO, MEDIR LA CONFORMIDAD ROMPE EL DESPLIEGUE DE
               # LAS 5 WEBS. `--repo` hace que qa-maestro ESCRIBA el `.qa-recibo`, y
               # aqui se mide PRODUCCION: la matriz pisaba los recibos de candidato
               # con recibos de produccion, y la puerta se plantaba en el paso 1 con
               # «RECIBO NO VALIDO · medido contra PRODUCCION». Medido hoy: 4 de los 5
               # recibos pisados a la misma hora que la corrida. `--repo` sigue
               # haciendo falta -de ahi salen las exclusiones y el arbol-, lo que
               # sobra es el efecto secundario.
               '--sin-recibo',
               '--max-urls', $max, '-q');
    push @cmd, '--gracias',  $w->{gracias}  if ($w->{gracias}  // '') ne '';
    push @cmd, '--contacto', $w->{contacto} if ($w->{contacto} // '') ne '';

    my $log = '';
    if (open my $ph, '-|', @cmd) { local $/; $log = <$ph> // ''; close $ph }
    my $j = leer_json($out);
    return { error => "qa-maestro no dejo JSON legible en $out" } unless $j;
    return { json => $j, fichero => $out, urls => scalar(@urls), log => $log };
}

sub correr_enlazado {
    my ($w, $dir) = @_;
    my $g = "$dir/$w->{clave}-grafo.json";
    my $c = "$dir/cache-enl-$w->{clave}";
    make_path($c) unless -d $c;
    unless (-s $g) {
        system($^X, "$DIR/crawl-links.pl", "$w->{dominio}/", $c, $g, 200);
    }
    return { error => 'crawl-links.pl no dejo grafo' } unless -s $g;
    my $txt = '';
    if (open my $ph, '-|', $^X, "$DIR/linking-gate.pl", $g) { local $/; $txt = <$ph> // ''; close $ph }
    my %e;
    while ($txt =~ /^(PASA|FALLA|AVISO)\s+(R\d+)\s+(.*)$/gmi) {
        my $st = uc $1 eq 'PASA' ? 'PASA' : (uc $1 eq 'FALLA' ? 'FALLO' : 'AVISO');
        $e{uc $2} = { estado => $st, titulo => $3 };
    }
    return { reglas => \%e, texto => $txt };
}

# =============================================================================
#  4 · LA MATRIZ
# =============================================================================
my %PESO = (FALLO=>0, AVISO=>1, NV=>2, PASA=>3);   # peor primero
my %A_ESTADO = (FALLO=>'no_cumple', AVISO=>'aviso', NV=>'no_medible', PASA=>'cumple');

# ── ALCANCE DEL INSTRUMENTO: que gates acreditan el SITIO leyendo UNA pagina ──
#  🔴 Leido en el codigo de qa-master.pl, no supuesto:
#     lente_a11y()        linea 856  `my $u = $URLS[0]`  -> A11Y-01,02,05,06,07,08
#     lente_rendimiento() linea 603  `my $u = $URLS[0]`  -> toda la lente REN
#     lente_estructura()  linea 1402 `my $u = $URLS[0]`  -> EST-01, EST-02, EST-06, EST-07
#  La lente SEO SI recorre @PAGES, y EST-09 tambien.
#  Consecuencia: un CUMPLE de esos gates significa «la home cumple», no «el sitio
#  cumple». Se marca en la celda y se cuenta abajo, porque un aprobado de alcance
#  desconocido se lee como un aprobado del sitio — que es el mismo fallo que
#  convierte un NO VERIFICADO en un verde.
#  compliance-selftest.pl P3-bis vuelve a MEDIR esto en cada corrida: si algun
#  dia qa-maestro recorre todas las paginas, la prueba lo dira y esta lista se
#  queda corta a gritos, no en silencio.
# 🔴 18-ago-2026 · A11Y-01 y A11Y-02 SALEN. `compliance-selftest.pl` P3-bis
#  lo venia diciendo -- «declara A11Y-01 como home-only y ya NO lo es» -- y lo
#  decia en el vacio: la autoprueba existia SIN CABLEAR a run-all.sh, asi
#  que su rojo no lo leia nadie. Efecto: la matriz rebajaba a «solo-home» dos
#  CUMPLE que ya son del sitio entero. `qa-master.pl:426` los mide sobre TODAS
#  las paginas leidas desde hace tiempo.
#  ⚠️ 05/06/07/08 se quedan: la sonda NO los observo disparando fuera de la home,
#  y quitarlos «ya que estamos» seria inventar evidencia. Se quita lo medido.
my %HOME_ONLY = map { $_ => 1 } qw(
    A11Y-05 A11Y-06 A11Y-07 A11Y-08
    REN-01 REN-02 REN-03 REN-04 REN-05 REN-06 REN-07 REN-08 REN-09 REN-10 REN-11 REN-12
    EST-01 EST-02 EST-06 EST-07
);

sub construir_matriz {
    my ($orden, $web, $medidas) = @_;
    my %M;      # regla -> clave -> {estado, motivo, detalle}
    for my $r (@REGLAS) {
        my ($qam, $enl, $otros) = gates_de($r->{gate}, $r->{id}, $r->{texto});
        for my $k (@$orden) {
            my $w = $web->{$k};
            my $m = $medidas->{$k};

            # 1. declarado no aplica en el .conf (con porque)
            if (exists $w->{no_aplica}{$r->{id}}) {
                $M{$r->{id}}{$k} = { estado=>'no_aplica', motivo=>'declarado', detalle=>$w->{no_aplica}{$r->{id}} };
                next;
            }
            # 2. la web no se pudo medir
            if (!$m || $m->{error}) {
                $M{$r->{id}}{$k} = { estado=>'no_medible', motivo=>'web-no-medida',
                                     detalle=>($m ? $m->{error} : 'no incluida en esta corrida') };
                next;
            }
            # 3. gates de qa-maestro atados a la regla
            my @vistos;
            for my $g (@$qam) {
                push @vistos, { id=>$g, %{ $m->{gates}{$g} } } if $m->{gates}{$g};
            }
            for my $g (@$enl) {
                next unless $m->{enlazado};
                if ($g eq '*') { push @vistos, { id=>"ENL-$_", %{ $m->{enlazado}{$_} } } for sort keys %{ $m->{enlazado} } }
                elsif ($m->{enlazado}{$g}) { push @vistos, { id=>"ENL-$g", %{ $m->{enlazado}{$g} } } }
            }
            if (@vistos) {
                # peor de los atados: una regla no esta mejor que su peor gate
                @vistos = sort { $PESO{$a->{estado}} <=> $PESO{$b->{estado}} } @vistos;
                my $p = $vistos[0];
                $M{$r->{id}}{$k} = {
                    estado  => $A_ESTADO{$p->{estado}},
                    motivo  => ($p->{estado} eq 'NV' ? 'no-verificado' : 'medido'),
                    gate    => join(' ', map { $_->{id} } @vistos),
                    # ⚠️ PEOR DE LOS ATADOS. Cuando una regla cuelga de dos gates que
                    #    miden cosas distintas, el veredicto lo pone uno solo: se
                    #    deja escrito CUAL, porque «TP-16 en rojo» no significa lo
                    #    mismo si lo dice EST-04 (la gracias esta mal) que si lo dice
                    #    MED-05 (hay un data-* huerfano en otra parte del repo).
                    decide  => $p->{id},
                    detalle => ($p->{dato} // '') || ($p->{titulo} // ''),
                    # un CUMPLE de alcance «home» dice que la HOME cumple
                    ($HOME_ONLY{$p->{id}} ? (alcance => 'solo-home') : ()),
                };
                next;
            }
            # 4. sin nada que lo mire: se dice POR QUE
            my $motivo;
            my $det = '';
            if (($r->{comprobable_maquina}//'') eq 'no') { $motivo = 'no-comprobable-maquina'; $det = $r->{tipo}//'' }
            elsif (@$otros)                              { $motivo = 'instrumento-no-corrido'; $det = join(', ', @$otros) }
            elsif (@$qam || @$enl)                       { $motivo = 'gate-no-emitido'; $det = join(' ', @$qam, map {"ENL-$_"} @$enl) }
            else                                         { $motivo = 'sin-gate'; $det = $r->{gate}//'' }
            $M{$r->{id}}{$k} = { estado=>'no_medible', motivo=>$motivo, detalle=>$det };
        }
    }
    return \%M;
}

# =============================================================================
#  5 · SALIDA
# =============================================================================
my %SIM = (cumple=>'.', no_cumple=>'X', aviso=>'!', no_aplica=>'-', no_medible=>'?');

sub imprimir_matriz {
    my ($orden, $web, $M, $medidas) = @_;
    my $anchoc = 1; $anchoc = length($_) > $anchoc ? length($_) : $anchoc for @$orden; $anchoc += 2;

    print "\n", "=" x 100, "\n";
    print "  MATRIZ DE CONFORMIDAD  ·  $FECHA\n";
    print "=" x 100, "\n";
    printf "  ESTANDAR   %s  ·  %d reglas%s\n", basename($opt{reglas}), scalar(@REGLAS),
           ($CATALOGO_OK ? '' : '  ⚠ NO LEIDO');
    printf "  WEBS       %s\n", join(' ', map { "$_(".($web->{$_}{nombre}//'').")" } @$orden);
    for my $k (@$orden) {
        my $m = $medidas->{$k};
        if ($m && $m->{error}) { printf "  ⚠ %-5s FUERA DE LA MATRIZ: %s\n", $k, $m->{error} }
        elsif ($web->{$k}{aviso_modo}) { printf "  ⚠ %-5s modo de ruta: %s\n", $k, $web->{$k}{aviso_modo} }
        printf "  ⚠ %-5s sitemap: %s\n", $k, $web->{$k}{aviso_sitemap} if $web->{$k}{aviso_sitemap};
    }
    print "  LEYENDA    . cumple   X no cumple   ! aviso   - no aplica   ? no medible\n";
    print "-" x 100, "\n";

    # ── filas ────────────────────────────────────────────────────────────────
    printf "  %-9s %-5s %s   %s\n", 'REGLA', 'FECHA', join('', map { sprintf "%-*s", $anchoc, $_ } @$orden), 'DOC';
    my $filas = 0;
    for my $r (@REGLAS) {
        my @c = map { $M->{$r->{id}}{$_} } @$orden;
        my $interesante = grep { $_->{estado} eq 'no_cumple' || $_->{estado} eq 'aviso' } @c;
        my $todo_medible = !grep { $_->{estado} eq 'no_medible' } @c;
        next if !$opt{todo} && !$interesante && $todo_medible;
        next if $opt{q} && !$interesante;
        $filas++;
        my $f = $r->{fecha} // ''; $f =~ s/^\d{4}-//;
        printf "  %-9s %-5s %s   %s\n", $r->{id}, $f,
               join('', map { sprintf "%-*s", $anchoc, $SIM{$_->{estado}} } @c),
               substr(($r->{ref} // $r->{doc} // ''), 0, 34);
        my $t = $r->{texto} // ''; $t =~ s/\s+/ /g;
        printf "  %-15s  %s\n", '', substr($t, 0, 92) if length $t;
    }
    print "  (ninguna)\n" unless $filas;
}

sub recuentos {
    my ($orden, $M) = @_;
    my %n;
    for my $rid (keys %$M) { for my $k (@$orden) { $n{$k}{ $M->{$rid}{$k}{estado} }++ } }
    return \%n;
}

sub imprimir_resumen {
    my ($orden, $web, $M, $medidas) = @_;
    my $n = recuentos($orden, $M);
    print "\n", "-" x 100, "\n  RECUENTO POR WEB\n", "-" x 100, "\n";
    printf "  %-6s %-22s %7s %10s %7s %10s %11s\n", 'CLAVE','WEB','CUMPLE','NO CUMPLE','AVISO','NO APLICA','NO MEDIBLE';
    for my $k (@$orden) {
        printf "  %-6s %-22s %7d %10d %7d %10d %11d\n", $k, ($web->{$k}{nombre}//''),
            ($n->{$k}{cumple}//0), ($n->{$k}{no_cumple}//0), ($n->{$k}{aviso}//0),
            ($n->{$k}{no_aplica}//0), ($n->{$k}{no_medible}//0);
    }

    # ── por que no se mide lo que no se mide ────────────────────────────────
    my %mot;
    for my $rid (keys %$M) { for my $k (@$orden) {
        my $c = $M->{$rid}{$k}; $mot{$c->{motivo}}++ if $c->{estado} eq 'no_medible';
    } }
    print "\n  POR QUE NO SE MIDE (celdas)\n";
    printf "    %-26s %6d   %s\n", $_, $mot{$_}, {
        'sin-gate'               => 'el estandar lo exige y NO HAY INSTRUMENTO. El agujero.',
        'no-comprobable-maquina' => 'el propio estandar lo marca asi (juicio humano)',
        'instrumento-no-corrido' => 'hay gate, pero no entra en esta corrida',
        'gate-no-emitido'        => 'el gate existe y no dijo nada de esa web',
        'no-verificado'          => 'el gate corrio y dijo NO VERIFICADO',
        'web-no-medida'          => 'la web quedo fuera de la matriz',
    }->{$_} // '' for sort { $mot{$b} <=> $mot{$a} } keys %mot;

    # ── cobertura del estandar ──────────────────────────────────────────────
    my ($con, $sin) = (0,0);
    for my $r (@REGLAS) {
        my ($q,$e,$o) = gates_de($r->{gate}, $r->{id}, $r->{texto});
        (@$q || @$e) ? $con++ : $sin++;
    }
    printf "\n  COBERTURA DEL ESTANDAR   %d de %d reglas atadas a un gate que esta corrida puede leer (%.0f%%)\n",
        $con, scalar(@REGLAS), (@REGLAS ? 100*$con/scalar(@REGLAS) : 0);
    printf "                           %d reglas NO las mira nada de lo que corre aqui.\n", $sin;

    # ⚠ Una regla de PROCEDIMIENTO acreditada por un gate de RESULTADO se prueba
    #   por su sintoma, no por el gesto. AC-17 («una paleta no se hereda: se
    #   re-mide») sale en rojo porque el contraste falla —que es la prueba de que
    #   se heredo— pero el gate no ha visto a nadie re-medir. Se cuenta aparte
    #   para que nadie lea la matriz como si hubiera comprobado el gesto.
    my $indir = 0;
    for my $r (@REGLAS) {
        next unless ($r->{tipo}//'') eq 'procedimiento';
        my ($q,$e,$o) = gates_de($r->{gate}, $r->{id}, $r->{texto});
        $indir++ if @$q || @$e;
    }
    printf "                           %d de ellas son de PROCEDIMIENTO: el gate prueba el SINTOMA, no el gesto.\n", $indir;

    # ── alcance: cuanto del verde se ha ganado leyendo una sola pagina ───────
    my (%solo_home, $celdas_home);
    for my $rid (keys %$M) { for my $k (@$orden) {
        next unless ($M->{$rid}{$k}{alcance} // '') eq 'solo-home';
        $celdas_home++; $solo_home{$k}++ if $M->{$rid}{$k}{estado} eq 'cumple';
    } }
    if ($celdas_home) {
        print "\n  ALCANCE DEL INSTRUMENTO   (leido en el codigo de qa-master.pl, no supuesto)\n";
        print "    Las lentes de RENDIMIENTO y ESTRUCTURA, y 6 comprobaciones de A11Y, leen\n";
        print "    UNA sola pagina (\$URLS[0]). Un CUMPLE suyo dice «la home cumple».\n";
        printf "    %-6s %d celdas en CUMPLE acreditadas con una sola pagina\n", $_, $solo_home{$_}
            for sort { ($solo_home{$b}//0) <=> ($solo_home{$a}//0) } grep { $solo_home{$_} } @$orden;
    }

    # ── cola de retropropagacion: lo que falla en mas de una web ────────────
    my @cola;
    for my $r (@REGLAS) {
        my @mal = grep { $M->{$r->{id}}{$_}{estado} eq 'no_cumple' } @$orden;
        my @bien= grep { $M->{$r->{id}}{$_}{estado} eq 'cumple'    } @$orden;
        push @cola, { id=>$r->{id}, n=>scalar(@mal), mal=>\@mal, bien=>\@bien, texto=>$r->{texto}, ref=>$r->{ref} } if @mal >= 2;
    }
    @cola = sort { $b->{n} <=> $a->{n} || $a->{id} cmp $b->{id} } @cola;
    print "\n", "-" x 100, "\n  COLA DE RETROPROPAGACION  ·  reglas incumplidas en 2 o mas webs\n", "-" x 100, "\n";
    if (@cola) {
        for my $c (@cola[0 .. ($#cola > 24 ? 24 : $#cola)]) {
            my $t = $c->{texto}//''; $t =~ s/\s+/ /g;
            printf "  %-9s %d webs  [%s]%s\n", $c->{id}, $c->{n}, join(' ', @{$c->{mal}}),
                   (@{$c->{bien}} ? '  (ya cumple: '.join(' ', @{$c->{bien}}).')' : '');
            printf "  %-9s %s\n", '', substr($t, 0, 88);
        }
        printf "  ... y %d mas (todas en el JSON)\n", scalar(@cola)-25 if @cola > 25;
    } else { print "  (ninguna)\n" }
    return \@cola;
}

# =============================================================================
#  6 · MODOS QUE NO MIDEN: --desde, --retro, --donde-mas
# =============================================================================
sub ultimo_snapshot {
    my ($excluir) = @_;
    opendir(my $dh, $opt{historial}) or return undef;
    my @f = sort grep { /^conformidad-\d{4}-\d{2}-\d{2}-\d{4}\.json$/ } readdir($dh);
    closedir $dh;
    @f = grep { "$opt{historial}/$_" ne ($excluir//'') } @f;
    return @f ? "$opt{historial}/$f[-1]" : undef;
}

sub cargar_snapshot {
    my ($f) = @_;
    my $j = leer_json($f) or return undef;
    return $j;
}

# --desde FECHA: la retropropagacion que NO necesita corrida anterior.
sub informe_desde {
    my ($snap, $desde) = @_;
    my $orden = $snap->{webs};
    my @nuevas = grep { ($_->{fecha}//'') gt $desde } @{ $snap->{reglas} };
    print "\n", "=" x 100, "\n";
    print "  RETROPROPAGACION  ·  reglas del estandar posteriores a $desde\n";
    print "=" x 100, "\n";
    printf "  %d reglas nuevas de %d. Para cada una: quien NO la cumple todavia.\n\n", scalar(@nuevas), scalar(@{$snap->{reglas}});
    my ($pend, $ciegas) = (0,0);
    for my $r (sort { ($a->{fecha}//'') cmp ($b->{fecha}//'') || $a->{id} cmp $b->{id} } @nuevas) {
        my $cel = $snap->{matriz}{$r->{id}} or next;
        my @mal = grep { $cel->{$_}{estado} eq 'no_cumple' } @$orden;
        my @nm  = grep { $cel->{$_}{estado} eq 'no_medible' } @$orden;
        my @ok  = grep { $cel->{$_}{estado} eq 'cumple' } @$orden;
        next unless @mal || @nm == scalar(@$orden);
        $pend++ if @mal; $ciegas++ if !@mal && @nm == scalar(@$orden);
        my $t = $r->{texto}//''; $t =~ s/\s+/ /g;
        printf "  %-9s %-10s %s\n", $r->{id}, ($r->{fecha}//''), substr($t, 0, 76);
        printf "  %-20s NO CUMPLE: %s%s\n", '', (@mal ? join(' ', @mal) : '(nadie)'),
               (@ok ? "   ya cumple: ".join(' ', @ok) : '');
        printf "  %-20s SIN MEDIR: %s   (%s)\n", '', join(' ', @nm),
               join('/', do { my %v; grep { !$v{$_}++ } map { $cel->{$_}{motivo} } @nm }) if @nm;
        printf "  %-20s %s\n", '', ($r->{ref}//'');
        print "\n";
    }
    print "-" x 100, "\n";
    printf "  %d reglas nuevas con al menos una web incumpliendo.\n", $pend;
    printf "  %d reglas nuevas que NINGUNA web puede acreditar: no hay instrumento que las mire.\n", $ciegas;
    print  "  Este es el informe que no existia. og:image:alt se quedo en site-a porque nadie\n";
    print  "  pregunto «¿a quien mas le aplica?» el dia que se escribio la regla.\n";
    return $pend;
}

# --retro: diff de dos snapshots
sub informe_retro {
    my ($ahora, $antes) = @_;
    my $orden = $ahora->{webs};
    my %A = map { $_->{id} => $_ } @{ $antes->{reglas} };
    my %H = map { $_->{id} => $_ } @{ $ahora->{reglas} };

    print "\n", "=" x 100, "\n";
    print "  RETROPROPAGACION  ·  $antes->{generado}   ->   $ahora->{generado}\n";
    print "=" x 100, "\n";

    # ── ¿han cambiado las WEBS o ha cambiado el INSTRUMENTO? ────────────────
    my $ma = $antes->{instrumento}{md5} || {};
    my $mh = $ahora->{instrumento}{md5} || {};
    my @cambia = grep { ($ma->{$_} // '?') ne ($mh->{$_} // '?') } sort keys %{{ %$ma, %$mh }};
    my @gate_cambia = grep { !/^estandar/ } @cambia;
    if (@cambia && !@gate_cambia) {
        print "  Instrumento identico; lo que ha cambiado es EL ESTANDAR (", join(', ', @cambia), ").\n";
        print "  Es el caso normal de este informe: reglas nuevas contra webs que ya estaban.\n\n";
    } elsif (@gate_cambia) {
        print "  ⚠ EL INSTRUMENTO HA CAMBIADO ENTRE LAS DOS CORRIDAS: ", join(', ', @gate_cambia), "\n";
        print "    Todo lo de abajo puede ser un cambio de la MEDIDA y no de las WEBS.\n";
        print "    Para atribuir un arreglo a una web, las dos corridas tienen que haberse\n";
        print "    hecho con el mismo instrumento (o volver a medir la de antes con este).\n\n";
    } else {
        print "  Instrumento identico en las dos corridas: lo que cambia son las webs.\n\n";
    }

    my @nuevas   = grep { !$A{$_} } map { $_->{id} } @{ $ahora->{reglas} };
    my @retirada = grep { !$H{$_} } map { $_->{id} } @{ $antes->{reglas} };
    printf "  ESTANDAR   %d reglas antes  ->  %d ahora   (+%d nuevas, -%d retiradas)\n",
        scalar(@{$antes->{reglas}}), scalar(@{$ahora->{reglas}}), scalar(@nuevas), scalar(@retirada);

    # 1. REGLAS NUEVAS y quien no las cumple  <- el informe que faltaba
    print "\n", "-" x 100, "\n  1 · REGLAS NUEVAS EN EL ESTANDAR, Y QUIEN NO LAS CUMPLE\n", "-" x 100, "\n";
    my $pend = 0;
    for my $id (sort @nuevas) {
        my $cel = $ahora->{matriz}{$id} or next;
        my @mal = grep { $cel->{$_}{estado} eq 'no_cumple' } @$orden;
        my @nm  = grep { $cel->{$_}{estado} eq 'no_medible' } @$orden;
        next unless @mal || @nm;
        $pend++ if @mal;
        my $t = ($H{$id}{texto}//''); $t =~ s/\s+/ /g;
        printf "  %-9s %s\n", $id, substr($t,0,84);
        printf "  %-9s NO CUMPLE %s%s\n", '', join(' ', @mal), (@nm ? "   ·  SIN MEDIR ".join(' ', @nm) : '') if @mal;
        printf "  %-9s SIN MEDIR %s\n", '', join(' ', @nm) if !@mal && @nm;
    }
    print "  (ninguna)\n" unless $pend;

    # 2. cambios celda a celda
    print "\n", "-" x 100, "\n  2 · QUE CAMBIO EN CADA WEB\n", "-" x 100, "\n";
    my (@arreglado, @roto, @perdido);
    for my $id (sort keys %{ $ahora->{matriz} }) {
        next unless $antes->{matriz}{$id};
        for my $k (@$orden) {
            my $a = $antes->{matriz}{$id}{$k} or next;
            my $h = $ahora->{matriz}{$id}{$k} or next;
            next if $a->{estado} eq $h->{estado};
            if    ($h->{estado} eq 'cumple'     && $a->{estado} eq 'no_cumple') { push @arreglado, [$id,$k] }
            elsif ($h->{estado} eq 'no_cumple'  && $a->{estado} eq 'cumple')    { push @roto, [$id,$k] }
            elsif ($h->{estado} eq 'no_medible' && $a->{estado} =~ /^(cumple|no_cumple|aviso)$/) {
                push @perdido, [$id,$k,$h->{motivo}];
            }
        }
    }
    printf "  ARREGLADO  %d celdas\n", scalar(@arreglado);
    printf "    %-9s %s\n", $_->[0], $_->[1] for @arreglado[0 .. ($#arreglado > 14 ? 14 : $#arreglado)];
    printf "  ROTO       %d celdas   <- regresion\n", scalar(@roto);
    printf "    %-9s %s\n", $_->[0], $_->[1] for @roto;
    printf "  PERDIDO    %d celdas   <- LA COMPROBACION DESAPARECIO\n", scalar(@perdido);
    printf "    %-9s %-6s %s\n", $_->[0], $_->[1], $_->[2] for @perdido;
    if (@perdido) {
        print "  🔴 Una comprobacion que desaparece baja el contador de fallos EXACTAMENTE\n";
        print "     igual que un arreglo. Aqui es fallo duro, nunca una mejora.\n";
    }

    # 3. arreglado en una, pendiente en las demas  <- og:image:alt
    print "\n", "-" x 100, "\n  3 · ARREGLADO EN UNA WEB Y PENDIENTE EN OTRAS  (el caso og:image:alt)\n", "-" x 100, "\n";
    my $n3 = 0;
    my %arr; $arr{$_->[0]}{$_->[1]} = 1 for @arreglado;
    for my $id (sort keys %arr) {
        my $cel = $ahora->{matriz}{$id};
        my @mal = grep { $cel->{$_}{estado} eq 'no_cumple' } @$orden;
        next unless @mal;
        $n3++;
        printf "  %-9s arreglado en [%s]  ·  SIGUE ROTO en [%s]\n", $id,
            join(' ', sort keys %{$arr{$id}}), join(' ', @mal);
    }
    print "  (ninguna)\n" unless $n3;

    return (scalar(@roto) + scalar(@perdido) + $pend);
}

# --donde-mas: la consulta de un comando
sub informe_donde_mas {
    my ($snap, $q) = @_;
    my $orden = $snap->{webs};
    my %R = map { $_->{id} => $_ } @{ $snap->{reglas} };
    print "\n", "=" x 100, "\n  ¿A QUIEN MAS LE PASA?  ·  $q\n";
    print "  (matriz de $snap->{generado})\n", "=" x 100, "\n";

    my @ids;
    if ($R{uc $q}) { @ids = (uc $q) }
    else {
        # id de gate: todas las reglas atadas a el
        my $g = uc $q;
        for my $r (@{ $snap->{reglas} }) {
            my ($qam,$enl,$o) = gates_de($r->{gate}, $r->{id}, $r->{texto});
            push @ids, $r->{id} if grep { $_ eq $g } @$qam, map {"R$_"} @$enl;
        }
        unless (@ids) {
            print "  No conozco '$q' ni como regla del estandar ni como gate.\n";
            print "  Reglas: ", join(' ', (sort keys %R)[0..9]), " ...\n";
            return 2;
        }
        printf "  '%s' es un gate. Reglas del estandar atadas a el: %s\n\n", $g, join(' ', @ids);
    }
    my $pend = 0;
    for my $id (@ids) {
        my $r = $R{$id}; my $cel = $snap->{matriz}{$id};
        my $t = $r->{texto}//''; $t =~ s/\s+/ /g;
        printf "  %s  ·  %s  ·  escrita %s\n", $id, ($r->{ref}//''), ($r->{fecha}//'?');
        printf "  %s\n", $t;
        printf "  gate: %s   ·  tipo: %s%s\n", ($r->{gate}//'NINGUNO'), ($r->{tipo}//'?'),
            (($r->{tipo}//'') eq 'procedimiento' ? '  ⚠ el gate prueba el sintoma, no el gesto' : '');
        for my $k (@$orden) {
            my $c = $cel->{$k};
            $pend++ if $c->{estado} eq 'no_cumple';
            printf "    %-6s %-11s %-9s %-9s %s\n", $k, $c->{estado},
                   ($c->{decide} // $c->{motivo} // ''),
                   (($c->{alcance}//'') eq 'solo-home' ? 'SOLO-HOME' : ''),
                   substr(($c->{detalle}//''), 0, 46);
        }
        my @mal = grep { $cel->{$_}{estado} eq 'no_cumple' } @$orden;
        my @nm  = grep { $cel->{$_}{estado} eq 'no_medible' } @$orden;
        print  "\n";
        printf "  >>> APLICAR TAMBIEN EN: %s\n", (@mal ? join(' ', @mal) : '(ninguna la incumple)');
        printf "  >>> Y COMPROBAR A MANO: %s   (nadie las ha mirado)\n", join(' ', @nm) if @nm;
        print  "\n";
    }
    return $pend ? 1 : 0;
}

# =============================================================================
#  7 · EJECUCION
# =============================================================================
if ($opt{autoprueba}) {
    my $rc = system($^X, "$DIR/compliance-selftest.pl");
    exit($rc == -1 ? 2 : ($rc >> 8));
}

# Modos que solo LEEN el ultimo snapshot: no vuelven a medir.
if (defined $opt{retro} || $opt{'donde-mas'} ne '' || ($opt{desde} ne '' && !$opt{usar})) {
    my $ult = ultimo_snapshot();
    if ($ult && !$opt{usar}) {
        my $snap = cargar_snapshot($ult) or die "no puedo leer $ult\n";
        if ($opt{'donde-mas'} ne '') { exit informe_donde_mas($snap, $opt{'donde-mas'}) }
        if ($opt{desde} ne '')       { exit(informe_desde($snap, $opt{desde}) ? 1 : 0) }
        if (defined $opt{retro}) {
            my $antesf = $opt{retro} ne '' ? $opt{retro} : ultimo_snapshot($ult);
            unless ($antesf) {
                print "\n  No hay snapshot anterior con el que comparar.\n";
                print "  Usa --desde FECHA: la fecha de cada regla esta en el propio estandar,\n";
                print "  asi que la retropropagacion se puede contestar el primer dia.\n";
                exit 2;
            }
            my $antes = cargar_snapshot($antesf) or die "no puedo leer $antesf\n";
            exit(informe_retro($snap, $antes) ? 1 : 0);
        }
    } elsif (!$opt{usar}) {
        print "\n  No hay ninguna matriz guardada en $opt{historial}.\n";
        print "  Corre primero:  perl compliance.pl\n";
        exit 2;
    }
}

# ── medir ────────────────────────────────────────────────────────────────────
my ($orden, $web) = leer_conf($opt{conf});
if ($opt{webs} ne '') {
    my %s = map { $_ => 1 } split /\s*,\s*/, $opt{webs};
    $orden = [ grep { $s{$_} } @$orden ];
    @$orden or die "ninguna de esas webs esta en $opt{conf}\n";
}
@REGLAS or do {
    warn "\n⚠ NO HE PODIDO LEER EL ESTANDAR ($opt{reglas}).\n"
       . "  Sin el, esto solo sabria hablar de los 74 gates y se leeria como si\n"
       . "  cubriera el estandar entero. Eso es el fallo que este fichero existe\n"
       . "  para matar, asi que no sigo.\n";
    exit 2;
};

# Los JSON crudos y la cache de descargas NO van al historial: pesan y no se
# consultan. Al historial va solo la matriz. Con --salida se conservan.
my $SALIDA = $opt{salida} || (File::Spec->tmpdir() . "/conformidad-$SELLO");
make_path($SALIDA) unless -d $SALIDA;
print STDERR "  corrida en $SALIDA\n";

my %medidas;
for my $k (@$orden) {
    my $w = $web->{$k};
    my $r;
    if ($opt{usar} ne '') {
        my $j = leer_json("$opt{usar}/$k.json");
        $r = $j ? { json => $j, fichero => "$opt{usar}/$k.json" } : { error => "no hay $opt{usar}/$k.json" };
        # el modo de ruta se comprueba igual: un JSON reutilizado no exime
        if (!$r->{error} && -d ($w->{repo}//'')) {
            my @u = urls_de_web($w);
            if (@u) {
                my $t = tanteo_modos(\@u, $w->{repo});
                my ($mej) = sort { $t->{$b} <=> $t->{$a} || $a cmp $b } keys %$t;
                $w->{aviso_modo} = "declarado '$w->{modo}' resuelve $t->{$w->{modo}}/".scalar(@u)."; '$mej' resuelve $t->{$mej}"
                    if $t->{$mej} > ($t->{$w->{modo}} // -1);
            }
        }
    } else {
        printf STDERR "  midiendo %-6s %s ...\n", $k, ($w->{dominio}//'');
        $r = correr_qa_maestro($w, $SALIDA);
    }
    if ($r->{error}) { $medidas{$k} = $r; next }
    my %g;
    for my $c (@{ $r->{json}{comprobaciones} }) {
        # si un id sale dos veces, manda el peor
        next if $g{$c->{id}} && $PESO{$g{$c->{id}}{estado}} <= $PESO{$c->{estado}};
        $g{$c->{id}} = $c;
    }
    $r->{gates} = \%g;
    if ($opt{'con-enlazado'} && $opt{usar} eq '') {
        printf STDERR "  enlazado %-6s ...\n", $k;
        my $e = correr_enlazado($w, $SALIDA);
        $r->{enlazado} = $e->{reglas} unless $e->{error};
    }
    $medidas{$k} = $r;
}

my $M = construir_matriz($orden, $web, \%medidas);

imprimir_matriz($orden, $web, $M, \%medidas) unless $opt{q} && $opt{json} ne '';
my $cola = imprimir_resumen($orden, $web, $M, \%medidas);

# ── snapshot ─────────────────────────────────────────────────────────────────
my $snap = {
    generado    => $FECHA,
    sello       => $SELLO,
    estandar    => { fichero => $opt{reglas}, reglas => scalar(@REGLAS) },
    # 🔴 HUELLA DEL INSTRUMENTO. Sin esto, un cambio en el gate o en el catalogo
    #    de reglas se lee en el diff como un cambio en las WEBS. Es la version
    #    de QA del «arreglo» que en realidad era que el instrumento midio otra
    #    cosa. --retro lo compara y lo grita antes de enseñar ningun numero.
    instrumento => { qa_maestro => "$DIR/qa-master.pl",
                     enlazado   => ($opt{'con-enlazado'} ? 'si' : 'no'),
                     perl       => "$]",
                     md5        => { map { basename($_) => huella($_) }
                                     ("$DIR/compliance.pl", "$DIR/qa-master.pl", $opt{reglas}) } },
    webs        => $orden,
    detalle_web => { map { $_ => { nombre=>$web->{$_}{nombre}, dominio=>$web->{$_}{dominio},
                                   modo=>$web->{$_}{modo}, repo=>$web->{$_}{repo},
                                   error=>($medidas{$_}{error}//undef),
                                   aviso_modo=>($web->{$_}{aviso_modo}//undef),
                                   urls=>($medidas{$_}{urls}//undef) } } @$orden },
    # 19-ago-2026 · SE GUARDAN TAMBIEN LOS ENGANCHES YA PARSEADOS (`gates`).
    # El campo `gate` es texto libre y quien sabe leerlo es `gates_de`, aqui
    # dentro. Si otro programa quisiera auditar la cobertura tendria que volver
    # a escribir esa gramatica, y entonces habria DOS sitios donde vive la misma
    # regla -que es exactamente el defecto que este trabajo esta cerrando-.
    # Guardandolos, `rule-instrument-index.pl` los LEE en vez de re-parsear.
    reglas      => [ map { { id=>$_->{id}, texto=>$_->{texto}, doc=>$_->{doc}, ref=>$_->{ref},
                             fecha=>$_->{fecha}, gate=>$_->{gate}, tipo=>$_->{tipo},
                             gates=>do { my ($q,$e,$o) = gates_de($_->{gate}, $_->{id}, $_->{texto});
                                         { qam=>$q, enl=>$e, otros=>$o } },
                             comprobable_maquina=>$_->{comprobable_maquina} } } @REGLAS ],
    matriz      => $M,
    recuento    => recuentos($orden, $M),
    cola_retro  => $cola,
};
unless ($opt{'sin-guardar'}) {
    my $f = "$opt{historial}/conformidad-$SELLO.json";
    escribir_json($f, $snap);
    print "\n  SNAPSHOT   $f\n";
    my $prev = ultimo_snapshot($f);
    print "  ANTERIOR   ", ($prev // '(ninguno: hoy es el primer dia)'), "\n";
    print "  RETRO      perl compliance.pl --retro        (compara con el anterior)\n" if $prev;
    print "  RETRO      perl compliance.pl --desde FECHA  (no necesita anterior)\n" unless $prev;

    # ---- 19-ago-2026 · EL INDICE, AQUI, Y NO POR CEREMONIA -------------------
    #  La cobertura que acaba de imprimirse ARRIBA se apoya en que el campo
    #  `gate` de cada regla apunte a algo que existe. Si apunta a un check que
    #  el instrumento no emite, la regla cuenta como cubierta y NO LA MIDE
    #  NADIE: el porcentaje sale inflado y hacia arriba, que es la direccion
    #  peligrosa. Medido el dia que se escribio esto: 7 enganches rotos, uno de
    #  ellos porque `_audit.sh` cambio de nombre esa misma manana.
    #  Por eso el indice se corre AQUI y no se deja para que alguien se acuerde.
    if (-f "$DIR/rule-instrument-index.pl") {
        my $salida = `"$^X" "$DIR/rule-instrument-index.pl" --snap "$f" 2>&1`;
        my $rc = $? >> 8;
        my ($rotos) = $salida =~ /(\d+) enganche\(s\) roto\(s\)/;
        my ($sing)  = $salida =~ /(\d+) reglas\. Es la unica/;
        print "\n  INDICE     regla -> instrumento\n";
        printf("             enganches ROTOS: %s%s\n", ($rotos // 0),
               (($rotos // 0) ? "   <-- la cobertura de arriba esta INFLADA" : "   (la cobertura de arriba se sostiene)"));
        printf("             sin gate y comprobables por maquina: %s\n", ($sing // '?'));
        print  "             el detalle:  perl rule-instrument-index.pl\n";
    }
}
escribir_json($opt{json}, $snap) if $opt{json} ne '';

if ($opt{desde} ne '') { informe_desde($snap, $opt{desde}) }

my $incumple = 0;
for my $rid (keys %$M) { for my $k (@$orden) { $incumple++ if $M->{$rid}{$k}{estado} eq 'no_cumple' } }
my $fuera = grep { $medidas{$_}{error} } @$orden;
print "\n", "=" x 100, "\n";
printf "  %d celdas en NO CUMPLE  ·  %d webs fuera de la matriz\n", $incumple, $fuera;
print  "  La matriz no arregla nada. Solo hace imposible decir «no lo sabiamos».\n";
print  "=" x 100, "\n";
exit($fuera ? 2 : ($incumple ? 1 : 0));
