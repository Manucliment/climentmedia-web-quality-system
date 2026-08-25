#!/usr/bin/perl
# =============================================================================
#  Prueba de crawl-links.pl · control POSITIVO y control NEGATIVO
# =============================================================================
#  Se corre con UNA linea desde PowerShell (bash no esta en el PATH):
#    perl "/path/to/web-quality-system/gates/crawl-links-tests/tests.pl"
#
#  🔴 POR QUE EXISTE: esta herramienta BLOQUEA despliegues de webs vivas. Un
#     detector que solo se ha visto en verde no prueba nada, y uno demasiado
#     laxo es tan malo como uno estricto: el detector de migas viejo buscaba
#     solo "breadcrumb" y acusaba en falso a 42 paginas de site-a y site-d que
#     SI tienen miga. Al arreglarlo hay que demostrar las dos direcciones:
#       · POSITIVO — la miga que existe se detecta (y con el marcado REAL de
#                    las 5 webs, copiado tal cual, no una version idealizada).
#       · NEGATIVO — lo que NO es una miga no se detecta. Aqui vive el riesgo
#                    de haber cambiado un falso positivo por otro.
#
#  ⚠️ NO toca la red. Siembra la cache que crawl-links.pl ya usa, asi que
#     ejercita el codigo DE VERDAD (clean_html incluido), no una copia.
# =============================================================================
use strict; use warnings;
use JSON::PP; use Digest::MD5 qw(md5_hex); use File::Path qw(make_path remove_tree);
use File::Temp qw(tempdir);

my $DIR    = $0; $DIR =~ s{[/\\][^/\\]+$}{};
my $CRAWL  = "$DIR/../crawl-links.pl";
die "no encuentro $CRAWL\n" unless -f $CRAWL;
my $HOST   = 'fx.test';
my $START  = "https://$HOST/";

my ($ok, $ko) = (0, 0);

