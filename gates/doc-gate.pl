#!/usr/bin/perl
# =============================================================================
#  doc-gate.pl · LA DOCUMENTACION SE MIDE, NO SE REVISA
# =============================================================================
#    perl doc-gate.pl                 # sobre la skill entera
#    perl doc-gate.pl --dir RUTA      # sobre otra carpeta
#    perl doc-gate.pl --lista D1      # solo una comprobacion
#
#  🔴 POR QUE EXISTE (13-ago-2026). Esta skill tiene 7.480 lineas de
#     documentacion en 22 ficheros y 12.100 de programas. Nadie relee 7.480
#     lineas, asi que la documentacion deriva del codigo EN SILENCIO: no falla,
#     simplemente empieza a mentir. Los tres casos que lo dispararon, todos del
#     mismo dia:
#       · un analisis busco `history.tsv` donde la documentacion decia que
#         estaba, no estaba ahi, y concluyo «tiene 621 lineas y 0 NOTA» de un
#         fichero que no existe. La conclusion era CIERTA por casualidad.
#       · `deploy.sh` prometia tres veces que el motivo «queda en el
#         historial» y era un `echo`.
#       · `_ds_page_gen.ps1` seguia documentado como el generador de una pagina
#         que se corrige a mano desde hace once dias.
#
#  🔑 LA REGLA QUE APLICA A SI MISMO: solo se acusa lo que se puede PROBAR.
#     Una ruta con `<placeholder>`, una del servidor, una de `/tmp` -- no se
#     miran. Un gate de documentacion que acusa en falso se desactiva el primer
#     dia, y entonces no protege nada. Ver 07-trampas.md §21, §23 y §24-bis:
#     los tres son la misma enfermedad, una regla midiendo algo parecido a lo
#     que dice medir.
#
#  Casos de prueba: doc-gate-tests/tests.pl (rojos Y verdes).
# =============================================================================
use strict;
use warnings;

