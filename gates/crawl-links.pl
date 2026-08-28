#!/usr/bin/perl
# Crawler de grafo de enlaces internos. Sin dependencias externas: curl + perl core.
# Uso: perl crawl.pl <start-url> <cachedir> <outfile.json> [maxpages] [extra-seeds-file]
use strict;
use warnings;
use JSON::PP;
use Digest::MD5 qw(md5_hex);

my ($START, $CACHE, $OUT, $MAX, $SEEDFILE) = @ARGV;
$MAX ||= 400;
die "uso: crawl.pl start cachedir out.json [max] [seedfile]\n" unless $START && $CACHE && $OUT;

# 28-ago-2026 · LOS ARGUMENTOS SON POSICIONALES, Y ANTES SE CREABA UN
# DIRECTORIO CON LO QUE LLEGARA. Si un llamante pasa un FLAG donde va el
# cachedir -por ejemplo `--salida`, que SI existe como opcion en compliance.pl
# y como alias de `--out` en receipt.pl-, este script hacia `mkdir "--salida"`
# en el directorio de trabajo. Sin error y sin aviso.
#
# Lo que costo el 28-ago-2026, en una web de cliente: el directorio nacio en la
# raiz del repo, el recibo lo sello como parte del arbol, el despliegue lo subio
# a produccion -34 ficheros basura sirviendo 200- y la verificacion de md5
# reviento porque `md5sum` lee un nombre que empieza por `-` como una opcion.
# O sea que el fallo llego hasta produccion Y ADEMAS rompio el gate que tenia
# que cazarlo.
#
# Un nombre que empieza por `-` no es un directorio que nadie quiera: es
# siempre un argumento mal pasado. Se rechaza, y se dice cual.
for my $par ([$CACHE, "cachedir"], [$OUT, "out.json"]) {
  my ($v, $q) = @$par;
  die "crawl.pl: el argumento <$q> vale '$v', que empieza por '-'.\n"
     . "  Son argumentos POSICIONALES: alguien ha pasado un flag donde va $q.\n"
     . "  Uso: perl crawl.pl <start-url> <cachedir> <out.json> [max] [seeds]\n"
    if $v =~ /^-/;
}
mkdir $CACHE unless -d $CACHE;

my $UA = 'Mozilla/5.0 (compatible; ClimentLinkAudit/1.0; +https://climentmedia.com/)';

