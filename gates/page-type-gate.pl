#!/usr/bin/perl
# =============================================================================
#  page-type-gate.pl · THE MARKUP OF A PAGE, JUDGED BY ITS TYPE
# =============================================================================
#    perl page-type-gate.pl <URL|fichero.html> [--tipo T] [--sondear] [--termino X] [--json]
#    perl page-type-gate.pl --tabla                      # page-types.tsv against anatomy.tsv
#    perl page-type-gate.pl --vocab-desde <schemaorg-current-https.jsonld>
#
#  🔴 WHY IT EXISTS (5-nov-2026). `qa-master SEO-11` only asks whether a page has
#     JSON-LD, and gives green to ANY JSON-LD. The defects that cost us were all
#     inside a block that existed: an areaServed with two towns nobody covered, FAQ
#     questions in the markup that were nowhere on the page, a SearchAction on a
#     site with no search. And nothing knew that a product listing must not carry
#     its products as loose Product nodes, or that a search results page should not
#     be indexed: the rule depends on the TYPE of the page, and the type was only
#     ever used to judge its sections.
#
#  WHAT IT JUDGES, by check:
#    PT-01  every ld+json block parses
#    PT-02  every @type and every property exists in schema.org (the vocabulary
#           file, generated from schema.org's own release); pending, superseded
#           and out-of-domain are warnings
#    PT-03  what the type of page MUST carry (page-types.tsv, column obl)
#    PT-04  what must not stand on its own on that type (column prohibido)
#    PT-05  the properties without which a node says nothing (Product, Offer,
#           BreadcrumbList, ItemList, FAQPage, Article, WebSite, LocalBusiness...)
#    PT-06  the markup against the page: FAQ questions, the price, the product
#           name and the headline must be on the page that a person sees
#    PT-07  potentialAction: a real Action, a target, and the search string
#           wired right ({name} in the urlTemplate = name= in query-input)
#    PT-08  --sondear: the urlTemplate, filled in, answers a results page of this
#           site (not a 404, not the home, not another host) that is not indexed
#    PT-09  indexing by type: a checkout or a search page indexed; a product page
#           with noindex; a filter URL or a page 2 with the wrong canonical
#    PT-10  the page node is the WebPage subtype of its type (ItemPage, CollectionPage...)
#    PT-11  every reference by @id to this page ("#org") points to a node on it
#
#  WHAT IT DOES NOT JUDGE, said out loud: whether the markup HELPS (Google says AI
#  features need no special markup); whether sameAs answers 200; the sections of
#  the page (that is structure-gate and anatomy.tsv); anything rendered only by
#  JavaScript (it reads the served HTML, the same as a crawler that does not run it).
#
#  Exit: 1 if any FALLO, 3 if the page could not be read, 0 otherwise.
# =============================================================================
use strict; use warnings; use utf8;
use JSON::PP;
use File::Basename qw(dirname);
use File::Spec;
use Unicode::Normalize qw(NFD);
binmode STDOUT, ':encoding(UTF-8)';

my $DIR = dirname(File::Spec->rel2abs($0));
my %O = (tipo => undef, sondear => 0, termino => undef, json => 0, tabla => 0, vocab => undef,
         tipos => "$DIR/page-types.tsv", anat => "$DIR/anatomy.tsv", voc => "$DIR/schemaorg-vocab.tsv");
my @POS;
while (@ARGV) {
    my $a = shift @ARGV;
    if    ($a eq '--tipo' || $a eq '--type')        { $O{tipo} = shift @ARGV }
    elsif ($a eq '--sondear' || $a eq '--probe')    { $O{sondear} = 1 }
    elsif ($a eq '--termino' || $a eq '--term')     { $O{termino} = shift @ARGV }
    elsif ($a eq '--json')                          { $O{json} = 1 }
    elsif ($a eq '--tabla' || $a eq '--table')      { $O{tabla} = 1 }
    elsif ($a eq '--vocab-desde' || $a eq '--vocab-from') { $O{vocab} = shift @ARGV }
    elsif ($a eq '--tipos-tsv')                     { $O{tipos} = shift @ARGV }
    elsif ($a eq '--anatomia-tsv')                  { $O{anat} = shift @ARGV }
    elsif ($a eq '--vocab-tsv')                     { $O{voc} = shift @ARGV }
    elsif ($a =~ /^--?h(elp)?$/)                    { print uso(); exit 0 }
    elsif ($a =~ /^--/)                             { die "page-type-gate: no conozco $a\n" . uso() }
    else                                            { push @POS, $a }
}
sub uso { "uso: perl page-type-gate.pl <URL|fichero.html> [--tipo T] [--sondear] [--termino X] [--json]\n"
        . "     perl page-type-gate.pl --tabla\n     perl page-type-gate.pl --vocab-desde <schemaorg.jsonld>\n" }

sub slurp { my $f = shift; open my $h, '<:raw', $f or return undef; local $/; my $c = <$h>; close $h; $c }
sub utf8d { my $s = shift // ''; my $d = eval { my $c = $s; utf8::decode($c) ? $c : undef }; defined $d ? $d : $s }

# =============================================================================
#  THE VOCABULARY. Generated, never written by hand: --vocab-desde reads the
#  release file of schema.org and writes one line per type and per property.
# =============================================================================
if (defined $O{vocab}) {
    my $raw = slurp($O{vocab}) // die "no puedo leer $O{vocab}\n";
    my $g = JSON::PP->new->utf8->decode($raw)->{'@graph'} or die "sin \@graph: no es el fichero de schema.org\n";
    my $id = sub { my $x = shift; $x = $x->{'@id'} if ref $x eq 'HASH'; $x //= ''; $x =~ s/^schema://; $x };
    my $arr = sub { my $x = shift; return () unless defined $x; return map { $id->($_) } (ref $x eq 'ARRAY' ? @$x : ($x)) };
    my (@C, @P);
    for my $n (@$g) {
        my @t = $arr->($n->{'@type'});
        my $nombre = $id->($n->{'@id'});
        next if $nombre =~ /[:\/]/;
        my $flag = (grep { /pending/ } $arr->($n->{'schema:isPartOf'})) ? 'pending' : '';
        $flag = (grep { /attic/ } $arr->($n->{'schema:isPartOf'})) ? 'attic' : $flag;
        my @sup = $arr->($n->{'schema:supersededBy'});
        $flag = join ',', grep { $_ ne '' } $flag, (@sup ? 'superseded:' . join('/', @sup) : ());
        if (grep { $_ eq 'rdfs:Class' } @t) {
            my @s = grep { $_ !~ /[:\/]/ } $arr->($n->{'rdfs:subClassOf'});
            push @C, join("\t", 'C', $nombre, join(',', @s), $flag);
        }
        if (grep { $_ eq 'rdf:Property' } @t) {
            push @P, join("\t", 'P', $nombre, join(',', $arr->($n->{'schema:domainIncludes'})), $flag);
        }
        # Enumeration members (InStock, NewCondition...) are typed by their enumeration.
        my @enum = grep { $_ !~ /^(rdfs:Class|rdf:Property)$/ && $_ !~ /[:\/]/ } @t;
        push @C, join("\t", 'E', $nombre, join(',', @enum), $flag) if @enum && !grep { /^rdf/ } @t;
    }
    my ($ver) = $raw =~ /"schema:schemaVersion"\s*:\s*"([^"]+)"/;
    my $out = $O{voc};
    open my $w, '>:raw', $out or die "no puedo escribir $out\n";
    print $w "# schemaorg-vocab.tsv · GENERADO por page-type-gate.pl --vocab-desde · no editar a mano\n";
    print $w "# Fuente: https://schema.org/version/latest/schemaorg-current-https.jsonld"
           . (defined $ver ? " (version $ver)" : '') . "\n";
    print $w "# Licencia del vocabulario: CC BY-SA 3.0, schema.org. C tipo supertipos marca · P propiedad dominios marca · E miembro enumeracion marca\n";
    print $w "$_\n" for sort(@C), sort(@P);
    close $w;
    printf "escrito %s: %d tipos y miembros, %d propiedades\n", $out, scalar(@C), scalar(@P);
    exit 0;
}

