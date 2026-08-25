#!/usr/bin/env perl
# =============================================================================
#  qa-master.pl  ·  EL punto de entrada del QA de una web nuestra
# =============================================================================
#  Perl 5 puro (viene con Git Bash). NO hay node ni python en esta maquina.
#  Depende de: curl (con -L y --compressed) y, opcionalmente, openssl.
#
#  POR QUE EXISTE
#  --------------
#  Teniamos gates sueltos —_audit.sh, audit-vs-source.sh, measure-screens.js,
#  structure-gate.js, linking-gate.pl, el de CPL, cruzar-medicion.sh— en una
#  TABLA. Una tabla es un catalogo, no un paso. Ya esta escrito en las reglas de
#  la casa: **una regla que nada obliga a mirar no es un sistema**. Este fichero
#  es el paso: se corre uno, y devuelve PASA o FALLA con la lista de lo que
#  falla, donde, y que hacer.
#
#  EL META-PATRON QUE LO MOTIVA (sintesis 10-ago-2026, 5 webs)
#  ----------------------------------------------------------
#  Especificacion y gate nunca estaban cableados entre si:
#    · 09 §2.11 especifica el 404 · 08-qa-final lo menciona 0 veces · site-d
#      sirve 796 bytes con 0 enlaces.
#    · web-page-standard §1 exige og:image:alt desde el 5-ago · 4 de 5 webs al 0%,
#      incluida aquella donde vive el estandar.
#    · 09 §1 exige data-sec · 0 de 121 paginas lo declaran.
#  Cada comprobacion de aqui lleva su PROCEDENCIA escrita, para que se vea de
#  que linea de que documento sale. Si el documento cambia, el gate cambia.
#
#  LAS CUATRO SENALES, Y POR QUE SON CUATRO
#  ----------------------------------------
#    FALLO         · medido, y esta mal. No se despliega.
#    AVISO         · medido, y hay que mirarlo. No bloquea por si solo.
#    NO VERIFICADO · NADIE LO HA MIRADO. No es un aprobado.
#    ACEPTADO      · medido, esta mal, y alguien FIRMO que es una decision de
#                    negocio y no un defecto nuestro. No cuenta para el
#                    veredicto; sale en el recibo con su nombre; CADUCA.
#  El tercero es el motivo de este fichero tanto como el primero: hoy se reporta
#  como verde lo que nadie ha mirado, y un informe sin la linea de lo que se ha
#  dejado fuera se lee como si lo cubriera todo.
#
#  🔴 EL CUARTO (11-ago-2026) · ACEPTADO · <repo>/_deploy/aceptado.conf
#     EL FALLO que lo trae: el gate no sabia distinguir un defecto NUESTRO de
#     una decision del CLIENTE. Trataba igual «el favicon pesa 320 KB» que «el
#     cliente no ha decidido el plazo de conservacion de los leads». Medido en
#     site-a: de sus 8 FALLOS, CERO eran defectos del arbol —3 falsos positivos
#     del gate y 5 decisiones ya tomadas—. Con eso ninguna web puede estar verde
#     mientras haya una decision pendiente, y siempre las hay: **un gate que
#     nunca se puede satisfacer es un gate que alguien apaga**.
#     NO es `--aun-asi` (eso es para lo que esta SIN MIRAR, y no toca el rojo).
#     La seccion 10-bis lleva el diseño entero y por que cada tuerca esta donde
#     esta; el resumen es que se declara en el REPO y no en la linea de ordenes,
#     que exige cinco campos, que se acepta un HALLAZGO y no un CHECK, que
#     caduca a los 90 dias, y que hay cosas que no se pueden aceptar nunca.
#
#  DEGRADA, NO SE BLOQUEA
#  ----------------------
#  Todo lo que necesita DOM (densidad, fila coja, foco real, LCP) NO se salta en
#  silencio: se emite el snippet exacto que hay que pegar (`--snippet`) y, si se
#  devuelve su JSON (`--dom fichero.json`), se evalua. Sin el, queda NO
#  VERIFICADO con la instruccion al lado. Un QA que exige un navegador que hoy no
#  compone frames no se puede correr.
#
#  🔴 LOS DOS MOMENTOS (arreglo del 11-ago-2026) · ANTES y DESPUES
#  ---------------------------------------------------------------
#  EL FALLO, encontrado en el primer uso real de la puerta: este fichero
#  escribia un recibo que SELLA EL ARBOL DEL REPO (118 ficheros, su md5) con un
#  VEREDICTO sacado de medir PRODUCCION. Son dos artefactos distintos pegados
#  con cinta, y el resultado es un bucle:
#      · site-d, 11-ago: recibo «VEREDICTO: FALLA» por los 11 defectos que el
#        despliegue pendiente viene A ARREGLAR. La puerta se niega a subir el
#        arreglo porque produccion esta mal, y produccion esta mal porque no se
#        ha subido el arreglo. El gate bloquea justo la mejora que existe para
#        permitir.
#      · Y al reves es peor: un repo con un defecto NUEVO recibe recibo VERDE si
#        produccion —que es lo que se mide— esta bien. El recibo no decia NADA
#        sobre lo que se iba a subir.
#
#  Los dos momentos, ahora separados y los dos obligatorios:
#      1 · ANTES de subir   → se mide el CANDIDATO: el arbol del repo, servido
#                             por HTTP en local (`--candidato`). Es lo unico que
#                             puede responder «¿esto que voy a subir esta bien?».
#      2 · DESPUES de subir → se mide PRODUCCION: G11, lo servido frente al
#                             recibo (`deploy.sh REPO --servido`). Es lo unico
#                             que puede responder «¿el visitante ve esto?».
#  Ninguno sustituye al otro y el recibo dice EN SU CARA cual de los dos es
#  (`MEDIDO-CONTRA: CANDIDATO | PRODUCCION`). Un recibo que no los distingue es
#  el fallo de hoy con otra ropa.
#
#  ⚠️ EL CANDIDATO SE SIRVE POR HTTP, NO POR file://
#     Estas webs enlazan en raiz-relativo (`/styles.css`). Con `file://` eso
#     resuelve a la raiz del disco y el gate mediria una pagina sin CSS, sin JS
#     y sin imagenes: verde por vacio. Se levanta un servidor estatico minimo en
#     127.0.0.1 y se mide ahi. El SITIO del recibo sigue siendo el dominio real
#     —lo compara `deploy.sh`—, y las URLs viajan por dentro en el espacio de
#     produccion: la traduccion a `localhost` ocurre SOLO en `fetch()`, que es el
#     unico punto por el que pasa la red.
#
#  ⚠️ LO QUE EL CANDIDATO NO PUEDE MEDIR SALE «NO VERIFICADO», NUNCA «PASA».
#     Compresion, cabeceras de cache, que el host devuelva 404 de verdad y G11
#     son configuracion del SERVIDOR, no del arbol. Contra el candidato saldrian
#     verdes por construccion —los contestaria mi propio servidor de pruebas— y
#     un PASA que no se ha medido es exactamente la enfermedad que este fichero
#     existe para curar. Se listan uno a uno en el informe, con su motivo, y en
#     el recibo bajo `NV-POR-CANDIDATO:`.
#
#  USO
#  ---
#    perl qa-master.pl https://dominio.tld [opciones]
#    perl qa-master.pl @urls.txt --tipo servicio
#
#    ANTES de subir:  perl qa-master.pl https://dominio.tld --repo DIR --candidato
#    DESPUES:         bash deploy.sh DIR --servido            (G11)
#
#    --tipo T           home|servicio|ciudad|ficha|hub|guia|comparativa|precios|
#                       contacto|gracias|legal|404   (por defecto: se infiere)
#    --solo L[,L...]    seo,rendimiento,a11y,medicion,estructura
#    --gracias /ruta    ruta de la pagina de GRACIAS. 🔴 El fallo mas caro que
#                       hemos tenido vive en la unica pagina que el gate no
#                       visitaba (G1: site-d, 3 etiquetas que no disparan).
#    --contacto /ruta   ruta de la pagina de contacto
#    --repo DIR         repo local: habilita md5 repo-vs-produccion (G11),
#                       lector de data-* (G12) y tokens de la paleta en local
#    --candidato        🔴 MIDE EL ARBOL DEL REPO, NO PRODUCCION. Levanta un
#                       servidor estatico en 127.0.0.1 sobre --repo (obligatorio)
#                       y mide ahi. El recibo lo estampa: MEDIDO-CONTRA: CANDIDATO.
#                       Es el gate de ANTES de subir. NO sustituye a G11.
#    --css URL|FICHERO  hoja de tokens explicita (por defecto se descubre)
#    --dom FICHERO      JSON devuelto por el snippet del navegador
#    --snippet          imprime el snippet y sale (no toca la red)
#    --json FICHERO     vuelca el resultado completo en JSON
#    --cache DIR        directorio de cache de descargas
#    --max-urls N       tope de URLs a recorrer (por defecto 25)
#    --una-sola         NO expandir por sitemap: auditar solo la URL tecleada
#                       (el comportamiento de antes del 10-ago-2026)
#    --muestra N        paginas que recorre la lente de RENDIMIENTO, que es la
#                       cara (descarga cada recurso). Por defecto 3.
#    --sin-red          solo lo que no necesita red (exige --repo)
#    -q                 solo FALLO / AVISO / NO VERIFICADO
#
#  🔴 EL ALCANCE SE DECLARA (arreglo 0.2/0.3 del 10-ago-2026)
#     Antes: se tecleaba UNA url y cuatro de las cinco lentes miraban SOLO esa,
#     sin decirlo. Consecuencias medidas:
#       · site-b: «[PASA] SEO-02 titles unicos · DATO 1 paginas» en una tienda
#         con 50 fichas que comparten title. Con la lista entera: 2 repetidos.
#       · el veredicto dependia del ORDEN de la lista: las mismas dos URLs
#         daban «A11Y-08 FALLO» o «A11Y-08 PASA» segun cual fuera la primera.
#     Ahora: con una sola URL se construye la lista desde el sitemap que este
#     fichero YA descargaba para SEO-16, cada lente agrega sobre todas las
#     paginas que mira, y el informe imprime un bloque ALCANCE con cuantas de
#     cuantas ha mirado cada una. Una lente que mira 1 de 25 lo dice.
#
#  🔴 EL ALCANCE SE EMITE, NO SOLO SE IMPRIME (arreglo P5 del 10-ago-2026)
#     Antes el bloque ALCANCE salia por pantalla y ahi moria: no se le pasaba a
#     receipt.pl, asi que TODOS los recibos decian «ALCANCE: NO DECLARADO»
#     mientras sellaban arboles enteros. Y el denominador era la LISTA, no el
#     sitio: «SEO 25 de 25 · todas» debajo de «25 del sitemap (40 disponibles)».
#     Las dos lineas no pueden ser verdad a la vez.
#
#     FORMATO EMITIDO — otro agente lo va a leer, asi que esta escrito aqui:
#
#     1) POR PANTALLA, bloque ALCANCE. Una linea por lente:
#            <LENTE>  <miradas> de <total> del sitio [· TODAS]
#                       (<miradas> de <lista> de la lista auditada)
#                       <nota: que checks son por pagina y cuales del sitio>
#        <total> es el numero de URLs del SITEMAP. Si no se ha podido saber
#        —sin red, sin sitemap—, la cabecera lo dice: «de la lista» y un aviso
#        de que NO se sabe que porcion del sitio es. «TODAS» solo aparece
#        cuando miradas >= total del SITIO.
#
#     2) A receipt.pl (contrato con receipt.pl::alcance_lineas), cinco claves:
#            alcance     => { LENTE => [ url, url, ... ], ... }   una por lente
#                                                                 CORRIDA
#            alcance_sitio      => URLs que tiene el SITIO (sitemap) | undef
#            alcance_lista      => URLs pedidas, sin deduplicar
#            alcance_documentos => documentos distintos (tras dedupe por md5)
#            alcance_dom => "fichero.json (innerWidth=NNN)" | undef
#        De ahi salen en el recibo, y quedan bajo el SELLO:
#            ALCANCE-URLS: N                  distintas, union de las lentes
#            ALCANCE-SITIO: N | NO SE SABE    el denominador honesto
#            ALCANCE-LISTA / ALCANCE-DOCUMENTOS
#            ALCANCE-FICHEROS-SELLADOS: M     el arbol que firma el recibo
#            ALCANCE-PAGINAS-SELLADAS: P      las paginas HTML de ese arbol
#            ALCANCE-PAGINAS-MEDIDAS: Q       cuantas de esas P se han mirado
#            ALCANCE-<LENTE>: N de M del sitio - URLS 1-25 | NO CORRIDA
#            ALCANCE-URL-001..NNN: la lista completa, una por linea
#        La distancia entre ALCANCE-PAGINAS-MEDIDAS y ALCANCE-PAGINAS-SELLADAS
#        es la parte del arbol que va FIRMADA pero NO MEDIDA. `receipt.pl
#        --verificar` la imprime en voz alta, con nombres de fichero.
#
#     3) En el --json, bajo la clave `alcance`:
#            { sitio_urls, lista_urls, documentos,
#              por_lente => { LENTE => { miradas, urls[], nota } } }
#
#     🔴 Y EL ALCANCE DECIDE (11-ago-2026): un recibo sin alcance declarado, o
#        con un alcance irrisorio frente a las paginas que sella, NO vale como
#        verde para desplegar. El criterio y su justificacion viven en UN sitio,
#        receipt.pl seccion 3-ter. Resumen: 1 de cada 3 paginas selladas, o 25
#        paginas —lo que da una corrida completa por defecto—, asi que ninguna
#        corrida normal puede fallarlo; solo la que mide menos a proposito.
#
#  🔴 UN DOCUMENTO NO SON N PAGINAS (arreglo P2 del 10-ago-2026)
#     La lista deduplicaba por CADENA DE URL. shop.site-b.example declara 67 URLs
#     y sirve ONCE documentos: `loja.html?cat=*` es un solo fichero (md5
#     e55587a629cc) y `produto.html?sku=*` otro (39f60689ed61). Con eso, SEO-02
#     contaba un fichero cuatro veces, SEO-04 castigaba una canonicalizacion
#     bien hecha, y EST-01 y SEO-06 llevaban el denominador inflado. Ahora se
#     deduplica por md5 del HTML SERVIDO. Lo que NO se pierde: que 50 URLs
#     sirvan el mismo title a un rastreador sin JS sigue siendo un defecto, lo
#     dice SEO-14, y lo dice UNA vez.
#
#  SALIDA / EXIT
#  -------------
#    VEREDICTO: PASA | FALLA        exit 0 si PASA, 1 si FALLA, 2 si no se pudo
#                                   correr (que NO es lo mismo que PASA), y
#                                   3 si alguna LENTE corrio y no midio nada
#                                   (que tampoco es lo mismo que PASA: es la
#                                   regla 10 de 00-formula.md · 07-trampas §18).
#
#  🔴 REGLA DE PUBLICACION (G14 · SKILL.md + 06-publicar.md)
#     En rojo NO se despliega. El gate de densidad existe desde el 7-ago y tres
#     dias despues 12 de 15 paginas seguian en rojo: sin esta regla, los gates
#     son informes.
# =============================================================================

use strict;
use warnings;
use utf8;                 # ⚠️ sin esto los literales salen doble-codificados
use POSIX qw(strftime floor);
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use File::Spec;           # devnull: `codigo_sin_seguir` tira la respuesta
use Digest::MD5 qw(md5_hex);
use JSON::PP;
use Encode ();            # REN-04: recorrer el texto por CARACTER, no por byte

binmode(STDOUT, ':encoding(UTF-8)');
binmode(STDERR, ':encoding(UTF-8)');

# ── Constantes de instrumento ────────────────────────────────────────────────
my $UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
       . '(KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36';
# ⚠️ Sin -L se mide el cuerpo de un 301, no la pagina. Sin UA de navegador,
#    shop.site-b.example devuelve 403 (y sus .js piden Referer).

# =============================================================================
#  0 · ARGUMENTOS
# =============================================================================
my %opt = (
    tipo      => '',
    solo      => '',
    gracias   => '',
    contacto  => '',
    repo      => '',
    css       => '',
    dom       => '',
    json      => '',
    cache     => '',
    'max-urls'=> 25,
    muestra   => 3,         # paginas que recorre la lente cara (RENDIMIENTO)
    snippet   => 0,
    'sin-red' => 0,
    'una-sola'=> 0,         # no expandir por sitemap
    candidato => 0,         # medir el ARBOL DEL REPO, no produccion
    q         => 0,
    recibo    => '',        # ruta del recibo; por defecto <repo>/.qa-recibo
    'sin-recibo' => 0,      # no escribirlo (para pruebas; NO para desplegar)
    horas     => 12,        # ventana de frescura que se estampa en el recibo
    # 🔴 Ver la evidencia ENTERA de cada hallazgo, no la muestra que se imprime.
    #    Existe por el estado ACEPTADO: la huella cubre el conjunto completo, y
    #    quien va a FIRMAR que un hallazgo se acepta tiene derecho a leer lo que
    #    esta silenciando antes de firmarlo. Sin esto, la huella seria un hash
    #    que nadie puede auditar, y un silenciador que nadie audita es el `# noqa`
    #    global del que este mecanismo existe para huir.
    evidencia => 0,
);
my @targets;
{
    my @a = @ARGV;

    # -- English aliases -------------------------------------------------
    # The option KEY is the captured name ($opt{$1}), so the internal keys
    # cannot be renamed without touching every lookup in this file. Aliases
    # are additive instead: they cannot break an existing invocation, and
    # they are the pattern this program already uses for lens names
    # (`--solo perf` and `--solo struct` have always worked).
    # Documented in gates/README.md. Both spellings are supported.
    my %ALIAS = (
        '--type'       => '--tipo',      '--only'      => '--solo',
        '--thanks'     => '--gracias',   '--contact'   => '--contacto',
        '--sample'     => '--muestra',   '--receipt'   => '--recibo',
        '--hours'      => '--horas',     '--candidate' => '--candidato',
        '--no-network' => '--sin-red',   '--no-receipt'=> '--sin-recibo',
        '--single'     => '--una-sola',  '--evidence'  => '--evidencia',
    );
    @a = map { $ALIAS{$_} // $_ } @a;

    while (@a) {
        my $x = shift @a;
        if ($x =~ /^--(tipo|solo|gracias|contacto|repo|css|dom|json|cache|max-urls|muestra|recibo|horas)$/) {
            $opt{$1} = shift(@a) // '';
        } elsif ($x =~ /^--(snippet|sin-red|sin-recibo|una-sola|candidato|evidencia)$/) {
            $opt{$1} = 1;
        } elsif ($x eq '-q') {
            $opt{q} = 1;
        } elsif ($x =~ /^-h|^--help$/) {
            exec($^X, '-e', 'open my $f,"<",$ARGV[0]; while(<$f>){ last unless /^#/; print substr($_,2) }', $0);
        } elsif ($x =~ /^-/) {
            die "opcion desconocida: $x\n";
        } else {
            push @targets, $x;
        }
    }
}

# --snippet no toca la red: se puede pedir siempre.
if ($opt{snippet}) { print snippet_js(); exit 0; }

@targets or die "uso: perl qa-master.pl https://dominio.tld [opciones]  (--help)\n";

# @fichero = lista de URLs
my @URLS;
my $DE_FICHERO = 0;        # la lista la ha dado el usuario, no la he inferido yo
for my $t (@targets) {
    if ($t =~ /^\@(.+)$/) {
        $DE_FICHERO = 1;
        open my $fh, '<', $1 or die "no puedo leer $1: $!\n";
        while (<$fh>) { chomp; s/\s+$//; push @URLS, $_ if /^https?:/ }
        close $fh;
    } else {
        push @URLS, $t;
    }
}
@URLS = @URLS[0 .. ($opt{'max-urls'}-1)] if @URLS > $opt{'max-urls'};
$_ =~ s{/$}{} for @URLS;   # normaliza; la raiz queda como https://host

# Lo que se PIDIO, antes de expandir. SEO-16 pregunta «¿la pagina que me has
# dado esta en el sitemap?»: si se comparara contra la lista expandida —que
# SALE del sitemap— la respuesta seria «si» siempre, y el check dejaria de
# medir nada.
my @URLS_PEDIDAS = @URLS;
my $EXPANDIDO    = '';     # texto que explica de donde salio la lista

my %LENTE_ON = map { $_ => 1 } qw(seo rendimiento a11y medicion estructura);
if ($opt{solo} ne '') {
    %LENTE_ON = ();
    for my $l (split /\s*,\s*/, lc $opt{solo}) {
        $l = 'a11y'        if $l =~ /^(accesib|a11y)/;
        $l = 'rendimiento' if $l =~ /^(rend|perf)/;
        $l = 'medicion'    if $l =~ /^(med|legal)/;
        $l = 'estructura'  if $l =~ /^(est|struct)/;
        $l = 'seo'         if $l =~ /^seo/;
        $LENTE_ON{$l} = 1;
    }
}

my $BASE = $URLS[0];
my ($SCHEME, $HOST) = $BASE =~ m{^(https?)://([^/]+)} ? ($1,$2) : ('https', $BASE);
my $ROOT = "$SCHEME://$HOST";

# =============================================================================
#  0-bis · EL CANDIDATO  ·  medir el arbol que se va a subir, no el que ya esta
# =============================================================================
#  Ver «LOS DOS MOMENTOS» en la cabecera. Aqui solo se monta la maquinaria:
#    · se comprueba que la peticion tiene sentido (sin --repo no hay candidato
#      que medir, y --sin-red mediria la nada);
#    · se levanta un servidor estatico en 127.0.0.1 sobre el repo;
#    · se dejan puestas las dos traducciones de URL que usa `fetch`.
#
#  🔴 Exit 2, no 1, si algo de esto falla. «No se pudo correr» NO es «FALLA» ni
#     mucho menos «PASA»: son las tres senales de siempre y confundirlas aqui
#     seria fabricar un rojo o un verde que nadie ha medido.
my $CAND_ON   = $opt{candidato} ? 1 : 0;
my $CAND_PORT = 0;
my $CAND_PID  = 0;
my ($CAND_DENTRO, $CAND_FUERA) = (0, 0);   # peticiones al arbol / a fuera
my @NV_CAND;                 # ids que quedan SIN VERIFICAR *por* medir el candidato

if ($CAND_ON) {
    if ($opt{repo} eq '' || !-d $opt{repo}) {
        print STDERR "--candidato necesita --repo DIR (el arbol que se va a subir).\n";
        print STDERR "Sin repo no hay candidato: lo unico que quedaria por medir es produccion,\n";
        print STDERR "que es justo lo que este modo viene a NO hacer.\n";
        exit 2;
    }
    if ($opt{'sin-red'}) {
        print STDERR "--candidato y --sin-red se excluyen: el candidato SE SIRVE POR HTTP.\n";
        exit 2;
    }
}

# ⚠️ En modo candidato NO se reutiliza el --cache. La cache esta indexada por
#    URL, y la MISMA URL sirve bytes distintos en produccion y en el candidato
#    —y bytes distintos en cada version del arbol—. Reutilizarla es la receta
#    exacta de un verde heredado de otra medicion: el fallo mas caro de esta
#    familia (mismo identificador, contenido de otra cosa) ya nos costo una vez.
my $CACHE = ($CAND_ON ? tempdir(CLEANUP => 1) : ($opt{cache} || tempdir(CLEANUP => 1)));
make_path($CACHE) unless -d $CACHE;
my $CACHE_NOTA = ($CAND_ON && $opt{cache} ne '')
    ? 'cache ignorada a proposito en modo candidato (la misma URL sirve otros bytes)' : '';

# =============================================================================
#  1 · INFRAESTRUCTURA: red, cache, resultados
# =============================================================================
my @R;              # resultados
my %SEEN;           # de-duplicado por id
my $NET_OK = 1;     # si la primera descarga falla, todo lo de red es NO VERIFICADO

# ── 🔴 EL TECHO DE --max-urls ERA SILENCIOSO (11-ago-2026) ───────────────────
#  MEDIDO en site-d.example: el sitemap declara 40 URLs, el tope por
#  defecto mide 25, y el check imprimia
#        [FALLO] A11Y-08 · DATO 25 de 25 paginas con saltos
#  «25 de 25» se lee como «todas». Las 15 que faltan no salian por ningun lado
#  en la linea del check, y una aceptacion firmada sobre ese hallazgo se leia
#  como una decision sobre el sitio entero cuando cubria el 62% de el.
#
#  RENDIMIENTO ya lo hacia bien (su $REN_PARCIAL) porque su recorte es evidente
#  —mira 3 paginas a proposito—. El del techo no se ve, y por eso callaba.
#
#  DOS MITADES, Y HACEN FALTA LAS DOS:
#    · el bloque ALCANCE dice PARCIAL por lente, con el denominador del SITIO;
#    · cada check recortado lleva `ev_parcial`, que cambia su huella de EV= a
#      EVP=. Eso es lo que impide que una aceptacion tomada sobre 25 de 40 se
#      presente como si cubriera 40. Si luego se mide entero, la huella cambia
#      —es OTRA garantia— y hay que volver a decidirla con el dato bueno.
#
#  Se declaran aqui arriba, antes de `add`, porque `add` los lee: un `my` mas
#  abajo seria otra variable y perl no avisaria de nada util.
my $LISTA_PARCIAL = '';   # se rellena tras construir @PAGES, si el techo recorto
my $TECHO_RECORTO = 0;    # 1 = fue --max-urls quien corto, no otra cosa

#  🔴 QUE CHECKS QUEDAN RECORTADOS: los que AGREGAN SOBRE LA LISTA DE PAGINAS.
#  Los que miden EL SITIO —un sitemap, un robots.txt, un contenedor de GTM, el
#  grafo de enlaces— no se miden por pagina, y marcarlos PARCIAL no seria solo
#  ruido: seria ruido EN LA HUELLA, invalidando aceptaciones que si cubren
#  exactamente lo que dicen cubrir.
#  La lista sale de las notas de `alcance()` de cada lente, comprobadas una a
#  una contra el codigo que las emite. Si se añade un check por pagina y no se
#  apunta aqui, su hallazgo saldra sin declarar el recorte: al tocar `alcance()`
#  hay que mirar esta lista.
my %POR_PAGINA = map { $_ => 1 } (
    # SEO-01..14 sobre todas las de la lista · 15/16/17 son del sitio
    (map { sprintf('SEO-%02d', $_) } 1 .. 14),
    # A11Y-01/02/05/06/07/08 sobre todas las leidas; 03/04 son la PALETA, que
    # sale de la union de las hojas DE ESAS PAGINAS: una hoja que solo usa la
    # pagina 30 no entra en la union, asi que tambien la recorta el techo.
    qw(A11Y-01 A11Y-02 A11Y-03 A11Y-04 A11Y-05 A11Y-06 A11Y-07 A11Y-08),
    # MED-02 y MED-06 sobre todas · el resto es del sitio o la de contacto
    qw(MED-02 MED-06),
    # EST-01 y EST-02 sobre todas, cada una con SU tipo
    qw(EST-01 EST-02),
);

sub add {
    my (%f) = @_;
    # El recorte se aplica en el UNICO punto por el que pasan todos los checks.
    # Nunca pisa un `ev_parcial` ya puesto: RENDIMIENTO trae el suyo, que es mas
    # especifico (dice la muestra) y ya incluye el denominador del sitio.
    $f{ev_parcial} = $LISTA_PARCIAL
        if $LISTA_PARCIAL ne ''
        && !( defined $f{ev_parcial} && $f{ev_parcial} ne '' )
        && $POR_PAGINA{ $f{id} // '' };
    push @R, {
        estado => $f{estado},   # PASA | FALLO | AVISO | NV
        lente  => $f{lente},
        id     => $f{id},
        titulo => $f{titulo},
        donde  => $f{donde}  // '',
        umbral => $f{umbral} // '',
        proc   => $f{proc}   // '',
        hacer  => $f{hacer}  // '',
        dato   => $f{dato}   // '',
        # ── 🔴 LA EVIDENCIA COMPLETA, SEPARADA DE LO QUE SE IMPRIME ──────────
        #  `donde` es para LEER: va truncado a tres o cuatro lineas porque un
        #  informe con 25 rutas seguidas no lo lee nadie. `ev` es para HUELLAR:
        #  es el conjunto ENTERO del hallazgo. Los dos salen del mismo sitio y
        #  no pueden discrepar, pero solo `ev` decide si una aceptacion casa.
        #  Un check que no pase `ev` conserva el comportamiento de siempre
        #  (huella sobre DATO+DONDE), que es correcto cuando su DONDE ya es la
        #  evidencia entera —la mayoria— y NO lo es cuando trunca. Por eso el
        #  arreglo es pasar `ev` en los que truncan, uno por uno.
        ev     => (ref $f{ev} eq 'ARRAY' ? [ @{$f{ev}} ] : undef),
        # Motivo por el que la evidencia NO puede ser completa (muestra, red
        # caida...). Vacio = el conjunto de `ev` es todo lo que hay.
        ev_parcial => ($f{ev_parcial} // ''),
    };
}
sub fallo { add(estado=>'FALLO', @_) }
sub aviso { add(estado=>'AVISO', @_) }
sub pasa  { add(estado=>'PASA',  @_) }
sub nv    { add(estado=>'NV',    @_) }

# 🔴 NO VERIFICADO *POR MEDIR EL CANDIDATO*. No es lo mismo que un hueco: es una
#    pregunta que solo produccion puede contestar, y que se contesta DESPUES,
#    con G11. Se marcan aparte para que `deploy.sh` no exija `--aun-asi` por
#    ellas —si lo exigiera en cada despliegue, `--aun-asi` dejaria de significar
#    nada en una semana, que es como muere un gate— y para poder enumerarlas.
sub nv_cand {
    my (%f) = @_;
    push @NV_CAND, { id => $f{id}, titulo => $f{titulo}, motivo => ($f{motivo} // '') };
    delete $f{motivo};
    nv(%f);
}

# _meta_qam: lee un `.meta` de la cache SOLO si lo escribio este programa.
#   Devuelve la linea, o undef —que aqui significa MISS, «vuelve a descargar»—.
#   La forma que escribe `fetch` es `%{http_code}\t...` con 5 campos; la de
#   `crawl-links.pl`, `%{http_code}|...` con 4. Comparten clave y directorio,
#   asi que la unica defensa es no fiarse del contenido: se exige codigo de 3
#   digitos Y tabulador. Un `000\t...` de curl fallido SI es nuestro y pasa.
#   ⚠️ Que no valide el numero de campos es a proposito: un meta corto pero
#      nuestro se degrada solo (undef en las colas), mientras que uno ajeno
#      MIENTE en todas las columnas a la vez.
sub _meta_qam {
    my ($f) = @_;
    return undef unless -s $f;
    open my $mf, '<', $f or return undef;
    my $x = <$mf> // ''; close $mf;
    return ($x =~ /^\d{3}\t/) ? $x : undef;
}

# codigo_sin_seguir: el codigo de la PRIMERA respuesta, sin seguir la cadena.
# `fetch` va con -L a proposito (mide la pagina que el visitante acaba viendo),
# pero hay preguntas donde eso miente: «¿esta expuesta esta ruta?» se contesta
# con lo que devuelve ELLA, no con lo que devuelva su destino. Un sitio que
# manda los 404 a la home hace que TODA ruta inexistente parezca un 200.
# Devuelve undef si no se pudo medir (que no es lo mismo que «no expuesta»).
sub codigo_sin_seguir {
    my ($url) = @_;
    return undef if $opt{'sin-red'};
    my $furl = url_a_local($url);
    my @cmd = ('curl', '-sS', '-o', File::Spec->devnull, '-w', '%{http_code}',
               '--max-time', '20', '-A', $UA, $furl);
    my $out = '';
    if (open my $ph, '-|', @cmd) { local $/; $out = <$ph> // ''; close $ph }
    $out =~ s/\s+//g;
    return ($out =~ /^\d{3}$/) ? $out + 0 : undef;
}

# fetch: devuelve hashref {code,body,hdr,wire,ctype,url,enc,cc,err}
my %FETCHED;
sub fetch {
    my ($url, %o) = @_;
    return $FETCHED{$url} if exists $FETCHED{$url};
    if ($opt{'sin-red'}) { return $FETCHED{$url} = { code=>0, body=>'', hdr=>'', wire=>0, err=>'--sin-red' } }
    # 🔴 LA FRONTERA. En modo candidato la MISMA URL de produccion se pide al
    #    servidor local; hacia dentro del programa no cambia nada. La clave de
    #    cache lleva el modo: la misma URL sirve otros bytes en cada uno, y una
    #    respuesta de produccion devuelta como si fuera del candidato seria el
    #    peor de los fallos —no da error, devuelve datos plausibles de otra cosa—.
    my $furl = url_a_local($url);
    # 🔴 SE CUENTA QUE VA A DONDE. En modo candidato, una URL que NO case con
    #    $HOST exacto —una variante `www.`, otro subdominio, un tercero— sale a
    #    internet de verdad, y eso es correcto para GTM pero NO para una pagina
    #    del sitio. Sin este contador la mezcla seria invisible: parte del
    #    informe hablaria del arbol y parte de produccion, sin decirlo. Con el,
    #    se imprime al lado del MEDIDO y se ve de un vistazo.
    if ($CAND_ON) { $furl eq $url ? $CAND_FUERA++ : $CAND_DENTRO++ }
    # ⚠️ COLISION DE CACHE CON `crawl-links.pl` — CERRADA el 11-ago-2026.
    #    Los dos cachean con la MISMA clave —md5(url)— en el MISMO directorio, y
    #    el propio EST-08 sugeria /tmp/cache para ambos. Pero el `.meta` de crawl
    #    va separado por | con 4 campos y este parte por \t y espera 5.
    #    (Los documentos ya dicen /tmp/cache-enlaces, pero eso es AHORRO, no la
    #    garantia: la garantia es que aqui se valida lo que se lee.)
    #    → El arreglo es VALIDAR AL LEER (`_meta_qam`), no cambiar la clave: un
    #      `.meta` que no tenga NUESTRA forma no es un HIT, es un MISS.
    #
    #    🔴 Intento fallido, no repetirlo: anadir un prefijo "QAM\0" a la clave.
    #    Namespacea de verdad, pero INVALIDA las caches pre-pobladas de los
    #    fixtures y tumbo la bateria de 180 a 170. Revertido.
    #
    #    ⚠️ EL DANO REAL NO ERA EL QUE ESTABA ESCRITO AQUI. Decia «se lee la linea
    #    entera como $code, no es un numero» — medido: SI numifia. Perl saca 200
    #    de "200|https://…|0|text/html", asi que la pagina pasaba todos los
    #    `code == 200` sin enterarse. Lo que se perdia era el RESTO: wire, ctype
    #    y eff salian undef, y el `.hdr` NI EXISTE porque crawl no lo escribe.
    #
    #    MEDIDO EL 11-ago-2026 sobre site-a.example, mismo binario, misma web,
    #    lo unico que cambia es la cache (`--solo rendimiento`, sitio entero):
    #        cache limpia       REN-08 PASA  · html=br js=br css=br ... js=zstd
    #        cache de crawl     REN-08 FALLO · «texto servido SIN comprimir»
    #    O sea: un FALSO ROJO que bloquea un despliegue legitimo, no un falso
    #    verde. Sin `.hdr` no hay `content-encoding` que leer y el check concluye
    #    que la web no comprime — sobre una web que sirve brotli. En otros checks
    #    el signo se invierte (con wire=0, todo lo que filtra por `wire > 0` se
    #    salta en silencio). Lo comun no es el color: es que el numero sale de
    #    una pagina que este programa nunca descargo.
    #
    #    ⚠️ Y POR QUE NO SE VIO ANTES: la RAIZ no colisiona. crawl cachea la home
    #    con barra —`https://host/`— y aqui `@URLS` se normaliza sin ella, asi
    #    que son dos claves. Chocan las SUBPAGINAS, que ambos escriben igual.
    #    Con `--una-sola` las dos corridas salen identicas y parece que no pasa
    #    nada: la diferencia solo aparece midiendo el sitio entero.
    my $key  = md5_hex(($CAND_ON ? "CANDIDATO\0" : '') . $url);
    my $bodyf = "$CACHE/$key.body";
    my $hdrf  = "$CACHE/$key.hdr";
    my $metaf = "$CACHE/$key.meta";
    unless (defined _meta_qam($metaf)) {
        my @cmd = ('curl', '-sSL', '--compressed', '--max-time', '30',
                   '-A', $UA, '-e', ($CAND_ON ? "http://127.0.0.1:$CAND_PORT/" : "$ROOT/"),
                   '-o', $bodyf, '-D', $hdrf,
                   '-w', '%{http_code}\t%{size_download}\t%{content_type}\t%{url_effective}\t%{time_total}',
                   $furl);
        my $out = '';
        if (open my $ph, '-|', @cmd) { local $/; $out = <$ph> // ''; close $ph }
        if (open my $mf, '>', $metaf) { print $mf $out; close $mf }
    }
    # Se valida OTRA VEZ despues de descargar. Si sigue sin ser nuestro formato,
    # o curl no llego a escribir o el fichero es de otro programa y no se pudo
    # sobrescribir: se devuelve un error con nombre, no se parsea la basura.
    # El hashref va COMPLETO —antes eran dos claves— porque aguas abajo hay
    # `$r->{body} =~ /</` sin `defined`, y un undef ahi es un aviso y una rama
    # que nadie eligio.
    my $meta = _meta_qam($metaf);
    unless (defined $meta) {
        return { code=>0, body=>'', hdr=>'', wire=>0, ctype=>'', url=>$url,
                 enc=>'', cc=>'', clen=>undef, time=>0,
                 err=>'meta de cache ausente o escrito por otro programa' };
    }
    my ($code,$wire,$ctype,$eff,$time) = split /\t/, $meta;
    my $body = ''; if (open my $bf, '<:raw', $bodyf) { local $/; $body = <$bf> // ''; close $bf }
    my $hdr  = ''; if (open my $hf, '<:raw', $hdrf)  { local $/; $hdr  = <$hf> // ''; close $hf }
    my ($enc) = $hdr =~ /^content-encoding:\s*(\S+)/mi;
    my ($cc)  = $hdr =~ /^cache-control:\s*([^\r\n]+)/mi;
    my ($clen)= $hdr =~ /^content-length:\s*(\d+)/mi;
    return $FETCHED{$url} = {
        code=>($code//0)+0, body=>$body, hdr=>$hdr, wire=>($wire//0)+0,
        # la URL efectiva vuelve al espacio de PRODUCCION: `base_ef` resuelve
        # los href relativos contra ella y el resto del programa la compara con
        # canonical, sitemap y is_internal, que hablan del dominio real.
        ctype=>($ctype//''), url=>url_a_real($eff//$url), enc=>($enc//''), cc=>($cc//''),
        clen=>$clen, time=>($time//0), err=>'',
    };
}
sub head_only {
    my ($url) = @_;
    my $r = fetch($url);
    return $r;
}

# =============================================================================
#  1-bis · EL SERVIDOR DEL CANDIDATO
# =============================================================================
#  Un servidor estatico minimo, en Perl 5 pelado (IO::Socket::INET e
#  IO::Compress::Gzip vienen con el nucleo; en esta maquina no hay python y el
#  node no pinta nada aqui). Sirve UN arbol de ficheros en 127.0.0.1 y se muere
#  con el proceso que lo levanto.
#
#  POR QUE UN SERVIDOR Y NO LEER EL DISCO
#  --------------------------------------
#  Porque lo que se quiere medir es LA PAGINA, no el fichero: los enlaces
#  raiz-relativos (`/styles.css`), la resolucion de `dir/` -> `dir/index.html`,
#  el 404, el peso EN EL CABLE. Todo eso son propiedades de servir por HTTP.
#  `file://` no las tiene y ademas resuelve `/styles.css` a la raiz del disco.
#
#  LAS TRES DECISIONES QUE NO SON OBVIAS
#  -------------------------------------
#  1 · COMPRIME (gzip) cuando el cliente lo pide y el tipo es texto. Sin esto,
#      `curl --compressed` mide el HTML sin comprimir y REN-01 sale ~3,4x mas
#      gordo: site-d son 10.531 B en disco y 3.133 B en el cable. Un peso
#      inflado inventa FALLOs de peso que produccion no tiene.
#      ⚠️ NO ES EL MISMO CODEC QUE PRODUCCION, Y LA DIFERENCIA NO TIENE SIGNO
#         FIJO. Medido el 11-ago-2026 comprimiendo LOS MISMOS BYTES servidos:
#             site-d.example  br    styles.css  5.973 B · gzip6 6.296 (+323)
#             site-d.example  br    index.html  3.133 B · gzip6 3.463 (+330)
#             site-a.example     br    home        5.924 B · gzip6 6.378 (+454)
#             climentmedia.com     zstd  audit.css   3.912 B · gzip6 3.534 (-378)
#         O sea: contra brotli el candidato lee ALTO, y contra el zstd que
#         negocia Caddy lee BAJO. Escribi «gzip siempre pesa mas» antes de
#         medirlo y era falso en una de las cinco webs. Lo que SI se puede
#         afirmar es la magnitud: unos cientos de bytes por fichero de texto,
#         tres ordenes de magnitud por debajo de los umbrales de REN-01 (AVISO
#         500 KB · FALLO 1.600 KB), asi que no mueve ningun veredicto. Lo que
#         NO se puede hacer es comparar el DATO de un candidato con el de una
#         corrida de produccion como si fueran el mismo instrumento.
#      ⚠️ Y por eso mismo REN-08 (¿comprime el servidor?) NO se mide aqui: lo
#         contestaria este fichero sobre si mismo.
#  2 · REDIRIGE `/ruta` -> `/ruta/` cuando existe `ruta/index.html`, que es lo
#      que hace cualquier host estatico bien configurado (Caddy, nginx, Apache).
#      Sin ese 301, `href="hoja.css"` dentro de una pagina servida por
#      `dir/index.html` resuelve a `/hoja.css` —404— y REN-13 acusa en falso. Ya
#      paso en climentmedia y esta escrito en la cabecera de `base_ef`.
#      ⚠️ Divergencia conocida: site-d sirve SIN barra final (301 al reves).
#         Solo cambia la cadena de la URL efectiva; SEO-04 compara ya sin barra
#         final, y sus enlaces son raiz-relativos, asi que no mueve ningun umbral.
#  3 · El 404 sirve `404.html` del arbol CON estado 404. Es la unica forma de que
#      EST-03 pueda leer el 404 del candidato. Que el HOST este configurado para
#      hacerlo es otra pregunta, y esa se queda en NO VERIFICADO.
my %CTYPE = (
    html=>'text/html; charset=utf-8', htm=>'text/html; charset=utf-8',
    css=>'text/css; charset=utf-8',   js=>'text/javascript; charset=utf-8',
    mjs=>'text/javascript; charset=utf-8', json=>'application/json; charset=utf-8',
    xml=>'application/xml; charset=utf-8', txt=>'text/plain; charset=utf-8',
    svg=>'image/svg+xml', png=>'image/png', jpg=>'image/jpeg', jpeg=>'image/jpeg',
    gif=>'image/gif', webp=>'image/webp', avif=>'image/avif', ico=>'image/x-icon',
    woff=>'font/woff', woff2=>'font/woff2', ttf=>'font/ttf', otf=>'font/otf',
    mp4=>'video/mp4', webm=>'video/webm', pdf=>'application/pdf',
    map=>'application/json; charset=utf-8', webmanifest=>'application/manifest+json',
);
sub _cand_comprimible { my $c = shift // ''; return $c =~ m{^(text/|application/(json|xml|manifest)|image/svg)} ? 1 : 0 }

sub _cand_responde {
    my ($cli, $code, $texto, $ctype, $cuerpo, $gz, $extra) = @_;
    $cuerpo = '' unless defined $cuerpo;
    my @h = ("HTTP/1.1 $code $texto",
             "Content-Type: $ctype",
             "Content-Length: " . length($cuerpo),
             "Connection: close",
             "Server: qa-maestro-candidato");
    push @h, @$extra if $extra;
    push @h, "Content-Encoding: gzip", "Vary: Accept-Encoding" if $gz;
    print $cli join("\r\n", @h), "\r\n\r\n", $cuerpo;
}

sub _cand_fichero {
    my ($dir, $ruta) = @_;
    # ?query y #fragmento no llegan al disco: `loja.html?cat=x` es loja.html
    $ruta =~ s/#.*$//;
    $ruta =~ s/\?.*$//;
    $ruta =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/ge;
    return (undef, undef) if $ruta =~ m{(^|/)\.\.(/|$)};      # nada de salir del arbol
    $ruta = "/$ruta" unless $ruta =~ m{^/};
    return ("$dir/index.html", undef) if $ruta eq '/';
    my $limpia = $ruta; $limpia =~ s{/+$}{};
    return ("$dir$limpia",            undef) if -f "$dir$limpia";
    return ("$dir$limpia.html",       undef) if -f "$dir$limpia.html";
    if (-f "$dir$limpia/index.html") {
        # el 301 de la barra final: ver la decision 2 de arriba
        return ("$dir$limpia/index.html", ($ruta =~ m{/$} ? undef : "$limpia/"));
    }
    return (undef, undef);
}

sub _cand_atiende {
    my ($cli, $dir) = @_;
    my $petic = <$cli>;
    return unless defined $petic;
    my %hdr;
    while (defined(my $l = <$cli>)) { $l =~ s/\r?\n\z//; last if $l eq ''; $hdr{lc $1} = $2 if $l =~ /^([^:]+):\s*(.*)$/ }
    my ($met, $ruta) = $petic =~ /^(\w+)\s+(\S+)/ ? ($1, $2) : ('GET', '/');
    my ($f, $redir) = _cand_fichero($dir, $ruta);

    if (defined $redir) {
        _cand_responde($cli, 301, 'Moved Permanently', 'text/html; charset=utf-8',
                       '', 0, [ "Location: $redir" ]);
        return;
    }
    my $code = 200; my $texto = 'OK';
    if (!defined $f || !-f $f) {
        $code = 404; $texto = 'Not Found';
        $f = "$dir/404.html";
        # Sin 404.html en el arbol se sirve un cuerpo vacio con estado 404: es
        # la verdad (el arbol no trae pagina de 404) y EST-03 lo dira.
        unless (-f $f) { _cand_responde($cli, 404, 'Not Found', 'text/html; charset=utf-8', '', 0); return }
    }
    my ($ext) = lc($f) =~ /\.([a-z0-9]+)$/ ? ($1) : ('');
    my $ctype = $CTYPE{$ext} // 'application/octet-stream';
    my $cuerpo = '';
    if (open my $fh, '<:raw', $f) { local $/; $cuerpo = <$fh> // ''; close $fh }
    my $gz = 0;
    if (_cand_comprimible($ctype) && ($hdr{'accept-encoding'} // '') =~ /gzip/i && length($cuerpo)) {
        my $z = '';
        if (eval { require IO::Compress::Gzip; IO::Compress::Gzip::gzip(\$cuerpo, \$z, Level => 6); 1 } && length($z)) {
            $cuerpo = $z; $gz = 1;
        }
    }
    $cuerpo = '' if uc($met) eq 'HEAD';
    _cand_responde($cli, $code, $texto, $ctype, $cuerpo, $gz);
}

sub _cand_bucle {
    my ($sock, $dir) = @_;
    require IO::Select;
    my $sel = IO::Select->new($sock);
    my $ultimo = time;
    while (1) {
        my @listo = $sel->can_read(5);
        # ⚠️ Guardia contra el hijo zombi: si el padre muere sin matarme (kill -9,
        #    consola cerrada), un servidor colgado del puerto sobrevive a la
        #    sesion y el siguiente candidato mediria ESTE arbol. 5 minutos sin una
        #    sola peticion = nadie me esta usando.
        if (!@listo) { last if time - $ultimo > 300; next }
        my $cli = $sock->accept or next;
        $ultimo = time;
        $cli->autoflush(1);
        eval { _cand_atiende($cli, $dir); 1 };
        close $cli;
    }
}

#  Devuelve (pid, puerto). Muere con exit 2 si no puede: «no se pudo correr».
sub arranca_candidato {
    my ($dir) = @_;
    require IO::Socket::INET;
    my $sock = IO::Socket::INET->new(Listen => 32, LocalAddr => '127.0.0.1',
                                     LocalPort => 0, Proto => 'tcp', ReuseAddr => 1);
    unless ($sock) {
        print STDERR "no puedo abrir un socket en 127.0.0.1: $!\n";
        print STDERR "sin servidor local no hay candidato que medir. NO es un PASA.\n";
        exit 2;
    }
    my $puerto = $sock->sockport;
    my $pid = fork();
    unless (defined $pid) {
        print STDERR "no puedo lanzar el servidor del candidato (fork): $!\n";
        exit 2;
    }
    if ($pid == 0) {
        # ⚠️ HIJO. Sale con POSIX::_exit para NO correr los END del padre: el
        #    tempdir de la cache se borra en un END, y un hijo que saliera
        #    «bien» le borraria la cache al padre a media medicion.
        eval { _cand_bucle($sock, $dir); 1 };
        POSIX::_exit(0);
    }
    # El padre comprueba que de verdad responde antes de dar por buena una sola
    # medida. Un servidor que no arranco y un arbol vacio se ven igual: 404 en
    # todo. Se distingue AQUI, no en el informe.
    my $vivo = 0;
    for my $intento (1 .. 40) {
        my $out = `curl -s -o /dev/null -w "%{http_code}" --max-time 3 "http://127.0.0.1:$puerto/" 2>/dev/null`;
        if (defined $out && $out =~ /^[1-5]\d\d$/) { $vivo = 1; last }
        select(undef, undef, undef, 0.10);
    }
    unless ($vivo) {
        kill 'TERM', $pid;
        print STDERR "el servidor del candidato no responde en 127.0.0.1:$puerto\n";
        exit 2;
    }
    return ($pid, $puerto);
}

#  🔴 LAS DOS TRADUCCIONES. Por dentro TODO el programa habla en URLs de
#     PRODUCCION —canonical, sitemap, is_internal, el SITIO del recibo—; la
#     unica frontera con la red es `fetch`, y es ahi donde se traduce. Meter
#     localhost en el resto del programa habria significado tocar cada check.
sub url_a_local {
    my ($u) = @_;
    return $u unless defined $u && $CAND_ON && $CAND_PORT;
    return $u unless $u =~ m{^https?://\Q$HOST\E(/[^\s]*)?$}i;
    my $resto = defined $1 && $1 ne '' ? $1 : '/';
    return "http://127.0.0.1:$CAND_PORT$resto";
}
sub url_a_real {
    my ($u) = @_;
    return $u unless defined $u && $CAND_ON && $CAND_PORT;
    return $u unless $u =~ m{^http://127\.0\.0\.1:$CAND_PORT(/[^\s]*)?$};
    my $resto = defined $1 && $1 ne '' ? $1 : '/';
    return "$ROOT$resto";
}

if ($CAND_ON) {
    ($CAND_PID, $CAND_PORT) = arranca_candidato($opt{repo});
}
END { kill 'TERM', $CAND_PID if $CAND_PID }

# ── Helpers de HTML ──────────────────────────────────────────────────────────
# ⚠️ Un `sed` por lineas NO quita los <script>: el Consent Mode se cuela como
#    "texto del sitio". Se quita en multilinea, y con regex NO codicioso.
# 🔴 17-ago-2026 · QUITAR LOS COMENTARIOS ANTES DE MEDIR. Tres checks se
#    aprobaban o se suspendian solos por lo que decia un comentario:
#      A11Y-07  contaba el `<main>` de un comentario -> falso positivo
#      MED-02   leia «consent default» de un comentario -> **falso NEGATIVO**:
#               aprobaba una pagina que carga GTM sin consentimiento
#      SEO-09b · A11Y-05 · A11Y-08 · REN-13  idem, medido con un fixture cuyos
#               comentarios nombran el vocabulario de cada check
#    Y el detonante es perverso: **cuanto mejor documentas una plantilla, mas
#    facil es que enganes al gate**. Un comentario que explica por que el orden
#    del consent importa aprobaba el check para siempre.
#    Por eso se quita en el PUNTO DONDE CADA LENTE COGE EL CUERPO, no check a
#    check: la lista de checks crece y la de puntos de entrada no.
sub sin_com { my $x = shift; return '' unless defined $x; $x =~ s/<!--.*?-->//gs; return $x }
sub strip_code { my $h = shift // ''; $h =~ s{<script\b.*?</script>}{}gsi; $h =~ s{<style\b.*?</style>}{}gsi; return $h }
sub tag_text   { my $h = shift // ''; $h = strip_code($h); $h =~ s{<[^>]*>}{ }gs; $h =~ s/\s+/ /g; return $h }
sub attr {
    my ($tag, $name) = @_;
    return $1 if $tag =~ /\b\Q$name\E\s*=\s*"([^"]*)"/i;
    return $1 if $tag =~ /\b\Q$name\E\s*=\s*'([^']*)'/i;
    return $1 if $tag =~ /\b\Q$name\E\s*=\s*([^\s>]+)/i;
    return undef;
}
# ── largo_visible · lo que MIDE un buscador, no lo que hay en el fichero ──────
#  🔴 20-ago-2026. SEO-01 acusaba a la portada de climentmedia de 67 caracteres
#  cuando en pantalla son 63: el title lleva `&amp;` y `length` cuenta CINCO
#  caracteres donde el usuario ve UNO. El aviso era del instrumento, no de la
#  web, y llevaba ahi desde el primer dia -- se veia solo cuando el title cae
#  justo en la frontera, que es exactamente cuando el aviso importa.
#  Mismo fallo en la meta description (50-165), y ahi hay MAS entidades porque
#  son frases mas largas: un &mdash; o un &eacute; y la cuenta se va.
#  Se decodifican solo las que aparecen de verdad en estas webs; una tabla
#  completa de entidades seria mas codigo del que hace falta y mas que probar.
sub largo_visible {
    my $s = shift; return 0 unless defined $s;
    # 20-ago-2026 · SEGUNDA PASADA, Y ES EL MISMO FALLO UN PISO MAS ABAJO:
    # arreglado ya que las entidades no cuenten CINCO donde se ve UNA, esto
    # seguia contando BYTES. Sin decodificar, una e acentuada son 2 y un guion
    # largo son 3, asi que el umbral castiga exactamente al frances y al
    # castellano -- las cinco webs.
    # Medido el 20-ago: el title de site-a.example/ti-care salia 70 y en
    # pantalla son 64; su meta description, 175 contra 167. Los dos avisos,
    # INVENTADOS. Y los dos caian justo en la frontera del umbral, que es
    # exactamente cuando el aviso importa: nunca se dispara donde da igual.
    # La leccion ya estaba escrita en el use Encode de la cabecera -- recorrer
    # el texto por CARACTER, no por byte -- aplicada en REN-04 y no aqui.
    $s = (eval { Encode::decode("UTF-8", $s, Encode::FB_CROAK()) } // $s)
        unless Encode::is_utf8($s);
    $s =~ s/&(#\d+|#x[0-9a-fA-F]+|[a-zA-Z][a-zA-Z0-9]{1,7});/X/g;
    return length($s);
}

sub meta_of {
    my ($h, $key) = @_;
    for my $t ($h =~ /(<meta\b[^>]*>)/gi) {
        my $p = attr($t,'property') // ''; my $n = attr($t,'name') // '';
        return attr($t,'content') if lc($p) eq lc($key) || lc($n) eq lc($key);
    }
    return undef;
}
sub abs_url {
    my ($href, $base) = @_;
    return undef unless defined $href && $href ne '';
    return undef if $href =~ /^(mailto:|tel:|javascript:|#|data:)/i;
    return $href if $href =~ m{^https?://};
    return "$SCHEME:$href" if $href =~ m{^//};
    return "$ROOT$href" if $href =~ m{^/};
    my $b = $base; $b =~ s{[^/]*$}{};
    $b = "$base/" if $base !~ m{/[^/]*$} || $base =~ m{^https?://[^/]+$};
    return $b . $href;
}
sub is_internal { my $u = shift // ''; return $u =~ m{^https?://\Q$HOST\E(/|$)} ? 1 : 0 }

# 🔴 La base para resolver un href RELATIVO es la URL EFECTIVA, no la tecleada.
#    La lista de paginas se normaliza quitando la barra final (linea ~156), asi
#    que `https://climentmedia.com/ad-account-audit/` viaja como `.../audit`; y
#    `href="ad-account-audit.css"` resuelto contra eso da `/ad-account-audit.css`
#    —404— en vez de `/ad-account-audit/ad-account-audit.css`, que existe y
#    devuelve 200. El defecto ya estaba y era SILENCIOSO (esa hoja no entraba ni
#    en el peso ni en la paleta); lo saco a la luz REN-07/REN-13 al empezar a
#    mirar el ESTADO, y de no arreglarlo el gate acusaria en falso a una web viva.
sub base_ef {
    my $u = shift;
    my $r = fetch($u);
    return ($r && $r->{code} == 200 && $r->{url}) ? $r->{url} : $u;
}
sub kb { my $b = shift // 0; return sprintf('%.0f KB', $b/1024) }

# ── A11Y-02 · el enlace de salto, en el idioma que sea (arreglo 0.5b) ────────
# 🔴 La lista de deteccion estaba en INGLES: `class="skip"` o un href a
#    #main/#content/#contenido seguido de «saltar|skip|aller|ir al». Con eso,
#    site-c —que SI lo tiene, `<a class="saltar" href="#principal">Ir
#    al contenido</a>`— salia acusada de no tenerlo. El gate castigaba el
#    castellano. Se detecta por CUALQUIERA de las tres senales: clase, destino
#    o texto.
#
# 🔴 ARREGLO P3 (10-ago-2026) · aquello quedo DEMASIADO LAXO, y un gate laxo no
#    es «mas amable»: es un falso verde esperando. La senal del DESTINO disparaba
#    con CUALQUIER `href="#main|#contenido|#inicio"` estuviera donde estuviera.
#    Medido con seis controles: 4 bien y 2 MAL —
#        <nav> ... <a href="#inicio">Inicio</a>        (item de menu)
#        <a href="#contenido">Contenido del curso</a>  (indice de un articulo)
#    contaban como enlace de salto. Una web sin salto alguno habria salido verde
#    solo por tener un menu ancla.
#
#    Un enlace de salto no se reconoce solo por a donde va: se reconoce por
#    DONDE ESTA. Es el PRIMER enlace enfocable del documento —existe para que la
#    primera pulsacion de Tab lo encuentre— y va ANTES de la navegacion, porque
#    su razon de ser es saltarsela. Verificado en las tres webs que lo tienen:
#    site-c, site-a y site-d lo sirven como enlace n.º 1 del <body> y fuera de
#    <nav>. Asi que la POSICION es condicion necesaria, y la clase, el texto y
#    el destino siguen siendo las tres senales que lo declaran.
#
#    Margen deliberado: se aceptan los TRES primeros enlaces enfocables, no solo
#    el primero, para no acusar en falso a una maqueta que anteponga un «saltar a
#    la busqueda» o un ancla de idioma. Un item de menu nunca cae ahi sin estar
#    ademas dentro de <nav>, y el indice de un articulo esta a decenas de enlaces.
sub tiene_skip_link {
    my $h = shift // '';
    my $b = strip_code($h);                  # sin <script>/<style>: no son enlaces
    my ($body) = $b =~ m{<body\b[^>]*>(.*)}si;
    $body = $b unless defined $body;         # fragmento sin <body>: se usa entero

    # Tramos ocupados por <nav>...</nav>. Un enlace de salto DENTRO de la
    # navegacion es una contradiccion: existe para saltarsela.
    my @nav;
    while ($body =~ m{<nav\b[^>]*>.*?</nav>}gsi) { push @nav, [ $-[0], $+[0] ] }

    my $n = 0;                               # enlaces ENFOCABLES vistos
    while ($body =~ m{<a\b[^>]*>.*?</a>}gsi) {
        my ($ini, $a) = ($-[0], $&);
        my ($open) = $a =~ /^(<[^>]*>)/;
        my $href = attr($open,'href');
        next unless defined $href && $href ne '';   # sin href no es enfocable
        next if (attr($open,'tabindex') // '') =~ /^\s*-/;
        $n++;
        last if $n > 3;                      # a partir del 4.º ya no es un salto
        next if grep { $ini >= $_->[0] && $ini < $_->[1] } @nav;
        next unless $href =~ /^#/;           # un salto es SIEMPRE un ancla interna
        my $cls  = lc(attr($open,'class') // '');
        my $txt  = lc(tag_text($a)); $txt =~ s/^\s+|\s+$//g;
        my $lbl  = lc(attr($open,'aria-label') // '');
        return 1 if $cls =~ /\b(skip|salt\w*|saut\w*|pular|ir-al)\b/;
        return 1 if $href =~ /^#(main|content|contenido|contenu|conteudo|principal|primary|inicio|top-content)\b/i;
        for my $t ($txt, $lbl) {
            next if $t eq '';
            return 1 if $t =~ /^(saltar|salta|skip|jump|aller|passer|pular|ir al|ir a|vai para|vá para|zum inhalt)\b/;
            return 1 if $t =~ /\b(al contenido|au contenu|to (the )?(main )?content|ao conteudo|ao conteúdo)\b/;
        }
    }
    return 0;
}

# =============================================================================
#  2 · COLOR: OKLCH / hex / rgb -> sRGB 8 bit -> contraste WCAG
# =============================================================================
#  🔴 Calibrado, no inventado. Reproduce EXACTAMENTE lo que mide el navegador
#     porque cuantiza a 8 bits ANTES de calcular la luminancia, que es lo que
#     hace getComputedStyle. Verificado contra tres numeros de nuestro propio
#     codigo:
#       oklch(0.58 0.09 210) vs blanco          -> 4,11  (medido a mano: 4,11)
#       oklch(0.58 ...) vs oklch(0.99 0.005 210)-> 4,01  (medido a mano: 4,01)
#       oklch(0.54 ...) vs el mismo fg          -> 4,79  (comentario de
#                                                  site-d/styles.css:42: 4,79)
#     Por eso este gate puede correr SIN NAVEGADOR, que es justo lo que le
#     faltaba a G2: structure-gate.js §4c devuelve #010000 para todo bajo las
#     banderas que nuestra propia guia exige.
# -----------------------------------------------------------------------------
sub _srgb_enc { my $c = shift; $c = $c <= 0.0031308 ? 12.92*$c : 1.055*($c**(1/2.4)) - 0.055;
                $c = 0 if $c < 0; $c = 1 if $c > 1; return int($c*255 + 0.5) }
sub oklch_to_rgb8 {
    my ($L,$C,$H) = @_;
    my $h = $H * 3.14159265358979 / 180;
    my ($a,$b) = ($C*cos($h), $C*sin($h));
    my $l_ = $L + 0.3963377774*$a + 0.2158037573*$b;
    my $m_ = $L - 0.1055613458*$a - 0.0638541728*$b;
    my $s_ = $L - 0.0894841775*$a - 1.2914855480*$b;
    my ($l,$m,$s) = ($l_**3, $m_**3, $s_**3);
    return ( _srgb_enc( 4.0767416621*$l - 3.3077115913*$m + 0.2309699292*$s),
             _srgb_enc(-1.2684380046*$l + 2.6097574011*$m - 0.3413193965*$s),
             _srgb_enc(-0.0041960863*$l - 0.7034186147*$m + 1.7076147010*$s) );
}
sub luminance8 {
    my @lin = map { my $c = $_/255; $c <= 0.04045 ? $c/12.92 : (($c+0.055)/1.055)**2.4 } @_;
    return 0.2126*$lin[0] + 0.7152*$lin[1] + 0.0722*$lin[2];
}
sub contrast {
    my ($a,$b) = @_;
    my ($x,$y) = (luminance8(@$a), luminance8(@$b));
    ($x,$y) = ($y,$x) if $y > $x;
    return ($x+0.05) / ($y+0.05);
}
# Resuelve un valor de color CSS a [r,g,b,alfa] 8-bit. Devuelve undef si no se
# puede (gradiente, imagen, currentColor...): «no medible» NO es «aprobado».
#
# 🔴 EL ALFA NO SE TIRA (arreglo del 10-ago-2026). La version anterior devolvia
#    solo [r,g,b] y `rgba(var(--ok-rgb), 0.16)` —el fondo translucido de una
#    pastilla— salia como el color OPACO 53,208,127, que es EXACTAMENTE el
#    color del texto que va encima. De ahi el disparate del informe:
#        .st-live : #35d07f sobre #35d07f = 1.00:1
#    Un 1,00:1 entre dos colores distintos es imposible por definicion; aqui no
#    eran distintos porque el instrumento habia perdido el alfa. Lo mismo con
#    `color: rgba(var(--white-rgb), 0.14)`, que salia blanco puro.
sub css_rgba {
    my ($v, $vars, $depth) = @_;
    $depth //= 0; return undef if $depth > 6;
    return undef unless defined $v;
    $v =~ s/^\s+|\s+$//g;
    $v =~ s/\s*!important\s*$//i;
    # var(--x, fallback)
    while ($v =~ /var\(\s*(--[\w-]+)\s*(?:,([^()]*))?\)/) {
        my ($name,$fb) = ($1,$2);
        my $rep = defined $vars->{$name} ? $vars->{$name} : (defined $fb ? $fb : '');
        return undef if $rep eq '';
        $v =~ s/var\(\s*\Q$name\E\s*(?:,[^()]*)?\)/$rep/;
        $depth++; return undef if $depth > 6;
    }
    # `background: none` es TRANSPARENTE, no «no medible». Tratarlo como no
    # medible apagaba fallos verdaderos: .cc__link de site-d declara
    # `background: none` y su 4,11:1 sobre el lienzo blanco es real.
    return [255,255,255,0] if $v =~ /^(transparent|none|initial|unset)$/i;
    return undef if $v =~ /gradient|url\(|currentColor|transparent|inherit/i;
    if ($v =~ /^oklch\(\s*([\d.]+)%?\s+([\d.]+)\s+([\d.]+)(?:\s*\/\s*([\d.]+)(%?))?/i) {
        my ($L,$C,$H,$A,$pc) = ($1,$2,$3,$4,$5);
        $L = $L/100 if $L > 1.5;   # oklch(58% ...)
        my $a = defined $A ? ($pc ? $A/100 : $A) : 1;
        return [ oklch_to_rgb8($L,$C,$H), $a ];
    }
    if ($v =~ /^#([0-9a-f]{3})([0-9a-f])?\b/i) {
        my ($x,$al) = ($1,$2); my @c = split //, $x;
        return [ (map { hex($_.$_) } @c), (defined $al ? hex($al.$al)/255 : 1) ];
    }
    if ($v =~ /^#([0-9a-f]{6})([0-9a-f]{2})?/i) {
        my ($x,$al) = ($1,$2);
        return [ (map { hex(substr($x,$_*2,2)) } 0..2), (defined $al ? hex($al)/255 : 1) ];
    }
    if ($v =~ /^rgba?\(\s*([\d.]+)[,\s]+([\d.]+)[,\s]+([\d.]+)(?:\s*[,\/]\s*([\d.]+)(%?))?/i) {
        my $a = defined $4 ? ($5 ? $4/100 : $4) : 1;
        return [ int($1), int($2), int($3), $a ];
    }
    if ($v =~ /^hsla?\(\s*([\d.]+)(?:deg)?[,\s]+([\d.]+)%[,\s]+([\d.]+)%(?:\s*[,\/]\s*([\d.]+)(%?))?/i) {
        my ($H,$S,$L) = ($1, $2/100, $3/100);
        my $a = defined $4 ? ($5 ? $4/100 : $4) : 1;
        my $c = (1 - abs(2*$L - 1)) * $S; my $hp = $H/60;
        my $x = $c * (1 - abs($hp - 2*int($hp/2) - 1));
        my @r = $hp<1?($c,$x,0):$hp<2?($x,$c,0):$hp<3?(0,$c,$x):$hp<4?(0,$x,$c):$hp<5?($x,0,$c):($c,0,$x);
        my $m = $L - $c/2;
        return [ (map { my $q=int(($_+$m)*255+0.5); $q<0?0:($q>255?255:$q) } @r), $a ];
    }
    my %named = (white=>[255,255,255,1], black=>[0,0,0,1]);
    return [ @{$named{lc $v}} ] if $named{lc $v};
    return undef;
}
# Compatibilidad: los sitios que solo quieren el color opaco (X7, comentarios).
sub css_color { my $c = css_rgba(@_); return undef unless $c; return [ @{$c}[0..2] ] }

# Compone un color con alfa SOBRE un fondo opaco. Es lo que hace el navegador,
# y es lo que convierte «#35d07f sobre #35d07f» en el par que de verdad se ve.
sub componer {
    my ($c, $bajo) = @_;
    return undef unless $c;
    my $a = defined $c->[3] ? $c->[3] : 1;
    return [ @{$c}[0..2] ] if $a >= 0.999;
    return undef unless $bajo;          # sin fondo conocido no hay composicion
    return [ map { my $q = int($c->[$_]*$a + $bajo->[$_]*(1-$a) + 0.5);
                   $q<0?0:($q>255?255:$q) } 0..2 ];
}

# ── EL FONDO REAL DE LA PAGINA (arreglo 0.1) ────────────────────────────────
# 🔴 Antes: `$vars{'--background'} // '#ffffff'`. O sea: si la hoja no llama
#    «--background» a su fondo, se asumia BLANCO. climentmedia pinta
#    rgb(7,7,8) y site-c oklch(16% ...), asi que el gate media todo el
#    texto claro de dos webs de tema oscuro contra un blanco que no existe y
#    emitia disparates del tipo «.btn-ghost #f4f4f2 sobre #ffffff = 1.10:1».
#    Doce celdas falsas, y toda web oscura futura.
#    Ahora se lee de la regla `body` (o `html`) de la hoja que este check YA
#    parsea, con la misma %vars y el mismo resolutor. Si no se puede resolver,
#    NO se asume: el check sale NO VERIFICADO.
sub fondo_de_pagina {
    my ($sincom, $vars) = @_;
    my ($valor, $color);
    while ($sincom =~ /([^{}]*)\{([^{}]*)\}/g) {
        my ($sel, $body) = ($1, $2);
        $sel =~ s/^\s+|\s+$//g;
        next unless grep { /^(body|html)$/i } split /\s*,\s*/, $sel;
        my ($bv) = $body =~ /background(?:-color)?\s*:\s*([^;]+)/;
        next unless defined $bv;
        my $c = css_rgba($bv, $vars) or next;
        next if defined $c->[3] && $c->[3] < 0.999;   # un body translucido no dice nada
        ($valor, $color) = ($bv, [ @{$c}[0..2] ]);
        last;                                          # el primero que resuelve manda
    }
    return ($color, $valor);
}

# =============================================================================
#  3 · DESCUBRIMIENTO
# =============================================================================
my %DOM;                        # JSON del navegador, si se ha dado
if ($opt{dom} ne '') {
    if (open my $fh, '<:raw', $opt{dom}) {
        local $/; my $raw = <$fh>; close $fh;
        my $j = eval { JSON::PP->new->utf8->relaxed->decode($raw) };
        if ($j) { %DOM = %$j } else { warn "aviso: no pude leer $opt{dom} como JSON: $@\n" }
    } else { warn "aviso: no pude abrir $opt{dom}\n" }
}

my $HOME = fetch("$ROOT/");
if (!$opt{'sin-red'} && ($HOME->{code} == 0 || $HOME->{body} eq '')) {
    $NET_OK = 0;
}

# ── 3b · LA LISTA DE PAGINAS (arreglo 0.2) ──────────────────────────────────
#  🔴 Este fichero YA descargaba el sitemap —lo usa SEO-16 desde el primer dia—
#     y aun asi auditaba solo la URL tecleada. Coste medido de la diferencia en
#     shop.site-b.example: 4 segundos.
#         una URL   -> «[PASA ] SEO-02 titles unicos · DATO 1 paginas»
#         67 en el sitemap -> «[FALLO] SEO-02 · 2 title repetidos en 25 paginas»
#     Un PASA sacado de una muestra de uno no es un PASA: es que no se ha
#     mirado. La URL tecleada se queda LA PRIMERA para que el tipo de pagina,
#     el DOM y la lente cara sigan hablando de ella.
sub urls_del_sitemap {
    my @out;
    my %visto;
    my @colas = ("$ROOT/sitemap.xml");
    my $vueltas = 0;
    while (@colas && $vueltas++ < 6) {
        my $sm = fetch(shift @colas);
        next unless $sm->{code} == 200 && $sm->{body};
        my $es_indice = $sm->{body} =~ /<sitemapindex/i ? 1 : 0;
        for my $loc ($sm->{body} =~ m{<loc>\s*([^<\s]+)\s*</loc>}gi) {
            $loc =~ s/&amp;/&/g;
            next unless $loc =~ m{^https?://\Q$HOST\E(/|$)};
            if ($es_indice) { push @colas, $loc unless $visto{$loc}++; next }
            $loc =~ s{/$}{};
            push @out, $loc unless $visto{$loc}++;
        }
    }
    return @out;
}
my $SITIO_URLS;            # cuantas URLs tiene el SITIO (sitemap), si se sabe
if (!$opt{'sin-red'} && !$opt{'una-sola'} && !$DE_FICHERO && @URLS == 1 && $NET_OK) {
    my @sm = urls_del_sitemap();
    $SITIO_URLS = scalar(@sm) if @sm;
    if (@sm) {
        my %ya = map { lc($_) => 1 } @URLS;
        push @URLS, grep { !$ya{lc $_}++ } @sm;
        my $antes = scalar @URLS;
        @URLS = @URLS[0 .. ($opt{'max-urls'}-1)] if @URLS > $opt{'max-urls'};
        $EXPANDIDO = sprintf('%d del sitemap (%d disponibles, tope --max-urls %d)',
                             scalar(@URLS), scalar(@sm), $opt{'max-urls'});
        $EXPANDIDO .= " · $antes antes del tope" if $antes > @URLS;
        $TECHO_RECORTO = 1 if $antes > @URLS;
    } else {
        $EXPANDIDO = 'sin sitemap util: solo la URL tecleada (y ESO ya es un hallazgo, ver SEO-16)';
    }
} elsif ($opt{'una-sola'}) {
    $EXPANDIDO = '--una-sola: no he expandido, aunque hubiera sitemap';
    # 🔴 ARREGLO P5 · aunque NO se expanda hay que saber de cuantas paginas se
    #    ha mirado una: «1 de 1» es verdad sobre la lista y mentira sobre el
    #    sitio. El sitemap ya se descarga para SEO-16, asi que preguntarlo aqui
    #    no cuesta una peticion nueva (fetch esta memorizado).
    if (!$opt{'sin-red'} && $NET_OK) { my @sm = urls_del_sitemap(); $SITIO_URLS = scalar(@sm) if @sm }
} elsif ($DE_FICHERO) {
    $EXPANDIDO = 'lista dada a mano';
    if (!$opt{'sin-red'} && $NET_OK) { my @sm = urls_del_sitemap(); $SITIO_URLS = scalar(@sm) if @sm }
}

# ── ALCANCE · cuantas paginas mira cada lente, y CUALES ──────────────────────
#  🔴 La mitad silenciosa de la loteria del orden: no es solo que las lentes
#     miraran una pagina, es que el informe no lo decia. «[PASA] A11Y-08» leido
#     sin saber que sale de 1 de 25 paginas se lee como «el sitio pasa».
#
#  🔴 ARREGLO P5 (10-ago-2026) · esto se imprimia y ahi moria: %ALCANCE no se
#     cableaba a receipt.pl, asi que TODOS los recibos decian «ALCANCE: NO
#     DECLARADO» mientras sellaban arboles de 192 ficheros. Ahora se guarda
#     tambien la LISTA de URLs miradas por lente, que es lo que receipt.pl
#     consume, y el denominador es el SITIO —no la lista auditada—, porque
#     «25 de 25 · todas» es falso cuando el sitio tiene 40.
my %ALCANCE;
sub alcance {
    my ($lente, $urls, $de, $nota) = @_;
    my @u = ref $urls eq 'ARRAY' ? grep { defined && $_ ne '' } @$urls : ();
    $ALCANCE{$lente} = {
        urls    => \@u,
        miradas => (ref $urls eq 'ARRAY' ? scalar(@u) : ($urls // 0)),
        de      => $de,
        nota    => ($nota // ''),
    };
}

# Paginas a analizar: las que se han pasado + gracias/contacto si se han dado
my @PAGES = @URLS;
push @PAGES, "$ROOT$opt{gracias}"  if $opt{gracias}  ne '' && !grep { $_ eq "$ROOT$opt{gracias}" } @PAGES;
push @PAGES, "$ROOT$opt{contacto}" if $opt{contacto} ne '' && !grep { $_ eq "$ROOT$opt{contacto}" } @PAGES;

# ── 🔴 AQUI SE DECLARA EL RECORTE (ver la cabecera de %POR_PAGINA) ───────────
#  Se compara contra el SITIO, no contra la lista: la lista es la que se
#  recorto, asi que usarla de denominador es la propia mentira que se arregla.
#  Si no se sabe cuantas paginas tiene el sitio (sin sitemap) NO se inventa un
#  denominador: no se declara recorte, y el bloque ALCANCE ya dice, con esas
#  palabras, que no sabe que porcion es.
if (defined $SITIO_URLS && $SITIO_URLS > scalar(@PAGES)) {
    $LISTA_PARCIAL = sprintf(
        'TECHO: se han mirado %d de las %d paginas del sitio%s. Lo que no salga aqui puede estar en las otras %d',
        scalar(@PAGES), $SITIO_URLS,
        ($TECHO_RECORTO ? " (tope --max-urls $opt{'max-urls'})" : ''),
        $SITIO_URLS - scalar(@PAGES));
}

# ── 3c · UN DOCUMENTO NO SON N PAGINAS (arreglo P2 del 10-ago-2026) ─────────
#  🔴 shop.site-b.example declara 67 URLs en su sitemap y sirve ONCE documentos:
#     los 7 `loja.html?cat=*` son el MISMO fichero (md5 e55587a629cc) y los 50
#     `produto.html?sku=*` tambien (md5 39f60689ed61). La lista deduplicaba por
#     CADENA DE URL, no por documento, y eso inflaba el gate entero:
#       · SEO-02 «2 titles repetidos en 25 paginas» — un fichero contado cuatro
#         veces no son cuatro paginas que compartan title.
#       · SEO-04 acusaba una canonicalizacion BIEN HECHA: esas variantes llevan
#         canonical a loja.html, que es exactamente lo que hay que hacer.
#       · EST-01 «17 de 25» y SEO-06 «25 de 25» con el denominador inflado.
#
#  ⚠️ ESTO NO PUEDE CONVERTIRSE EN UN FALSO NEGATIVO. Que 50 URLs sirvan el
#     MISMO <title> a un rastreador sin JS SI es un defecto real — pero es UNO,
#     no 50, y su sitio natural es SEO-14 («la pagina servida no tiene
#     contenido»), que ya lo caza y sigue disparando. Aqui solo se deja de
#     contar el mismo fichero N veces.
#
#  ⚠️ NO se deduplica lo que no se ha podido leer: una URL que no responde
#     conserva su identidad, porque «no leida» no es «igual a otra».
#
#  El representante es DETERMINISTA —la URL mas corta y, a igualdad, la primera
#  alfabeticamente— para que el resultado no dependa del orden de la lista:
#  `loja.html` gana a `loja.html?cat=redondos` la sirva quien la sirva.
my @PAGES_URLS = @PAGES;     # todas las URLs pedidas, sin deduplicar
my %DOC_DE;                  # url -> md5 del documento SERVIDO
my %URLS_DE_DOC;             # md5 -> [urls que sirven ese documento]
my $DOCS_NOTA = '';
if (!$opt{'sin-red'} && $NET_OK) {
    for my $u (@PAGES_URLS) {
        my $r = fetch($u);
        next unless $r->{code} == 200 && defined $r->{body} && $r->{body} =~ /</;
        my $m = md5_hex($r->{body});
        $DOC_DE{$u} = $m;
        push @{ $URLS_DE_DOC{$m} }, $u;
    }
    my %rep;
    for my $m (keys %URLS_DE_DOC) {
        my @u = sort { length($a) <=> length($b) or $a cmp $b } @{ $URLS_DE_DOC{$m} };
        $URLS_DE_DOC{$m} = \@u;
        $rep{$m} = $u[0];
    }
    my (@docs, %puesto);
    for my $u (@PAGES_URLS) {
        my $m = $DOC_DE{$u};
        if (!defined $m) { push @docs, $u; next }      # ilegible: no se deduplica
        next if $puesto{$m}++;
        push @docs, $rep{$m};
    }
    if (@docs < @PAGES_URLS) {
        my @multi = grep { @{$URLS_DE_DOC{$_}} > 1 } sort keys %URLS_DE_DOC;
        $DOCS_NOTA = sprintf('%d URLs sirven %d documentos distintos (%d fichero%s repetido%s con otra cadena de consulta) · el denominador son DOCUMENTOS',
                             scalar(@PAGES_URLS), scalar(@docs), scalar(@multi),
                             (@multi == 1 ? '' : 's'), (@multi == 1 ? '' : 's'));
        @PAGES = @docs;
    }
}
# Cuantas URLs sirve cada documento; 1 si no se ha podido medir.
sub urls_del_doc {
    my $u = shift;
    my $m = $DOC_DE{$u};
    return [$u] unless defined $m && $URLS_DE_DOC{$m};
    return $URLS_DE_DOC{$m};
}

# Tipo por pagina: --tipo manda; si no, se infiere de la ruta (y se DICE que se
# ha inferido, porque una inferencia no es una declaracion).
# 🔴 LO QUE LA PAGINA DECLARA MANDA SOBRE LO QUE LA RUTA SUGIERE (11-ago-2026)
#    El titulo de EST-02c ya decia «(INFERIDO de la ruta, no declarado)», o sea
#    que la distincion existia en el informe y no existia en el codigo: no habia
#    forma de declarar nada salvo `--tipo`, que aplica a TODAS las paginas de la
#    corrida y por tanto no sirve en un sitio con tipos mezclados.
#
#    EL CASO QUE LO DESTAPO: climentmedia.com/agents es un INDICE de agentes, y
#    la inferencia lo llamaba «servicio» porque su ruta no esta en la lista de
#    hubs (`servicios|services|zones|zonas|catalogo|categorias`). Resultado: se
#    le exigian oferta, calificacion, proceso y objeciones. 20 de los 37 FALLO
#    de EST-02c salian de ahi.
#
#    POR QUE NO SE ARREGLA ANADIENDO `agents` A ESA LISTA: porque la lista
#    siempre estara incompleta. La siguiente web tendra /tools/, /productos/ o
#    /soluciones/ y volveremos aqui. Una lista de nombres mide MI hipotesis
#    sobre como se llaman las cosas, no lo que la pagina es.
#
#    ⚠️ Y EL RIESGO, DICHO: si una pagina puede declarar su tipo, puede declarar
#    uno mas comodo para esquivar una anatomia exigente. Por eso NO se silencia
#    nada —un hub tiene sus propios roles OBL, solo que otros— y por eso el
#    informe dice CUANTAS lo declaran y cuantas van por inferencia: una
#    declaracion queda en el recibo, a la vista, y se puede discutir. Un valor
#    que no existe NO se acepta en silencio: se avisa y se vuelve a inferir.
#  LA TABLA DE ANATOMIAS, que es tambien EL VOCABULARIO de `data-tipo`.
#  🔴 Estaba mas abajo y la lista de tipos validos se escribio a mano aqui.
#     Se quedo corta a la primera: `ficha` estaba en la tabla y NO en la lista,
#     asi que una pagina que declaraba `data-tipo="ficha"` —las 7 fichas de
#     agente de climentmedia— se rechazaba y volvia a inferirse «servicio»,
#     que es justo lo que se venia a corregir. Una sola fuente: los tipos
#     validos SON las claves de esta tabla.
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
my %TIPOS_OK   = map { $_ => 1 } keys %ANATOMIA;
my %TIPO_DECL;              # url -> 1 si el tipo salio del MARCADO
my @TIPO_RAROS;             # data-tipo con un valor que no esta en la lista
sub tipo_de {
    my $u = shift;
    return $opt{tipo} if $opt{tipo} ne '';
    my $cuerpo = fetch($u)->{body} // '';
    if ($cuerpo =~ /<(?:main|body)\b[^>]*\bdata-tipo\s*=\s*["']([^"']+)["']/i) {
        my $t = lc $1; $t =~ s/^\s+|\s+$//g;
        if ($TIPOS_OK{$t}) { $TIPO_DECL{$u} = 1; return $t }
        push @TIPO_RAROS, qq{$u (data-tipo="$t")}
            unless grep { $_ =~ /^\Q$u\E / } @TIPO_RAROS;
    }
    my ($p) = $u =~ m{^https?://[^/]+(/.*)?$}; $p //= '/';
    return 'home'     if $p eq '/' || $p eq '';
    return 'gracias'  if $p =~ m{/(gracias|merci|thank|obrigad)};
    return 'contacto' if $p =~ m{/(contact|contacto|kontakt|contactos)};
    return 'legal'    if $p =~ m{/(legal|aviso|privacidad|privacy|cookies|politica|politique|termos|terminos)};
    return 'guia'     if $p =~ m{/(learn|blog|guia|guide|articulo|post)/};
    return 'hub'      if $p =~ m{/(servicios|services|zones|zonas|catalogo|categorias)/?$};
    return 'servicio';
}

# =============================================================================
#  SENAL POSITIVA DE MONTAJE POR JS  (la que usa SEO-14)
# =============================================================================
# 🔴 POR QUE NO VALE MEDIR LA LONGITUD (11-ago-2026).
#    SEO-14 disparaba con `length($txt) < 200 || @h1 == 0`. Eso NO mide su
#    propio titulo: mide si la pagina es CORTA. Medido sobre el HTML SERVIDO:
#
#      site-a /merci        171 car.,  1 h1, sin marcador ....... gracias, LEGITIMA
#      site-b loja.html    0 car.,  0 h1, class="skeleton" ... la tienda, DEFECTO
#      site-b produto      0 car.,  0 h1, class="skeleton" ... 52 SKU,    DEFECTO
#      site-b home     1.556 car.,  1 h1, #catGrid vacio ..... enriquece,  LEGITIMA
#      site-d roto    1.435 car.,  0 h1, sin marcador ....... le falta el h1
#
#    Entre 0 y 171 no hay NADA: el corte no es un umbral que haya que afinar,
#    es un abismo. Y el `@h1 == 0` era el defecto de SEO-09 («pagina sin h1»,
#    misma lista de URLs, linea de arriba) acusado por segunda vez bajo un
#    titulo que no es el suyo: el arbol roto de la bateria tiene 1.435
#    caracteres de contenido servido y se le decia que «solo existe con JS».
#
# 🔴 POR QUE TAMPOCO VALE EXIMIR POR noindex NI POR TIPO DE PAGINA.
#    La tienda de site-b esta ENTERA en noindex a proposito: eximir por
#    noindex la deja sin medir justo donde vive el defecto, y el dia que se
#    quite el noindex la tienda es invisible. Y una exencion por tipo
#    («gracias», «legal») se rodea renombrando la pagina. Por eso la senal es
#    POSITIVA: hay que ENSENAR el montaje por JS, no alegar una categoria.
#
# Devuelve ($esqueleto, @senal).
#    $esqueleto SOLO lo enciende un marcador de carga (skeleton / aria-busy).
#    El contenedor vacio NUNCA decide por si solo: solo pone nombre a una
#    region que YA se ha medido vacia. La home de site-b tiene dos (#catGrid,
#    #featGrid, los dos nombrados por su JS) y tiene que seguir pasando.
sub senal_montaje_js {
    my ($main, $h, $hay_main) = @_;
    $main //= ''; $h //= '';
    my $donde = $hay_main ? '<main>' : 'la region de contenido';
    my ($esq, @s) = (0);

    # 1 · marcador de carga: el propio marcado dice que eso no es la pagina
    if ($main =~ /\bclass\s*=\s*["'][^"']*\b(skeleton|esqueleto|placeholder|shimmer|spinner|is-loading|loading)\b/i) {
        $esq = 1; push @s, "marcador de carga class=\"$1\" donde va el contenido";
    }
    if ($main =~ /\baria-busy\s*=\s*["']true["']/i) {
        $esq = 1; push @s, 'aria-busy="true": el marcado declara que aun no hay contenido';
    }

    # 2 · contenedor VACIO que un <script> de la pagina rellena
    my $js  = join "\n", ($h =~ m{<script\b[^>]*>(.*?)</script>}gsi);
    my $mod = ($h =~ /<script[^>]*\btype\s*=\s*["']module["']/i) ? 1 : 0;
    my %visto;
    while ($main =~ m{<(div|section|article|ul|span)\b([^>]*)>(.*?)</\1>}gsi) {
        my ($at, $dentro) = ($2, $3);
        my ($id) = $at =~ /(?:^|\s)id\s*=\s*["']([^"']+)["']/i;
        next unless defined $id && $id ne '' && !$visto{$id}++;
        my $t = tag_text($dentro); $t =~ s/^\s+|\s+$//g;
        next if length $t;
        if    ($js =~ /\Q$id\E/) { push @s, "contenedor vacio #$id dentro de $donde, y un <script> de la pagina lo nombra" }
        elsif ($mod)             { push @s, "contenedor vacio #$id dentro de $donde, y la pagina carga un <script type=\"module\">" }
    }
    return ($esq, @s);
}

# Por debajo de esto la region servida no trae ni una frase. Se elige por la
# medida de arriba (0 / 171 / 1.435 / 1.556), no por gusto: no hay ninguna
# pagina cerca de 40, asi que moverlo entre 1 y ~150 no cambia ningun veredicto.
my $VACIA_CAR = 40;

# =============================================================================
#  4 · LENTE 1 · SEO
#     Procedencia: 03-contenido-y-seo.md · web-page-standard SKILL.md ·
#                  09-tipos-de-pagina.md · G4 · G5 · G10 · X3 · X4
# =============================================================================
sub lente_seo {
    unless ($NET_OK) {
        nv(lente=>'SEO', id=>'SEO-00', titulo=>'la lente entera',
           umbral=>'requiere red', proc=>'qa-maestro',
           hacer=>"la descarga de $ROOT/ ha fallado: no hay medicion, y eso NO es un aprobado");
        return;
    }
    my (@titles, %ogimg, @sin_ogalt, @sin_twimg, @sin_can, @sin_desc, @sin_h1, @multi_h1,
        @img_sin_alt, @sin_jsonld, @sin_bread, @solo_js, @desc_corta, @title_largo);
    alcance('SEO', [@PAGES], undef, 'SEO-01..14 sobre todas las de la lista · SEO-15/16/17 son del sitio');

    for my $u (@PAGES) {
        my $r = fetch($u);
        next unless $r->{code} == 200 && $r->{body} =~ /</;
        my $h = sin_com($r->{body});
        my $tipo = tipo_de($u);

        my ($t) = $h =~ m{<title[^>]*>(.*?)</title>}si;
        $t //= ''; $t =~ s/\s+/ /g; $t =~ s/^\s+|\s+$//g;
        push @titles, [$u, $t];
        my $lt = largo_visible($t);
        push @title_largo, "$u ($lt)" if $lt > 65 || ($lt < 15 && $t ne '');

        my $d = meta_of($h, 'description');
        if (!defined $d || $d eq '') { push @sin_desc, $u }
        elsif (largo_visible($d) < 50 || largo_visible($d) > 165) { push @desc_corta, "$u (".largo_visible($d).")" }

        # SEO-04 · canonical
        # 🔴 ARREGLO P2 (10-ago-2026) · esto castigaba una canonicalizacion BIEN
        #    HECHA. `loja.html?cat=redondos` sirve el MISMO documento que
        #    `loja.html` y declara canonical a `loja.html`: eso es exactamente lo
        #    que hay que hacer con una variante de filtro, y salia como FALLO
        #    «canonical no apunta a si misma» siete veces seguidas. La regla no
        #    es «canonical == mi URL», es «canonical == el documento que sirvo»:
        #    si el destino devuelve 200 y es el MISMO fichero byte a byte, la
        #    canonicalizacion esta bien.
        #    ⚠️ Lo que NO se perdona sigue sin perdonarse: sin canonical (los
        #    produto.html?sku=* de site-b) o apuntando a OTRO documento.
        my ($can) = $h =~ /<link[^>]*rel=["']canonical["'][^>]*>/i ? ($h =~ /<link[^>]*rel=["']canonical["'][^>]*href=["']([^"']+)["']/i)[0] : undef;
        $can //= ($h =~ /<link[^>]*href=["']([^"']+)["'][^>]*rel=["']canonical["']/i)[0];
        if (!defined $can) { push @sin_can, "$u (sin canonical)" }
        else {
            my ($a,$b) = ($can, $r->{url}); s{/$}{} for ($a,$b);
            if (lc($a) ne lc($b)) {
                my $mio    = md5_hex($h);
                my $canabs = abs_url($can, $r->{url}) // $can;
                my $rc     = is_internal($canabs) ? fetch($canabs) : undef;
                my $mismo  = ($rc && $rc->{code} == 200 && defined $rc->{body}
                              && md5_hex($rc->{body}) eq $mio) ? 1 : 0;
                push @sin_can, "$u -> $can" unless $mismo;
            }
        }

        my $oi = meta_of($h,'og:image');
        $ogimg{$oi}++ if defined $oi && $oi ne '';
        push @sin_ogalt, $u unless defined meta_of($h,'og:image:alt');
        push @sin_twimg, $u unless defined(meta_of($h,'twitter:image')) || defined(meta_of($h,'twitter:card'));

        my @h1 = $h =~ /<h1\b[^>]*>/gi;
        push @sin_h1,   $u if @h1 == 0;
        push @multi_h1, $u." (".scalar(@h1).")" if @h1 > 1;

        # X3 · el check de `alt` de 03 §2 esta ROTO: cuenta alt="" como ausencia.
        # alt="" es una imagen DECORATIVA correctamente marcada. Falla solo si
        # NO existe el atributo.
        my $n_noalt = 0;
        for my $img ($h =~ /(<img\b[^>]*>)/gi) { $n_noalt++ unless defined attr($img,'alt') }
        push @img_sin_alt, "$u ($n_noalt)" if $n_noalt;

        my $ld = join "\n", ($h =~ m{<script[^>]*application/ld\+json[^>]*>(.*?)</script>}gsi);
        # 🔴 19-ago-2026 · SEO-11 y SEO-13 ACUSABAN A PAGINAS `noindex`.
        # Su propio umbral dice «en cada INDEXABLE», y la de gracias de site-c
        # -que es noindex a proposito, porque es donde se mide la conversion-
        # salia como FALLO. Estuve a punto de anadirle JSON-LD a una pagina que
        # Google no va a mirar nunca. Un dato estructurado en una pagina fuera
        # del indice es peso muerto: la regla ya lo decia y el check no.
        my $noindex = $h =~ /<meta[^>]+name=["']robots["'][^>]*content=["'][^"']*noindex/i;
        push @sin_jsonld, $u if $ld !~ /\S/ && !$noindex;
        push @sin_bread,  $u if $tipo ne 'home' && $ld !~ /BreadcrumbList/ && !$noindex;

        # G10 · el HTML SERVIDO frente al DOM. produto.html de site-b pesa 1.503
        # bytes en vivo: mismo <title> para 52 SKU, sin h1, sin JSON-LD. El JS lo
        # arregla — y los scrapers de WhatsApp y LinkedIn no ejecutan JS.
        #
        # 🔴 ARREGLO P2 · aqui es donde vive de verdad el defecto de site-b, y
        #    por eso SEO-02 puede dejar de contarlo 50 veces sin que se pierda:
        #    se dice CUANTAS URLs sirve este mismo documento. «1 documento sirve
        #    50 URLs con el mismo title y su contenido lo monta JS» es el
        #    hallazgo entero, en una linea, sin inflar ningun denominador.
        my ($main) = $h =~ m{<main\b[^>]*>(.*?)</main>}si;
        my $hay_main = defined $main ? 1 : 0;
        $main //= $h;
        my $txt = tag_text($main); $txt =~ s/^\s+|\s+$//g;
        my ($esqueleto, @senal) = senal_montaje_js($main, $h, $hay_main);
        # DOS caminos, y los dos exigen una senal POSITIVA, no una longitud:
        #  (1) la region servida esta VACIA -> no hay pagina que rastrear.
        #  (2) trae un ESQUELETO y ni siquiera su h1 -> la cascara no es la
        #      pagina. Este camino existe para que no se rodee el (1) metiendo
        #      un migado o un parrafo de relleno alrededor del esqueleto.
        my $porque = '';
        if (length($txt) < $VACIA_CAR) {
            $porque = @senal
                ? 'la region de contenido servida esta VACIA · '.join(' · ', @senal)
                : 'la region de contenido servida esta VACIA · sin senal de montaje en el HTML: no puedo nombrar la causa, pero servido no hay nada';
        } elsif ($esqueleto && @h1 == 0) {
            $porque = 'sirve un ESQUELETO en lugar de la pagina · '.join(' · ', @senal);
        }
        if ($porque ne '') {
            my $nurls = scalar @{ urls_del_doc($u) };
            push @solo_js, "$u (".length($txt)." car. de texto, ".scalar(@h1)." h1) "
                         . $porque
                         . ($nurls > 1 ? ", y este MISMO documento se sirve en $nurls URLs con el mismo title" : '');
        }
    }

    # --- veredictos ---
    # 🔴 ARREGLO P2 · @PAGES ya viene deduplicado por DOCUMENTO, asi que aqui
    #    «paginas» son ficheros distintos y no cadenas de URL distintas. Antes,
    #    site-b daba «2 title repetidos en 25 paginas» contando un fichero
    #    cuatro veces. Lo que SI es un defecto —50 URLs sirviendo el mismo
    #    title— no desaparece: lo dice SEO-14, y una vez.
    my %seen_t; my @dups;
    for my $p (@titles) { push @dups, $p->[1] if $seen_t{lc $p->[1]}++ && $p->[1] ne '' }
    @dups = do { my %u; grep { !$u{$_}++ } @dups };
    @dups ? fallo(lente=>'SEO', id=>'SEO-02', titulo=>'titles duplicados',
                  donde=>join(' · ', map { "\"$_\"" } @dups[0..($#dups>2?2:$#dups)]),
                  ev=>[map { "\"$_\"" } @dups],
                  dato=>scalar(@dups)." title repetidos en ".scalar(@titles)." documentos distintos",
                  umbral=>'0 duplicados · se cuentan DOCUMENTOS (md5 del HTML servido), no cadenas de URL',
                  proc=>'qa-final.sh §2 · 03-contenido-y-seo §2 · arreglo P2: un fichero servido en 8 URLs no son 8 paginas con el mismo title (ver SEO-14)',
                  hacer=>'cada pagina responde a una pregunta distinta: si dos comparten title, o se fusionan o una lleva noindex (09 §5, canibalizacion)')
          : pasa(lente=>'SEO', id=>'SEO-02', titulo=>'titles unicos', dato=>scalar(@titles).' documentos distintos');

    @title_largo ? aviso(lente=>'SEO', id=>'SEO-01', titulo=>'longitud del title fuera de 15-65',
                         donde=>join(' · ', @title_largo[0..($#title_largo>2?2:$#title_largo)]),
                         ev=>[@title_largo],
                         umbral=>'15-65 caracteres', proc=>'03-contenido-y-seo §2',
                         hacer=>'recortar hasta que quepa entero en el resultado de busqueda')
                : pasa(lente=>'SEO', id=>'SEO-01', titulo=>'title presente y en rango');

    @sin_desc ? fallo(lente=>'SEO', id=>'SEO-03', titulo=>'sin meta description',
                      donde=>join(' · ', @sin_desc[0..($#sin_desc>2?2:$#sin_desc)]),
                      ev=>[@sin_desc],
                      dato=>scalar(@sin_desc).' de '.scalar(@PAGES),
                      umbral=>'100% de las indexables', proc=>'03-contenido-y-seo §2',
                      hacer=>'una frase que diga lo que hay dentro y por que abrirla; no un resumen del title')
              : pasa(lente=>'SEO', id=>'SEO-03', titulo=>'meta description en todas');
    @desc_corta and aviso(lente=>'SEO', id=>'SEO-03b', titulo=>'meta description fuera de 50-165',
                          donde=>join(' · ', @desc_corta[0..($#desc_corta>2?2:$#desc_corta)]),
                          ev=>[@desc_corta],
                          umbral=>'50-165 caracteres', proc=>'03-contenido-y-seo §2',
                          hacer=>'si sobra, Google la corta; si falta, la reescribe el');

    @sin_can ? fallo(lente=>'SEO', id=>'SEO-04', titulo=>'canonical ausente o no apunta a si misma',
                     donde=>join(' · ', @sin_can[0..($#sin_can>2?2:$#sin_can)]),
                     ev=>[@sin_can],
                     umbral=>'canonical == URL final', proc=>'qa-final.sh §2',
                     hacer=>'canonical absoluta a la URL final servida (ojo con la barra final y con el 301)')
             : pasa(lente=>'SEO', id=>'SEO-04', titulo=>'canonical apunta a si misma');

    # G4 · el check existe y mide la dimension equivocada: `grep -q og:image`
    # mide PRESENCIA, no utilidad. Sale [ok] en sitios al 0% de og:image:alt.
    @sin_ogalt ? fallo(lente=>'SEO', id=>'SEO-06', titulo=>'og:image:alt ausente',
                       donde=>join(' · ', @sin_ogalt[0..($#sin_ogalt>2?2:$#sin_ogalt)]),
                       ev=>[@sin_ogalt],
                       dato=>scalar(@sin_ogalt).' de '.scalar(@PAGES),
                       umbral=>'100% · 🔴 OBLIGATORIO desde el 5-ago-2026',
                       proc=>'web-page-standard SKILL.md:80 · G4 (4 de 5 webs al 0%, incluida donde vive el estandar)',
                       hacer=>'<meta property="og:image:alt" content="lo que se VE en la imagen"> en cada pagina')
               : pasa(lente=>'SEO', id=>'SEO-06', titulo=>'og:image:alt en todas');

    @sin_twimg ? aviso(lente=>'SEO', id=>'SEO-07', titulo=>'sin twitter:image ni twitter:card',
                       donde=>join(' · ', @sin_twimg[0..($#sin_twimg>2?2:$#sin_twimg)]),
                       ev=>[@sin_twimg],
                       umbral=>'twitter:card + twitter:image', proc=>'G4 (0% en 3 de 5 webs)',
                       hacer=>'anadir twitter:card=summary_large_image y twitter:image (puede reusar la og:image)')
               : pasa(lente=>'SEO', id=>'SEO-07', titulo=>'tarjeta de Twitter/X presente');

    my $n_ogimg = scalar keys %ogimg;
    if (@PAGES >= 5 && $n_ogimg <= 1) {
        fallo(lente=>'SEO', id=>'SEO-08', titulo=>'una sola og:image para todo el sitio',
              dato=>"$n_ogimg imagen distinta para ".scalar(@PAGES).' paginas',
              umbral=>'og:image propia por pagina (o por tipo, declarado)',
              proc=>'G4 · site-a 1, site-b 1, site-c 1 · climentmedia 28 y site-d 25',
              hacer=>'la misma imagen en todas es la misma tarjeta al compartir cualquiera: se pierde el clic en el unico canal donde el titular no manda');
    } elsif (@PAGES >= 5) {
        pasa(lente=>'SEO', id=>'SEO-08', titulo=>'og:image variada', dato=>"$n_ogimg distintas");
    }

    @sin_h1 ? fallo(lente=>'SEO', id=>'SEO-09', titulo=>'pagina sin h1',
                    donde=>join(' · ', @sin_h1[0..($#sin_h1>2?2:$#sin_h1)]),
                    ev=>[@sin_h1],
                    umbral=>'exactamente 1 h1', proc=>'09-tipos-de-pagina §1',
                    hacer=>'el h1 es la promesa de la pagina: sin el, ni el buscador ni el lector saben de que va')
            : pasa(lente=>'SEO', id=>'SEO-09', titulo=>'h1 presente');
    @multi_h1 and fallo(lente=>'SEO', id=>'SEO-09b', titulo=>'mas de un h1',
                        donde=>join(' · ', @multi_h1), umbral=>'exactamente 1',
                        proc=>'09-tipos-de-pagina §1', hacer=>'degradar los sobrantes a h2');

    @img_sin_alt ? fallo(lente=>'SEO', id=>'SEO-10', titulo=>'<img> SIN atributo alt',
                         donde=>join(' · ', @img_sin_alt[0..($#img_sin_alt>2?2:$#img_sin_alt)]),
                         ev=>[@img_sin_alt],
                         umbral=>'0 imagenes sin el ATRIBUTO. alt="" es correcto: marca decorativa',
                         proc=>'X3 · el check de 03 §2 esta mal escrito y cuenta alt="" como ausencia',
                         hacer=>'alt descriptivo si aporta; alt="" si es decoracion. Lo que no vale es no ponerlo')
                 : pasa(lente=>'SEO', id=>'SEO-10', titulo=>'todas las <img> llevan alt (alt="" cuenta como correcto)');

    @sin_jsonld ? fallo(lente=>'SEO', id=>'SEO-11', titulo=>'sin JSON-LD',
                        donde=>join(' · ', @sin_jsonld[0..($#sin_jsonld>2?2:$#sin_jsonld)]),
                        ev=>[@sin_jsonld],
                        umbral=>'JSON-LD coherente con el tipo en cada indexable',
                        proc=>'web-page-standard §1 · mejor modelo: site-d 100% en 41 paginas',
                        hacer=>'schema por tipo, no uno generico: site-c, mismo modelo de negocio que site-d, tiene 0 Organization, 0 LocalBusiness y 0 breadcrumb')
                : pasa(lente=>'SEO', id=>'SEO-11', titulo=>'JSON-LD presente');

    @sin_bread and aviso(lente=>'SEO', id=>'SEO-13', titulo=>'sin BreadcrumbList',
                         donde=>join(' · ', @sin_bread[0..($#sin_bread>2?2:$#sin_bread)]),
                         ev=>[@sin_bread],
                         umbral=>'todas menos la home', proc=>'site-d 88% · G5',
                         hacer=>'BreadcrumbList en el JSON-LD y la miga visible: es como el buscador entiende la jerarquia');

    # G10
    @solo_js ? fallo(lente=>'SEO', id=>'SEO-14', titulo=>'la pagina SERVIDA no tiene contenido (solo existe si se ejecuta JS)',
                     donde=>join(' · ', @solo_js[0..($#solo_js>2?2:$#solo_js)]),
                     ev=>[@solo_js],
                     umbral=>'la region de contenido del HTML SERVIDO trae contenido (>=40 car.) O, si trae un esqueleto, trae al menos su h1 · NO es un umbral de longitud: una pagina CORTA con su h1 y sin senal de montaje PASA (site-a /merci: 171 car., 1 h1) · el h1 ausente es SEO-09, no este',
                     proc=>'G10 · 09 §2 marca «solo con JS» PROHIBIDO en la ficha de producto',
                     hacer=>'title, canonical, h1, og y JSON-LD tienen que estar en el HTML servido: los scrapers de WhatsApp y LinkedIn no ejecutan JS')
             : pasa(lente=>'SEO', id=>'SEO-14', titulo=>'el HTML servido ya trae la pagina');

    # robots / sitemap
    my $rb = fetch("$ROOT/robots.txt");
    if ($rb->{code} != 200) {
        fallo(lente=>'SEO', id=>'SEO-15', titulo=>'robots.txt no responde 200', dato=>"HTTP $rb->{code}",
              umbral=>'200', proc=>'qa-final.sh §1', hacer=>'publicar robots.txt con el sitemap declarado');
    } elsif ($rb->{body} =~ /^\s*Disallow:\s*\/\s*$/mi && $rb->{body} !~ /Allow:/i) {
        fallo(lente=>'SEO', id=>'SEO-15', titulo=>'robots.txt bloquea el sitio entero',
              umbral=>'sin Disallow: /', proc=>'qa-final.sh §1', hacer=>'quitar el Disallow: / (tipico resto de staging)');
    } else {
        pasa(lente=>'SEO', id=>'SEO-15', titulo=>'robots.txt correcto');
    }
    my $sm = fetch("$ROOT/sitemap.xml");
    my @locs = $sm->{body} =~ m{<loc>\s*([^<\s]+)\s*</loc>}gi;
    if ($sm->{code} != 200 || !@locs) {
        fallo(lente=>'SEO', id=>'SEO-16', titulo=>'sitemap.xml ausente o vacio', dato=>"HTTP $sm->{code}, ".scalar(@locs).' URLs',
              umbral=>'200 y >=1 <loc>', proc=>'qa-final.sh §1', hacer=>'generarlo desde la spec, no a mano');
    } else {
        my %in = map { my $x=$_; $x =~ s{/$}{}; (lc $x => 1) } @locs;
        # ⚠️ Contra lo que se PIDIO, no contra la lista expandida: la expansion
        #    SALE del sitemap, asi que compararla consigo misma daria PASA
        #    siempre y este check dejaria de medir nada.
        my @fuera = grep { my $x=$_; $x =~ s{/$}{}; !$in{lc $x} } @URLS_PEDIDAS;
        @fuera ? aviso(lente=>'SEO', id=>'SEO-16', titulo=>'la pagina analizada NO esta en el sitemap',
                       donde=>join(' · ', @fuera), dato=>scalar(@locs).' URLs en el sitemap',
                       umbral=>'toda indexable en el sitemap', proc=>'qa-final.sh §1',
                       hacer=>'o entra en el sitemap, o lleva noindex a proposito. Las dos cosas se declaran; lo que no vale es el limbo')
                : pasa(lente=>'SEO', id=>'SEO-16', titulo=>'sitemap.xml con la pagina dentro', dato=>scalar(@locs).' URLs');
    }

    # PC14 · hreflang: 0 de 148 paginas. Una sola mencion en toda la skill, y es
    # la exclusion razonada de climentmedia. En las otras cuatro no se planteo.
    my $any_hreflang = 0;
    for my $u (@PAGES) { my $r = fetch($u); $any_hreflang = 1 if $r->{body} && $r->{body} =~ /hreflang=/i }
    nv(lente=>'SEO', id=>'SEO-17', titulo=>'hreflang / cobertura de idiomas',
       dato=>($any_hreflang ? 'hay etiquetas hreflang, sin comprobar reciprocidad' : 'ninguna etiqueta hreflang'),
       umbral=>'decidir y DECLARAR: o el sitio es monolingue a proposito, o hay hreflang reciproco',
       proc=>'PC14 · 0 de 148 paginas nuestras lo ejercitan · site-a.example sirve Belgica solo en frances',
       hacer=>'escribir la decision en el CLAUDE.md del proyecto. Un sitio belga solo en frances es una decision, pero hoy no consta que se tomara');
}

# =============================================================================
#  5-bis · `unicode-range`  ·  QUE FUENTES BAJA EL NAVEGADOR DE VERDAD
# =============================================================================
#  🔴 POR QUE (arreglo 11-ago-2026, verificado a mano antes de tocar nada).
#     REN-04 sumaba los .woff2 DECLARADOS. site-a declara 4 (254 KB) y
#     Chrome baja 2 (112,9 KB): los otros dos son los cortes `latin-ext`, y el
#     navegador NO PIDE un fichero cuyo `unicode-range` no interseca con lo que
#     la pagina escribe. Medido aparte del gate sobre el arbol entero de site-a:
#     25 ficheros, 37 codepoints no-ASCII, **0 en latin-ext**. El sitio esta en
#     frances, y `œ` (U+0153) va dentro del corte `latin`, no del `latin-ext`.
#     Sumar los 4 no es un umbral estricto: es medir mal.
#
#  ⚠️ ESTO NO ES UN DESCUENTO GENERAL. Solo se descuenta un fichero cuando se
#     cumplen las TRES: tiene `unicode-range`, NO va en un `<link rel=preload>`
#     —eso el navegador lo baja si o si— y NINGUNO de sus rangos toca un
#     caracter de la muestra. Una fuente SIN `unicode-range` sigue sumando
#     entera, y una con un rango que el sitio SI usa tambien.
#
#  ⚠️ FALLA HACIA EL LADO CARO. Si un token del rango no se entiende, si no se
#     ha podido leer el texto, o si aparece una entidad HTML con nombre que no
#     esta en la tabla, NO se descuenta nada: el juego de caracteres se declara
#     incierto y se cuentan los ficheros como antes. Descontar de menos infla el
#     presupuesto; descontar de mas absuelve a un sitio pesado.
#
#  ⚠️ Esto solo toca REN-04. REN-01 (peso de pagina) sigue sumando lo DECLARADO,
#     que es la direccion conservadora para un presupuesto de bytes; por eso el
#     informe puede decir «font 254 KB» en REN-01 y «2 ficheros · 113 KB» en
#     REN-04, y por eso REN-04 escribe su metodo dentro del DATO.

# Entidades con nombre que se saben traducir. Lo que NO este aqui vuelve
# `incierto` y desactiva el descuento: es preferible a adivinar un codepoint.
my %ENT_CP = (
    nbsp=>0xA0, amp=>38, lt=>60, gt=>62, quot=>34, apos=>39, iexcl=>0xA1, cent=>0xA2,
    pound=>0xA3, curren=>0xA4, yen=>0xA5, sect=>0xA7, uml=>0xA8, copy=>0xA9, ordf=>0xAA,
    laquo=>0xAB, not=>0xAC, shy=>0xAD, reg=>0xAE, macr=>0xAF, deg=>0xB0, plusmn=>0xB1,
    sup2=>0xB2, sup3=>0xB3, acute=>0xB4, micro=>0xB5, para=>0xB6, middot=>0xB7,
    cedil=>0xB8, sup1=>0xB9, ordm=>0xBA, raquo=>0xBB, frac14=>0xBC, frac12=>0xBD,
    frac34=>0xBE, iquest=>0xBF, Agrave=>0xC0, Aacute=>0xC1, Acirc=>0xC2, Atilde=>0xC3,
    Auml=>0xC4, Aring=>0xC5, AElig=>0xC6, Ccedil=>0xC7, Egrave=>0xC8, Eacute=>0xC9,
    Ecirc=>0xCA, Euml=>0xCB, Igrave=>0xCC, Iacute=>0xCD, Icirc=>0xCE, Iuml=>0xCF,
    ETH=>0xD0, Ntilde=>0xD1, Ograve=>0xD2, Oacute=>0xD3, Ocirc=>0xD4, Otilde=>0xD5,
    Ouml=>0xD6, times=>0xD7, Oslash=>0xD8, Ugrave=>0xD9, Uacute=>0xDA, Ucirc=>0xDB,
    Uuml=>0xDC, Yacute=>0xDD, THORN=>0xDE, szlig=>0xDF, agrave=>0xE0, aacute=>0xE1,
    acirc=>0xE2, atilde=>0xE3, auml=>0xE4, aring=>0xE5, aelig=>0xE6, ccedil=>0xE7,
    egrave=>0xE8, eacute=>0xE9, ecirc=>0xEA, euml=>0xEB, igrave=>0xEC, iacute=>0xED,
    icirc=>0xEE, iuml=>0xEF, eth=>0xF0, ntilde=>0xF1, ograve=>0xF2, oacute=>0xF3,
    ocirc=>0xF4, otilde=>0xF5, ouml=>0xF6, divide=>0xF7, oslash=>0xF8, ugrave=>0xF9,
    uacute=>0xFA, ucirc=>0xFB, uuml=>0xFC, yacute=>0xFD, thorn=>0xFE, yuml=>0xFF,
    OElig=>0x152, oelig=>0x153, Scaron=>0x160, scaron=>0x161, Yuml=>0x178, fnof=>0x192,
    circ=>0x2C6, tilde=>0x2DC, ensp=>0x2002, emsp=>0x2003, thinsp=>0x2009,
    ndash=>0x2013, mdash=>0x2014, lsquo=>0x2018, rsquo=>0x2019, sbquo=>0x201A,
    ldquo=>0x201C, rdquo=>0x201D, bdquo=>0x201E, dagger=>0x2020, Dagger=>0x2021,
    bull=>0x2022, hellip=>0x2026, permil=>0x2030, lsaquo=>0x2039, rsaquo=>0x203A,
    euro=>0x20AC, trade=>0x2122, larr=>0x2190, uarr=>0x2191, rarr=>0x2192,
    darr=>0x2193, harr=>0x2194, minus=>0x2212, nbsp4=>0xA0,
);

# cps_del_texto(\@cuerpos) -> (\%codepoints, $incierto)
sub cps_del_texto {
    my ($cuerpos) = @_;
    my (%cps, $incierto);
    for my $raw (@$cuerpos) {
        next unless defined $raw && length $raw;
        # 🔴 EL ORDEN IMPORTA, Y ME MORDIO AL ESCRIBIRLO: primero DECODIFICAR
        #    los bytes, y solo despues traducir las entidades. Al reves, meter
        #    un chr(0x2019) dentro de una cadena de BYTES la asciende a
        #    caracteres a mitad, `decode` revienta, y el resultado era que TODOS
        #    los sitios salian con el juego «INCIERTO» y no se descontaba nunca
        #    nada. El fallo no daba error: daba el numero de antes.
        my $t = eval { Encode::decode('UTF-8', $raw, Encode::FB_CROAK()) };
        # Un cuerpo que no es UTF-8 valido no se puede recorrer por caracteres:
        # se declara incierto en vez de contar bytes sueltos como codepoints.
        if (!defined $t) { $incierto ||= 'un cuerpo no decodifica como UTF-8'; next }
        $t =~ s/&#x([0-9a-f]+);/chr(hex($1))/gie;
        $t =~ s/&#(\d+);/chr($1)/ge;
        $t =~ s/&([a-zA-Z][a-zA-Z0-9]{1,31});/
                  exists $ENT_CP{$1} ? chr($ENT_CP{$1}) : do { $incierto ||= "entidad &$1; sin traducir"; '' }
               /ge;
        $cps{ord $_} = 1 for split //, $t;
    }
    return (\%cps, $incierto);
}

# ur_toca($cadena_unicode_range, \%cps) -> 1 si el navegador PEDIRIA el fichero
sub ur_toca {
    my ($ur, $cps) = @_;
    my $tokens = 0;
    for my $tok (split /\s*,\s*/, ($ur // '')) {
        $tok =~ s/^\s+|\s+$//g;
        next if $tok eq '';
        return 1 unless $tok =~ s/^[uU]\+//;          # token que no entiendo -> cuenta
        my ($lo, $hi);
        if    ($tok =~ /^([0-9a-fA-F]+)-([0-9a-fA-F]+)$/) { ($lo,$hi) = (hex($1), hex($2)) }
        elsif ($tok =~ /^([0-9a-fA-F]*)(\?+)$/)           { my ($b,$q) = ($1,$2);
                                                            $lo = hex($b.('0' x length $q));
                                                            $hi = hex($b.('F' x length $q)) }
        elsif ($tok =~ /^([0-9a-fA-F]+)$/)                { $lo = $hi = hex($1) }
        else                                              { return 1 }
        $tokens++;
        for my $cp (keys %$cps) { return 1 if $cp >= $lo && $cp <= $hi }
    }
    return $tokens ? 0 : 1;    # sin un solo token valido no se descuenta nada
}

# =============================================================================
#  5 · LENTE 2 · RENDIMIENTO
#     Procedencia: G3 · PC2 · PC12 · PC17 · 13-rendimiento.md (propuesto)
#     🔴 Los umbrales NO son estandar de industria: son el liston que nuestra
#        PROPIA mejor web ya alcanza (site-c: 0,037-0,041 B/px y 2 ficheros de
#        fuente / 45 KB). Eso es defendible y comprobable; un numero inventado no.
# =============================================================================
sub lente_rendimiento {
    unless ($NET_OK) {
        nv(lente=>'RENDIMIENTO', id=>'REN-00', titulo=>'la lente entera',
           umbral=>'requiere red', proc=>'qa-maestro', hacer=>'sin descarga no hay peso que medir');
        return;
    }
    # 🔴 ARREGLO 0.3 · esta lente tambien empezaba con `my $u = $URLS[0]`.
    #    Pero es la CARA: descarga cada recurso del primer render. Multiplicar
    #    por 25 lo que ya tarda 13 s no es un arreglo, es otro problema. Se
    #    MUESTREA —y se dice el tamano de la muestra, que es la mitad que
    #    faltaba: un informe que no declara su alcance se lee como si lo
    #    cubriera todo.
    # 🔴 ARREGLO P1b (10-ago-2026) · `--muestra 3` NO cogia una muestra: cogia
    #    LAS TRES PRIMERAS de la lista. En un sitio expandido por sitemap eso es
    #    «la home y sus dos vecinas de fichero», que suelen ser la misma plantilla
    #    —y en site-b, literalmente el mismo documento—. Una muestra sesgada al
    #    principio de la lista mide la home tres veces y llama a eso cobertura.
    #    Ahora se reparte por la lista entera, de forma DETERMINISTA (mismo
    #    resultado en cada corrida) y conservando SIEMPRE la primera, que es la
    #    URL que se ha tecleado y de la que hablan el tipo, el --dom y REN-06.
    my $u = $URLS[0];
    my $tope = int($opt{muestra} || 3); $tope = 1 if $tope < 1;
    my @muestra;
    if (@PAGES <= $tope) {
        @muestra = @PAGES;
    } else {
        my %ya;
        for my $i (0 .. $tope-1) {
            my $j = $tope == 1 ? 0 : int($i * ($#PAGES) / ($tope - 1) + 0.5);
            push @muestra, $PAGES[$j] unless $ya{$j}++;
        }
    }
    alcance('RENDIMIENTO', [@muestra], undef,
            'MUESTRA repartida por la lista (descarga cada recurso de cada pagina) · --muestra N para ampliar · REN-01 y REN-06 son por pagina');

# 🔴 EL CASO HONESTO DE «NO PUEDO ENUMERAR MI EVIDENCIA COMPLETA».
#    Esta lente descarga cada recurso de cada pagina, asi que mira una MUESTRA
#    (3 por defecto) y no el sitio entero. Sus hallazgos son ciertos, pero su
#    AUSENCIA no prueba nada del resto: aceptar «REN-02 · 4 imagenes pesadas»
#    medido sobre 3 paginas de 25 NO es aceptar que el sitio no tenga mas.
#    Por eso la huella de estos checks sale con EVP en vez de EV, y el recibo
#    lo dice con todas las letras. Una aceptacion que no puede garantizar su
#    alcance no puede presentarse como si lo hiciera.
#    Si se mide entero (--muestra >= paginas), esto queda vacio y vuelve a ser
#    una aceptacion normal — con OTRA huella, que es lo correcto: es otra
#    garantia, y hay que volver a decidirla con el dato bueno.
#    🔴 Y EL DENOMINADOR ES EL SITIO, NO LA LISTA (11-ago-2026). Esta linea
#    decia «3 de 25» en un sitio de 40: la muestra se sacaba de una lista que YA
#    venia recortada por --max-urls, asi que arrastraba el mismo error un piso
#    mas abajo —y con el agravante de sonar precisa—. Son dos recortes
#    encadenados (techo y muestra) y el que manda es el de fuera.
my $REN_DE = (defined $SITIO_URLS && $SITIO_URLS > scalar(@PAGES))
             ? $SITIO_URLS : scalar(@PAGES);
my $REN_PARCIAL = (@muestra < $REN_DE)
    ? sprintf('MUESTRA: se han mirado %d de %d paginas%s (--muestra %d). Lo que no salga aqui puede estar en las otras %d',
              scalar(@muestra), $REN_DE,
              ($REN_DE != scalar(@PAGES) ? ' del SITIO (la lista venia ya recortada por --max-urls)' : ''),
              $tope, $REN_DE - scalar(@muestra))
    : '';

    my $r = fetch($u);
    my $h = sin_com($r->{body});
    # 🔴 Sin una sola pagina descargada no hay peso que medir, y un inventario
    #    vacio saldria por PASA en REN-01, REN-04, REN-07 y REN-13 a la vez.
    if (!grep { fetch($_)->{code} == 200 } @muestra) {
        nv(lente=>'RENDIMIENTO', id=>'REN-00', titulo=>'la lente entera',
           dato=>'ninguna de las '.scalar(@muestra).' paginas de la muestra se ha podido descargar',
           umbral=>'al menos una pagina 200', proc=>'qa-maestro',
           hacer=>'sin descarga no hay peso que medir, y un inventario vacio NO es un presupuesto cumplido');
        return;
    }

    # --- inventario de recursos del HTML servido -----------------------------
    # %font_ur       url del .woff2 -> lista de `unicode-range` declarados
    # %font_preload  url que ademas va en <link rel=preload as=font>: esa la baja
    #                el navegador SI o SI, sin mirar que caracteres hay.
    my (%res, @imgs, %en_pag, %font_ur, %font_preload);
    my $anota = sub {                      # fusiona sin pisar lo ya sabido
        my ($url, $pag, %a) = @_;
        $res{$url} ||= {};
        for my $k (keys %a) {
            next unless defined $a{$k};
            if ($k =~ /^(blocking|tercero)$/) { $res{$url}{$k} ||= $a{$k} }
            else { $res{$url}{$k} //= $a{$k} }
        }
        $en_pag{$pag}{$url} = 1;
    };
    for my $pg (@muestra) {
        my $rp = fetch($pg);
        next unless $rp->{code} == 200;
        my $hp = sin_com($rp->{body});
        my $bp = base_ef($pg);           # base EFECTIVA: ver el comentario de base_ef
        $anota->($pg, $pg, tipo=>'html', wire=>$rp->{wire}, enc=>$rp->{enc}, cc=>$rp->{cc});
        for my $t ($hp =~ /(<link\b[^>]*>)/gi) {
            my $rel = lc(attr($t,'rel') // '');
            my $href = abs_url(attr($t,'href'), $bp) or next;
            if    ($rel =~ /stylesheet/)               { $anota->($href, $pg, tipo=>'css')  }
            elsif ($rel =~ /icon/)                     { $anota->($href, $pg, tipo=>'icon') }
            elsif ($rel =~ /preload/ && (attr($t,'as')//'') eq 'font') { $anota->($href, $pg, tipo=>'font'); $font_preload{$href} = 1 }
        }
        for my $t ($hp =~ /(<script\b[^>]*>)/gi) {
            my $src = attr($t,'src') or next;
            my $a = abs_url($src, $bp) or next;
            $anota->($a, $pg, tipo=>'js', blocking=>(($t =~ /\b(defer|async|type=["']module["'])/i) ? 0 : 1));
        }
        for my $t ($hp =~ /(<img\b[^>]*>)/gi) {
            my $src = attr($t,'src') // attr($t,'data-src');
            my $a = abs_url($src, $bp) or next;
            my ($w,$hh) = (attr($t,'width'), attr($t,'height'));
            push @imgs, { url=>$a, w=>$w, h=>$hh, pag=>$pg, lazy=>((attr($t,'loading')//'') eq 'lazy') };
            $anota->($a, $pg, tipo=>'img', w=>$w, h=>$hh) unless (attr($t,'loading')//'') eq 'lazy';
        }
    }
    # 🔴 Las etiquetas NO se declaran con <script src>: GTM y gtag se inyectan
    #    desde un script INLINE que CONSTRUYE la URL con concatenacion. Contando
    #    solo los src= salia «0 KB de terceros» en la web donde el 93% del peso
    #    son etiquetas (site-d: 711 KB de tags sobre 55 KB de web propia).
    #    Se reconstruye la URL exacta que descargaria el navegador.
    for my $pg (@muestra) {
        my $hp = sin_com(fetch($pg)->{body});
        for my $id ($hp =~ /\b(GTM-[A-Z0-9]+)\b/g) {
            $anota->("https://www.googletagmanager.com/gtm.js?id=$id", $pg, tipo=>'js', tercero=>1);
        }
        { my %vistos_id;
          for my $id ($hp =~ /\b(AW-\d+|G-[A-Z0-9]{8,})\b/g) {
            next if $vistos_id{$id}++;
            $anota->("https://www.googletagmanager.com/gtag/js?id=$id", $pg, tipo=>'js', tercero=>1);
          } }
        $anota->('https://connect.facebook.net/en_US/fbevents.js', $pg, tipo=>'js', tercero=>1) if $hp =~ /fbevents\.js/;
    }

    # fuentes declaradas en el CSS
    # 🔴 ARREGLO P1a (10-ago-2026) · AQUI VIVIA LA ULTIMA LOTERIA DEL ORDEN.
    #    Esta linea era `$anota->($a, $u, tipo=>'font')`: TODAS las @font-face de
    #    TODAS las hojas se cargaban a `$URLS[0]`, la primera de la lista, en vez
    #    de a las paginas que cargan esa hoja. Cuatro lineas mas arriba, el
    #    inventario de <link rel=preload as=font> ya lo hacia BIEN (`$pg`): el
    #    modelo estaba en el propio fichero.
    #    Consecuencia MEDIDA en site-a.example, la misma pagina:
    #        home la PRIMERA de la lista  -> 1053 KB (font 254 KB)
    #        home la SEGUNDA de la lista  ->  912 KB (font 113 KB)
    #    141 KB de fuentes se le atribuian a otra pagina. Y la direccion del
    #    error es la mala: INFRAVALORA el peso de todas las paginas menos una,
    #    asi que un sitio pesado podia colarse por debajo del tope segun en que
    #    orden se escribiera la lista.
    my %fam;
    # que paginas de la muestra cargan cada hoja
    my %pgs_de_css;
    for my $pg (keys %en_pag) {
        for my $ru (keys %{ $en_pag{$pg} }) {
            push @{ $pgs_de_css{$ru} }, $pg if ($res{$ru}{tipo} // '') eq 'css';
        }
    }
    for my $cu (grep { ($res{$_}{tipo}//'') eq 'css' } sort keys %res) {
        my $c = fetch($cu);
        next unless $c->{code} == 200;
        # Si la hoja no consta en ninguna pagina (no deberia pasar), se le
        # atribuye a la tecleada, pero NO en silencio: es mejor que perderla.
        my @dest = @{ $pgs_de_css{$cu} // [$u] };
        for my $blk ($c->{body} =~ /\@font-face\s*\{(.*?)\}/gs) {
            my ($f) = $blk =~ /font-family\s*:\s*['"]?([^;'"]+)/;
            $fam{$f}++ if $f;
            # `unicode-range` decide si el navegador LLEGA A PEDIR el fichero.
            # Se guarda por URL y se ACUMULA: la misma URL puede salir en dos
            # @font-face con rangos distintos, y entonces vale la union.
            my ($ur) = $blk =~ /unicode-range\s*:\s*([^;}]+)/i;
            for my $s ($blk =~ /url\(\s*['"]?([^'")]+)/g) {
                my $a = abs_url($s, $cu) or next;
                $anota->($a, $_, tipo=>'font') for @dest;
                push @{ $font_ur{$a} }, $ur if defined $ur && $ur =~ /\S/;
            }
        }
    }

    # --- descarga de todo lo del primer render -------------------------------
    my ($total, $terceros, $por_tipo) = (0, 0, {});
    my (@sin_comprimir, @sellado_nostore, @pesadas, @blocking, @rotos, @fuera_del_arbol);
    for my $ru (sort keys %res) {
        my $x = fetch($ru);
        my $t = $res{$ru}{tipo} // '?';
        # 🔴 ARREGLO 0.6 · ANTES ESTO ERA `next unless code == 200`, y un recurso
        #    que no responde se quedaba a cero bytes y salia por PASA. Caso real:
        #    site-d.example declara <link rel="icon" href="/favicon.svg">,
        #    la URL devuelve 404, y el gate emitia
        #        [PASA] REN-07 favicon ligero · DATO 0 KB
        #    Medir peso no es medir estado: 0 KB puede ser «ligero» o puede ser
        #    «no existe», y son cosas opuestas.
        if ($x->{code} != 200) {
            # 🔴 24-ago-2026 · EN MODO CANDIDATO, UN 404 PUEDE SER DEL SERVIDOR DE
            #    PRUEBAS, NO DE LA PAGINA. El candidato sirve SOLO el arbol que se
            #    va a subir; si la pagina declara un recurso que vive en OTRO
            #    backend del mismo dominio, aqui no esta y devuelve 404 por
            #    construccion. No es una hipotesis: site-b.example son dos webs bajo
            #    un dominio —69 paginas estaticas nuestras y WordPress— y sus
            #    fichas referencian 330 imagenes de `/wp-content/uploads/`.
            #    Medido ese dia: el gate acuso 1 rota; las 330 responden 200 en
            #    PRODUCCION, y en el candidato fallan todas las que le toque mirar.
            #    Acusar ahi es bloquear un despliegue por un hueco del instrumento.
            #    -> El discriminador NO es «es externa»: es si el fichero ESTA EN
            #       EL ARBOL. Si esta y no responde, es un defecto nuestro de
            #       verdad y sigue saliendo FALLO. Si no esta, solo produccion
            #       puede contestar, y lo contesta despues.
            #    ⚠️ EL DISCRIMINADOR NO PUEDE SER «¿existe el fichero?». Con eso,
            #       una ruta MAL ESCRITA a algo nuestro (`/css/styls.css`) tampoco
            #       existe, y quedaria absuelta — justo el defecto que hay que
            #       cazar. La pregunta correcta es de QUIEN ES esa zona del
            #       dominio: si el arbol tiene ese primer segmento, la sirve el
            #       arbol y un 404 es nuestro; si no lo tiene (`/wp-content/`),
            #       la sirve otro backend y aqui no hay nada que preguntar.
            my $en_arbol = 1;
            if ($CAND_ON && $opt{repo} ne '') {
                my $ruta = $ru; $ruta =~ s{^[a-z]+://[^/]+}{}i; $ruta =~ s/[?#].*$//;
                if ($ruta =~ m{^/(.+)$}) {
                    my $resto = $1;
                    if ($resto =~ m{^([^/]+)/}) {
                        # tiene carpeta: la zona es nuestra solo si esa carpeta esta en el arbol
                        $en_arbol = (-d "$opt{repo}/$1") ? 1 : 0;
                    }
                    # sin carpeta (fichero en la raiz) la zona es nuestra por definicion
                }
            }
            if ($en_arbol) {
                push @rotos, "$ru ($t · HTTP $x->{code})";
                $res{$ru}{roto} = $x->{code};
            } else {
                push @fuera_del_arbol, "$ru ($t)";
            }
            next;
        }
        if ($x->{wire} == 0 && $t ne 'html') {
            push @rotos, "$ru ($t · 200 pero 0 bytes)";
            $res{$ru}{roto} = '0B';
            next;
        }
        $res{$ru}{wire} = $x->{wire};
        $total += $x->{wire};
        $por_tipo->{$t} += $x->{wire};
        # 🔴 Se ANOTA quien es tercero, con la URL EFECTIVA (tras redirecciones),
        #    para que el cociente POR PAGINA de REN-05 use exactamente la misma
        #    decision que esta suma y no una re-derivada que pueda discrepar.
        if ($res{$ru}{tercero} || !is_internal($x->{url})) { $res{$ru}{ter} = 1; $terceros += $x->{wire} }
        # PC17 · texto sin comprimir
        push @sin_comprimir, $ru if $t =~ /^(html|css|js)$/ && ($x->{enc} eq '' || $x->{enc} =~ /identity/i);
        # PC12 · sellado ?v= + no-store: las dos tecnicas se cancelan
        push @sellado_nostore, $ru if $ru =~ /\?v=/ && $x->{cc} =~ /no-store/i;
        push @blocking, $ru if $res{$ru}{blocking};
    }

    # REN-13 · recurso declarado que no responde (arreglo 0.6, generalizado)
    @rotos ? fallo(lente=>'RENDIMIENTO', id=>'REN-13', titulo=>'recurso declarado en el HTML que NO responde 200',
                   donde=>join("\n                 ", @rotos[0..($#rotos>3?3:$#rotos)]),
                   ev=>[@rotos],
                   ev_parcial=>$REN_PARCIAL,
                   dato=>scalar(@rotos).' de '.scalar(keys %res).' recursos',
                   umbral=>'todo href/src del primer render devuelve 200 y >0 bytes',
                   proc=>'arreglo 0.6 del 10-ago-2026 · el gate media TAMANO y no ESTADO: el favicon 404 de site-d.example salia como «favicon ligero · 0 KB · PASA»',
                   hacer=>'publicar el fichero o quitar la etiqueta. Un 404 declarado es una peticion perdida en cada visita, y aqui tapaba dos checks de peso (REN-07 y REN-04)')
           : pasa(lente=>'RENDIMIENTO', id=>'REN-13', titulo=>'todos los recursos declarados responden', dato=>scalar(keys %res).' recursos');

    # Los que el candidato NO PUEDE contestar se dicen en voz alta, con nombre.
    # Callarlos seria peor que acusarlos: un recurso que nadie ha mirado y que no
    # sale en ningun sitio se lee como un PASA. Los contesta produccion.
    nv_cand(lente=>'RENDIMIENTO', id=>'REN-13b',
            titulo=>'recursos declarados que NO estan en el arbol: solo produccion puede contestarlos',
            motivo=>'el candidato sirve el arbol que se sube; estos recursos los sirve otro backend del mismo dominio',
            dato=>scalar(@fuera_del_arbol).' recurso(s) fuera del arbol',
            donde=>join("\n                 ", @fuera_del_arbol[0..($#fuera_del_arbol>3?3:$#fuera_del_arbol)]),
            umbral=>'los 200 se comprueban contra PRODUCCION, no contra el candidato',
            proc=>'24-ago-2026 · site-b.example son dos webs bajo un dominio: las fichas declaran 330 imagenes de /wp-content/ que jamas estaran en el arbol estatico',
            hacer=>'comprobarlos contra produccion (o con G11 despues de subir). Si alguno da 404 ALLI, entonces si es un defecto')
      if @fuera_del_arbol;

    # terceros que no estan en $res (GTM inyectado inline, pixel, etc.)
    my @third_hosts;
    { my %th;
      for my $pg (@muestra) {
        my $hp = sin_com(fetch($pg)->{body});
        for my $d ($hp =~ /["']https?:\/\/([a-z0-9.-]+)/gi) { $th{lc $d}++ unless $d =~ /\Q$HOST\E$/i || $d =~ /^(schema\.org|www\.w3\.org)$/ }
      }
      @third_hosts = sort keys %th; }

    # REN-01 · peso inicial · POR PAGINA (sumar las de la muestra seria inventar
    # una pagina que nadie visita). Se reporta la peor, y se dice cual es.
    my ($tk, $det, $peor) = (0, '', $u);
    for my $pg (@muestra) {
        my ($tp, %pt) = (0);
        for my $ru (keys %{ $en_pag{$pg} // {} }) {
            next unless defined $res{$ru}{wire};
            $tp += $res{$ru}{wire}; $pt{ $res{$ru}{tipo} } += $res{$ru}{wire};
        }
        next unless $tp/1024 > $tk;
        $tk = $tp/1024; $peor = $pg;
        # ⚠️ El desempate por NOMBRE no es cosmetico: sin el, dos tipos que pesan
        #    lo mismo (site-a: icon 313 KB e img 313 KB) salen en el orden del hash
        #    de Perl, que cambia en cada proceso. Dos corridas del MISMO comando
        #    imprimian DATO distintos, y eso hace imposible comparar dos informes.
        $det = join(' · ', map { "$_ ".kb($pt{$_}) }
                           sort { $pt{$b} <=> $pt{$a} or $a cmp $b } keys %pt);
    }
    my $sufijo = @muestra > 1 ? sprintf(' · la mas pesada de %d paginas', scalar @muestra) : '';
    # ⚠️ El peso SI se mide contra el candidato —es del arbol, no del host— pero
    #    el texto propio viaja en gzip y produccion en brotli o zstd segun el
    #    host. Medido: +323/+330/+454 B contra brotli, -378 B contra zstd. Unos
    #    cientos de bytes, tres ordenes por debajo de los umbrales, pero NO es el
    #    mismo instrumento: se dice en el DATO en vez de callarlo, porque un
    #    numero que no declara como se tomo acaba comparado con otro que se tomo
    #    de otra forma, y de ahi salen los «ha empeorado» que no existen.
    $sufijo .= ' · CANDIDATO (gzip local; produccion usa br o zstd: +-unos cientos de B por fichero de texto)' if $CAND_ON;
    if ($tk > 1600) {
        fallo(lente=>'RENDIMIENTO', id=>'REN-01', titulo=>'peso del primer render por encima del tope',
              donde=>$peor, dato=>sprintf('%.0f KB en el cable · %s%s', $tk, $det, $sufijo),
              umbral=>'FALLO >1.600 KB · AVISO >500 · objetivo <=300',
              proc=>'G3 · PC2 (0 apariciones de LCP/CLS/brotli/srcset en SKILL.md + 13 references + web-page-standard)',
              hacer=>'mirar el reparto de arriba: si manda «img», reencodear a WebP; si manda «js» de terceros, ver REN-05');
    } elsif ($tk > 500) {
        aviso(lente=>'RENDIMIENTO', id=>'REN-01', titulo=>'peso del primer render alto',
              donde=>$peor, dato=>sprintf('%.0f KB · %s%s', $tk, $det, $sufijo),
              umbral=>'AVISO >500 KB · objetivo <=300', proc=>'G3',
              hacer=>'no bloquea, pero se paga en cada visita movil');
    } else {
        pasa(lente=>'RENDIMIENTO', id=>'REN-01', titulo=>'peso del primer render', dato=>sprintf('%.0f KB · %s%s', $tk, $det, $sufijo));
    }

    # REN-02 · imagen individual
    # 🔴 ARREGLO P4 (10-ago-2026) · UN VECTOR NO TIENE RESOLUCION.
    #    Este check acusaba de «sobredimensionados» a tres SVG de ~700 B de
    #    climentmedia (meta.svg 738 B, googleads.svg 755 B, ga4.svg 404 B),
    #    declarados a 18x18, por 2,278 / 2,330 / 1,247 «B/px». Bytes-por-pixel
    #    mide si un BITMAP trae mas pixeles de los que se pintan; un SVG no trae
    #    pixeles, trae instrucciones, y se ve igual de nitido a 18 px que a 1800.
    #    Peor: el HACER que emitia era «reencodear a WebP» un logo vectorial, o
    #    sea, romperlo a proposito. Tres FALLO falsos y un consejo daninho.
    #    Un SVG SI puede ser un problema, pero por PESO ABSOLUTO —un mapa o un
    #    icono con un bitmap incrustado dentro—, asi que se vigila con su propio
    #    umbral y se dice que es otro criterio.
    my (@svg_gordos, %svg_vistos);
    for my $i (@imgs) {
        my $x = fetch($i->{url}); next unless $x->{code} == 200 && $x->{wire} > 0;
        my $es_svg = ($i->{url} =~ /\.svgz?(\?|$)/i) || (($x->{ctype}//'') =~ m{image/svg}i);
        if ($es_svg) {
            $svg_vistos{ $i->{url} } = 1;
            # 100 KB de vector ya no es un vector: es un bitmap disfrazado o un
            # mapa entero. Los de climentmedia pesan 0,4-0,7 KB.
            push @svg_gordos, sprintf('%s (%.0f KB de SVG)', $i->{url}, $x->{wire}/1024)
                if $x->{wire} > 100*1024;
            next;
        }
        my $why = '';
        $why = sprintf('%.0f KB', $x->{wire}/1024) if $x->{wire} > 500*1024;
          # 🔴 18-ago-2026 · EL B/px NECESITA UN SUELO EN BYTES ABSOLUTOS.
          #  Sin el, este check acusaba al logotipo de site-d: 12.444 B a 45x48
          #  = 5,76 B/px. Se hizo LO QUE SU PROPIO `hacer` MANDA -reencodear a
          #  WebP al tamano en que se muestra-: 2.342 B, y **seguia fallando**
          #  (1,08 B/px). Para bajar de 0,30 en 45x48 harian falta 648 bytes, que
          #  es territorio SVG, no raster. Un check cuyo remedio declarado no lo
          #  satisface esta roto: o se cumple o se cambia el remedio.
          #  Y era incoherente en la otra direccion: ignoraba una foto de 400 KB a
          #  1600x1200 (0,21 B/px) mientras acusaba a un icono de 2 KB.
          #  El suelo son 4 KB, y no me lo invento: el objetivo de peso de pagina
          #  de este mismo check son 300 KB, asi que 4 KB es el 1,3% -- por debajo
          #  de eso el asset NO PUEDE ser el problema. Lo gordo sigue cazado por
          #  la rama de >500 KB, que no depende del ratio.
          my $SUELO_BPX = 4 * 1024;
          if ($x->{wire} > $SUELO_BPX
              && $i->{w} && $i->{h} && $i->{w} =~ /^\d+$/ && $i->{h} =~ /^\d+$/ && $i->{w}*$i->{h} > 0) {
              my $bpp = $x->{wire} / ($i->{w}*$i->{h});
              $why .= sprintf('%s%.3f B/px', ($why?' · ':''), $bpp) if $bpp > 0.30;
          }
        push @pesadas, "$i->{url} ($why)" if $why;
    }
    @pesadas = do { my %v; grep { !$v{$_}++ } @pesadas };
    @svg_gordos = do { my %v; grep { !$v{$_}++ } @svg_gordos };
    # Se cuentan los que se han RECONOCIDO como vector (extension o
    # content-type), no los que lo parecen por el nombre: un SVG servido sin
    # extension existe, y si no se cuenta aqui REN-02b no llegaria a mirarlo.
    my $n_svg = scalar keys %svg_vistos;
    @pesadas ? fallo(lente=>'RENDIMIENTO', id=>'REN-02', titulo=>'imagen sobredimensionada',
                     donde=>join("\n                 ", @pesadas[0..($#pesadas>2?2:$#pesadas)]),
                     ev=>[@pesadas],
                     ev_parcial=>$REN_PARCIAL,
                     umbral=>'FALLO >500 KB o >0,30 B/px SOBRE LOS PIXELES EN QUE SE MUESTRA (width x height del marcado) · objetivo <=0,10 B/px · los SVG NO entran: un vector no tiene resolucion (ver REN-02b)',
                     proc=>'G3 · el liston es el que ya alcanza site-c (0,037-0,041 B/px), no un numero de industria',
                     hacer=>'reencodear a WebP al tamano en que se MUESTRA. Un B/px de tres cifras no es un error del calculo: es un asset gigante metido en un hueco pequeno (el logo de site-a es 1080x1080 declarado a 40x40 = 729x en pixeles)')
              : pasa(lente=>'RENDIMIENTO', id=>'REN-02', titulo=>'ninguna imagen sobredimensionada',
                     dato=>scalar(@imgs).' imagenes'.($n_svg ? " ($n_svg SVG, medidos por peso en REN-02b)" : ''));

    # REN-02b · el vector se vigila por PESO ABSOLUTO, que es lo unico que
    # significa algo en un formato sin resolucion.
    if ($n_svg) {
        @svg_gordos ? aviso(lente=>'RENDIMIENTO', id=>'REN-02b', titulo=>'SVG pesado',
                            donde=>join("\n                 ", @svg_gordos[0..($#svg_gordos>2?2:$#svg_gordos)]),
                            ev=>[@svg_gordos],
                            ev_parcial=>$REN_PARCIAL,
                            dato=>scalar(@svg_gordos).' de '.$n_svg.' SVG',
                            umbral=>'AVISO >100 KB de peso ABSOLUTO · no se le aplica B/px',
                            proc=>'arreglo P4 del 10-ago-2026 · REN-02 acusaba a tres SVG de 0,4-0,7 KB por «2,278 B/px» y mandaba reencodearlos a WebP',
                            hacer=>'un SVG de mas de 100 KB casi siempre lleva un bitmap incrustado o un trazado sin simplificar: mirarlo antes que reencodearlo')
                    : pasa(lente=>'RENDIMIENTO', id=>'REN-02b', titulo=>'SVG de peso razonable', dato=>"$n_svg SVG, ninguno >100 KB");
    }

    # REN-12 · el mismo fichero servido con dos nombres. Barato, y encontrado en
    # vivo la primera vez que se corrio esto: site-a sirve el MISMO PNG
    # (320.221 B, md5 identico) como /favicon.png y como el logo del <header>.
    # 640 KB en el primer render para una imagen.
    {
        my %porhash;
        for my $ru (grep { ($res{$_}{tipo}//'') =~ /^(img|icon|font)$/ } sort keys %res) {
            my $x = fetch($ru); next unless $x->{code} == 200 && $x->{wire} > 20*1024;
            push @{ $porhash{ md5_hex($x->{body}) } }, $ru;
        }
        my @dupfile = grep { @{$porhash{$_}} > 1 } sort keys %porhash;
        @dupfile ? fallo(lente=>'RENDIMIENTO', id=>'REN-12', titulo=>'el mismo fichero servido con dos nombres (se descarga dos veces)',
                         donde=>join("\n                 ", map { join(" == ", sort @{$porhash{$_}}) } @dupfile),
                         dato=>scalar(@dupfile).' duplicados byte a byte',
                         umbral=>'0 · un asset, una URL',
                         proc=>'encontrado por este gate el 10-ago-2026 en site-a.example: favicon.png y assets/logo-kad-*.png son el MISMO PNG de 320.221 B',
                         hacer=>'dejar una sola URL y referenciarla desde los dos sitios. Es peso puro, sin contrapartida')
                 : pasa(lente=>'RENDIMIENTO', id=>'REN-12', titulo=>'sin assets duplicados');
    }

    # REN-03 · width/height (CLS)
    my @sin_dim = do { my %v; grep { !$v{$_->{url}}++ } grep { !($_->{w} && $_->{h}) } @imgs };
    @sin_dim ? fallo(lente=>'RENDIMIENTO', id=>'REN-03', titulo=>'<img> sin width/height',
                     donde=>join(' · ', map { $_->{url} } @sin_dim[0..($#sin_dim>2?2:$#sin_dim)]),
                     ev=>[map { $_->{url} } @sin_dim],
                     ev_parcial=>$REN_PARCIAL,
                     dato=>scalar(@sin_dim).' imagenes distintas sin dimensionar en '.scalar(@muestra).' paginas',
                     umbral=>'0', proc=>'G3 (site-b 50/56, site-a 1/8 —justo el PNG de 2,3 MB—, climentmedia 1/9)',
                     hacer=>'width y height en el marcado reservan el hueco: sin ellos el texto salta cuando carga la imagen (CLS)')
             : pasa(lente=>'RENDIMIENTO', id=>'REN-03', titulo=>'todas las <img> con dimensiones');

    # REN-04 · tipografia
    #  ⚠️ Mismo patron que REN-07: un .woff2 que devuelve 404 pesaba 0 KB y
    #     ABARATABA el presupuesto. Se cuentan aparte y se dicen.
    my @declaradas = grep { ($res{$_}{tipo}//'') eq 'font' } sort keys %res;
    # 🔴 SE CUENTA LO QUE EL NAVEGADOR BAJARIA · ver el bloque «5-bis».
    #    El juego de caracteres se saca de los cuerpos ENTEROS de la muestra
    #    (HTML + CSS + JS internos), no del texto visible: incluir de mas es la
    #    direccion segura —un caracter de sobra hace que la fuente SI cuente—.
    my ($cps, $incierto) = cps_del_texto([
        map { fetch($_)->{body} }
        grep { fetch($_)->{code} == 200 }
        (@muestra, grep { (($res{$_}{tipo}//'') =~ /^(css|js)$/) && !$res{$_}{tercero} } sort keys %res)
    ]);
    $incierto ||= 'no se ha podido leer texto de ninguna pagina' unless keys %$cps;
    my (@fontfiles, @nobajadas, $bytes_nobajados);
    $bytes_nobajados = 0;
    for my $fu (@declaradas) {
        my $ur = $font_ur{$fu};
        if (!$incierto && $ur && @$ur && !$font_preload{$fu}
            && !grep { ur_toca($_, $cps) } @$ur) {
            push @nobajadas, $fu;
            $bytes_nobajados += ($res{$fu}{wire} // 0);
            next;
        }
        push @fontfiles, $fu;
    }
    # ⚠️ Un fichero que no responde 200 sigue contando AUNQUE el rango no se use:
    #    lo mide REN-13 y no se le quita peso a un fallo real por este camino.
    my @font_rotas = grep { $res{$_}{roto} } @declaradas;
    push @fontfiles, grep { my $r = $_; !grep { $_ eq $r } @fontfiles } @font_rotas;
    my $fontbytes = 0; $fontbytes += ($res{$_}{wire}//0) for @fontfiles;
    my $nfam = scalar keys %fam;
    # 🔴 EL METODO, DENTRO DEL DATO: el numero tiene que ser rastreable, porque
    #    ya no coincide con «cuantos @font-face hay» ni con el font de REN-01.
    my $metodo = $incierto
        ? "juego de caracteres INCIERTO ($incierto): NO se descuenta nada, se cuentan los ".scalar(@declaradas).' declarados'
        : sprintf('metodo: unicode-range cruzado con los %d caracteres distintos de la muestra', scalar keys %$cps);
    $metodo .= sprintf(' · %d de %d NO se bajan (%s): %s',
                       scalar(@nobajadas), scalar(@declaradas), kb($bytes_nobajados),
                       join(', ', map { s{.*/}{}r } sort @nobajadas)) if @nobajadas;
    my $font_dato = "$nfam familias · ".scalar(@fontfiles).' ficheros · '.kb($fontbytes)
                  . (@font_rotas ? ' · ⚠ '.scalar(@font_rotas).' NO responden (ver REN-13), su peso NO cuenta' : '')
                  . ' · '.$metodo;
    if ($nfam >= 3 || @fontfiles > 4 || $fontbytes > 200*1024 || @font_rotas) {
        fallo(lente=>'RENDIMIENTO', id=>'REN-04', titulo=>'presupuesto tipografico excedido',
              donde=>(@font_rotas ? join(' · ', @font_rotas) : ''),
              dato=>$font_dato,
              umbral=>'FALLO >=3 familias, >4 ficheros QUE SE BAJEN, >200 KB bajados, o cualquier fichero que no responda 200 · objetivo <=2 ficheros y <=60 KB',
              proc=>'G3 · site-c sirve 2 ficheros / 45 KB · site-d: 0 webfonts y aun asi la mejor maqueta · 11-ago-2026: se descuenta lo que el navegador NO pide por unicode-range (site-a declara 4/254 KB y Chrome baja 2/112,9 KB)',
              hacer=>'subset a los caracteres que se usan, un peso por familia, woff2 y font-display:swap');
    } else {
        pasa(lente=>'RENDIMIENTO', id=>'REN-04', titulo=>'presupuesto tipografico', dato=>$font_dato);
    }

    # REN-05 · terceros
    # ⚠️ DECLARADO AL ARREGLAR P1b (10-ago-2026), porque el arreglo lo destapo:
    #    los KB de terceros son un hecho, pero el PORCENTAJE es un cociente sobre
    #    la union de recursos de las paginas MUESTREADAS —una pagina que nadie
    #    visita—, asi que depende del tamano de la muestra. Medido en
    #    site-d.example, mismos 151 KB de etiquetas:
    #        3 primeras paginas (muestra sesgada al principio) -> 54%  FALLO
    #        3 repartidas por la lista                          -> 43%  PASA
    #        las 25                                             -> 10%  PASA
    #    El 54% no era una web peor: era una muestra de las tres paginas mas
    #    ligeras del sitio. El numero de KB no se mueve; el cociente si. Se
    #    imprime el tamano de la muestra AL LADO del porcentaje para que nadie
    #    lo lea como un dato del sitio, y se recuerda ampliarla antes de creerlo.
    # 🔴 ARREGLO (11-ago-2026) · EL COCIENTE ES POR PAGINA, NO SOBRE LA UNION.
    #    El aviso de arriba era honesto y aun asi el gate seguia decidiendo con
    #    el numero que el propio aviso desaconsejaba: **el `if` no lee el DATO**.
    #    Medido en site-d.example, mismos 152 KB de etiquetas:
    #        1 pagina -> 56% FALLO   ·   muestra 3 -> 46% PASA   ·   40 -> 8% PASA
    #    El numerador no se movia; crecia el denominador (la union de recursos de
    #    las paginas muestreadas). O sea: **ampliar la cobertura APAGABA el
    #    fallo**, que es la unica direccion que un gate no se puede permitir.
    #
    #    Ahora se calcula el cociente DENTRO de cada pagina y manda la PEOR.
    #    «Los terceros son el 56% del peso de esta pagina» es un hecho del sitio
    #    y no se mueve al medir mas; «el 8% de la union de 40 paginas» era un
    #    hecho del muestreo. Ampliar cobertura ahora solo puede EMPEORAR el
    #    veredicto (aparece una pagina peor), nunca apagarlo.
    #
    #    La rama ABSOLUTA (>300 KB) se queda como estaba: son bytes, no cociente.
    # ⚠️ Arranca en -1, no en 0. Con 0 y comparacion estricta, una web SIN
    #    terceros —climentmedia hoy— no fijaba ninguna pagina y el DATO salia
    #    «sin pagina medible», que se lee como «no he podido mirar» cuando la
    #    verdad es «he mirado y es cero». Son cosas opuestas.
    my ($peor_pct, $peor_pag, $peor_ter, $peor_tot) = (-1, '', 0, 0);
    for my $pg (@muestra) {
        my ($tp, $terp) = (0, 0);
        for my $ru (keys %{ $en_pag{$pg} // {} }) {
            next if $res{$ru}{roto};
            my $w = $res{$ru}{wire} // 0;
            $tp += $w;
            $terp += $w if $res{$ru}{ter};
        }
        next unless $tp > 0;
        my $p = 100 * $terp / $tp;
        ($peor_pct, $peor_pag, $peor_ter, $peor_tot) = ($p, $pg, $terp, $tp) if $p > $peor_pct;
    }
    my $pct = $total ? 100*$terceros/$total : 0;     # union: solo para el detalle
    my $peor_dice = $peor_pag ne ''
        ? sprintf(' · peor pagina %s: %s de %s = %.0f%% (peor de %d medida%s)',
                  $peor_pag, kb($peor_ter), kb($peor_tot), $peor_pct,
                  scalar(@muestra), (@muestra == 1 ? '' : 's'))
        : ' · sin pagina medible';
    if ($terceros > 300*1024 || ($peor_pct > 50 && $peor_ter > 100*1024)) {
        fallo(lente=>'RENDIMIENTO', id=>'REN-05', titulo=>'presupuesto de terceros excedido',
              donde=>$peor_pag,
              dato=>sprintf('%s de terceros en total%s · %s', kb($terceros), $peor_dice, join(' ', @third_hosts)),
              umbral=>'FALLO >300 KB en total, o >50% del peso DE UNA PAGINA con >100 KB · ⚠️ el % es POR PAGINA desde el 11-ago-2026: sobre la union dependia de cuantas midieras · ⚠️ medido sobre el PRIMER render: lo que un tercero carga A SU VEZ no se ve sin el panel de red (bloque B), asi que este numero es un SUELO',
              proc=>'G3 (site-d: 93% del peso son etiquetas, 711 KB sobre 55 KB de web propia, medido con navegador)',
              hacer=>'la web propia no puede pesar menos que su medicion. Quitar duplicados (ver REN-06) y cargar lo que no sea critico despues del load');
    } else {
        pasa(lente=>'RENDIMIENTO', id=>'REN-05', titulo=>'presupuesto de terceros',
             dato=>sprintf('%s en total (%.0f%% de la union)%s', kb($terceros), $pct, $peor_dice));
    }

    # REN-06 · id de medicion duplicado
    my %ids;
    $ids{$_}++ for ($h =~ /\b(AW-\d+|G-[A-Z0-9]{8,}|GTM-[A-Z0-9]+)\b/g);
    my $fb = () = $h =~ /fbevents\.js/g;
    my @dupids = grep { $ids{$_} > 2 } sort keys %ids;   # >2: la etiqueta suele citarse 2 veces por instalacion
    if (@dupids || $fb > 1) {
        aviso(lente=>'RENDIMIENTO', id=>'REN-06', titulo=>'identificador de medicion citado de mas',
              dato=>join(' · ', (map { "$_ x$ids{$_}" } @dupids), ($fb>1 ? "fbevents.js x$fb" : ())),
              umbral=>'un id, una instalacion', proc=>'G3 (site-d carga gtag.js del MISMO AW- dos veces + fbevents duplicado)',
              hacer=>'comprobar en el panel de red si se descarga dos veces; si si, quitar la instalacion directa y dejar solo la del contenedor');
    } else {
        pasa(lente=>'RENDIMIENTO', id=>'REN-06', titulo=>'sin identificadores de medicion duplicados');
    }

    # REN-07 · favicon
    # 🔴 ARREGLO 0.6 · medir TAMANO no es medir ESTADO. Este check emitia
    #    «[PASA] REN-07 favicon ligero · DATO 0 KB» sobre
    #    https://site-d.example/favicon.svg, que devuelve 404 (796 bytes de
    #    pagina de error). 0 KB puede ser «ligero» o puede ser «no existe».
    # 🔴 `sort keys`, NO `keys`. Perl aleatoriza el orden de las claves de un
    #    hash EN CADA PROCESO. Sin ordenar, REN-07 emitia los dos iconos unas
    #    veces en un orden y otras en el otro, y con ellos su huella: 4 de 10
    #    corridas del MISMO comando sobre site-b daban una huella distinta.
    #    Una aceptacion de REN-07 habria dejado de casar sola, sin que nadie
    #    tocara la web. Se ordena en ORIGEN —aqui, donde nace la lista— y no
    #    normalizando la huella: el orden de hash tambien ensucia el DONDE que
    #    lee una persona, y eso no lo arregla ninguna huella.
    #    Mismo motivo en los otros `sort keys` de esta lente.
    my @icons = grep { ($res{$_}{tipo}//'') eq 'icon' } sort keys %res;
    my @icon_rotos = grep { $res{$_}{roto} } @icons;
    my ($ipeso) = (0); $ipeso += ($res{$_}{wire}//0) for @icons;
    if (@icon_rotos) {
        fallo(lente=>'RENDIMIENTO', id=>'REN-07', titulo=>'el favicon declarado NO existe',
              donde=>join(' · ', map { "$_ (".($res{$_}{roto} =~ /^\d+$/ ? "HTTP $res{$_}{roto}" : '0 bytes').")" } @icon_rotos),
              dato=>scalar(@icon_rotos).' de '.scalar(@icons).' iconos declarados no responden',
              umbral=>'200 y >0 bytes · y <=10 KB',
              proc=>'arreglo 0.6 · antes se media el peso y no el estado, asi que un 404 salia como «favicon ligero · 0 KB · PASA»',
              hacer=>'publicar el fichero o quitar el <link rel="icon">. Mientras tanto el navegador pide /favicon.ico y se lleva otro 404');
    } elsif ($ipeso > 10*1024) {
        fallo(lente=>'RENDIMIENTO', id=>'REN-07', titulo=>'favicon pesado',
              donde=>join(' · ', @icons), dato=>kb($ipeso),
              umbral=>'<=10 KB', proc=>'G3 · X9 (el check que hay mide IDENTIDAD, nunca peso: los 320 KB de site-a CUMPLEN el check actual)',
              hacer=>'SVG, o PNG de 32px. climentmedia lo sirve como data: URI: 0 peticiones');
    } elsif (@icons) {
        pasa(lente=>'RENDIMIENTO', id=>'REN-07', titulo=>'favicon ligero', dato=>kb($ipeso).' · '.scalar(@icons).' declarado(s), todos responden');
    } else {
        # 19-ago-2026 - FALSO POSITIVO. La lista de iconos son RECURSOS DESCARGADOS,
        #   y un favicon en `data:` no se descarga: nunca entra en la lista. Asi que
        #   una web que lo declara del mejor modo posible -cero peticiones- salia
        #   como "sin favicon declarado en el HTML". Le pasaba a climentmedia, y el
        #   propio texto de este check ya decia "climentmedia lo sirve como data:
        #   URI". Se mira el HTML, que es donde esta la respuesta.
        my $htmlIcono = fetch($URLS[0])->{body} // '';
        my $iconoEnLinea = ($htmlIcono =~ /<link[^>]*rel=["'][^"']*icon[^"']*["'][^>]*href=["']data:/i)
                            || ($htmlIcono =~ /<link[^>]*href=["']data:[^>]*rel=["'][^"']*icon/i);
        if ($iconoEnLinea) {
            pasa(lente=>'RENDIMIENTO', id=>'REN-07', titulo=>'favicon en linea (data: URI)',
                 dato=>'0 peticiones: no hay fichero que pedir');
        } else {
            aviso(lente=>'RENDIMIENTO', id=>'REN-07', titulo=>'sin favicon declarado en el HTML',
                  umbral=>'<link rel="icon">', proc=>'02-diseno', hacer=>'declararlo: si no, el navegador pide /favicon.ico y suele ser un 404');
        }
    }

    # PC17 · compresion — el unico punto ciego que sale BIEN. Se reporta IGUAL,
    # con fecha: sin la comprobacion, «seguro que esta puesto» es una suposicion.
    #
    # 🔴 CONTRA EL CANDIDATO NO SE MIDE. Quien comprime aqui es el servidor de
    #    pruebas de este mismo fichero, asi que un PASA seria este fichero
    #    aprobandose a si mismo. La compresion es del HOST, no del arbol.
    if ($CAND_ON) {
        nv_cand(lente=>'RENDIMIENTO', id=>'REN-08', titulo=>'compresion del texto servido',
                dato=>'medido contra el CANDIDATO: comprime el servidor local (gzip), no el de produccion',
                umbral=>'brotli o zstd o gzip en html/css/js',
                proc=>'PC17 · la compresion es configuracion del HOST, no del arbol del repo',
                motivo=>'la compresion la pone el servidor, y aqui el servidor es el de pruebas',
                hacer=>'se contesta DESPUES de subir: perl qa-master.pl <URL real> --repo DIR (sin --candidato)');
    } else {
    @sin_comprimir ? fallo(lente=>'RENDIMIENTO', id=>'REN-08', titulo=>'texto servido SIN comprimir',
                           donde=>join(' · ', @sin_comprimir[0..($#sin_comprimir>2?2:$#sin_comprimir)]),
                           ev=>[@sin_comprimir],
                           ev_parcial=>$REN_PARCIAL,
                           umbral=>'brotli o zstd o gzip en html/css/js', proc=>'PC17 (verificado 10-ago-2026: las 5 webs comprimen)',
                           hacer=>'activarlo en el servidor. Es gratis y es el mayor porcentaje de peso que se quita de una vez')
                   : pasa(lente=>'RENDIMIENTO', id=>'REN-08', titulo=>'html/css/js comprimidos',
                          dato=>join(' ', map { ($res{$_}{tipo}//'').'='.(fetch($_)->{enc}||'?') } grep { ($res{$_}{tipo}//'') =~ /^(html|css|js)$/ } sort keys %res));
    }

    # PC12 · sellado ?v= + no-store
    # 🔴 Igual que REN-08: `Cache-Control` lo pone el host. El servidor del
    #    candidato no manda ninguna, asi que «no hay no-store» saldria PASA
    #    siempre y por construccion.
    if ($CAND_ON) {
        nv_cand(lente=>'RENDIMIENTO', id=>'REN-09', titulo=>'cabeceras de cache frente al sellado ?v=',
                dato=>'medido contra el CANDIDATO: el servidor local no manda Cache-Control',
                umbral=>'sellado ?v= => Cache-Control: immutable, nunca no-store',
                proc=>'PC12 · las cabeceras de cache son configuracion del HOST',
                motivo=>'Cache-Control lo pone el servidor de produccion; aqui no hay ninguna que leer',
                hacer=>'se contesta DESPUES de subir, midiendo la URL real');
    } else {
    @sellado_nostore ? fallo(lente=>'RENDIMIENTO', id=>'REN-09', titulo=>'asset sellado con ?v= y servido con no-store',
                             donde=>join(' · ', @sellado_nostore[0..($#sellado_nostore>2?2:$#sellado_nostore)]),
                             ev=>[@sellado_nostore],
                             ev_parcial=>$REN_PARCIAL,
                             umbral=>'sellado ?v= => Cache-Control: immutable',
                             proc=>'PC12 (loja.site-b: ~43 KB re-descargados en cada navegacion, para siempre)',
                             hacer=>'las dos tecnicas se cancelan: el sello existe PARA poder cachear eternamente y el no-store lo prohibe. Quitar el no-store')
                     : pasa(lente=>'RENDIMIENTO', id=>'REN-09', titulo=>'cabeceras de cache coherentes con el sellado');
    }

    @blocking ? aviso(lente=>'RENDIMIENTO', id=>'REN-10', titulo=>'script bloqueante en el <head>',
                      donde=>join(' · ', @blocking), umbral=>'0 · defer, async o type=module',
                      proc=>'PC17 (render-blocking: 0 en las cinco webs, hoy)',
                      hacer=>'anadir defer. Es la unica de estas que se arregla escribiendo una palabra')
              : pasa(lente=>'RENDIMIENTO', id=>'REN-10', titulo=>'sin scripts bloqueantes');

    # PC2 · lo que NO se puede medir sin navegador
    if (exists $DOM{lcp_ms} || exists $DOM{cls}) {
        my ($lcp,$cls) = ($DOM{lcp_ms}//0, $DOM{cls}//0);
        ($lcp > 2500 || $cls > 0.1)
          ? fallo(lente=>'RENDIMIENTO', id=>'REN-11', titulo=>'Core Web Vitals de campo',
                  dato=>sprintf('LCP %.0f ms · CLS %.3f', $lcp, $cls),
                  umbral=>'LCP <=2.500 ms · CLS <=0,1', proc=>'PC2 · snippet de qa-maestro',
                  hacer=>'si el LCP es una imagen: dimensionarla y precargarla. Si el CLS: REN-03')
          : pasa(lente=>'RENDIMIENTO', id=>'REN-11', titulo=>'Core Web Vitals',
                 dato=>sprintf('LCP %.0f ms · CLS %.3f', $lcp, $cls));
    } else {
        nv(lente=>'RENDIMIENTO', id=>'REN-11', titulo=>'LCP y CLS reales',
           umbral=>'LCP <=2.500 ms · CLS <=0,1',
           proc=>'PC2 · 0 apariciones de LCP/CLS en toda la documentacion, verificado',
           hacer=>'perl qa-master.pl --snippet > /tmp/s.js  ·  pegarlo en la consola  ·  guardar su JSON  ·  --dom /tmp/s.json');
    }
}

# =============================================================================
#  6 · LENTE 3 · ACCESIBILIDAD
#     Procedencia: G2 · G8 · X7 · PC8 · PC13 · sospecha de metodo (44x44)
# =============================================================================
sub lente_a11y {
    unless ($NET_OK) {
        nv(lente=>'ACCESIBILIDAD', id=>'A11Y-00', titulo=>'la lente entera', umbral=>'requiere red',
           proc=>'qa-maestro', hacer=>'sin descarga no hay HTML que leer');
        return;
    }
    my $u = $URLS[0];
    my $h = sin_com(fetch($u)->{body});

    # 🔴 ARREGLO 0.3 · LA LOTERIA DEL ORDEN.
    #    Esta lente empezaba con `my $u = $URLS[0]` y no volvia a mirar ninguna
    #    otra pagina. Experimento reproducible, las MISMAS dos URLs, cambiando
    #    solo el orden:
    #        home primero    -> [FALLO] A11Y-08 saltos de nivel de titular
    #        /tarot/ primero -> [PASA ] A11Y-08 jerarquia sin saltos
    #    Y en site-c: 1 URL -> A11Y-08 FALLO · 25 URLs -> A11Y-08 PASA.
    #    Ampliar la cobertura APAGABA un fallo real, que es la peor direccion
    #    posible del error. Ahora se AGREGA sobre @PAGES: un id, un veredicto,
    #    y la lista de paginas que lo incumplen. El resultado no depende del
    #    orden porque no depende de la primera.
    my @vistas = @PAGES;
    my (@sin_lang, @sin_skip, @svg_mal, @mudos, @main_mal, @saltos_pag, @no_leidas, @leidas);
    my $n_svg_mal = 0;
    for my $p (@vistas) {
        my $r = fetch($p);
        if ($r->{code} != 200 || $r->{body} !~ /</) { push @no_leidas, "$p (HTTP $r->{code})"; next }
        push @leidas, $p;
        my $hp = sin_com($r->{body});

        # A11Y-01 · lang
        my ($html_tag) = $hp =~ /(<html\b[^>]*>)/i;
        my $lang = $html_tag ? attr($html_tag,'lang') : undef;
        push @sin_lang, $p unless $lang && $lang =~ /^[a-z]{2}/i;

        # A11Y-02 · enlace de salto (arreglo 0.5b, ver abajo)
        push @sin_skip, $p unless tiene_skip_link($hp);

        # A11Y-05 · SVG decorativo sin marcar
        my $nsvg = 0;
        for my $s ($hp =~ /(<svg\b[^>]*>)/gi) { $nsvg++ unless $s =~ /aria-hidden|role=["']img["']|aria-label/i }
        if ($nsvg) { push @svg_mal, "$p ($nsvg)"; $n_svg_mal += $nsvg }

        # A11Y-06 · enlace/boton sin nombre accesible
        for my $m ($hp =~ m{(<a\b[^>]*>.*?</a>|<button\b[^>]*>.*?</button>)}gsi) {
            my ($open) = $m =~ /^(<[^>]*>)/;
            next if attr($open,'aria-label') || attr($open,'title') || attr($open,'aria-labelledby');
            my $txt = tag_text($m); $txt =~ s/^\s+|\s+$//g;
            push @mudos, substr($open,0,70)." <- $p" if $txt eq '';
        }

        # A11Y-07 · un solo <main>
        # 🔴 17-ago-2026 · SIN QUITAR LOS COMENTARIOS, ESTE CHECK ACUSA A QUIEN
        #    HABLA DE EL. Salio escribiendo su propio caso de prueba: el fixture
        #    llevaba un comentario explicando el defecto -«A11Y-07 DOS <main>:
        #    el salto ir-al-contenido deja de ser determinista»- y el gate conto
        #    ESE `<main` como una etiqueta mas. La pagina tenia uno y el gate
        #    decia dos.
        #    Es la misma familia que el mojibake de `_check.sh` marcandose a si
        #    mismo: un barrido que no distingue codigo de prosa acusa a la
        #    documentacion de ser el defecto que documenta.
        (my $hp_sin_com = $hp) =~ s/<!--.*?-->//gs;
        my $nmain = () = $hp_sin_com =~ /<main\b/gi;
        push @main_mal, "$p (hay $nmain)" if $nmain != 1;

        # A11Y-08 · saltos de nivel de titular
        my @lv = map { /<h([1-6])\b/i ? $1 : () } ($hp =~ /(<h[1-6]\b)/gi);
        my @s; my $prev = 0;
        for my $i (0..$#lv) { push @s, "h$prev->h$lv[$i]" if $prev && $lv[$i] > $prev+1; $prev = $lv[$i] }
        push @saltos_pag, "$p (".join(' ', @s).")" if @s;
    }
    # 🔴 Una pagina que no se ha podido leer NO se salta en silencio: si se
    #    saltara, un checkeo agregado sobre CERO paginas saldria por PASA, que es
    #    justo el fallo que este fichero existe para no cometer.
    my $leidas = scalar(@vistas) - scalar(@no_leidas);
    alcance('ACCESIBILIDAD', [@leidas], undef,
            'A11Y-01/02/05/06/07/08 sobre todas las leidas · la PALETA sobre la union de sus hojas');
    @no_leidas and nv(lente=>'ACCESIBILIDAD', id=>'A11Y-0x', titulo=>'paginas que no he podido leer',
                      donde=>join(' · ', @no_leidas[0..($#no_leidas>3?3:$#no_leidas)]),
                      ev=>[@no_leidas],
                      dato=>scalar(@no_leidas).' de '.scalar(@vistas),
                      umbral=>'todas las de la lista responden 200 con HTML',
                      proc=>'qa-maestro', hacer=>'lo que no se ha leido no esta medido, y los PASA de esta lente no hablan de ello');
    if (!$leidas) {
        nv(lente=>'ACCESIBILIDAD', id=>'A11Y-00', titulo=>'la lente entera',
           dato=>'0 de '.scalar(@vistas).' paginas legibles',
           umbral=>'al menos una pagina descargable', proc=>'qa-maestro',
           hacer=>'sin una sola pagina leida no hay accesibilidad que medir, y eso NO es un aprobado');
        return;
    }

    @sin_lang ? fallo(lente=>'ACCESIBILIDAD', id=>'A11Y-01', titulo=>'<html> sin lang',
                      donde=>join(' · ', @sin_lang[0..($#sin_lang>2?2:$#sin_lang)]),
                      ev=>[@sin_lang],
                      dato=>scalar(@sin_lang).' de '.scalar(@vistas).' paginas',
                      umbral=>'lang valido', proc=>'WCAG 3.1.1 (A)',
                      hacer=>'sin lang el lector de pantalla lee en el idioma del sistema: un texto en frances leido con voz espanola')
              : pasa(lente=>'ACCESIBILIDAD', id=>'A11Y-01', titulo=>'<html lang>', dato=>scalar(@vistas).' paginas');

    @sin_skip ? fallo(lente=>'ACCESIBILIDAD', id=>'A11Y-02', titulo=>'sin enlace de salto al contenido',
                      donde=>join(' · ', @sin_skip[0..($#sin_skip>2?2:$#sin_skip)]),
                      ev=>[@sin_skip],
                      dato=>scalar(@sin_skip).' de '.scalar(@vistas).' paginas',
                      umbral=>'1 como primer foco · en castellano, frances o portugues tambien cuenta',
                      proc=>'lo hacen 4 de 5 webs · climentmedia 0 de 45 paginas',
                      hacer=>'<a class="skip" href="#main">Saltar al contenido</a> como primer hijo de <body>')
              : pasa(lente=>'ACCESIBILIDAD', id=>'A11Y-02', titulo=>'enlace de salto al contenido', dato=>scalar(@vistas).' paginas');

    # ── A11Y-03/04 · LA PALETA (G2) ─────────────────────────────────────────
    # 🔴 Un fallo de contraste de un TOKEN se reporta como N fallos de pagina.
    #    El arreglo es UNA variable; el informe son 40 lineas. Se mide la paleta.
    my (%vars, %comments, @cssrc);
    if ($opt{css} ne '') { @cssrc = ($opt{css}) }
    else {
        my %ya;
        for my $p (@vistas) {
            my $hp = sin_com(fetch($p)->{body});
            for my $t ($hp =~ /(<link\b[^>]*>)/gi) {
                next unless (attr($t,'rel')//'') =~ /stylesheet/i;
                my $a = abs_url(attr($t,'href'), base_ef($p)) or next;
                next if $a =~ m{^https?://fonts\.(googleapis|gstatic)\.com}i;   # no trae paleta
                push @cssrc, $a unless $ya{$a}++;
            }
        }
    }
    my $css = '';
    for my $c (@cssrc) {
        if ($c =~ m{^https?://}) { my $x = fetch($c); $css .= $x->{body} if $x->{code} == 200 }
        elsif (-f $c) { if (open my $fh,'<:raw',$c) { local $/; $css .= <$fh> // ''; close $fh } }
    }
    # tokens de :root + el comentario que los acompana (X7)
    for my $line (split /\n/, $css) {
        if ($line =~ /(--[\w-]+)\s*:\s*([^;]+);/) {
            my ($n,$v) = ($1,$2); $v =~ s/\s+$//;
            $vars{$n} = $v unless exists $vars{$n};
            $comments{$n} = $1 if $line =~ m{/\*(.*?)\*/};
        }
    }
    if (!%vars) {
        nv(lente=>'ACCESIBILIDAD', id=>'A11Y-03', titulo=>'contraste de la PALETA',
           umbral=>'cada par (fondo, texto) usado en boton o texto >=4,5:1',
           proc=>'G2 · structure-gate.js §4c devuelve #010000 para todo bajo nuestras propias banderas',
           hacer=>'pasar la hoja de tokens con --css URL_O_FICHERO. Sin tokens no hay paleta que medir, y eso no es un aprobado');
    } else {
        # 🔴 Los pares NO se inventan: se leen de las REGLAS que la hoja declara.
        #    La primera version de esto emparejaba cada --X con su --X-foreground
        #    "por convencion", y acusaba a --whatsapp y --success de fallar como
        #    texto sin que nadie los use como texto. Eso es medir mi hipotesis,
        #    no el hecho: la regla de la casa dice que antes de barrer se abren
        #    dos ficheros y se mira como escriben eso de verdad. Aqui se hace
        #    solo: se recorre cada regla que declara COLOR y FONDO a la vez —que
        #    es exactamente lo que resolveria el navegador— y se mide ese par.
        my $sincom = $css; $sincom =~ s{/\*.*?\*/}{}gs;

        # ── 1) EL FONDO DE LA PAGINA, LEIDO. NO ASUMIDO (arreglo 0.1) ───────
        my ($bg_pagina, $bg_crudo) = fondo_de_pagina($sincom, \%vars);

        # ── 2) Mapa de fondos declarados, para resolver el de un ANCESTRO ───
        #    `.cta-band p { color:#c5d2df }` no dice su fondo: lo pone
        #    `.cta-band { background: linear-gradient(...) }`. Heredar ahi el
        #    fondo de la pagina es el MISMO error que asumir blanco, un nivel
        #    mas abajo. Se busca el fondo del ancestro en la propia hoja.
        my (%BG_SEL, %BG_ULT);
        {
            my $cp = $sincom;
            while ($cp =~ /([^{}]*)\{([^{}]*)\}/g) {
                my ($sel, $body) = ($1, $2);
                my ($bv) = $body =~ /background(?:-color)?\s*:\s*([^;]+)/;
                next unless defined $bv;
                for my $s (split /\s*,\s*/, $sel) {
                    $s =~ s/^\s+|\s+$//g; next if $s eq '' || $s =~ /^[\@]/;
                    # ⚠️ Un ::before con `background` es una LINEA decorativa, no
                    #    el fondo del elemento. Tomarlo por fondo hizo que
                    #    `.or-divider` se midiera contra el gris de su propia
                    #    rayita: 2,56:1 inventado.
                    next if $s =~ /::/;
                    # ⚠️ Y el fondo de un ESTADO no es el fondo en reposo. Con
                    #    `.cc__link{background:none}` + `.cc__link:hover{...}`
                    #    la clase parecia tener «2 fondos distintos» y el par se
                    #    declaraba no medible: eso APAGABA su 4,11:1, que es real.
                    next if $s =~ /:(hover|focus|focus-visible|active|checked|visited|target)\b/;
                    push @{ $BG_SEL{$s} }, $bv;
                    my @p = grep { length } split /\s*(?:>|\s)\s*/, $s;
                    next unless @p;
                    (my $ult = $p[-1]) =~ s/:{1,2}[\w-]+(\([^)]*\))?//g;   # sin pseudo
                    # ⚠️ Y SOLO por clase o id. Indexar por el nombre del
                    #    elemento (`li`, `p`, `svg`) empareja cualquier cosa con
                    #    cualquier cosa: `.about-facts li` salio medido contra el
                    #    naranja de una lista que no tiene nada que ver (1,01:1).
                    push @{ $BG_ULT{$ult} }, $bv if $ult =~ /^[.#][\w-]+$/;
                }
            }
        }
        # Resuelve una lista de valores a UN color, o dice por que no puede.
        my $unico = sub {
            my ($lista) = @_;
            return (undef,'') unless $lista && @$lista;
            my (%d, $ok);
            for my $v (@$lista) {
                my $c = css_rgba($v, \%vars);
                if (!$c) { return (undef,'no resoluble (degradado o imagen)') }
                my $op = componer($c, $bg_pagina);
                return (undef,'translucido sin fondo de pagina conocido') unless $op;
                $d{ sprintf('%02x%02x%02x', @$op) } = $op; $ok = $op;
            }
            return (undef,'la hoja le da '.scalar(keys %d).' fondos distintos') if keys(%d) > 1;
            return ($ok,'');
        };
        # Un componente de selector (clase o id) -> el fondo que le pinta la hoja.
        # Incluye la convencion BEM que usan las cinco hojas: `.lightbox__close`
        # vive dentro de `.lightbox`, y `.lightbox` SI declara su fondo. Sin
        # esto, el boton de cerrar del visor se media contra el lienzo de la
        # pagina (1,05:1) en vez de contra el velo oscuro que tiene detras.
        my $por_clase = sub {
            my ($k) = @_;
            return () unless defined $k && $k =~ /^[.#][\w-]+$/;
            if ($BG_ULT{$k}) { my ($c,$w) = $unico->($BG_ULT{$k}); return ($c,$w,"por $k") }
            if ($k =~ /^\.([\w-]+)__[\w-]+$/ && $BG_ULT{".$1"}) {
                my ($c,$w) = $unico->($BG_ULT{".$1"}); return ($c,$w,"bloque .$1");
            }
            return ();
        };
        # SOLO ancestros: nunca el propio elemento. Es lo que hay DEBAJO de el, y
        # por eso sirve tambien para componer su propio fondo translucido.
        my $solo_ancestros = sub {
            my ($sel) = @_;
            my @p = grep { length } split /\s*(?:>|\s)\s*/, $sel;
            for (my $i = $#p-1; $i >= 0; $i--) {                 # del mas cercano al mas lejano
                my $pref = join ' ', @p[0..$i];
                if ($BG_SEL{$pref}) { my ($c,$w) = $unico->($BG_SEL{$pref}); return ($c,$w,"ancestro $pref") }
                (my $ult = $p[$i]) =~ s/:{1,2}[\w-]+(\([^)]*\))?//g;
                my @r = $por_clase->($ult);
                return ($r[0], $r[1], "ancestro $r[2]") if @r;
            }
            if (@p) {                                            # BEM: el bloque del propio elemento
                (my $ult = $p[-1]) =~ s/:{1,2}[\w-]+(\([^)]*\))?//g;
                if ($ult =~ /^\.([\w-]+)__[\w-]+$/ && $BG_ULT{".$1"}) {
                    my ($c,$w) = $unico->($BG_ULT{".$1"}); return ($c,$w,"bloque .$1");
                }
            }
            return (undef,'','');
        };
        my $fondo_heredado = sub {
            my ($sel) = @_;
            my @r = $solo_ancestros->($sel);
            return @r if defined $r[0] || $r[1];
            # el propio elemento, pintado por una regla con mas contexto:
            # `.result--catalog .result__banner { background: ... }` para
            # `.result__banner { color:#fff }`
            my @p = grep { length } split /\s*(?:>|\s)\s*/, $sel;
            if (@p) {
                (my $ult = $p[-1]) =~ s/:{1,2}[\w-]+(\([^)]*\))?//g;
                my @s = $por_clase->($ult);
                return ($s[0], $s[1], $s[2]) if @s;
            }
            return (undef,'','');
        };

        my (@pares, %vistos, @no_medibles);
        while ($sincom =~ /([^{}]*)\{([^{}]*)\}/g) {
            my ($sel, $body) = ($1, $2);
            $sel =~ s/^\s+|\s+$//g;
            next if $sel =~ /^[\@:]/ || $sel eq '';        # @font-face, :root, @media...
            next if $sel =~ /::(before|after|selection)/;   # pseudo-elementos decorativos
            my ($cv) = $body =~ /(?:^|;|\s)color\s*:\s*([^;]+)/;
            my ($bv) = $body =~ /background(?:-color)?\s*:\s*([^;]+)/;
            next unless defined $cv;
            my $fg_a = css_rgba($cv, \%vars) or next;      # gradiente/currentColor => no medible
            my $bgc;                                        # fondo OPACO sobre el que se pinta
            my $origen_bg;
            my $b_propio = defined $bv ? css_rgba($bv, \%vars) : undef;
            if (defined $bv && !$b_propio) {
                push @no_medibles, substr($sel,0,52).' (su propio fondo no es un color: degradado o imagen)'; next;
            }
            # Un fondo declarado con alfa CERO (`none`, `transparent`,
            # `rgba(...,0)`) no pinta nada: lo que se ve es el de detras. Se
            # trata igual que si no lo hubiera declarado.
            undef $bv if $b_propio && defined $b_propio->[3] && $b_propio->[3] <= 0.001;
            if (defined $bv) {
                my $b = $b_propio;
                # Un fondo TRANSLUCIDO se compone sobre lo que tiene DEBAJO, que
                # es el ancestro, no el lienzo de la pagina. `.lightbox__close`
                # es rgba(255,255,255,.16) sobre el velo oscuro de `.lightbox`:
                # componerlo sobre el lienzo daba 1,05:1, que no existe.
                my $alfa = defined $b->[3] ? $b->[3] : 1;
                my $debajo = $bg_pagina;
                $origen_bg = 'declarado en la regla';
                if ($alfa < 0.999) {
                    my ($c,$why,$de) = $solo_ancestros->($sel);
                    if ($c) { $debajo = $c; $origen_bg = "translucido sobre $de" }
                }
                $bgc = componer($b, $debajo);
                if (!$bgc) { push @no_medibles, substr($sel,0,52).' (fondo translucido y no se que hay debajo)'; next }
            } else {
                # ⚠️ Una regla de ESTADO que cambia solo el color no dice cual es
                #    su fondo: lo pone la regla hermana del mismo estado. Asumir
                #    el fondo de pagina ahi produjo un falso suspenso real
                #    (.chips--link li:hover a = «1,03:1», que no existe: el
                #    li:hover pinta el fondo).
                if ($sel =~ /:(hover|focus|active|checked|visited)|\[aria-/) {
                    push @{$vistos{__estado}}, substr($sel,0,52); next;
                }
                my ($c,$why,$de) = $fondo_heredado->($sel);
                if ($c) { $bgc = $c; $origen_bg = $de }
                elsif ($why) { push @no_medibles, substr($sel,0,52)." ($why)"; next }
                elsif ($bg_pagina) { $bgc = $bg_pagina; $origen_bg = 'el de la pagina' }
                else { push @no_medibles, substr($sel,0,52).' (no se el fondo de la pagina)'; next }
            }
            my $fg = componer($fg_a, $bgc);
            if (!$fg) { push @no_medibles, substr($sel,0,52).' (texto translucido sin fondo conocido)'; next }
            # texto grande: 3:1 en vez de 4,5:1 (WCAG 1.4.3)
            my ($fs) = $body =~ /font-size\s*:\s*([\d.]+)(rem|px|em)/;
            my $px = defined $fs ? ($2 eq 'px' ? $fs : $fs*16) : 16;
            my $bold = $body =~ /font-weight\s*:\s*(bold|[7-9]00)/ ? 1 : 0;
            my $min = ($px >= 24 || ($px >= 18.66 && $bold)) ? 3.0 : 4.5;
            my $clave = sprintf('%02x%02x%02x-%02x%02x%02x-%s', @$fg, @$bgc, $min);
            next if $vistos{$clave}++;
            push @pares, { nombre=>substr($sel,0,52), a=>$fg, b=>$bgc, min=>$min, de=>$origen_bg };
        }

        # ── 3) CENTINELA · un 1,00:1 es imposible entre colores distintos ───
        #    Si el resolutor devuelve el MISMO color para texto y fondo, no es
        #    que la web sea invisible: es que este instrumento se ha equivocado.
        #    Antes salia como FALLO («.st-live #35d07f sobre #35d07f») y era el
        #    alfa perdido. Se queda como centinela por si vuelve por otra via:
        #    grita, y NO cuenta como defecto de la web.
        my (@malos, @imposibles);
        for my $p (@pares) {
            my $r = contrast($p->{a}, $p->{b});
            my $mismo = (sprintf('%02x%02x%02x',@{$p->{a}}) eq sprintf('%02x%02x%02x',@{$p->{b}})) ? 1 : 0;
            if ($mismo || $r < 1.0005) {
                push @imposibles, sprintf('%s : #%02x%02x%02x sobre #%02x%02x%02x = %.2f:1 (fondo: %s)',
                                          $p->{nombre}, @{$p->{a}}, @{$p->{b}}, $r, $p->{de});
                next;
            }
            push @malos, sprintf('%s : #%02x%02x%02x sobre #%02x%02x%02x = %.2f:1 (necesita %.1f · fondo %s)',
                                 $p->{nombre}, @{$p->{a}}, @{$p->{b}}, $r, $p->{min}, $p->{de}) if $r < $p->{min};
        }
        @imposibles and nv(lente=>'ACCESIBILIDAD', id=>'A11Y-03z', titulo=>'CENTINELA: el instrumento ha devuelto un ratio imposible',
                           donde=>join("\n                 ", @imposibles[0..($#imposibles>3?3:$#imposibles)]),
                           ev=>[@imposibles],
                           dato=>scalar(@imposibles).' pares con ratio 1,00:1',
                           umbral=>'ningun par con dos colores distintos puede dar 1,00:1',
                           proc=>'centinela anadido el 10-ago-2026 · el caso original era `rgba(var(--ok-rgb),.16)` con el alfa tirado, que devolvia el color del texto como fondo',
                           hacer=>'🔴 NO arregles la web por esto: arregla el gate. Estos pares NO cuentan como fallo de contraste');

        if (!$bg_pagina) {
            nv(lente=>'ACCESIBILIDAD', id=>'A11Y-03a', titulo=>'el fondo de la pagina no se ha podido resolver',
               dato=>'la hoja no declara un `body { background: ... }` que este resolutor entienda',
               umbral=>'`body { background: <color> }` resoluble, o medirlo en navegador',
               proc=>'arreglo 0.1 · antes se ASUMIA blanco y eso emitia 12 celdas falsas en climentmedia (fondo real rgb(7,7,8)) y suspendia entera a site-c (oklch(16% ...))',
               hacer=>'pasar la hoja correcta con --css, o medir en navegador. Solo se han medido los pares que declaran su fondo: los demas van en A11Y-03b');
        }

        if (!@pares) {
            nv(lente=>'ACCESIBILIDAD', id=>'A11Y-03', titulo=>'contraste de la PALETA',
               dato=>'la hoja no declara ninguna regla con color y fondo resolubles',
               umbral=>'>=4,5:1 texto normal · >=3:1 texto grande y UI',
               proc=>'G2', hacer=>'medirlo en navegador, o pasar la hoja de tokens correcta con --css. «No medible» no es «aprobado»');
        } elsif (@malos) {
            fallo(lente=>'ACCESIBILIDAD', id=>'A11Y-03', titulo=>'la PALETA no llega a AA',
                  donde=>join("\n                 ", @malos),
                  dato=>scalar(@malos).' pares de '.scalar(@pares)
                        .' · fondo de pagina: '.($bg_crudo ? sprintf('%s = #%02x%02x%02x', $bg_crudo, @$bg_pagina) : 'NO RESUELTO'),
                  umbral=>'>=4,5:1 texto normal · >=3:1 texto grande y elementos de UI (WCAG 1.4.3 / 1.4.11)',
                  proc=>'G2 · el arreglo es UNA variable, no 40 paginas. Calibrado: reproduce el navegador (0,58 -> 4,11 y 4,01; 0,54 -> 4,79)',
                  hacer=>'bajar la luminosidad del token hasta que pase, y VOLVER A CORRER esto. En site-d la tabla es L=0,58 -> 4,02 FALLA · 0,55 -> 4,59 raspando · 0,54 -> 4,79 PASA');
        } else {
            pasa(lente=>'ACCESIBILIDAD', id=>'A11Y-03', titulo=>'la paleta llega a AA',
                 dato=>scalar(@pares).' pares medidos sobre fondo '
                       .($bg_crudo ? sprintf('%s = #%02x%02x%02x', $bg_crudo, @$bg_pagina) : 'declarado en cada regla'));
        }
        {
            my @e = (($vistos{__estado} ? @{$vistos{__estado}} : ()), @no_medibles);
            @e and nv(lente=>'ACCESIBILIDAD', id=>'A11Y-03b', titulo=>'reglas cuyo fondo real no se puede saber leyendo la hoja',
                      donde=>join(' · ', @e[0..($#e>3?3:$#e)]),
                      ev=>[@e],
                      dato=>scalar(@e).' reglas',
                      umbral=>'>=4,5:1 tambien en hover, focus y sobre degradado',
                      proc=>'G2 · asumir el fondo de pagina aqui produjo un falso suspenso de 1,03:1 en site-a que no existe · y «.cta-band p sobre blanco» cuando .cta-band pinta un degradado oscuro',
                      hacer=>'pasar el raton por encima con el inspector abierto, o medirlo con el snippet. Un hover ilegible es un defecto que solo ve quien usa el raton despacio');
        }

        # X7 · el comentario de un color NO es una medicion
        my @mienten;
        for my $tok (sort keys %comments) {
            my $c = css_color($vars{$tok} // '', \%vars) or next;
            my ($dec) = $comments{$tok} =~ /(\d+[.,]\d+)\s*:\s*1/ or next;
            (my $decn = $dec) =~ s/,/./;
            my $ref = $comments{$tok} =~ /blanco|white|fond|background/i
                    ? [255,255,255]
                    : (css_color($vars{'--primary-foreground'} // '#ffffff', \%vars) // [255,255,255]);
            my $real = contrast($c, $ref);
            my $alt  = contrast($c, [255,255,255]);
            # se le concede el mejor de los dos candidatos: acusar por elegir mal
            # la referencia seria acusar al instrumento, no al codigo.
            my $best = abs($real-$decn) < abs($alt-$decn) ? $real : $alt;
            push @mienten, sprintf('%s dice %s:1 y son %.2f:1', $tok, $dec, $best) if abs($best - $decn) > 0.15;
        }
        @mienten ? fallo(lente=>'ACCESIBILIDAD', id=>'A11Y-04', titulo=>'el comentario del color no coincide con el color',
                         donde=>join("\n                 ", @mienten),
                         umbral=>'|comentario - real| <= 0,15',
                         proc=>'X7 · site-a/styles.css:27 dice «4,84:1 sobre blanco» y son 4,11:1 · el CSS de site-d avisa dos lineas antes: «no fiarse de un comentario para un color»',
                         hacer=>'corregir el comentario Y el color. Un comentario falso sobrevive a la migracion y nadie lo vuelve a medir')
                : (%comments ? pasa(lente=>'ACCESIBILIDAD', id=>'A11Y-04', titulo=>'los comentarios de contraste coinciden con el color') : ());
    }

    # A11Y-05 · SVG decorativo sin marcar dentro de enlace o boton (todas)
    @svg_mal ? fallo(lente=>'ACCESIBILIDAD', id=>'A11Y-05', titulo=>'SVG sin aria-hidden ni nombre',
                     donde=>join(' · ', @svg_mal[0..($#svg_mal>2?2:$#svg_mal)]),
                     ev=>[@svg_mal],
                     dato=>"$n_svg_mal SVG en ".scalar(@svg_mal).' de '.scalar(@vistas).' paginas',
                     umbral=>'0 · decorativo => aria-hidden="true"; informativo => role="img" + aria-label',
                     proc=>'lo hacen bien 4 de 5 webs · site-b: 184 SVG sin marcar dentro de enlaces',
                     hacer=>'un SVG sin marcar dentro de un enlace hace que el lector lea el enlace dos veces o no lo lea')
             : pasa(lente=>'ACCESIBILIDAD', id=>'A11Y-05', titulo=>'SVG marcados', dato=>scalar(@vistas).' paginas');

    # A11Y-06 · enlace/boton sin nombre accesible (todas)
    @mudos ? fallo(lente=>'ACCESIBILIDAD', id=>'A11Y-06', titulo=>'enlace o boton sin nombre accesible',
                   donde=>join("\n                 ", @mudos[0..($#mudos>2?2:$#mudos)]),
                   ev=>[@mudos],
                   dato=>scalar(@mudos).' en '.scalar(@vistas).' paginas',
                   umbral=>'0', proc=>'WCAG 4.1.2 (A)',
                   hacer=>'aria-label con lo que HACE, no con lo que es ("Llamar al 91...", no "telefono")')
           : pasa(lente=>'ACCESIBILIDAD', id=>'A11Y-06', titulo=>'todos los controles tienen nombre', dato=>scalar(@vistas).' paginas');

    # A11Y-07 · un solo <main> (todas)
    @main_mal ? fallo(lente=>'ACCESIBILIDAD', id=>'A11Y-07', titulo=>'<main>: no hay exactamente uno',
                      donde=>join(' · ', @main_mal[0..($#main_mal>2?2:$#main_mal)]),
                      ev=>[@main_mal],
                      dato=>scalar(@main_mal).' de '.scalar(@vistas).' paginas',
                      umbral=>'exactamente 1', proc=>'WCAG 1.3.1 · el enlace de salto necesita destino',
                      hacer=>'un solo <main id="main">, y que el skip link apunte ahi')
              : pasa(lente=>'ACCESIBILIDAD', id=>'A11Y-07', titulo=>'un <main>', dato=>scalar(@vistas).' paginas');

    # A11Y-08 · saltos de nivel de titular (todas)
    #  🔴 Este es EL caso de la loteria del orden: medido sobre una sola pagina,
    #     el veredicto cambiaba segun cual fuera la primera de la lista.
    @saltos_pag ? fallo(lente=>'ACCESIBILIDAD', id=>'A11Y-08', titulo=>'saltos de nivel de titular',
                        donde=>join("\n                 ", @saltos_pag[0..($#saltos_pag>3?3:$#saltos_pag)]),
                        ev=>[@saltos_pag],
                        dato=>scalar(@saltos_pag).' de '.scalar(@vistas).' paginas con saltos',
                        umbral=>'0', proc=>'WCAG 1.3.1 · site-d: 10 saltos',
                        hacer=>'los niveles son el indice por el que navega un lector de pantalla: no se saltan para elegir un tamano, se elige el tamano con CSS')
                : pasa(lente=>'ACCESIBILIDAD', id=>'A11Y-08', titulo=>'jerarquia de titulares sin saltos', dato=>scalar(@vistas).' paginas');

    # ── FORMULARIO (G8) ─────────────────────────────────────────────────────
    my $formsrc = $h;
    # La huella tiene que IDENTIFICAR algo: "la pagina del --dom" no vale como
    # hallazgo, porque no dice cual es. Se compone la URL de verdad.
    my $form_de  = $ROOT . ($opt{dom} ne '' ? $opt{dom} : '/');
    my $curl_contacto = $opt{contacto} ne '' ? "$ROOT$opt{contacto}" : '';
    # 19-ago-2026 - SIN --contacto, LAS TRES DE ABAJO NO SE EMITIAN. Ni PASA, ni
    #   FALLO, ni NO VERIFICADO: desaparecian del informe. La linea era
    #   `$formsrc = fetch(...)->{body} // $h`, y ese `// $h` sustituia por la
    #   PORTADA -que no tiene formulario- en cuanto la bandera venia vacia, que es
    #   su valor por defecto. Medido en site-c.example: con la bandera A11Y-10
    #   sale FALLO; sin ella el informe baja de 2 fallos a 1 y no dice que falte
    #   nada. El veredicto dependia de que alguien se acordara de una bandera.
    #   Ahora el formulario SE BUSCA entre las paginas ya leidas (fetch cachea, no
    #   cuesta red) y, si no aparece en ninguna, se DICE en vez de callarse.
    if ($h !~ /<form\b/i) {
        for my $u (grep { $_ } ($curl_contacto, @PAGES)) {
            my $b = fetch($u)->{body} // '';
            next unless $b =~ /<form\b/i;
            $formsrc = $b; $form_de = $u; last;
        }
    }
    if ($formsrc !~ /<form\b/i) {
        for my $f (['A11Y-09','campos con autocomplete'],
                       ['A11Y-10','region viva para los errores del formulario'],
                       ['A11Y-11','honeypot blindado para lector de pantalla']) {
            nv(lente=>'ACCESIBILIDAD', id=>$f->[0], titulo=>$f->[1],
               dato=>'ninguna de las '.scalar(@PAGES).' paginas leidas trae un <form>',
               umbral=>'si el sitio tiene formulario, esto TIENE que medirse: es la unica conversion de la mayoria',
               proc=>'G8 - antes del 19-ago estas tres se saltaban en silencio cuando no habia --contacto',
               hacer=>'si hay formulario y no sale aqui, pasar --contacto /ruta/ y volver a correr: el gate no lo esta viendo');
        }
    }
    if ($formsrc =~ /<form\b/i) {
        my (@sin_ac, $honeypot_ok, $honeypot);
        for my $inp ($formsrc =~ /(<input\b[^>]*>|<textarea\b[^>]*>)/gi) {
            my $type = lc(attr($inp,'type') // 'text');
            next if $type =~ /^(hidden|submit|button|checkbox|radio)$/;
            my $name = lc(attr($inp,'name') // attr($inp,'id') // '');
            # 🔴 17-ago-2026 · EL DETECTOR NO VEIA EL CEPO QUE TENEMOS EN VIVO.
            #    Buscaba `honeypot|hp_|_gotcha|bot-field`, y el de
            #    site-d.example se llama **`website`** -- el nombre clasico
            #    de cepo, precisamente porque parece un campo normal. Resultado:
            #    A11Y-11 no se disparaba NUNCA sobre el unico formulario del
            #    parque que tiene uno, y ese cepo estaba VISIBLE en pantalla.
            #    Se anaden los tres nombres clasicos (`website`, `url`, `fax`) y
            #    el `tabindex=-1`, que es marcado de ocultacion accesible.
            #    Se alinea a proposito con `forms-gate.js` F3: dos gates
            #    que miran lo mismo con dos listas distintas acaban discrepando.
            if ($inp =~ /(honeypot|hp_|_gotcha|bot-field)/i
                || $name =~ /^(website|url|fax)$/
                || $inp =~ /tabindex=["']?-1/i
                || ($inp =~ /style=["'][^"']*(display:\s*none|left:\s*-9)/i)) {
                $honeypot = 1;
                $honeypot_ok = 1 if $inp =~ /aria-hidden/i && $inp =~ /tabindex=["']?-1/i && $inp =~ /autocomplete=["']off/i;
                next;
            }
            next unless $name =~ /(nom|name|mail|tel|phone|apellido|surname|prenom)/;
            push @sin_ac, ($name || substr($inp,0,40)) unless attr($inp,'autocomplete');
        }
        @sin_ac ? fallo(lente=>'ACCESIBILIDAD', id=>'A11Y-09', titulo=>'campos sin autocomplete',
                        donde=>join(' · ', @sin_ac), dato=>scalar(@sin_ac).' campos',
                        umbral=>'given-name / family-name / email / tel en todo campo de identidad',
                        proc=>'G8 · WCAG 1.3.5 (AA) · lo hace bien site-c (3/3); site-a 18 campos sin el, site-d 3',
                        hacer=>'autocomplete="given-name|family-name|email|tel". Ahorra teclear en movil, que es donde llega el lead')
                : pasa(lente=>'ACCESIBILIDAD', id=>'A11Y-09', titulo=>'campos con autocomplete');

        ($formsrc =~ /aria-live=|role=["']alert["']/i)
          ? pasa(lente=>'ACCESIBILIDAD', id=>'A11Y-10', titulo=>'region viva para los errores del formulario',
                donde=>$form_de)
          : fallo(lente=>'ACCESIBILIDAD', id=>'A11Y-10', titulo=>'sin region viva para los errores',
                  donde=>$form_de,
                  umbral=>'un contenedor con aria-live="polite" o role="alert"',
                  proc=>'G8 · 0 en site-d, site-a y site-c',
                  hacer=>'quien no ve la pantalla no se entera de que el formulario ha fallado: se queda esperando');

        if ($honeypot) {
            $honeypot_ok ? pasa(lente=>'ACCESIBILIDAD', id=>'A11Y-11', titulo=>'honeypot accesible')
                         : aviso(lente=>'ACCESIBILIDAD', id=>'A11Y-11', titulo=>'honeypot sin blindar para lector de pantalla',
                                 umbral=>'aria-hidden="true" + tabindex="-1" + autocomplete="off"',
                                 proc=>'buena practica sin documentar: la hacen TRES webs nuestras y no esta escrita en ningun sitio',
                                 hacer=>'sin los tres atributos, un lector de pantalla anuncia el campo trampa y el usuario lo rellena: se le descarta el lead');
        }
    }

    # ── Lo que NO se puede afirmar sin navegador ni sin persona ──────────────
    # Sospecha de metodo: 44x44 es AAA. El criterio AA aplicable (2.5.8, 24x24)
    # lo pasan las cinco webs. NO se promueve a fallo: seria acusar por un
    # criterio que no aplica.
    aviso(lente=>'ACCESIBILIDAD', id=>'A11Y-12', titulo=>'tamano tactil: 44x44 es AAA, NO es fallo',
          umbral=>'AA = 24x24 (WCAG 2.2 SC 2.5.8) con la excepcion de espaciado · 44x44 es solo referencia',
          proc=>'sospecha de metodo de la sintesis: sin implementar la excepcion de espaciado salian 16 falsos suspensos solo en la home de site-d',
          hacer=>'no arreglar nada por este numero. Si se quiere subir a 44, es decision de diseno, no correccion de defecto');

    nv(lente=>'ACCESIBILIDAD', id=>'A11Y-13', titulo=>'teclado real y lector de pantalla',
       umbral=>'recorrer con Tab: orden logico, foco siempre visible, sin trampa en el banner ni en el menu movil',
       proc=>'PC8 · el foco se midio con .focus() programatico, que NO es tabular; 1.094 elementos quedaron fuera por invisibles',
       hacer=>'10 minutos con Tab y 10 con NVDA/VoiceOver. Es lo unico que prueba esto, y no lo sustituye ningun script');

    nv(lente=>'ACCESIBILIDAD', id=>'A11Y-14', titulo=>'texto sobre foto o degradado',
       umbral=>'>=4,5:1 sobre la zona real de la imagen',
       proc=>'PC13 · 167 elementos no medibles con getComputedStyle en las 5 webs (site-b 70 · site-a 40 · cm 35 · site-c 18 · bc 4)',
       hacer=>'references/measure-contrast-on-photo.py YA EXISTE. «No medible» no es «aprobado»');
}

# =============================================================================
#  7 · LENTE 4 · MEDICION Y LEGAL
#     Procedencia: G1 · G9 · G12 · G13 · PC1 · PC3 · PC5 · 04-medicion.md
# =============================================================================
sub lente_medicion {
    unless ($NET_OK) {
        nv(lente=>'MEDICION', id=>'MED-00', titulo=>'la lente entera', umbral=>'requiere red',
           proc=>'qa-maestro', hacer=>'sin descarga no hay contenedor que cruzar');
        return;
    }
    my $h = sin_com($HOME->{body});
    my @vistas = @PAGES;
    # 🔴 ARREGLO 0.3 · el contenedor, la politica y el cruce son del SITIO y se
    #    miden en la home; pero el orden del consent y las casillas premarcadas
    #    son de CADA pagina, y aqui se miraba solo una. Se declara que mira que.
    alcance('MEDICION', [@vistas], undef,
            'MED-02 y MED-06 sobre todas · MED-01/03/05/07/08 son del sitio (home + contenedor) · MED-10/11 la de contacto');

    my ($gtm) = $h =~ /\b(GTM-[A-Z0-9]+)\b/;
    if (!$gtm) { for my $p (@vistas) { my $b = fetch($p)->{body} // ''; ($gtm) = $b =~ /\b(GTM-[A-Z0-9]+)\b/; last if $gtm } }

    if (!$gtm) {
        my ($ga) = $h =~ /\b(G-[A-Z0-9]{8,}|AW-\d+)\b/;
        $ga ? aviso(lente=>'MEDICION', id=>'MED-01', titulo=>'medicion directa, sin contenedor', dato=>$ga,
                    umbral=>'GTM si hay publicidad', proc=>'04-medicion §1',
                    hacer=>'sin contenedor no se puede cambiar la medicion sin tocar la web. Correcto si el cliente no hace publicidad')
            : aviso(lente=>'MEDICION', id=>'MED-01', titulo=>'sin medicion ninguna',
                    umbral=>'correcto si el cliente no mide · FALLO si hace publicidad', proc=>'qa-final.sh §3',
                    hacer=>'climentmedia.com esta asi: cero eventos, y sus CTA apuntan a servidor NUESTRO —se podrian contar en el log sin anadir un tercero. «Vendemos medicion de anuncios y no sabemos cuanta gente pulsa el boton» (PC16)');
    } else {
        pasa(lente=>'MEDICION', id=>'MED-01', titulo=>'contenedor', dato=>$gtm);

        # MED-02 · orden del consent
        # ⚠️ Patron tolerante a espacios: `consent', 'default'` no casa con
        #    `consent'*,*'*default`. Ese error dio un falso FALLO en la auditoria.
        my (@sin_consent, @consent_tarde);
        for my $p (@vistas) {
            my $b = sin_com(fetch($p)->{body});   # los comentarios fuera ANTES del filtro: uno que nombre GTM hacia entrar aqui a una pagina sin contenedor
            next unless $b =~ /\bGTM-[A-Z0-9]+\b|googletagmanager\.com/;   # sin contenedor no aplica
            # 🔴 17-ago-2026 · SIN QUITAR LOS COMENTARIOS, ESTE CHECK SE APRUEBA
            #    CON UN COMENTARIO. Salio escribiendo su propio caso: el fixture
            #    llevaba `<!-- MED-02 · GTM PRIMERO y el consent default
            #    DESPUES -->` ANTES del contenedor, y el gate leyo ESE «consent
            #    default» como la declaracion. Una pagina que carga GTM antes
            #    del consentimiento salia PASA.
            #    Es PEOR que el mismo fallo en A11Y-07, que solo daba un falso
            #    positivo: aqui un comentario APRUEBA un check de cumplimiento
            #    que deberia suspender, y el dano cae en el visitante al que se
            #    le ponen cookies sin haber aceptado nada.
            my $gp  = index($b, 'googletagmanager.com/gtm.js');
            my $cp2 = ($b =~ /consent['"]?\s*,?\s*['"]?default/) ? $-[0] : -1;
            if    ($cp2 < 0)                 { push @sin_consent, $p }
            elsif ($gp >= 0 && $cp2 > $gp)   { push @consent_tarde, $p }
        }
        if (@sin_consent) {
            fallo(lente=>'MEDICION', id=>'MED-02', titulo=>'sin consent default: cookies antes de aceptar',
                  donde=>join(' · ', @sin_consent[0..($#sin_consent>2?2:$#sin_consent)]),
                  ev=>[@sin_consent],
                  dato=>scalar(@sin_consent).' de '.scalar(@vistas).' paginas',
                  umbral=>'gtag("consent","default",...) ANTES de cargar el contenedor', proc=>'04-medicion §3',
                  hacer=>'el bloque de consent default va inline en el <head>, delante de todo');
        } elsif (@consent_tarde) {
            fallo(lente=>'MEDICION', id=>'MED-02', titulo=>'consent default DESPUES del contenedor',
                  donde=>join(' · ', @consent_tarde[0..($#consent_tarde>2?2:$#consent_tarde)]),
                  ev=>[@consent_tarde],
                  dato=>scalar(@consent_tarde).' de '.scalar(@vistas).' paginas',
                  umbral=>'antes', proc=>'04-medicion §3', hacer=>'moverlo arriba: cuando llega, las cookies ya estan puestas');
        } else {
            pasa(lente=>'MEDICION', id=>'MED-02', titulo=>'consent default antes del contenedor', dato=>scalar(@vistas).' paginas');
        }

        # ── MED-03 · EL CRUCE (G1) · el gate mas caro que faltaba ────────────
        my $cont = fetch("https://www.googletagmanager.com/gtm.js?id=$gtm");
        if ($cont->{code} != 200 || length($cont->{body}) < 1000) {
            nv(lente=>'MEDICION', id=>'MED-03', titulo=>'cruce eventos <-> disparadores del contenedor',
               dato=>"gtm.js?id=$gtm devolvio HTTP $cont->{code}",
               umbral=>'todo evento emitido tiene disparador, y todo disparador tiene emisor',
               proc=>'G1 · qa-final.sh §3 cuenta las dos listas y NUNCA las cruza',
               hacer=>'reintentar; si el contenedor no es publico, el cruce se hace en la interfaz de GTM a mano');
        } else {
            my $cjs = $cont->{body};
            # eventos que EMITE el sitio: marcado + JS servido + la de gracias
            my %emit;
            my @scan = ($h);
            for my $t ($h =~ /(<script\b[^>]*>)/gi) {
                my $src = attr($t,'src') or next;
                my $a = abs_url($src, $ROOT.'/') or next;
                next unless is_internal($a);
                my $x = fetch($a); push @scan, $x->{body} if $x->{code} == 200;
            }
            if ($opt{gracias} ne '') {
                my $g = fetch("$ROOT$opt{gracias}");
                push @scan, $g->{body} if $g->{code} == 200;
                for my $t (($g->{body}//'') =~ /(<script\b[^>]*>)/gi) {
                    my $src = attr($t,'src') or next;
                    my $a = abs_url($src, "$ROOT$opt{gracias}") or next;
                    next unless is_internal($a);
                    my $x = fetch($a); push @scan, $x->{body} if $x->{code} == 200;
                }
            }
            for my $s (@scan) {
                next unless defined $s;
                # ⚠️ `$emit{$1}++ for $s =~ /.../g` ES UN BUG SILENCIOSO: en un
                #    `for` modificador, `$1` ya no cambia por elemento —guarda la
                #    ULTIMA captura— asi que N eventos distintos se cuentan todos
                #    bajo el nombre del ultimo. Me mordio al escribir esto: el
                #    cruce de site-d reportaba 2 eventos donde habia 7.
                #    Con `$_` cada elemento es el suyo.
                $emit{$_}++ for $s =~ /data-event\s*=\s*["']([a-z0-9_]+)["']/gi;
                $emit{$_}++ for $s =~ /['"]event['"]\s*:\s*['"]([a-z0-9_]+)['"]/gi;
                $emit{$_}++ for $s =~ /gtag\(\s*['"]event['"]\s*,\s*['"]([a-z0-9_]+)['"]/gi;
                $emit{$_}++ for $s =~ /data-thanks\s*=\s*["']([a-z0-9_]+)["']/gi;
            }
            delete $emit{$_} for qw(gtm_js gtm_dom gtm_load js config);
            # nombres que el CONTENEDOR conoce
            my @sinescucha = grep { index($cjs, "\"$_\"") < 0 && index($cjs, "'$_'") < 0 } sort keys %emit;
            if (@sinescucha) {
                fallo(lente=>'MEDICION', id=>'MED-03', titulo=>'evento emitido que el contenedor NO escucha',
                      donde=>join(' · ', @sinescucha),
                      dato=>scalar(@sinescucha).' de '.scalar(keys %emit).' eventos emitidos',
                      umbral=>'0 · todo nombre emitido aparece en gtm.js',
                      proc=>'G1 · site-d emite page_view_gracias y el contenedor escucha thank_you_view: TRES etiquetas de Ads que no han disparado nunca',
                      hacer=>'o se renombra el evento en la pagina, o se anade el disparador en GTM. Y despues se comprueba en Ads que llega (MED-13)');
            } elsif (%emit) {
                pasa(lente=>'MEDICION', id=>'MED-03', titulo=>'todo evento emitido tiene disparador',
                     dato=>join(' ', sort keys %emit));
            } else {
                aviso(lente=>'MEDICION', id=>'MED-03', titulo=>'el sitio no emite ningun evento con nombre',
                      umbral=>'>=1 evento de conversion', proc=>'G1',
                      hacer=>'puede ser correcto si el disparador es por URL (site-a usa _cn(PATH,"/merci")). Comprobar en GTM que existe ese disparador, y anotarlo: es el mecanismo REAL, no el que documentamos');
            }

            # G9 · politica de cookies contra los proveedores REALES del contenedor
            my %prov;
            $prov{'Google Ads'}   = 1 if $cjs =~ /AW-\d+/;
            $prov{'Google Analytics'} = 1 if $cjs =~ /G-[A-Z0-9]{8,}/;
            $prov{'Floodlight'}   = 1 if $cjs =~ /DC-\d+/;
            $prov{'Meta / Facebook'} = 1 if $cjs =~ /fbevents|connect\.facebook/;
            my $pol = '';
            my $polurl = '';
            for my $ruta (qw(/politica-cookies /politica-de-cookies /politique-cookies /cookies /cookie-policy /politica-privacidad /politique-confidentialite /privacidad)) {
                my $x = fetch("$ROOT$ruta");
                if ($x->{code} == 200) { $pol .= tag_text($x->{body}); $polurl ||= "$ROOT$ruta" }
            }
            if ($pol eq '') {
                fallo(lente=>'MEDICION', id=>'MED-07', titulo=>'hay contenedor y no hay pagina de cookies/privacidad',
                      umbral=>'una pagina alcanzable', proc=>'qa-final.sh §5 · G9', hacer=>'publicarla antes de que el contenedor cargue nada');
            } else {
                my @nonombrados = grep { my $p = $_; my $k = ($p =~ /Google/ ? 'Google' : ($p =~ /Meta/ ? 'Facebook|Meta' : $p));
                                         $pol !~ /$k/i } sort keys %prov;
                @nonombrados
                  ? fallo(lente=>'MEDICION', id=>'MED-07', titulo=>'la politica no nombra a un proveedor que el contenedor SI carga',
                          donde=>$polurl, dato=>'sin nombrar: '.join(' · ', @nonombrados),
                          umbral=>'cada proveedor real, por su nombre, con sus cookies y su plazo',
                          proc=>'G9 · deriva en las DOS direcciones: site-d no nombra a Google y escribe cookies de publicidad; site-c declara _ga y Facebook que el sitio migrado YA NO pone',
                          hacer=>'nombrar al tercero y sus cookies (_ga, _gid, _gcl_au). Solo loja.site-b lo hace hoy')
                  : pasa(lente=>'MEDICION', id=>'MED-07', titulo=>'la politica nombra a los proveedores reales', dato=>join(' · ', sort keys %prov));
                # al reves
                my @fantasma;
                push @fantasma, 'Facebook/Meta' if $pol =~ /facebook|meta pixel/i && !$prov{'Meta / Facebook'};
                push @fantasma, 'Google Analytics' if $pol =~ /_ga\b|analytics/i && !$prov{'Google Analytics'};
                @fantasma and aviso(lente=>'MEDICION', id=>'MED-07b', titulo=>'la politica declara un proveedor que el sitio NO carga',
                                    donde=>$polurl, dato=>join(' · ', @fantasma), umbral=>'la politica describe lo que hay, ni mas ni menos',
                                    proc=>'G9 · site-c declara 98 filas de caducidad de cookies que ya no pone',
                                    hacer=>'quitarlo. Una politica que sobra tambien es una politica falsa, y se audita igual');
                # 24-ago-2026 · ESTE CHECK EXISTE PARA ESTO Y NO LO VEIA.
                # site-c.example servia su politica de privacidad con la
                # PLANTILLA POR DEFECTO DE WORDPRESS pegada dentro: 12 parrafos
                # que empiezan literalmente por "Texto sugerido:", secciones
                # sobre comentarios, registro de usuarios y Gravatar que esa web
                # no tiene, y el dominio de la agencia ANTERIOR publicado como
                # si fuera el suyo -tambien en la meta description, que es lo
                # que Google indexa-. En vivo desde el 6-ago, y qa-maestro daba
                # FALLO 0. El check solo buscaba "pendiente de revision", que es
                # UNA forma de decirlo; "Texto sugerido:" es la que sale de
                # serie en cualquier WordPress en espanol. Tres de las cinco
                # webs vienen de WordPress.
                ($pol =~ /pendiente de revisi/i
                 || $pol =~ /texto\s+sugerido\s*:/i        # WordPress ES
                 || $pol =~ /suggested\s+text\s*:/i        # WordPress EN
                 || $pol =~ /texte\s+sugg.r.\s*:/i)        # WordPress FR
                  and fallo(lente=>'MEDICION', id=>'MED-08', titulo=>'la politica esta marcada como borrador EN VIVO',
                            donde=>$polurl, umbral=>'ninguna pagina legal en produccion dice que no esta revisada',
                            proc=>'G9 · site-d lo tiene asi, bajo un formulario de clinica dental con texto libre',
                            hacer=>'o se revisa, o se quita la frase, o no se publica. Las tres son mejores que la actual');
            }
        }

        # G13 · casillas premarcadas (en TODAS las paginas: el banner puede
        # diferir entre plantillas, y aqui se miraba solo la home)
        my @premarcadas;
        { my %v;
          for my $p (@vistas) {
            my $b = fetch($p)->{body} // '';
            for my $inp ($b =~ /(<input\b[^>]*type=["']checkbox["'][^>]*>)/gi) {
                next unless $inp =~ /\bchecked\b/i;
                my $n = lc((attr($inp,'data-cc') // attr($inp,'name') // attr($inp,'id') // ''));
                next if $n =~ /necess|tecnic|essential|required/;
                my $k = ($n || substr($inp,0,50));
                push @premarcadas, $k unless $v{$k}++;
            }
          } }
        @premarcadas ? fallo(lente=>'MEDICION', id=>'MED-06', titulo=>'casilla de analitica o publicidad PREMARCADA',
                             donde=>join(' · ', @premarcadas), umbral=>'ninguna distinta de «necesarias» lleva checked',
                             proc=>'G13 · site-a y site-d. Matiz honesto: el consent default esta en denied, asi que no se dispara nada sin pulsar. Es defecto de FORMA del consentimiento, no fuga de datos',
                             hacer=>'quitar checked. Quien abre «Configurar» y pulsa «Guardar» sin tocar nada esta otorgando sin haberlo elegido')
                     : pasa(lente=>'MEDICION', id=>'MED-06', titulo=>'sin casillas premarcadas');
    }

    # ── G12 · todo data-* que escriba el generador tiene lector en el runtime ─
    #
    # 🔴 ARREGLO 11-ago-2026 · ESTE CHECK ACUSABA POR DOS MOTIVOS FALSOS, y los
    #    dos verificados a mano en site-a antes de tocar nada:
    #
    #    1 · EL PATRON DE LECTOR NO ENTENDIA UN SELECTOR CON VALOR.
    #        Era `\[data-([a-z0-9-]+)\]`, o sea: solo `[data-x]` a secas. El
    #        lector real de site-a es
    #            script.js:263  ev.target.closest('[data-pop-act="close"]')
    #        y por llevar `="close"` no casaba. El atributo TIENE lector desde
    #        que se escribio, y el gate llevaba desde entonces acusandolo.
    #        Ahora se reconocen las seis formas de selector de atributo de CSS
    #        (`=`, `~=`, `|=`, `^=`, `$=`, `*=`) ademas del `[attr]` pelado, y
    #        `dataset['popAct']` junto al `dataset.popAct` que ya se leia.
    #
    #    2 · SE ACUSABA A UN data-* QUE NO SE EMITE EN NINGUNA PAGINA.
    #        `data-col` y `data-sec` viven en `_gen.ps1` de site-a dentro de dos
    #        ramas que hoy no dispara ninguna pagina: el barrido los veia en el
    #        fichero y los daba por emitidos. Un atributo que no llega al HTML
    #        no tiene nada que leer: es NO APLICA, no FALLO.
    #        Lo EMITIDO se cuenta ahora SOLO desde .html del repo y desde las
    #        paginas realmente servidas, nunca desde el generador.
    #
    #    ⚠️ CONTROL NEGATIVO DE ESTE ARREGLO, y es el caro: site-d emitia
    #       `data-thanks` en `gracias/index.html` SIN lector, y eso era la
    #       conversion muerta. Ese caso cae del lado EMITIDO, asi que sigue
    #       saltando. Si algun dia deja de saltar, este arreglo esta roto.
    #
    #    ⚠️ Y LA GUARDA QUE IMPIDE QUE EL FILTRO CIEGUE EL CHECK: si no se ha
    #       podido leer NINGUNA fuente de emision (repo sin .html y sin red),
    #       no se filtra nada —se acusa como antes— y se dice en el DATO. Un
    #       filtro que no sabe distinguir no puede absolver.
    if ($opt{repo} ne '' && -d $opt{repo}) {
        my (%escritos, %leidos, %emitidos);
        my $fuentes = 0;    # de cuantas fuentes de EMISION se ha podido leer
        my @files;
        my @stack = ($opt{repo});
        while (@stack) {
            my $d = pop @stack;
            opendir(my $dh, $d) or next;
            for my $e (readdir $dh) {
                # 🔴 `_migrate/` ES CODIGO DEL CLIENTE, NO NUESTRO (11-ago-2026).
                #    Ahi vive su web capturada tal cual, como evidencia para
                #    auditar la migracion, y no se despliega. Escanearla hacia
                #    que MED-05 nos acusara de `data-accordion-index` y
                #    `data-bullet-index` del Elementor de site-c: 4 de los 5
                #    huerfanos que reportaba salian de su HTML viejo. Acusar a
                #    alguien del codigo de otro no es un gate estricto, es ruido
                #    — y el ruido es lo que hace que un gate se acabe apagando.
                #    ⚠️ Los generadores NUESTROS (`_gen.ps1`) SIGUEN escaneandose:
                #       la exclusion es por carpeta de ORIGEN, no por «lo que
                #       empieza por guion bajo».
                next if $e =~ /^\.|^node_modules$|^_deploy$|^_migrate$/;
                my $p = "$d/$e";
                if (-d $p) { push @stack, $p }
                elsif ($e =~ /\.(html|js|ps1|sh|php)$/i) { push @files, $p }
            }
            closedir $dh;
        }
        # 🔴 NO-DETERMINISMO ARREGLADO EN ORIGEN (11-ago-2026). `readdir` no
        #    promete orden, y unas lineas mas abajo `$escritos{$_} //= $f`
        #    guarda EL PRIMER fichero donde aparece cada data-*. Sin ordenar,
        #    un atributo escrito en dos sitios se reportaba unas veces con un
        #    fichero y otras con el otro: el DONDE cambiaba solo entre corridas
        #    del mismo arbol. Eso hacia que una aceptacion VALIDA dejase de
        #    casar sin que nadie hubiera tocado nada — el camino mas corto para
        #    que alguien deje de fiarse del fichero y lo apague.
        #    Se ordena la LISTA, que es la causa, en vez de normalizar la
        #    huella, que solo taparia el sintoma.
        @files = sort @files;
        for my $f (@files) {
            open my $fh, '<:raw', $f or next; local $/; my $c = <$fh>; close $fh;
            # ⚠️ `$_`, NO `$1`: ver la nota de MED-03. Con `$1` este barrido
            #    reportaba «2 atributos» en site-d y se dejaba fuera justo
            #    data-thanks, que es EL defecto que existe para encontrar.
            $escritos{$_} //= $f for $c =~ /\bdata-([a-z][a-z0-9-]{2,})\s*=\s*["']/gi;
            # 🔴 EMITIDO ≠ ESCRITO. Solo un .html demuestra que el atributo llega
            #    de verdad al marcado; el generador tiene ramas que no dispara
            #    nadie (site-a: data-col y data-sec).
            if ($f =~ /\.html?$/i) {
                $fuentes++;
                # 🔴 INSIDE A TAG, not anywhere in the file. The pattern used to run
                #    over the whole content, so any PROSE naming `data-x="v"` counted
                #    as markup. Measured case: a page that is escaped documentation
                #    inside a <pre> — `&lt;div data-event=…` — with not one real
                #    attribute in it (0 matches of `<tag ... data-event=`). MED-05
                #    accused it of emitting data-event and data-loc with no reader,
                #    and held up a deploy.
                #    Emitted means the browser sees an ATTRIBUTE, so look only inside
                #    `<...>`, which is the only place an attribute can exist.
                #    ⚠️ What it costs: `[^>]*` stops at the first `>`, so a `>` inside
                #       an earlier attribute VALUE would hide the data-* after it.
                #       Rare in generated HTML, and it fails towards NOT accusing —
                #       the behaviour it replaces was accusing outright.
                for my $tag ($c =~ /<[a-zA-Z][^>]*>/g) {
                    $emitidos{lc $_} = 1 for $tag =~ /\bdata-([a-z][a-z0-9-]{2,})\s*=\s*["']/gi;
                }
            }
            $leidos{$_}++  for $c =~ /getAttribute\(\s*['"]data-([a-z0-9-]+)['"]/gi;
            $leidos{$_}++  for $c =~ /dataset\.([a-zA-Z0-9_]+)/g;
            $leidos{$_}++  for $c =~ /dataset\[\s*['"]([a-zA-Z0-9_-]+)['"]\s*\]/g;
            # SELECTOR DE ATRIBUTO, con valor o sin el. Las seis formas de CSS
            # (`=` `~=` `|=` `^=` `$=` `*=`) y el `[data-x]` pelado. El lector de
            # site-a —`[data-pop-act="close"]`— caia justo por el `="close"`.
            $leidos{$_}++  for $c =~ /\[\s*data-([a-z0-9-]+)\s*(?:[~|^\$*]?=|\])/gi;
        }
        # La otra fuente de emision: lo que el sitio SIRVE de verdad. Hace falta
        # para un repo que no versiona el HTML (se genera al desplegar): sin
        # esto, ahi %emitidos saldria vacio y el filtro cegaria el check entero.
        my $vistas_mudas = 0;
        for my $p (@vistas) {
            my $b = fetch($p)->{body} // '';
            unless (length $b) { $vistas_mudas++; next }
            $fuentes++;
            # Same tag-scoping as above, for the same reason: fix only the repo
            # branch and the gate starts accusing again the moment the page is
            # SERVED. Half a correction is the one that deceives, because the
            # symptom disappears until the next deploy.
            for my $tag ($b =~ /<[a-zA-Z][^>]*>/g) {
                $emitidos{lc $_} = 1 for $tag =~ /\bdata-([a-z][a-z0-9-]{2,})\s*=\s*["']/gi;
            }
        }
        # 🔴 EL VOCABULARIO DEL PROPIO GATE NO ES UN HUERFANO (11-ago-2026).
        #    `data-sec` y `data-tipo` no los lee ningun JS del sitio: los leo YO,
        #    aqui, desde EST-01/EST-02c y desde structure-gate.js. Y `09 §1` los
        #    EXIGE. Sin esta exencion el gate se contradice en la misma corrida:
        #    una lente pide el atributo y otra acusa de emitirlo. Medido en
        #    climentmedia, que salia FALLO por el unico `data-sec` que tenia.
        #    ⚠️ La exencion es por NOMBRE EXACTO y esta cerrada a estos dos. No
        #       vale para un `data-loquesea` que alguien declare «de herramienta»:
        #       el defecto que este check existe para cazar —el `data-thanks` de
        #       site-d, que era la conversion muerta— sigue entrando entero.
        my %VOCAB_GATE = map { $_ => 1 } qw(sec tipo);
        my (@huerfanos, @noaplica);
        for my $k (sort keys %escritos) {
            next if $VOCAB_GATE{$k};
            my $camel = $k; $camel =~ s/-(\w)/\u$1/g;
            next if $leidos{$k} || $leidos{$camel};
            # NO APLICA: escrito en el repo pero que no llega a ninguna pagina.
            # Solo se absuelve si se ha podido MIRAR alguna pagina (`$fuentes`).
            if ($fuentes && !$emitidos{lc $k}) {
                push @noaplica, "data-$k (solo en ".($escritos{$k} =~ s/^\Q$opt{repo}\E.?//r).")";
                next;
            }
            push @huerfanos, "data-$k (escrito en ".($escritos{$k} =~ s/^\Q$opt{repo}\E.?//r).")";
        }
        # 🔴 EL METODO, EN EL DATO. Un numero sin su procedencia no se puede
        #    rastrear, y este lleva un filtro nuevo dentro.
        my $metodo = $fuentes
            ? sprintf('emision leida de %d pagina%s (%d data-* llegan al marcado)',
                      $fuentes, ($fuentes==1?'':'s'), scalar(keys %emitidos))
            : 'SIN fuente de emision legible: no se filtra nada, se acusa todo lo escrito';
        $metodo .= ' · '.scalar(@noaplica).' NO APLICA (escritos y nunca emitidos): '
                 . join(', ', @noaplica[0..($#noaplica>2?2:$#noaplica)]) if @noaplica;
        @huerfanos ? fallo(lente=>'MEDICION', id=>'MED-05', titulo=>'data-* emitido por el generador SIN lector en el runtime',
                           donde=>join("\n                 ", @huerfanos[0..($#huerfanos>4?4:$#huerfanos)]),
                           ev=>[@huerfanos],
                           # 🔴 LA OTRA MITAD DEL NO-DETERMINISMO DE MED-05, y esta
                           #    NO se arregla en origen: el filtro «NO APLICA»
                           #    necesita saber que data-* LLEGAN al marcado, y eso
                           #    se lee descargando paginas. Si una no baja, el
                           #    filtro absuelve de menos y la lista de huerfanos
                           #    crece —de ahi el «3 atributos» y luego «2»—. No es
                           #    orden de hash: es que se ha medido otra cosa.
                           #    Se DICE en vez de disimularlo: aceptacion PARCIAL.
                           ev_parcial=>($vistas_mudas
                               ? sprintf('%d de %d paginas no se han podido leer: el filtro de «escrito y nunca emitido» va degradado y la lista de huerfanos puede crecer o encoger entre corridas',
                                         $vistas_mudas, scalar(@vistas))
                               : ''),
                           dato=>scalar(@huerfanos).' atributos · '.$metodo,
                           umbral=>'por cada data-X que LLEGA al marcado, un getAttribute/dataset/[data-X] (con o sin valor) en el repo · lo escrito y nunca emitido es NO APLICA',
                           proc=>'G12 · data-thanks lo escribia site-d en gracias/index.html y no existia en ningun .js: esa era la conversion muerta. Arreglo 11-ago-2026: el patron no entendia `[data-x="v"]` y se acusaba a data-* de ramas del generador que no dispara nadie',
                           hacer=>'o se anade el lector, o se quita el atributo. Un contrato que no cumple nadie es peor que no tenerlo')
                   : pasa(lente=>'MEDICION', id=>'MED-05', titulo=>'todo data-* tiene lector',
                          dato=>scalar(keys %escritos).' atributos escritos · '.$metodo);
    } else {
        nv(lente=>'MEDICION', id=>'MED-05', titulo=>'data-* emitido sin lector en el runtime',
           umbral=>'por cada data-X emitido, un lector en el JS del mismo repo',
           proc=>'G12 · es la CAUSA del fallo de conversion de site-d',
           hacer=>'volver a correr con --repo C:/ruta/al/repo. Es un grep cruzado de dos listas y tarda un segundo');
    }

    # ── Formulario: receptor y doble envio ──────────────────────────────────
    my $cu = $opt{contacto} ne '' ? "$ROOT$opt{contacto}" : '';
    if (!$cu) { for my $u (@PAGES) { $cu = $u, last if $u =~ m{/(contact|contacto|kontakt)} } }
    $cu ||= $URLS[0];
    my $cb = fetch($cu)->{body} // '';
    if ($cb =~ /<form\b/i) {
        my ($fo) = $cb =~ /(<form\b[^>]*>)/i;
        my $act = attr($fo,'action');
        if (!defined $act || $act eq '') {
            $cb =~ /mailto:/i
              ? fallo(lente=>'MEDICION', id=>'MED-10', titulo=>'formulario SIN action y con mailto',
                      donde=>$cu, umbral=>'action a un receptor propio', proc=>'qa-final.sh §4 (el fallo de Site A y el de BC)',
                      hacer=>'sin cliente de correo configurado no envia nada, y no queda copia en disco. Se pierde el lead sin que nadie se entere')
              : fallo(lente=>'MEDICION', id=>'MED-10', titulo=>'formulario SIN action',
                      donde=>$cu, umbral=>'action explicito', proc=>'qa-final.sh §4',
                      hacer=>'comprobar a donde envia de verdad (puede ser JS); si es JS, MED-11 y el bloque B');
        } else {
            my $a = abs_url($act, $cu) // $act;
            # 🔴 EL CANDIDATO NO EJECUTA NADA · arreglo 11-ago-2026.
            #    El servidor del candidato sirve FICHEROS del arbol; no ejecuta
            #    PHP ni resuelve rutas. Contra el, `action="/contact.php"` daba
            #    404 y este check cantaba «el receptor del formulario devuelve
            #    404» en site-a, cuando produccion contesta 405 (medido).
            #    La cabecera ya tenia la doctrina escrita —compresion, cache,
            #    estado 404 y G11 salen NO VERIFICADO por esto mismo— y este
            #    check no estaba en la lista. Ahora si: en modo candidato, lo
            #    que depende de EJECUTAR algo en el servidor no es FALLO ni
            #    PASA, es una pregunta que solo contesta produccion.
            #    ⚠️ La rama de arriba (formulario SIN action) NO entra aqui: eso
            #       es un hecho del arbol y el candidato lo mide igual de bien.
            my ($ruta_a) = $a =~ m{^[a-z]+://[^/]*([^?#]*)}i;
            my ($ext_a)  = ($ruta_a // '') =~ m{\.([a-z0-9]{1,6})$}i;
            $ext_a = lc($ext_a // '');
            my $ejecuta = $ext_a =~ /^(php\d?|phtml|cgi|pl|py|rb|asp|aspx|ashx|jsp|jspx|do|action)$/
                            ? "el receptor es un manejador de servidor (.$ext_a) y aqui no se ejecuta: se serviria el fuente o un 404"
                        : $ext_a eq ''
                            ? 'el receptor es una ruta sin fichero: la resuelve el servidor (rewrite/router), no el arbol'
                        : '';
            if ($CAND_ON && $ejecuta) {
                nv_cand(lente=>'MEDICION', id=>'MED-10', titulo=>'el receptor del formulario responde',
                        donde=>$a, dato=>'medido contra el CANDIDATO: '.$ejecuta,
                        motivo=>$ejecuta,
                        umbral=>'no 404 · y el metodo real es POST: un GET a un receptor bien puesto suele dar 405, que NO es un fallo',
                        proc=>'qa-final.sh §4 · site-a 11-ago-2026: el candidato daba 404 a /contact.php y produccion devuelve 405',
                        hacer=>'se contesta DESPUES de subir: perl qa-master.pl <URL real> --repo DIR (sin --candidato)');
            } else {
                my $x = fetch($a);
                $x->{code} == 404
                  ? fallo(lente=>'MEDICION', id=>'MED-10', titulo=>'el receptor del formulario devuelve 404',
                          donde=>$a, umbral=>'no 404', proc=>'qa-final.sh §4', hacer=>'desplegar el receptor, o corregir el action')
                  : pasa(lente=>'MEDICION', id=>'MED-10', titulo=>'receptor del formulario', dato=>"$a (HTTP $x->{code})");
            }
        }
        # MED-11 · guarda de doble envio
        my $js = '';
        for my $t ($cb =~ /(<script\b[^>]*>)/gi) {
            my $src = attr($t,'src') or next; my $au = abs_url($src, base_ef($cu)) or next;
            next unless is_internal($au); my $x = fetch($au); $js .= $x->{body} if $x->{code}==200;
        }
        $js .= $cb;
        ($js =~ /disabled\s*=\s*(true|!0)|\.disabled\s*=|enviando|sending|isSubmitting|aria-busy/i)
          ? pasa(lente=>'MEDICION', id=>'MED-11', titulo=>'guarda de doble envio')
          : fallo(lente=>'MEDICION', id=>'MED-11', titulo=>'sin guarda de doble envio',
                  donde=>$cu, umbral=>'deshabilitar el boton mientras se envia',
                  proc=>'G8 · lo dice el codigo de quien SI lo bloquea: site-b/js/configurator.js:575 «uma pessoa enviou QUATRO vezes em dois minutos por nao ver resposta»',
                  hacer=>'deshabilitar el submit y cambiar su texto a «Enviando...» hasta que responda el receptor');

        # PC3 · caducidad de los ficheros de leads
        my $pol2 = '';
        for my $ruta (qw(/politica-privacidad /politique-confidentialite /privacidad /privacy /politica-de-privacidade)) {
            my $x = fetch("$ROOT$ruta"); $pol2 .= tag_text($x->{body}) if $x->{code} == 200;
        }
        # 🔴 EL NUMERO PUEDE IR EN LETRA, Y HASTA EL 21-ago-2026 ESO ERA UN
        #    FALSO POSITIVO. El patron exigia \d+, asi que la politica de
        #    site-a.example diciendo «conservees DEUX MOIS ... puis supprimees
        #    automatiquement» -- un plazo perfectamente escrito y ademas
        #    cumplido por un cron -- salia como «sin plazo de conservacion».
        #    El texto legal en frances y en espanol escribe los numeros
        #    pequenos en letra: exigir cifras es medir el ESTILO, no el hecho.
        #    Y el dano no es cosmetico: el unico camino que le quedaba a una web
        #    que hace lo correcto era taparlo en aceptado.conf, que es
        #    exactamente lo que ese fichero no debe usarse para hacer.
        my $NUM = qr/\d+|veinticuatro|vingt-quatre|twenty-four|una|uno|une|uma|dos|duas|dois|deux|two|tres|tr[eê]s|trois|three|cuatro|quatre|four|cinco|cinq|five|seis|six|sete|siete|sept|seven|ocho|oito|huit|eight|nueve|nove|neuf|nine|diez|dez|dix|ten|once|onze|eleven|doce|douze|twelve|one|um|un/i;
        # 🔴 Y `conserva\w*` NO CASABA CON EL FRANCES, que era justo el idioma del
        #    caso que motivo el arreglo. «conservées» es conserv + e-acentuada, y
        #    `\w` no casa una vocal acentuada en una cadena de bytes: la palabra
        #    disparadora fallaba y daba igual lo bien que estuviera el numero.
        #    Mi fixture no lo vio porque estaba en espanol -«se conservan DURANTE
        #    dos meses»- y ahi disparaba `durante`. Un banco que prueba la frase
        #    parecida y no la REAL deja pasar exactamente esto.
        #    `conserv` a secas cubre conservées, conservation, conservan,
        #    conservados y conservadas de una vez.
        ($pol2 =~ /(durante|pendant|por un plazo|conserv|prazo)[^.]{0,80}\b(?:$NUM)\b\s*(mes|meses|ano|anos|año|años|mois|ans|years?|months?)\b/i)
          ? pasa(lente=>'MEDICION', id=>'MED-09', titulo=>'plazo de conservacion declarado')
          : fallo(lente=>'MEDICION', id=>'MED-09', titulo=>'sin plazo de conservacion de los datos del formulario',
                  umbral=>'un plazo en meses, escrito, y un borrado que lo cumpla',
                  proc=>'PC3 · 4 receptores nuestros escriben nombre, telefono, email, IP y texto libre en _leads/*.jsonl: CERO purga y CERO plazo en los cuatro. En site-a y site-d ese texto libre puede ser dato de salud (categoria especial del RGPD)',
                  hacer=>'un plazo en la politica y un cron de purga. Horas de trabajo, y hoy es el riesgo legal mas grande que tenemos');
    }

    # /_leads/ expuesto
    # 🔴 EL OTRO CHECK QUE EL CANDIDATO NO PUEDE MEDIR (barrido del 11-ago-2026,
    #    junto con MED-10). Que `/_leads/` este cerrado es configuracion del
    #    HOST —.htaccess, reglas del servidor—, no del arbol: aqui esos
    #    directorios ni siquiera se sirven (`_deploy` esta excluido del
    #    candidato), asi que el bucle no encontraba nada y NO EMITIA NADA.
    #    Callarse es peor que un PASA falso: al menos un PASA se ve en el
    #    recibo. Ahora sale NO VERIFICADO con su motivo, y lo contesta G11.
    if ($CAND_ON) {
        nv_cand(lente=>'MEDICION', id=>'MED-12', titulo=>'rutas internas expuestas por web',
                dato=>'medido contra el CANDIDATO: quien cierra /_leads/ y /_secrets/ es el host, no el arbol',
                motivo=>'la proteccion la pone el servidor (.htaccess/reglas), no el repo',
                umbral=>'403 o 404 en /_leads/, /_secrets/ y /check-smtp.php',
                proc=>'qa-final.sh §5 · barrido de dependencias del candidato, 11-ago-2026',
                hacer=>'se contesta DESPUES de subir: perl qa-master.pl <URL real> (sin --candidato)');
    } else {
        # 🔴 SIN SEGUIR REDIRECCIONES. `fetch` usa `curl -sSL`, asi que si el
        #    sitio manda los 404 a la home —lo hace WordPress con el plugin
        #    «Redirect 404 to Homepage», y lo hacia site-b.example el 22-ago-2026—
        #    el codigo que vuelve es el 200 DE LA HOME y este check acusaba de
        #    exponer `_secrets/` un sitio donde ese directorio ni se sirve.
        #    Medido: 302 a `/` en las tres rutas. Es la misma familia que «el
        #    control mide algo ADYACENTE a lo que afirma», y aqui el sesgo iba
        #    hacia el falso ROJO: caro igual, porque un rojo que no se puede
        #    arreglar es un rojo que alguien acaba tapando.
        my @expuestas;
        for my $p (qw(/_leads/ /_secrets/ /check-smtp.php)) {
            my $c = codigo_sin_seguir("$ROOT$p");
            push @expuestas, "$ROOT$p (HTTP $c)" if defined $c && $c == 200;
        }
        @expuestas and fallo(lente=>'MEDICION', id=>'MED-12', titulo=>'ruta interna expuesta por web',
                             donde=>join(' · ', @expuestas), umbral=>'403 o 404', proc=>'qa-final.sh §5',
                             hacer=>'bloquear en el servidor. Ahi dentro hay nombres, telefonos e IPs');
    }

    # ── PC1 · el punto ciego mas caro que tenemos ───────────────────────────
    nv(lente=>'MEDICION', id=>'MED-13', titulo=>'que UNA conversion haya LLEGADO a Google Ads / GA4',
       umbral=>'>=1 conversion registrada en la interfaz de Ads en los ultimos 7 dias',
       proc=>'PC1 · en las cinco webs la verificacion se detiene en «la etiqueta existe». Nadie ha abierto Ads ni GA4 en ningun proyecto',
       hacer=>'un acceso de lectura a Ads por cliente y una comprobacion al mes. 🔴 Es el hueco entre dos cosas que cada una parece correcta: el contenedor bien Y la pagina bien, y cero conversiones');

    nv(lente=>'MEDICION', id=>'MED-14', titulo=>'que pasa cuando el visitante pulsa RECHAZAR',
       umbral=>'0 cookies de terceros y gcs=G100 despues de rechazar',
       proc=>'PC5 · se ha comprobado el estado ANTES de elegir y tras ACEPTAR. La rama de rechazo no se ha mirado nunca en ninguna web',
       hacer=>'abrir el banner, pulsar Rechazar, y mirar cookies + dataLayer en el panel');
}

# =============================================================================
#  8 · LENTE 5 · ESTRUCTURA
#     Procedencia: 09-tipos-de-pagina.md · G6 · G7 · G11 · X2 · X5 · A-bis/A-ter
# =============================================================================
# %ANATOMIA vive ARRIBA, junto a `tipo_de`: es la lista de tipos que el gate
# conoce, y `data-tipo` se valida contra ella. Tenerla aqui obligaba a
# mantener a mano una segunda lista de tipos validos, y la segunda lista SE
# QUEDO CORTA el primer dia: `data-tipo="ficha"` se rechazaba por no estar en
# ella mientras %ANATOMIA si tenia `ficha`. Una sola fuente.

# ── EST-10 · desplegables medio vacios ───────────────────────────────────────
# Devuelve, por cada control de MENU con aria-controls="X", cuantos destinos
# DISTINTOS hay dentro del panel X.
#
# 🔴 De donde sale: el 13-ago se sacaron 3 agentes del megapanel «Agents» de
#    climentmedia por la razon correcta (era una seleccion a mano de 3 de 7, que
#    envejece sola), y no se miro con que se quedaba el panel: DOS enlaces, uno
#    de ellos el mismo del padre y el otro ya presente en otro panel. Un chevron
#    que promete un menu y entrega eso es peor que no tenerlo. Lo vio Manuel
#    mirando la web; ningun gate lo miraba. R10 del gate de enlazado no sirve:
#    mide destinos del cromo sobre el sitio entero, no el reparto por panel.
#
# DOS decisiones de implementacion, las dos por trampas ya sufridas:
#  1 · SOLO controles dentro de <header> o <nav>. `aria-controls` tambien lo usa
#      un acordeon de FAQ, cuyo panel legitimamente tiene CERO enlaces: sin este
#      acotado el check acusaria a las FAQ de las 5 webs.
#  2 · El panel se recorta con un CONTADOR DE PROFUNDIDAD sobre su propia
#      etiqueta, no con `.*?</div>`: el megapanel lleva <div> anidados y el
#      perezoso se queda en el primer cierre interno (07-trampas: regex
#      codicioso sobre HTML).
# ── EST-11 · VOCABULARIO INTERNO A LA VISTA DEL VISITANTE ────────────────────
#
# 🔴 De donde sale: el 14-ago-2026, remaquetando site-c.example, salieron a
#    produccion TRES cosas de esta misma familia, y ninguna la miraba nada:
#
#      <h1>hero</h1>                     el titular cayo en el nombre del ROL
#      <h2>calificacion</h2>             lo mismo, en diez secciones
#      Inicio / hipnosis-para-eliminar-una-tercera-persona / Hipnosis
#                                        una miga pintando el SLUG crudo
#      [ campo ] No rellenar             el cepo de robots, visible (site-d)
#
#    Las cuatro son HTML perfectamente valido. Un <h2> con texto es un <h2>; un
#    enlace con texto es un enlace. Ni `_audit.sh`, ni el gate de enlazado, ni
#    las cinco lentes decian una palabra. Las vio Manuel mirando la pantalla.
#
# LA REGLA, y es de una linea: **lo que ve el visitante es idioma suyo, no
# nuestro.** Un rol es vocabulario de la anatomia; un slug es una ruta; «No
# rellenar» es una instruccion para un robot. Nada de eso se le enseña a nadie.
#
# ⚠️ Solo se mira TEXTO CORTO Y SUELTO -titulares, migas, etiquetas-, nunca
#    prosa: la palabra «proceso» dentro de un parrafo es castellano normal, y
#    acusarla seria un falso positivo en todas las webs en español. Lo que se
#    persigue es un ELEMENTO ENTERO cuyo texto es exactamente un token nuestro.
my @ROLES_INTERNOS = qw(hero oferta calificacion proceso objeciones cierre prueba
                        contexto mapa hermanos cta catalogo formulario alternativas
                        evidencia catalogo);
my %ES_ROL = map { $_ => 1 } @ROLES_INTERNOS;
sub vocabulario_a_la_vista {
    my ($html) = @_;
    my @mal;
    # 1 · un titular cuyo texto es EXACTAMENTE el nombre de un rol
    while ($html =~ m{<(h[1-6])\b[^>]*>(.*?)</\1>}gsi) {
        my ($tag, $txt) = (lc $1, $2);
        $txt =~ s/<[^>]+>//g; $txt =~ s/\s+/ /g; $txt =~ s/^\s+|\s+$//g;
        push @mal, "<$tag>$txt</$tag> es el nombre de un rol" if $ES_ROL{ lc $txt };
    }
    # 2 · un escalon de miga pintado con el slug crudo. La firma es inequivoca:
    #     minusculas-con-guiones, sin espacios y con dos guiones o mas. Un
    #     titulo de verdad lleva espacios.
    if ($html =~ m{<(nav|ol)\b[^>]*(?:crumb|miga|breadcrumb)[^>]*>(.*?)</\1>}si) {
        my $m = $2;
        while ($m =~ m{>([^<>]+)<}g) {
            my $t = $1; $t =~ s/^\s+|\s+$//g;
            next unless length $t;
            push @mal, "la miga pinta el slug crudo: «$t»"
                if $t =~ /^[a-z0-9]+(?:-[a-z0-9]+){2,}$/;
        }
    }
    # 3 · 🔴 EL CEPO DE ROBOTS NO SE PUEDE DECIDIR AQUI, Y SE MIDIO ANTES DE
    #     ENCENDERLO. La primera version de este check acusaba a toda pagina
    #     cuyo marcado llevara una etiqueta «No rellenar» sin ocultar EN EL HTML.
    #     Medido con getComputedStyle sobre las tres webs que tienen formulario,
    #     antes de dar el check por bueno:
    #
    #       site-c /contacto  x=-9999  seVe=false   <- acusada EN FALSO
    #       site-a   /          0 etiquetas           <- acusada EN FALSO
    #       site-d /contacto  x=16 w=277 seVe=TRUE  <- la unica de verdad
    #
    #     DOS FALSOS DE TRES. Se esconde con `position:absolute; left:-9999px`,
    #     que es lo CORRECTO -`display:none` lo ignoran algunos bots-, y eso no
    #     se ve leyendo el HTML: hace falta el DOM.
    #     Asi que la regla se queda, pero NO aqui: pertenece a la lente que mide
    #     con navegador (`--dom`, familia EST-06). Un gate que acusa a dos
    #     formularios BIEN construidos de cada tres se apaga solo, y entonces
    #     tampoco caza el que si.
    return @mal;
}

sub paneles_de_menu {
    my ($html) = @_;
    # 1 · la region de navegacion. Puede haber varias (cabecera y pie).
    my $nav = join "\n", ($html =~ m{<header\b[^>]*>(.*?)</header>}gsi),
                         ($html =~ m{<nav\b[^>]*>(.*?)</nav>}gsi);
    return () unless $nav =~ /\S/;
    # 2 · los ids prometidos. Se recogen en UNA pasada y se procesan despues:
    #    los `pos()` de dos //g sobre la misma cadena se pisan.
    my @ids; my %visto;
    while ($nav =~ m{\baria-controls\s*=\s*["']([^"']+)["']}gi) {
        push @ids, $1 unless $visto{$1}++;
    }
    my @out;
    for my $id (@ids) {
        my $h = $html;
        unless ($h =~ m{<([a-z][a-z0-9]*)\b[^>]*\bid\s*=\s*["']\Q$id\E["'][^>]*>}i) {
            # El control apunta a un panel que no existe. Es un defecto distinto
            # y peor, asi que se reporta con -1 en vez de callarse.
            push @out, [$id, -1]; next;
        }
        my ($tag, $ini) = (lc $1, $+[0]);
        my ($depth, $fin) = (1, undef);
        pos($h) = $ini;
        while ($h =~ m{<(/?)\Q$tag\E\b([^>]*)>}gi) {
            my ($cierre, $attrs) = ($1, $2);
            next if $attrs =~ m{/\s*$};        # autocerrada
            $depth += $cierre ? -1 : 1;
            if ($depth == 0) { $fin = $-[0]; last }
        }
        next unless defined $fin;              # sin cierre: HTML roto, no es cosa de este check
        my $cuerpo = substr($h, $ini, $fin - $ini);
        my %dest;
        while ($cuerpo =~ m{<a\b[^>]*\bhref\s*=\s*["']([^"']*)["']}gi) { $dest{$1} = 1 }
        push @out, [$id, scalar keys %dest];
    }
    return @out;
}

# ── EST-12 · EL PIE ──────────────────────────────────────────────────────────
# 17-ago-2026 · El paso 2 de `16-revision-paso-a-paso.md` no lo miraba ningun
# programa, y era uno de los cuatro asi. Lo que se comprueba, y de donde sale:
#
#  a · HAY pie. Sin el, lo demas no tiene donde estar.
#  b · Enlaza los LEGALES. Un sitio que recoge datos y esconde su privacidad no
#      es un problema de SEO: es el visitante el que no puede ejercer nada.
#  c · 🔴 EL TELEFONO DEL PIE ES EL DEL SCHEMA. Es el defecto de las DOS LISTAS
#      para el mismo hecho -el mismo que caza R6 con las migas-: cuando el
#      numero cambia se cambia en uno de los dos sitios, y a partir de ahi
#      Google publica un telefono y el visitante ve otro. No lo mira nadie
#      porque las dos cosas son validas por separado.
#  d · El enlace de AUTORIA a climentmedia.com. Va como AVISO y no como fallo
#      mientras las webs no lo declaren: un check nuevo que se pone en rojo en
#      las cinco a la vez ensena a ignorar el gate (misma razon que 2-bis).
#
# ⚠️ Y el matiz que hay que respetar al ponerlo, escrito aqui para que no se
#    pierda: **un enlace IGUAL en el pie de las cinco webs es un patron que
#    Google reconoce como red de enlaces.** Lo que aguanta es un enlace de
#    autoria con TEXTO DISTINTO por sitio, apuntando a una pagina que explique
#    quien hizo la web. Por eso el gate rechaza el ancla que es solo la marca.
sub pie_de {
    my ($html) = @_;
    my @pies = $html =~ m{<footer\b[^>]*>(.*?)</footer>}gsi;
    return join("\n", @pies);
}

sub lente_estructura {
    unless ($NET_OK) {
        nv(lente=>'ESTRUCTURA', id=>'EST-00', titulo=>'la lente entera', umbral=>'requiere red',
           proc=>'qa-maestro', hacer=>'sin descarga no hay maqueta que leer');
        return;
    }
    my $u = $URLS[0];
    my $h = sin_com(fetch($u)->{body});
    # ⚠️ Se calcula DESPUES del bucle, no aqui: `%TIPO_DECL` lo llena `tipo_de`,
    #    y a esta altura el bucle que la llama todavia no ha corrido. Calculado
    #    aqui salia SIEMPRE «INFERIDO», incluso con la pagina declarando su tipo
    #    y el gate aplicandolo bien (se veia `hub x1` en el resumen y la etiqueta
    #    seguia diciendo lo contrario). Un informe que se contradice a si mismo.
    my $inferido = '';

    # 🔴 ARREGLO 0.3 · aqui la loteria del orden era doble: no solo se miraba una
    #    sola pagina, es que el TIPO salia de `tipo_de($URLS[0])`. Si la primera
    #    de la lista era un aviso legal, la lente auditaba el sitio entero como
    #    si fuera un aviso legal —y «legal» no tiene roles OBL, asi que EST-01 y
    #    EST-02 se saltaban en silencio para TODAS las demas. Ahora cada pagina
    #    se juzga con SU tipo.
    my @vistas = @PAGES;
    my (@sin_sec, @sin_datasec, @anat_mal, @heur, %tipos, $con_datasec, @no_leidas, @leidas_est);
    my (@drop_pobres, @drop_rotos, $drop_mirados);
    my (@sin_pie, @pie_sin_legal, @nap_discrepa, @sin_autoria, @autoria_marca, %anclas_autoria);
    my @vocab_mal;
    for my $p (@vistas) {
        my $rp = fetch($p);
        if ($rp->{code} != 200 || $rp->{body} !~ /</) { push @no_leidas, "$p (HTTP $rp->{code})"; next }
        push @leidas_est, $p;
        my $hp = sin_com($rp->{body});
        my $tp = tipo_de($p);
        $tipos{$tp}++;
        # EST-11 · vocabulario interno a la vista. Sobre el documento entero:
        # la miga vive fuera de <main> en varias de nuestras webs.
        for my $v (vocabulario_a_la_vista($hp)) { push @vocab_mal, "$p — $v" }

        # EST-10 · sobre el DOCUMENTO entero, no sobre <main>: el menu es cromo.
        for my $par (paneles_de_menu($hp)) {
            my ($id, $n) = @$par;
            $drop_mirados++;
            if    ($n < 0)  { push @drop_rotos,  "$p (aria-controls=\"$id\" no apunta a ningun elemento)" }
            elsif ($n < 3)  { push @drop_pobres, "$p (panel \"$id\": $n destino".($n==1?'':'s').")" }
        }

        # ── EST-12 · el pie ───────────────────────────────────────────────
        my $pie = pie_de($hp);
        if ($pie !~ /\S/) {
            push @sin_pie, $p;
        } else {
            my @hrefs_pie = $pie =~ m{<a\b[^>]*href\s*=\s*["']([^"']+)["']}gi;
            # b · legales. Se buscan por RUTA y en los cuatro idiomas del parque
            #     (es/fr/en/pt), no por el texto del enlace: el texto cambia con
            #     la marca y la ruta no.
            my $legales = grep {
                m{(aviso-?legal|privacidad|privacy|cookies|terminos|terms|
                    mentions-?legales|politique|confidentialit|protecao|privacidade)}xi
            } @hrefs_pie;
            push @pie_sin_legal, "$p ($legales enlace(s) legal(es) en el pie)" if $legales < 2;

            # c · el telefono del pie contra el del schema. Solo se compara si
            #     la pagina emite uno: sin schema no hay dos listas que puedan
            #     discrepar, y acusar seria inventarse el defecto.
            my ($ld) = join "\n",
                ($hp =~ m{<script\b[^>]*type\s*=\s*["']application/ld\+json["'][^>]*>(.*?)</script>}gsi);
            my ($tel_ld) = ($ld // '') =~ m{"telephone"\s*:\s*"([^"]+)"}i;
            if (defined $tel_ld) {
                (my $n_ld = $tel_ld) =~ s/\D//g;
                my @tel_pie = $pie =~ m{href\s*=\s*["']tel:([^"']+)["']}gi;
                my @n_pie = map { my $x = $_; $x =~ s/\D//g; $x } @tel_pie;
                # Se compara por los ULTIMOS 9 digitos: el prefijo se escribe de
                # tres formas (+34, 0034, sin nada) y eso no es una discrepancia.
                my $cola = sub { my $x = shift; length($x) > 9 ? substr($x, -9) : $x };
                if (@n_pie && !grep { $cola->($_) eq $cola->($n_ld) } @n_pie) {
                    push @nap_discrepa,
                         "$p (schema $tel_ld · pie ".join(' ', @tel_pie).")";
                }
            }

            # d · el enlace de autoria
            my @aut = grep { m{climentmedia\.com}i } @hrefs_pie;
            if (!@aut) {
                push @sin_autoria, $p;
            } else {
                # El ancla, para poder mirar que NO es la misma en las cinco webs.
                my ($anc) = $pie =~ m{<a\b[^>]*href\s*=\s*["'][^"']*climentmedia\.com[^"']*["'][^>]*>(.*?)</a>}si;
                $anc //= ''; $anc =~ s/<[^>]*>//g; $anc =~ s/\s+/ /g; $anc =~ s/^\s+|\s+$//g;
                $anclas_autoria{$anc}++ if $anc ne '';
                push @autoria_marca, "$p (ancla: «$anc»)"
                    if $anc =~ /^\s*climent\s*media\s*$/i;
            }
        }

        my ($mp) = $hp =~ m{<main\b[^>]*>(.*?)</main>}si; $mp //= $hp;
        my $ns = () = $mp =~ /<section\b/gi;
        push @sin_sec, "$p ($ns <section>, tipo $tp)" if $tp !~ /^(legal|404|gracias)$/ && $ns < 2;

        my @secs = $mp =~ /data-sec\s*=\s*["']([a-z-]+)["']/gi;
        if (!@secs) {
            push @sin_datasec, $p;
            my $need = scalar @{$ANATOMIA{$tp} // []};
            push @heur, "$p ($ns <section> para $need roles OBL de «$tp»)" if $need && $ns < $need;
        } else {
            $con_datasec = 1;
            my %hay = map { $_ => 1 } @secs;
            my @faltan = grep { !$hay{$_} } @{$ANATOMIA{$tp} // []};
            push @anat_mal, "$p «$tp» faltan: ".join(' ', @faltan) if @faltan;
        }
    }
    my $resumen_tipos = join(' ', map { "$_ x$tipos{$_}" } sort keys %tipos);
    my $leidas = scalar(@vistas) - scalar(@no_leidas);
    alcance('ESTRUCTURA', [@leidas_est], undef,
            'EST-01, EST-02 y EST-10 sobre todas, cada una con SU tipo · EST-03/04/08/09 son del sitio · EST-05/06/07 solo la pagina del --dom');
    @no_leidas and nv(lente=>'ESTRUCTURA', id=>'EST-0x', titulo=>'paginas que no he podido leer',
                      donde=>join(' · ', @no_leidas[0..($#no_leidas>3?3:$#no_leidas)]),
                      ev=>[@no_leidas],
                      dato=>scalar(@no_leidas).' de '.scalar(@vistas),
                      umbral=>'todas las de la lista responden 200 con HTML',
                      proc=>'qa-maestro', hacer=>'lo que no se ha leido no esta medido: EST-01 y EST-02 no hablan de esas paginas');
    if (!$leidas) {
        nv(lente=>'ESTRUCTURA', id=>'EST-01', titulo=>'seccionado y anatomia',
           dato=>'0 de '.scalar(@vistas).' paginas legibles',
           umbral=>'al menos una pagina descargable', proc=>'qa-maestro',
           hacer=>'sin una sola pagina leida no hay maqueta que medir, y eso NO es un aprobado');
    } else {

    # EST-01 · <section>
    @sin_sec ? fallo(lente=>'ESTRUCTURA', id=>'EST-01', titulo=>'la pagina no esta seccionada',
                     donde=>join("\n                 ", @sin_sec[0..($#sin_sec>3?3:$#sin_sec)]),
                     ev=>[@sin_sec],
                     dato=>scalar(@sin_sec).' de '.scalar(@vistas).' paginas · tipos: '.$resumen_tipos,
                     umbral=>'>=2 <section> dentro de <main>, salvo legal/404/gracias',
                     proc=>'site-d 40/40 paginas con <section> frente a 2/35 de climentmedia · se genera desde spec con orden de secciones fijo',
                     hacer=>'una seccion es un ROL, no un fondo (09 §1). Sin secciones la pagina es una tirada de <p> y ningun gate de maqueta puede decir nada de ella')
             : pasa(lente=>'ESTRUCTURA', id=>'EST-01', titulo=>'la pagina esta seccionada',
                    dato=>scalar(@vistas).' paginas · tipos: '.$resumen_tipos);

    # El informe dice DE DONDE sale el tipo, y con que reparto: una anatomia
    # exigida sobre un tipo ADIVINADO no vale lo mismo que sobre uno declarado.
    my $n_decl = scalar grep { $TIPO_DECL{$_} } @leidas_est;
    $inferido = $opt{tipo} ne ''  ? ''
              : $n_decl == 0      ? ' (INFERIDO de la ruta, no declarado)'
              : $n_decl == scalar(@leidas_est) ? ' (declarado con data-tipo)'
              : sprintf(' (%d de %d declaran data-tipo; el resto INFERIDO de la ruta)',
                        $n_decl, scalar(@leidas_est));
    # Un data-tipo con un valor inventado no se traga en silencio: si no esta en
    # la lista, la pagina cree que declara algo y el gate mide otra cosa.
    @TIPO_RAROS and aviso(lente=>'ESTRUCTURA', id=>'EST-02d', titulo=>'data-tipo con un valor que no existe',
                          donde=>join("\n                 ", @TIPO_RAROS[0..($#TIPO_RAROS>3?3:$#TIPO_RAROS)]),
                          ev=>[@TIPO_RAROS],
                          dato=>scalar(@TIPO_RAROS).' pagina(s) · se ha vuelto a inferir el tipo por la ruta',
                          umbral=>'data-tipo debe ser uno de: '.join(' ', sort keys %TIPOS_OK),
                          proc=>'09-tipos-de-pagina §2',
                          hacer=>'corregir el valor o quitar el atributo: declarar un tipo que el gate no conoce es creer que se declara algo mientras se mide otra cosa');

    # EST-02 · data-sec (PC4 / X2) · 0 de 121 paginas. NUNCA se reporta como PASA.
    if (@sin_datasec) {
        nv(lente=>'ESTRUCTURA', id=>'EST-02', titulo=>"anatomia por ROL de la pagina$inferido",
           donde=>join(' · ', @sin_datasec[0..($#sin_datasec>2?2:$#sin_datasec)]),
           ev=>[@sin_datasec],
           dato=>scalar(@sin_datasec).' de '.scalar(@vistas).' paginas no declaran data-sec (0 de 121 paginas nuestras lo hacen) · tipos: '.$resumen_tipos,
           umbral=>'cada seccion con data-sec="<rol>", y los roles OBL del tipo de CADA pagina (09 §2)',
           proc=>'X2/PC4 · 09 §1 lo EXIGE y ningun generador lo emite: la comprobacion 2 de las 7 de 09 §7 nunca se ha ejecutado sobre ninguna pagina',
           hacer=>'decidir de una vez: o los generadores emiten data-sec, o el gate infiere el rol por otra via. Hoy hay un contrato que no cumple nadie, que es la peor de las dos opciones');
        # sustituto honesto, marcado como heuristica: cuenta secciones contra roles
        @heur and aviso(lente=>'ESTRUCTURA', id=>'EST-02b', titulo=>'HEURISTICA: menos secciones que roles obligatorios',
                        donde=>join("\n                 ", @heur[0..($#heur>3?3:$#heur)]),
                        ev=>[@heur],
                        dato=>scalar(@heur).' de '.scalar(@vistas).' paginas',
                        umbral=>'>= un bloque por rol OBL (heuristica: NO sustituye a data-sec)',
                        proc=>'09 §2 · sucedaneo mientras EST-02 sea inverificable',
                        hacer=>'abrir la pagina y comprobar a mano que estan los roles OBL de su tipo (09 §2)');
    }
    if ($con_datasec) {
        @anat_mal ? fallo(lente=>'ESTRUCTURA', id=>'EST-02c', titulo=>"anatomia incompleta$inferido",
                          donde=>join("\n                 ", @anat_mal[0..($#anat_mal>3?3:$#anat_mal)]),
                          ev=>[@anat_mal],
                          dato=>scalar(@anat_mal).' de '.scalar(@vistas).' paginas',
                          umbral=>'todos los roles OBL de 09 §2, por tipo de pagina', proc=>'09-tipos-de-pagina §2',
                          hacer=>'cada rol que falta tiene su consecuencia escrita en 09 §2. Los moldes estan en references/moldes/')
                  : pasa(lente=>'ESTRUCTURA', id=>'EST-02c', titulo=>'anatomia completa en las paginas que declaran data-sec');
    }

    # ── EST-10 · un desplegable con menos de 3 destinos no es un desplegable ──
    # El umbral es 3 y no 2 a proposito: con dos entradas, el desplegable cuesta
    # mas de lo que reparte —dos gestos (abrir y elegir) para lo que cabe en uno—
    # y ademas el padre YA es uno de los destinos en el molde web-nav-001.
    @drop_rotos and fallo(lente=>'ESTRUCTURA', id=>'EST-10b', titulo=>'un control apunta a un panel que no existe',
                          donde=>join("\n                 ", @drop_rotos[0..($#drop_rotos>3?3:$#drop_rotos)]),
                          ev=>[@drop_rotos],
                          dato=>scalar(@drop_rotos).' control(es)',
                          umbral=>'todo aria-controls resuelve a un elemento con ese id',
                          proc=>'16-revision-paso-a-paso paso 1',
                          hacer=>'un boton que anuncia un panel inexistente no abre nada, y con teclado deja el foco muerto');
    if (!$drop_mirados) {
        pasa(lente=>'ESTRUCTURA', id=>'EST-10', titulo=>'desplegables del menu',
             dato=>'ninguno: el menu de este sitio no tiene desplegables');
    } else {
        @drop_pobres ? fallo(lente=>'ESTRUCTURA', id=>'EST-10', titulo=>'desplegable con menos de 3 destinos',
                             donde=>join("\n                 ", @drop_pobres[0..($#drop_pobres>3?3:$#drop_pobres)]),
                             ev=>[@drop_pobres],
                             dato=>scalar(@drop_pobres).' de '.$drop_mirados.' paneles mirados',
                             umbral=>'>=3 destinos DISTINTOS por panel de menu',
                             proc=>'climentmedia 13-ago: se sacaron 3 agentes del panel «Agents» y quedo con 2 enlaces, uno el mismo del padre. Lo vio Manuel, no un gate',
                             hacer=>'colapsar el desplegable a un <a> EN LA MISMA TANDA en que se le quitan entradas: un chevron que promete un menu y entrega dos enlaces es peor que no tenerlo')
                     : pasa(lente=>'ESTRUCTURA', id=>'EST-10', titulo=>'los desplegables del menu reparten',
                            dato=>$drop_mirados.' panel(es) mirados, todos con >=3 destinos');
    }

    # ── EST-12 · EL PIE (paso 2 de 16-revision-paso-a-paso) ─────────────────
    @sin_pie ? fallo(lente=>'ESTRUCTURA', id=>'EST-12', titulo=>'paginas sin <footer>',
                     donde=>join("\n                 ", @sin_pie[0..($#sin_pie>3?3:$#sin_pie)]),
                     ev=>[@sin_pie], dato=>scalar(@sin_pie).' de '.scalar(@vistas).' paginas',
                     umbral=>'todas las paginas llevan <footer>',
                     proc=>'16-revision-paso-a-paso paso 2',
                     hacer=>'sin pie no hay donde poner los legales, el NAP ni el mapa minimo')
            : pasa(lente=>'ESTRUCTURA', id=>'EST-12', titulo=>'todas las paginas llevan pie',
                   dato=>scalar(@vistas).' paginas');

    @pie_sin_legal and fallo(lente=>'ESTRUCTURA', id=>'EST-12b', titulo=>'el pie no enlaza los legales',
                     donde=>join("\n                 ", @pie_sin_legal[0..($#pie_sin_legal>3?3:$#pie_sin_legal)]),
                     ev=>[@pie_sin_legal], dato=>scalar(@pie_sin_legal).' de '.scalar(@vistas).' paginas',
                     umbral=>'>=2 enlaces legales en el pie (aviso legal, privacidad, cookies...)',
                     proc=>'16-revision-paso-a-paso paso 2',
                     hacer=>'un sitio que recoge datos y esconde su politica no tiene un problema de SEO: el visitante no puede ejercer nada');

    # 🔴 El defecto de las DOS LISTAS para el mismo hecho, aplicado al telefono.
    @nap_discrepa ? fallo(lente=>'ESTRUCTURA', id=>'EST-12c', titulo=>'el telefono del pie NO es el del schema',
                     donde=>join("\n                 ", @nap_discrepa[0..($#nap_discrepa>3?3:$#nap_discrepa)]),
                     ev=>[@nap_discrepa], dato=>scalar(@nap_discrepa).' pagina(s)',
                     umbral=>'el tel: del pie coincide con "telephone" del JSON-LD',
                     proc=>'mismo fallo que caza R6 con las migas: dos listas para una jerarquia',
                     hacer=>'cuando cambia el numero se cambia en uno de los dos sitios, y a partir de ahi Google publica un telefono y el visitante ve otro')
                  : pasa(lente=>'ESTRUCTURA', id=>'EST-12c', titulo=>'el NAP del pie cuadra con el schema');

    # AVISO y no FALLO mientras no lo declare ninguna web: un check que se pone
    # rojo en las cinco a la vez ensena a ignorar el gate (misma razon que 2-bis).
    @sin_autoria and aviso(lente=>'ESTRUCTURA', id=>'EST-12d', titulo=>'el pie no lleva el enlace de autoria',
                     donde=>join(' · ', @sin_autoria[0..($#sin_autoria>2?2:$#sin_autoria)]),
                     ev=>[@sin_autoria], dato=>scalar(@sin_autoria).' de '.scalar(@vistas).' paginas',
                     umbral=>'un enlace de autoria a climentmedia.com en el pie',
                     proc=>'16-revision-paso-a-paso paso 2 · decidido por Manuel el 17-ago: en el pie, en todas',
                     hacer=>'y con TEXTO DISTINTO por sitio: el mismo enlace en las cinco webs es un patron de red de enlaces. Un enlace de autoria apunta a una pagina que explica quien hizo la web');

    # Si lo lleva, el ancla no puede ser la marca pelada: eso es exactamente el
    # patron que se quiere evitar.
    @autoria_marca and fallo(lente=>'ESTRUCTURA', id=>'EST-12e', titulo=>'el enlace de autoria usa la marca como ancla',
                     donde=>join("\n                 ", @autoria_marca[0..($#autoria_marca>3?3:$#autoria_marca)]),
                     ev=>[@autoria_marca], dato=>scalar(@autoria_marca).' pagina(s)',
                     umbral=>'ancla descriptiva, distinta en cada web',
                     proc=>'16-revision-paso-a-paso paso 2',
                     hacer=>'«Climent Media» repetido en el pie de las cinco webs es la firma de una red de enlaces. Un enlace de autoria dice QUE se hizo, no solo quien');

    keys %anclas_autoria and nv(lente=>'ESTRUCTURA', id=>'EST-12f', titulo=>'el ancla de autoria, para comparar entre webs',
                     dato=>join(' · ', map { "«$_» x$anclas_autoria{$_}" } sort keys %anclas_autoria),
                     umbral=>'ancla DISTINTA en cada una de las webs que hacemos',
                     proc=>'un solo sitio no puede saberlo: hace falta mirar las cinco',
                     hacer=>'comparar esta ancla con la de las otras cuatro webs. Si se repite, es el patron que Google lee como red de enlaces');

    # ── EST-11 · vocabulario NUESTRO delante del visitante ────────────────────
    @vocab_mal ? fallo(lente=>'ESTRUCTURA', id=>'EST-11', titulo=>'el visitante esta leyendo vocabulario interno',
                       donde=>join("\n                 ", @vocab_mal[0..($#vocab_mal>3?3:$#vocab_mal)]),
                       ev=>[@vocab_mal],
                       dato=>scalar(@vocab_mal).' caso(s) en '.scalar(@leidas_est).' paginas',
                       umbral=>'ningun texto visible es un rol, un slug ni una instruccion para robots',
                       proc=>'14-ago-2026 · site-c publico <h1>hero</h1>, diez <h2> con nombre de rol y una miga con el slug crudo; site-d enseñaba el campo cepo. Los cuatro son HTML valido y no los miraba nada',
                       hacer=>'un rol es vocabulario de la anatomia y un slug es una ruta: si el contenido no trae titular, la seccion sale SIN titular. Nunca se rellena con el nombre de la pieza')
              : pasa(lente=>'ESTRUCTURA', id=>'EST-11', titulo=>'nada de vocabulario interno a la vista',
                     dato=>scalar(@leidas_est).' paginas');
    }   # fin del bloque «al menos una pagina legible»

    # ── EST-03 · LA 404 (G7 / X5) ───────────────────────────────────────────
    # 09 §2.11 la especifica. 08-qa-final.md la menciona 0 veces. site-d sirve
    # 796 bytes con 0 enlaces: callejon sin salida en una web que paga clics.
    my $probe = "$ROOT/no-existe-qa-maestro-" . substr(md5_hex(time),0,8);
    # 🔴 NO-DETERMINISMO ENCONTRADO AL CERRAR EL AGUJERO DE LA HUELLA
    #    (11-ago-2026, site-b). El sufijo del sondeo es `md5(time)`: cambia
    #    CADA SEGUNDO. Iba dentro del DONDE, y por tanto dentro de la huella,
    #    asi que EST-03 daba una huella distinta en cada corrida y una
    #    aceptacion suya NO PODIA CASAR NUNCA — ni recien copiada del informe.
    #    Un silenciador que no se puede usar es tan malo como uno que silencia
    #    de mas: el que lo intenta cree que ha firmado algo y no ha firmado nada.
    #    La URL sigue siendo aleatoria (que es lo que garantiza que no exista);
    #    lo que no puede ser aleatorio es la EVIDENCIA, porque el hallazgo no es
    #    «esta URL concreta», es «este sitio no trata bien las URLs que no
    #    existen». Se arregla en ORIGEN: la identidad del hallazgo no lleva el
    #    token volatil.
    my $probe_ev = "$ROOT/no-existe-qa-maestro-<aleatorio>";
    my $p404 = fetch($probe);
    if ($p404->{code} != 404) {
        fallo(lente=>'ESTRUCTURA', id=>'EST-03', titulo=>'una URL inexistente no devuelve 404',
              donde=>$probe_ev, dato=>"HTTP $p404->{code}", umbral=>'404',
              proc=>'09 §2.11 · G7', hacer=>'un 200 en una URL inventada hace que el buscador indexe basura infinita');
    } else {
        my @a = $p404->{body} =~ /<a\b[^>]*href=["']([^"']+)["']/gi;
        my @int = grep { my $x = abs_url($_, $probe); $x && is_internal($x) } @a;
        my $h1  = $p404->{body} =~ /<h1\b/i ? 1 : 0;
        my $viv = 0;
        for my $x (@int[0 .. ($#int > 4 ? 4 : $#int)]) {
            my $au = abs_url($x, $probe) or next;
            $viv++ if fetch($au)->{code} == 200;
        }
        # 🔴 EST-03 TIENE DOS MITADES Y SOLO UNA ES DEL ARBOL.
        #    · el CONTENIDO del 404 (h1, salidas, cromo) esta en `404.html`: eso
        #      se mide igual de bien contra el candidato, y si esta mal se dice.
        #    · que el HOST devuelva 404 —y no un 200 con basura indexable— es
        #      configuracion, y el que ha contestado 404 aqui es mi servidor de
        #      pruebas. Asi que el candidato NO puede dar PASA a este check: da
        #      NO VERIFICADO diciendo que el contenido si cumple.
        (@int >= 3 && $h1 && $viv >= 3)
          ? ($CAND_ON
              ? nv_cand(lente=>'ESTRUCTURA', id=>'EST-03', titulo=>'la 404: contenido OK, estado sin medir',
                        dato=>scalar(@int)." enlaces internos y h1 en el 404.html del candidato ($viv vivos)",
                        umbral=>'404 real del host + h1 propio + >=3 enlaces internos vivos',
                        proc=>'09 §2.11 · G7 · el ESTADO 404 lo da el host, no el arbol',
                        motivo=>'el contenido del 404.html cumple; que el host lo sirva CON estado 404 solo se ve en produccion',
                        hacer=>'comprobarlo despues de subir: curl -o /dev/null -w "%{http_code}" https://dominio/loquesea')
              : pasa(lente=>'ESTRUCTURA', id=>'EST-03', titulo=>'la pagina 404 saca de ahi', dato=>scalar(@int)." enlaces internos, $viv comprobados vivos"))
          : fallo(lente=>'ESTRUCTURA', id=>'EST-03', titulo=>'la pagina 404 es un callejon sin salida',
                  donde=>$probe_ev, dato=>sprintf('%d bytes · h1: %s · %d enlaces internos · %d vivos',
                                               length($p404->{body}), ($h1?'si':'NO'), scalar(@int), $viv),
                  umbral=>'404 + h1 propio + >=3 enlaces internos que den 200 + el mismo cromo que el resto',
                  proc=>'09 §2.11 lo especifica y 08-qa-final.md menciona «404» exactamente 0 veces · site-d sirve 796 bytes con CERO <a> · el 404 de site-c es la UNICA de sus 20 paginas que pasa structure-gate.js',
                  hacer=>'un bloque: que ha pasado, buscador si existe, y 3-5 enlaces a lo mas buscado');
    }

    # EST-04 · pagina de gracias
    if ($opt{gracias} ne '') {
        my $g = fetch("$ROOT$opt{gracias}");
        if ($g->{code} != 200) {
            fallo(lente=>'ESTRUCTURA', id=>'EST-04', titulo=>'la pagina de gracias no responde 200',
                  donde=>"$ROOT$opt{gracias}", dato=>"HTTP $g->{code}", umbral=>'200',
                  proc=>'09 §2.10', hacer=>'sin ella no hay disparador de conversion por URL, que es como funciona de verdad la unica web nuestra que mide bien');
        } else {
            my $noindex = ($g->{body} =~ /noindex/i) ? 1 : 0;
            my @sal = grep { my $x=abs_url($_,"$ROOT$opt{gracias}"); $x && is_internal($x) }
                      ($g->{body} =~ /<a\b[^>]*href=["']([^"']+)["']/gi);
            ($noindex && @sal >= 1)
              ? pasa(lente=>'ESTRUCTURA', id=>'EST-04', titulo=>'pagina de gracias', dato=>'noindex + '.scalar(@sal).' salidas')
              : fallo(lente=>'ESTRUCTURA', id=>'EST-04', titulo=>'pagina de gracias mal montada',
                      donde=>"$ROOT$opt{gracias}", dato=>($noindex?'':'sin noindex · ').scalar(@sal).' enlaces de salida',
                      umbral=>'noindex + al menos una salida + que diga QUE PASA AHORA y CUANDO',
                      proc=>'09 §2.10', hacer=>'sin noindex compite con la pagina de contacto en el buscador; sin salida, el visitante que acaba de convertir se queda en blanco');
        }
    } else {
        nv(lente=>'ESTRUCTURA', id=>'EST-04', titulo=>'pagina de gracias',
           umbral=>'noindex + salida + plazo de respuesta',
           proc=>'09 §2.10 · G1 (el fallo mas caro vive en la unica pagina que el gate no visita)',
           hacer=>'volver a correr con --gracias /ruta. Si no existe la ruta, ESO es el hallazgo');
    }

    # ── EST-05..07 · lo que necesita DOM ────────────────────────────────────
    if (%DOM) {
        my $iw = $DOM{innerWidth} // 0;
        my $ih = $DOM{innerHeight} // 0;
        # PC15 · la skill repite cuatro veces «imprimir innerWidth» y no menciona
        # innerHeight ni una vez — y measure-screens.js DIVIDE por el.
        if (!$iw || !$ih) {
            nv(lente=>'ESTRUCTURA', id=>'EST-05', titulo=>'medidas de DOM',
               dato=>"innerWidth=$iw innerHeight=$ih",
               umbral=>'el JSON tiene que traer innerWidth e innerHeight',
               proc=>'PC15 · 3 paginas se midieron a 664 en vez de 720 (--disable-web-security lo cambia): 8,4% de inflacion en pantallas de scroll',
               hacer=>'volver a capturar con el snippet completo');
        } else {
            my $pant = $DOM{screens} // 0;
            my $ctas = $DOM{ctas} // 0;
            my $desb = $DOM{blocks_over_1screen} // 0;
            my $gapmax = $DOM{max_gap_screens} // 0;
            my $prosa  = $DOM{es_pagina_prosa} ? 'si' : 'no';
            my @d;
            # Sospecha de metodo: el limite de 6 pantallas NO aplica a prosa.
            push @d, sprintf('bloque > 1 pantalla: %d', $desb) if $desb > 0;
            push @d, sprintf('tramo sin CTA: %.1f pantallas', $gapmax) if $gapmax > 2.5;
            push @d, sprintf('pagina: %.1f pantallas', $pant) if $pant > 6 && !$DOM{es_pagina_prosa};
            # 🔴 LA UNICA EXCEPCION DECLARADA (08-qa-final): si falla SOLO por el
            # umbral de CTAs y su interaccion principal son <button>, es un FALSO
            # FALLA. Medido el 7-ago en shop.site-b.example/a-medida.html: 0 CTA en
            # una pagina que es un configurador de 6 pasos, o sea TODA ELLA
            # mecanismo de conversion. Sus botones son button.choice y
            # button.stepper__item.
            # NO se cambian las clases del componente para que el gate lo vea:
            # eso es maquillar el instrumento y deja la web peor que antes.
            my $conf = ($ctas < 2 && ($DOM{buttons_visibles} // 0) >= 3);
            if ($ctas < 2 && !$conf) { push @d, sprintf('CTAs: %d', $ctas) }
            elsif ($conf) {
                aviso(lente=>'ESTRUCTURA', id=>'EST-06b', titulo=>'FALSO FALLA de CTAs: pagina-configurador',
                      donde=>$u, dato=>"$ctas CTA con clase reconocida, pero ".$DOM{buttons_visibles}.' <button> visibles',
                      umbral=>'excepcion declarada, no se arregla',
                      proc=>'08-qa-final «la unica excepcion declarada» · medido en shop.site-b.example/a-medida.html el 7-ago-2026',
                      hacer=>'ANOTARLO Y SEGUIR. 🔴 No cambies las clases del componente para que el gate lo vea');
            }
            @d ? fallo(lente=>'ESTRUCTURA', id=>'EST-06', titulo=>'densidad y CTAs',
                       donde=>"$u a innerWidth=$iw innerHeight=$ih",
                       dato=>join(' · ', @d)." · esPaginaProsa: $prosa",
                       umbral=>'ningun bloque >1 pantalla · <=2,5 pantallas sin CTA · >=2 CTA · <=6 pantallas SOLO si no es prosa',
                       proc=>'08-qa-final A-bis · sospecha de metodo: el gate aplicaba el mismo limite de 6 pantallas a paginas de PROSA (4 de 15). Lo que SI es defecto sin discusion es el tramo sin CTA y el bloque desbordado',
                       hacer=>'partir el bloque desbordado y repartir CTAs. Al migrar se conserva el CONTENIDO; la maqueta se rehace')
               : pasa(lente=>'ESTRUCTURA', id=>'EST-06', titulo=>'densidad y CTAs',
                      dato=>sprintf('%.1f pantallas · %d CTA · 0 desbordes · esPaginaProsa: %s (medido a %dx%d)', $pant, $ctas, $prosa, $iw, $ih));

            # G6 · estados de contenido real
            my @e;
            push @e, "fila coja: $DOM{filas_cojas}"          if ($DOM{filas_cojas}//0)      > 0;
            push @e, "titular huerfano: $DOM{titulares_huerfanos}" if ($DOM{titulares_huerfanos}//0) > 0;
            push @e, "alturas desiguales: $DOM{alturas_desiguales}" if ($DOM{alturas_desiguales}//0) > 0;
            push @e, "rejilla con 1 elemento: $DOM{listas_de_uno}"  if ($DOM{listas_de_uno}//0)  > 0;
            @e ? fallo(lente=>'ESTRUCTURA', id=>'EST-07', titulo=>'estados de contenido real',
                       donde=>$u, dato=>join(' · ', @e),
                       umbral=>'0 huecos en la ultima fila · 0 titulares con la ultima linea de UNA palabra · alturas de hermanos dentro del 25% · ninguna rejilla de >=2 columnas con 1 hijo',
                       proc=>'G6 · 18 filas cojas y 53 titulares huerfanos en las 5 webs. 03-rejilla lo llama «el tell mas visible» y esta en PROSA dentro del molde: no habia gate',
                       hacer=>'reequilibrar el numero de tarjetas o cambiar de columnas. Un hueco vacio en la ultima fila es lo primero que se ve')
               : pasa(lente=>'ESTRUCTURA', id=>'EST-07', titulo=>'estados de contenido real');
        }
    } else {
        nv(lente=>'ESTRUCTURA', id=>'EST-06', titulo=>'densidad, CTAs y estados de contenido (fila coja, titular huerfano, alturas)',
           umbral=>'ningun bloque >1 pantalla · <=2,5 pantallas sin CTA · >=2 CTA · 0 filas cojas',
           proc=>'08-qa-final A-bis/A-ter · G6',
           hacer=>"perl $0 --snippet > qa.js  ·  pegarlo en la consola a 1298 y a 390  ·  guardar el JSON  ·  volver con --dom qa.json");
    }

    # EST-08 · enlazado (grafo)
    nv(lente=>'ESTRUCTURA', id=>'EST-08', titulo=>'el grafo de enlaces: huerfanas, profundidad, anclas',
       umbral=>'0 huerfanas · profundidad <=3 · el hijo enlaza de vuelta al hub',
       proc=>'08-qa-final A-ter.3 · es el unico gate que mira el GRAFO: /blog/ de Site C listo 11 entradas sin enlazar a ninguna con todos los demas gates en verde',
       hacer=>"perl references/crawl-links.pl $ROOT/ /tmp/cache-enlaces /tmp/g.json 400  &&  perl references/linking-gate.pl /tmp/g.json");

    # EST-09 · repo vs produccion (G11)
    # 🔴 CONTRA EL CANDIDATO ESTE CHECK NO EXISTE, Y ES EL MAS IMPORTANTE DE
    #    DESACTIVAR BIEN: lo servido ES el repo, asi que compararlos daria
    #    «118 ficheros identicos · PASA» SIEMPRE. Seria un verde tautologico
    #    ocupando el sitio de la unica pregunta que importa despues de subir.
    #    G11 es, por definicion, la pregunta de DESPUES.
    if ($CAND_ON) {
        nv_cand(lente=>'ESTRUCTURA', id=>'EST-09', titulo=>'repo frente a produccion (G11)',
                dato=>'medido contra el CANDIDATO: aqui lo servido ES el repo, compararlos no comprueba nada',
                umbral=>'md5 de cada fichero servido == el del repo',
                proc=>'G11 · es la pregunta de DESPUES de subir, no la de antes',
                motivo=>'lo servido y el repo son el mismo arbol: la comparacion seria tautologica',
                hacer=>'DESPUES de subir: bash deploy.sh '.($opt{repo} ne '' ? $opt{repo} : 'REPO').' --servido');
    } elsif ($opt{repo} ne '' && -d $opt{repo}) {
        my @dist; my $n = 0;
        # 🔴 NO solo las paginas: tambien el CSS y el JS. El caso real que este
        #    gate existe para cazar es de site-d, y esta en styles.css (el
        #    arreglo de contraste de las 11:18 del 10-ago, sin desplegar). Un
        #    md5 solo sobre .html lo habria dado por verde.
        my @comparables = @PAGES;
        {
            my $hh = fetch($URLS[0])->{body} // '';
            for my $t ($hh =~ /(<link\b[^>]*>|<script\b[^>]*>)/gi) {
                my $href = attr($t,'href') // attr($t,'src') or next;
                next if ($t =~ /^<link/i) && (attr($t,'rel')//'') !~ /stylesheet/i;
                my $a = abs_url($href, base_ef($URLS[0])) or next;
                $a =~ s/\?.*$//;                    # el sellado ?v= no viaja al disco
                push @comparables, $a if is_internal($a) && !grep { $_ eq $a } @comparables;
            }
        }
        for my $u2 (@comparables) {
            my ($path) = $u2 =~ m{^https?://[^/]+(/.*)?$}; $path //= '/';
            my @cand = $path eq '/' ? ("$opt{repo}/index.html")
                     : ("$opt{repo}$path/index.html", "$opt{repo}$path.html", "$opt{repo}$path");
            my ($f) = grep { -f $_ } @cand;
            next unless $f;
            $n++;
            open my $fh, '<:raw', $f or next; local $/; my $local = <$fh>; close $fh;
            my $serv = fetch($u2)->{body} // '';
            # se comparan bytes: es barato y binario
            my $m_local = md5_hex($local);
            my $m_serv  = md5_hex($serv);
            # ── 🔴 EL MD5 EN LA EVIDENCIA, NO LA LONGITUD (11-ago-2026) ──────
            #  Este check DECIDE por md5 y luego apuntaba BYTES. La huella se
            #  calcula sobre la evidencia, asi que un cambio que no mueve la
            #  longitud no movia la huella. Caso medido: cambiar un telefono
            #  (+34917737078 -> +34600000000) en un fichero que ya diferia deja
            #  16575 B antes y 16575 B despues -> misma huella byte a byte, y una
            #  aceptacion de EST-09 lo SILENCIA.
            #  Y EST-09 es «el repo NO es lo que se sirve»: el unico check que,
            #  cuando falla, deja inutiles a los otros 73. Un silenciador ahi no
            #  se puede permitir, y fallaba hacia el lado inseguro.
            #  Van los dos lados porque el hallazgo es un PAR: si cambia el repo
            #  o cambia lo servido, es otro hallazgo y vuelve a contar.
            #  Los bytes se quedan al lado: no deciden nada, pero un humano leyendo
            #  «repo 16575 B / servido 16490 B» ve de que tamano es la diferencia.
            push @dist, sprintf('%s (repo %s %d B / servido %s %d B)',
                                $path, substr($m_local, 0, 8), length($local),
                                       substr($m_serv,  0, 8), length($serv))
                if $m_local ne $m_serv;
        }
        if (!$n) {
            nv(lente=>'ESTRUCTURA', id=>'EST-09', titulo=>'repo frente a produccion',
               dato=>'no he sabido mapear ninguna URL a un fichero del repo',
               umbral=>'md5 identico', proc=>'G11 · G5 (el mapeo URL->fichero tiene tres modos: dir, flat, extensionless)',
               hacer=>'comprobar la estructura del repo; sin el mapeo, esto no se ha medido');
        } elsif (@dist) {
            fallo(lente=>'ESTRUCTURA', id=>'EST-09', titulo=>'el repo NO es lo que se sirve',
                  donde=>join("\n                 ", @dist[0..($#dist>3?3:$#dist)]),
                  ev=>[@dist],
                  dato=>scalar(@dist).' de '.$n.' ficheros distintos',
                  umbral=>'md5 identico tras desplegar',
                  proc=>'G11 · verificado 10-ago: cm, site-a y site-c sirven los bytes del repo; site-d no —el arreglo de contraste de las 11:18 no estaba desplegado. Si el barrido dijera que las cinco estan mal, el sospechoso seria el barrido',
                  hacer=>'desplegar. 🔴 Un gate verde en local no dice NADA sobre lo que ve el visitante: este es el gate que hace inutiles a todos los demas cuando falla');
        } else {
            pasa(lente=>'ESTRUCTURA', id=>'EST-09', titulo=>'el repo es lo que se sirve', dato=>"$n ficheros identicos");
        }
    } else {
        nv(lente=>'ESTRUCTURA', id=>'EST-09', titulo=>'repo frente a produccion',
           umbral=>'md5 de cada fichero servido == el del repo',
           proc=>'G11 · es el gate que hace inutiles a todos los demas cuando falla',
           hacer=>'volver a correr con --repo C:/ruta/al/repo');
    }
}

# =============================================================================
#  9 · EL SNIPPET  ·  lo unico que necesita navegador
# =============================================================================
sub snippet_js {
    return <<'JS';
/* ===========================================================================
   qa-maestro · SNIPPET DE NAVEGADOR
   ---------------------------------------------------------------------------
   Se pega en la consola (o en javascript_tool del panel) de la pagina ya
   cargada, y devuelve un JSON. Se guarda ese JSON y se vuelve con:
       perl qa-master.pl <url> --dom fichero.json

   🔴 SE CORRE DOS VECES: a escritorio y a 390. En movil todo se apila, y un
      bloque que cabe a 1280 puede ocupar tres pantallas a 390.

   ⚠️ LO PRIMERO que se mira NO es el veredicto: es innerWidth Y innerHeight.
      · Chrome headless en Windows CLAMPA --window-size a ~500px, y
        --hide-scrollbars no devuelve los 18px: para 1280 hay que PEDIR 1298.
      · innerHeight tambien miente: --disable-web-security lo cambio de 720 a
        664 y eso son 8,4% de inflacion en «pantallas de scroll». La skill
        repite cuatro veces «imprimir innerWidth» y no menciona innerHeight ni
        una vez, y este calculo DIVIDE por el.
      Si los dos numeros no son los que se pidieron, la medicion se tira entera.
   =========================================================================== */
(() => {
  const out = { innerWidth: innerWidth, innerHeight: innerHeight,
                url: location.href, ts: new Date().toISOString() };
  const main = document.querySelector('main') || document.body;
  const vh = innerHeight || 1;

  // ── densidad y CTAs (08-qa-final A-bis) ──────────────────────────────────
  const doc = document.documentElement;
  out.screens = +(doc.scrollHeight / vh).toFixed(2);
  const bloques = [...main.children].filter(e => e.getBoundingClientRect().height > 4);
  out.blocks = bloques.length;
  out.blocks_over_1screen = bloques.filter(e => e.getBoundingClientRect().height > vh).length;

  // ⚠️ Limite conocido: no cuenta los <button> que son la interaccion principal
  //    de una pagina-configurador. Se cuentan aparte, para poder distinguir un
  //    FALLA real de un falso FALLA (08-qa-final, «la unica excepcion declarada»).
  const sel = 'a.btn,a.cta,[class*="btn"],[class*="cta"],a[href^="tel:"],a[href^="https://wa.me"],button[type=submit],form';
  const cta = [...main.querySelectorAll(sel)].filter(e => e.getBoundingClientRect().height > 0);
  out.ctas = cta.length;
  out.buttons_visibles = [...main.querySelectorAll('button:not([disabled])')]
      .filter(e => e.getBoundingClientRect().height > 0 && e.innerText.trim()).length;

  const tops = cta.map(e => e.getBoundingClientRect().top + scrollY).sort((a,b) => a-b);
  let gap = tops.length ? tops[0] : doc.scrollHeight, prev = tops[0] || 0;
  for (const t of tops) { gap = Math.max(gap, t - prev); prev = t; }
  gap = Math.max(gap, doc.scrollHeight - prev);
  out.max_gap_screens = +(gap / vh).toFixed(2);

  // pagina-prosa: hijos directos de <main> que son <p> sueltos
  const ps = [...main.children].filter(e => e.tagName === 'P').length;
  out.es_pagina_prosa = ps >= 8 && ps / Math.max(bloques.length,1) > 0.5;

  // ── G6 · estados de contenido real ───────────────────────────────────────
  // fila coja: se agrupan los hijos por offsetTop REAL (no por la clase CSS,
  // que miente en cuanto hay un wrap).
  let cojas = 0, unos = 0, alturas = 0;
  for (const g of document.querySelectorAll('[class*="grid"],[class*="rejilla"],[class*="cards"],ul[class*="col"]')) {
    const hijos = [...g.children].filter(e => e.getBoundingClientRect().height > 4);
    if (hijos.length < 1) continue;
    const filas = {};
    hijos.forEach(e => { const t = Math.round(e.getBoundingClientRect().top + scrollY);
                         (filas[t] = filas[t] || []).push(e); });
    const claves = Object.keys(filas);
    const cols = Math.max(...claves.map(k => filas[k].length));
    if (cols >= 2 && claves.length >= 2) {
      const ultima = filas[claves[claves.length-1]].length;
      if (ultima < cols) cojas++;
    }
    if (cols === 1 && hijos.length === 1 && g.getBoundingClientRect().width > hijos[0].getBoundingClientRect().width * 1.6) unos++;
    for (const k of claves) {
      const hs = filas[k].map(e => e.getBoundingClientRect().height);
      if (hs.length >= 2 && Math.max(...hs) > Math.min(...hs) * 1.25) { alturas++; break; }
    }
  }
  out.filas_cojas = cojas; out.listas_de_uno = unos; out.alturas_desiguales = alturas;

  // titular huerfano: la ULTIMA LINEA REAL con una sola palabra.
  // Se miden las lineas con Range.getClientRects, no contando caracteres.
  let huerfanos = 0;
  for (const h of document.querySelectorAll('h1,h2,h3')) {
    const n = h.firstChild; if (!n || n.nodeType !== 3) continue;
    const r = document.createRange(); r.selectNodeContents(h);
    const rects = [...r.getClientRects()];
    if (rects.length < 2) continue;
    const palabras = h.innerText.trim().split(/\s+/);
    // aproximacion honesta: si la ultima linea ocupa menos del 25% del ancho
    // del titular y hay mas de una linea, la ultima palabra va sola.
    const ancho = Math.max(...rects.map(x => x.width));
    if (rects[rects.length-1].width < ancho * 0.25 && palabras.length > 2) huerfanos++;
  }
  out.titulares_huerfanos = huerfanos;

  // ── Core Web Vitals de esta carga (PC2) ──────────────────────────────────
  try {
    const lcp = performance.getEntriesByType('largest-contentful-paint');
    out.lcp_ms = lcp.length ? Math.round(lcp[lcp.length-1].startTime) : null;
  } catch (e) { out.lcp_ms = null; }
  // El CLS NO se puede reconstruir despues: hay que observarlo desde el inicio.
  // Para medirlo, pegar ESTO ANTES de recargar la pagina, y luego el snippet:
  //   window.__cls_qa=0; new PerformanceObserver(l=>{for(const e of l.getEntries())
  //     if(!e.hadRecentInput) window.__cls_qa+=e.value;}).observe({type:'layout-shift',buffered:true});
  out.cls = (typeof window.__cls_qa === 'number') ? +window.__cls_qa.toFixed(4) : null;
  if (out.cls === null) out.cls_nota = 'CLS sin observador: queda NO VERIFICADO, que no es lo mismo que 0';

  // ── desbordamiento horizontal REAL ───────────────────────────────────────
  // ⚠️ getBoundingClientRect().right > innerWidth NO es desbordamiento: dio 35
  //    falsos positivos (tablas dentro de overflow-x:auto, un glow decorativo y
  //    el honeypot en left:-9999px). Lo real es scrollWidth del documento.
  out.overflow_horizontal = doc.scrollWidth > innerWidth + 1;
  out.doc_scrollWidth = doc.scrollWidth;

  console.log(JSON.stringify(out, null, 2));
  return out;
})();
JS
}

# =============================================================================
#  10 · EJECUCION Y REPORTE
# =============================================================================
lente_seo()         if $LENTE_ON{seo};
lente_rendimiento() if $LENTE_ON{rendimiento};
lente_a11y()        if $LENTE_ON{a11y};
lente_medicion()    if $LENTE_ON{medicion};
lente_estructura()  if $LENTE_ON{estructura};

# =============================================================================
#  10-bis · ACEPTADO  ·  la decision de negocio que ya se tomo
# =============================================================================
#  POR QUE EXISTE
#  --------------
#  El gate no sabia distinguir un defecto NUESTRO de una decision del CLIENTE.
#  Trataba igual «el favicon pesa 320 KB» —que es culpa nuestra y se arregla en
#  diez minutos— que «el cliente no ha decidido el plazo de conservacion de los
#  leads», que no se arregla escribiendo codigo. Consecuencia medida en site-a el
#  11-ago-2026: de sus 8 FALLOS, CERO eran defectos del arbol. Tres eran falsos
#  positivos del propio gate y cinco eran decisiones tomadas por Manuel o por el
#  cliente. Con eso, ninguna web puede estar verde mientras haya una decision
#  pendiente — y siempre las hay. **Un gate que nunca se puede satisfacer es un
#  gate que alguien apaga**, y el dia que lo apaguen tampoco protegera de los
#  defectos de verdad.
#
#  QUE NO ES
#  ---------
#  NO es `--aun-asi`. Ese es para lo que esta SIN MIRAR (NO VERIFICADO) y no
#  toca el rojo: el rojo sigue siendo parada dura. ACEPTADO tampoco borra nada:
#  el hallazgo se mide igual, se cuenta aparte, y sale en el recibo con su
#  nombre, su motivo, quien lo firma y hasta cuando. Nadie va a poder decir que
#  no lo sabia.
#
#  🔴 ESTO ES UN SILENCIADOR. Todo el diseño esta puesto en hacerlo dificil de
#     abusar, porque la version comoda de esto es un `# noqa` global:
#
#   1 · SE DECLARA EN EL REPO, no en la linea de ordenes: <repo>/_deploy/
#       aceptado.conf, versionado y legible. Una bandera se copia y se pega sin
#       pensar; un fichero se revisa en un diff y deja rastro de quien lo puso.
#   2 · CINCO CAMPOS OBLIGATORIOS: CHECK, HALLAZGO, MOTIVO, ACEPTA, FECHA. Si
#       falta uno, la entrada NO VALE y el fallo sigue contando. No se avisa y
#       se aplica igual: se rechaza y se dice por que.
#   3 · SE ACEPTA UN HALLAZGO, NO UN CHECK. Esta es la regla que decide si esto
#       sirve o se convierte en un silenciador global. `CHECK: MED-07` a secas
#       taparia tambien un MED-07 nuevo y distinto en otra pagina. Por eso cada
#       entrada casa contra la EVIDENCIA concreta —la huella de DATO y DONDE—, y
#       si la evidencia cambia deja de estar aceptada y VUELVE A CONTAR. El
#       informe imprime la huella exacta de cada FALLO para que escribirla sea
#       copiar, no adivinar.
#   4 · CADUCA. Una aceptacion sin fecha de fin es un defecto enterrado con
#       papeleo. Por defecto 90 dias, con tope duro de 180 (ver mas abajo).
#       Caducada = FALLO otra vez, sin ceremonia.
#   5 · HAY COSAS QUE NO SE PUEDEN ACEPTAR NUNCA. La lista vive AQUI, en el
#       gate, no en el fichero que el gate vigila: una lista de prohibidos que
#       se puede editar desde el mismo sitio que se quiere silenciar no prohibe
#       nada.
#
#  POR QUE 90 DIAS (y tope de 180)
#  -------------------------------
#  El plazo tiene que doler lo justo. Mas corto que un trimestre y hay que
#  re-decidir cada dos por tres: el fichero se vuelve tramite, y un tramite se
#  firma sin leer —que es exactamente el fallo que esto viene a evitar—. Mas
#  largo y nadie recuerda por que se acepto: la aceptacion «temporal» se hace
#  permanente por abandono, que es como muere un defecto conocido. 90 dias es un
#  trimestre: cae en un limite natural de revision con el cliente, y una
#  decision que lleva un trimestre sin moverse esta de verdad encallada y merece
#  volver a bloquear. El tope de 180 existe porque si no, alguien escribe
#  `HASTA: 2099-01-01` el primer dia y ya no hay caducidad: se rechaza la
#  entrada entera, no se recorta en silencio. Y el recibo avisa a 14 dias vista
#  —una vuelta de correo con el cliente— para que la caducidad no llegue como
#  una sorpresa el dia del despliegue.
# =============================================================================

# ── La huella del hallazgo ──────────────────────────────────────────────────
#  Es la EVIDENCIA, no el check: lo que cambia cuando la situacion cambia. El
#  titulo, el umbral, la procedencia y el «hacer» son texto fijo de la
#  definicion del check; DATO y DONDE son lo que se ha medido hoy.
#  Cuando el check no emite ninguna evidencia —A11Y-10 y MED-09 son asi: son
#  binarios y de sitio entero— la huella es TODO-EL-CHECK, escrito con todas
#  las letras. No es un comodin que se pueda usar a voluntad: si el hallazgo SI
#  trae evidencia, TODO-EL-CHECK no casa y el fallo sigue contando. Asi la
#  unica forma de aceptar un check entero es que el check no tenga instancias.
sub _norm_ev {
    my $s = shift;
    return '' unless defined $s;
    $s =~ s/\s+/ /g;               # DONDE llega multilinea y con sangria
    $s =~ s/^\s+|\s+$//g;
    return $s;
}

# ── 🔴 EL AGUJERO QUE ESTO CIERRA (11-ago-2026) ─────────────────────────────
#  La huella se calculaba sobre lo que se IMPRIME, y varios checks imprimen una
#  lista TRUNCADA («las 4 primeras») mas un contador. Consecuencia medida en
#  site-d con A11Y-08 (DATO=25 de 25 paginas, DONDE=las 4 primeras):
#
#    defecto nuevo en /odontologia — DENTRO de las 4 visibles → vuelve a contar
#    defecto nuevo en /contacto    — FUERA, y ya fallaba      → SIGUE SILENCIADO
#
#  Huella byte a byte identica en el segundo caso: empeorar una pagina que ya
#  fallaba y no esta entre las visibles no movia la huella. Fallaba hacia el
#  lado INSEGURO, que es el unico que no se puede permitir un silenciador.
#
#  Ahora la huella se calcula sobre `ev` —la evidencia COMPLETA— y la pantalla
#  sigue truncando. Cualquier pagina que entre o salga del hallazgo mueve la
#  huella y el fallo vuelve a contar.
#
#  POR QUE UN HASH Y NO LA LISTA ENTERA
#  ------------------------------------
#  Porque la huella se escribe A MANO en aceptado.conf, copiada del informe.
#  Con 25 rutas dentro serian ~3 KB en una linea: el fichero deja de ser
#  revisable en un diff, y ser revisable es la PRIMERA cerradura de este
#  mecanismo —antes que la caducidad y antes que la lista de prohibidos—. Un
#  silenciador que nadie puede leer es un silenciador que nadie audita.
#  Asi que la huella queda en dos piezas:
#      DATO=<el contador, legible>  EV=<8 hex del conjunto entero>
#  El DATO deja ver de un vistazo QUE se acepta; el EV ata la aceptacion al
#  conjunto exacto. 8 hex son 32 bits: para que una aceptacion tapara otro
#  hallazgo harian falta el MISMO check, el MISMO DATO y una colision de 1
#  entre 4.000 millones. El riesgo real de este fichero no son las colisiones,
#  es que nadie lo lea.
#  Para VER la evidencia entera antes de firmar: --evidencia.
use constant EV_HASH_LEN => 8;

# Orden estable + deduplicado. Sin esto, el mismo hallazgo puede dar huellas
# distintas entre corridas (orden de hash, orden de readdir) y una aceptacion
# VALIDA dejaria de casar sola. Eso falla hacia el lado seguro, pero erosiona
# la confianza en el fichero, y un fichero en el que nadie confia se apaga.
sub _ev_lista {
    my ($ev) = @_;
    return [] unless ref $ev eq 'ARRAY';
    my %v;
    for my $x (@$ev) {
        my $s = _norm_ev($x);
        next if $s eq '';
        $v{$s} = 1;
    }
    return [ sort keys %v ];
}
sub ev_hash {
    my ($ev) = @_;
    my $l = _ev_lista($ev);
    return undef unless @$l;
    # 🔴 14-ago-2026 · `md5_hex` NO ACEPTA CARACTERES ANCHOS, y muere con
    #    «Wide character in subroutine entry» -- sin veredicto, sin ID y sin
    #    linea en el recibo, que es el peor final posible para un gate.
    #    Salta en cuanto una evidencia trae texto de la PAGINA con acentos o
    #    comillas españolas, que es lo normal en cuatro de nuestras cinco webs.
    #    Lo destapo el fixture de EST-11 el dia que se escribio; hasta entonces
    #    ninguna evidencia habia llevado texto del contenido, solo URLs.
    #    Se codifica a UTF-8 (bytes) antes de resumir: el hash es estable y
    #    sigue siendo el mismo para la misma evidencia.
    my $txt = join("\n", @$l);
    utf8::encode($txt) if utf8::is_utf8($txt);
    return substr(md5_hex($txt), 0, EV_HASH_LEN);
}

sub huella_hallazgo {
    my ($c) = @_;
    my $d = _norm_ev($c->{dato});
    my $w = _norm_ev($c->{donde});
    # ── evidencia COMPLETA declarada: la huella la cubre entera ─────────────
    if (defined(my $h = ev_hash($c->{ev}))) {
        my @p;
        push @p, "DATO=$d" if $d ne '';
        # 🔴 EVP, no EV, cuando el alcance es PARCIAL. La huella dice en su
        #    propia cara que la aceptacion no puede garantizar todo el sitio.
        #    Y ata la aceptacion a ESE alcance: si manana se mide entero, la
        #    huella cambia y hay que volver a decidir con el dato bueno.
        push @p, ($c->{ev_parcial} ne '' ? "EVP=$h" : "EV=$h");
        return join(' ', @p);
    }
    # Sin `ev`: el DONDE ya es la evidencia entera (o no hay evidencia).
    my @p;
    push @p, "DATO=$d"  if $d ne '';
    push @p, "DONDE=$w" if $w ne '';
    # ── 🔴 EL ALCANCE PARCIAL TAMBIEN CUENTA SIN `ev` (11-ago-2026) ──────────
    #  El marcador EVP vivia dentro de la rama que exige `ev`, asi que un check
    #  sin evidencia enumerable —A11Y-03, la PALETA, que sale de la union de las
    #  hojas DE LAS PAGINAS MIRADAS— tenia la MISMA huella medido sobre 25 de 40
    #  que medido sobre las 40. Es el agujero de EST-09 otra vez: una aceptacion
    #  firmada sobre media medida se presentaba como si cubriera el sitio, y al
    #  ampliar la cobertura no volvia a preguntar.
    #  `PARCIAL` a secas, sin el texto: el texto lleva numeros que cambian con
    #  cada corrida (25 de 40, 26 de 41) y eso haria caducar aceptaciones validas
    #  por crecer el sitemap. Lo que tiene que atar es el HECHO de ser parcial.
    push @p, 'PARCIAL' if defined $c->{ev_parcial} && $c->{ev_parcial} ne '';
    return @p ? join(' ', @p) : 'TODO-EL-CHECK';
}

# ── Lo que NO se puede aceptar nunca ────────────────────────────────────────
#  Criterio, y es uno solo para que se pueda discutir: el daño cae sobre el
#  VISITANTE, y es INVISIBLE para nosotros. Un favicon de 320 KB nos lo cuenta
#  la siguiente medicion; que un formulario de fisioterapia mande datos de salud
#  a un sitio donde no dice cuanto se guardan no lo cuenta nadie hasta que hay
#  una reclamacion. Lo que se queda FUERA de la lista tambien esta razonado:
#    · MED-10 (el receptor del formulario da 404) duele mucho —los leads se
#      pierden en silencio— y es candidato natural. NO se mete todavia porque
#      contra el CANDIDATO ya no es un FALLO: sale NO VERIFICADO-por-candidato
#      (el servidor de pruebas es estatico y no ejecuta PHP), asi que aqui no
#      protegeria de nada y en produccion prohibiria un id cuyo comportamiento
#      acaba de cambiar. Se mira cuando haya corridas de produccion con el nuevo
#      reparto; prohibir a ciegas es como se fabrica la puerta que nunca se
#      puede abrir que este encargo viene a quitar.
#      ⚠️ Lo mismo vale para MED-12, que SI esta en la lista: contra el
#      candidato tampoco es medible, asi que la prohibicion solo muerde en
#      produccion. Es donde tiene que morder.
#    · A11Y-* no esta: la accesibilidad es un continuo y el gate ya distingue
#      AA de AAA. Prohibir aceptar un nivel de titular seria ruido con galones.
#  Se casa contra el TITULO porque un mismo id cubre gravedades distintas:
#  MED-07 es «la politica no nombra a Google Analytics» (discutible, aceptable)
#  y tambien «hay contenedor y NO hay pagina de cookies» (no hay donde leer que
#  se hace con tus datos). Prohibir por id entero seria o dejar pasar lo grave o
#  bloquear para siempre lo leve.
my @NO_ACEPTABLE = (
    { id=>'MED-02', re=>undef,
      por=>'se ponen cookies de terceros ANTES de que el visitante acepte: no es forma, es fuga' },
    { id=>'MED-06', re=>undef,
      por=>'casilla de analitica/publicidad PREMARCADA: se otorga un consentimiento que nadie eligio' },
    { id=>'MED-07', re=>qr/no hay pagina de cookies/i,
      por=>'se recogen datos y no existe pagina donde leer que se hace con ellos' },
    { id=>'MED-08', re=>undef,
      por=>'una politica legal marcada como borrador EN VIVO: el sitio confiesa que no responde de su propio texto' },
    { id=>'MED-12', re=>undef,
      por=>'ruta interna servida por web (_leads, _secrets): ahi dentro hay nombres, telefonos e IPs' },
);
sub prohibido {
    my ($c) = @_;
    for my $p (@NO_ACEPTABLE) {
        next unless $c->{id} eq $p->{id};
        next if $p->{re} && ($c->{titulo} // '') !~ $p->{re};
        return $p->{por};
    }
    return undef;
}

# ── Fechas: ISO a epoch, en UTC y a mediodia ────────────────────────────────
#  A mediodia para que ningun cambio de hora convierta un «hoy» en un «ayer».
sub _iso_a_epoch {
    my ($s) = @_;
    return undef unless defined $s && $s =~ /^(\d{4})-(\d{2})-(\d{2})$/;
    my ($y,$m,$d) = ($1,$2,$3);
    return undef if $m < 1 || $m > 12 || $d < 1 || $d > 31;
    require Time::Local;
    my $t = eval { Time::Local::timegm(0,0,12,$d,$m-1,$y) };
    return $t;
}
sub _epoch_a_iso { my $t = shift; my @g = gmtime($t); return sprintf('%04d-%02d-%02d', $g[5]+1900, $g[4]+1, $g[3]) }

use constant DIA          => 86400;
use constant ACEPT_DIAS   => 90;    # por defecto
use constant ACEPT_TOPE   => 180;   # tope duro: mas alla, la entrada no vale
use constant ACEPT_AVISO  => 14;    # a partir de aqui el recibo avisa

# ── El lector del fichero ───────────────────────────────────────────────────
#  Formato de bloques. Se eligio en vez de una linea por entrada porque el
#  MOTIVO es prosa y una linea con cinco campos separados por `|` se vuelve
#  ilegible justo en el campo que hay que leer.
#      [ACEPTADO]
#      CHECK:    MED-09
#      HALLAZGO: TODO-EL-CHECK
#      MOTIVO:   ...
#      ACEPTA:   Nombre Apellido
#      FECHA:    2026-08-11
#      HASTA:    2026-11-09        (opcional; por defecto FECHA + 90 dias)
sub lee_aceptados {
    my ($repo) = @_;
    my $f = "$repo/_deploy/aceptado.conf";
    return ([], [], $f, 0) unless -f $f;
    open my $fh, '<:encoding(UTF-8)', $f or return ([], [], $f, 0);
    my (@buenas, @malas, %cur);
    my $linea_ini = 0;
    my $n = 0;
    my $cierra = sub {
        return unless %cur;
        my %e = %cur; %cur = ();
        $e{_linea} = $linea_ini;
        # ── los CINCO campos. Sin uno, la entrada NO VALE ────────────────────
        my @faltan = grep { !defined $e{$_} || $e{$_} =~ /^\s*$/ }
                     qw(CHECK HALLAZGO MOTIVO ACEPTA FECHA);
        if (@faltan) {
            $e{_mal} = 'faltan campos obligatorios: ' . join(', ', @faltan);
            push @malas, \%e; return;
        }
        my $ini = _iso_a_epoch($e{FECHA});
        unless (defined $ini) { $e{_mal} = "FECHA no es una fecha ISO (AAAA-MM-DD): $e{FECHA}"; push @malas, \%e; return }
        my $fin;
        if (defined $e{HASTA} && $e{HASTA} !~ /^\s*$/) {
            $fin = _iso_a_epoch($e{HASTA});
            unless (defined $fin) { $e{_mal} = "HASTA no es una fecha ISO (AAAA-MM-DD): $e{HASTA}"; push @malas, \%e; return }
            if ($fin < $ini) { $e{_mal} = "HASTA ($e{HASTA}) es anterior a FECHA ($e{FECHA})"; push @malas, \%e; return }
            # 🔴 El tope se RECHAZA, no se recorta. Recortar en silencio deja al
            #    que lo escribio creyendo que tiene dos años cuando tiene medio.
            if ($fin - $ini > ACEPT_TOPE * DIA) {
                $e{_mal} = sprintf('HASTA esta a %d dias de FECHA y el tope duro son %d. Una aceptacion mas larga que eso es un defecto enterrado: partela o arreglalo',
                                   int(($fin-$ini)/DIA), ACEPT_TOPE);
                push @malas, \%e; return;
            }
        } else {
            $fin = $ini + ACEPT_DIAS * DIA;
        }
        $e{_ini} = $ini; $e{_fin} = $fin;
        $e{_hasta_iso} = _epoch_a_iso($fin);
        $e{_dias} = int(($fin - time) / DIA);
        push @buenas, \%e;
    };
    while (my $l = <$fh>) {
        $n++;
        $l =~ s/^\x{FEFF}//;                 # BOM si lo puso un editor
        $l =~ s/\r?\n$//;
        next if $l =~ /^\s*#/;               # comentario
        if ($l =~ /^\s*\[ACEPTADO\]\s*$/i) { $cierra->(); $linea_ini = $n; %cur = (_abierto=>1); next }
        next if $l =~ /^\s*$/;
        if ($l =~ /^\s*([A-Za-z-]+)\s*:\s*(.*)$/) {
            my ($k, $v) = (uc $1, $2);
            $v =~ s/\s+$//;
            if (!$cur{_abierto}) { %cur = (_abierto=>1); $linea_ini = $n }
            $cur{$k} = $v;
        }
    }
    close $fh;
    $cierra->();
    return (\@buenas, \@malas, $f, 1);
}

# ── Aplicarlo ───────────────────────────────────────────────────────────────
#  Se hace DESPUES de correr las cinco lentes y ANTES de contar: el hallazgo se
#  mide igual que siempre —esto no apaga ninguna comprobacion—, solo cambia de
#  casilla al contarlo. Si alguien quita el fichero, el rojo vuelve solo.
my @ACEPTADOS;          # los que han casado
my @ACEPT_RECHAZADAS;   # entradas del fichero que NO valen, y por que
my @ACEPT_SOBRAN;       # entradas validas que no casan con ningun FALLO de hoy
my $ACEPT_FICHERO = '';
my $ACEPT_HAY     = 0;
my $ACEPT_CONF_MD5 = '';
if ($opt{repo} ne '' && -d $opt{repo}) {
    my ($buenas, $malas, $ruta, $hay) = lee_aceptados($opt{repo});
    $ACEPT_FICHERO = $ruta; $ACEPT_HAY = $hay;
    if ($hay && open(my $cf, '<:raw', $ruta)) { local $/; $ACEPT_CONF_MD5 = md5_hex(<$cf> // ''); close $cf }
    push @ACEPT_RECHAZADAS, { %$_, _por => $_->{_mal} } for @$malas;
    my %usada;
    for my $c (@R) {
        next unless $c->{estado} eq 'FALLO';
        my $h = huella_hallazgo($c);
        for my $e (@$buenas) {
            next unless ($e->{CHECK} // '') eq $c->{id};
            next unless _norm_ev($e->{HALLAZGO}) eq $h;
            # 1 · lo que no se puede aceptar nunca
            if (my $por = prohibido($c)) {
                push @ACEPT_RECHAZADAS, { %$e, _por => "NO ES ACEPTABLE: $por" };
                $usada{"$e"} = 1;
                last;
            }
            # 2 · caducidad
            if (time > $e->{_fin}) {
                push @ACEPT_RECHAZADAS, { %$e,
                    _por => sprintf('CADUCADA el %s (hace %d dias). Una aceptacion caducada vuelve a ser FALLO',
                                    $e->{_hasta_iso}, int((time - $e->{_fin})/DIA)) };
                $usada{"$e"} = 1;
                last;
            }
            # 3 · casa: cambia de casilla, no desaparece
            $c->{estado}   = 'ACEPTADO';
            $c->{_acept}   = $e;
            $c->{_huella}  = $h;
            push @ACEPTADOS, $c;
            $usada{"$e"} = 1;
            last;
        }
    }
    # Una entrada valida que no casa con nada es informacion, no un error: o el
    # hallazgo ya se arreglo (y sobra), o cambio (y el fallo ha vuelto a contar,
    # que es justo lo que se queria). Se dice, para que no se quede ahi de
    # adorno tapando algo que nadie vuelve a mirar.
    push @ACEPT_SOBRAN, $_ for grep { !$usada{"$_"} } @$buenas;
}

my %ICONO = ('FALLO'=>'FALLO', 'AVISO'=>'AVISO', 'NV'=>'NO VERIF', 'PASA'=>'PASA', 'ACEPTADO'=>'ACEPTADO');
my %N = (FALLO=>0, AVISO=>0, NV=>0, PASA=>0, ACEPTADO=>0);
$N{$_->{estado}}++ for @R;

my $fecha = strftime('%Y-%m-%d %H:%M', localtime);
print "\n";
print "=" x 78, "\n";
print "  QA MAESTRO  ·  $ROOT  ·  $fecha\n";
print "=" x 78, "\n";
print "  INSTRUMENTO  perl $] · curl · SIN navegador"
    . (%DOM ? " · DOM de $opt{dom} (innerWidth=".($DOM{innerWidth}//'?').", innerHeight=".($DOM{innerHeight}//'?').")" : " · sin DOM")
    . "\n";
# 🔴 LA LINEA QUE FALTABA. Un informe que no dice contra QUE se midio se lee
#    como si hablara de la web viva; el recibo que sale de el sella el arbol del
#    repo. Eran dos artefactos distintos con una sola cara.
if ($CAND_ON) {
    print "  MEDIDO       🔴 CANDIDATO · el arbol de $opt{repo}\n";
    print "               servido en http://127.0.0.1:$CAND_PORT · NO es produccion\n";
    print "               Esto responde «¿lo que voy a subir esta bien?».\n";
    print "               Lo que ve el visitante se comprueba DESPUES: deploy.sh REPO --servido (G11)\n";
    printf "               PETICIONES   %d al arbol · %d a fuera (terceros: GTM, gtag, fuentes...)\n",
           $CAND_DENTRO, $CAND_FUERA;
    print  "               ⚠ una URL del sitio en otro host (una variante www., otro subdominio)\n"
         . "                 cae en «a fuera» y se mide contra PRODUCCION sin decirlo. Si ese\n"
         . "                 numero no cuadra con los terceros que declara la web, mirarlo.\n"
        if $CAND_FUERA > 0;
    print "               $CACHE_NOTA\n" if $CACHE_NOTA ne '';
} else {
    print "  MEDIDO       PRODUCCION · $ROOT (lo que ve el visitante hoy)\n";
    print "               ⚠ NO dice nada de los cambios sin subir del repo. Para eso: --candidato\n"
        if $opt{repo} ne '';
}
print "  PAGINAS      " . scalar(@PAGES) . " · tipo: " . ($opt{tipo} ne '' ? $opt{tipo} : 'inferido por ruta (uno por pagina)')
    . ($EXPANDIDO ne '' ? "\n               $EXPANDIDO" : '')
    . ($DOCS_NOTA ne '' ? "\n               $DOCS_NOTA" : '') . "\n";
print "  LENTES       " . join(' ', grep { $LENTE_ON{$_} } qw(seo rendimiento a11y medicion estructura)) . "\n";
print "  REPO         " . ($opt{repo} ne '' ? $opt{repo} : 'no dado (MED-05 y EST-09 quedan sin verificar)') . "\n";

# ── ALCANCE · lo que mira cada lente, dicho ─────────────────────────────────
#  🔴 «[PASA] A11Y-08» sacado de 1 de 25 paginas se lee igual que sacado de las
#     25. Esta tabla es la mitad del arreglo 0.3: la otra mitad es que ya no
#     dependa del orden.
#
#  🔴 ARREGLO P5 (10-ago-2026) · EL DENOMINADOR ERA LA LISTA, NO EL SITIO.
#     Decia «SEO 25 de 25 · todas» debajo de una cabecera que en la linea de
#     arriba confesaba «25 del sitemap (40 disponibles, tope --max-urls 25)».
#     Las dos lineas no podian ser verdad a la vez: «todas» era todas LAS DE LA
#     LISTA AUDITADA, y quien lo lea entiende «todas las del sitio». Un informe
#     que se contradice consigo mismo se cree por la linea mas comoda. Ahora el
#     denominador es el SITIO cuando se sabe cuantas paginas tiene, y cuando no
#     se sabe se dice que no se sabe.
my $SITIO_DE = $SITIO_URLS;                 # URLs que tiene el sitio, si consta
if (%ALCANCE) {
    print "  ALCANCE      cuantas paginas ha mirado cada lente\n";
    printf "               denominador: %s\n",
           (defined $SITIO_DE
              ? "el SITIO ($SITIO_DE URLs en el sitemap), no la lista auditada"
              : 'la LISTA auditada · ⚠ no se cuantas paginas tiene el sitio, asi que NO se que porcion es');
    # El recorte, dicho UNA vez y entero, antes de la tabla. La tabla dice
    # cuanto mira cada lente; esta linea dice por que ninguna llega al final.
    printf "               ⚠ %s\n", $LISTA_PARCIAL if $LISTA_PARCIAL ne '';
    for my $l (qw(SEO RENDIMIENTO ACCESIBILIDAD MEDICION ESTRUCTURA)) {
        next unless $ALCANCE{$l};
        my $a  = $ALCANCE{$l};
        my $de = defined $a->{de} ? $a->{de} : (defined $SITIO_DE ? $SITIO_DE : scalar(@PAGES));
        #  🔴 «25 de 40» sin adjetivo se lee de pasada como «25 de 25»: el ojo
        #     coge el primer numero y sigue. PARCIAL es una palabra, no un
        #     cociente, y ademas se puede buscar con grep desde otro script.
        my $todo = ($a->{miradas} >= $de) ? ' · TODAS' : ' · PARCIAL';
        printf "               %-14s %2d de %2d%s%s\n", $l, $a->{miradas}, $de,
               (defined $SITIO_DE ? ' del sitio' : ' de la lista'), $todo;
        printf "               %-14s   (%d de %d de la lista auditada)\n", '', $a->{miradas}, scalar(@PAGES)
            if defined $SITIO_DE && $SITIO_DE != scalar(@PAGES);
        printf "               %-14s   %s\n", '', $a->{nota} if $a->{nota} ne '';
    }
    for my $l (qw(SEO RENDIMIENTO ACCESIBILIDAD MEDICION ESTRUCTURA)) {
        next unless $LENTE_ON{lc $l eq 'accesibilidad' ? 'a11y' : lc $l};
        next if $ALCANCE{$l};
        printf "               %-14s NO HA DECLARADO SU ALCANCE (tratalo como 1 de %d)\n", $l, scalar(@PAGES);
    }
}

my %TITULO = (
    'SEO'           => 'LENTE 1 · SEO / GEO / AEO',
    'RENDIMIENTO'   => 'LENTE 2 · RENDIMIENTO',
    'ACCESIBILIDAD' => 'LENTE 3 · ACCESIBILIDAD',
    'MEDICION'      => 'LENTE 4 · MEDICION Y LEGAL',
    'ESTRUCTURA'    => 'LENTE 5 · ESTRUCTURA Y MAQUETA',
);
for my $l (qw(SEO RENDIMIENTO ACCESIBILIDAD MEDICION ESTRUCTURA)) {
    my @x = grep { $_->{lente} eq $l } @R;
    next unless @x;
    print "\n", "-" x 78, "\n", "  $TITULO{$l}\n", "-" x 78, "\n";
    for my $c (sort { my %o=(FALLO=>0,AVISO=>1,ACEPTADO=>2,NV=>3,PASA=>4); $o{$a->{estado}} <=> $o{$b->{estado}} or $a->{id} cmp $b->{id} } @x) {
        next if $opt{q} && $c->{estado} eq 'PASA';
        printf "  [%-8s] %-9s %s\n", $ICONO{$c->{estado}}, $c->{id}, $c->{titulo};
        next if $c->{estado} eq 'PASA' && !$c->{dato};
        printf "               DATO   %s\n", $c->{dato}   if $c->{dato};
        next if $c->{estado} eq 'PASA';
        printf "               DONDE  %s\n", $c->{donde}  if $c->{donde};
        # 🔴 La huella, impresa en cada FALLO, es lo que hace usable el estado
        #    ACEPTADO sin volverlo un comodin: escribirla es COPIAR, no
        #    adivinar, y si el hallazgo cambia el que la copio ve al instante
        #    que la suya ya no es esta.
        printf "               HUELLA %s\n", huella_hallazgo($c) if $c->{estado} eq 'FALLO';
        # 🔴 QUE CUBRE LA HUELLA. Sin esta linea, alguien lee «DONDE: 4 rutas» y
        #    cree que acepta 4 cosas cuando esta aceptando 25. El numero que
        #    importa es el de la huella, no el de lo que cabe en pantalla.
        if ($c->{estado} eq 'FALLO' || $c->{estado} eq 'ACEPTADO') {
            my $l = _ev_lista($c->{ev});
            # 🔴 EL AVISO DE PARCIAL, FUERA DEL `if (@$l)` (11-ago-2026). Estaba
            #    dentro, asi que un check sin evidencia enumerable —A11Y-03, la
            #    PALETA— se imprimia sin una palabra sobre su alcance aunque lo
            #    tuviera recortado. El que firma una aceptacion lee ESTA pantalla.
            if ($c->{ev_parcial} ne '') {
                printf "               ⚠ PARCIAL %s\n", $c->{ev_parcial};
                printf "               ⚠ La huella lleva %s: esta aceptacion NO puede\n",
                       (@$l ? 'EVP (no EV)' : 'la marca PARCIAL');
                print  "                 garantizar todo el sitio, solo lo que se ha mirado.\n";
            }
            if (@$l) {
                printf "               ALCANCE la huella cubre %d · en pantalla caben menos%s\n",
                       scalar(@$l), ($opt{evidencia} ? '' : ' · --evidencia para verlas todas');
                if ($opt{evidencia}) {
                    print "               EVIDENCIA COMPLETA (la que entra en la huella):\n";
                    printf("                 %s\n", $_) for @$l;
                }
            }
        }
        if ($c->{estado} eq 'ACEPTADO') {
            my $e = $c->{_acept};
            printf "               HUELLA %s\n", $c->{_huella};
            printf "               MOTIVO %s\n", $e->{MOTIVO};
            printf "               FIRMA  %s · aceptado %s · caduca %s (quedan %d dias)\n",
                   $e->{ACEPTA}, $e->{FECHA}, $e->{_hasta_iso}, $e->{_dias};
            print  "               ⚠ NO cuenta para el veredicto, pero SIGUE MEDIDO y sale en el recibo.\n";
            printf "               ⚠ CADUCA EN %d DIAS y volvera a ser FALLO. Decidirlo antes.\n", $e->{_dias}
                if $e->{_dias} <= ACEPT_AVISO;
            print  "\n";
            next;
        }
        printf "               UMBRAL %s\n", $c->{umbral} if $c->{umbral};
        printf "               ORIGEN %s\n", $c->{proc}   if $c->{proc};
        printf "               %s %s\n", ($c->{estado} eq 'NV' ? 'COMO  ' : 'HACER '), $c->{hacer} if $c->{hacer};
        print  "\n";
    }
}

# 🔴 «PASA» A SECAS, NUNCA, SI HAY ACEPTADOS. El veredicto lo lee alguien que
#    no ha visto el informe —un recibo, un historial, otro agente— y «PASA» y
#    «PASA con cinco defectos conocidos que alguien firmo» no son la misma
#    frase. La coletilla viaja pegada al veredicto por todas partes: informe,
#    JSON, recibo e historial.
# 🔴 13-ago-2026 · UNA LENTE QUE NO HA MEDIDO NADA TAMPOCO ES «PASA».
#    Trampa §18, abierta desde el 11-ago con la nota «NO he comprobado si
#    deploy.sh dejaria pasar un recibo asi». MEDIDO hoy, apuntando el gate a
#    un puerto muerto con `--solo seo`:
#        [NO VERIF] SEO-00 la lente entera
#        VEREDICTO: PASA
#        FALLO 0 · AVISO 0 · ACEPTADO 0 · NO VERIFICADO 1 · PASA 0
#        exit 0 — y el recibo escribia «LENTE-SEO: PASA»
#    CERO comprobaciones pasadas y las dos caras -veredicto y recibo- diciendo
#    que si. La coletilla se pega al veredicto por el mismo motivo que la de los
#    aceptados: quien lee «PASA» a secas no ha visto el informe.
my @LENTES_SIN_MEDIR;
{
    my %por_lente;
    push @{ $por_lente{ $_->{lente} } }, $_ for grep { defined $_->{lente} } @R;
    for my $l (sort keys %por_lente) {
        # SIN MEDIR = todas sus comprobaciones en NV. Una sola PASA o AVISO ya
        # dice que la lente miro algo, y entonces no se puede llamar sin medir.
        push @LENTES_SIN_MEDIR, $l unless grep { ($_->{estado} // '') ne 'NV' } @{ $por_lente{$l} };
    }
}
my $veredicto = $N{FALLO} ? 'FALLA' : 'PASA';
$veredicto .= sprintf(' (con %d aceptado%s)', $N{ACEPTADO}, ($N{ACEPTADO}==1?'':'s')) if $N{ACEPTADO};
$veredicto .= sprintf(' · %d lente%s SIN MEDIR: %s',
                      scalar(@LENTES_SIN_MEDIR), (@LENTES_SIN_MEDIR == 1 ? '' : 's'),
                      join(' ', @LENTES_SIN_MEDIR)) if @LENTES_SIN_MEDIR;
print "\n", "=" x 78, "\n";
printf "  VEREDICTO: %s\n", $veredicto;
printf "    FALLO %d  ·  AVISO %d  ·  ACEPTADO %d  ·  NO VERIFICADO %d  ·  PASA %d\n",
       @N{qw(FALLO AVISO ACEPTADO NV PASA)};
print  "=" x 78, "\n";

# ── ACEPTADOS · id por id, con su nombre. Nadie puede decir que no lo sabia ──
if ($N{ACEPTADO}) {
    printf "  ACEPTADOS: %d · decisiones ya tomadas, NO defectos sin arreglar\n", $N{ACEPTADO};
    printf "    declarados en %s\n", $ACEPT_FICHERO;
    for my $c (sort { $a->{id} cmp $b->{id} } @ACEPTADOS) {
        my $e = $c->{_acept};
        printf "    %-9s %s\n", $c->{id}, $c->{titulo};
        printf "              %s\n", $e->{MOTIVO};
        printf "              firma %s · %s -> %s (%d dias)%s\n",
               $e->{ACEPTA}, $e->{FECHA}, $e->{_hasta_iso}, $e->{_dias},
               ($e->{_dias} <= ACEPT_AVISO ? '  🔴 CADUCA PRONTO' : '');
    }
    print  "    Siguen medidos y siguen en el recibo. Cuando caduquen vuelven a ser FALLO.\n";
}
# Entradas que NO valen. Se dicen SIEMPRE y en voz alta: una entrada rota que se
# ignora en silencio se lee como aplicada, y entonces alguien cree tener una
# decision firmada donde no hay nada.
if (@ACEPT_RECHAZADAS) {
    printf "\n  🔴 %d ENTRADA%s DE aceptado.conf NO VALE%s · el fallo SIGUE CONTANDO\n",
           scalar(@ACEPT_RECHAZADAS), (@ACEPT_RECHAZADAS==1?'':'S'), (@ACEPT_RECHAZADAS==1?'':'N');
    for my $e (@ACEPT_RECHAZADAS) {
        printf "    %-9s (linea %s)  %s\n", ($e->{CHECK} // '(sin CHECK)'), ($e->{_linea} // '?'), $e->{_por};
    }
}
if (@ACEPT_SOBRAN) {
    printf "\n  ⚠ %d entrada%s de aceptado.conf no casa%s con ningun FALLO de hoy:\n",
           scalar(@ACEPT_SOBRAN), (@ACEPT_SOBRAN==1?'':'s'), (@ACEPT_SOBRAN==1?'':'n');
    printf "    %-9s %s\n", ($_->{CHECK} // '?'), _norm_ev($_->{HALLAZGO}) for @ACEPT_SOBRAN;
    print  "    O el hallazgo se arreglo —y la entrada sobra, quitala— o CAMBIO, y entonces\n";
    print  "    el fallo ha vuelto a contar arriba, que es exactamente lo que tenia que pasar.\n";
}
if ($N{NV}) {
    print "  ⚠ NO VERIFICADO NO ES UN APROBADO. $N{NV} comprobaciones no las ha mirado\n";
    print "    nadie. Un informe que no dice lo que ha dejado fuera se lee como si lo\n";
    print "    cubriera todo, y eso es lo que hace que un fallo pase el gate.\n";
}
# 🔴 LOS QUE NO SE HAN MEDIDO *POR SER EL CANDIDATO*, UNO A UNO Y CON SU MOTIVO.
#    No van mezclados con los demas huecos a proposito: estos no se arreglan
#    mirando mas, se contestan SUBIENDO y midiendo produccion. Enumerarlos es la
#    unica forma de que quien lee el recibo sepa que le falta por saber.
if (@NV_CAND) {
    print "\n";
    printf "  LO QUE EL CANDIDATO NO PUEDE MEDIR (%d) · no son huecos: son la pregunta de DESPUES\n", scalar(@NV_CAND);
    printf "    %-9s %s\n", $_->{id}, $_->{motivo} for @NV_CAND;
    print  "    Ninguno sale PASA aqui: un PASA que no se ha medido es la enfermedad que\n";
    print  "    este gate existe para curar. Los contesta G11 despues de subir:\n";
    print  "        bash deploy.sh " . ($opt{repo} ne '' ? $opt{repo} : 'REPO') . " --servido\n";
}
if ($N{FALLO}) {
    print "  🔴 EN ROJO NO SE DESPLIEGA (SKILL.md · 06-publicar.md · G14).\n";
    print "     El gate de densidad existe desde el 7-ago y tres dias despues 12 de 15\n";
    print "     paginas seguian en rojo: sin esta regla, un gate es un informe.\n";
    print "     Si alguno de estos NO es un defecto nuestro sino una decision ya tomada\n";
    print "     —del cliente o de Manuel—, se declara con su HUELLA, su motivo, su firma\n";
    print "     y su fecha en " . ($opt{repo} ne '' ? "$opt{repo}/_deploy/aceptado.conf" : '<repo>/_deploy/aceptado.conf') . ".\n";
    print "     Deja de contar para el veredicto y SIGUE saliendo en el recibo, con nombre.\n";
    print "     Lo que NO es: una forma de tapar un defecto nuestro. Caduca, y hay cosas\n";
    print "     que no se pueden aceptar nunca (el gate las rechaza y dice cuales).\n";
}
print "  Faltan los BLOQUES B (mirar) y C (las preguntas) de 08-qa-final.md.\n";
print "  Ningun script encuentra lo que no se le ha escrito.\n";

if ($opt{json} ne '') {
    open my $jf, '>:raw', $opt{json} or die "no puedo escribir $opt{json}: $!\n";
    print $jf JSON::PP->new->utf8->canonical->pretty->encode({
        generado => $fecha, sitio => $ROOT, veredicto => $veredicto,
        # contra QUE se midio: sin esto, dos JSON identicos pueden hablar de dos
        # arboles distintos y no hay forma de saber cual es cual
        medido_contra => ($CAND_ON ? 'CANDIDATO' : 'PRODUCCION'),
        medido_en     => ($CAND_ON ? "http://127.0.0.1:$CAND_PORT" : $ROOT),
        nv_por_candidato => [ map { $_->{id} } @NV_CAND ],
        resumen => { fallo=>$N{FALLO}, aviso=>$N{AVISO}, no_verificado=>$N{NV},
                     pasa=>$N{PASA}, aceptado=>$N{ACEPTADO} },
        # Los aceptados, enteros: quien consuma el JSON tiene que poder ver que
        # se silencio y con que firma sin abrir el conf del repo.
        aceptados => [ map { { id => $_->{id}, titulo => $_->{titulo},
                               huella => $_->{_huella}, motivo => $_->{_acept}{MOTIVO},
                               acepta => $_->{_acept}{ACEPTA}, fecha => $_->{_acept}{FECHA},
                               hasta  => $_->{_acept}{_hasta_iso}, dias => $_->{_acept}{_dias},
                               # Alcance de la aceptacion: vacio = cubre todo lo
                               # que el check mide. Con texto = PARCIAL, y el
                               # recibo tiene que decirlo en su cara.
                               parcial => ($_->{ev_parcial} // ''),
                               cubre   => scalar(@{ _ev_lista($_->{ev}) }) } }
                       sort { $a->{id} cmp $b->{id} } @ACEPTADOS ],
        aceptados_rechazados => [ map { { check => ($_->{CHECK} // ''), linea => ($_->{_linea} // 0),
                                          por => $_->{_por} } } @ACEPT_RECHAZADAS ],
        instrumento => { perl => "$]", dom => ($opt{dom} ne '' ? $opt{dom} : undef),
                         innerWidth => $DOM{innerWidth}, innerHeight => $DOM{innerHeight} },
        # 🔴 ARREGLO P5 · el alcance tambien en el JSON, con la misma forma que
        #    se le pasa a receipt.pl: quien consuma el JSON no tiene que adivinar
        #    sobre cuantas paginas se midio ni cuales.
        alcance => {
            sitio_urls  => $SITIO_URLS,          # lo que tiene el SITIO (sitemap)
            lista_urls  => scalar(@PAGES_URLS),  # lo que se pidio auditar
            documentos  => scalar(@PAGES),       # tras deduplicar por md5 servido
            por_lente   => { map { $_ => { miradas => $ALCANCE{$_}{miradas},
                                           urls    => $ALCANCE{$_}{urls},
                                           nota    => $ALCANCE{$_}{nota} } } keys %ALCANCE },
        },
        comprobaciones => \@R,
    });
    close $jf;
}

# =============================================================================
#  11 · EL RECIBO
# =============================================================================
#  Hasta aqui esto era un INFORME: sale por pantalla, se lee, y desaparece con
#  el scroll. Nada ata lo que dice al arbol que se va a subir, y por eso «he
#  corrido el QA» ha sido siempre una afirmacion de palabra.
#
#  El recibo lo convierte en un hecho comprobable por otro: lleva el md5 del
#  arbol desplegable, asi que solo vale para ESTE arbol; caduca; y dice contra
#  que version del estandar se midio.
#
#  🔴 Se escribe TAMBIEN cuando el veredicto es FALLA. Un recibo rojo no es un
#     recibo que falta: son dos cosas distintas y el que despliega tiene que
#     poder distinguirlas. «No hay recibo» = nadie ha mirado. «Recibo en rojo»
#     = alguien miro y esta mal. Si solo se escribiera en verde, borrar el
#     recibo seria la forma facil de saltarse el gate.
# =============================================================================
if ($opt{repo} ne '' && -d $opt{repo} && !$opt{'sin-recibo'}) {
    my ($midir) = $0 =~ m{^(.*)[\\/][^\\/]+$};
    $midir = '.' unless defined $midir && $midir ne '';
    my $lib = "$midir/receipt.pl";
    if (-f $lib) {
        my $ok = eval { require $lib; 1 };
        if ($ok) {
            my %lentes;
            my @nv_ids;
            # 🔴 18-ago-2026 · Y LOS QUE FALLAN, TAMBIEN. El recibo guardaba el ID
            #    de lo NO VERIFICADO y del FALLO solo un numero: 727 corridas en
            #    FALLA sobre webs reales y ni una dice QUE check acuso. Sin el
            #    nombre no se puede saber que gate se gana su sitio y cual solo
            #    hace ruido -- que es la pregunta que el instrumento no sabia
            #    contestar de si mismo.
            my @fallo_ids;
            my %MAPA = ('SEO'=>'SEO', 'RENDIMIENTO'=>'RENDIMIENTO',
                        'ACCESIBILIDAD'=>'ACCESIBILIDAD', 'MEDICION'=>'MEDICION',
                        'ESTRUCTURA'=>'ESTRUCTURA');
            for my $l (keys %MAPA) {
                next unless grep { $_->{lente} eq $l } @R;
                my @x = grep { $_->{lente} eq $l } @R;
                # 🔴 TRES estados, no dos (13-ago-2026, §18). Con `? 'FALLA' :
                #    'PASA'` una lente cuyas comprobaciones son TODAS NO
                #    VERIFICADO quedaba sellada «PASA» en el recibo -medido con
                #    el gate apuntando a un puerto muerto-. Y `receipt.pl
                #    --para-desplegar` acepta cualquier lente que diga PASA o
                #    FALLA, asi que la puerta se la tragaba.
                $lentes{$l} = (grep { $_->{estado} eq 'FALLO' } @x) ? 'FALLA'
                            : (grep { ($_->{estado} // '') ne 'NV' } @x) ? 'PASA'
                            : 'NO VERIFICADA';
            }
            push @nv_ids, $_->{id} for grep { $_->{estado} eq 'NV' } @R;
            push @fallo_ids, $_->{id} for grep { $_->{estado} eq 'FALLO' } @R;
            # 🔴 ARREGLO P5 · ESTO ES LO QUE FALTABA. %ALCANCE se imprimia y ahi
            #    moria: no se pasaba, asi que receipt.pl escribia «ALCANCE: NO
            #    DECLARADO» en TODOS los recibos —incluido el que sella los 192
            #    ficheros de climentmedia habiendo medido lo que midio—. Un
            #    recibo que sella un arbol y no dice sobre que se midio miente
            #    por omision sobre su alcance, que es como mienten los informes.
            #    Formato (contrato con receipt.pl::alcance_lineas): hashref
            #    { LENTE => [urls] }, una clave por lente CORRIDA. De ahi salen
            #    ALCANCE-URLS, ALCANCE-<LENTE> y ALCANCE-URL-NNN.
            my %alc = map { $_ => [ @{ $ALCANCE{$_}{urls} } ] }
                      grep { $ALCANCE{$_} && @{ $ALCANCE{$_}{urls} } } keys %ALCANCE;
            my $r = eval {
                main::escribe_recibo(
                    repo   => $opt{repo},
                    sitio  => $ROOT,
                    salida => ($opt{recibo} ne '' ? $opt{recibo} : undef),
                    horas  => $opt{horas},
                    instrumento => "perl $] · curl"
                                 . (%DOM ? " · DOM (innerWidth=".($DOM{innerWidth}//'?').")"
                                         : " · sin DOM"),
                    # 🔴 EL ARREGLO DEL 11-ago-2026, EN UNA LINEA: el recibo dice
                    #    en su cara si el veredicto sale del arbol que sella o de
                    #    una web que ya estaba subida. `sitio` sigue siendo el
                    #    dominio real —lo compara deploy.sh— aunque la medicion
                    #    venga de 127.0.0.1: son cosas distintas y no se mezclan.
                    medido_contra => ($CAND_ON ? 'CANDIDATO' : 'PRODUCCION'),
                    medido_en     => ($CAND_ON ? "http://127.0.0.1:$CAND_PORT" : $ROOT),
                    nv_candidato  => [ map { $_->{id} } @NV_CAND ],
                    veredicto => $veredicto,
                    lentes    => \%lentes,
                    fallo => $N{FALLO}, aviso => $N{AVISO},
                    nv    => $N{NV},    pasa  => $N{PASA},
                    nv_ids => \@nv_ids,
                    fallo_ids => \@fallo_ids,
                    # 🔴 Los aceptados van AL RECIBO, no solo al informe. El
                    #    informe se lee y desaparece con el scroll; el recibo es
                    #    lo que queda sellado junto al arbol y lo que mira quien
                    #    despliega. Un silenciador que no aparece en el recibo
                    #    es un silenciador secreto.
                    aceptados => [ map { { id => $_->{id}, titulo => $_->{titulo},
                                           huella => $_->{_huella},
                                           motivo => $_->{_acept}{MOTIVO},
                                           acepta => $_->{_acept}{ACEPTA},
                                           fecha  => $_->{_acept}{FECHA},
                                           hasta  => $_->{_acept}{_hasta_iso},
                                           dias   => $_->{_acept}{_dias},
                                           parcial => ($_->{ev_parcial} // ''),
                                           cubre   => scalar(@{ _ev_lista($_->{ev}) }) } }
                                   sort { $a->{id} cmp $b->{id} } @ACEPTADOS ],
                    aceptados_rechazados => scalar(@ACEPT_RECHAZADAS),
                    aceptados_aviso_dias => ACEPT_AVISO,
                    # 🔴 El md5 del PROPIO conf. `_deploy/` y los `.conf` estan
                    #    fuera del arbol desplegable —y hacen bien: no se suben—,
                    #    asi que ARBOL-HASH NO los cubre. Sin esta linea, un
                    #    recibo dice «5 aceptados» y no hay forma de saber que
                    #    version del fichero los firmo. Con ella, se compara.
                    aceptados_conf => $ACEPT_CONF_MD5,
                    alcance => (%alc ? \%alc : undef),
                    # 🔴 11-ago-2026 · el DENOMINADOR. Sin esto el recibo decia
                    #    «ALCANCE-SEO: 25 URLs» y no habia forma de saber si eran
                    #    25 de 35 o 25 de 200. Los tres numeros salen de aqui
                    #    porque aqui es donde se saben; receipt.pl NO los puede
                    #    deducir del arbol (el sitemap no esta en el repo, y las
                    #    URLs con ?query no son ficheros).
                    alcance_sitio      => $SITIO_URLS,
                    alcance_lista      => scalar(@PAGES_URLS),
                    alcance_documentos => scalar(@PAGES),
                    alcance_dom => ($opt{dom} ne ''
                                    ? "$opt{dom} (innerWidth=".($DOM{innerWidth}//'?').")"
                                    : undef),
                );
            };
            if ($r) {
                print "\n  RECIBO   $r->{salida}\n";
                printf "           arbol %s · %d ficheros · estandar %s · caduca en %d h\n",
                       $r->{hash}, $r->{ficheros}, $r->{estandar}, $opt{horas};
                printf "           MEDIDO-CONTRA: %s\n", ($CAND_ON ? 'CANDIDATO (el arbol que sella)' : 'PRODUCCION (la web ya subida)');
                print  ($CAND_ON
                        ? "           Este recibo SI habla del arbol que firma. Vale para subir; despues\n"
                        . "           hace falta G11: bash deploy.sh $opt{repo} --servido\n"
                        : "           ⚠ Este recibo sella el arbol del repo pero su veredicto sale de\n"
                        . "           PRODUCCION: no dice nada de los cambios sin subir. Para eso, --candidato\n");
                print  "           El despliegue lo exige. Si tocas un fichero, el hash cambia\n";
                print  "           y hay que volver a correr esto: es el punto.\n";
            } else {
                print "\n  ⚠ NO he podido escribir el recibo: $@\n";
                print "    Sin recibo el despliegue se niega, y hace bien.\n";
            }
        } else {
            print "\n  ⚠ NO he podido cargar receipt.pl: $@\n";
        }
    } else {
        print "\n  ⚠ falta $lib: no hay recibo, y sin recibo no se despliega.\n";
    }
} elsif (!$opt{'sin-recibo'}) {
    print "\n  ⚠ SIN RECIBO: no me has dado --repo, asi que no se sobre que arbol\n";
    print "    he medido. El despliegue se negara. Vuelve a correr con --repo DIR.\n";
}

# 🔴 14-ago-2026 · REGLA 10 · UNA LENTE QUE CORRIO Y NO MIDIO NADA SALE ≠ 0.
#
# El 13-ago se arreglo la mitad de esto (§18): el veredicto pasa a decir
# «PASA · 1 lente SIN MEDIR: SEO» y el recibo sella la lente como NO VERIFICADA
# en vez de como aprobada. Pero el CODIGO DE SALIDA seguia siendo 0, y medido
# hoy sobre un host que no contesta:
#
#     VEREDICTO: PASA · 1 lente SIN MEDIR: SEO
#     FALLO 0 · AVISO 0 · ACEPTADO 0 · NO VERIFICADO 1 · PASA 0
#     exit 0                                          <- cero medido, exito
#
# La coletilla la lee una persona. El exit lo lee TODO LO DEMAS: un `&&`, un
# script de despliegue, una tarea programada. Arreglar la frase y dejar el
# numero es arreglar la mitad que se ve.
#
# SALE 3, NO 1, y la distincion importa: 1 es «lo he medido y esta mal» y 3 es
# «no lo he medido». Quien reciba un 1 va a buscar el defecto; quien reciba un 3
# tiene que ir a mirar por que la lente no pudo medir -- casi siempre la red o
# una pagina que no responde. Mandar a alguien a buscar un defecto que no existe
# cuesta una tarde, que es la misma razon por la que la puerta distingue
# NO CORRIDA de NO VERIFICADA.
exit(1) if $N{FALLO};
exit(3) if @LENTES_SIN_MEDIR;
exit(0);