# ---------- utilidades de URL ----------
sub host_of { my $u = shift; return $u =~ m{^https?://([^/]+)} ? lc($1) : ''; }
sub strip_www { my $h = shift; $h =~ s/^www\.//; return $h; }

my $START_HOST = strip_www(host_of($START));

sub abs_url {
    my ($href, $base) = @_;
    return undef unless defined $href;
    $href =~ s/^\s+|\s+$//g;
    return undef if $href eq '';
    return undef if $href =~ /^(mailto:|tel:|javascript:|data:|sms:|#)/i;
    $href =~ s/#.*$//;                       # fuera el fragmento
    return undef if $href eq '';
    my ($bscheme, $bhost, $bpath) = $base =~ m{^(https?)://([^/]+)(/[^?]*)?};
    $bpath = '/' unless defined $bpath;
    my $u;
    if    ($href =~ m{^https?://}i) { $u = $href; }
    elsif ($href =~ m{^//})         { $u = "$bscheme:$href"; }
    elsif ($href =~ m{^/})          { $u = "$bscheme://$bhost$href"; }
    else {
        my $dir = $bpath; $dir =~ s{[^/]*$}{};
        $u = "$bscheme://$bhost$dir$href";
    }
    # colapsar ../ y ./
    my ($sch, $hst, $rest) = $u =~ m{^(https?)://([^/]+)(.*)$};
    return undef unless defined $hst;
    my ($path, $qs) = split /\?/, (defined $rest ? $rest : ''), 2;
    $path = '/' if !defined $path || $path eq '';
    my @seg; for my $s (split m{/}, $path, -1) {
        next if $s eq '.';
        if ($s eq '..') { pop @seg if @seg; next; }
        push @seg, $s;
    }
    $path = join('/', @seg); $path = '/' . $path unless $path =~ m{^/};
    $path =~ s{//+}{/}g;
    return lc($sch) . '://' . lc($hst) . $path . (defined $qs && $qs ne '' ? "?$qs" : '');
}

# Clave canonica: sin www, y SIN barra final (salvo la raiz).
# 🔴 NO se anade barra final. site-a.example sirve /services y responde 301 a
# /services/: anadirla fabricaba una redireccion por pagina y el gate cantaba 14
# "enlaces a URL que redirige" que no existian. La barra la decide el SITIO, no yo.
# Esta clave solo sirve para DEDUPLICAR; la URL que se pide es la original.
sub canon {
    my $u = shift; return undef unless $u;
    my ($sch, $hst, $rest) = $u =~ m{^(https?)://([^/]+)(.*)$};
    return $u unless defined $hst;
    $hst = strip_www($hst);
    my ($path, $qs) = split /\?/, (defined $rest ? $rest : '/'), 2;
    $path = '/' if !defined $path || $path eq '';
    $path =~ s{/+$}{} if $path ne '/';
    $path = '/' if $path eq '';
    return "https://$hst$path" . (defined $qs && $qs ne '' ? "?$qs" : '');
}

sub is_internal { my $u = shift; return 0 unless $u; return strip_www(host_of($u)) eq $START_HOST ? 1 : 0; }
sub is_asset {
    my $u = shift; my ($p) = $u =~ m{^https?://[^/]+([^?]*)};
    return ($p && $p =~ /\.(png|jpe?g|gif|svg|webp|avif|ico|css|js|mjs|pdf|zip|gz|xml|txt|json|woff2?|ttf|eot|mp4|webm|mp3|csv|md)$/i) ? 1 : 0;
}

# ---------- fetch con cache ----------
# _meta_crawl: lee un `.meta` SOLO si lo escribio ESTE programa.
#   Devuelve la linea, o undef —que significa MISS, «vuelve a descargar»—.
#   ⚠️ COLISION DE CACHE CON `qa-master.pl`, cerrada el 11-ago-2026 en los dos
#      lados. Los dos cachean con la MISMA clave —md5(url)— en el MISMO
#      directorio, y `08-qa-final.md` mandaba /tmp/cache a los dos (ahora dice
#      /tmp/cache-enlaces, pero eso es AHORRO: la garantia es esta validacion,
#      que no depende de que nadie escriba bien la ruta). Pero el meta de
#      qa-maestro va por \t con 5 campos y este por | con 4.
#      Leyendo el suyo, `split /\|/` devuelve UN campo: $code se queda la linea
#      entera (numifia a 200, asi que ni salta), y $eff, $nred y $ctype salen
#      undef. Resultado: `content_type` vacio y **`redirects` 0 para todas las
#      paginas** — el grafo diria que aqui no redirige nada. Silencioso y
#      plausible, que es la peor clase.
#   No se cambia la clave a proposito: un prefijo invalida las caches
#   pre-pobladas de los fixtures (probado en qa-maestro, tumbo su bateria).
sub _meta_crawl {
    my ($f) = @_;
    return undef unless -e $f;
    open my $m, '<', $f or return undef;
    my $x = <$m> // ''; close $m;
    return ($x =~ /^\d{3}\|/) ? $x : undef;
}
# 🔴 18-ago-2026 · LA CACHE NO CADUCABA, Y MIDIO UN SITIO COMO ERA CINCO DIAS ANTES.
#  `fetch` reutilizaba cualquier `.meta` con formato nuestro, sin mirar de cuando
#  era. Medido: un `/tmp/ce-cm` del 13-ago hizo que climentmedia.com saliera
#  **FALLA con R6, R7 y R10 rotas** -- las tres arregladas y desplegadas el 14-ago.
#  Con cache limpia: PASA CON AVISOS. Tres acusaciones falsas sobre la web
#  principal, y ninguna señal de que se estuviera leyendo el pasado.
#  Ahora caduca a las 12 h, igual que el recibo de QA y por el mismo motivo: una
#  medida vieja no es una medida, es un recuerdo. `CRAWL_CACHE_HORAS=0` fuerza
#  descarga; un numero mas alto lo alarga, pero entonces es una decision escrita.
my $CACHE_HORAS = defined $ENV{CRAWL_CACHE_HORAS} ? $ENV{CRAWL_CACHE_HORAS} : 12;
my ($N_CACHE, $N_RED, $N_VIEJA) = (0, 0, 0);

sub fetch {
    my $u = shift;
    my $k = md5_hex($u);
    my $body = "$CACHE/$k.body";
    my $meta = "$CACHE/$k.meta";
    my $vale = defined _meta_crawl($meta);
    if ($vale && $CACHE_HORAS > 0) {
        my $edad_h = (-M $meta) * 24;          # -M: dias desde que arranco el script
        if ($edad_h > $CACHE_HORAS) { $vale = 0; $N_VIEJA++ }
    } elsif ($vale && $CACHE_HORAS == 0) { $vale = 0 }
    $vale ? $N_CACHE++ : $N_RED++;
    unless ($vale) {
        # OJO: shop.site-b.example (Hostinger/mod_security) devuelve 403 si llega
        # Accept-Encoding SIN Accept. Mandamos siempre Accept.
        my @cmd = ('curl', '-sSL', '--compressed', '--max-time', '30', '-A', $UA,
                   '-H', 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                   '-H', 'Accept-Language: en;q=0.9,fr;q=0.8,pt;q=0.8,es;q=0.8',
                   '-o', $body, '-w', '%{http_code}|%{url_effective}|%{num_redirects}|%{content_type}', $u);
        my $pid = open(my $fh, '-|');
        if (!$pid) { open(STDERR, '>', File::Spec->devnull) if 0; exec @cmd; exit 1; }
        my $w = do { local $/; <$fh> }; close $fh;
        open my $m, '>', $meta or die $!; print $m (defined $w ? $w : '000||0|'); close $m;
        select(undef, undef, undef, 0.12);
    }
    # Se valida OTRA VEZ tras descargar: si sigue sin ser nuestro formato, o
    # curl no escribio o el fichero es de otro programa y no se pudo pisar.
    # Codigo 0 -> la pagina se marca rota, que es lo honesto; lo que no puede
    # pasar es entrar al parseo con una linea ajena.
    my $line = _meta_crawl($meta);
    return (0, $u, 0, '', '') unless defined $line;
    chomp $line;
    my ($code, $eff, $nred, $ctype) = split /\|/, $line, 4;
    my $html = '';
    if (-e $body) { open my $b, '<:raw', $body or die $!; $html = do { local $/; <$b> }; close $b; }
    return ($code || 0, $eff || $u, $nred || 0, $ctype || '', $html);
}

# ---------- parsing ----------
sub clean_html {
    my $h = shift;
    $h =~ s{<script\b.*?</script>}{}gsi;
    $h =~ s{<style\b.*?</style>}{}gsi;
    $h =~ s{<!--.*?-->}{}gs;
    $h =~ s{<noscript\b.*?</noscript>}{}gsi;
    return $h;
}

# separa el HTML en (chrome = header/nav/footer, main = el resto)
sub split_regions {
    my $h = shift;
    my $chrome = '';
    my $rest = $h;
    for my $tag (qw(header nav footer)) {
        while ($rest =~ s{(<$tag\b[^>]*>.*?</$tag>)}{ }si) { $chrome .= $1; }
    }
    # contenedores marcados como nav/footer/breadcrumb por clase o aria
    while ($rest =~ s{(<(div|section|aside|ul|ol)\b[^>]*(?:class|id|aria-label)="[^"]*(?:breadcrumb|site-nav|main-nav|navbar|site-footer|footer)[^"]*"[^>]*>.*?</\2>)}{ }si) { $chrome .= $1; }
    return ($chrome, $rest);
}

sub extract_links {
    my ($h, $base) = @_;
    my @out;
    while ($h =~ m{<a\b([^>]*)>(.*?)</a>}gsi) {
        my ($attrs, $inner) = ($1, $2);
        my ($href) = $attrs =~ m{\bhref\s*=\s*"([^"]*)"}i;
        ($href) = $attrs =~ m{\bhref\s*=\s*'([^']*)'}i unless defined $href;
        ($href) = $attrs =~ m{\bhref\s*=\s*([^\s>]+)}i  unless defined $href;
        next unless defined $href;
        my $rel = ($attrs =~ m{\brel\s*=\s*"([^"]*)"}i) ? lc($1) : '';
        my $txt = $inner;
        $txt =~ s{<[^>]*>}{ }gs;
        $txt =~ s{&nbsp;}{ }g; $txt =~ s{&amp;}{&}g; $txt =~ s{&#x27;|&#39;}{'}g;
        $txt =~ s{&[a-zA-Z]+;|&#x?[0-9a-fA-F]+;}{ }g;
        $txt =~ s{\s+}{ }g; $txt =~ s{^\s+|\s+$}{}g;
        if ($txt eq '') {
            my ($al) = $inner =~ m{\balt\s*=\s*"([^"]*)"}i;
            my ($ar) = $attrs =~ m{\baria-label\s*=\s*"([^"]*)"}i;
            $txt = defined $ar ? "[aria] $ar" : (defined $al ? "[img alt] $al" : '[SIN TEXTO]');
        }
        my $a = abs_url($href, $base);
        next unless defined $a;
        push @out, { href => $href, url => $a, text => $txt, rel => $rel };
    }
    return @out;
}

sub tag_text { my ($h, $t) = @_; if ($h =~ m{<$t\b[^>]*>(.*?)</$t>}si) { my $x = $1; $x =~ s{<[^>]*>}{ }gs; $x =~ s{\s+}{ }g; $x =~ s{^ | $}{}g; return $x; } return ''; }

# ---------- migas de pan ----------
# 🔴 El detector buscaba SOLO "breadcrumb" y nuestras webs no estan en ingles:
#    acusaba de "schema sin miga visible" a 42 paginas que SI la tienen (site-a 6,
#    site-d 36). Los patrones NO se inventan -- se sacaron de abrir los
#    ficheros de las 5 webs y mirar como las escriben de verdad:
#      site-a      <nav class="crumbs" aria-label="Fil d'Ariane">       (fr)
#      site-d  <nav class="crumbs wrap" aria-label="Miga de pan">   (es)
#      site-b   <div class="crumbs" style="padding-top:0">           (pt; div, sin aria-label)
#      climentmedia y site-c NO tienen miga visible. Eso es un fallo REAL
#      (cm emite BreadcrumbList en 36 paginas sin pintar la miga) y no se tapa.
#
#    "crumb" va SIN \b a proposito: con \b delante no casaria "breadcrumb"
#    (la letra previa, la 'd', tambien es de palabra). Cubre breadcrumb y crumbs.
#    "miga", "migalha" y "ariane" van CON \b para no cazar "amiga", "hormiga",
#    "enemiga" ni "mariane". "migalhas de pao" es el termino portugues: NO se ha
#    observado en las 5 (site-b usa "crumbs"), va de mas por si aparece.
my $BC_HINT = qr/(?: crumb | \bmigas?\b | \bmigalhas?\b | \bariane\b )/xi;

# 🔴 Se mira el HTML LIMPIO (sin <script>), NUNCA el crudo. Un class="crumbs"
#    dentro de un bundle JS es codigo, no una miga en pantalla: site-b
#    construye las suyas en js/shop.js y js/product.js, y darlas por visibles
#    leyendo el HTML servido seria inventarse la medida. Lo que este rastreo
#    no puede ver, no lo afirma.
#    Limite conocido y NO cubierto a proposito: una miga marcada solo por su
#    TEXTO ("Estas aqui:", "Vous etes ici") sin clase ni aria-label. No se ha
#    visto en ninguna de las 5; anadirlo sin un caso real seria inventar.
sub has_visible_breadcrumb {
    my $clean = shift;
    return 0 unless defined $clean && $clean ne '';
    while ($clean =~ m{<[a-zA-Z][a-zA-Z0-9:-]*\b([^>]*)>}g) {
        my $attrs = $1;
        next unless defined $attrs && $attrs ne '';
        # microdata sobre marcado REAL (no JSON-LD): eso si se ve en pantalla
        return 1 if $attrs =~ m{\bitemtype\s*=\s*["'][^"']*BreadcrumbList}i;
        while ($attrs =~ m{\b(?:class|id|aria-label)\s*=\s*"([^"]*)"}gi) { return 1 if $1 =~ $BC_HINT; }
        while ($attrs =~ m{\b(?:class|id|aria-label)\s*=\s*'([^']*)'}gi) { return 1 if $1 =~ $BC_HINT; }
    }
    return 0;
}

# ---------- semillas ----------
my %seed;
$seed{canon($START)} = 1;
my @sitemap_urls;
my %sitemap_raw;   # clave canonica -> URL literal del sitemap
{
    my ($c, $e, $n, $ct, $sx) = fetch("https://$START_HOST/sitemap.xml");
    if ($c == 200) {
        while ($sx =~ m{<loc>\s*([^<]+?)\s*</loc>}gi) {
            my $u = $1; $u =~ s/&amp;/&/g;
            my $k = canon($u);
            push @sitemap_urls, $k;
            $sitemap_raw{$k} //= $u;
        }
    }
}
my %in_sitemap = map { $_ => 1 } @sitemap_urls;

my @extra_seeds;
if ($SEEDFILE && -e $SEEDFILE) {
    open my $f, '<', $SEEDFILE or die $!;
    while (my $l = <$f>) { chomp $l; $l =~ s/\s+//g; next unless $l =~ m{^https?://}; push @extra_seeds, canon($l); }
    close $f;
}

# ---------- BFS ----------
my (%page, %depth, %queue_seen, @queue, %orig);
push @queue, canon($START); $depth{canon($START)} = 0; $queue_seen{canon($START)} = 1;
$orig{canon($START)} = $START;
# %orig: clave canonica -> URL TAL COMO LA ESCRIBE EL SITIO. Se pide esa, no la clave,
# para no fabricar redirecciones inventando la barra final.
for my $u (@sitemap_urls) { $orig{$u} //= ($sitemap_raw{$u} // $u); }

# las URLs del sitemap y las semillas extra se encolan a profundidad "desconocida" (99)
# SOLO despues de agotar el BFS real, para no falsear la profundidad.
my $phase = 'bfs';
my @deferred = ();
for my $u (@sitemap_urls, @extra_seeds) { next if $queue_seen{$u}; $queue_seen{$u} = 1; push @deferred, $u; }

my %edge;      # src => { dsturl => {text, region, rel} }
my $fetched = 0;

sub process {
    my ($u, $d) = @_;
    my ($code, $eff, $nred, $ctype, $html) = fetch($orig{$u} // $u);
    $fetched++;
    my $ceff = canon($eff);
    my $rec = {
        url            => $u,
        final_url      => $ceff,
        status         => $code + 0,
        redirects      => $nred + 0,
        content_type   => $ctype,
        depth          => (defined $d ? $d : undef),
        in_sitemap     => ($in_sitemap{$u} ? JSON::PP::true : JSON::PP::false),
        reached_by_crawl => ($d == 99 ? JSON::PP::false : JSON::PP::true),
    };
    if ($code != 200 || ($ctype && $ctype !~ /html/i)) {
        $page{$u} = $rec; return ();
    }
    my $clean = clean_html($html);
    my ($chrome, $main) = split_regions($clean);
    $rec->{title} = tag_text($clean, 'title');
    $rec->{h1}    = tag_text($main ne '' ? $main : $clean, 'h1');
    $rec->{bytes} = length($html);
    # el schema SI se busca en el HTML crudo: el JSON-LD vive en un <script>,
    # que es justo lo que clean_html quita.
    #
    # 🔴 13-ago-2026 · PERO SOLO DENTRO DEL <script>, no en cualquier parte del
    #    HTML. Antes bastaba con que la palabra "BreadcrumbList" apareciera en la
    #    pagina, y climentmedia.com/agents/web-audit-kit/copy/ la MENCIONA en un
    #    ejemplo de codigo escapado (`&lt;script...&gt;{"@type":"BreadcrumbList"`)
    #    dentro de una tabla que documenta que schema lleva cada tipo de pagina.
    #    Resultado: R6 la acusaba de «emite BreadcrumbList sin pintar la miga»
    #    para siempre, y no hay miga que pintar porque no emite ningun schema.
    #    Misma familia que la trampa ya escrita en 07-trampas.md: una expresion
    #    regular sobre HTML midiendo la PALABRA en vez del hecho.
    my $ld = join "\n",
        ($html =~ m{<script\b[^>]*type\s*=\s*["']application/ld\+json["'][^>]*>(.*?)</script>}gsi);
    $rec->{has_breadcrumb_schema} = ($ld =~ /BreadcrumbList/ ? JSON::PP::true : JSON::PP::false);
    $rec->{has_breadcrumb_visible} = has_visible_breadcrumb($clean) ? JSON::PP::true : JSON::PP::false;
    # 🔴 Cuantos <a href> trae el HTML SERVIDO, sin filtrar nada. Es el unico
    #    dato que distingue "esta pagina no enlaza a nada" de "esta pagina no la
    #    ha pintado nadie todavia": shop.site-b.example/loja.html son 1.574 bytes
    #    con 0 anclas porque la rejilla la monta js/shop.js. Sin este numero, el
    #    gate no puede saber si una huerfana es real o inventada por el metodo.
    my $nA = () = ($clean =~ m{<a\b[^>]*\bhref\s*=}gi);
    $rec->{a_href_total} = $nA;

    my @all;
    push @all, map { $_->{region} = 'chrome';  $_ } extract_links($chrome, $eff);
    push @all, map { $_->{region} = 'body';    $_ } extract_links($main,   $eff);

    # dentro de body: si el <a> vive dentro de un <p>, es contextual de prosa
    my %prose;
    while ($main =~ m{<p\b[^>]*>(.*?)</p>}gsi) {
        my $p = $1;
        for my $l (extract_links($p, $eff)) { $prose{$l->{url}} = 1; }
    }
    while ($main =~ m{<li\b[^>]*>(.*?)</li>}gsi) {
        my $p = $1;
        next if $p =~ m{<(article|div class="card)}i;
        for my $l (extract_links($p, $eff)) { $prose{$l->{url}} = 1 unless exists $prose{$l->{url}}; }
    }

    my (%int_out, %ext_out, @next);
    my ($n_chrome, $n_body, $n_prose) = (0,0,0);
    for my $l (@all) {
        my $t = canon($l->{url});
        next unless $t;
        if (is_internal($l->{url})) {
            next if is_asset($l->{url});
            next if $t eq $u || $t eq $ceff;         # autoenlace
            $orig{$t} //= $l->{url};                 # la forma de URL que usa el SITIO
            # "prosa" solo tiene sentido en la region body: un enlace del menu que
            # ademas aparece en un <p> NO es un enlace contextual.
            $l->{prose} = ($l->{region} eq 'body' && $prose{$l->{url}}) ? 1 : 0;
            if (!exists $int_out{$t}) {
                $int_out{$t} = { text => [], region => $l->{region}, prose => $l->{prose} };
            }
            push @{ $int_out{$t}{text} }, $l->{text};
            $int_out{$t}{prose} = 1 if $l->{prose};
            $int_out{$t}{region} = 'body' if $l->{region} eq 'body';
            $n_chrome++ if $l->{region} eq 'chrome';
            $n_body++   if $l->{region} eq 'body';
            $n_prose++  if $l->{prose};
            push @next, $t;
        } else {
            $ext_out{ $l->{url} } = ($l->{rel} || '');
        }
    }
    $edge{$u} = \%int_out;
    $rec->{out_internal_unique}  = scalar keys %int_out;
    $rec->{out_internal_total}   = $n_chrome + $n_body;
    $rec->{out_chrome}           = $n_chrome;
    $rec->{out_body}             = $n_body;
    $rec->{out_prose}            = $n_prose;
    $rec->{out_external_unique}  = scalar keys %ext_out;
    $rec->{external}             = [ sort keys %ext_out ];

    # 🔴 Firma de "el cuerpo lo monta el JS". Se calcula aqui, y no antes,
    #    porque necesita $n_body. Las dos senales salen de mirar el HTML real de
    #    shop.site-b.example/loja.html (1.574 B, 0 anclas), no de suponer:
    #      · punto de montaje: un elemento CON id y VACIO -> <div id="app-header"></div>
    #      · esqueleto de carga: class="skeleton|placeholder|shimmer|spinner"
    #    Se exigen ADEMAS <script> y que el CUERPO (fuera de nav/header/footer)
    #    no aporte NI UN enlace interno. Esa tercera condicion es la que evita
    #    el falso positivo obvio: una pagina normal con un <div id="mapa"></div>
    #    de Google Maps si enlaza desde su cuerpo, y no se marca.
    #    Para que sirve: distinguir "esta pagina no enlaza a nada" de "esta
    #    pagina no la ha pintado nadie todavia". Sin eso el gate llama huerfanas
    #    a fichas que existen y que se enlazan solas -- y un gate que acusa de
    #    60 huerfanas a una tienda que funciona se apaga en una semana.
    my $tiene_script = ($html  =~ m{<script\b}i) ? 1 : 0;
    my $montaje      = ($clean =~ m{<(\w+)\b[^>]*\bid\s*=\s*["'][^"']+["'][^>]*>\s*</\1>}i) ? 1 : 0;
    my $esqueleto    = ($clean =~ m{\bclass\s*=\s*["'][^"']*\b(?:skeleton|placeholder|shimmer|spinner)\b}i) ? 1 : 0;
    $rec->{js_shell} = ($tiene_script && ($montaje || $esqueleto) && $n_body == 0)
                       ? JSON::PP::true : JSON::PP::false;

    $page{$u} = $rec;
    return @next;
}

while (@queue || ($phase eq 'bfs' && !@queue && @deferred)) {
    if (!@queue) { $phase = 'seeds'; @queue = map { [$_, 99] } @deferred; @deferred = (); last if !@queue; }
    my $item = shift @queue;
    my ($u, $d);
    if (ref $item eq 'ARRAY') { ($u, $d) = @$item; } else { $u = $item; $d = $depth{$u}; }
    next if exists $page{$u};
    last if $fetched >= $MAX;
    my @next = process($u, $d);
    for my $n (@next) {
        next if exists $page{$n};
        if (!$queue_seen{$n} || (defined $depth{$n} && $depth{$n} == 99)) { }
        if (!$queue_seen{$n}) { $queue_seen{$n} = 1; }
        if (!defined $depth{$n} || $depth{$n} > $d + 1) { $depth{$n} = $d + 1; }
        @deferred = grep { $_ ne $n } @deferred;
        push @queue, [$n, $depth{$n}] unless grep { (ref $_ eq 'ARRAY' ? $_->[0] : $_) eq $n } @queue;
    }
}
# segunda vuelta: semillas no alcanzadas
if (@deferred) {
    for my $u (@deferred) {
        next if exists $page{$u};
        last if $fetched >= $MAX;
        process($u, 99);
    }
}

# ---------- remapear aristas a la URL FINAL ----------
my %final_of;
for my $u (keys %page) { $final_of{$u} = $page{$u}{final_url} || $u; }
my %inbound;   # dst => [ {from, text, region, prose} ]
my %redirect_links;
for my $src (keys %edge) {
    my $s = $final_of{$src} || $src;
    for my $dst (keys %{ $edge{$src} }) {
        my $f = $final_of{$dst} || $dst;
        if (exists $page{$dst} && ($page{$dst}{redirects} // 0) > 0) {
            push @{ $redirect_links{"$src -> $dst"} }, $f;
        }
        next if $f eq $s;
        push @{ $inbound{$f} }, {
            from   => $s,
            text   => join(' | ', @{ $edge{$src}{$dst}{text} }),
            region => $edge{$src}{$dst}{region},
            prose  => $edge{$src}{$dst}{prose} ? JSON::PP::true : JSON::PP::false,
        };
    }
}

# ---------- consolidar por URL final ----------
my %byfinal;
for my $u (keys %page) {
    my $f = $page{$u}{final_url} || $u;
    if (!exists $byfinal{$f}) { $byfinal{$f} = $page{$u}; }
    else {
        $byfinal{$f}{in_sitemap} = JSON::PP::true if $in_sitemap{$u};
    }
    $byfinal{$f}{in_sitemap} = ($in_sitemap{$f} || $in_sitemap{$u}) ? JSON::PP::true : $byfinal{$f}{in_sitemap};
}

for my $f (keys %byfinal) {
    my @inb = @{ $inbound{$f} || [] };
    my %uniq; my @u2;
    for my $i (@inb) { next if $uniq{ $i->{from} }++; push @u2, $i; }
    $byfinal{$f}{in_total}      = scalar @inb;
    $byfinal{$f}{in_unique}     = scalar @u2;
    $byfinal{$f}{in_body}       = scalar grep { $_->{region} eq 'body' } @u2;
    $byfinal{$f}{in_prose}      = scalar grep { $_->{prose} } @u2;
    $byfinal{$f}{inbound}       = [ map { { from => $_->{from}, text => $_->{text}, region => $_->{region}, prose => $_->{prose} } } @u2 ];
    $byfinal{$f}{out_targets}   = [ sort keys %{ $edge{$f} || {} } ];
    delete $byfinal{$f}{external} if ($byfinal{$f}{out_external_unique} // 0) == 0;
}

my $out = {
    site              => $START_HOST,
    start             => canon($START),
    crawled_at        => scalar(gmtime()) . ' UTC',
    # De donde salen los bytes que se han medido. Sin esto, una corrida sobre
    # cache vieja es indistinguible de una corrida fresca -- y ya produjo tres
    # FALLAs falsas sobre climentmedia.com (ver la cabecera de fetch).
    cache             => "descargadas $N_RED · reutilizadas $N_CACHE · caducadas $N_VIEJA"
                       . " (limite ${CACHE_HORAS}h; CRAWL_CACHE_HORAS lo cambia)",
    method            => 'curl -sSL (sigue 301) + parser perl; enlaces de <a href> tras quitar script/style/comentarios',
    pages_fetched     => $fetched,
    sitemap_count     => scalar @sitemap_urls,
    sitemap           => [ sort @sitemap_urls ],
    pages             => \%byfinal,
};
open my $o, '>', $OUT or die $!;
print $o JSON::PP->new->pretty->canonical->encode($out);
close $o;
print "OK  $START_HOST  fetched=$fetched  pages=", scalar(keys %byfinal), "  sitemap=", scalar(@sitemap_urls), "\n";