# siembra una entrada de cache: crawl-links.pl no pide nada si el .meta existe
sub seed {
    my ($cache, $url, $code, $body, $ctype) = @_;
    my $k = md5_hex($url);
    open my $m, '>', "$cache/$k.meta" or die $!;
    print $m "$code|$url|0|" . ($ctype // 'text/html; charset=utf-8');
    close $m;
    open my $b, '>:raw', "$cache/$k.body" or die $!;
    print $b (defined $body ? $body : '');
    close $b;
}

# caso <etiqueta> <esperado 0|1> <html del <body>>
sub caso {
    my ($eti, $esperado, $body_html) = @_;
    my $tmp   = tempdir(CLEANUP => 1);
    my $cache = "$tmp/c"; make_path($cache);
    my $out   = "$tmp/g.json";

    my $html = "<!DOCTYPE html><html lang=\"es\"><head><title>T</title></head>"
             . "<body>$body_html</body></html>";
    seed($cache, "https://$HOST/sitemap.xml", 404, '', 'text/html');
    seed($cache, $START, 200, $html);

    # maxpages=1: la prueba es HERMETICA. Si dejo que siga enlaces, un fixture
    # con <a href="loja.html"> se sale a la red de verdad -- y ademas mete una
    # segunda pagina en el JSON, con lo que leer "la primera que salga" lee la
    # equivocada. Ya me paso: dio MAL con el detector funcionando bien.
    my $log = `perl "$CRAWL" "$START" "$cache" "$out" 1 2>&1`;
    if (!-f $out) {
        printf "  MAL   %-52s el rastreador no produjo salida: %s\n", $eti, ($log // '');
        $ko++; return;
    }
    my $j = JSON::PP->new->decode(do { local $/; open my $h, '<', $out or die $!; <$h> });
    my $rec = $j->{pages}{$START};
    if (!$rec) {
        printf "  MAL   %-52s no hay registro para %s (claves: %s)\n",
               $eti, $START, join(', ', sort keys %{ $j->{pages} });
        $ko++; return;
    }
    my $real = ($rec->{has_breadcrumb_visible} ? 1 : 0);
    if ($real == $esperado) {
        printf "  OK    %-52s miga=%d\n", $eti, $real; $ok++;
    } else {
        printf "  MAL   %-52s esperaba miga=%d y salio %d\n", $eti, $esperado, $real; $ko++;
    }
}

print "\n== CONTROL POSITIVO · marcado REAL de las 5 webs (copiado tal cual)\n";
# site-a.example/services:53 y zones/ath.html:53
caso('site-a (fr) nav.crumbs + aria "Fil d\'Ariane"', 1,
     q{<nav class="crumbs" aria-label="Fil d'Ariane"><ol><li><a href="/">Accueil</a></li><li aria-current="page">Nos services</li></ol></nav>});
# site-d.example clinica/index.html:39
caso('site-d (es) nav.crumbs.wrap + "Miga de pan"', 1,
     q{<nav class="crumbs wrap" aria-label="Miga de pan"><ol><li><a href="/">Inicio</a></li><li aria-current="page">La clinica</li></ol></nav>});
# shop.site-b.example carrinho.html:21 -- div, SIN aria-label
caso('site-b (pt) div.crumbs sin aria-label', 1,
     q{<div class="crumbs" style="padding-top:0"><a href="loja.html">Loja</a><span class="sep">/</span><span>Carrinho</span></div>});

print "\n== CONTROL POSITIVO · variantes que el detector debe cubrir\n";
caso('ingles: aria-label="Breadcrumb"', 1, q{<nav aria-label="Breadcrumb"><ol><li>a</li></ol></nav>});
caso('ingles: class="breadcrumb" (el patron viejo)', 1, q{<ol class="breadcrumb"><li>a</li></ol>});
caso('comillas simples: class=\'crumbs\'', 1, q{<nav class='crumbs'><ol><li>a</li></ol></nav>});
caso('id en vez de class: id="breadcrumbs"', 1, q{<div id="breadcrumbs"><a href="/">Inicio</a></div>});
caso('plural es: aria-label="Migas de pan"', 1, q{<nav aria-label="Migas de pan"><ol><li>a</li></ol></nav>});
caso('microdata itemtype BreadcrumbList (marcado real)', 1,
     q{<ol itemscope itemtype="https://schema.org/BreadcrumbList"><li>a</li></ol>});

print "\n== CONTROL NEGATIVO · lo que NO es una miga y no puede acusarse\n";
# climentmedia.com: 36 paginas asi. Es un FALLO REAL y tiene que seguir saliendo.
caso('climentmedia: SOLO JSON-LD, sin miga en pantalla', 0,
     q{<script type="application/ld+json">{"@type":"BreadcrumbList","itemListElement":[]}</script><nav class="nav-links" aria-label="Main navigation"><a href="/">Home</a></nav>});
caso('script inline que CONSTRUYE class="breadcrumb"', 0,
     q{<div id="app"></div><script>document.body.innerHTML='<nav class="breadcrumb"><a href="/">Inicio</a></nav>';</script>});
caso('la palabra en PROSA, no en un atributo', 0,
     q{<main><p>Este articulo explica que es un breadcrumb y una miga de pan.</p></main>});
caso('class="amigas" (la \\b de "miga")', 0, q{<section class="amigas"><p>x</p></section>});
caso('class="hormiga" (la \\b de "miga")', 0, q{<section class="hormiga"><p>x</p></section>});
caso('aria-label="Mariane" (la \\b de "ariane")', 0, q{<nav aria-label="Mariane"><a href="/">x</a></nav>});
caso('pagina normal sin nada de esto', 0,
     q{<header><nav aria-label="Principal"><a href="/">Inicio</a></nav></header><main><h1>Hola</h1></main>});
caso('noscript con una miga (no se pinta si hay JS)', 0,
     q{<noscript><nav class="crumbs"><a href="/">Inicio</a></nav></noscript><main><h1>Hola</h1></main>});

print "\n== EL SCHEMA SE MIDE DENTRO DEL <script>, NO EN LA PAGINA · 13-ago-2026\n";
# 🔴 EL DEFECTO: `has_breadcrumb_schema` era `$html =~ /BreadcrumbList/`, o sea
#    la PALABRA en cualquier parte del HTML. climentmedia.com/agents/web-audit-kit/copy/
#    documenta que schema lleva cada tipo de pagina y ENSENA el ejemplo escapado
#    (`&lt;script...&gt;{"@type":"BreadcrumbList"`). R6 la acusaba de «emite
#    BreadcrumbList sin pintar la miga» para siempre: no emite ninguno.
sub caso_schema {
    my ($eti, $esperado, $body_html) = @_;
    my $tmp   = tempdir(CLEANUP => 1);
    my $cache = "$tmp/c"; make_path($cache);
    my $out   = "$tmp/g.json";
    my $html  = "<!DOCTYPE html><html lang=\"es\"><head><title>T</title></head><body>$body_html</body></html>";
    seed($cache, "https://$HOST/sitemap.xml", 404, '', 'text/html');
    seed($cache, $START, 200, $html);
    my $log = `perl "$CRAWL" "$START" "$cache" "$out" 1 2>&1`;
    if (!-f $out) { printf "  MAL   %-52s sin salida: %s\n", $eti, ($log//''); $ko++; return }
    my $j = JSON::PP->new->decode(do { local $/; open my $h,'<',$out or die $!; <$h> });
    my $real = $j->{pages}{$START}{has_breadcrumb_schema} ? 1 : 0;
    if ($real == $esperado) { printf "  OK    %-52s schema=%d\n", $eti, $real; $ok++ }
    else { printf "  MAL   %-52s esperaba schema=%d y salio %d\n", $eti, $esperado, $real; $ko++ }
}
caso_schema('JSON-LD de verdad SE detecta', 1,
    q{<script type="application/ld+json">{"@context":"https://schema.org","@type":"BreadcrumbList","itemListElement":[]}</script><main><h1>x</h1></main>});
caso_schema('con comillas simples y espacios en el type', 1,
    q{<script type = 'application/ld+json' >{"@type":"BreadcrumbList"}</script><main><h1>x</h1></main>});
# el caso real de climentmedia: la palabra en un ejemplo ESCAPADO
caso_schema('mencion escapada en un ejemplo de codigo NO cuenta', 0,
    q{<main><p>Cada ficha lleva:</p><pre>&lt;script type="application/ld+json"&gt;{"@type":"BreadcrumbList", ...}&lt;/script&gt;</pre></main>});
caso_schema('la palabra en una tabla de documentacion NO cuenta', 0,
    q{<main><table><tr><td>JSON-LD TechArticle + BreadcrumbList</td></tr></table></main>});
caso_schema('otro JSON-LD que no es miga NO cuenta', 0,
    q{<script type="application/ld+json">{"@type":"FAQPage","mainEntity":[]}</script><main><h1>x</h1></main>});

print "\n== COLISION DE CACHE CON qa-master.pl · 11-ago-2026\n";
# 🔴 EL DEFECTO: los dos programas cachean con la MISMA clave -md5(url)- en el
#    MISMO directorio, y `08-qa-final.md` mandaba /tmp/cache a los dos. Pero el
#    `.meta` de qa-maestro va por \t con 5 campos y el de aqui por | con 4.
#    Leyendo el suyo, `split /\|/` devuelve UN campo: $code se queda la linea
#    entera -numifia a 200, asi que ni salta- y $eff, $nred y $ctype salen
#    undef. El grafo sale con `content_type` vacio y **`redirects` 0 en todas
#    las paginas**: diria que aqui no redirige nada. Ni un error.
#    El arreglo es VALIDAR AL LEER, y hacen falta LOS DOS casos -- si solo se
#    prueba que rechaza el ajeno, «rechazarlo todo» pasa por arreglo y la cache
#    deja de existir sin que nadie se entere.
sub caso_cache {
    my ($eti, $formato, $espera) = @_;
    my $tmp = tempdir(CLEANUP => 1);
    my $cache = "$tmp/c"; make_path($cache);
    my $out = "$tmp/g.json";
    # puerto muerto: si la semilla NO se usa, la re-descarga falla al instante
    # (connection refused) y no se toca la red. La prueba sigue siendo hermetica.
    my $u = 'http://127.0.0.1:1/';
    my $html = '<!DOCTYPE html><html lang="es"><head><title>T</title></head>'
             . '<body><main><h1>Semilla</h1></main></body></html>';
    my $k = md5_hex($u);
    open my $b, '>:raw', "$cache/$k.body" or die $!; print $b $html; close $b;
    open my $m, '>', "$cache/$k.meta" or die $!;
    print $m ($formato eq 'qam' ? "200\t118\ttext/html; charset=utf-8\t$u\t0.001"
                                : "200|$u|0|text/html; charset=utf-8");
    close $m;
    my $log = `perl "$CRAWL" "$u" "$cache" "$out" 1 2>&1`;
    if (!-f $out) {
        printf "  MAL   %-52s el rastreador no produjo salida: %s\n", $eti, ($log // ''); $ko++; return;
    }
    my $j = JSON::PP->new->decode(do { local $/; open my $h, '<', $out or die $!; <$h> });
    # ⚠️ NO se busca por $u: `crawl-links.pl` guarda la pagina bajo su URL
    #    NORMALIZADA (canoniza el esquema a https) y solo usa la original para
    #    descargar, via %orig. Buscar la clave literal daba -1 con el arreglo
    #    funcionando -- el fallo era de la prueba. Con maxpages=1 hay UNA.
    my @k = sort keys %{ $j->{pages} };
    if (@k != 1) {
        printf "  MAL   %-52s esperaba 1 pagina y hay %d (%s)\n", $eti, scalar(@k), join(', ', @k);
        $ko++; return;
    }
    my $rec = $j->{pages}{ $k[0] };
    my $real = $rec ? ($rec->{status} + 0) : -1;
    if ($real == $espera) { printf "  OK    %-52s status=%d\n", $eti, $real; $ok++ }
    else { printf "  MAL   %-52s esperaba status=%d y salio %d\n", $eti, $espera, $real; $ko++ }
}
# AJENO -> MISS -> re-descarga contra un puerto muerto -> 0. Antes salia 200
# con el cuerpo de la semilla, que es la mentira que se venia a matar.
caso_cache('meta AJENO (\t de qa-maestro) NO vale como HIT', 'qam',   0);
# PROPIO -> HIT. Este es el que impide «arreglarlo» rechazandolo todo.
caso_cache('meta PROPIO (| de crawl) SIGUE valiendo',        'crawl', 200);

# =============================================================================
print "\n== R5 EN UN SITIO PLANO · 13-ago-2026\n";
# 🔴 EL DEFECTO: R5 deducia el padre de cada pagina QUITANDO el ultimo tramo de
#    su ruta. En un sitio PLANO -todas las URLs a un nivel, que es como estan
#    site-c y site-d- el padre de las 28 sale "/", y la regla acaba exigiendo
#    que la PORTADA enlace a las 28: a las 11 entradas del blog y al aviso legal
#    incluidos. Eso choca de frente con R10 (menu acotado, <=15 enlaces) y
#    convierte la home en un mapa del sitio. La aritmetica de rutas no dice
#    quien cuelga de quien cuando la ruta no tiene jerarquia; quien lo cubre
#    ahi es R3 (cada pagina necesita un entrante de contenido) y R4 (huerfanas).
#
#    Lo que R5 SI tiene que seguir cazando -y por eso dos de estos cuatro casos
#    esperan FALLA- es la seccion incompleta: un /servicios que no enlaza a uno
#    de sus hijos, y una portada que no enlaza a una seccion. Si al relajar la
#    regla esos dos se pusieran verdes, el arreglo seria un apano para que mi
#    sitio pase, que es exactamente lo que no puede ser.
#
#    ⚠️ Estos casos NO tocan el rastreador: alimentan al gate con un grafo ya
#       hecho. Es la primera prueba que tiene linking-gate.pl.
my $GATE = "$DIR/../linking-gate.pl";
die "no encuentro $GATE\n" unless -f $GATE;

# $rutas: [ [ruta, [rutas destino...]], ... ]. La primera tiene que ser '/'.
sub caso_r5 {
    my ($eti, $espera, $rutas) = @_;
    my $tmp = tempdir(CLEANUP => 1);
    my $f   = "$tmp/g.json";
    my (%pages, %inb);
    my $url = sub { my $r = shift; return "https://$HOST" . ($r eq '/' ? '/' : $r); };
    for my $par (@$rutas) {
        my ($r, $dst) = @$par;
        my @t = map { $url->($_) } @$dst;
        $inb{$_}++ for @t;
        $pages{ $url->($r) } = {
            status => 200, depth => ($r eq '/' ? 0 : 1),
            out_targets => [ sort @t ],
            out_internal_unique => scalar @t,
            out_chrome => 2, out_body => scalar @t,
            # la miga y las anclas no son lo que se mide aqui; se dan en verde
            # para que el informe no salga lleno de ruido de otras reglas.
            has_breadcrumb_visible => JSON::PP::true,
            has_breadcrumb_schema  => JSON::PP::false,
            inbound => [],
        };
    }
    for my $u (keys %pages) {
        $pages{$u}{in_unique} = $inb{$u} // 0;
        $pages{$u}{in_body}   = $inb{$u} // 0;
    }
    open my $h, '>', $f or die $!;
    print $h JSON::PP->new->encode({ site => $HOST, start => $url->('/'),
                                     sitemap => [ sort keys %pages ], pages => \%pages });
    close $h;

    my $log = `perl "$GATE" "$f" 2>&1`;
    my ($linea) = $log =~ /^(PASA|FALLA|AVISO|NOVERIF)\s+R5\b.*$/m;
    my $real = $linea // 'SIN LINEA R5';
    if ($real eq $espera) { printf "  OK    %-52s R5=%s\n", $eti, $real; $ok++ }
    else { printf "  MAL   %-52s esperaba R5=%s y salio %s\n", $eti, $espera, $real; $ko++ }
}

# --- los dos que NO se pueden acusar: no hay jerarquia que incumplir
caso_r5('plano: la home no enlaza a todas las paginas', 'PASA',
        [ ['/',        ['/servicio-a', '/blog']],
          ['/servicio-a', ['/']],
          ['/blog',     ['/post-uno', '/post-dos']],
          ['/post-uno', ['/blog']],
          ['/post-dos', ['/blog']],
          ['/aviso-legal', ['/']] ]);
caso_r5('plano: la home no enlaza NI a una sola hermana', 'PASA',
        [ ['/',        ['/contacto']],
          ['/uno',     ['/']], ['/dos', ['/']], ['/tres', ['/']],
          ['/contacto', ['/']] ]);

# --- los dos que SIGUEN siendo defecto de verdad
caso_r5('jerarquico: /servicios no enlaza a un hijo', 'FALLA',
        [ ['/',                 ['/servicios']],
          ['/servicios',        ['/servicios/uno']],
          ['/servicios/uno',    ['/servicios']],
          ['/servicios/dos',    ['/servicios']] ]);
caso_r5('jerarquico: la home no enlaza a la seccion',  'FALLA',
        [ ['/',                 ['/contacto']],
          ['/contacto',         ['/']],
          ['/servicios',        ['/servicios/uno', '/servicios/dos']],
          ['/servicios/uno',    ['/servicios']],
          ['/servicios/dos',    ['/servicios']] ]);
caso_r5('jerarquico completo: nada que reprochar',     'PASA',
        [ ['/',                 ['/servicios', '/contacto']],
          ['/contacto',         ['/']],
          ['/servicios',        ['/servicios/uno', '/servicios/dos']],
          ['/servicios/uno',    ['/servicios']],
          ['/servicios/dos',    ['/servicios']] ]);

# =============================================================================
print "\n== R10 CUENTA OCURRENCIAS, NO DESTINOS · 13-ago-2026\n";
# 🔴 EL DEFECTO: `out_chrome` cuenta OCURRENCIAS de enlace. Un pie con seis
#    anclas `/services#generale`, `#massages`... suma seis y apunta a UNA
#    pagina. La condicion comparaba esas ocurrencias con el numero de PAGINAS
#    -peras con manzanas- y la frase impresa era «el menu enlaza medio sitio»,
#    que es una afirmacion sobre destinos UNICOS.
#    Medido: site-d salia FALLA con 25 ocurrencias sobre 40 paginas cuando su
#    cromo enlaza 10 destinos distintos, el 25% del sitio. Acusacion falsa.
#    NINGUN umbral se ha tocado: blando 15 ocurrencias, duro la mitad del sitio.
sub caso_r10 {
    my ($eti, $espera, $npag, $ocurr, $destinos) = @_;
    my $tmp = tempdir(CLEANUP => 1);
    my $f   = "$tmp/g.json";
    my @rutas = ('/', map { "/p$_" } 1 .. $npag - 1);
    my @dest  = map { "https://$HOST$_" } @$destinos;
    my %pages;
    for my $r (@rutas) {
        my $u = "https://$HOST" . ($r eq '/' ? '/' : $r);
        $pages{$u} = {
            status => 200, depth => ($r eq '/' ? 0 : 1),
            out_targets => [ sort @dest ],
            out_internal_unique => scalar @dest,
            out_chrome => $ocurr, out_body => 1,
            has_breadcrumb_visible => JSON::PP::true,
            has_breadcrumb_schema  => JSON::PP::false,
            in_unique => 1, in_body => 1, inbound => [],
        };
    }
    # el cromo de TODAS apunta a los mismos destinos: es lo que hace un menu
    for my $d (@dest) {
        next unless $pages{$d};
        $pages{$d}{inbound} = [ map { { from => $_, text => 'x', region => 'chrome', prose => 0 } }
                                grep { $_ ne $d } keys %pages ];
    }
    open my $h, '>', $f or die $!;
    print $h JSON::PP->new->encode({ site => $HOST, start => "https://$HOST/",
                                     sitemap => [ sort keys %pages ], pages => \%pages });
    close $h;
    my $log = `perl "$GATE" "$f" 2>&1`;
    my ($linea) = $log =~ /^(PASA|FALLA|AVISO|NOVERIF)\s+R10\b.*$/m;
    my $real = $linea // 'SIN LINEA R10';
    if ($real eq $espera) { printf "  OK    %-52s R10=%s\n", $eti, $real; $ok++ }
    else { printf "  MAL   %-52s esperaba R10=%s y salio %s\n", $eti, $espera, $real; $ko++ }
}

# el caso de site-d: muchas repeticiones, pocos destinos. NO es medio sitio.
caso_r10('25 ocurrencias a 5 destinos sobre 20 paginas', 'AVISO', 20, 25,
         [qw(/p1 /p2 /p3 /p4 /p5)]);
# el de site-a y climentmedia: el menu SI es el sitio. Tiene que seguir cayendo.
caso_r10('20 ocurrencias a 8 destinos sobre 10 paginas', 'FALLA', 10, 20,
         [qw(/p1 /p2 /p3 /p4 /p5 /p6 /p7 /p8)]);
# menu normal: por debajo del limite blando, ni se discute
caso_r10('10 ocurrencias a 8 destinos sobre 20 paginas', 'PASA',  20, 10,
         [qw(/p1 /p2 /p3 /p4 /p5 /p6 /p7 /p8)]);

# =============================================================================
#  17-ago-2026 · R7, R8 y R9 — las tres reglas del paso 9 que no tenian caso
# =============================================================================
#  `linking-gate.pl` estaba en 7 de 10. Las tres que faltaban sostienen el paso
#  9 de la revision y las tres han cazado defectos reales del parque. Se prueban
#  sobre un grafo fabricado aqui: el gate no toca la red, lee un JSON.
sub caso_regla {
    my ($eti, $regla, $espera, $pages) = @_;
    my $tmp = tempdir(CLEANUP => 1);
    my $f   = "$tmp/g.json";
    # Se rellenan los campos que el gate espera en TODAS las paginas, para que
    # las otras nueve reglas no metan ruido en la linea que se esta midiendo.
    for my $u (keys %$pages) {
        my $q = $pages->{$u};
        $q->{status}                 //= 200;
        $q->{depth}                  //= ($u =~ m{^https?://[^/]+/$} ? 0 : 1);
        # 🔴 POR DEFECTO CADA PAGINA ENLAZA A LAS DEMAS, y no es relleno: `R0`
        #    declara el INSTRUMENTO invalido si ninguna pagina tiene enlaces
        #    internos -«los pinta el JS»- y entonces **no imprime ninguna otra
        #    regla**. Con fixtures sin enlaces, mis 8 casos salieron todos
        #    «SIN LINEA»: no es que las reglas fallaran, es que el gate se negaba
        #    a hablar. R0 hace bien; el fixture estaba mal.
        $q->{out_targets}            //= [ grep { $_ ne $u } sort keys %$pages ];
        $q->{out_internal_unique}    //= scalar @{ $q->{out_targets} };
        $q->{out_chrome}             //= 2;
        $q->{out_body}               //= scalar @{ $q->{out_targets} };
        $q->{in_unique}              //= 1;
        $q->{in_body}                //= 1;
        $q->{inbound}                //= [];
        $q->{has_breadcrumb_visible} //= JSON::PP::true;
        $q->{has_breadcrumb_schema}  //= JSON::PP::false;
    }
    open my $h, '>', $f or die $!;
    print $h JSON::PP->new->encode({ site => $HOST, start => "https://$HOST/",
                                     sitemap => [ sort keys %$pages ], pages => $pages });
    close $h;
    my $log = `perl "$GATE" "$f" 2>&1`;
    my ($linea) = $log =~ /^(PASA|FALLA|AVISO|NOVERIF)\s+\Q$regla\E\b/m;
    my $real = $linea // "SIN LINEA $regla";
    if ($real eq $espera) { printf "  OK    %-52s %s=%s\n", $eti, $regla, $real; $ok++ }
    else { printf "  MAL   %-52s esperaba %s=%s y salio %s\n", $eti, $regla, $espera, $real; $ko++;
           print "        ", join("\n        ", grep { /\Q$regla\E/ } split /\n/, $log), "\n" }
}

print "\n== R7 · ENLAZAR A LA CANONICA · 17-ago-2026\n";
# 🔴 EL DEFECTO REAL: climentmedia.com tenia **143 enlaces a `/index.html`** -uno
#    por pagina, el de la marca del menu- y la canonica `/` recibia CERO. El
#    `canonical` estaba bien puesto y Google consolida, asi que el dano es
#    acotado, pero el sitio entero se enlazaba a si mismo por la URL que no es.
#    Se arreglo en un punto (`href="../"`), y R7 es lo que vigila que no vuelva.
caso_regla('R7 · `/index.html` conviviendo con `/`, FALLA', 'R7', 'FALLA', {
    "https://$HOST/"           => { in_unique => 0, in_body => 0 },
    "https://$HOST/index.html" => { in_unique => 9, in_body => 9 },
});
caso_regla('R7 · solo la canonica, pasa', 'R7', 'PASA', {
    "https://$HOST/"      => { in_unique => 9, in_body => 9 },
    "https://$HOST/blog/" => { in_unique => 2, in_body => 2 },
});

print "\n== R8 · ANCLAS DESCRIPTIVAS\n";
# «leer mas» es el mismo texto para 40 destinos distintos: no le dice nada ni al
# visitante que navega con lector de pantalla ni a Google.
caso_regla('R8 · un «leer mas» ya la tumba', 'R8', 'FALLA', {
    "https://$HOST/"      => {},
    "https://$HOST/blog/" => { inbound => [ { from => "https://$HOST/", text => 'leer mas', region => 'body' } ] },
});
# El ancla VACIA se cuenta aparte: un enlace envolviendo una imagen sin alt no
# es generico, es mudo. Los dos son fallo, pero son dos hallazgos distintos.
caso_regla('R8 · y un ancla vacia tambien', 'R8', 'FALLA', {
    "https://$HOST/"      => {},
    "https://$HOST/blog/" => { inbound => [ { from => "https://$HOST/", text => '', region => 'body' } ] },
});
caso_regla('R8 · con texto que dice a donde va, pasa', 'R8', 'PASA', {
    "https://$HOST/"      => {},
    "https://$HOST/blog/" => { inbound => [ { from => "https://$HOST/", text => 'todas las entradas del blog', region => 'body' } ] },
});

print "\n== R9 · ENLACES DE CONTENIDO · los TRES tramos\n";
# 🔴 EL DEFECTO REAL: site-c.example estaba al **9%** (74 de 830). Un sitio
#    que solo se navega por el menu no reparte autoridad: la reparte plana, que
#    es lo mismo que no repartirla. Hoy esta al 25%.
#    Los tres tramos llevan caso a proposito -<10 FALLA, <20 AVISA, >=20 pasa-:
#    un umbral con un solo caso no prueba que el de al lado siga funcionando.
caso_regla('R9 · 8% de contenido, FALLA', 'R9', 'FALLA', {
    "https://$HOST/"      => { out_chrome => 23, out_body => 2 },
    "https://$HOST/blog/" => { out_chrome => 23, out_body => 2 },
});
caso_regla('R9 · 15%, AVISA (no bloquea)', 'R9', 'AVISO', {
    "https://$HOST/"      => { out_chrome => 17, out_body => 3 },
    "https://$HOST/blog/" => { out_chrome => 17, out_body => 3 },
});
caso_regla('R9 · 25%, pasa', 'R9', 'PASA', {
    "https://$HOST/"      => { out_chrome => 15, out_body => 5 },
    "https://$HOST/blog/" => { out_chrome => 15, out_body => 5 },
});

printf "\n-----------------------------------------------------------------\n";
printf "  OK %-3d  ·  MAL %d\n", $ok, $ko;
print $ko ? "  🔴 HAY FALLOS: no se despliega nada con esto en rojo.\n"
          : "  El detector caza la miga que existe y no se inventa ninguna.\n";
exit($ko ? 1 : 0);
