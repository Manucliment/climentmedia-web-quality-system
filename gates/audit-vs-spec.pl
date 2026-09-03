#!/usr/bin/env perl
# =============================================================================
#  audit-vs-spec.pl  ·  EL PASO 7 CUANDO NO HAY ORIGEN
# =============================================================================
#  Perl 5 puro (viene con Git Bash). Sin jq, sin node, sin python. Solo JSON::PP,
#  que ya usa qa-master.pl.
#
#  POR QUE EXISTE
#  --------------
#  El paso 7 de la skill es `audit-vs-source.sh`, y responde a UNA pregunta:
#  «¿que tenian ellos que nosotros no?». Enumera desde SU CODIGO. Por eso caza
#  categorias enteras que a nadie se le habian ocurrido.
#
#  🔴 Un cliente SIN web no tiene codigo. El tic era IMPOSIBLE de cumplir y la
#  checklist lo exigia igual, asi que el flujo greenfield entero estaba roto:
#  o se mentia, o se saltaba en silencio. La skill ya lo decia («falta su
#  equivalente contra la spec y la anatomia») y ese equivalente es este fichero.
#
#  LA PREGUNTA QUE HACE ESTE, Y POR QUE NO ES LA MISMA
#  --------------------------------------------------
#  En una MIGRACION el fallo es PERDER: 13 imagenes, 5 fichas de equipo, 9 de 11
#  eventos. El inventario de verdad es el suyo.
#  En un GREENFIELD no hay nada que perder: el fallo es INVENTAR y no decirlo, y
#  entregar con huecos. Por eso este gate mira en LAS DOS DIRECCIONES:
#    spec -> sitio   ¿esta todo lo que la spec declara, y con la anatomia de 09 §2?
#    sitio -> spec   ¿hay algo publicado que ninguna linea de la spec respalda?
#  La segunda direccion no existe en audit-vs-source.sh porque alli no hace falta.
#
#  COMO SE COMPONE CON LOS DEMAS (no se solapan, se reparten)
#  ---------------------------------------------------------
#    migracion : audit-vs-source.sh  (inventario contra SU codigo)
#              + audit-vs-spec.pl --modo migracion   (anatomia, medicion y
#                enlazado contra la spec: eso NO lo mira audit-vs-origen)
#    greenfield: audit-vs-spec.pl --modo greenfield  (todos los bloques)
#  Y despues, en los dos casos, qa-master.pl sobre el sitio PUBLICADO. Este
#  gate corre sobre el REPO y sin red: es el unico que puede hablar ANTES de
#  desplegar, que es cuando arreglar cuesta barato.
#
#  USO
#  ---
#    perl audit-vs-spec.pl --modo greenfield [--repo DIR] [--solo B[,B]] [-q]
#
#    --modo greenfield|migracion   OBLIGATORIO. Decide que bloques aplican.
#    --repo DIR                    raiz del repo (por defecto: el cwd)
#    --solo B[,B...]               intake,esqueleto,paginas,anatomia,enlazado,
#                                  medicion,formularios,imagenes,legal,inventado
#    --json FICHERO                vuelca el resultado completo
#    -q                            solo FALLO / AVISO / NO VERIFICADO
#
#  SALIDA / EXIT
#  -------------
#    VEREDICTO: PASA | FALLA     exit 0 si PASA · 1 si FALLA · 2 si NO SE PUDO
#                                CORRER (que no es lo mismo que PASA).
#
#  LAS TRES SENALES (igual que qa-maestro, y por el mismo motivo)
#    FALLO         medido, y esta mal. No se genera/despliega.
#    AVISO         medido, hay que mirarlo. No bloquea por si solo.
#    NO VERIFICADO nadie lo ha mirado. NO es un aprobado.
#
#  QUE FORMA DE _spec/ ENTIENDE
#  ---------------------------
#  Las dos que tenemos, sin tocarlas:
#    · `_spec/site.json`  con brand{} nap{} tracking{} y colecciones
#      `pages[] categories[] legal[]` (site-d) — cada entrada con `slug`.
#    · `_spec/*.jsonl`    un registro por linea con `slug` (services.jsonl: 29).
#  El TIPO de pagina no se adivina de la URL: sale de la COLECCION de la que
#  viene la entidad, que es exacto. `*.jsonl` -> servicio · categories -> hub ·
#  legal -> legal · pages -> por slug. Un campo `tipo` explicito manda sobre eso.
#  Rutas: se prueban `<slug>/index.html`, `<slug>.html` y
#  `<category>/<slug>/index.html`, porque site-a es plano y site-d por carpetas.
#  🔴 Esto NO se dedujo: se abrio `_gen.ps1:497,575` y se listo `odontologia/`.
#
#  LO QUE ESTE GATE NO PUEDE VER, DICHO
#  ------------------------------------
#  No abre un navegador: densidad, CTAs, CPL, contraste real y estados de
#  contenido son de qa-maestro con `--dom`. No toca la red: entrega, SSL y
#  repo-vs-produccion tambien. Si un bloque no se puede correr lo dice; nunca
#  se salta en silencio.
# =============================================================================

use strict;
use warnings;
use utf8;
use JSON::PP;
use File::Basename;

binmode(STDOUT, ':encoding(UTF-8)');
binmode(STDERR, ':encoding(UTF-8)');

