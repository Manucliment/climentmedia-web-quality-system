#!/usr/bin/perl
# =============================================================================
#  Bench for page-type-gate.pl
# =============================================================================
#  Every check is seen RED and GREEN. The pages are written here, one per case,
#  small enough to read: what a case expects is next to the markup that makes it.
#  PT-08 (the search string, filled in) runs against servidor.pl on 127.0.0.1,
#  which plays a site with a search, one without, and one whose results page
#  can be indexed. Nothing here touches a real site.
# =============================================================================
use strict; use warnings; use utf8;
use File::Basename qw(dirname); use File::Spec; use File::Temp qw(tempdir);
binmode STDOUT, ':encoding(UTF-8)';
my $DIR  = dirname(File::Spec->rel2abs($0));
my $GATE = File::Spec->catfile(dirname($DIR), 'page-type-gate.pl');
my $TMP  = tempdir('ptg-XXXXXX', TMPDIR => 1, CLEANUP => 1);
my ($OK, $MAL) = (0, 0);

sub pagina {   # pagina(tipo, [jsonld...], cuerpo, cabeza extra)
    my ($tipo, $ld, $cuerpo, $cab) = @_;
    my $bloques = join '', map { qq{<script type="application/ld+json">$_</script>\n} } @$ld;
    my $dt = defined $tipo ? qq{ data-tipo="$tipo"} : '';
    return qq{<!doctype html><html lang="es"><head><meta charset="utf-8"><title>Prueba</title>\n}
         . qq{<link rel="canonical" href="https://tienda.example/pagina/">\n} . ($cab // '') . $bloques
         . qq{</head><body><main$dt>$cuerpo</main></body></html>\n};
}
my $n = 0;
sub fichero { my $c = shift; my $f = File::Spec->catfile($TMP, 'p' . (++$n) . '.html');
              open my $h, '>:encoding(UTF-8)', $f or die $!; print $h $c; close $h; $f }
sub corre { my @a = @_; my $o = qx{perl "$GATE" @a 2>&1}; my $x = $? >> 8; utf8::decode($o); ($o, $x) }
sub caso {     # caso(titulo, fichero|url, [args], [patrones que DEBEN salir], [que NO deben salir], salida)
    my ($t, $f, $args, $si, $no, $sal) = @_;
    my ($o, $x) = corre(qq{"$f"}, @$args);
    my @fallos;
    for my $p (@$si) { push @fallos, "falta /$p/" unless $o =~ /$p/m }
    for my $p (@{ $no || [] }) { push @fallos, "sobra /$p/" if $o =~ /$p/m }
    push @fallos, "salio $x, esperaba $sal" if defined $sal && $x != $sal;
    if (@fallos) { $MAL++; printf "  MAL   %-62s %s\n", $t, join(' · ', @fallos);
                   print map { "        | $_\n" } grep { /PT-\d/ } split /\n/, $o }
    else { $OK++; printf "  ok    %s\n", $t }
}

my $MIGA = '{"@context":"https://schema.org","@type":"BreadcrumbList","itemListElement":['
         . '{"@type":"ListItem","position":1,"name":"Inicio","item":"https://tienda.example/"},'
         . '{"@type":"ListItem","position":2,"name":"Lamparas"}]}';
my $FICHA_CUERPO = '<h1>Lampara de mesa Nube</h1><p>Precio: 49,95 €. Envio en 48 horas.</p>';
sub producto { my ($precio, %x) = @_;
    my $off = defined $precio ? qq{,"offers":{"\@type":"Offer","price":"$precio","priceCurrency":"EUR","availability":"https://schema.org/InStock"}} : '';
    return qq{{"\@context":"https://schema.org","\@type":"Product","name":"Lampara de mesa Nube","image":"https://tienda.example/nube.jpg"$off}} }
my $ITEMPAGE = '{"@context":"https://schema.org","@type":"ItemPage","@id":"https://tienda.example/pagina/#pagina","name":"Lampara"}';

print "BANCO · page-type-gate.pl\n\n== LA TABLA\n";
{
    my ($o, $x) = corre('--tabla');
    if ($o =~ /PASA: cada anatomia tiene su fila/ && $x == 0) { $OK++; print "  ok    page-types.tsv cubre anatomy.tsv y cada nombre existe\n" }
    else { $MAL++; print "  MAL   page-types.tsv contra anatomy.tsv: $o\n" }
    my $an = File::Spec->catfile($TMP, 'anat.tsv');
    open my $h, '>', $an or die; print $h "home|hero||2.1|1|\nsocio|hero||2.15|1|\n"; close $h;
    ($o, $x) = corre('--tabla', '--anatomia-tsv', qq{"$an"});
    if ($o =~ /«socio».*no lo nombra/ && $x == 1) { $OK++; print "  ok    una anatomia nueva sin fila aqui SI la caza --tabla\n" }
    else { $MAL++; print "  MAL   una anatomia nueva sin fila no la caza: $o\n" }
    my $pt = File::Spec->catfile($TMP, 'tipos.tsv');
    open $h, '>', $pt or die; print $h "home||home|WebPage|WebSite;Organizacion|-|-|-|index|\n"; close $h;
    ($o, $x) = corre('--tabla', '--tipos-tsv', qq{"$pt"}, '--anatomia-tsv', qq{"$an"});
    if ($o =~ /«Organizacion», que no es un tipo de schema.org/ && $x == 1) { $OK++; print "  ok    una errata en la tabla (Organizacion) SI la caza --tabla\n" }
    else { $MAL++; print "  MAL   una errata en la tabla no la caza: $o\n" }
}

print "\n== PT-01 · LOS BLOQUES SE LEEN\n";
caso('un bloque con una coma de mas: FALLO', fichero(pagina('ficha', ['{"@type":"Product","name":"x",}'], $FICHA_CUERPO)), [],
     ['^FALLO\s+PT-01'], [], 1);
caso('una pagina de gracias sin JSON-LD: PASA, no lo pide', fichero(pagina('gracias', [], '<h1>Gracias</h1>', '<meta name="robots" content="noindex">')), [],
     ['^PASA\s+PT-01\s+sin JSON-LD, y este tipo no pide'], ['^FALLO'], 0);

print "\n== PT-02 · LOS NOMBRES EXISTEN\n";
caso('una errata de tipo (Prodcut) y de propiedad (mainEntiryOfPage): FALLO',
     fichero(pagina('ficha', ['{"@context":"https://schema.org","@type":"Prodcut","name":"x","mainEntiryOfPage":"y"}'], $FICHA_CUERPO)), [],
     ['^FALLO\s+PT-02.*tipo «Prodcut».*propiedad «mainEntiryOfPage'], [], 1);
caso('un nombre pendiente (gtin) es AVISO, no FALLO',
     fichero(pagina('ficha', [$MIGA, $ITEMPAGE, '{"@context":"https://schema.org","@type":"Product","name":"Lampara de mesa Nube","image":"i.jpg","gtin":"8412345678905","offers":{"@type":"Offer","price":"49.95","priceCurrency":"EUR","availability":"https://schema.org/InStock"}}'], $FICHA_CUERPO)), [],
     ['^PASA\s+PT-02', '^AVISO\s+PT-02.*gtin \(pending\)'], ['^FALLO'], 0);
# 5-nov-2026 · Physiotherapy es miembro de MedicalSpecialty Y tipo (subClassOf MedicalBusiness): el vocabulario lo leia
#  solo como miembro y el gate lo daba por inexistente en la pagina de un fisioterapeuta.
caso('un tipo medico que tambien es especialidad (Physiotherapy) existe: PASA',
     fichero(pagina('legal', ['{"@context":"https://schema.org","@type":"Physiotherapy","name":"Kine Nube","telephone":"+32 2 000 00 00","address":"Rue Nube 1, Bruxelles"}'], '<h1>Aviso legal</h1>')), [],
     ['^PASA\s+PT-02'], ['tipo «Physiotherapy»'], 0);
caso('una especialidad que NO es tipo (Dentistry) usada como @type: FALLO',
     fichero(pagina('legal', ['{"@context":"https://schema.org","@type":"Dentistry","name":"x"}'], '<h1>Aviso legal</h1>')), [],
     ['^FALLO\s+PT-02.*tipo «Dentistry»'], [], 1);

print "\n== PT-03 / PT-04 · LO QUE PIDE EL TIPO, Y LO QUE NO\n";
my $FICHA_BIEN = fichero(pagina('ficha', [$MIGA, $ITEMPAGE, producto('49.95')], $FICHA_CUERPO));
caso('una ficha con Product, Offer y migas: PASA en todo', $FICHA_BIEN, [],
     ['^PASA\s+PT-03', '^PASA\s+PT-05', '^PASA\s+PT-06', '^PASA\s+PT-10\s+la pagina es ItemPage'], ['^FALLO', '^AVISO'], 0);
caso('una ficha sin Product: FALLO', fichero(pagina('ficha', [$MIGA], $FICHA_CUERPO)), [],
     ['^FALLO\s+PT-03.*falta Product/ProductGroup'], [], 1);
# 6-nov-2026 · la ficha de un programa o de un agente lleva SoftwareApplication (o un subtipo): PT-03 pedia Product
#  y siete fichas de agentes de una web nuestra daban FALLO con su marcado bien puesto. Su espejo: con Service sigue
#  en FALLO, porque un servicio es un `servicio`, no una ficha.
caso('una ficha de programa con WebApplication: PT-03 PASA',
     fichero(pagina('ficha', [$MIGA, $ITEMPAGE, '{"@context":"https://schema.org","@type":"WebApplication","name":"Agente de informes","applicationCategory":"BusinessApplication","operatingSystem":"Web"}'], '<h1>Agente de informes</h1><p>Un agente que prepara el informe semanal.</p>')), [],
     ['^PASA\s+PT-03'], ['^FALLO\s+PT-03'], undef);
caso('una ficha con Service y sin Product: sigue en FALLO',
     fichero(pagina('ficha', [$MIGA, $ITEMPAGE, '{"@context":"https://schema.org","@type":"Service","name":"Agente de informes","provider":{"@type":"Organization","name":"x"}}'], '<h1>Agente de informes</h1><p>Un agente que prepara el informe semanal.</p>')), [],
     ['^FALLO\s+PT-03.*falta Product/ProductGroup/SoftwareApplication'], [], 1);
caso('una guia sin Article: FALLO', fichero(pagina('guia', [$MIGA], '<h1>Como elegir una lampara</h1>')), [],
     ['^FALLO\s+PT-03.*falta Article'], [], 1);
caso('una guia con BlogPosting (subtipo de Article): PASA',
     fichero(pagina('guia', [$MIGA, '{"@context":"https://schema.org","@type":"BlogPosting","headline":"Como elegir una lampara","datePublished":"2026-10-01","dateModified":"2026-11-01","author":{"@type":"Person","name":"Ana"}}'], '<h1>Como elegir una lampara</h1>')), [],
     ['^PASA\s+PT-03'], ['^FALLO'], 0);
caso('un tipo que no existe (data-tipo="socio"): FALLO, no se mide como el mas cercano', fichero(pagina('socio', [$MIGA], '<h1>x</h1>')), [],
     ['^FALLO\s+PT-03\s+tipo de pagina desconocido'], [], 1);
caso('sin tipo declarado: NO VERIFICADO, no PASA', fichero(pagina(undef, [$MIGA], '<h1>x</h1>')), [],
     ['^NO VERIFICADO\s+PT-03'], ['^PASA\s+PT-03'], 0);
caso('el alias pdp vale por ficha', fichero(pagina(undef, [$MIGA, $ITEMPAGE, producto('49.95')], $FICHA_CUERPO)), ['--tipo', 'pdp'],
     ['tipo ficha', '^PASA\s+PT-03'], ['^FALLO'], 0);
my $LISTA = '{"@context":"https://schema.org","@type":"ItemList","itemListElement":[{"@type":"ListItem","position":1,"item":'
          . producto('49.95') . '},{"@type":"ListItem","position":2,"url":"https://tienda.example/lampara-sol/"}]}';
my $COLL = '{"@context":"https://schema.org","@type":"CollectionPage","name":"Lamparas"}';
caso('un listado con los productos dentro de la ItemList: PASA',
     fichero(pagina('plp', [$MIGA, $COLL, $LISTA], '<h1>Lamparas</h1><p>Lampara de mesa Nube 49,95 €</p>')), [],
     ['^PASA\s+PT-03', '^PASA\s+PT-04', '^PASA\s+PT-10\s+la pagina es CollectionPage'], ['^FALLO'], 0);
caso('un listado con migas y CollectionPage, sin ItemList: PASA (Google no la pide en una categoria)',
     fichero(pagina('plp', [$MIGA, $COLL], '<h1>Lamparas</h1>')), [], ['^PASA\s+PT-03'], ['^FALLO'], 0);
caso('un listado solo con migas: FALLO, nada dice que es un listado',
     fichero(pagina('plp', [$MIGA], '<h1>Lamparas</h1>')), [], ['^FALLO\s+PT-03.*falta CollectionPage/ItemList'], [], 1);
# 5-nov-2026 · un hub (la pagina que reparte a los servicios o a las zonas) igual que un listado: lo que dice que es un
#  listado es CollectionPage o ItemList, no las dos. Pedia ItemList siempre (2 hubs de una web real en FALLO con CollectionPage).
caso('un hub con migas y CollectionPage: PASA',
     fichero(pagina('hub', [$MIGA, $COLL], '<h1>Servicios</h1>')), [], ['^PASA\s+PT-03'], ['^FALLO'], 0);
caso('un hub solo con migas: FALLO',
     fichero(pagina('hub', [$MIGA], '<h1>Servicios</h1>')), [], ['^FALLO\s+PT-03.*falta CollectionPage/ItemList'], [], 1);
caso('un listado con un Product suelto: FALLO',
     fichero(pagina('plp', [$MIGA, $COLL, $LISTA, producto('49.95')], '<h1>Lamparas</h1>')), [],
     ['^FALLO\s+PT-04.*Product.*elementos de la ItemList'], [], 1);
caso('una portada con FAQPage: FALLO (la portada no lleva FAQ, 09 §2.1)',
     fichero(pagina('home', ['{"@context":"https://schema.org","@type":"WebSite","name":"Tienda","url":"https://tienda.example/"}',
                             '{"@context":"https://schema.org","@type":"Organization","name":"Tienda","url":"https://tienda.example/"}',
                             '{"@context":"https://schema.org","@type":"FAQPage","mainEntity":[{"@type":"Question","name":"Envio","acceptedAnswer":{"@type":"Answer","text":"48 h"}}]}'],
                     '<h1>Tienda</h1><p>Envio</p><p>48 h</p>')), [],
     ['^FALLO\s+PT-04.*FAQPage'], [], 1);

print "\n== PT-05 · LAS PROPIEDADES MINIMAS\n";
caso('un Product sin offers, reseñas ni valoracion: FALLO', fichero(pagina('ficha', [$MIGA, $ITEMPAGE, producto(undef)], $FICHA_CUERPO)), [],
     ['^FALLO\s+PT-05.*Product sin offers\|aggregateRating\|review'], [], 1);
caso('una miga sin position y sin URL en medio: FALLO',
     fichero(pagina('ficha', ['{"@context":"https://schema.org","@type":"BreadcrumbList","itemListElement":[{"@type":"ListItem","name":"Inicio"},{"@type":"ListItem","position":2,"name":"Lamparas","item":"https://tienda.example/l/"},{"@type":"ListItem","position":3,"name":"Nube"}]}', $ITEMPAGE, producto('49.95')], $FICHA_CUERPO)), [],
     ['^FALLO\s+PT-05.*elemento 1 sin position', 'elemento 1 sin item'], ['elemento 3 sin item'], 1);
caso('un Article sin fechas: AVISO, no FALLO',
     fichero(pagina('guia', [$MIGA, '{"@context":"https://schema.org","@type":"Article","headline":"Como elegir una lampara"}'], '<h1>Como elegir una lampara</h1>')), [],
     ['^AVISO\s+PT-05.*sin datePublished'], ['^FALLO'], 0);

caso('un AggregateOffer con lowPrice (variantes): PASA, no se le pide el price de un Offer',
     fichero(pagina('ficha', [$MIGA, $ITEMPAGE, '{"@context":"https://schema.org","@type":"Product","name":"Lampara de mesa Nube","image":"i.jpg","offers":{"@type":"AggregateOffer","lowPrice":"49.95","highPrice":"69.95","priceCurrency":"EUR","offerCount":3}}'], $FICHA_CUERPO)), [],
     ['^PASA\s+PT-05'], ['^FALLO'], 0);
caso('un AggregateOffer sin lowPrice: FALLO, su propia regla',
     fichero(pagina('ficha', [$MIGA, $ITEMPAGE, '{"@context":"https://schema.org","@type":"Product","name":"Lampara de mesa Nube","image":"i.jpg","offers":{"@type":"AggregateOffer","priceCurrency":"EUR","offerCount":3}}'], $FICHA_CUERPO)), [],
     ['^FALLO\s+PT-05.*AggregateOffer.*sin lowPrice'], ['sin price\|priceSpecification'], 1);
# 5-nov-2026 · un ProductGroup de Shopify: las ofertas en cada variante, no en el grupo.
#   Contra la regla de antes (la de Product) el primero salia FALLO «sin offers».
my $VAR = sub { my ($o) = @_; '{"@type":"Product","name":"Lampara de mesa Nube","image":"i.jpg","sku":"L1"' . ($o ? ',"offers":{"@type":"Offer","price":"49.95","priceCurrency":"EUR","availability":"https://schema.org/InStock"}' : '') . '}' };
caso('un ProductGroup sin offers, con sus variantes ofertadas: PASA',
     fichero(pagina('ficha', [$MIGA, $ITEMPAGE, '{"@context":"https://schema.org","@type":"ProductGroup","name":"Lampara de mesa Nube","image":"i.jpg","productGroupID":"G1","variesBy":"https://schema.org/size","hasVariant":[' . $VAR->(1) . ',' . $VAR->(1) . ']}'], $FICHA_CUERPO)), [],
     ['^PASA\s+PT-05'], ['^FALLO\s+PT-05'], 0);
caso('un ProductGroup sin hasVariant ni offers: FALLO, su propia regla',
     fichero(pagina('ficha', [$MIGA, $ITEMPAGE, '{"@context":"https://schema.org","@type":"ProductGroup","name":"Lampara de mesa Nube","image":"i.jpg"}'], $FICHA_CUERPO)), [],
     ['^FALLO\s+PT-05.*ProductGroup.*sin hasVariant'], ['sin offers'], 1);
caso('una variante sin offers: FALLO, la de Product sigue mirando cada variante',
     fichero(pagina('ficha', [$MIGA, $ITEMPAGE, '{"@context":"https://schema.org","@type":"ProductGroup","name":"Lampara de mesa Nube","image":"i.jpg","productGroupID":"G1","variesBy":"https://schema.org/size","hasVariant":[' . $VAR->(1) . ',' . $VAR->(0) . ']}'], $FICHA_CUERPO)), [],
     ['^FALLO\s+PT-05.*Product.*sin offers'], [], 1);

print "\n== PT-06 · EL MARCADO CONTRA LA PAGINA\n";
caso('el precio del marcado (39.95) no es el de la pagina (49,95): FALLO',
     fichero(pagina('ficha', [$MIGA, $ITEMPAGE, producto('39.95')], $FICHA_CUERPO)), [],
     ['^FALLO\s+PT-06.*precio 39.95'], [], 1);
# 6-nov-2026 · LAS VARIANTES DE UN ProductGroup. Una tienda escribe un ProductGroup con
#   cuatro variantes, cada una con su URL (?variant=…) y su precio, y la pagina ensena el
#   precio de la elegida: los otros tres se ven en la URL de su variante, no en esta.
#   PT-06 pedia los cuatro aqui (FALLO en 4 packs, medido ese dia). Ahora, de las
#   variantes de un grupo, basta UNA en la pagina. Los dos que TIENEN que seguir en
#   rojo: un grupo sin ningun precio de variante visible, y un Product suelto.
my $VARP = sub { my ($p, $v) = @_; '{"@type":"Product","name":"Lampara de mesa Nube ' . $v . '","image":"i.jpg","sku":"L' . $v . '","offers":{"@type":"Offer","url":"https://tienda.example/pagina/?variant=' . $v . '","price":"' . $p . '","priceCurrency":"EUR","availability":"https://schema.org/InStock"}}' };
my $GRUPO = sub { '{"@context":"https://schema.org","@type":"ProductGroup","name":"Lampara de mesa Nube","image":"i.jpg","productGroupID":"G1","variesBy":"https://schema.org/size","hasVariant":[' . join(',', @_) . ']}' };
caso('un ProductGroup: la variante elegida en la pagina y las otras en su URL: PASA',
     fichero(pagina('ficha', [$MIGA, $ITEMPAGE, $GRUPO->($VARP->('49.95', 1), $VARP->('59.95', 2), $VARP->('69.95', 3))], $FICHA_CUERPO)), [],
     ['^PASA\s+PT-06.*1 de 3 precios de variante'], ['^FALLO\s+PT-06'], 0);
caso('un ProductGroup sin ningun precio de variante en la pagina: FALLO',
     fichero(pagina('ficha', [$MIGA, $ITEMPAGE, $GRUPO->($VARP->('39.95', 1), $VARP->('59.95', 2))], $FICHA_CUERPO)), [],
     ['^FALLO\s+PT-06.*ninguno de los 2 precios de las variantes'], [], 1);
caso('un Product suelto con dos ofertas, una que no se ve: FALLO (no es un grupo)',
     fichero(pagina('ficha', [$MIGA, $ITEMPAGE, '{"@context":"https://schema.org","@type":"Product","name":"Lampara de mesa Nube","image":"i.jpg","offers":[{"@type":"Offer","price":"49.95","priceCurrency":"EUR"},{"@type":"Offer","price":"59.95","priceCurrency":"EUR"}]}'], $FICHA_CUERPO)), [],
     ['^FALLO\s+PT-06.*precio 59.95'], [], 1);
caso('el precio con punto de miles (1.299,00 € en la pagina, 1299 en el marcado): PASA',
     fichero(pagina('ficha', [$MIGA, $ITEMPAGE, producto('1299')], '<h1>Lampara de mesa Nube</h1><p>1.299,00 €</p>')), [],
     ['^PASA\s+PT-06'], ['^FALLO'], 0);
my $FAQ = sub { my $q = shift; qq{{"\@context":"https://schema.org","\@type":"FAQPage","mainEntity":[{"\@type":"Question","name":"$q","acceptedAnswer":{"\@type":"Answer","text":"En 48 horas laborables."}}]}} };
caso('una pregunta del marcado que no esta en la pagina: FALLO',
     fichero(pagina('faq', [$FAQ->('¿Venis a Utrecht?')], '<h1>Preguntas</h1><h2>¿Cuanto tarda el envio?</h2><p>En 48 horas laborables.</p>')), [],
     ['^FALLO\s+PT-06.*no esta en la pagina'], [], 1);
caso('la misma pregunta escrita con tildes y otra puntuacion en la pagina: PASA',
     fichero(pagina('faq', [$FAQ->('Cuanto tarda el envio')], '<h1>Preguntas</h1><h2>¿Cuánto tarda el envío?</h2><p>En 48 horas laborables.</p>')), [],
     ['^PASA\s+PT-06', '^PASA\s+PT-03', '^PASA\s+PT-10\s+la pagina es FAQPage'], ['^FALLO'], 0);

print "\n== PT-07 · LAS ACCIONES Y LA CADENA DE BUSQUEDA\n";
my $WS = sub { my ($tpl, $in) = @_; qq{{"\@context":"https://schema.org","\@type":"WebSite","name":"Tienda","url":"https://tienda.example/","potentialAction":{"\@type":"SearchAction","target":{"\@type":"EntryPoint","urlTemplate":"$tpl"},"query-input":"$in"}}} };
my $ORG = '{"@context":"https://schema.org","@type":"Organization","@id":"https://tienda.example/#org","name":"Tienda","url":"https://tienda.example/","logo":"https://tienda.example/l.png"}';
sub home { my $ws = shift; fichero(pagina('home', [$ws, $ORG], '<h1>Tienda de lamparas</h1>', '')) }
caso('{search_term_string} en la plantilla y name=q en query-input: FALLO, la URL sale con las llaves',
     home($WS->('https://tienda.example/?s={search_term_string}', 'required name=q')), [],
     ['^FALLO\s+PT-07.*pide \{search_term_string\} y ningun -input declara name=search_term_string', 'name=q y la plantilla no tiene \{q\}'], [], 1);
caso('la plantilla relativa (/?s={q}): FALLO',
     home($WS->('/?s={q}', 'required name=q')), [], ['^FALLO\s+PT-07.*no es una URL absoluta'], [], 1);
caso('la plantilla a otro dominio: FALLO',
     home($WS->('https://buscador.otro.example/?q={q}', 'required name=q')), [], ['^FALLO\s+PT-07.*otro dominio'], [], 1);
caso('la plantilla bien cableada: PASA, y sin --sondear PT-08 dice NO VERIFICADO',
     home($WS->('https://tienda.example/?s={q}', 'required name=q')), [],
     ['^PASA\s+PT-07', '^NO VERIFICADO\s+PT-08'], ['^FALLO'], 0);
caso('query-input en su forma larga (PropertyValueSpecification con valueName): PASA',
     home(qq{{"\@context":"https://schema.org","\@type":"WebSite","name":"Tienda","url":"https://tienda.example/","potentialAction":{"\@type":"SearchAction","target":"https://tienda.example/buscar?q={q}","query-input":{"\@type":"PropertyValueSpecification","valueRequired":true,"valueName":"q"}}}}), [],
     ['^PASA\s+PT-07'], ['^FALLO'], 0);
caso('una ReadAction en una pagina de servicio: AVISO, nadie la lee',
     fichero(pagina('servicio', [$MIGA, '{"@context":"https://schema.org","@type":"Service","name":"Montaje","potentialAction":{"@type":"ReadAction","target":"https://tienda.example/montaje/"}}'], '<h1>Montaje</h1>')), [],
     ['^AVISO\s+PT-07.*ReadAction.*ningun buscador ni asistente'], ['^FALLO\s+PT-07'], undef);
caso('una potentialAction que no es una Action (Offer): FALLO',
     fichero(pagina('servicio', [$MIGA, '{"@context":"https://schema.org","@type":"Service","name":"Montaje","potentialAction":{"@type":"Offer","target":"https://tienda.example/"}}'], '<h1>Montaje</h1>')), [],
     ['^FALLO\s+PT-07.*Offer no es una Action'], [], 1);

print "\n== PT-09 · LA INDEXACION POR TIPO\n";
caso('un pago sin noindex: AVISO', fichero(pagina('checkout', [], '<h1>Pago</h1>')), [], ['^AVISO\s+PT-09.*sin noindex'], [], undef);
caso('un pago con noindex: PASA', fichero(pagina('checkout', [], '<h1>Pago</h1>', '<meta name="robots" content="noindex, nofollow">')), [], ['^PASA\s+PT-09'], ['^AVISO\s+PT-09'], undef);
caso('una ficha con noindex: FALLO', fichero(pagina('ficha', [$MIGA, $ITEMPAGE, producto('49.95')], $FICHA_CUERPO, '<meta name="robots" content="noindex">')), [],
     ['^FALLO\s+PT-09.*tiene que salir en Google'], [], 1);

print "\n== PT-10 / PT-11 · EL NODO DE PAGINA Y LAS REFERENCIAS\n";
caso('un contacto marcado como AboutPage: AVISO',
     fichero(pagina('contacto', [$ORG, '{"@context":"https://schema.org","@type":"AboutPage","name":"Contacto"}'], '<h1>Contacto</h1>')), [],
     ['^AVISO\s+PT-10.*es AboutPage.*ContactPage'], [], undef);
caso('un publisher por @id que no esta en la pagina: AVISO',
     fichero(pagina('guia', [$MIGA, '{"@context":"https://schema.org","@type":"Article","headline":"Guia","datePublished":"2026-10-01","dateModified":"2026-10-02","author":{"@type":"Person","name":"Ana"},"publisher":{"@id":"#org"}}'], '<h1>Guia</h1>')), [],
     ['^AVISO\s+PT-11.*#org'], [], undef);
caso('el mismo publisher con su nodo en la pagina: PASA',
     fichero(pagina('guia', [$MIGA, '{"@context":"https://schema.org","@graph":[{"@type":"Organization","@id":"#org","name":"Tienda"},{"@type":"Article","headline":"Guia","datePublished":"2026-10-01","dateModified":"2026-10-02","author":{"@type":"Person","name":"Ana"},"publisher":{"@id":"#org"}}]}'], '<h1>Guia</h1>')), [],
     ['^PASA\s+PT-11'], ['^AVISO\s+PT-11'], undef);

print "\n== PT-08 · LA BUSQUEDA, RELLENADA, RESPONDE (servidor en 127.0.0.1)\n";
{
    my $port = 20000 + ($$ % 20000);
    my $wsl = sub { my $ruta = shift; qq{{"\@context":"https://schema.org","\@type":"WebSite","name":"Tienda","url":"http://127.0.0.1:PUERTO/","potentialAction":{"\@type":"SearchAction","target":{"\@type":"EntryPoint","urlTemplate":"http://127.0.0.1:PUERTO$ruta"},"query-input":"required name=q"}}} };
    my %f = ('bien' => '/buscar?q={q}', 'indexable' => '/indexable?q={q}', 'sin' => '/sin-buscador?s={q}', 'ignora' => '/cualquiera?q={q}', 'roto' => '/no-existe?q={q}');
    for my $k (keys %f) {
        open my $h, '>:encoding(UTF-8)', File::Spec->catfile($TMP, "home-$k.html") or die;
        print $h pagina('home', [$wsl->($f{$k}), '{"@context":"https://schema.org","@type":"Organization","name":"Tienda","url":"http://127.0.0.1:PUERTO/"}'],
                        '<h1>Lamparas de diseño</h1>', '<link rel="canonical" href="http://127.0.0.1:PUERTO/">');
        close $h;
    }
    my $pid = fork();
    if (defined $pid && $pid == 0) { exec 'perl', File::Spec->catfile($DIR, 'servidor.pl'), $port, $TMP; exit 1 }
    my $listo = 0;
    for (1 .. 30) { if (qx{curl -s -o /dev/null -w %{http_code} http://127.0.0.1:$port/} =~ /200/) { $listo = 1; last } select(undef, undef, undef, 0.2) }
    if (!$listo) { $MAL++; print "  MAL   el servidor de pruebas no arranca en $port\n" }
    else {
        my $u = "http://127.0.0.1:$port/f";
        caso('un buscador que responde con resultados y noindex: PASA', "$u/home-bien.html", ['--sondear'],
             ['^PASA\s+PT-08.*termino «lamparas»'], ['^FALLO', '^AVISO\s+PT-08'], 0);
        caso('el termino elegido a mano (--termino nube): PASA', "$u/home-bien.html", ['--sondear', '--termino', 'nube'],
             ['^PASA\s+PT-08.*termino «nube»'], [], 0);
        caso('un buscador cuyos resultados se pueden indexar: AVISO', "$u/home-indexable.html", ['--sondear'],
             ['^AVISO\s+PT-08.*se puede indexar'], ['^FALLO\s+PT-08'], 0);
        caso('un sitio sin buscador que redirige a la portada: FALLO', "$u/home-sin.html", ['--sondear'],
             ['^FALLO\s+PT-08.*redirige a la portada'], [], 1);
        caso('una pagina que responde 200 sin ensenar lo buscado: FALLO', "$u/home-ignora.html", ['--sondear'],
             ['^FALLO\s+PT-08.*no ensena el termino'], [], 1);
        caso('una plantilla que lleva a un 404: FALLO', "$u/home-roto.html", ['--sondear'],
             ['^FALLO\s+PT-08.*responde 404'], [], 1);
        caso('una pagina que responde 429: NO VERIFICADO, no se juzga el error como si fuera la pagina',
             "http://127.0.0.1:$port/limite", ['--tipo', 'ficha'],
             ['^NO VERIFICADO .*responde 429.*no es un defecto de la pagina'], ['PT-03', '^FALLO'], 3);
    }
    kill 'KILL', $pid if $pid;
    waitpid($pid, 0) if $pid;
}

print "\n  OK $OK · MAL $MAL\n";
exit($MAL ? 1 : 0);