my (%CLASE, %PROP, %ENUM);
sub cargar_vocab {
    my $raw = slurp($O{voc});
    return 0 unless defined $raw;
    for (split /\r?\n/, $raw) {
        next if /^#/ || !/\S/;
        my ($k, $n, $l, $f) = split /\t/, $_, 4;
        $f //= ''; $l //= '';
        if    ($k eq 'C') { $CLASE{$n} = { sup => [ grep { /\S/ } split /,/, $l ], f => $f } }
        elsif ($k eq 'P') { $PROP{$n}  = { dom => [ grep { /\S/ } split /,/, $l ], f => $f } }
        elsif ($k eq 'E') { $ENUM{$n}  = { de  => [ grep { /\S/ } split /,/, $l ], f => $f } }
    }
    return scalar keys %CLASE;
}
my %SUPERS;
sub supers {   # the type and everything above it
    my $c = shift;
    return @{ $SUPERS{$c} } if $SUPERS{$c};
    my (%v, @st); @st = ($c);
    while (@st) { my $x = shift @st; next if $v{$x}++; push @st, @{ $CLASE{$x}{sup} || [] } }
    $SUPERS{$c} = [ keys %v ];
    return keys %v;
}
sub es_un { my ($t, $de) = @_; return scalar grep { $_ eq $de } supers($t) }