# =============================================================================
#  0 · ARGUMENTOS
# =============================================================================
my %opt = (modo => '', repo => '.', solo => '', json => '', q => 0);
{
    my @a = @ARGV;

    # English aliases, for the flag AND for the mode value. Additive; both
    # spellings work. `greenfield` was already the same word in both.
    my %ALIAS = ('--mode' => '--modo', '--only' => '--solo',
                 'migration' => 'migracion');
    @a = map { $ALIAS{$_} // $_ } @a;

    while (@a) {
        my $x = shift @a;
        if ($x =~ /^--(modo|repo|solo|json)$/) { $opt{$1} = shift(@a) // ''; }
        elsif ($x eq '-q') { $opt{q} = 1 }
        elsif ($x =~ /^-h|^--help$/) { exec("perl -ne 'print if 1..90' \"$0\"") }
        else { die "argumento no reconocido: $x\n" }
    }
}
$opt{modo} =~ /^(greenfield|migracion)$/
    or do { print STDERR "  --modo greenfield|migracion es OBLIGATORIO.\n"
          . "  No es burocracia: en migracion el inventario de verdad es SU codigo\n"
          . "  (audit-vs-source.sh) y aqui solo se miran anatomia, medicion y\n"
          . "  enlazado. En greenfield no hay origen y se miran todos los bloques.\n";
            exit 2 };

my $ROOT = $opt{repo};
$ROOT =~ s{[\\/]+$}{};
-d $ROOT or do { print STDERR "  No existe el repo: $ROOT\n"; exit 2 };
my $SPEC = "$ROOT/_spec";
-d $SPEC or do {
    print STDERR "  No hay $SPEC. Este gate compara contra la SPEC: sin spec no\n"
               . "  hay nada contra que comparar, y eso NO es un aprobado.\n"
               . "  Si el sitio se mantiene a mano (site-b), este gate no aplica:\n"
               . "  dilo por escrito en el recibo, no lo dejes en blanco.\n";
    exit 2;
};

my %SOLO = map { $_ => 1 } grep { $_ ne '' } split /,/, $opt{solo};
sub quiere { my $b = shift; return !%SOLO || $SOLO{$b} }

# =============================================================================
#  1 · REGISTRO DE RESULTADOS
# =============================================================================
my @R;
sub add {
    my %h = @_;
    push @R, \%h;
    return if $opt{q} && $h{estado} eq 'PASA';
    my %ico = (PASA => '  ok  ', FALLO => '🔴 FALLO', AVISO => '⚠️ AVISO', NV => '?? NO VERIF');
    printf "  %-11s %-9s %s\n", $ico{$h{estado}}, $h{id}, $h{titulo};
    print  "                        dato:   $h{dato}\n"   if $h{dato};
    print  "                        umbral: $h{umbral}\n" if $h{umbral} && $h{estado} ne 'PASA';
    print  "                        hacer:  $h{hacer}\n"  if $h{hacer}  && $h{estado} ne 'PASA';
    print  "                        proc:   $h{proc}\n"   if $h{proc}   && $h{estado} ne 'PASA';
}
sub fallo { add(estado=>'FALLO', @_) }
sub aviso { add(estado=>'AVISO', @_) }
sub pasa  { add(estado=>'PASA',  @_) }
sub nv    { add(estado=>'NV',    @_) }

# =============================================================================
#  2 · LECTURA DE LA SPEC Y DEL DISCO
# =============================================================================
# 🔴 18-ago-2026 · UN COMENTARIO NO ES CONTENIDO, Y AQUI NO SE QUITABA NUNCA.
#  `qa-master.pl` quita comentarios en 20 sitios; este programa, en CERO, con 15
#  lecturas de fichero. Medido el mismo dia en que se escribio la trampa §43:
#  un `_deploy/contact.php` con la constante puesta en `RELLENAR@ejemplo.tld` y un
#  comentario que dice «cuando el cliente conteste, poner info@cliente.be` ponia
#  INT-02 en VERDE. El check que existe por el CRM muerto de site-a aprobaba una web
#  cuyo formulario no lleva a ningun sitio, y lo aprobaba por su DOCUMENTACION.
#  Saber la trampa no la evita: solo la evita un mecanismo.
#
#  ⚠️ Y no vale un `s{//.*}{}g` a lo bruto: se lleva por delante el `//` de
#  `https://`. Por eso `//` solo cuenta como comentario si empieza la linea o
#  viene tras un espacio, y NUNCA si lo precede `:`. El `#` solo a principio de
#  linea (PowerShell, Perl, sh), para no tocar los `#rrggbb` del CSS.
sub sin_com {
    my ($x, $como) = @_;
    return '' unless defined $x;
    $como = 'html' unless defined $como;
    $x =~ s/<!--.*?-->//gs;                       # HTML
    if ($como ne 'html') {
        $x =~ s{/\*.*?\*/}{}gs;                   # bloque C/CSS/JS/PHP
        $x =~ s{(^|[^:\w])//[^\n]*}{$1}gm;        # linea //, salvo tras ':'
        $x =~ s{^\s*\#[^\n]*$}{}gm;               # linea #
    }
    return $x;
}
sub slurp {
    my $f = shift;
    open my $fh, '<:encoding(UTF-8)', $f or return undef;
    local $/; my $c = <$fh>; close $fh; return $c;
}

my $site;
{
    my $raw = slurp("$SPEC/site.json");
    defined $raw or do { print STDERR "  No se pudo leer $SPEC/site.json\n"; exit 2 };
    $site = eval { JSON::PP->new->utf8(0)->decode($raw) };
    $@ and do { print STDERR "  $SPEC/site.json no es JSON valido: $@\n"; exit 2 };
}

# ── Entidades: cada una con su TIPO, que sale de su COLECCION ────────────────
# (no de la URL: inferir el tipo de la ruta es lo que hace qa-maestro cuando no
#  tiene mas remedio, y lo marca «INFERIDO». Aqui no hace falta adivinar.)
my @ENT;
sub ent { push @ENT, { @_ } }

for my $p (@{ $site->{pages} || [] }) {
    next unless ref $p eq 'HASH' && $p->{slug};
    my $t = $p->{tipo} || ($p->{slug} =~ /^(contacto|contact)$/           ? 'contacto'
                        :  $p->{slug} =~ /^(gracias|merci|thanks)$/       ? 'gracias'
                        :  $p->{slug} =~ /^(precios|tarifas|pricing)$/    ? 'precios'
                        :                                                  'servicio');
    ent(slug=>$p->{slug}, tipo=>$t, col=>'pages', rec=>$p);
}
# 🔴 13-ago-2026 · ESTE GATE SE MORIA CON UN ERROR DE PERL EN UN REPO REAL.
#    `perl audit-vs-spec.pl --modo migracion` sobre site-e-web:
#        Not an ARRAY reference at audit-vs-spec.pl line 181.
#    Causa: `@{ $site->{legal} }` daba por hecho que `legal` es una LISTA de
#    paginas. Lo es en site-d y en site-a; en site-c `legal` es un HASH de ajustes
#    -textos, banderas, «titular_necesario»-. La MISMA clave con dos
#    significados en dos specs, y ninguna esta mal: nadie escribio nunca que
#    forma tenia que tener.
#
#    Morir asi es el peor final posible: sin veredicto, sin ID y sin linea en el
#    recibo. Un gate que revienta no dice «esta mal», dice NADA, y quien lo lanza
#    se queda sin saber si su sitio pasa. Ahora la forma rara se DECLARA como no
#    medible, con su nombre, y el resto del gate sigue corriendo.
#
#    ⚠️ No se adivina. Un hash cuyas claves son slugs y cuyos valores son
#    registros SI se lee -es la misma coleccion escrita de otra forma-; cualquier
#    otra cosa se dice y no se toca. Regla 8 de 00-formula.md: una declaracion
#    elige COMO se mide, o lleva a NO VERIFICADO. Nunca a PASA.
sub coleccion {
    my ($nombre, $v) = @_;
    return () unless defined $v;
    return @$v if ref $v eq 'ARRAY';
    if (ref $v eq 'HASH') {
        my @vals = values %$v;
        my @recs = grep { ref $_ eq 'HASH' && $_->{slug} } @vals;
        my @hashes = grep { ref $_ eq 'HASH' } @vals;
        # solo si TODO el hash son registros: medio y medio no se sabe leer
        return @recs if @recs && @recs == @hashes && @hashes == @vals;
        nv(id=>'ESQ-03', titulo=>"la coleccion «$nombre» no tiene forma de lista de paginas",
           dato=>"_spec/site.json -> $nombre es un HASH de ".scalar(@vals)." valores, de los que ".scalar(@recs)." parecen paginas",
           umbral=>'una lista de registros con slug, o un hash slug => registro',
           hacer=>"si «$nombre» significa otra cosa en esta spec (ajustes, textos), esta bien: lo que NO vale es que el gate lo suponga",
           proc=>'audit-vs-spec.pl · coleccion()');
        return ();
    }
    nv(id=>'ESQ-03', titulo=>"la coleccion «$nombre» no se puede leer",
       dato=>"_spec/site.json -> $nombre es ".(ref($v) || 'un escalar'),
       umbral=>'una lista de registros con slug',
       hacer=>'mirar la spec: el gate no adivina formas', proc=>'audit-vs-spec.pl · coleccion()');
    return ();
}
for my $c (coleccion('categories', $site->{categories})) {
    next unless ref $c eq 'HASH' && $c->{slug};
    ent(slug=>$c->{slug}, tipo=>($c->{tipo} || 'hub'), col=>'categories', rec=>$c);
}
for my $l (coleccion('legal', $site->{legal})) {
    next unless ref $l eq 'HASH' && $l->{slug};
    ent(slug=>$l->{slug}, tipo=>'legal', col=>'legal', rec=>$l);
}
for my $z (coleccion('cities', $site->{cities} || $site->{zones})) {
    next unless ref $z eq 'HASH' && $z->{slug};
    ent(slug=>$z->{slug}, tipo=>'ciudad', col=>'cities', rec=>$z);
}
# jsonl: una entidad por linea. services.jsonl -> servicio; cities.jsonl -> ciudad.
for my $f (sort glob("$SPEC/*.jsonl")) {
    my $base = basename($f, '.jsonl');
    my $tipo = $base =~ /^(cities|zones|villes)$/  ? 'ciudad'
             : $base =~ /^(products|productos)$/   ? 'ficha'
             : $base =~ /^(guides|guias|learn)$/   ? 'guia'
             :                                       'servicio';
    open my $fh, '<:encoding(UTF-8)', $f or next;
    while (my $line = <$fh>) {
        next unless $line =~ /\S/;
        my $r = eval { JSON::PP->new->utf8(0)->decode($line) };
        next unless $r && ref $r eq 'HASH' && $r->{slug};
        ent(slug=>$r->{slug}, tipo=>($r->{tipo} || $tipo), col=>$base, rec=>$r);
    }
    close $fh;
}
ent(slug=>'', tipo=>'home', col=>'home', rec=>($site->{home} || {})) if $site->{home};

# ── Resolucion de ruta: se PRUEBAN las convenciones que usamos de verdad ─────
sub ruta_de {
    my $e = shift;
    # 14-ago-2026 · TAMBIEN POR SLUG. En site-c.example la portada viene de
    # WordPress con `tipo: "page"` y `slug: "home"`, asi que este gate buscaba
    # `home/index.html`, no lo encontraba, y acusaba a la portada de no existir.
    return ('index.html') if $e->{tipo} eq 'home' || ($e->{slug} // '') eq 'home';
    my $s = $e->{slug};
    my $cat = $e->{rec}{category} // '';
    my @cand = ("$s/index.html", "$s.html");
    unshift @cand, "$cat/$s/index.html", "$cat/$s.html" if $cat ne '';
    return @cand;
}
sub html_de {
    my $e = shift;
    for my $c (ruta_de($e)) { return ($c, scalar slurp("$ROOT/$c")) if -f "$ROOT/$c" }
    return (undef, undef);
}

# Todo el HTML del repo (para la direccion sitio -> spec)
my @HTML;
{
    my @dirs = ($ROOT);
    my %skip = map { $_ => 1 } qw(_spec _migrate _deploy _seo _dev _design .git
                                  node_modules assets _cowork _post-images .claude);
    while (my $d = shift @dirs) {
        opendir(my $dh, $d) or next;
        for my $n (readdir $dh) {
            next if $n eq '.' || $n eq '..' || $skip{$n};
            my $p = "$d/$n";
            if    (-d $p)             { push @dirs, $p }
            elsif ($n =~ /\.html$/i)  { my $r = $p; $r =~ s{^\Q$ROOT\E/}{}; push @HTML, $r }
        }
        closedir $dh;
    }
    @HTML = sort @HTML;
}

# =============================================================================
#  3 · ANATOMIA · 09-tipos-de-pagina.md §2, SOLO los roles OBL
# =============================================================================
#  🔴 Misma tabla que qa-master.pl:1376. Esta duplicada A PROPOSITO y con este
#  aviso: si 09 §2 cambia, se cambian LAS DOS. La alternativa —un tercer fichero
#  de tabla que los dos importen— es el documento 17 que venimos a no escribir.
#  🔴 18-ago-2026 · LA TABLA YA NO SE ESCRIBE AQUI, Y NO SE VUELVE A ESCRIBIR.
#  Estaba escrita TRES veces —qa-master.pl, audit-vs-spec.pl y
#  structure-gate.js— y una de ellas llevaba el aviso «duplicada A PROPOSITO:
#  si 09 §2 cambia, se cambian LAS DOS». Cuando se midieron, SIETE de los doce
#  tipos discrepaban, y las dos que se prometian gemelas eran justo las que se
#  habian ido del documento: a `ficha` le faltaban tres roles, a `hub` le
#  faltaba `calificacion` —la seccion que lo distingue de un menu—, y `guia`,
#  `comparativa`, `precios`, `contacto` y `gracias` iban cada una por su lado.
#  Fuente unica: anatomy.tsv, al lado de este script. Guarda: anatomy.pl --gate.
sub anatomia_cargar {
    my $quiero = shift; $quiero = 'roles' unless defined $quiero;
    my ($midir) = $0 =~ m{^(.*)[\/][^\/]+$}; $midir = '.' unless defined $midir;
    my $f = "$midir/anatomy.tsv";
    open my $fh, '<', $f or die
        "no encuentro anatomy.tsv junto al script ($f).\n"
      . "  La tabla de anatomias tiene UNA fuente y es ese fichero. Sin el, este\n"
      . "  gate no puede comprobar la anatomia — y una comprobacion que no se hace\n"
      . "  no se aprueba. Antes habia una copia a mano aqui: por eso se fue del\n"
      . "  documento sin que nadie lo viera.\n";
    my %t;
    while (my $l = <$fh>) {
        chomp $l; $l =~ s/\r$//;
        next if $l =~ /^\s*#/ || $l !~ /\S/;
        my ($tipo, $roles, $cond) = split /\|/, $l;
        next unless defined $tipo && $tipo =~ /^[a-z0-9]+$/;
        my $col = $quiero eq 'cond' ? $cond : $roles;
        $t{$tipo} = [ grep { /\S/ } split ' ', (defined $col ? $col : '') ];
    }
    close $fh;
    die "anatomy.tsv sin tipos: un gate sobre una tabla vacia aprueba cualquier cosa\n"
        unless scalar(keys %t) >= 10;
    return %t;
}
my %ANATOMIA = anatomia_cargar();

# =============================================================================
#  BLOQUE 1 · INTAKE — los campos que 00-intake.md §A declara BLOQUEANTES
# =============================================================================
#  Solo en greenfield: con web, estos datos salen de su codigo y el gate del
#  inventario es audit-vs-source.sh.
sub bloque_intake {
    my @falta;
    my $chk = sub {
        my ($etiqueta, @rutas) = @_;
        for my $r (@rutas) {
            my $v = $site; $v = ref $v eq 'HASH' ? $v->{$_} : undef for split /\./, $r;
            return 1 if defined $v && !ref $v && $v =~ /\S/ && $v !~ /^(TODO|XXX|PENDIENTE|placeholder)/i;
            return 1 if ref $v eq 'ARRAY' && @$v;
        }
        push @falta, "$etiqueta (buscado en: " . join(' | ', @rutas) . ")";
        return 0;
    };
    $chk->('nombre comercial',  'brand.name');
    $chk->('nombre legal',      'brand.legalName', 'brand.name');
    $chk->('telefono',          'nap.telephone', 'nap.mobile');
    $chk->('email',             'nap.email');
    $chk->('horario',           'nap.hoursDisplay', 'nap.hours');
    $chk->('direccion o «no la publicamos»', 'nap.streetAddress', 'nap.noAddress');
    $chk->('zonas que atiende', 'nap.areaServed');

    @falta ? fallo(id=>'INT-01', titulo=>'faltan datos BLOQUEANTES del intake',
                   dato=>join(' · ', @falta), umbral=>'los 8 del bloque A de 00-intake.md',
                   proc=>'00-intake.md §A',
                   hacer=>'estos proyectos no mueren en el diseno: mueren a mitad porque falta el horario o quien aprueba. Se piden ANTES de generar, en formato movil')
          : pasa(id=>'INT-01', titulo=>'datos bloqueantes del intake presentes');

    # Donde llegan los leads · 00-intake §A: se pregunta AUNQUE haya web
    my $rec = $site->{form}{to} // $site->{contact}{to} // $site->{nap}{leadsTo} // '';
    my $php = sin_com(slurp("$ROOT/_deploy/contact.php"), 'php');
    # ⚠️ Se busca una DIRECCION, no un `@`: en PHP `@` es el supresor de errores
    # (`@mail(...)`) y cualquier receptor lo daria por bueno sin tener buzon.
    #
    # 🔴 18-ago-2026 · Y NO VALE CUALQUIER DIRECCION. Este check existe por Site A a
    # Domicile —meses enviando a un CRM dado de baja— y venia VERDE DE FABRICA:
    # references/form-handler.php, que es el fichero que se copia a
    # _deploy/contact.php, traia escrito `contact@ejemplo.tld`. Copiar la
    # plantilla y no tocarla ponia en verde justo la comprobacion que existe
    # para que eso no pase. Un placeholder es la AUSENCIA de un buzon, no un buzon.
    my $FALSAS = qr/\b(?:ejemplo|example|exemple|dominio|domain|tudominio|sin-configurar|cambiar|rellenar|placeholder)\b|\.(?:tld|invalid|example|test|local)\b/i;
    my @dirs = ($rec =~ /\S/) ? ($rec) : ();
    push @dirs, ($php =~ /([\w.+-]+\@[\w-]+\.[\w.]+)/g);
    my @reales = grep { $_ !~ $FALSAS } @dirs;
    if (@reales) {
        pasa(id=>'INT-02', titulo=>'destino de los leads declarado', dato=>$reales[0]);
    } elsif (@dirs) {
        fallo(id=>'INT-02', titulo=>'el destino de los leads es el de la PLANTILLA, sin tocar',
              dato=>join(' · ', @dirs),
              umbral=>'un buzon real, y que sea uno que LEAN',
              proc=>'00-intake.md §A + §C · references/form-handler.php',
              hacer=>'form-handler.php se COPIA. Si sale de aqui con el valor de ejemplo, el formulario contesta 200 y el correo no llega a nadie — que es el defecto que este check viene a cerrar');
    } else {
        fallo(id=>'INT-02', titulo=>'no consta a donde llegan los leads',
              umbral=>'un buzon real, y que sea uno que LEAN',
              proc=>'00-intake.md §A + §C',
              hacer=>'en Site A a Domicile su formulario llevaba meses enviando a un CRM dado de baja. Un formulario que falla dando 200 no avisa a nadie');
    }

    # Quien aprueba, con nombre
    my $ap = $site->{approver} // $site->{_approver} // $site->{brand}{approver} // '';
    $ap =~ /\S/ ? pasa(id=>'INT-03', titulo=>'quien aprueba, con nombre', dato=>$ap)
                : aviso(id=>'INT-03', titulo=>'no consta quien aprueba, con nombre',
                        umbral=>'`approver` en site.json', proc=>'00-intake.md §A',
                        hacer=>'«el cliente» no aprueba nada. Sin nombre, la primera revision se queda sin destinatario');
}

# =============================================================================
#  BLOQUE 2 · ESQUELETO — los defectos CONOCIDOS del que se clona
# =============================================================================
#  🔴 El esqueleto por defecto es site-d-web porque gana en SEO y estructura
#  (40/40 paginas con <section>), que son las dos cosas que NO se retrofitan
#  barato. Pero se clona su GENERADOR y su SPEC, **no su estado**: su conversion
#  esta muerta, no tiene 404 y el 93% de su peso son etiquetas. Este bloque
#  existe para que esos tres defectos no viajen con la copia.
sub bloque_esqueleto {
    -f "$ROOT/404.html" || -f "$ROOT/404/index.html"
        ? pasa(id=>'ESQ-01', titulo=>'existe pagina 404')
        : fallo(id=>'ESQ-01', titulo=>'no hay pagina 404',
                umbral=>'404.html con 3-5 enlaces a los destinos mas pedidos',
                proc=>'09 §2.11 la especifica · 08-qa-final no la mencionaba NUNCA',
                hacer=>'site-d es el UNICO de los 5 repos sin 404.html: produccion devuelve el 404 de Apache, 796 bytes y CERO enlaces, en una web de 40 paginas que paga clics. Si has clonado site-d, has clonado este agujero');

    # Favicon: el caso que ensena por que un check puede ser peor que ninguno
    my @fav = grep { -f } map { "$ROOT/$_" } qw(favicon.ico favicon.png favicon.svg);
    if (@fav) {
        my ($peor) = sort { -s $b <=> -s $a } @fav;
        my $kb = int((-s $peor)/1024);
        $kb > 50 ? fallo(id=>'ESQ-02', titulo=>'favicon desproporcionado',
                         dato=>basename($peor)." = $kb KB", umbral=>'<= 50 KB',
                         proc=>'13-rendimiento §0',
                         hacer=>'el de site-a son 320 KB servidos en 13 paginas. Se sirve en TODAS: es el byte que mas veces viaja de la web')
                 : pasa(id=>'ESQ-02', titulo=>'peso del favicon', dato=>"$kb KB");
    } else {
        aviso(id=>'ESQ-02', titulo=>'no hay favicon', proc=>'audit-vs-origen §7',
              hacer=>'sin favicon la pestana y el resultado de busqueda salen genericos');
    }

    # Paleta heredada: el token, no las 136 paginas
    my $css = slurp("$ROOT/styles.css") // '';
    if ($css =~ /--primary\s*:\s*oklch\(\s*([0-9.]+)/) {
        my $L = $1;
        # ⚠️ Esto es un PROXY sobre el token, NO una medicion de contraste. El
        # contraste real se mide con getComputedStyle sobre el pixel pintado
        # (14 §3.1) y lo hace qa-maestro --solo a11y. Aqui solo se caza la franja
        # de luminosidad que ya sabemos que suspende, para que no viaje en la copia.
        $L < 0.55 || $L > 0.62
            ? pasa(id=>'ESQ-03', titulo=>'--primary fuera de la franja que suspende AA',
                   dato=>"L=$L · PROXY sobre el token: el contraste real lo mide qa-maestro --solo a11y")
            : fallo(id=>'ESQ-03', titulo=>'--primary en la franja de luminosidad que suspende AA',
                    dato=>"L=$L", umbral=>'contraste >= 4,5:1 sobre blanco, MEDIDO',
                    proc=>'14-accesibilidad §2 · el barrido de luminosidad',
                    hacer=>'un TOKEN, dos webs de cliente: 98 suspensos en site-a y 38 en bc, incluido el boton primario de las dos. El barrido que lo resuelve vive en un COMENTARIO del CSS de site-d y nunca salio de ahi. NO se mide leyendo una captura');
    } else {
        nv(id=>'ESQ-03', titulo=>'contraste de la paleta',
           umbral=>'>= 4,5:1 medido con getComputedStyle',
           proc=>'14-accesibilidad §2',
           hacer=>'no se encontro --primary en oklch() en styles.css: se mide con qa-maestro --solo a11y --repo DIR, no se da por bueno');
    }
}

# =============================================================================
#  BLOQUE 3 · PAGINAS — cada entidad de la spec tiene su fichero
# =============================================================================
# 🔴 14-ago-2026 · LO QUE LA SPEC RETIRA A PROPOSITO NO ES UNA PAGINA QUE FALTA.
#
# En site-c.example este gate acusaba de «no existen en disco» a
# /tienda, /carrito, /finalizar-compra y /mi-cuenta -- que son el WooCommerce
# VACIO que el cliente decidio retirar, declarado en `urls.se_retiran` CON su
# motivo -- y a /x, una entrada de prueba de 10 palabras. Cinco de seis
# acusaciones eran una decision tomada, escrita y firmada.
#
# Un gate que da por defecto lo que la spec declara como retirado ensena dos
# cosas malas a la vez: a ignorar sus fallos, y a borrar la declaracion para
# callarlo. Se lee la declaracion. Y se DICE cuantas se saltaron: un hueco
# declarado sigue siendo un hueco, pero es un hueco con dueno.
sub retiradas {
    my $u = $site->{urls} or return ();
    my $r = $u->{se_retiran} or return ();
    my @slugs;
    if    (ref $r eq 'HASH')  { @slugs = keys %$r }
    elsif (ref $r eq 'ARRAY') { @slugs = @$r }
    else                      { return () }
    my %s;
    for my $x (@slugs) {
        next unless defined $x && !ref $x;
        (my $t = $x) =~ s{^/|/$}{}g;    # "/tienda" y "tienda" son la misma
        $s{$t} = 1 if length $t;
    }
    return %s;
}

sub bloque_paginas {
    my (@falta, %vista);
    my %RETIRADA = retiradas();
    my $saltadas = 0;
    for my $e (@ENT) {
        my ($ruta) = html_de($e);
        if ($ruta) { $vista{$ruta} = 1; next }
        if ($RETIRADA{ $e->{slug} // '' }) { $saltadas++; next }
        push @falta, "$e->{col}/$e->{slug} (probado: " . join(' ', ruta_de($e)) . ")";
    }
    $saltadas and aviso(id=>'PAG-01b', titulo=>'entidades que la spec retira a proposito',
                        dato=>"$saltadas de ".scalar(@ENT)." · declaradas en urls.se_retiran",
                        umbral=>'cada retirada, con su motivo escrito en la spec',
                        proc=>'audit-vs-spec.pl · retiradas()',
                        hacer=>'no es un fallo: es una decision. Se dice para que se vea que se salto, no para que se arregle');
    @falta ? fallo(id=>'PAG-01', titulo=>'la spec declara paginas que no existen en disco',
                   dato=>join(' · ', @falta[0..($#falta > 9 ? 9 : $#falta)])
                        . (@falta > 10 ? " · (+".(@falta-10)." mas)" : ''),
                   umbral=>'una pagina por entidad de la spec', proc=>'audit-vs-origen §1, contra la spec',
                   hacer=>'o falta generar, o la spec declara algo que no se quiere: las dos cosas se arreglan ahora, no despues de publicar')
          : pasa(id=>'PAG-01', titulo=>'todas las entidades de la spec tienen pagina', dato=>scalar(@ENT).' entidades');

    for my $f (qw(robots.txt sitemap.xml llms.txt)) {
        -f "$ROOT/$f" ? pasa(id=>'PAG-02', titulo=>"existe $f")
                      : fallo(id=>'PAG-02', titulo=>"falta $f", proc=>'audit-vs-origen §7',
                              hacer=>'salen del MISMO bucle que las paginas (SKILL.md paso 3): si falta uno, el bucle no los emite y faltara siempre');
    }

    # sitemap contra disco: una URL en el sitemap que no existe es un 404 firmado
    my $sm = slurp("$ROOT/sitemap.xml");
    if (defined $sm) {
        my @loc = $sm =~ m{<loc>\s*([^<]+?)\s*</loc>}gi;
        # ⚠️ FALSO POSITIVO YA PAGADO (10-ago-2026, midiendo este mismo gate):
        # site-d publica URLs SIN extension y SIN barra final
        # (`/odontologia`), y `odontologia/index.html` existe. La primera version
        # probaba solo `<ruta>` y `<ruta>.html`, daba por rotas las 38 URLs del
        # sitemap y era mentira. Se prueban LAS TRES convenciones.
        my @rotas;
        for my $u (@loc) {
            my $p = $u; $p =~ s{^https?://[^/]+}{}; $p =~ s{[?#].*$}{}; $p =~ s{^/}{};
            my @cand = $p eq ''        ? ('index.html')
                     : $p =~ m{/$}     ? ($p.'index.html')
                     :                   ($p, "$p.html", "$p/index.html");
            push @rotas, $u unless grep { -f "$ROOT/$_" } @cand;
        }
        @rotas ? fallo(id=>'PAG-03', titulo=>'el sitemap lista URLs que no existen en disco',
                       dato=>join(' · ', @rotas[0..($#rotas > 4 ? 4 : $#rotas)]),
                       umbral=>'0', proc=>'_audit.sh · llms.txt de climentmedia publico 11 URLs a 404',
                       hacer=>'un sitemap con 404 le pide a Google que indexe lo que no hay')
               : pasa(id=>'PAG-03', titulo=>'el sitemap apunta a paginas que existen', dato=>scalar(@loc).' URLs');
    } else {
        nv(id=>'PAG-03', titulo=>'coherencia del sitemap', hacer=>'no hay sitemap.xml que leer');
    }
}

# =============================================================================
#  BLOQUE 4 · ANATOMIA — el corazon del gate, y el equivalente real del paso 7
# =============================================================================
#  audit-vs-origen pregunta «¿que tenian ellos que nosotros no?».
#  Aqui la pregunta es «¿que exige la anatomia de este TIPO que esta pagina no
#  tiene?». Es la misma clase de pregunta —enumerar desde fuera de mi cabeza—
#  con la unica fuente que existe cuando no hay origen: 09 §2.
sub bloque_anatomia {
    my (%sin_datasec, %incompleta, $n_ok);
    for my $e (@ENT) {
        my ($ruta, $h) = html_de($e);
        next unless defined $h;
        my $tipo = $e->{tipo};
        next unless exists $ANATOMIA{$tipo} && @{$ANATOMIA{$tipo}};
        my ($main) = $h =~ m{<main\b[^>]*>(.*?)</main>}si; $main //= $h;
        my @secs = $main =~ /data-sec\s*=\s*["']([a-z-]+)["']/gi;
        if (!@secs) { push @{$sin_datasec{$tipo}}, $ruta; next }
        my %hay = map { lc $_ => 1 } @secs;
        my @faltan = grep { !$hay{$_} } @{$ANATOMIA{$tipo}};
        @faltan ? push(@{$incompleta{$ruta}}, @faltan) : $n_ok++;
    }

    if (%sin_datasec) {
        my $tot = 0; $tot += scalar @$_ for values %sin_datasec;
        # 🔴 En GREENFIELD esto es FALLO, no NO VERIFICADO, y la diferencia importa.
        # qa-maestro lo deja en NV porque sobre una web ya publicada no hay nada
        # que hacer sin regenerar. Aqui todavia no hay 40 paginas: hay un
        # generador y una spec, y anadirlo cuesta un atributo.
        my $m = join(' · ', map { "$_: ".scalar(@{$sin_datasec{$_}}) } sort keys %sin_datasec);
        $opt{modo} eq 'greenfield'
          ? fallo(id=>'ANA-01', titulo=>'ninguna seccion declara su ROL (data-sec)',
                  dato=>"$tot paginas sin data-sec · $m", umbral=>'toda seccion del cuerpo con data-sec="<rol>"',
                  proc=>'09 §1 lo EXIGE · 0 de 121 paginas nuestras lo cumplen',
                  hacer=>'la comprobacion de anatomia por rol NUNCA se ha ejecutado sobre ninguna pagina nuestra, y por eso 09 §2 lleva desde el 27-jul sin poder fallar. Se anade en el generador ANTES de la primera tanda: cuesta un atributo ahora y 121 paginas despues')
          : nv(id=>'ANA-01', titulo=>'anatomia por ROL: la pagina no declara data-sec',
               dato=>"$tot paginas · $m", umbral=>'data-sec="<rol>" por seccion',
               proc=>'09 §1 · en migracion se hereda el generador y esto se arregla en la siguiente tanda',
               hacer=>'NO es un aprobado: significa que la anatomia de 09 §2 no se ha podido comprobar en esas paginas. Se escribe tal cual en el recibo');
    }
    if (%incompleta) {
        my @l = map { "$_ -> faltan: ".join(' ', @{$incompleta{$_}}) } sort keys %incompleta;
        fallo(id=>'ANA-02', titulo=>'paginas que declaran rol pero incumplen su anatomia',
              dato=>join(' · ', @l[0..($#l > 6 ? 6 : $#l)]),
              umbral=>'todos los roles OBL de 09 §2 para ese tipo', proc=>'09-tipos-de-pagina §2',
              hacer=>'cada rol que falta tiene su consecuencia escrita al lado en 09 §2, y su molde en references/moldes/');
    }
    $n_ok and pasa(id=>'ANA-02', titulo=>'paginas con la anatomia completa', dato=>"$n_ok");
    %sin_datasec || %incompleta || $n_ok
        or nv(id=>'ANA-01', titulo=>'anatomia', hacer=>'ninguna entidad con anatomia definida que comprobar');
}

# =============================================================================
#  BLOQUE 5 · ENLAZADO EN LA SPEC — se decide ANTES de escribir (12 §4)
# =============================================================================
#  El grafo real lo mide linking-gate.pl sobre el sitio PUBLICADO. Pero para
#  entonces el error ya cuesta una regeneracion. Lo que SI se puede comprobar
#  aqui es que la spec declara un padre para cada hijo y que ningun hub queda
#  por debajo del minimo de 09 §4.2.
sub bloque_enlazado {
    my %hijos;
    for my $e (@ENT) {
        my $pa = $e->{rec}{category} // $e->{rec}{hub} // $e->{rec}{parent} // '';
        push @{$hijos{$pa}}, $e->{slug} if $pa ne '';
    }
    my %es_hub = map { $_->{slug} => 1 } grep { $_->{tipo} eq 'hub' } @ENT;

    # ⚠️ FALSO POSITIVO YA PAGADO: `pages[]` son paginas FIJAS de primer nivel
    # (clinica, resultados, reservar-cita). No son hijos de ningun hub y exigirles
    # padre marcaba `clinica` como huerfana estando bien. Hijo = el que viene de
    # una COLECCION (`*.jsonl`, `cities`), que es hijo por construccion.
    my @huerfanos = grep { $_->{tipo} =~ /^(servicio|ficha|ciudad|guia)$/
                        && $_->{col} ne 'pages'
                        && !($_->{rec}{category} // $_->{rec}{hub} // $_->{rec}{parent}) } @ENT;
    @huerfanos ? fallo(id=>'ENL-01', titulo=>'entidades sin padre declarado en la spec',
                       dato=>join(' ', map { $_->{slug} } @huerfanos[0..($#huerfanos > 7 ? 7 : $#huerfanos)]),
                       umbral=>'todo hijo declara su hub', proc=>'12-enlazado-interno §4',
                       hacer=>'las 5 ciudades de site-c reciben CERO enlaces de todo el sitio estando en el sitemap e indexables. Si el padre no esta en la spec, no hay bucle que emita el enlace')
                : pasa(id=>'ENL-01', titulo=>'todo hijo declara su hub');

    my @flacos = grep { $es_hub{$_} && @{$hijos{$_}} < 4 } sort keys %hijos;
    my @vacios = grep { $es_hub{$_} && !$hijos{$_} } sort keys %es_hub;
    (@flacos || @vacios)
        ? aviso(id=>'ENL-02', titulo=>'hubs por debajo del minimo',
                dato=>join(' · ', (map { "$_: ".scalar(@{$hijos{$_}})." hijos" } @flacos),
                                  (map { "$_: 0 hijos" } @vacios)),
                umbral=>'>= 4 hijos, o no es un hub: es una pagina', proc=>'09 §4.2',
                hacer=>'un hub con 2 hijos canibaliza a sus hijos y no reparte nada. O crecen, o se funden en una sola pagina')
        : pasa(id=>'ENL-02', titulo=>'los hubs llegan al minimo de hijos');
}

# =============================================================================
#  BLOQUE 6 · MEDICION — el fallo mas caro que hemos tenido, y es de greenfield
# =============================================================================
sub bloque_medicion {
    # ── MED-01 · todo data-* que ESCRIBE el generador tiene LECTOR en el runtime
    # 🔴 Este es el de site-d, verificado abriendo los dos ficheros:
    #    _gen.ps1:359 emite `data-thanks` y `grep -c data-thanks script.js` = 0.
    my $gen = '';
    $gen .= (slurp($_) // '') for grep { -f } map { "$ROOT/$_" } qw(_gen.ps1 _gen.js build.pl);
    my $run = '';
    $run .= (slurp($_) // '') for grep { -f } map { "$ROOT/$_" } qw(script.js assets/script.js js/site.js);
    # 🔴 18-ago-2026 · EL CSS TAMBIEN LEE ATRIBUTOS, y este check no lo sabia.
    #    En la prueba de site-f el molde 15 (tabla-especificacion) emite
    #    `data-col` y su mecanismo movil es `content: attr(data-col)` en el CSS:
    #    el atributo tiene lector, y de hecho es el que hace la tabla usable en
    #    movil. El check solo miraba script.js y lo acuso de mudo. Cuarto FALLO
    #    del gate, falso. Un selector `[data-x]` cuenta igual: es un lector.
    my $css = '';
    $css .= (slurp($_) // '') for grep { -f } map { "$ROOT/$_" }
            qw(styles.css style.css assets/styles.css css/styles.css css/style.css);
    if ($gen eq '' || $run eq '') {
        nv(id=>'MED-01', titulo=>'lectores de los data-* que escribe el generador',
           dato=>($gen eq '' ? 'no se encontro generador' : 'no se encontro runtime JS'),
           proc=>'qa-maestro G12',
           hacer=>'sin los dos ficheros no se puede cruzar. NO es un aprobado');
    } else {
        # 🔴 14-ago-2026 · SE LEIAN LOS COMENTARIOS COMO CODIGO.
        #    En site-c.example este check acusaba `data-conversion` de no
        #    tener lector. Y no lo tiene, claro: **se quito el 12-ago**, y lo
        #    unico que queda en el generador es el COMENTARIO que explica por
        #    que se quito. El gate estaba acusando a la documentacion del
        #    arreglo de ser el defecto. Se quitan las lineas de comentario
        #    (las que empiezan por `#`, que en PowerShell y en Perl son eso)
        #    antes de buscar.
        my $gen_codigo = join "\n", grep { !/^\s*#/ } split /\n/, $gen;
        my %escritos = map { $_ => 1 } ($gen_codigo =~ /data-([a-z][a-z0-9-]*)\s*=/gi);
        delete $escritos{$_} for qw(loc cc cc-act);   # cromo/consent: lector en el propio banner
        # 🔴 Y ESTOS DOS NO LOS LEE EL RUNTIME, LOS LEE EL GATE.
        #    `data-tipo` y `data-sec` son el contrato de 09-tipos-de-pagina: los
        #    escribe el generador y los lee `qa-master.pl` (EST-02) desde
        #    fuera, no el navegador. Un atributo sin lector EN EL RUNTIME es
        #    una conversion muerta; un atributo cuyo lector es el instrumento es
        #    justo lo contrario -- es lo que hace medible la anatomia.
        #    Sin esta excepcion, cablear data-sec a una web la ponia en rojo por
        #    haberla arreglado.
        delete $escritos{$_} for qw(tipo sec);
        my (@mudos, @por_css);
        for my $a (sort keys %escritos) {
            # el runtime puede leerlo como atributo (`data-thanks`) o como
            # propiedad de dataset, que va en camelCase (`dataset.thanks`).
            my $camel = $a; $camel =~ s/-(\w)/\u$1/g;
            next if $run =~ /data-\Q$a\E/i;
            next if $run =~ /dataset\s*\.\s*\Q$camel\E\b/;
            next if $run =~ /dataset\s*\[\s*["']\Q$camel\E["']\s*\]/;
            # lectores en CSS: `content: attr(data-x)` y el selector `[data-x]`
            if ($css =~ /attr\(\s*data-\Q$a\E\s*\)/i || $css =~ /\[\s*data-\Q$a\E\s*[\]~^|*\$=]/i) {
                push @por_css, $a; next;
            }
            push @mudos, $a;
        }
        @mudos ? fallo(id=>'MED-01', titulo=>'el generador escribe atributos que NADIE lee',
                       dato=>join(' ', map { "data-$_" } @mudos),
                       umbral=>'todo data-* emitido tiene lector en el runtime',
                       proc=>'qa-maestro G12 · site-d: _gen.ps1:359 emite data-thanks y script.js lo lee 0 veces',
                       hacer=>'ese es exactamente el aspecto de una conversion muerta: el marcador esta puesto, la etiqueta existe en Ads, y no dispara nadie. Cero conversiones, cero GA4, cero gclid, sobre una clinica que paga clics')
               : pasa(id=>'MED-01', titulo=>'todo data-* emitido tiene lector',
                      dato=>scalar(keys %escritos).' atributos'
                            .(@por_css ? '  ·  leidos por el CSS: '.join(' ', map { "data-$_" } @por_css) : ''));
    }

    # ── MED-02 · la pagina de gracias existe, es noindex y marca la conversion
    my ($g) = grep { $_->{tipo} eq 'gracias' } @ENT;
    my ($rg, $hg) = $g ? html_de($g) : (undef, undef);
    if (!defined $hg) {
        for my $c (qw(gracias/index.html merci.html thanks/index.html gracias.html)) {
            next unless -f "$ROOT/$c"; $rg = $c; $hg = slurp("$ROOT/$c"); last;
        }
    }
    if (!defined $hg) {
        fallo(id=>'MED-02', titulo=>'no hay pagina de gracias',
              umbral=>'una pagina de gracias, noindex, con el evento de conversion',
              proc=>'09 §2.10 + 04-medicion.md',
              hacer=>'sin pagina de gracias no hay donde disparar la conversion, y sin conversion la publicidad se optimiza a ciegas');
    } else {
        my $ni = $hg =~ /noindex/i;
        my $marca = $hg =~ /data-thanks|dataLayer|gtag\s*\(|conversion/i;
        ($ni && $marca) ? pasa(id=>'MED-02', titulo=>'pagina de gracias: noindex + marca de conversion', dato=>$rg)
                        : fallo(id=>'MED-02', titulo=>'pagina de gracias incompleta', dato=>$rg
                                 . ($ni ? '' : ' · SIN noindex') . ($marca ? '' : ' · SIN marca de conversion'),
                                umbral=>'noindex Y marca de conversion', proc=>'09 §2.10',
                                hacer=>'en site-a la conversion la dispara un pageview de /merci: si esa ruta cambia, se deja de medir y NADA falla');
    }

    # ── MED-03 · el contenedor declarado en la spec esta en las paginas
    my $gtm = $site->{tracking}{gtm} // '';
    if ($gtm =~ /^GTM-[A-Z0-9]+$/) {
        my @sin = grep { my $h = slurp("$ROOT/$_") // ''; $h !~ /\Q$gtm\E/ } @HTML;
        @sin ? fallo(id=>'MED-03', titulo=>'paginas sin el contenedor que declara la spec',
                     dato=>scalar(@sin).' de '.scalar(@HTML).': '.join(' ', @sin[0..($#sin > 4 ? 4 : $#sin)]),
                     umbral=>'el contenedor en TODAS', proc=>'04-medicion.md',
                     hacer=>'una pagina sin contenedor no mide nada y no avisa: es un agujero con forma de pagina normal')
             : pasa(id=>'MED-03', titulo=>'el contenedor esta en todas las paginas', dato=>"$gtm · ".scalar(@HTML));
    } else {
        aviso(id=>'MED-03', titulo=>'la spec no declara contenedor de medicion',
              proc=>'00-intake §C', hacer=>'si el cliente va a hacer publicidad, la medicion es obligatoria ANTES de lanzar campanas');
    }
}

# =============================================================================
#  BLOQUE 7 · FORMULARIOS — contar TODOS, no solo el que duele
# =============================================================================
sub bloque_formularios {
    my @con = grep { my $h = slurp("$ROOT/$_") // ''; $h =~ /<form\b/i } @HTML;
    if (!@con) {
        aviso(id=>'FOR-01', titulo=>'no hay ningun formulario en el sitio',
              proc=>'05-formularios.md',
              hacer=>'si el negocio capta por telefono es correcto: dilo en el recibo. Si no, falta la via principal de captacion');
        return;
    }
    my %dest;
    for my $f (@con) {
        my $h = slurp("$ROOT/$f") // '';
        my ($a) = $h =~ /<form\b[^>]*\baction\s*=\s*["']([^"']*)["']/i;
        $dest{ defined $a && $a =~ /\S/ ? $a : '(sin action: envia a si misma)' }++;
    }
    my @mailto = grep { /^mailto:/i } keys %dest;
    @mailto ? fallo(id=>'FOR-01', titulo=>'formulario que envia por mailto:',
                    dato=>join(' ', @mailto), umbral=>'receptor propio, nunca mailto:',
                    proc=>'05-formularios.md · audit-vs-origen §4',
                    hacer=>'mailto: abre el cliente de correo del visitante y pierde el lead en cuanto no tiene uno configurado. Y no deja copia en disco')
            : pasa(id=>'FOR-01', titulo=>'formularios', dato=>scalar(@con).' paginas · destinos: '.join(' ', sort keys %dest));

    my $php = slurp("$ROOT/_deploy/contact.php") // '';
    if ($php eq '') {
        nv(id=>'FOR-02', titulo=>'receptor del formulario',
           proc=>'05-formularios.md + form-handler.php',
           hacer=>'no hay _deploy/contact.php que leer: si el receptor es otro, se dice cual. NO es un aprobado');
    } else {
        my $copia = $php =~ /fopen|file_put_contents|fwrite/i;
        $copia ? pasa(id=>'FOR-02', titulo=>'el receptor deja copia en disco')
               : fallo(id=>'FOR-02', titulo=>'el receptor NO deja copia en disco',
                       umbral=>'correo Y copia en disco', proc=>'05-formularios.md',
                       hacer=>'el correo es lo que se rompe en silencio: buzon borrado, SMTP caducado, rebote. La copia en disco es la unica prueba de que el lead existio');
    }
}

# =============================================================================
#  BLOQUE 8 · IMAGENES — existen, y tienen alt
# =============================================================================
sub bloque_imagenes {
    my (@falta, @sinalt);
    for my $e (@ENT) {
        my $img = $e->{rec}{image} // $e->{rec}{ogImage} // '';
        next if $img eq '' || $img =~ m{^https?://};
        my $p = $img; $p =~ s{^/}{};
        push @falta, "$e->{slug} -> $img" unless -f "$ROOT/$p";
        my $alt = $e->{rec}{imageAlt} // '';
        push @sinalt, $e->{slug} unless $alt =~ /\S/;
    }
    @falta ? fallo(id=>'IMG-01', titulo=>'la spec referencia imagenes que no estan en disco',
                   dato=>join(' · ', @falta[0..($#falta > 6 ? 6 : $#falta)]), umbral=>'0',
                   proc=>'audit-vs-origen §5',
                   hacer=>'una imagen declarada y ausente sale como hueco roto en produccion, y og:image roto es un rectangulo gris en WhatsApp: el canal real de recomendacion de un negocio local')
          : pasa(id=>'IMG-01', titulo=>'las imagenes declaradas existen');
    @sinalt ? fallo(id=>'IMG-02', titulo=>'imagenes de la spec sin imageAlt',
                    dato=>join(' ', @sinalt[0..($#sinalt > 9 ? 9 : $#sinalt)])
                         . (@sinalt > 10 ? " (+".(@sinalt-10).")" : ''),
                    umbral=>'imageAlt es campo OBLIGATORIO del tipo',
                    proc=>'09 §2.4 (web-content-model-013) + 14-accesibilidad',
                    hacer=>'si el alt no es campo de la spec, se escribe a mano y se olvida: og:image:alt es obligatorio desde el 5-ago y esta al 0% en 4 de 5 webs, incluida aquella donde vive el estandar')
            : pasa(id=>'IMG-02', titulo=>'toda imagen de la spec tiene alt');
}

# =============================================================================
#  BLOQUE 9 · LEGAL — con el texto del cliente, no un marcador
# =============================================================================
sub bloque_legal {
    # 🔴 14-ago-2026 · «LA SPEC NO DECLARA NINGUNA PAGINA LEGAL» sobre una web
    #    que tiene TRES, publicadas y con su texto. El gate solo miraba una
    #    forma de declararlo -- la coleccion `legal` de site.json -- y
    #    site-c.example la usa para otra cosa: ahi guarda los datos del
    #    titular que faltan, no la lista de paginas.
    #
    #    Se reconocen las TRES formas en que una pagina puede decir que es legal,
    #    de la mas debil a la mas fuerte:
    #      1 · la coleccion `legal` de la spec (como antes)
    #      2 · `tipos.por_slug` -- la declaracion explicita de tipo de pagina
    #      3 · `data-tipo="legal"` EN EL HTML, que es la que se sirve de verdad
    #    La tercera manda: es lo que lee qa-maestro y lo que ve Google.
    my %porSlug;
    if ($site->{tipos} && ref $site->{tipos}{por_slug} eq 'HASH') {
        %porSlug = %{ $site->{tipos}{por_slug} };
    }
    my @leg = grep {
        my $e = $_;
        my $es = ($e->{tipo} // '') eq 'legal'
              || (($porSlug{ $e->{slug} // '' } // '') eq 'legal');
        unless ($es) {
            my (undef, $h) = html_de($e);
            $es = 1 if defined $h && $h =~ /data-tipo\s*=\s*["']legal["']/i;
        }
        $es;
    } @ENT;
    if (!@leg) {
        fallo(id=>'LEG-01', titulo=>'la spec no declara ninguna pagina legal',
              umbral=>'aviso legal · privacidad · cookies', proc=>'00-intake §B',
              hacer=>'publicar el suyo, que ya tenia y ya habia aprobado, no es redactarlo. Redactar uno nuevo es del cliente');
        return;
    }
    my @malas;
    for my $e (@leg) {
        my ($ruta, $h) = html_de($e);
        next unless defined $h;
        # ⚠️ `TODO` va SIN /i y con fronteras: en castellano «todo» es una palabra
        # normal, y case-insensitive marcaba como relleno media web legal.
        push @malas, "$ruta (marcador de pendiente)"
            if $h =~ /Texte en attente|pendiente de revisi|lorem ipsum|\[texto\]/i
            || $h =~ /\bTODO\b/;
        my $txt = $h; $txt =~ s{<script\b.*?</script>}{}gsi; $txt =~ s{<[^>]*>}{ }gs;
        $txt =~ s/\s+/ /g;
        push @malas, "$ruta (".length($txt)." caracteres)" if length($txt) < 800;
    }
    @malas ? fallo(id=>'LEG-01', titulo=>'paginas legales sin el texto real del cliente',
                   dato=>join(' · ', @malas), umbral=>'texto aprobado, sin marcadores',
                   proc=>'audit-vs-origen §8 · 00-intake §B',
                   hacer=>'site-d tiene la politica de privacidad marcada EN VIVO como «Pendiente de revision juridica» bajo un formulario que recoge texto libre de una clinica dental')
           : pasa(id=>'LEG-01', titulo=>'paginas legales con texto', dato=>scalar(@leg));
}

# =============================================================================
#  BLOQUE 10 · INVENTADO — la direccion que audit-vs-origen no tiene
# =============================================================================
#  Solo en greenfield. Aqui el fallo no es perder: es publicar algo que ninguna
#  linea de la spec respalda, y no decirlo.
sub bloque_inventado {
    my %esperada;
    for my $e (@ENT) { my ($r) = html_de($e); $esperada{$r} = 1 if $r }
    $esperada{'index.html'} = 1; $esperada{'404.html'} = 1; $esperada{'404/index.html'} = 1;
    my @sueltas = grep { !$esperada{$_} } @HTML;
    @sueltas ? aviso(id=>'INV-01', titulo=>'paginas en disco que ninguna entidad de la spec declara',
                     dato=>join(' ', @sueltas[0..($#sueltas > 9 ? 9 : $#sueltas)])
                          . (@sueltas > 10 ? " (+".(@sueltas-10).")" : ''),
                     umbral=>'toda pagina sale de la spec', proc=>'SKILL.md regla 2: cada cambio con su `why`',
                     hacer=>'una pagina fuera del generador se pierde en la siguiente regeneracion, o sobrevive a un cambio que deberia haberla tocado. Si es a proposito, se declara en la spec o en overrides con su motivo')
             : pasa(id=>'INV-01', titulo=>'toda pagina en disco sale de la spec');

    # Marcadores de relleno servidos como contenido
    my @lorem;
    for my $f (@HTML) {
        my $h = slurp("$ROOT/$f") // '';
        push @lorem, $f if $h =~ /lorem ipsum|XXXXX|\[pendiente\]|placeholder text/i
                        || $h =~ /\bTODO\b/;   # sin /i: «todo» es castellano normal
    }
    @lorem ? fallo(id=>'INV-02', titulo=>'texto de relleno servido como contenido',
                   dato=>join(' ', @lorem[0..($#lorem > 6 ? 6 : $#lorem)]), umbral=>'0',
                   proc=>'00-intake §D',
                   hacer=>'lo que no vale es inventar y no decirlo. Un texto que el cliente no ha leido acaba en una reclamacion el dia que un paciente lo cita')
           : pasa(id=>'INV-02', titulo=>'sin texto de relleno');

    # Schema que afirma lo que la spec no sostiene
    my $sm = 0;
    for my $f (@HTML) {
        my $h = slurp("$ROOT/$f") // '';
        $sm++ if $h =~ /"SearchAction"/ && $h !~ /<input[^>]*type=["']search|role=["']search/i;
    }
    $sm ? fallo(id=>'INV-03', titulo=>'schema que afirma algo que el sitio no tiene',
                dato=>"SearchAction en $sm paginas sin buscador", umbral=>'schema honesto',
                proc=>'08-qa-final bloque C.5',
                hacer=>'un SearchAction sin buscador es una promesa a Google que la web no cumple')
        : pasa(id=>'INV-03', titulo=>'sin schema que afirme lo que no existe');
}

# =============================================================================
#  11 · EJECUCION
# =============================================================================
print "\n";
print "=" x 78, "\n";
print "  audit-vs-spec  ·  modo $opt{modo}  ·  $ROOT\n";
print "  ", scalar(@ENT), " entidades en la spec  ·  ", scalar(@HTML), " paginas en disco\n";
print "=" x 78, "\n\n";

my @plan = $opt{modo} eq 'greenfield'
    ? qw(intake esqueleto paginas anatomia enlazado medicion formularios imagenes legal inventado)
    : qw(paginas anatomia enlazado medicion formularios imagenes legal);
if ($opt{modo} eq 'migracion' && !%SOLO) {
    print "  NOTA · modo migracion: el inventario contra SU codigo lo hace\n";
    print "         audit-vs-source.sh y NO se repite aqui. Los bloques intake,\n";
    print "         esqueleto e inventado no aplican. Si audit-vs-source.sh no se\n";
    print "         ha corrido, este PASA no cubre el paso 7.\n\n";
}
my %fn = (intake=>\&bloque_intake, esqueleto=>\&bloque_esqueleto, paginas=>\&bloque_paginas,
          anatomia=>\&bloque_anatomia, enlazado=>\&bloque_enlazado, medicion=>\&bloque_medicion,
          formularios=>\&bloque_formularios, imagenes=>\&bloque_imagenes, legal=>\&bloque_legal,
          inventado=>\&bloque_inventado);
for my $b (@plan) {
    next unless quiere($b);
    printf "── %s %s\n", uc $b, '─' x (72 - length $b);
    $fn{$b}->();
    print "\n";
}

my $nf = grep { $_->{estado} eq 'FALLO' } @R;
my $na = grep { $_->{estado} eq 'AVISO' } @R;
my $nn = grep { $_->{estado} eq 'NV'    } @R;
my $np = grep { $_->{estado} eq 'PASA'  } @R;

print "-" x 78, "\n";
printf "  PASA %d  ·  FALLO %d  ·  AVISO %d  ·  NO VERIFICADO %d\n", $np, $nf, $na, $nn;
print  "  🔴 NO VERIFICADO no es un aprobado: es lo que nadie ha mirado.\n" if $nn;
print  "  VEREDICTO: ", ($nf ? 'FALLA' : 'PASA'), "\n";
print  "  En rojo no se despliega (SKILL.md · qa-maestro G14).\n" if $nf;
print "-" x 78, "\n";

if ($opt{json} ne '') {
    open my $fh, '>:encoding(UTF-8)', $opt{json} or die "no se pudo escribir $opt{json}\n";
    print $fh JSON::PP->new->pretty->canonical->encode({
        modo => $opt{modo}, repo => $ROOT, entidades => scalar @ENT,
        paginas => scalar @HTML, veredicto => ($nf ? 'FALLA' : 'PASA'),
        resumen => { pasa=>$np, fallo=>$nf, aviso=>$na, no_verificado=>$nn },
        resultados => \@R });
    close $fh;
}

exit($nf ? 1 : 0);