my ($DIR, $SOLO) = ('', '');
while (@ARGV) {
    my $x = shift @ARGV;
    if    ($x eq '--dir')   { $DIR  = shift @ARGV // '' }
    elsif ($x eq '--lista') { $SOLO = uc(shift @ARGV // '') }
    elsif ($x =~ /^--?(h|help|ayuda)$/) { print_ayuda(); exit 0 }
    else  { die "no entiendo '$x'. Prueba --ayuda\n" }
}
if ($DIR eq '') { ($DIR) = $0 =~ m{^(.*)[\\/][^\\/]+$}; $DIR = '.' unless defined $DIR && $DIR ne ''; }
$DIR =~ s{[\\/]+$}{};
-d $DIR or die "no existe la carpeta $DIR\n";
# 🔴 14-ago-2026 · ABSOLUTA, Y NO ES COSMETICO: **D5 NO HABIA CORRIDO NUNCA**.
#
# D1, D4 y D5 derivan el directorio PADRE con `$DIR =~ m{^(.*)[/\\][^/\\]+$}`.
# Lanzado desde `references/` sin `--dir`, `$DIR` valia "." -- una ruta relativa
# sin ningun separador-, ese patron NO CASA, y el padre acababa siendo "." otra
# vez. Resultado: D5 buscaba los CAMINO-*.md en `references/`, donde no hay
# ninguno, y decia «menos de 2 caminos: no aplica».
#
# Y asi es EXACTAMENTE como lo llama `run-all.sh`. O sea que el check que
# comprueba que los cuatro documentos que alguien SIGUE nombran la puerta de
# despliegue llevaba desde que se escribio **saliendo en verde sin mirar nada**.
# Del otro lado pasaba lo simetrico: `--dir <raiz-de-la-skill>` si encuentra los
# caminos, pero entonces D3 y D4 no encuentran ni programas ni trampas.
# NUNCA se habian comprobado las cinco cosas en la misma corrida.
#
# Es la trampa §29-bis de 07-trampas.md -- una prueba cuyo resultado depende de
# desde donde la lances- en el gate de la documentacion, y encontrada por lo
# mismo de siempre: por LEER la salida en vez de mirar solo el exit.
use Cwd qw(abs_path);
$DIR = abs_path($DIR) // $DIR;

sub print_ayuda {
    print <<'AYUDA';
doc-gate.pl · comprueba que la documentacion dice la verdad sobre el codigo.
  --dir RUTA     carpeta a mirar (por defecto, la del propio programa)
  --lista ID     solo una: D1 D2 D3 D4
Sale 1 si algo FALLA. Solo acusa lo que puede probar.
AYUDA
}

# ---------------------------------------------------------------------------
#  lectura
# ---------------------------------------------------------------------------
sub slurp { my $f = shift; open my $h, '<:raw', $f or return ''; local $/; my $c = <$h>; close $h; $c }

opendir(my $dh, $DIR) or die "no puedo leer $DIR: $!\n";
my @todo = sort grep { !/^\./ } readdir $dh;
closedir $dh;
my @DOCS  = grep { /\.md$/i  && -f "$DIR/$_" } @todo;
my @PROGS = grep { /\.(pl|sh|js)$/i && -f "$DIR/$_" } @todo;

# 25-ago · LAYOUT SPLIT. In the original tree the documents and the programs
# lived in ONE directory. In this repository they do not: the programs are in
# gates/ and the prose is in blueprint/, paths/, docs/ and checklists/. If this
# directory has programs and no documents, walk the sibling directories --
# ONE level, so a fixture tree in a test battery is not swept in by accident.
# Names stay relative to $DIR so every existing lookup keeps working.
#  🔴 25-ago · THIS USED TO READ `if (!@DOCS && @PROGS)` — walk the siblings ONLY
#     when this directory has no documents of its own. Adding a single
#     `gates/README.md` was enough to satisfy `@DOCS` and switch the whole sweep
#     off: D1 went from 35 documents to 1 and D4 stopped finding the trap log
#     entirely. It degraded to a WARNING rather than a failure, so `run-all.sh`
#     kept printing PASA over it.
#     A discovery step conditional on an ABSENCE is armed by nothing and
#     disarmed by anything. It now always walks, and merges.
if (@PROGS) {
    my ($MADRE) = $DIR =~ m{^(.*)[\\/][^\\/]+$};
    #  🔴 AND ONLY IF THE PARENT LOOKS LIKE THIS REPOSITORY'S ROOT.
    #     Making the walk unconditional fixed §78 and immediately broke two cases
    #     of this gate's own battery: the battery builds a fixture tree, and `..`
    #     of a fixture tree is a scratch directory. It swept in two unrelated
    #     documents and reported 20 findings that were nobody's defect.
    #     So the condition is a POSITIVE structural fact — the parent holds at
    #     least two of the prose directories — not "this directory happens to
    #     have no documents", which is what §78 was.
    my $parece_raiz = 0;
    if (defined $MADRE && $MADRE ne '' && -d $MADRE) {
        $parece_raiz = grep { -d "$MADRE/$_" } qw(blueprint paths docs checklists);
    }
    if ($parece_raiz >= 2) {
        for my $sub ('..', map { "../$_" } qw(blueprint paths docs checklists docs/traps)) {
            opendir(my $sh, "$DIR/$sub") or next;
            for my $e (sort grep { !/^\./ } readdir $sh) {
                push @DOCS, "$sub/$e" if $e =~ /\.md$/i && -f "$DIR/$sub/$e";
            }
            closedir $sh;
        }
    }
}
@DOCS or die "no hay ningun .md en $DIR (ni en sus carpetas hermanas)\n";

my ($FALLO, $AVISO, $PASA) = (0,0,0);
my @LINEAS;
sub bad  { my ($id,$t,$d) = @_; $FALLO++; push @LINEAS, ['FALLO',$id,$t,$d] }
sub avis { my ($id,$t,$d) = @_; $AVISO++; push @LINEAS, ['AVISO',$id,$t,$d] }
sub ok   { my ($id,$t,$d) = @_; $PASA++;  push @LINEAS, ['PASA', $id,$t,$d] }
sub corre { my $id = shift; return $SOLO eq '' || $SOLO eq $id }

# ---------------------------------------------------------------------------
#  D1 · RUTAS CITADAS QUE NO EXISTEN
# ---------------------------------------------------------------------------
#  🔴 SOLO SE MIRAN LAS RUTAS QUE EMPIEZAN POR `references/`. Es la unica forma
#     de ruta que, escrita en un documento de esta skill, significa sin ninguna
#     duda «un fichero de esta skill». Todo lo demas se salta A PROPOSITO:
#       · `index.html`, `loja.html`, `404.html`, `CLAUDE.md`  -> prosa: hablan
#         del arbol de una web de cliente, no de aqui
#       · `gtag.js`, `fbevents.js`                            -> de terceros
#       · `scratchpad/...`                                    -> de una sesion
#       · `site-d-web/styles.css`                           -> otro repo
#       · `site-a.example/services.html`                    -> una URL
#     La primera version de esta comprobacion NO las excluia y saco 32 fallos,
#     de los que 29 eran falsos. Eso es exactamente la enfermedad que este gate
#     viene a curar (07-trampas §21, §23, §24-bis), y ademas la que lo apagaria:
#     nadie mantiene encendido un gate que acusa en falso 9 de cada 10 veces.
#
#     Se resuelve contra la carpeta mirada Y contra su madre, porque un
#     documento de `references/` cita `references/x.pl` desde la raiz de la
#     skill, que es como se lee desde fuera.
if (corre('D1')) {
    my ($MADRE) = $DIR =~ m{^(.*)[\\/][^\\/]+$};
    $MADRE = $DIR unless defined $MADRE && $MADRE ne '';
    my %vistas;
    for my $doc (@DOCS) {
        # 🔴 28-ago-2026 · UN REGISTRO DE CORRIDAS NO AFIRMA QUE UNA RUTA EXISTA
        #    HOY: dice que existia el dia que se corrio. Un `RUN_LOG.md` es un
        #    apunte que se AÑADE, no documentacion que instruya, y reescribirlo
        #    para callar a este check falsifica el registro -- que es justo lo
        #    que un registro no puede permitirse.
        #    El caso real: el RUN_LOG de un sitio citaba dos veces una ruta bajo
        #    `references/`, carpeta que se renombro a `gates/` el 25-ago. Las dos
        #    lineas estan en PASADO ("se corrio X -> EXIT 0", "el generador leia
        #    X") y eran ciertas en su fecha. D1 solo puede probar que la ruta no
        #    existe AHORA, y eso no contradice ninguna de las dos.
        #    Es la misma familia que la exclusion de «una CITA de lo que decia
        #    otro documento no es una afirmacion», que ya estaba mas abajo.
        #    ⚠️ La exclusion es por FICHERO y lo mas estrecha posible: cualquier
        #    OTRO documento que cite esa misma ruta muerta sigue cayendo.
        next if $doc =~ m{(^|[\\/])RUN_LOG\.md$}i;
        my $c = slurp("$DIR/$doc");
        my $n = 0;
        for my $linea (split /\n/, $c) {
            $n++;
            # 🔴 DOS EXCLUSIONES QUE SALIERON DE MEDIR, no de imaginar. Al correr
            #    esto por primera vez sobre los 5 repos de cliente saco 3
            #    hallazgos y los 3 eran FALSOS:
            #      · site-d y site-a: «- [ ] ... contrasena puesta en
            #        `_secrets/smtp.txt`» -- una TAREA PENDIENTE. El fichero no
            #        existe todavia, y ademas no debe: es un secreto.
            #      · climentmedia: la ruta iba dentro de una CITA de lo que decia
            #        un SKILL.md viejo («lee `references/current-implementation.md`
            #        para ver el mecanismo ACTUAL»), contando un defecto pasado.
            #    Una tarea sin hacer y una cita no son afirmaciones sobre el
            #    presente. Sin estas dos lineas el gate acusaba 3 de 3 en falso
            #    sobre los repos reales, y un gate asi se apaga el primer dia.
            next if $linea =~ /^\s*[-*]\s*\[ \]/;          # tarea sin hacer
            my $en_cita = 0;
            while ($linea =~ /"([^"\n]{4,300})"/g) { $en_cita = 1 if $1 =~ /`/ }
            next if $en_cita;                               # la ruta va citada
            while ($linea =~ /`([^`\n]{2,120})`/g) {
                my $t = $1;
                next if $t =~ m{[<>*\$\{\}]|\.\.\.};
                next if $t =~ /\s/;
                # 🔴 SOLO `references/x`. El 13-ago probe a incluir tambien las
                #    carpetas internas de repo (`_deploy/`, `_spec/`...) pensando
                #    que eran inequivocas, y LO MEDI sobre los 5 repos y sobre la
                #    propia skill: **12 acusaciones, 12 falsas**.
                #      · en los repos, `_secrets/smtp.txt` era una tarea pendiente
                #        y `references/current-implementation.md` iba dentro de una
                #        cita de un SKILL.md viejo;
                #      · en la SKILL fue peor y es lo que mata la idea: esta
                #        documentacion describe OTROS repos, asi que sus
                #        `_spec/site.json` y `_deploy/...` son correctos alli y no
                #        existen aqui. Nueve de nueve.
                #    Un programa no puede distinguir «una ruta de este arbol» de
                #    «una ruta del arbol del que hablo». Se retira, y queda escrito
                #    para que nadie la vuelva a anadir pensando que es facil.
                next unless $t =~ m{^references/[\w./-]+\.(pl|sh|js|md|json|conf|tsv)$};
                (my $rel = $t) =~ s{^references/}{};
                next if -e "$DIR/$rel" || -e "$MADRE/$t" || -e "$DIR/$t";
                next if $vistas{$t}++;
                bad('D1', "programa citado que no existe", "$doc:$n -> $t");
            }
        }
    }
    ok('D1', 'los programas citados existen', scalar(@DOCS).' documentos') unless grep { $_->[1] eq 'D1' && $_->[0] eq 'FALLO' } @LINEAS;
}

# ---------------------------------------------------------------------------
#  D2 · BANDERAS CITADAS QUE EL PROGRAMA NO ACEPTA
# ---------------------------------------------------------------------------
#  Se leen las banderas REALES del analizador de opciones de cada programa y se
#  comparan con las que la documentacion pone al lado de ese programa.
#  Es la comprobacion que habria cazado «--solo implica --sin-recibo» antes de
#  que nadie escribiera codigo para arreglar algo que ya estaba resuelto.
if (corre('D2')) {
    my %acepta;
    for my $p (@PROGS) {
        my $src = slurp("$DIR/$p");
        my %f;
        # perl:  $x eq '--foo'   /^--(a|b|c)$/   '--foo'
        $f{$1} = 1 while $src =~ /--([a-z][a-z0-9-]{1,24})\b/g;
        # 🔴 14-ago-2026 · Y LAS QUE SE DECLARAN EN UNA ALTERNATIVA.
        #    El patron de arriba solo ve `--foo` escrito entero. `qa-master.pl`
        #    declara SEIS banderas asi:
        #        } elsif ($x =~ /^--(snippet|sin-red|sin-recibo|una-sola|...)$/) {
        #    y ahi el `--` va seguido de `(`, que no es `[a-z]`: no casaba
        #    ninguna. Resultado: D2 acusaba a `--sin-recibo` de «bandera que el
        #    programa no acepta» **siendo una bandera que el programa acepta**,
        #    en cuanto un documento la citaba sola.
        #    Lo destapo escribir la regla 13 de 00-formula.md, que la cita.
        while ($src =~ m{--\(([a-z0-9|_-]{3,200})\)}g) {
            $f{$_} = 1 for grep { /^[a-z]/ } split /\|/, $1;
        }
        $acepta{$p} = \%f;
    }
    my %vistas;
    for my $doc (@DOCS) {
        my $c = slurp("$DIR/$doc");
        my $n = 0;
        for my $linea (split /\n/, $c) {
            $n++;
            # 🔴 SOLO si la linea nombra UN programa. Si nombra dos, no se puede
            #    saber de cual es cada bandera, y atribuirlas al primero acusa en
            #    falso. Me paso con mi propia linea de §19 -- «`--sin-recibo`, y
            #    `receipt.pl --para-desplegar`» -- donde `--sin-recibo` es de
            #    qa-maestro. Ante la duda, este gate calla.
            my %progs;
            $progs{$1} = 1 while $linea =~ /\b([a-z0-9-]+\.(?:pl|sh|js))\b/g;
            next unless scalar(keys %progs) == 1;
            my ($prog) = keys %progs;
            next unless $acepta{$prog};
            while ($linea =~ /(?<![\w-])--([a-z][a-z0-9-]{1,24})\b/g) {
                my $flag = $1;
                next if $acepta{$prog}{$flag};
                next if $vistas{"$prog|$flag"}++;
                bad('D2', "bandera que el programa no acepta", "$doc:$n -> $prog --$flag");
            }
        }
    }
    ok('D2', 'las banderas citadas existen', scalar(@PROGS).' programas') unless grep { $_->[1] eq 'D2' && $_->[0] eq 'FALLO' } @LINEAS;
}

# ---------------------------------------------------------------------------
#  D3 · IDs DE COMPROBACION CITADOS QUE NADIE EMITE
# ---------------------------------------------------------------------------
#  Un documento que explica «arregla SEO-12» cuando SEO-12 no existe manda a
#  buscar algo que no esta. Solo se miran las familias que sabemos leer, y solo
#  si el programa que las emite esta en esta carpeta: si no, no se puede saber
#  y no se acusa.
if (corre('D3')) {
    my %emitidos;
    for my $p (@PROGS) {
        my $src = slurp("$DIR/$p");
        $emitidos{$1} = 1 while $src =~ /id\s*=>\s*'([A-Z][A-Z0-9]*-[0-9]+[a-z]?)'/g;
        $emitidos{$1} = 1 while $src =~ /\b(R[0-9]{1,2})\b\s+[a-z]/g;   # reglas del gate de enlazado
    }
    my %familias = map { $_ => 1 } qw(SEO REN A11Y MED EST);
    # 🔴 28-ago-2026 · SOLO SE JUZGA UNA FAMILIA QUE SE HAYA VISTO EMITIR.
    #    Al conectar por fin los repos de sitio (`config/site-repos.conf`),
    #    `un repo de sitio` salio con 5 FALLO citando MED-09, MED-01, EST-03,
    #    EST-04 y MED-13. Los cinco EXISTEN en `qa-master.pl` -- lo que pasa es
    #    que ese programa no vive en el repo del sitio, asi que aqui no se lee.
    #    Y el guardia de "¿tengo con que juzgar?" era `keys %emitidos`, que en
    #    ese arbol NO estaba vacio: un `R10 l` suelto dentro de un `.js` casaba
    #    con el patron de las reglas de enlazado. UN acierto accidental basto
    #    para que se creyera en posesion del catalogo entero.
    #    Es el hermano del "un cero de grep no es una ausencia": **un UNO
    #    tampoco es una presencia.** Sin un solo `MED-*` emitido en el arbol,
    #    este check no sabe nada de la familia MED y no puede acusarla.
    #    ⚠️ NO se apaga: si el arbol SI emite MED-01..MED-08 y el documento cita
    #    MED-99, sigue saliendo FALLO. Lo unico que se calla es la familia de la
    #    que no hay ni un emisor, y se dice en voz alta cuantas se callaron.
    # ⚠️ La familia se saca de CADA clave por separado, no de un `join` dentro
    #    del `while`: `join(...)` fabrica una cadena NUEVA en cada vuelta, asi
    #    que `pos()` se reinicia y el bucle no termina JAMAS. Costo un timeout.
    my %fam_emitida;
    for my $k (keys %emitidos) { $fam_emitida{$1} = 1 if $k =~ /^([A-Z][A-Z0-9]*)-[0-9]/ }
    if (keys %emitidos) {
        my %vistas; my %sin_emisor;
        for my $doc (@DOCS) {
            my $c = slurp("$DIR/$doc");
            my $n = 0;
            for my $linea (split /\n/, $c) {
                $n++;
                while ($linea =~ /\b([A-Z][A-Z0-9]*)-([0-9]+[a-z]?)\b/g) {
                    my ($fam, $num) = ($1, $2);
                    next unless $familias{$fam};
                    if (!$fam_emitida{$fam}) { $sin_emisor{$fam}++; next; }
                    my $id = "$fam-$num";
                    next if $emitidos{$id};
                    next if $vistas{$id}++;
                    bad('D3', "ID de comprobacion que nadie emite", "$doc:$n -> $id");
                }
            }
        }
        if (keys %sin_emisor) {
            avis('D3', 'familias de ID que este arbol no emite: no se juzgan',
                 join(' · ', map { "$_ (".$sin_emisor{$_}." cita(s))" } sort keys %sin_emisor)
                 . ' -- su programa vive en la skill, no aqui');
        }
        ok('D3', 'los IDs citados existen', scalar(keys %emitidos).' emitidos') unless grep { $_->[1] eq 'D3' && $_->[0] eq 'FALLO' } @LINEAS;
    } else {
        avis('D3', 'no he encontrado ningun ID emitido', 'sin programa que los emita, no se puede comprobar');
    }
}

# ---------------------------------------------------------------------------
#  D4 · TRAMPAS SIN MECANISMO DECLARADO
# ---------------------------------------------------------------------------
#  🔑 ESTA ES LA QUE IMPORTA. Una trampa escrita es una historia; lo que impide
#     repetirla es un mecanismo. Medido en esta misma skill: con la regla
#     escrita delante, el incumplimiento fue del 44%. Escribirla ayuda; no basta.
#
#     Convencion: cada seccion `## N ·` de 07-trampas.md declara una linea
#         **Lo caza:** <fichero de prueba, ID de comprobacion, o «nadie»>
#     «nadie» es una respuesta VALIDA y no falla: hay trampas que no se pueden
#     automatizar. Lo que no vale es no decirlo -- porque entonces no se sabe
#     cuantas de las 25 estan cubiertas de verdad, que es el unico numero que
#     dice si esto mejora.
if (corre('D4')) {
    # The traps live in one file in the Spanish original and in four numbered
    # parts in the English edition. ALL of them are read: checking one part and
    # calling it "the trap file" would be measuring a quarter and reporting the
    # whole, which is the bias this gate exists to catch.
    # Matches `07-trampas.md`, `traps.md` AND `traps/1-19.md`: the parts live in
    # a traps/ subdirectory, and `[^/]*` cannot cross the separator. The first
    # version missed all four parts and reported "0 traps" while reading only
    # the index — a check quietly measuring nothing, which is §65.
    my @tf = grep { m{(?:trampas|traps)[^/\\]*\.md$}i
                 || m{traps[/\\][^/\\]+\.md$}i } @DOCS;
    if (!@tf) {
        avis('D4', 'no hay fichero de trampas',
             "no encuentro *trampas.md ni *traps*.md en $DIR ni en sus hermanas");
    } else {
        my $c = join("\n", map { slurp("$DIR/$_") } @tf);
        my @sec;
        my @lineas = split /\n/, $c;
        for my $i (0 .. $#lineas) {
            # 19-ago-2026 - EL FICHERO TIENE DOS CONVENCIONES DE ENCABEZADO. Las 59
            #   primeras trampas son `## N .` y las ultimas seis `## �N .`. Este patron
            #   solo aceptaba la primera, asi que �60..�65 eran INVISIBLES para D4: se
            #   escribieron cinco trampas sin declarar quien las caza y el gate no dijo
            #   nada. Un gate que no ve parte de su entrada no avisa de que no la ve.
            next unless $lineas[$i] =~ /^##\s+(?:\xc2\xa7)?\s*(\d+[a-z-]*)\s*·\s*(.+)$/;
            push @sec, { n => $1, titulo => $2, desde => $i };
        }
        for my $j (0 .. $#sec) {
            my $hasta = ($j < $#sec) ? $sec[$j+1]{desde} - 1 : $#lineas;
            my $cuerpo = join "\n", @lineas[ $sec[$j]{desde} .. $hasta ];
            # `Lo caza:` in the Spanish original, `Caught by:` in the English
            # edition. Both count as a declaration; the point of D4 is that the
            # trap declares its mechanism, not which language it declares it in.
            $sec[$j]{caza} = ($cuerpo =~ /\*\*(?:Lo caza|Caught by):\*\*\s*(.+)/) ? $1 : undef;
        }
        my @sin = grep { !defined $_->{caza} } @sec;
        my @con = grep {  defined $_->{caza} } @sec;
        # `nadie` in the Spanish original, `nobody` in the English edition.
        my $nadie = grep { $_->{caza} =~ /\b(?:nadie|nobody)\b/i } @con;
        if (@sin) {
            bad('D4', 'trampas sin declarar que las caza',
                scalar(@sin).' de '.scalar(@sec).": ".join(' ', map { '§'.$_->{n} } @sin[0 .. ($#sin > 7 ? 7 : $#sin)]));
        } else {
            ok('D4', 'todas las trampas declaran su mecanismo',
               scalar(@sec)." trampas · $nadie dicen «nadie» a proposito");
        }
    }
}

# ---------------------------------------------------------------------------
#  D5 · LOS CAMINOS LLEVAN EL MISMO BLOQUE DE LA PUERTA
# ---------------------------------------------------------------------------
#  🔴 13-ago-2026 · MEDIDO CON UN GREP DE TRES SEGUNDOS: los cuatro documentos
#     que alguien SIGUE -CAMINO-1 a CAMINO-4- no nombraban ni una vez
#     `deploy.sh`, la unica puerta obligatoria del proceso. Y CAMINO-1 mandaba
#     medir «el sitio publicado» sin `--candidato`, justo lo contrario de lo que
#     dice el SKILL.md. Asi se llega a desplegar a mano con todo en verde: no
#     saltandose el proceso, sino siguiendo el documento equivocado.
#
#     Se arreglo poniendo el MISMO bloque en los cuatro. Esto comprueba que sigue
#     siendo el mismo, porque «acordarse de copiarlo» es la clase de regla que ya
#     fallo antes (§24, el menu duplicado a mano en 21 paginas).
#     Compara el texto NORMALIZADO -sin espacios de mas- para no acusar por un
#     salto de linea, que seria ruido y no una divergencia.
if (corre('D5')) {
    my ($MADRE2) = $DIR =~ m{^(.*)[\\/][^\\/]+$};
    $MADRE2 = $DIR unless defined $MADRE2 && $MADRE2 ne '';
    my @caminos;
    # `CAMINO-*.md` was the Spanish name and `paths/<n>-*.md` is the English one.
    # BOTH are looked for, and the English ones live in a paths/ subdirectory.
    # This is trap §36 exactly: the check said "fewer than 2 paths: does not
    # apply" and PASSED without looking at anything, because it was searching
    # for a filename that no longer exists. A check that cannot find its subject
    # has to say so, not pass.
    # 🔴 26-ago-2026 · EL PATRON NUMERICO SOLO VALE DENTRO DE `paths/`.
    #    Estaba aplicado a los CUATRO directorios, incluido `$DIR`. En el repo
    #    `$DIR` es `gates/`, que no tiene ningun `.md` numerado, y por eso
    #    pasaba. En la skill `$DIR` es `references/`, que tiene `10-` a `18-`:
    #    los recogia como caminos y les exigia el bloque de la puerta.
    #    Medido ese dia: repo PASA («4 caminos, un solo bloque») y skill FALLA
    #    («9 de 13»), acusando a nueve documentos de referencia. Mismo codigo,
    #    veredictos opuestos, y el de la skill era falso.
    #    Es la trampa §36 en el otro sentido: alli el check no encontraba a su
    #    sujeto, aqui encuentra de mas. Las dos son el mismo defecto -- el check
    #    no sabe identificar a su sujeto -- y las dos ensenan a ignorarlo.
    for my $d ($DIR, $MADRE2, "$MADRE2/paths", "$DIR/../paths") {
        next unless -d $d;
        my $es_paths = ($d =~ m{[\\/]paths[\\/]?$}) ? 1 : 0;
        opendir(my $h, $d) or next;
        push @caminos, map { "$d/$_" }
                       grep { /^CAMINO-.*\.md$/i
                              || ($es_paths && /^[1-9][0-9]?-.*\.md$/) } readdir $h;
        closedir $h;
    }
    # Dedup by BASENAME, not by path string: `x/paths/a.md` and
    # `x/gates/../paths/a.md` are the same file and counted as two.
    my %u; @caminos = grep { my $b = $_; $b =~ s{.*[\\/]}{}; !$u{$b}++ } @caminos;
    if (!@caminos) {
        # ZERO found is NOT the same as one found, and conflating them is §36
        # itself: the check said "does not apply" and passed without looking,
        # because it was searching for a filename that no longer existed.
        avis('D5', 'no encuentro los caminos',
             'cero: ni CAMINO-*.md ni paths/<n>-*.md. Sin sujeto no se comprueba nada');
    } elsif (@caminos < 2) {
        # ONE path is an honest "nothing to compare": a block is compared
        # BETWEEN documents, and with one there is no between.
        ok('D5', 'los caminos llevan el mismo bloque', 'un solo camino: nada que comparar');
    } else {
        my (%bloque, @sin);
        for my $f (@caminos) {
            my $c = slurp($f);
            # Both headings: the Spanish original and the English edition.
            my ($b) = $c =~ /(^##\s+(?:🔴\s+LA PUERTA|THE DOOR).*)/ms;
            (my $base = $f) =~ s{.*[\\/]}{};
            if (!defined $b) { push @sin, $base; next }
            $b =~ s/\s+/ /g; $b =~ s/^\s+|\s+$//g;
            $bloque{$base} = $b;
        }
        my %distintos; $distintos{$_}++ for values %bloque;
        if (@sin) {
            bad('D5', 'un camino sin el bloque de la puerta',
                scalar(@sin).' de '.scalar(@caminos).': '.join(' ', @sin));
        } elsif (scalar(keys %distintos) > 1) {
            bad('D5', 'los caminos NO llevan el mismo bloque',
                scalar(keys %distintos).' versiones distintas entre '.scalar(@caminos).' caminos');
        } else {
            ok('D5', 'los caminos llevan el mismo bloque',
               scalar(@caminos).' caminos, un solo bloque');
        }
    }
}

# ---------------------------------------------------------------------------
#  D6 · SKILL.md no puede mentir sobre su propia bateria
# ---------------------------------------------------------------------------
#  19-ago-2026. SKILL.md publicaba «365 casos en verde» y «59 de 121 con caso»
#  cuando eran 817 y 117 de 132 -- y en otro parrafo del MISMO documento citaba
#  el desglose correcto. Se contradecia a si mismo.
#
#  No es cosmetico: ese parrafo dice literalmente «si baja, se ha roto algo del
#  instrumento». Un umbral escrito a mano que lleva meses sin tocarse NO puede
#  detectar una bajada -- cualquier numero por encima de 365 parece bien,
#  incluidos los que serian una regresion de verdad. Es la misma familia que
#  07-trampas §61: un control que no puede ponerse rojo.
#
#  `run-all.sh` deja su recuento en `.ultima-bateria`. Aqui se compara.
#  Si no hay fichero, se dice -- no se aprueba por defecto.
if (corre('D6')) {
    my ($MADRE6) = $DIR =~ m{^(.*)[\/][^\/]+$};
    my $f = "$DIR/.ultima-bateria";
    if (!-f $f) {
        avis('D6', 'nadie ha corrido la bateria todavia',
             'sin .ultima-bateria no hay con que comparar: corre run-all.sh');
    } else {
        my %m;
        open my $h, '<:raw', $f or die;
        while (my $l = <$h>) { $m{$1} = $2 if $l =~ /^([\w-]+):\s*(.+?)\s*$/ }
        close $h;
        my $real  = $m{verde} // '';
        # 🔴 26-ago-2026 · Y EL RECUENTO NO ES UNO, SON DOS.
        #    `historial` sale NO MEDIDO en una instalacion nueva y PASA en
        #    cuanto la maquina ha desplegado una vez, asi que el total no es el
        #    mismo numero para todo el mundo. El README promete el de una
        #    INSTALACION LIMPIA -lo dice en su propia frase- y aqui se comparaba
        #    contra ESTA corrida. Medido ese dia: tras desplegar dos webs la
        #    bateria paso de 617 a 619 y este check se puso rojo sin que nadie
        #    hubiera roto nada.
        #    ⚠️ Y el arreglo obvio era el malo: subir el numero a 619 habria
        #       dejado este check en ROJO para cualquiera que clone el repo y no
        #       haya desplegado nunca. Un gate no puede exigir que la
        #       documentacion mienta a los demas para callarse en tu maquina.
        #    Se aceptan los DOS y no se pierde poder: si la documentacion se
        #    queda vieja de verdad, no casa con ninguno.
        my $limpia = $m{"verde-instalacion-limpia"} // $real;
        # 🔴 28-ago-2026 · Y NO SON DOS CIFRAS, SON CUATRO: hay DOS MODOS.
        #    `--fast` se salta los 10 bancos lentos y da 630; la corrida
        #    completa da 728. Las dos son ciertas y las dos estan publicadas.
        #    Hasta hoy `.ultima-bateria` guardaba solo la ultima corrida sin
        #    decir de que modo era, asi que este check comparaba el numero del
        #    README -que es el de `--fast`, y lo dice en su propia frase-
        #    contra la corrida que hubiera pasado por ultima vez: verde tras
        #    una rapida, ROJO tras una completa, sin que nadie tocara nada.
        #    Ahora el fichero lleva `modo:` y conserva las cifras del otro.
        #    ⚠️ NO se pierde poder: una cifra caducada de verdad no casa con
        #       ninguna de las cuatro. Lo que se deja de castigar es publicar
        #       las dos medidas que el propio programa sabe producir.
        my $otro   = $m{"otro-modo-verde"} // '';
        my $otro_l = $m{"otro-modo-verde-instalacion-limpia"} // $otro;
        my %valido = map { $_ => 1 } grep { length } ($real, $limpia, $otro, $otro_l);
        # 🔴 26-ago-2026 · D6 MIRABA SOLO `SKILL.md`, Y `gates/README.md` PUBLICA
        #    SU PROPIO RECUENTO SIN QUE NADIE LO VIGILE. Medido ese dia: el
        #    README decia «451 cases green» y la bateria daba 592 -- 141 casos de
        #    diferencia, y en verde. Es EXACTAMENTE el defecto que la cabecera de
        #    arriba describe, cometido en el fichero de al lado: un numero a mano
        #    que nadie puede ver caducar.
        #    Y va en ingles ademas de en castellano, porque el README lo esta.
        # 🔴 26-ago-2026 · Y EL README RAIZ TAMBIEN, por el mismo motivo que se
        #    anadio `gates/README.md` arriba: publica su propio recuento y nadie
        #    lo miraba. Medido ese dia: decia «37 programs and 27 test
        #    batteries» cuando ya eran 28, y estaba asi EN UN COMMIT YA
        #    EMPUJADO. Un numero a mano en un documento publico no caduca
        #    despacio: caduca callado.
        my @docs = ( [ 'SKILL.md',        "$MADRE6/SKILL.md" ],
                     [ 'gates/README.md', "$DIR/README.md"   ],
                     [ 'README.md',       "$MADRE6/README.md" ] );
        my (@dichos, @mal);
        for my $d (@docs) {
            next unless -f $d->[1];
            my $t = slurp($d->[1]);
            my @n = ($t =~ /(\d{2,5})\s*(?:\S+\s*)?0 en rojo/g);
            push @n, ($t =~ /(\d{2,5})\s+casos en verde/g);
            push @n, ($t =~ /(\d{2,5})\s+cases green/g);
            push @dichos, @n;
            push @mal, map { "$d->[0] dice $_" } grep { !$valido{$_} } @n;

            # 🔴 EL NUMERO DE BATERIAS ES OTRO DATO A MANO, y hasta hoy nadie lo
            #    vigilaba. `run-all.sh` ya lo deja escrito (`bancos:`), asi que
            #    solo faltaba compararlo. Cuenta los DECLARADOS, no los
            #    corridos: en `--fast` corren 18 de 28, y el documento habla de
            #    cuantos hay, no de cuantos cupieron en esta corrida.
            if (defined $m{bancos} and length $m{bancos}) {
                my @b = ($t =~ /(\d{1,4})\s+test batteries/g);
                push @b, ($t =~ /(\d{1,4})\s+bancos de prueba/g);
                push @dichos, @b;
                push @mal, map { "$d->[0] dice $_ baterias" }
                           grep { $_ ne $m{bancos} } @b;
            }
        }
        if (!@dichos) {
            ok('D6', 'la documentacion no publica un recuento de la bateria', 'nada que pueda caducar');
        } elsif (@mal) {
            bad('D6', 'la documentacion publica un recuento que ya no es cierto',
                join(' · ', @mal)." y la ultima bateria midio $real"
                . ($limpia ne $real ? " ($limpia en una instalacion limpia)" : ""));
        } else {
            ok('D6', 'el recuento de la documentacion coincide con la ultima bateria',
               "$real casos, en ".scalar(@docs)." documento(s)");
        }
    }
}

# ---------------------------------------------------------------------------
#  informe
# ---------------------------------------------------------------------------
print "===== GATE DE DOCUMENTACION · $DIR =====\n\n";
my %ultimo;
for my $l (@LINEAS) {
    my ($estado, $id, $tit, $det) = @$l;
    if (($ultimo{$id} // '') ne $id) { $ultimo{$id} = $id }
    printf "%-6s %-4s %-42s %s\n", $estado, $id, $tit, ($det // '');
}
print "\n";
printf "  FALLO %d  ·  AVISO %d  ·  PASA %d\n", $FALLO, $AVISO, $PASA;
print $FALLO ? "  🔴 la documentacion dice cosas que el codigo no dice.\n"
             : "  la documentacion casa con el codigo en lo que se puede comprobar.\n";
print "  ⚠️ Lo que este gate NO mira: si lo escrito es BUENO, si esta al dia en\n"
    . "     lo que no cita rutas ni IDs, y si sobra. Eso no lo sabe un programa.\n";
exit($FALLO ? 1 : 0);
