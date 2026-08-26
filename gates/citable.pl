#!/usr/bin/perl
# =============================================================================
#  citable.pl · ¿SOBREVIVE UN PARRAFO A QUE LO SAQUEN DE LA PAGINA?
# =============================================================================
#  26-ago-2026. Sale de `citation-ready-check` (Andre Guelmann, gtm-skills, MIT)
#  y del tamano de bloque medido en el estudio GEO de Princeton
#  (arXiv:2311.09735), via `seo-intel/references/ai-visibility.md`.
#
#  EL PRINCIPIO, QUE ES TODO: un motor de respuestas no lee la pagina, extrae
#  un trozo -uno o dos parrafos- y responde con el. Asi que cada parrafo hay
#  que leerlo COMO SI FUERA LO UNICO QUE HAY EN LA PAGINA. El contexto del
#  parrafo de arriba desaparece en la recuperacion.
#
#  POR QUE NOS FALTABA. Nuestro estandar ya cubre la superficie del FRAGMENTO
#  DESTACADO -`WPS-13`: capsula de 40-60 palabras bajo el H1- y NO cubre la de
#  la CITA, que son 134-167 palabras autocontenidas. Es justo la superficie que
#  perseguimos con `llms.txt`, con `/learn/` y con todo el eje de producto.
#
#  DOS DE LAS OCHO CATEGORIAS DE LA SKILL YA SON REGLAS NUESTRAS y no se
#  reimplementan aqui: los H2 en forma de pregunta y el «>=1 tabla con
#  veredicto». Este gate hace las SEIS que son mecanicas sobre el texto.
#
#  🔴 SOLO TEXTO DE ORIGEN. La skill lo pone como regla dura y se respeta: no
#  hay `--url`. «Lo que devuelve un fetcher no es lo que la pagina le sirve a un
#  motor.» Se mide el HTML del repo, que es la fuente.
#
#  🔴 Y EL LIMITE QUE MAS IMPORTA: los patrones son POR IDIOMA, y un idioma
#  sin patrones NO SE PUEDE MEDIR. Cero hallazgos sobre una pagina que no se ha
#  sabido leer es un cero con cara de aprobado, asi que se lee `<html lang>` y,
#  si el idioma no esta cubierto, sale NO MEDIDO -- nunca 0.
#
#  CUBIERTOS HOY: en - es - fr - pt, o sea las SEIS webs del parque.
#  Al anadir un idioma, el riesgo NO es que falten patrones: es que un patron
#  valido en un idioma sea una palabra corriente en otro una vez sin acentos.
#  Ya ha pasado dos veces y las dos estan anotadas al lado de su bloque:
#    `il`/`elle` en frances -> impersonales (il faut, il y a): fuera
#    `e` acentuado y `nos` en portugues -> la conjuncion y la contraccion: fuera
#
#  SEVERIDAD (la de la skill, sin puntuaciones numericas: ella lo prohibe)
#    BLOQUEA   el motor no puede usar el pasaje   -> rc 1
#    DEBILITA  usable, pero hay versiones mejores -> rc 0, se lista
#    PULIDO    para la proxima revision            -> rc 0, se lista
#
#  QUE DEVUELVE
#    0  medido, y ningun BLOQUEA
#    1  medido, y hay al menos un BLOQUEA
#    3  NO MEDIDO -idioma no cubierto, o no se pudo leer-
#
#  USO
#    perl citable.pl --file pagina.html [--brand "Climent Media"]
#    perl citable.pl --repo DIR [--brand "..."]   (barre el arbol)
# =============================================================================
use strict;
use warnings;