# =============================================================================
#  THE TABLE OF TYPES
# =============================================================================
sub cargar_tipos {
    my $raw = slurp($O{tipos}) // die "no puedo leer $O{tipos}\n";
    my (%T, %ALIAS, @orden);
    for my $l (split /\r?\n/, utf8d($raw)) {
        next if $l =~ /^\s*#/ || $l !~ /\S/;
        my @c = split /\|/, $l, 10;
        my $t = $c[0]; $t =~ s/^\s+|\s+$//g;
        die "page-types.tsv: linea sin tipo: $l\n" unless $t =~ /^[a-z0-9-]+$/;
        my $grp = sub { my $s = shift // ''; return [] if $s eq '-' || $s !~ /\S/; [ map { [ split m{/} ] } split /;/, $s ] };
        my $lst = sub { my $s = shift // ''; return [] if $s eq '-' || $s !~ /\S/; [ map { (split /:/)[0] } split ' ', $s ] };
        $T{$t} = { alias => [ split ' ', ($c[1] // '') ], anat => ($c[2] // ''), pagina => ($c[3] // 'WebPage'),
                   obl => $grp->($c[4]), rec => ($c[5] // ''), prohibido => $lst->($c[6]),
                   acciones => $lst->($c[7]), indexar => ($c[8] // 'libre'), nota => ($c[9] // '') };
        push @orden, $t;
        for my $a ($t, @{ $T{$t}{alias} }) {
            die "page-types.tsv: «$a» nombra dos tipos ($ALIAS{$a} y $t)\n" if exists $ALIAS{$a} && $ALIAS{$a} ne $t;
            $ALIAS{$a} = $t;
        }
    }
    die "page-types.tsv: 0 tipos\n" unless @orden;
    return (\%T, \%ALIAS, \@orden);
}

if ($O{tabla}) {
    my ($T, $ALIAS, $orden) = cargar_tipos();
    my $n = cargar_vocab();
    my @mal;
    my $an = slurp($O{anat}) // die "no puedo leer $O{anat}\n";
    my %anat;
    for (split /\r?\n/, $an) { next if /^\s*#/ || !/\S/; my ($t) = split /\|/; $t =~ s/\s//g; $anat{$t} = 1 }
    for my $a (sort keys %anat) {
        push @mal, "anatomy.tsv tiene «$a» y page-types.tsv no lo nombra (ni como tipo ni como alias)" unless $ALIAS->{$a};
    }
    for my $t (@$orden) {
        my $x = $T->{$t}{anat};
        push @mal, "$t apunta a la anatomia «$x», que anatomy.tsv no tiene" if $x ne '' && $x ne '-' && !$anat{$x};
        next unless $n;
        for my $tipo ($T->{$t}{pagina}, (map { @$_ } @{ $T->{$t}{obl} }), @{ $T->{$t}{prohibido} }, @{ $T->{$t}{acciones} }) {
            push @mal, "$t nombra «$tipo», que no es un tipo de schema.org" unless $CLASE{$tipo};
        }
        push @mal, "$t: su pagina «$T->{$t}{pagina}» no es un WebPage" if $CLASE{$T->{$t}{pagina}} && !es_un($T->{$t}{pagina}, 'WebPage');
        push @mal, "$t: indexar «$T->{$t}{indexar}» no es index, noindex ni libre" unless $T->{$t}{indexar} =~ /^(index|noindex|libre)$/;
    }
    push @mal, "no hay vocabulario ($O{voc}): no puedo comprobar los nombres" unless $n;
    printf "page-types.tsv · %d tipos · %d nombres · contra %d anatomias%s\n", scalar(@$orden), scalar(keys %$ALIAS), scalar(keys %anat), $n ? " y $n tipos de schema.org" : '';
    print "  MAL  $_\n" for @mal;
    print @mal ? "  FALLO " . scalar(@mal) . "\n" : "  PASA: cada anatomia tiene su fila, y cada nombre existe\n";
    exit(@mal ? 1 : 0);
}

# =============================================================================
#  THE PAGE
# =============================================================================
my $OBJ = shift @POS or die uso();
my ($HTML, $CABS, $URL, $ESTADO) = ('', '', '', 0);
sub curl {   # a normal Chrome: the Hostinger CDN answers 403 to HeadlessChrome
    my ($u) = @_;
    my $tmp = File::Spec->catfile(File::Spec->tmpdir, "ptg-$$-" . int(rand(1e6)));
    my @c = ('curl', '-s', '-L', '--max-time', '25', '-A',
             'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36',
             '-D', "$tmp.h", '-o', "$tmp.b", '-w', '%{http_code} %{url_effective}', $u);
    open my $p, '-|', @c or return (0, '', '', $u);
    my $w = do { local $/; <$p> } // ''; close $p;
    my ($st, $fin) = $w =~ /^(\d+)\s+(\S*)/;
    my $b = slurp("$tmp.b") // ''; my $h = slurp("$tmp.h") // '';
    unlink "$tmp.b", "$tmp.h";
    my @bloques = split /\r?\n\r?\n(?=HTTP\/)/, $h;   # with -L, the headers of the LAST answer
    return ($st // 0, $b, $bloques[-1] // '', $fin // $u);
}
if ($OBJ =~ m{^https?://}i) {
    my ($st, $b, $h, $fin) = curl($OBJ);
    if ($st =~ /^(429|503)$/) { sleep 8; ($st, $b, $h, $fin) = curl($OBJ) }
    ($ESTADO, $HTML, $CABS, $URL) = ($st, $b, $h, $fin);
    if (!$st) { print "NO VERIFICADO · no he podido pedir $OBJ\n"; exit 3 }
    # 🔴 5-nov-2026 · a shop answered 429 to a product page and this gate judged the
    #    18 bytes of the error as the page: «no JSON-LD, no Product». What was measured
    #    was the refusal. A page that does not answer 200 is not read, and says why.
    #    (A page declared 404 is the exception: its status is what PT-09 judges.)
    my $quiere_404 = (defined $O{tipo} && $O{tipo} eq '404');
    if ($st != 200 && !($quiere_404 && $st == 404)) {
        print "NO VERIFICADO · $OBJ responde $st" . ($st =~ /^(429|403|503)$/ ? ' (el servidor limita o bloquea la sonda: no es un defecto de la pagina)' : '') . "\n";
        exit 3;
    }
} else {
    $HTML = slurp($OBJ);
    if (!defined $HTML) { print "NO VERIFICADO · no puedo leer $OBJ\n"; exit 3 }
    $ESTADO = 200;
    ($URL) = $HTML =~ /<link\b[^>]*\brel=["']canonical["'][^>]*\bhref=["']([^"']+)["']/i;
    $URL //= '';
}
$HTML = utf8d($HTML);

my ($T, $ALIAS) = cargar_tipos();
my $NVOC = cargar_vocab();
my $TIPO_DECL;
if (defined $O{tipo}) { $TIPO_DECL = $O{tipo} }
elsif ($HTML =~ /<(?:main|body)\b[^>]*\bdata-tipo\s*=\s*["']([^"']+)["']/i) { $TIPO_DECL = $1 }
my $TIPO = defined $TIPO_DECL ? $ALIAS->{$TIPO_DECL} : undef;
my $FT = $TIPO ? $T->{$TIPO} : undef;

my @L; my ($NF, $NA, $NP, $NN) = (0, 0, 0, 0);
sub linea { my ($e, $id, $t, $d) = @_; push @L, { estado => $e, id => $id, titulo => $t, detalle => $d // '' };
            $e eq 'FALLO' ? $NF++ : $e eq 'AVISO' ? $NA++ : $e eq 'PASA' ? $NP++ : $NN++ }
sub fallo { linea('FALLO', @_) } sub aviso { linea('AVISO', @_) } sub pasa { linea('PASA', @_) } sub nv { linea('NV', @_) }

# --- the text a person sees ----------------------------------------------------
my %ENT = (amp => '&', lt => '<', gt => '>', quot => '"', apos => "'", nbsp => ' ', euro => '€',
           aacute => 'á', eacute => 'é', iacute => 'í', oacute => 'ó', uacute => 'ú', ntilde => 'ñ',
           Aacute => 'Á', Eacute => 'É', Iacute => 'Í', Oacute => 'Ó', Uacute => 'Ú', Ntilde => 'Ñ',
           uuml => 'ü', egrave => 'è', agrave => 'à', ccedil => 'ç', ocirc => 'ô', ecirc => 'ê', laquo => '«', raquo => '»', rsquo => "'", lsquo => "'", ldquo => '"', rdquo => '"', hellip => '...', ndash => '-', mdash => '-');
sub ent { my $s = shift // ''; $s =~ s/&#x([0-9a-f]+);/chr(hex $1)/gie; $s =~ s/&#(\d+);/chr($1)/ge;
          $s =~ s/&([a-z]+);/exists $ENT{$1} ? $ENT{$1} : "&$1;"/gie; $s }
sub visible {
    my $h = shift;
    $h =~ s{<!--.*?-->}{ }gs;
    $h =~ s{<(script|style|template|noscript|svg)\b.*?</\1\s*>}{ }gsi;
    $h =~ s{<head\b.*?</head\s*>}{ }gsi;
    $h =~ s{<[^>]+>}{ }gs;
    return ent($h);
}
sub norm { my $s = lc(NFD(shift // '')); $s =~ s/\p{Mn}//g; $s =~ s/[^\p{L}\p{N}]+/ /g; $s =~ s/^ | $//g; $s }
my $VIS  = norm(visible($HTML));
my $VISC = visible($HTML); $VISC =~ s/\s+/ /g;
my ($H1) = $HTML =~ m{<h1\b[^>]*>(.*?)</h1\s*>}si; $H1 = norm(visible($H1 // ''));
my ($TITLE) = $HTML =~ m{<title\b[^>]*>(.*?)</title\s*>}si; $TITLE = norm(ent($TITLE // ''));
sub se_ve { my $t = norm(shift); return 1 if $t eq ''; return index(" $VIS ", " $t ") >= 0 }

# =============================================================================
#  PT-01 · THE BLOCKS PARSE
# =============================================================================
my @BLOQUES;
while ($HTML =~ m{<script\b([^>]*)>(.*?)</script\s*>}gsi) {
    my ($at, $c) = ($1, $2);
    next unless $at =~ /type\s*=\s*["']?application\/ld\+json/i;
    push @BLOQUES, $c;
}
my (@RAICES, @MALOS);
for my $i (0 .. $#BLOQUES) {
    my $c = $BLOQUES[$i]; $c =~ s/^\s*<!--|-->\s*$//g;
    my $d = eval { JSON::PP->new->relaxed(0)->decode($c) };
    if ($@ || !defined $d) { my $e = $@ || 'vacio'; $e =~ s/ at .*? line \d+.*//s; push @MALOS, 'bloque ' . ($i + 1) . ": $e" }
    else { push @RAICES, $d }
}
if (!@BLOQUES) {
    my $sin = $FT && !@{ $FT->{obl} };
    $sin ? pasa('PT-01', 'sin JSON-LD, y este tipo no pide ninguno', $TIPO)
         : aviso('PT-01', 'la pagina no lleva JSON-LD', $FT ? "el tipo $TIPO pide " . join(' + ', map { join('/', @$_) } @{ $FT->{obl} }) : 'tipo sin declarar');
} elsif (@MALOS) {
    fallo('PT-01', 'un bloque ld+json no se puede leer', join(' · ', @MALOS) . ' · un bloque roto no le dice nada a nadie, y los que lo leen lo descartan entero');
} else {
    pasa('PT-01', 'los bloques ld+json se leen', scalar(@BLOQUES) . ' bloque(s)');
}

# --- the nodes -----------------------------------------------------------------
#  Every hash with @type is a node. `suelto` = not reached through itemListElement,
#  so a Product inside the ItemList of a listing does not count as standing alone.
my (@NODOS, %POR_ID, @REFS);
sub tipos_de { my $t = shift->{'@type'}; my @t = ref $t eq 'ARRAY' ? @$t : defined $t ? ($t) : ();
               map { my $x = $_; $x =~ s{^(?:https?://schema\.org/|schema:)}{}; $x } @t }
sub recorre {
    my ($x, $ruta, $en_lista) = @_;
    if (ref $x eq 'ARRAY') { recorre($_, $ruta, $en_lista) for @$x; return }
    return unless ref $x eq 'HASH';
    my @t = tipos_de($x);
    my @claves = grep { $_ !~ /^\@/ } keys %$x;
    if (@t) {
        push @NODOS, { n => $x, t => \@t, ruta => $ruta, suelto => !$en_lista };
        $POR_ID{ $x->{'@id'} } = $x if defined $x->{'@id'} && !ref $x->{'@id'};
    } elsif (defined $x->{'@id'} && !@claves) {
        push @REFS, { id => $x->{'@id'}, ruta => $ruta };
    }
    for my $k (keys %$x) {
        next if $k =~ /^\@(?:context|type|id)$/;
        recorre($x->{$k}, ($ruta eq '' ? $k : "$ruta.$k"), $en_lista || $k eq 'itemListElement');
    }
}
recorre($_, '', 0) for @RAICES;
my %HAY; for my $n (@NODOS) { $HAY{$_}++ for @{ $n->{t} } }
sub nodos_de { my $c = shift; grep { my $n = $_; grep { $CLASE{$_} ? es_un($_, $c) : $_ eq $c } @{ $n->{t} } } @NODOS }
sub val { my ($n, $k) = @_; my $v = $n->{$k}; return $v }
sub texto { my $v = shift; return '' unless defined $v; return $v->[0] // '' if ref $v eq 'ARRAY' && !ref $v->[0];
            return $v->{'@value'} // $v->{name} // '' if ref $v eq 'HASH'; return ref $v ? '' : $v }
sub tiene { my ($n, $k) = @_; my $v = $n->{$k}; return 0 unless defined $v; return 0 if !ref $v && $v !~ /\S/;
            return 0 if ref $v eq 'ARRAY' && !@$v; return 1 }

# =============================================================================
#  PT-02 · THE NAMES EXIST
# =============================================================================
if (!@NODOS) {
    nv('PT-02', 'nombres de schema.org', 'no hay nodos que mirar') if @BLOQUES && !@MALOS;
} elsif (!$NVOC) {
    nv('PT-02', 'nombres de schema.org', "sin vocabulario ($O{voc}): generalo con --vocab-desde");
} else {
    my (@no_tipo, @no_prop, @pend, @fuera);
    my %visto;
    for my $nd (@NODOS) {
        my $n = $nd->{n};
        for my $t (@{ $nd->{t} }) {
            if ($t =~ m{[:/]}) { next }                         # another vocabulary: not ours to judge
            if (!$CLASE{$t}) { push @no_tipo, $t unless $visto{"t$t"}++; next }
            my $f = $CLASE{$t}{f};
            push @pend, "$t ($f)" if $f =~ /pending|attic|superseded/ && !$visto{"tf$t"}++;
        }
        for my $k (keys %$n) {
            next if $k =~ /^\@/ || $k =~ m{[:/]};
            my $base = $k; $base =~ s/-(input|output)$//;
            if (!$PROP{$base}) { push @no_prop, "$k (en " . join('/', @{ $nd->{t} }) . ')' unless $visto{"p$k"}++; next }
            my $f = $PROP{$base}{f};
            push @pend, "$base ($f)" if $f =~ /pending|attic|superseded/ && !$visto{"pf$base"}++;
            my @dom = @{ $PROP{$base}{dom} };
            my $ok = !@dom || grep { my $t = $_; !$CLASE{$t} || grep { es_un($t, $_) } @dom } @{ $nd->{t} };
            push @fuera, "$base en " . join('/', @{ $nd->{t} }) unless $ok || $visto{'d' . $base . join('/', @{ $nd->{t} })}++;
        }
    }
    if (@no_tipo || @no_prop) {
        fallo('PT-02', 'un tipo o una propiedad no existe en schema.org',
              join(' · ', (map { "tipo «$_»" } @no_tipo), (map { "propiedad «$_»" } @no_prop))
              . ' · una errata (mainEntiryOfPage) no da error en ninguna parte: simplemente no se lee');
    } else {
        pasa('PT-02', 'todos los tipos y propiedades existen en schema.org', scalar(@NODOS) . ' nodos');
    }
    aviso('PT-02', 'nombres pendientes o reemplazados', join(' · ', @pend) . ' · funcionan, pero no son parte estable del vocabulario') if @pend;
    aviso('PT-02', 'una propiedad fuera de su tipo', join(' · ', @fuera) . ' · schema.org lo tolera; un lector estricto la ignora') if @fuera;
}

# =============================================================================
#  PT-03 / PT-04 · WHAT THE TYPE CARRIES, AND WHAT IT MUST NOT
# =============================================================================
if (!defined $TIPO_DECL) {
    nv('PT-03', 'lo que el tipo de pagina exige', 'la pagina no declara data-tipo y no se ha pasado --tipo');
} elsif (!$TIPO) {
    fallo('PT-03', 'tipo de pagina desconocido', "«$TIPO_DECL» no esta en page-types.tsv: declarar el tipo mas cercano mide una cosa que no es");
} else {
    my @falta;
    # 🔴 5-nov-2026 · BreadcrumbList IS an ItemList in schema.org, so the crumbs alone
    #    answered «ItemList» for a listing that had none. A node that another group of
    #    the same row names by its own type does not count for this one.
    my %nombrado = map { $_ => 1 } map { @$_ } @{ $FT->{obl} };
    for my $g (@{ $FT->{obl} }) {
        my $hay = grep { my $c = $_;
                         grep { my $nd = $_; !grep { $_ ne $c && $nombrado{$_} && $CLASE{$_} && es_un($_, $c) } @{ $nd->{t} } } nodos_de($c) } @$g;
        push @falta, join('/', @$g) unless $hay;
    }
    if (!@{ $FT->{obl} }) { pasa('PT-03', "el tipo $TIPO no exige marcado", '') }
    elsif (@falta) { fallo('PT-03', "le falta lo que pide una pagina $TIPO", 'falta ' . join(' y ', @falta) . ($FT->{nota} ? " · $FT->{nota}" : '')) }
    else { pasa('PT-03', "lleva lo que pide una pagina $TIPO", join(' + ', map { join('/', @$_) } @{ $FT->{obl} })) }

    my @prohib;
    for my $c (@{ $FT->{prohibido} }) {
        my @n = grep { $_->{suelto} } nodos_de($c);
        push @prohib, "$c" . (@n > 1 ? " x" . scalar(@n) : '') if @n;
    }
    @prohib ? fallo('PT-04', "lleva lo que una pagina $TIPO no debe llevar suelto", join(', ', @prohib)
                    . ($TIPO =~ /^(plp|pcp|hub)$/ ? ' · en un listado, los productos van como elementos de la ItemList, no como Product sueltos' : ''))
            : pasa('PT-04', "nada prohibido para $TIPO", @{ $FT->{prohibido} } ? 'mirado: ' . join(' ', @{ $FT->{prohibido} }) : '');
}

# =============================================================================
#  PT-05 · THE PROPERTIES WITHOUT WHICH A NODE SAYS NOTHING
#  Required = what Google documents as required for that feature, or what our
#  standard requires (02-estandar §7). Recommended ones only warn.
# =============================================================================
my @REGLAS = (
    # tipo, exigidas (cada una puede ser a|b), avisadas, de donde
    ['Product',        ['name', 'offers|aggregateRating|review'], ['image'],                   'Google, fragmentos de producto'],
    ['Offer',          ['price|priceSpecification', 'priceCurrency|priceSpecification'], ['availability'], 'Google, fichas de comerciante'],
    ['AggregateOffer', ['lowPrice', 'priceCurrency'],            ['offerCount'],               'Google, fragmentos de producto'],
    ['BreadcrumbList', ['itemListElement'],                      [],                           'Google, migas'],
    ['ItemList',       ['itemListElement'],                      [],                           'schema.org'],
    ['FAQPage',        ['mainEntity'],                           [],                           'schema.org'],
    ['Question',       ['name', 'acceptedAnswer|suggestedAnswer'], [],                         'schema.org'],
    ['Article',        ['headline'],                             ['datePublished', 'dateModified', 'author'], '02-estandar §7: siempre con las dos fechas'],
    ['WebSite',        ['name', 'url'],                          [],                           'Google, nombre del sitio'],
    ['Organization',   ['name'],                                 ['url', 'logo'],              'Google, organizacion'],
    ['LocalBusiness',  ['name', 'address|areaServed'],           ['telephone'],                '02-estandar §7: con area de servicio, areaServed y nunca una direccion inventada'],
    ['Person',         ['name'],                                 [],                           'schema.org'],
    ['JobPosting',     ['title', 'datePosted', 'hiringOrganization', 'description'], ['validThrough'], 'Google, ofertas de empleo'],
    ['Service',        ['name|serviceType'],                     ['provider'],                 '02-estandar §7'],
);
{
    my (@mal, @avi, $mirados);
    # 🔴 5-nov-2026 · an AggregateOffer IS an Offer, and was judged by the Offer rule:
    #    «sin price» on a shop whose product carried lowPrice, which is what an
    #    AggregateOffer is for. A node answers to its MOST specific rule only.
    my %CON_REGLA = map { $_->[0] => 1 } @REGLAS;
    for my $r (@REGLAS) {
        my ($c, $obl, $rec) = @$r;
        for my $nd (nodos_de($c)) {
            next if grep { $_ ne $c && $CON_REGLA{$_} && $CLASE{$_} && es_un($_, $c) } @{ $nd->{t} };
            my $n = $nd->{n}; $mirados++;
            my $donde = join('/', @{ $nd->{t} }) . ($nd->{ruta} ne '' ? " en $nd->{ruta}" : '');
            for my $alt (@$obl) { push @mal, "$donde sin $alt" unless grep { tiene($n, $_) } split /\|/, $alt }
            for my $k (@$rec)   { push @avi, "$donde sin $k" unless tiene($n, $k) }
        }
    }
    # The lists: each element with its position, and a crumb (but the last) with its URL.
    for my $nd (nodos_de('ItemList')) {
        my $els = $nd->{n}{itemListElement}; $els = [$els] if ref $els eq 'HASH';
        next unless ref $els eq 'ARRAY';
        my $es_miga = grep { es_un($_, 'BreadcrumbList') } grep { $CLASE{$_} } @{ $nd->{t} };
        for my $i (0 .. $#$els) {
            my $e = $els->[$i]; next unless ref $e eq 'HASH';
            next unless grep { $_ eq 'ListItem' } tipos_de($e);
            push @mal, join('/', @{ $nd->{t} }) . " elemento " . ($i + 1) . " sin position" unless defined $e->{position};
            next unless $es_miga;
            my $item = $e->{item};
            my $nom = defined $e->{name} || (ref $item eq 'HASH' && defined $item->{name});
            push @mal, "BreadcrumbList elemento " . ($i + 1) . " sin name" unless $nom;
            push @mal, "BreadcrumbList elemento " . ($i + 1) . " sin item (solo el ultimo puede ir sin URL)"
                unless defined $item || $i == $#$els;
        }
    }
    if (!$mirados) { nv('PT-05', 'propiedades minimas', @NODOS ? 'ningun nodo de un tipo con reglas' : 'no hay nodos') }
    elsif (@mal)   { fallo('PT-05', 'un nodo sin lo que lo hace util', join(' · ', @mal)) }
    else           { pasa('PT-05', 'cada nodo lleva sus propiedades minimas', "$mirados nodos mirados") }
    aviso('PT-05', 'propiedades recomendadas que faltan', join(' · ', @avi)) if @avi;
}

# =============================================================================
#  PT-06 · THE MARKUP AGAINST THE PAGE
#  Only describes what is there. Each case below is one we have had.
# =============================================================================
{
    my (@mal, @avi, $mirado);
    for my $nd (nodos_de('Question')) {
        my $q = texto($nd->{n}{name}); next if $q eq ''; $mirado++;
        push @mal, "la pregunta «" . substr($q, 0, 70) . "» no esta en la pagina" unless se_ve($q);
        my $a = $nd->{n}{acceptedAnswer}; $a = $a->[0] if ref $a eq 'ARRAY';
        my $at = ref $a eq 'HASH' ? texto($a->{text}) : '';
        $at = visible($at); $at =~ s/\s+/ /g; $at =~ s/^\s+//;
        my $trozo = join ' ', (split ' ', $at)[0 .. 7];
        push @avi, "la respuesta a «" . substr($q, 0, 40) . "» no empieza igual que en la pagina" if $trozo ne '' && !se_ve($trozo);
    }
    if ($TIPO && $TIPO eq 'ficha') {
        for my $nd (grep { $_->{suelto} } nodos_de('Product')) {
            my $nom = texto($nd->{n}{name}); next if $nom eq ''; $mirado++;
            my $nn = norm($nom);
            push @avi, "el producto «$nom» no coincide con el h1" unless $H1 ne '' && (index($H1, $nn) >= 0 || index($nn, $H1) >= 0);
        }
        for my $nd (nodos_de('Offer')) {
            my $p = texto($nd->{n}{price}); next unless $p =~ /^\s*([0-9]+)(?:[.,]([0-9]+))?\s*$/; $mirado++;
            my ($ent, $dec) = ($1, $2 // '');
            my $miles = $ent; 1 while $miles =~ s/^(\d+)(\d{3})/$1.$2/;
            my $miles2 = $ent; 1 while $miles2 =~ s/^(\d+)(\d{3})/$1,$2/;
            $dec = substr("${dec}00", 0, 2) if length $dec;
            my @formas = $dec eq '' || $dec eq '00'
                ? map { (qr/(?<![\d.,])\Q$_\E(?:[.,]00)?(?![\d])/) } ($ent, $miles, $miles2)
                : map { (qr/(?<![\d.,])\Q$_\E[.,]\Q$dec\E(?!\d)/) } ($ent, $miles, $miles2);
            push @mal, "el precio $p del marcado no aparece en la pagina" unless grep { $VISC =~ $_ } @formas;
        }
    }
    for my $nd (grep { $_->{suelto} } nodos_de('Article')) {
        my $h = norm(texto($nd->{n}{headline})); next if $h eq ''; $mirado++;
        push @avi, "el headline no es el h1 ni el title" unless ($H1 ne '' && (index($H1, $h) >= 0 || index($h, $H1) >= 0))
                                                          || ($TITLE ne '' && index($TITLE, $h) >= 0);
    }
    if (!$mirado) { nv('PT-06', 'el marcado contra la pagina', 'no hay preguntas, producto, precio ni articulo que cruzar') }
    elsif (@mal)  { fallo('PT-06', 'el marcado dice algo que la pagina no ensena', join(' · ', @mal) . ' · el marcado solo describe lo que se ve') }
    else          { pasa('PT-06', 'lo marcado esta en la pagina', '') }
    aviso('PT-06', 'el marcado y la pagina no dicen lo mismo', join(' · ', @avi)) if @avi;
}

# =============================================================================
#  PT-07 · THE ACTIONS, AND THE SEARCH STRING
#  schema.org/docs/actions.html: `<prop>-input` says what a client must supply,
#  "required name=q" is its short form, and {q} in the urlTemplate is that name.
#  A template whose {search_term_string} has no `name=search_term_string` (or the
#  other way round) builds a URL with the braces still in it.
# =============================================================================
my @PLANTILLAS;   # [accion, plantilla, nombre]
{
    my (@mal, @avi, $n);
    my $HOST = ($URL =~ m{^https?://([^/:?#]+)}i)[0] // '';
    for my $nd (@NODOS) {
        my $pa = $nd->{n}{potentialAction}; next unless defined $pa;
        for my $a (ref $pa eq 'ARRAY' ? @$pa : ($pa)) {
            $n++;
            if (ref $a ne 'HASH') { push @mal, 'una potentialAction que no es un objeto'; next }
            my @t = tipos_de($a);
            my $nom = join('/', @t) || 'sin @type';
            if (!@t) { push @mal, 'una potentialAction sin @type'; next }
            if ($NVOC && !grep { $CLASE{$_} && es_un($_, 'Action') } @t) { push @mal, "$nom no es una Action de schema.org"; next }
            my $dueno = join('/', @{ $nd->{t} });
            my $permitida = $FT ? grep { my $x = $_; grep { $_ eq $x } @t } @{ $FT->{acciones} } : 0;
            push @avi, "$nom en $dueno: ningun buscador ni asistente documenta que la lea" unless $permitida || !$FT;
            push @avi, "SearchAction colgada de $dueno: va en el WebSite de la portada" if (grep { $_ eq 'SearchAction' } @t) && !grep { $CLASE{$_} ? es_un($_, 'WebSite') : $_ eq 'WebSite' } @{ $nd->{t} };
            my $tg = $a->{target};
            my @tg = ref $tg eq 'ARRAY' ? @$tg : defined $tg ? ($tg) : ();
            if (!@tg) { push @mal, "$nom sin target: no dice adonde ir"; next }
            # the names a client must fill in
            my %entrada;
            for my $k (grep { /-input$/ } keys %$a) {
                my $v = $a->{$k};
                if (!ref $v) { my ($x) = $v =~ /\bname=([^\s]+)/; $entrada{$x} = $k if defined $x; push @mal, "$nom: $k sin name= (nada que poner en la plantilla)" unless defined $x }
                elsif (ref $v eq 'HASH') { my $x = $v->{valueName}; $entrada{$x} = $k if defined $x; push @mal, "$nom: $k sin valueName" unless defined $x }
            }
            for my $t1 (@tg) {
                my $tpl = ref $t1 eq 'HASH' ? ($t1->{urlTemplate} // $t1->{url}) : $t1;
                if (!defined $tpl || ref $tpl) { push @mal, "$nom: target sin urlTemplate"; next }
                my %hueco = map { $_ => 1 } $tpl =~ /\{([^}]+)\}/g;
                if ($tpl !~ m{^https?://}i) { push @mal, "$nom: la plantilla «$tpl» no es una URL absoluta" }
                else {
                    my ($th) = $tpl =~ m!^https?://([^/:?#{]+)!i; $th //= '';
                    push @mal, "$nom: la plantilla va a otro dominio ($th)"
                        if $HOST ne '' && lc($th =~ s/^www\.//r) ne lc($HOST =~ s/^www\.//r);
                }
                for my $h (sort keys %hueco) {
                    my $limpio = $h; $limpio =~ s/^[+#.\/;?&]//;
                    push @mal, "$nom: la plantilla pide {$h} y ningun -input declara name=$limpio" unless $entrada{$limpio};
                }
                for my $e (sort keys %entrada) {
                    push @mal, "$nom: $entrada{$e} declara name=$e y la plantilla no tiene {$e}"
                        unless grep { my $x = $_; $x =~ s/^[+#.\/;?&]//; $x eq $e } keys %hueco;
                }
                push @mal, "$nom: la plantilla no tiene ningun hueco {…}: siempre pide lo mismo" if !%hueco && grep { $_ eq 'SearchAction' } @t;
                push @PLANTILLAS, [$nom, $tpl, (keys %entrada)[0]] if %hueco && (grep { $_ eq 'SearchAction' } @t);
            }
        }
    }
    if (!$n)     { pasa('PT-07', 'sin potentialAction', 'nada que comprobar') }
    elsif (@mal) { fallo('PT-07', 'una accion mal construida', join(' · ', @mal)) }
    else         { pasa('PT-07', 'las acciones estan bien construidas', "$n accion(es)") }
    aviso('PT-07', 'una accion que nadie lee', join(' · ', @avi)) if @avi;
}

# =============================================================================
#  PT-08 · --sondear: THE SEARCH STRING, FILLED IN, ANSWERS
# =============================================================================
if (!@PLANTILLAS) {
    # nothing to probe: said only when there was something to say
} elsif (!$O{sondear}) {
    nv('PT-08', 'la busqueda responde', 'hay SearchAction y no se ha pedido --sondear: que la plantilla este bien escrita no prueba que el buscador exista');
} else {
    my $term = $O{termino};
    if (!defined $term) { ($term) = grep { length($_) >= 4 } split ' ', $H1; $term //= 'test' }
    my (@mal, @avi, @sin);
    my $HOST = ($URL =~ m{^https?://([^/:?#]+)}i)[0] // '';
    for my $p (@PLANTILLAS) {
        my ($nom, $tpl, $nombre) = @$p;
        (my $u = $tpl) =~ s/\{[^}]+\}/my $x = $term; $x =~ s{([^A-Za-z0-9\-_.~])}{sprintf('%%%02X', ord $1)}ge; $x/ge;
        my ($st, $b, $h, $fin) = curl($u);
        # 🔴 5-nov-2026 · a Shopify search answered 429 to the probe: the host cutting off
        #    a client that asks fast says nothing about the search. Once more, slowly, and
        #    if it still refuses, it is NOT MEASURED, never a FALLO.
        if ($st =~ /^(429|403|503)$/) { sleep 5; ($st, $b, $h, $fin) = curl($u) }
        if ($st =~ /^(429|403|503)$/) { push @sin, "$u responde $st: el servidor no deja medir (limite o bloqueo de bots), no prueba que no haya buscador"; next }
        $b = utf8d($b);
        my ($fh) = $fin =~ m{^https?://([^/:?#]+)}i; $fh //= '';
        my ($fpath, $fq) = $fin =~ m{^https?://[^/]+(/[^?#]*)?(\?[^#]*)?}i; $fpath //= '/'; $fq //= '';
        if (!$st) { push @mal, "$u no responde" }
        elsif ($st != 200) { push @mal, "$u responde $st" }
        elsif ($HOST ne '' && ($fh =~ s/^www\.//r) ne ($HOST =~ s/^www\.//r)) { push @mal, "$u acaba en otro dominio ($fh)" }
        elsif ($fpath eq '/' && $fq eq '' && $tpl =~ /\?/) { push @mal, "$u redirige a la portada sin la busqueda: no hay buscador detras" }
        elsif (index(norm(visible($b)), norm($term)) < 0) { push @mal, "$u no ensena el termino buscado («$term»): no parece una pagina de resultados" }
        else {
            my $robots = join ' ', ($b =~ /<meta\b[^>]*\bname=["']robots["'][^>]*\bcontent=["']([^"']*)["']/gi), ($h =~ /^x-robots-tag:\s*(.*)$/gim);
            push @avi, "$u se puede indexar: una pagina de resultados debe llevar noindex (Google pide no indexar espacios infinitos)" unless $robots =~ /noindex/i;
        }
    }
    if (@mal)     { fallo('PT-08', 'la busqueda declarada no lleva a una pagina de resultados', join(' · ', @mal)) }
    elsif (@sin)  { nv('PT-08', 'la busqueda responde', join(' · ', @sin)) }
    else          { pasa('PT-08', 'la busqueda declarada responde con resultados', "termino «$term»") }
    aviso('PT-08', 'la pagina de resultados', join(' · ', @avi)) if @avi;
}

# =============================================================================
#  PT-09 · INDEXING BY TYPE
# =============================================================================
if ($FT) {
    my $robots = join ' ', ($HTML =~ /<meta\b[^>]*\bname=["']robots["'][^>]*\bcontent=["']([^"']*)["']/gi),
                           ($HTML =~ /<meta\b[^>]*\bcontent=["']([^"']*)["'][^>]*\bname=["']robots["']/gi),
                           ($CABS =~ /^x-robots-tag:\s*(.*)$/gim);
    my $noindex = $robots =~ /noindex|\bnone\b/i ? 1 : 0;
    my ($canon) = $HTML =~ /<link\b[^>]*\brel=["']canonical["'][^>]*\bhref=["']([^"']+)["']/i;
    ($canon) = $HTML =~ /<link\b[^>]*\bhref=["']([^"']+)["'][^>]*\brel=["']canonical["']/i unless defined $canon;
    my (@mal, @avi);
    my $want = $FT->{indexar};
    push @mal, "una pagina $TIPO con noindex: es una pagina que tiene que salir en Google" if $want eq 'index' && $noindex;
    push @avi, "una pagina $TIPO sin noindex: no tiene nada que posicionar y gasta rastreo" if $want eq 'noindex' && !$noindex && !($TIPO eq '404' && $ESTADO == 404);
    push @mal, "la 404 responde $ESTADO" if $TIPO eq '404' && $OBJ =~ m{^https?://} && $ESTADO != 404;
    if ($URL ne '' && $OBJ =~ m{^https?://} && $TIPO =~ /^(plp|pcp|hub)$/) {
        my ($q) = $OBJ =~ /\?([^#]*)/; $q //= '';
        my @par = grep { $_ !~ /^(utm_|gclid|fbclid|page$|paged$|p$|pg$)/i } map { (split /=/)[0] } split /&/, $q;
        my $pag = $q =~ /(?:^|&)(?:page|paged|p|pg)=(\d+)/i ? $1 : ($OBJ =~ m{/page/(\d+)/?} ? $1 : 0);
        my $canon_abs = defined $canon ? $canon : '';
        if (@par && !$noindex && $canon_abs ne '' && $canon_abs =~ /\Q$par[0]\E=/) {
            push @avi, "un filtro u orden (" . join(',', @par) . ") con canonica a si mismo y sin noindex: cada combinacion es una pagina indexable";
        }
        if ($pag > 1 && $canon_abs ne '' && $canon_abs !~ /(?:page|paged|p|pg)=\Q$pag\E|\/page\/\Q$pag\E/) {
            push @avi, "la pagina $pag del listado tiene la canonica en otra pagina ($canon_abs): Google pide que cada pagina de la serie sea su propia canonica";
        }
    }
    if (@mal) { fallo('PT-09', "la indexacion no es la de una pagina $TIPO", join(' · ', @mal)) }
    elsif ($want eq 'libre' && !@avi) { pasa('PT-09', "una pagina $TIPO decide su indexacion", $noindex ? 'noindex' : 'index') }
    else { pasa('PT-09', "indexacion de una pagina $TIPO", ($noindex ? 'noindex' : 'index') . ", como pide el tipo") unless @avi }
    aviso('PT-09', "indexacion de una pagina $TIPO", join(' · ', @avi)) if @avi;
} else {
    nv('PT-09', 'indexacion por tipo', 'sin tipo de pagina');
}

# =============================================================================
#  PT-10 · THE PAGE NODE AND ITS SUBTYPE
# =============================================================================
if ($FT && $NVOC) {
    my @pag = grep { my $n = $_; grep { $CLASE{$_} && es_un($_, 'WebPage') } @{ $n->{t} } } grep { $_->{suelto} } @NODOS;
    my $quiero = $FT->{pagina};
    if (!@pag) {
        $quiero eq 'WebPage' ? pasa('PT-10', 'nodo de pagina', "el tipo $TIPO no tiene un subtipo propio")
                             : aviso('PT-10', 'sin nodo de pagina', "recomendado: $quiero (con mainEntity hacia lo que la pagina describe)");
    } else {
        my @tt = map { @{ $_->{t} } } @pag;
        if (grep { $_ eq $quiero || ($CLASE{$_} && es_un($_, $quiero)) } @tt) { pasa('PT-10', "la pagina es $quiero", '') }
        elsif ($quiero eq 'WebPage') { pasa('PT-10', 'nodo de pagina', join('/', @tt)) }
        else { aviso('PT-10', "el nodo de pagina no es el de una pagina $TIPO", 'es ' . join('/', @tt) . ", y una pagina $TIPO es $quiero") }
    }
} elsif ($FT) { nv('PT-10', 'el subtipo de pagina', 'sin vocabulario') }

# =============================================================================
#  PT-11 · THE REFERENCES BY @id
# =============================================================================
{
    my $base = $URL; $base =~ s/#.*//;
    my @rotas;
    for my $r (@REFS) {
        my $id = $r->{id};
        my $local = $id =~ /^#/ || ($base ne '' && index($id, "$base#") == 0);
        next unless $local;
        my $abs = $id =~ /^#/ ? "$base$id" : $id;
        my $rel = $id =~ /^#/ ? $id : substr($id, length($base));
        push @rotas, "$id (en $r->{ruta})" unless $POR_ID{$id} || $POR_ID{$abs} || $POR_ID{$rel};
    }
    if (@rotas) { aviso('PT-11', 'una referencia por @id que no lleva a ningun nodo', join(' · ', @rotas) . ' · el grafo queda partido: el lector no sabe quien es el publisher') }
    elsif (@REFS) { pasa('PT-11', 'las referencias por @id llevan a un nodo', scalar(@REFS) . ' referencia(s)') }
}

# =============================================================================
#  OUT
# =============================================================================
if ($O{json}) {
    print JSON::PP->new->canonical->pretty->encode({ url => $URL || $OBJ, tipo => $TIPO, lineas => \@L,
        fallo => $NF, aviso => $NA, pasa => $NP, nv => $NN });
} else {
    print "PAGE TYPE GATE · " . ($URL || $OBJ) . " · tipo " . ($TIPO // ($TIPO_DECL ? "$TIPO_DECL (desconocido)" : 'sin declarar')) . "\n\n";
    for my $l (@L) {
        my $e = $l->{estado} eq 'NV' ? 'NO VERIFICADO' : $l->{estado};
        printf "%-6s %-6s %s%s\n", $e, $l->{id}, $l->{titulo}, $l->{detalle} ne '' ? " · $l->{detalle}" : '';
    }
    printf "\n  FALLO %d  ·  AVISO %d  ·  PASA %d  ·  NO VERIFICADO %d\n", $NF, $NA, $NP, $NN;
    print "  ⚠️ Lo que este gate NO mira: si el marcado ayuda (Google dice que la IA no pide ninguno), si sameAs responde,\n"
        . "     las secciones de la pagina (structure-gate) ni lo que solo pinta JavaScript.\n";
}
exit($NF ? 1 : 0);
