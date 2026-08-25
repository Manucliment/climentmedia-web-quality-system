#!/usr/bin/perl
# Gate de enlazado interno. Lee el JSON que produce crawl-links.pl y da VEREDICTO.
# Uso:  perl linking-gate.pl <crawl.json>
# Sale 1 si algo FALLA. Cada regla dice PASA / FALLA / AVISO y por que.
use strict; use warnings; use JSON::PP;

my $f = $ARGV[0] or die "uso: perl linking-gate.pl <crawl.json>\n";
my $j = JSON::PP->new->decode(do { local $/; open my $h,'<',$f or die "$f: $!"; <$h> });
my $p = $j->{pages};
my %sm = map { $_ => 1 } @{ $j->{sitemap} || [] };
my $host = $j->{site};

my ($fail, $warn, $nover) = (0,0,0);
sub ok   { printf "PASA   %-34s %s\n", $_[0], $_[1]//''; }
sub bad  { printf "FALLA  %-34s %s\n", $_[0], $_[1]//''; $fail++; }
sub avis { printf "AVISO  %-34s %s\n", $_[0], $_[1]//''; $warn++; }
# 🔴 NOVERIF no es un aprobado: cuenta para la salida != 0. Lo que no se ha
#    podido medir no se despliega como si estuviera bien. Existe porque acusar
#    y callar son los dos errores, y hay un tercer estado real: "con este
#    metodo no se puede saber".
sub nv   { printf "NOVERIF %-33s %s\n", $_[0], $_[1]//''; $nover++; }

my @ok200 = grep { $p->{$_}{status} == 200 } keys %$p;
my $N = scalar @ok200;
print "===== GATE DE ENLAZADO INTERNO - $host ($N paginas 200) =====\n\n";

# --- R0: el rastreo mide algo. Un sitio que inyecta enlaces por JS da ceros que MIENTEN.
{
  my $sinlinks = grep { ($p->{$_}{out_internal_unique}//0) == 0 } @ok200;
  my $chrome   = 0; $chrome += $p->{$_}{out_chrome}//0 for @ok200;
  if ($sinlinks > $N/3 || ($chrome == 0 && $N > 3)) {
    nv('R0 el rastreo es valido',
        "$sinlinks/$N paginas sin NINGUN enlace interno y nav/footer=$chrome. Los enlaces los pinta el JS: el HTML servido no los lleva. NO leas el resto del informe como hallazgos -- el instrumento no puede medir este sitio, que es distinto de que el sitio este mal.");
    print "\n>>> VEREDICTO: NO VERIFICADO (instrumento invalido para este sitio)\n"; exit 1;
  } else { ok('R0 el rastreo es valido', "nav/footer=$chrome enlaces; $sinlinks paginas sin salientes"); }
}

# --- Paginas que el rastreo estatico NO puede medir (cuerpo montado por JS).
# 🔴 R0 mira una MEDIA del sitio y solo caza la cascara JS COMPLETA. El caso
#    frecuente se le escapa: cascara SERVIDA con su nav estatica + rejilla de
#    producto pintada por JS. Ahi R0 sale verde y R2/R4 acusan de huerfanas a
#    fichas que existen y que se enlazan solas desde esa rejilla. Comprobado en
#    crawl-links-tests/orphans-js.pl: 12 fichas acusadas con R0 en PASA.
#    Las paginas marcadas js_shell son el motivo por el que ese grafo esta
#    incompleto, y no se puede acusar de huerfano a nadie sin saber que hay
#    dentro de ellas.
my @shells = sort grep { $p->{$_}{js_shell} } @ok200;
if (@shells) {
  printf "NOTA   %-34s %d pagina(s) montan su cuerpo con JS; el grafo esta incompleto:\n",
         'el rastreo no ve todo el grafo', scalar @shells;
  print "         - $_\n" for @shells[0 .. ($#shells > 4 ? 4 : $#shells)];
  print "         ... y ".(@shells-5)." mas\n" if @shells > 5;
  print "\n";
}

# --- R1: profundidad de clic desde la home
{
  my $max = 0; my @deep;
  for my $u (@ok200) { my $d = $p->{$u}{depth};
    next unless defined $d && $d != 99;
    $max = $d if $d > $max; push @deep, $u if $d > 3; }
  my $lim = $N > 1000 ? 5 : ($N > 100 ? 4 : 3);
  if (@deep && $max > $lim) { bad("R1 profundidad <= $lim clics", "max=$max; ".scalar(@deep)." paginas por debajo: ".join(', ', @deep[0..($#deep>2?2:$#deep)])); }
  else { ok("R1 profundidad <= $lim clics", "max=$max"); }
}

# --- R2: todo lo del sitemap se alcanza NAVEGANDO. La regla dura.
{
  my @unreach;
  for my $u (sort keys %sm) {
    if (!exists $p->{$u}) { push @unreach, "$u [no rastreada]"; next; }
    push @unreach, $u if !$p->{$u}{reached_by_crawl};
  }
  if (@unreach && @shells) {
    nv('R2 sitemap alcanzable navegando', scalar(@unreach)." URL(s) no se alcanzaron rastreando, pero hay ".scalar(@shells)." pagina(s) que montan su cuerpo con JS: NO se puede saber si el enlace existe y no lo vemos, o no existe. Mirar a mano una de estas en el navegador:");
    print "         - $_\n" for @unreach[0 .. ($#unreach > 4 ? 4 : $#unreach)];
    print "         ... y ".(@unreach-5)." mas\n" if @unreach > 5;
  }
  elsif (@unreach) { bad('R2 sitemap alcanzable navegando', scalar(@unreach)." URL(s) solo llegan por sitemap:");
                  print "         - $_\n" for @unreach; }
  else { ok('R2 sitemap alcanzable navegando', scalar(keys %sm)." URLs, todas alcanzables"); }
}

# --- R3: cada pagina indexable recibe >=1 enlace DE CONTENIDO (fuera de nav/footer)
{
  my @solonav;
  for my $u (@ok200) { next if ($p->{$u}{depth}//9) == 0;
    push @solonav, $u if ($p->{$u}{in_body}//0) == 0 && ($p->{$u}{in_unique}//0) > 0; }
  if (@solonav) { avis('R3 >=1 entrante de contenido', scalar(@solonav)." pagina(s) solo se alcanzan por el menu:");
                  print "         - $_\n" for @solonav[0..($#solonav>5?5:$#solonav)]; }
  else { ok('R3 >=1 entrante de contenido'); }
}

# --- R4: huerfanas duras (0 entrantes de ningun tipo)
{
  my @orf = grep { ($p->{$_}{in_unique}//0) == 0 && ($p->{$_}{depth}//9) != 0 } @ok200;
  if (@orf && @shells) {
    # 🔴 NO se acusa. Una ficha que solo enlaza la rejilla que pinta el JS sale
    #    con 0 entrantes en un rastreo estatico, y NO es huerfana. Tampoco se
    #    da por buena: se dice que no se ha podido medir y como comprobarlo.
    nv('R4 cero huerfanas duras', scalar(@orf)." pagina(s) con 0 entrantes EN EL HTML SERVIDO, pero ".scalar(@shells)." pagina(s) montan su cuerpo con JS y pueden ser justo las que las enlazan. NO son huerfanas probadas. Para medirlo de verdad hace falta un rastreo con navegador (Chrome del servidor), no curl:");
    print "         - $_\n" for @orf[0 .. ($#orf > 4 ? 4 : $#orf)];
    print "         ... y ".(@orf-5)." mas\n" if @orf > 5;
  }
  elsif (@orf) { bad('R4 cero huerfanas duras', scalar(@orf)." pagina(s) con 0 entrantes:");
              print "         - $_\n" for @orf; }
  else { ok('R4 cero huerfanas duras', 'ninguna (ojo: las que no estan ni enlazadas ni en sitemap hay que buscarlas en el repo)'); }
}

# --- R5: un hub enlaza a TODOS sus hijos
{
  my %children;
  for my $u (@ok200) {
    my ($path) = $u =~ m{^https?://[^/]+(/.*)$}; next unless $path;
    next if $path eq '/';
    next if $path =~ m{/index\.html$};   # es la MISMA pagina que su directorio, no un hijo
    my $parent = $path; $parent =~ s{/+$}{}; $parent =~ s{/[^/]+$}{};
    $parent = '/' if $parent eq '';
    my ($base) = $u =~ m{^(https?://[^/]+)};
    push @{ $children{"$base$parent"} }, $u;
  }
  # 🔴 13-ago-2026 · LA RAIZ NO ES EL PADRE DE MEDIO SITIO.
  #    En un sitio PLANO -todas las URLs a un nivel, que es como estan site-c y
  #    site-d- la aritmetica de arriba hace que el padre de las 28 paginas sea
  #    "/", y la regla acababa exigiendo que la PORTADA enlazase a las 28: a las
  #    11 entradas del blog y al aviso legal incluidos. Eso choca de frente con
  #    R10 (menu acotado, <=15 enlaces por pagina) y convierte la home en un mapa
  #    del sitio. La ruta no dice quien cuelga de quien cuando no hay jerarquia
  #    EN la ruta; lo que si lo cubre ahi es R3 (cada pagina necesita un entrante
  #    de contenido) y R4 (cero huerfanas), que ya se comprueban arriba.
  #    Asi que la raiz responde solo por los hijos que son HUB a su vez: la
  #    portada tiene que enlazar a cada SECCION, no a cada pagina. En un sitio
  #    plano no hay secciones, y entonces R5 no tiene nada que decir -- y lo dice.
  #    Los cinco casos que lo fijan estan en crawl-links-tests/tests.pl,
  #    dos esperando PASA y dos esperando FALLA: la seccion incompleta y la
  #    portada que se deja una seccion siguen siendo defecto.
  my %es_hub = map { $_ => 1 } keys %children;
  my (@rotos, $mirados);
  for my $hub (sort keys %children) {
    next unless exists $p->{$hub} && $p->{$hub}{status} == 200;
    my @hijos = @{ $children{$hub} };
    @hijos = grep { $es_hub{$_} } @hijos if $hub =~ m{^https?://[^/]+/$};
    next unless @hijos;
    $mirados++;
    my %out = map { $_ => 1 } @{ $p->{$hub}{out_targets} || [] };
    my @miss = grep { !$out{$_} } @hijos;
    push @rotos, "$hub -> no enlaza a ".scalar(@miss)."/".scalar(@hijos)." hijos (".join(', ', map { s{^https?://[^/]+}{}r } @miss[0..($#miss>2?2:$#miss)]).")" if @miss;
  }
  if (@rotos) { bad('R5 el hub enlaza a sus hijos'); print "         - $_\n" for @rotos; }
  # Un PASA a secas se lee como "hubs verificados". Si no habia ninguno que
  # mirar hay que decirlo, o la linea verde miente por omision.
  elsif (!$mirados) { ok('R5 el hub enlaza a sus hijos', 'sin jerarquia en las URLs: nada que comprobar (lo cubren R3 y R4)'); }
  else { ok('R5 el hub enlaza a sus hijos', "$mirados hub(s) con hijos, todos completos"); }
}

# --- R6: breadcrumb visible donde hay jerarquia, y coherente con el schema
{
  my (@sinvis, @soloschema);
  for my $u (@ok200) { my $d = $p->{$u}{depth}; next unless defined $d && $d >= 1 && $d != 99;
    push @sinvis, $u unless $p->{$u}{has_breadcrumb_visible};
    push @soloschema, $u if $p->{$u}{has_breadcrumb_schema} && !$p->{$u}{has_breadcrumb_visible}; }
  if (@soloschema) { bad('R6 breadcrumb VISIBLE, no solo schema', scalar(@soloschema)." pagina(s) emiten BreadcrumbList sin breadcrumb en pantalla"); }
  elsif (@sinvis)  { avis('R6 breadcrumb VISIBLE', scalar(@sinvis)." pagina(s) con jerarquia y sin breadcrumb"); }
  else { ok('R6 breadcrumb VISIBLE'); }
}

# --- R7: los enlaces internos apuntan a la URL canonica
{
  my (@dup, @redir);
  for my $u (@ok200) {
    push @redir, $u if ($p->{$u}{redirects}//0) > 0 && ($p->{$u}{in_unique}//0) > 0;
    if ($u =~ m{/index\.html$} && ($p->{$u}{in_unique}//0) > 0) {
      # misma convencion de clave que el rastreador: sin barra final salvo la raiz
      (my $clean = $u) =~ s{index\.html$}{};
      $clean =~ s{(?<!//)/$}{} unless $clean =~ m{^https?://[^/]+/$};
      push @dup, sprintf("%s recibe %d enlaces; la canonica %s recibe %d",
        $u, $p->{$u}{in_unique}//0, $clean, exists $p->{$clean} ? ($p->{$clean}{in_unique}//0) : 0);
    }
  }
  if (@dup || @redir) { bad('R7 enlazar a la URL canonica');
      print "         - $_\n" for @dup;
      print "         - enlace a URL que redirige: $_\n" for @redir; }
  else { ok('R7 enlazar a la URL canonica'); }
}

# --- R8: anclas
{
  my (%gen); my ($tot, $vacio) = (0, 0);
  for my $u (@ok200) { for my $i (@{ $p->{$u}{inbound}||[] }) { $tot++;
    my $t = lc($i->{text}//''); $t =~ s/^\s+|\s+$//g;
    $vacio++ if $t eq '' || $t eq '[sin texto]';
    $gen{$t}++ if $t =~ /^(aqui|aquí|here|click here|read more|leer mas|leer más|ver mas|ver más|learn more|more|mas|más|saber mas|saber más|this|esto|link|enlace|ver|view|continue|continuar|see more|en savoir plus|lire la suite|ici|voir plus|saiba mais|ver mais|clique aqui)$/; } }
  my $n = 0; $n += $_ for values %gen;
  if ($n || $vacio) { bad('R8 anclas descriptivas', "$n ancla(s) genericas, $vacio sin texto (de $tot)"); }
  else { ok('R8 anclas descriptivas', "$tot enlaces, 0 genericas"); }
}

# --- R9: el sitio no se sostiene solo con el menu
{
  my ($c,$b) = (0,0);
  for my $u (@ok200) { $c += $p->{$u}{out_chrome}//0; $b += $p->{$u}{out_body}//0; }
  my $pct = ($c+$b) ? 100*$b/($c+$b) : 0;
  if ($pct < 10) { bad('R9 >=10% enlaces de contenido', sprintf("solo %.0f%% (%d de %d). El sitio se sostiene con el menu.", $pct, $b, $c+$b)); }
  elsif ($pct < 20) { avis('R9 >=20% enlaces de contenido', sprintf("%.0f%% (%d de %d)", $pct, $b, $c+$b)); }
  else { ok('R9 enlaces de contenido', sprintf("%.0f%%", $pct)); }
}

# --- R10: el menu no enlaza medio sitio
{
  # 🔴 13-ago-2026 · EL NUMERO Y LA FRASE NO HABLABAN DE LO MISMO.
  #    `out_chrome` cuenta OCURRENCIAS de enlace, no destinos distintos: un pie
  #    con seis anclas `/services#generale`, `#massages`... suma seis y apunta a
  #    UNA pagina. La condicion `>= 0.5*$N` comparaba esas ocurrencias con el
  #    numero de PAGINAS -- peras con manzanas- y la frase que imprimia era «el
  #    menu enlaza medio sitio», que es una afirmacion sobre destinos UNICOS.
  #    Medido el 13-ago: site-d salia FALLA con 25 ocurrencias sobre 40
  #    paginas cuando su cromo enlaza 10 destinos distintos, el 25% del sitio.
  #    Acusacion falsa. site-a (10 de 16 = 62%) y climentmedia (26 de 44 = 59%)
  #    seguian siendo ciertas, y lo siguen siendo con el arreglo.
  #    NO se ha tocado ningun umbral: el limite blando sigue en 15 ocurrencias y
  #    el duro en la mitad del sitio. Lo unico que cambia es QUE se compara con
  #    la mitad del sitio -- destinos unicos, que es lo que la frase decia.
  my %uniq_chrome;   # pagina de origen -> { destino => 1 } solo region chrome
  for my $t (@ok200) {
    for my $i (@{ $p->{$t}{inbound} || [] }) {
      $uniq_chrome{ $i->{from} }{$t} = 1 if ($i->{region} // '') eq 'chrome';
    }
  }
  my ($maxnav, $where, $maxuniq) = (0, '', 0);
  for my $u (@ok200) { my $n = $p->{$u}{out_chrome}//0; if ($n > $maxnav) { $maxnav = $n; $where = $u; } }
  for my $u (@ok200) { my $n = scalar keys %{ $uniq_chrome{$u} || {} }; $maxuniq = $n if $n > $maxuniq; }
  my $lim = 15;
  my $pct = $N ? sprintf('%.0f', 100*$maxuniq/$N) : 0;
  if ($maxnav > $lim && $maxuniq >= 0.5*$N) {
    bad('R10 menu acotado', "el cromo enlaza $maxuniq destinos distintos de $N paginas ($pct%): el menu enlaza medio sitio y aplana la jerarquia ($maxnav enlaces por pagina en $where)");
  } elsif ($maxnav > $lim) { avis('R10 menu acotado', "$maxnav enlaces de nav/footer por pagina (limite blando $lim), pero solo $maxuniq destinos distintos: $pct% del sitio"); }
  else { ok('R10 menu acotado', "$maxnav enlaces a $maxuniq destinos distintos ($pct% del sitio)"); }
}

my $nvtxt = $nover ? ", $nover sin verificar" : '';
print "\n>>> VEREDICTO: ",
      ($fail  ? "FALLA ($fail regla(s) rotas, $warn aviso(s)$nvtxt)"
              : ($nover ? "NO VERIFICADO ($nover regla(s) no medibles con este metodo, $warn aviso(s))"
                        : ($warn ? "PASA CON AVISOS ($warn)" : "PASA"))), "\n";
# 🔴 NO VERIFICADO tambien sale != 0. Un "no he podido medirlo" no es un
#    aprobado, y si saliera 0 el despliegue pasaria por la puerta sin que nadie
#    mire. Quien lo lea distingue el caso por el texto del veredicto.
exit(($fail || $nover) ? 1 : 0);