my ($file, $repo, $brand, $quiet) = ('', '', '', 0);
while (@ARGV) {
  my $a = shift @ARGV;
  if    ($a eq '--file')  { $file  = shift @ARGV // '' }
  elsif ($a eq '--repo')  { $repo  = shift @ARGV // '' }
  elsif ($a eq '--brand') { $brand = shift @ARGV // '' }
  elsif ($a eq '--quiet' or $a eq '-q') { $quiet = 1 }
  else { die "argumento desconocido: $a\n" }
}
no_medido("hace falta --file o --repo") unless $file or $repo;

# --- patrones por idioma ------------------------------------------------------
# Cada idioma trae sus cuatro listas. Si un idioma no esta aqui, NO se mide.
my %LANG = (
  # 🔴 `pronoun` distingue PRONOMBRE de DETERMINANTE, y esa distincion la puso
  #    la primera corrida real: de 76 hallazgos, ~37 eran «this page», «that
  #    distinction», «these terms»... que NO son pronombres huerfanos - son un
  #    demostrativo con su sustantivo, o sea que el sujeto SI esta nombrado.
  #    Un instrumento con 50% de falsos positivos no mide, acusa.
  #    Regla: this/these/those/that solo cuentan si les sigue un VERBO.
  #    it/they son casi siempre pronombres -- la excepcion es el `it`
  #    impersonal, y tiene su propio patron `expletive` justo debajo.
  en => {
    # 🔴 26-ago-2026 · EL `it` IMPERSONAL DEL INGLES, FUERA.
    #    Es la misma trampa que ya se esquivo a proposito en frances con
    #    `il faut` / `il y a`, y el ingles la tiene igual sin guardia: en
    #    «It is recommended that...» el `it` no apunta a nada PORQUE NO HAY
    #    NADA A QUE APUNTAR. No es un pronombre huerfano, es un sujeto
    #    gramatical de relleno, y nombrarlo es imposible.
    #    Salio en climentmedia sobre una cita de la documentacion de Meta.
    #    Solo ingles: en espanol la construccion no lleva sujeto.
    expletive => qr/^\s*it(?:'s|\s+(?:is|was))\s+(?:recommended|said|known|thought|believed|assumed|understood|worth|possible|impossible|important|essential|easy|hard|difficult|tempting|common|rare|clear|obvious|fair|true|likely|unlikely|better|best|tempting|useful|normal|natural)\b|^\s*it\s+(?:turns out|follows that|remains to|helps to|depends how|makes sense to)\b/i,
    pronoun  => qr/^\s*(?:(?:this|these|those|that)\s+(?:is|are|was|were|means|meant|makes|made|gives|gave|shows|showed|happens|happened|works|worked|matters|mattered|explains|comes|goes|can|could|will|would|should|must|has|have|had|does|do|did|becomes|leaves|puts|takes|tends|seems|sounds|looks|feels|costs|breaks|fails|helps)\b|(?:this|that|these|those|it|they)'(?:s|re|ll|ve|d)\s+\w|(?:it|they)\s+\w)/i,
    backref  => qr/\b(as (?:mentioned|noted|discussed|we saw|shown) (?:above|earlier|previously)|see above|the (?:previous|preceding) (?:section|paragraph)|as explained earlier)\b/i,
    hedge    => qr/\b(may|might|could potentially|possibly|perhaps|arguably|somewhat|relatively|fairly|generally speaking|it seems|tends to)\b/i,
    reldate  => qr/\b(recently|currently|nowadays|these days|last year|this year|next year|lately|at the moment|in recent (?:years|months))\b/i,
    generic  => qr/\b(we|our|us|the (?:tool|platform|product|company|solution|service))\b/i,
  },
  es => {
    # esto/eso/ello/aquello son SIEMPRE pronombres. este/esta/estos/estas
    # pueden ser determinante -«esta pagina explica...»- y ahi solo cuentan
    # con un verbo detras. Misma correccion que en ingles, misma causa.
    pronoun  => qr/^\s*(?:(?:esto|eso|ello|aquello)\s+\w|(?:este|esta|estos|estas|esos|esas)\s+(?:es|son|era|eran|fue|fueron|significa|hace|da|muestra|pasa|funciona|importa|explica|puede|podria|va|deja|tiene|supone|implica|cuesta|falla|ayuda)\b)/i,
    backref  => qr/\b(como (?:se )?(?:vio|dijimos|vimos|hemos visto|se explico) (?:arriba|antes|anteriormente)|mas arriba|ver arriba|en el apartado anterior|como decia(?:mos)?)\b/i,
    hedge    => qr/\b(podria|podrian|quizas|quiza|tal vez|posiblemente|en principio|suele|tiende a|parece que|mas o menos|relativamente|bastante)\b/i,
    reldate  => qr/\b(recientemente|actualmente|hoy en dia|ultimamente|el ano pasado|este ano|en los ultimos (?:anos|meses)|por ahora)\b/i,
    generic  => qr/\b(nosotros|nuestra|nuestro|nuestras|nuestros|la (?:herramienta|plataforma|empresa|solucion))\b/i,
  },
  # 🆕 26-ago-2026 · FRANCES. Cubre DOS sitios -uno `fr` y otro `fr-BE`-, asi que
  #    lleva la cobertura del gate de 3 de 6 a 5 de 6 con un solo idioma. Era el
  #    punto de mejor relacion valor/coste del plan de webs.
  #
  #    🔴 `il` y `elle` NO entran, y es deliberado. En frances profesional el uso
  #       IMPERSONAL es constante -«il faut», «il y a», «il est possible»,
  #       «il s'agit de»- y ahi el pronombre no señala a nada porque no tiene a
  #       quien señalar: sacado de la pagina se entiende igual. Meterlos daria el
  #       mismo 50% de falsos positivos que dieron `this page` y `these terms` en
  #       ingles la primera vez. Se prefiere medir de menos y decirlo.
  #       Consecuencia honesta: en frances este check ve MENOS que en ingles.
  fr => {
    pronoun  => qr/^\s*(?:(?:c'est|ce sont|cela|ca|celui-ci|celle-ci|ceux-ci|celles-ci)\s+\w|(?:ce|cet|cette|ces)\s+(?:est|sont|etait|etaient|permet|permettent|signifie|montre|fonctionne|arrive|change|explique|donne|reste|devient|implique|coute|echoue|aide)\b)/i,
    backref  => qr/\b(comme (?:vu|indique|mentionne|explique|dit) (?:plus haut|ci-dessus|precedemment)|voir plus haut|ci-dessus|dans la section precedente|comme (?:nous l'avons vu|explique plus haut))\b/i,
    hedge    => qr/\b(peut-etre|pourrait|pourraient|probablement|sans doute|il semble|semblerait|a tendance a|relativement|plutot|en principe|generalement|dans certains cas)\b/i,
    reldate  => qr/\b(recemment|actuellement|aujourd'hui|de nos jours|dernierement|l'annee derniere|cette annee|ces derniers mois|pour l'instant|en ce moment)\b/i,
    generic  => qr/\b(nous|notre|nos|l'equipe|la plateforme|l'outil|la societe|le cabinet)\b/i,
  },
  # 🆕 26-ago-2026 · PORTUGUES. Cierra el sexto sitio, que ademas es el UNICO del
  #    parque con citas de IA -23 en 15 paginas- y por tanto el unico del que se
  #    puede aprender algo sobre por que un motor cita.
  #
  #    🔴 DOS PALABRAS QUEDAN FUERA A PROPOSITO, Y LAS DOS POR LA MISMA CAUSA:
  #       al quitar acentos colisionan con palabras corrientes.
  #       · `e` con acento -«E uma solucao...»- se vuelve `e`, que es la
  #         conjuncion «y». Acusaria una de cada dos frases.
  #       · `nos` con acento -«nosotros»- se vuelve `nos`, que es tambien la
  #         contraccion «en los». Se dejan solo nossa/nosso/nossas/nossos.
  #       Es la misma familia que la firma `A-tilde` ya documentada: un patron
  #       que sirve en un idioma es una palabra corriente en otro.
  pt => {
    pronoun  => qr/^\s*(?:(?:isto|isso|aquilo)\s+\w|(?:este|esta|estes|estas|esse|essa|esses|essas)\s+(?:e|sao|era|eram|foi|foram|significa|faz|da|mostra|acontece|funciona|importa|explica|pode|poderia|vai|deixa|tem|implica|custa|falha|ajuda)\b)/i,
    backref  => qr/\b(como (?:visto|referido|explicado|dito) acima|ver acima|acima referido|na seccao anterior|conforme (?:acima|referido))\b/i,
    hedge    => qr/\b(talvez|provavelmente|eventualmente|possivelmente|em principio|tende a|parece que|relativamente|bastante|geralmente|poderia|poderiam)\b/i,
    reldate  => qr/\b(recentemente|atualmente|actualmente|hoje em dia|ultimamente|o ano passado|este ano|nos ultimos (?:anos|meses)|de momento)\b/i,
    generic  => qr/\b(nossa|nosso|nossas|nossos|a (?:ferramenta|plataforma|empresa|loja|solucao))\b/i,
  },
);

# 🔴 26-ago-2026 · AMPLIADA PARA EL FRANCES. Traia solo los acentos del
#    castellano, y los patrones se comparan contra el texto SIN acentos: sin
#    `a` grave ni `e` grave, media palabra francesa no casaba con nada.
#    Los que faltaban se sacaron CONTANDO los del sitio real, no de memoria:
#    e-agudo 2235 · a-grave 683 · e-grave 104 · i-circunflejo 22 · c-cedilla 13
#    · e-circunflejo 8 · a-circunflejo 5 · o-circunflejo 4 · u-grave 3.
my %ACC = (
  "\xc3\xa1"=>'a',"\xc3\xa9"=>'e',"\xc3\xad"=>'i',"\xc3\xb3"=>'o',"\xc3\xba"=>'u',
  "\xc3\x81"=>'A',"\xc3\x89"=>'E',"\xc3\x8d"=>'I',"\xc3\x93"=>'O',"\xc3\x9a"=>'U',
  "\xc3\xb1"=>'n',"\xc3\x91"=>'N',"\xc3\xbc"=>'u',"\xc3\xa7"=>'c',"\xc3\x87"=>'C',
  "\xc3\xa0"=>'a',"\xc3\x80"=>'A',"\xc3\xa8"=>'e',"\xc3\x88"=>'E',
  "\xc3\xaa"=>'e',"\xc3\x8a"=>'E',"\xc3\xab"=>'e',"\xc3\xa2"=>'a',
  "\xc3\xae"=>'i',"\xc3\xaf"=>'i',"\xc3\xb4"=>'o',"\xc3\x94"=>'O',
  "\xc3\xb9"=>'u',"\xc3\xbb"=>'u',"\xc3\xa3"=>'a',"\xc3\xb5"=>'o',
);
sub deacc { my $s = shift; for my $k (keys %ACC) { my $v=$ACC{$k}; $s =~ s/\Q$k\E/$v/g } $s }

# --- reunir ficheros ----------------------------------------------------------
my @targets;
if ($file) { no_medido("no existe $file") unless -f $file; @targets = ($file) }
else {
  no_medido("no existe el directorio $repo") unless -d $repo;
  my @stack = ($repo);
  while (@stack) {
    my $d = pop @stack; opendir(my $dh, $d) or next;
    for my $e (readdir $dh) {
      next if $e eq '.' or $e eq '..';
      # 🔴 26-ago-2026 · ESTO ERA UNA LISTA DE NOMBRES ESCRITA A MANO, y por eso
      #    no conocia `_candidato`: la primera corrida real sobre un sitio en portugues midio
      #    82 paginas -13 reales + 69 copias del candidato-, o sea que cualquier
      #    defecto salia CONTADO DOS VECES. Es el mismo agujero que ya costo 78
      #    FALLOS falsos por `_og/` en nora, arreglado alli y no traido aqui.
      #    Ahora es una REGLA, no una lista: ningun directorio `_*` se publica
      #    -comprobado sobre los 13 que hay en las 6 webs-, asi que ninguno se
      #    mide. Una lista no puede enterarse de un directorio que aun no existe.
      next if $e =~ /^_/ or $e =~ /^(\.git|\.design-sync|node_modules|ds-bundle)$/;
      my $p = "$d/$e";
      if (-d $p) { push @stack, $p } elsif ($e =~ /\.html?$/i) { push @targets, $p }
    }
    closedir $dh;
  }
  no_medido("no hay ni un .html bajo $repo") unless @targets;
}

# --- medir --------------------------------------------------------------------
my (@findings, @skipped);
my ($n_med, $n_par, $n_banda) = (0, 0, 0);

for my $f (sort @targets) {
  open my $fh, '<', $f or do { push @skipped, [$f, "no se pudo abrir: $!"]; next };
  local $/; my $html = <$fh>; close $fh;

  my ($lang) = $html =~ m{<html[^>]*\blang=["']?([a-zA-Z]{2})}i;
  $lang = lc($lang // '');
  unless ($lang and $LANG{$lang}) {
    push @skipped, [ $f, $lang ? "idioma '$lang' sin patrones" : "sin <html lang>" ];
    next;
  }
  my $P = $LANG{$lang};
  $n_med++;

  # Fuera el cromo: nav, cabecera, pie, aparte, script y estilo. Medir el menu
  # como si fuera prosa produce hallazgos que no son de nadie.
  my $body = $html;
  $body =~ s{<(script|style|nav|header|footer|aside|form)\b.*?</\1>}{}gis;
  $body =~ s{<!--.*?-->}{}gs;

  my @paras;
  while ($body =~ m{<p\b[^>]*>(.*?)</p>}gis) {
    my $t = $1;
    $t =~ s/<[^>]*>//g;
    $t =~ s/&nbsp;/ /gi; $t =~ s/&amp;/&/gi;
    # 26-ago-2026 - EL APOSTROFO Y LAS COMILLAS, ANTES DEL COMODIN.
    #   El comodin de mas abajo convertia `&rsquo;` en un ESPACIO, asi que
    #   `It&rsquo;s recommended` se leia `It s recommended` y casaba con el
    #   patron de pronombre huerfano por una razon que no tiene nada que ver
    #   con el texto: un BLOQUEA fabricado por la propia normalizacion.
    #   Encontrado en climentmedia, 1 de 58.
    #   Y arreglar SOLO esto habria creado el fallo simetrico: `That&rsquo;s
    #   the part that fails` es un huerfano de verdad y habria dejado de
    #   verse. Por eso el patron aprende a leer contracciones en el mismo
    #   gesto. Los dos cambios van juntos o sobra uno.
    $t =~ s/&rsquo;|&lsquo;|&apos;|&#8217;|&#39;/'/gi;
    $t =~ s/&ldquo;|&rdquo;|&quot;|&#8220;|&#8221;/"/gi;
    $t =~ s/&mdash;|&ndash;|&#8212;|&#8211;/--/gi;
    $t =~ s/&[a-z]+;/ /gi; $t =~ s/&#x?[0-9a-f]+;/ /gi;
    $t =~ s/\s+/ /g; $t =~ s/^\s+|\s+$//g;
    next if length($t) < 40;      # pies de foto, etiquetas, migas
    push @paras, $t;
  }
  next unless @paras;

  my $rel = $f; $rel =~ s{^\Q$repo\E/?}{} if $repo;

  for my $t (@paras) {
    $n_par++;
    my $flat  = deacc($t);
    my @words = split /\s+/, $t;
    my $wc    = scalar @words;
    $n_banda++ if $wc >= 134 and $wc <= 167;
    my $frag  = length($t) > 90 ? substr($t, 0, 90) . '...' : $t;

    # 1 · pronombre huerfano al abrir  -> BLOQUEA
    # Dos salidas antes de acusar, las dos de la primera corrida real sobre
    # climentmedia:
    #   1) el `it` IMPERSONAL, que no apunta a nada porque no hay a que.
    #   2) una CITA TEXTUAL. Un pronombre huerfano dentro de una cita no se
    #      puede arreglar: reescribirlo es falsear a quien citas. Sigue
    #      valiendo saberlo -- por eso baja a PULIDO en vez de desaparecer --
    #      pero la accion es otra: dar contexto ANTES de abrir la cita.
    #      Un gate que exige lo imposible se acaba desactivando entero.
    #      🔴 Y LA COMILLA HAY QUE QUITARLA ANTES DE MIRAR, no despues. El
    #      patron esta anclado en `^`, asi que una comilla de apertura lo
    #      dejaba sin casar y el parrafo salia EXENTO EN SILENCIO -- un
    #      punto ciego peor que el falso positivo que vino a arreglar,
    #      porque no se ve. Se quita, se juzga, y si era cita se baja a
    #      PULIDO. Exento a proposito y exento por accidente se parecen
    #      mucho en la salida y no se parecen en nada.
    my $es_cita = ($t =~ /^\s*(?:"|\xe2\x80\x9c|\xc2\xab)/) ? 1 : 0;
    my $abre = $flat;
    $abre =~ s/^\s*(?:"|\xe2\x80\x9c|\xc2\xab)\s*//;
    if ($abre =~ $P->{pronoun}
        and not ($P->{expletive} and $abre =~ $P->{expletive})) {
      if ($es_cita) {
        push @findings, [ 'PULIDO', $rel, 'una cita textual abre con un pronombre', $frag,
          'una cita no se reescribe: da el contexto ANTES de abrirla, o parafrasea y atribuye' ];
      } else {
        push @findings, [ 'BLOQUEA', $rel, 'abre con un pronombre sin antecedente', $frag,
          'nombra el sujeto en la primera frase: sacado de la pagina, el pronombre no senala a nada' ];
      }
    }
    # 2 · referencia hacia atras  -> BLOQUEA
    if ($flat =~ $P->{backref}) {
      push @findings, [ 'BLOQUEA', $rel, 'referencia a algo anterior de la pagina', $frag,
        'repite el dato en vez de apuntar a el: al extraer el pasaje, "arriba" no existe' ];
    }
    # 3 · sujeto sin nombrar  -> DEBILITA (solo si se dio --brand)
    #
    # 🔴 SOLO en parrafos de >=60 palabras, y el umbral lo puso la primera
    #    corrida real: sin el, este check solo acuso a 156 de 840 parrafos -el
    #    19%- y habria hecho el gate inservible. Pedir la marca en CADA parrafo
    #    que dice «we» no es lo que pide la skill, y ademas repetirla veinte
    #    veces es keyword stuffing, que el propio estudio GEO mide en -10%.
    #    Lo que se cita son pasajes largos y autocontenidos; un «we built this»
    #    de 20 palabras no es candidato a extraccion.
    if (length $brand and $wc >= 60 and $flat =~ $P->{generic}) {
      my $b = deacc($brand);
      unless ($flat =~ /\Q$b\E/i) {
        push @findings, [ 'DEBILITA', $rel, 'dice "nosotros/la herramienta" y no nombra la marca', $frag,
          "nombra \"$brand\" una vez en el pasaje, o el motor no sabe a quien atribuirlo" ];
      }
    }
    # 4 · hedging  -> DEBILITA (dos o mas en el mismo parrafo)
    my $h = () = ($flat =~ /$P->{hedge}/gi);
    if ($h >= 2) {
      push @findings, [ 'DEBILITA', $rel, "$h atenuantes en un parrafo: no queda nada citable", $frag,
        'afirma lo que sepas y di lo que no sepas; el tono sin coletillas es lo que se cita' ];
    }
    # 5 · fecha relativa  -> DEBILITA
    if ($flat =~ $P->{reldate}) {
      push @findings, [ 'DEBILITA', $rel, 'fecha relativa: caduca sin avisar', $frag,
        'pon la fecha o el numero: "recientemente" no significa nada fuera de su contexto' ];
    }
    # 6 · parrafo demasiado largo  -> PULIDO
    my $sent = () = ($t =~ /[.!?](?:\s|$)/g);
    if ($sent > 5) {
      push @findings, [ 'PULIDO', $rel, "$sent frases en un parrafo", $frag,
        'partelo: un pasaje con varios hechos distintos se extrae a medias' ];
    }
  }
}

no_medido("ninguna pagina tenia un idioma con patrones (" . scalar(@skipped) . " saltadas)")
  if $n_med == 0;

# --- informe ------------------------------------------------------------------
my %ord = ( BLOQUEA => 0, DEBILITA => 1, PULIDO => 2 );
@findings = sort { $ord{$a->[0]} <=> $ord{$b->[0]} or $a->[1] cmp $b->[1] } @findings;
my @block = grep { $_->[0] eq 'BLOQUEA' } @findings;

unless ($quiet) {
  printf "paginas medidas: %d  ·  parrafos: %d\n", $n_med, $n_par;
  printf "pasajes en la banda de cita (134-167 palabras): %d\n\n", $n_banda;

  if (@skipped) {
    printf "NO MEDIDAS (%d) - un cero sobre estas no seria un aprobado:\n", scalar @skipped;
    printf "  %s  (%s)\n", $_->[0], $_->[1] for @skipped[0 .. ($#skipped > 9 ? 9 : $#skipped)];
    printf "  ... y %d mas\n", scalar(@skipped) - 10 if @skipped > 10;
    print "\n";
  }

  my $last = '';
  for my $f (@findings) {
    print "\n" if $f->[0] ne $last; $last = $f->[0];
    printf "  [%s] %s\n", $f->[0], $f->[1];
    printf "        %s\n", $f->[2];
    printf "        \"%s\"\n", $f->[3];
    printf "        -> %s\n", $f->[4];
  }
  print "\n";

  unless ($n_banda) {
    print "AVISO: ni un pasaje entre 134 y 167 palabras. Esa es la longitud que\n";
    print "extraen los motores para CITAR; la capsula de 40-60 cubre el fragmento\n";
    print "destacado, que es otra superficie. No tumba el gate: es una prior de un\n";
    print "solo estudio, no una regla nuestra medida.\n\n";
  }
}

if (@block) {
  printf "VEREDICTO: FALLA - %d BLOQUEA(N) la cita, %d debilitan, %d de pulido\n",
    scalar @block,
    scalar(grep { $_->[0] eq 'DEBILITA' } @findings),
    scalar(grep { $_->[0] eq 'PULIDO' } @findings);
  exit 1;
}
printf "VEREDICTO: PASA - 0 bloqueos, %d debilitan, %d de pulido%s\n",
  scalar(grep { $_->[0] eq 'DEBILITA' } @findings),
  scalar(grep { $_->[0] eq 'PULIDO' } @findings),
  (@skipped ? sprintf(' (%d NO MEDIDAS)', scalar @skipped) : '');
exit 0;

sub no_medido {
  my ($why) = @_;
  print "NO MEDIDO: $why\n";
  print "VEREDICTO: NO MEDIDO (rc=3). Esto NO es un aprobado.\n";
  exit 3;
}
