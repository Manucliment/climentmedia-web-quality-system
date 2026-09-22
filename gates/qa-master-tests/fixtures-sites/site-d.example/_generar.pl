#!/usr/bin/env perl
# =============================================================================
#  _generar.pl · site-d.example (produccion VIEJA) y fixtures-repos/site-d-web
#                (el repo ARREGLADO que aun no se ha subido)
# =============================================================================
#    perl fixtures-sites/site-d.example/_generar.pl
#
#  Escribe los DOS arboles a la vez, desde UNA tabla, para que las paginas
#  sean byte a byte las mismas en los dos y solo difieran en lo que el banco
#  necesita que difiera. Contenido INVENTADO: una clinica dental ficticia
#  («Clinica Dental Ejemplo») sin direccion, sin telefono y sin nadie real.
#  Nada que empiece por `_` lo sirve fake-production.pl (este fichero tampoco).
#
#  QUE REPRODUCE (los casos de tests.sh que nombran site-d / $BCREPO):
#    PRODUCCION (fixtures-sites/site-d.example/) · la version VIEJA
#      · --primary oklch(0.58 0.09 210): 4,01:1 sobre el lienzo -> A11Y-03 FALLO
#      · <link rel=icon href=/favicon.svg> y el fichero NO existe -> 404
#      · gracias/ emite data-thanks="page_view_gracias" y el contenedor
#        (_gtm.js) solo escucha thank_you_view -> MED-03
#      · la politica de cookies dice «pendiente de revision juridica» -> MED-08
#        y no nombra al proveedor que el contenedor carga -> MED-07
#      · casillas de analitica y publicidad premarcadas -> MED-06
#      · enlace de salto «Saltar al contenido» (A11Y-02 PASA)
#      · todo el texto comprimido (el proxy da gzip) y 0 webfonts
#      · sitemap de 40 URLs: con el tope por defecto (25) el gate mide 25 de 40
#      · 10 paginas con salto de titular h2->h4 (7 de ellas entre las 25
#        primeras): A11Y-08 FALLA sobre una lista recortada -> huella EVP
#      · terceros al ~93% del peso de /politica-cookies (ver TERCEROS abajo)
#    REPO (fixtures-repos/site-d-web/) · el arbol ARREGLADO sin desplegar
#      · las MISMAS paginas, byte a byte (EST-09 solo acusa a styles.css)
#      · styles.css con --primary oklch(0.54 0.09 210): 4,79:1 -> AA
#      · favicon.svg presente (230 B)
#      · script.js que SI lee data-thanks (el MED-05 de site-d esta arreglado)
#      · _migrate/origen/: HTML VIEJO del cliente, con data-* sin lector. El
#        gate NO lo escanea (no es codigo nuestro, no se despliega).
#
#  🔴 TERCEROS · por que el script de etiquetas vive en `terceros.example`
#     REN-05 cuenta como tercero todo recurso cuya URL no es del host exacto.
#     Las etiquetas de verdad (googletagmanager.com, por HTTPS) el banco NO las
#     alcanza: el proxy rechaza todo CONNECT, asi que salen «HTTP 0» y no pesan.
#     Por eso el peso de terceros lo sirve un HOST PROPIO, con su carpeta en
#     fixtures-sites/terceros.example/: para el navegador y para el gate es otro
#     origen, igual que el de verdad.
#     (La primera version lo servia de `site-d.example:8080`, que solo es otro
#     origen porque el proxy IGNORA el puerto: un detalle de implementacion del
#     servidor. El dia que alguien le ensenara a respetar puertos, REN-05
#     cambiaria sin avisar. Un host propio no depende de eso.)
#     El fichero es relleno pseudoaleatorio (semilla fija) porque lo que se
#     mide es su peso EN EL CABLE, ya comprimido: ~102 KB, como un contenedor de
#     etiquetas real. Con eso /politica-cookies (la mas ligera) queda al ~93%.
#
#  Solo modulos del nucleo (Compress::Zlib para los PNG, IO::Compress::Gzip
#  para medir el peso comprimido del relleno).
# =============================================================================
use strict; use warnings; use utf8;
use File::Basename qw(dirname);
use File::Path qw(make_path);
use Cwd qw(abs_path);
use Compress::Zlib qw(compress crc32);
use IO::Compress::Gzip qw(gzip $GzipError);

my $SITIO = dirname(abs_path($0));
my $REPO  = abs_path("$SITIO/../../fixtures-repos") . '/site-d-web';
my $HOST  = 'http://site-d.example';
my $MARCA = 'Clínica Dental Ejemplo';

sub escribe {
    my ($f, $txt, $raw) = @_;
    make_path(dirname($f));
    open my $h, ($raw ? '>:raw' : '>:encoding(UTF-8)'), $f or die "$f: $!";
    print $h $txt; close $h;
}
sub a_los_dos { my ($rel, $txt, $raw) = @_; escribe("$SITIO/$rel", $txt, $raw); escribe("$REPO/$rel", $txt, $raw) }

# ── LA TABLA ────────────────────────────────────────────────────────────────
#  slug | title | h1 | description | parrafo 1 | h2 A | parrafo A | h2 B | parrafo B
#  `salto` = el titular de la segunda seccion va en <h4> (salto h2->h4, A11Y-08)
#  El ORDEN es el del sitemap: la home la primera y /politica-cookies la ultima
#  (con --max-urls 40 y la muestra de 3, el gate mira las posiciones 0, 20 y 39).
my @P = (
 ['', "$MARCA · Tu dentista de barrio", 'Tu dentista de barrio, sin prisas',
  'Clínica dental ficticia de un sitio de pruebas: revisiones, implantes, ortodoncia y urgencias con cita en el mismo día.',
  'Atendemos a familias del barrio desde hace años. Te explicamos cada tratamiento antes de empezar y te damos el presupuesto por escrito.',
  'Lo que hacemos', 'Odontología general, implantes, ortodoncia para niños y adultos, estética dental y urgencias. Todo en la misma clínica.',
  'Cómo es la primera visita', 'Revisión completa, radiografía si hace falta y un plan por escrito. Sin compromiso y sin prisas.', {img=>'portada'}],
 ['tratamientos', "Tratamientos dentales · $MARCA", 'Todos nuestros tratamientos',
  'Lista completa de tratamientos de la clínica: desde una limpieza hasta un implante, con lo que dura y lo que cuesta cada uno.',
  'Aquí tienes cada tratamiento con una explicación corta. Si no sabes cuál necesitas, empieza por una primera visita.',
  'Odontología general', 'Revisiones, empastes, limpiezas y extracciones sencillas.',
  'Especialidades', 'Implantes, ortodoncia, endodoncia, periodoncia y cirugía oral.', {}],
 ['implantes-dentales', "Implantes dentales · $MARCA", 'Implantes dentales',
  'Qué es un implante dental, cuánto tarda el proceso completo y qué cuidados necesita después, explicado sin tecnicismos.',
  'Un implante sustituye la raíz de un diente perdido. Encima se coloca una corona que se ve y funciona como un diente propio.',
  'Cuánto tarda', 'Entre tres y seis meses desde la colocación hasta la corona definitiva, según el hueso de cada paciente.',
  'Cuidados', 'Cepillado normal, hilo o irrigador y una revisión al año.', {}],
 ['ortodoncia', "Ortodoncia con brackets · $MARCA", 'Ortodoncia con brackets',
  'Brackets metálicos y estéticos para niños y adultos: cuánto dura el tratamiento, cada cuánto hay revisión y qué molestias da.',
  'Los brackets siguen siendo la opción más versátil para mover los dientes. Los hay metálicos y de cerámica, casi invisibles.',
  'Duración', 'Entre doce y veinticuatro meses, con una revisión al mes.',
  'Molestias', 'Los primeros días tras cada ajuste notarás presión. Pasa sola en dos o tres días.', {}],
 ['ortodoncia-invisible', "Ortodoncia invisible · $MARCA", 'Ortodoncia invisible con alineadores',
  'Alineadores transparentes que se cambian cada dos semanas: para quién sirven, cuántas horas hay que llevarlos y cuánto cuestan.',
  'Los alineadores son férulas transparentes hechas a medida. Se quitan para comer y para cepillarse.',
  'Para quién', 'Para casos leves y moderados. En la primera visita te decimos si tu caso encaja.',
  'Horas de uso', 'Veintidós horas al día. Si no se llevan, el tratamiento se alarga.', {}],
 ['endodoncia', "Endodoncia · $MARCA", 'Endodoncia: salvar un diente dañado',
  'Cuándo hace falta una endodoncia, cómo es la sesión y por qué conservar el diente propio es mejor que extraerlo.',
  'La endodoncia limpia el interior de un diente infectado y lo sella. Se hace con anestesia local y no duele.',
  'Cómo es la sesión', 'Suele bastar una sesión de una hora. En dientes con varias raíces pueden ser dos.',
  'Después', 'Es normal notar el diente sensible dos o tres días. Luego se coloca una corona o un empaste.', {salto=>1}],
 ['periodoncia', "Periodoncia · $MARCA", 'Periodoncia: encías sanas',
  'Tratamiento de la enfermedad de las encías: señales de alarma, raspado y alisado radicular y mantenimiento posterior.',
  'Las encías que sangran al cepillarse no son normales. Son la primera señal de gingivitis, que tiene tratamiento.',
  'El tratamiento', 'Una limpieza profunda por debajo de la encía, por cuadrantes y con anestesia local.',
  'Mantenimiento', 'Revisiones cada tres o cuatro meses para que no vuelva.', {salto=>1}],
 ['blanqueamiento', "Blanqueamiento dental · $MARCA", 'Blanqueamiento dental',
  'Blanqueamiento en clínica y en casa: resultados reales, cuánto dura el efecto y quién no debería hacérselo.',
  'El blanqueamiento aclara el color natural del diente. No cambia empastes ni coronas, que se quedan del color que tenían.',
  'En clínica o en casa', 'En clínica es una sesión de una hora. En casa son férulas a medida durante dos semanas.',
  'Cuánto dura', 'Entre uno y dos años, según lo que comas y bebas.', {}],
 ['protesis-dentales', "Prótesis dentales · $MARCA", 'Prótesis dentales fijas y removibles',
  'Coronas, puentes y dentaduras: qué opción conviene según los dientes que faltan y cómo se adaptan las primeras semanas.',
  'Una prótesis repone dientes perdidos. Puede ser fija, sobre dientes o implantes, o removible, que se quita para limpiarla.',
  'Fijas', 'Coronas y puentes. Se sienten como dientes propios.',
  'Removibles', 'Más económicas. Necesitan unas semanas de adaptación.', {}],
 ['odontopediatria', "Odontopediatría · $MARCA", 'Dentista para niños',
  'Primera visita del niño al dentista, selladores, flúor y ortodoncia temprana, con un trato pensado para que no tenga miedo.',
  'La primera visita conviene antes de los tres años. Así el niño conoce la clínica sin que le duela nada.',
  'Prevención', 'Selladores en las muelas y flúor. Evitan la mayoría de caries infantiles.',
  'Ortodoncia temprana', 'A partir de los siete años revisamos cómo crecen los maxilares.', {salto=>1}],
 ['estetica-dental', "Estética dental · $MARCA", 'Estética dental',
  'Carillas, blanqueamiento, contorneado y diseño de sonrisa: qué se puede cambiar, qué no y cuánto tarda cada opción.',
  'La estética dental mejora forma y color sin renunciar a la salud del diente. Te enseñamos una simulación antes de empezar.',
  'Opciones', 'Blanqueamiento, carillas, contorneado de encías y adhesión de composite.',
  'Simulación', 'Te enseñamos cómo quedará antes de tocar un solo diente.', {}],
 ['carillas', "Carillas dentales · $MARCA", 'Carillas de porcelana y composite',
  'Diferencias entre carillas de porcelana y de composite, cuánto duran, cuánto cuestan y cómo se cuidan en el día a día.',
  'Una carilla es una lámina fina que se pega sobre la cara visible del diente para cambiar su forma o su color.',
  'Porcelana o composite', 'La porcelana dura más y no se mancha. El composite es más económico y se repara en una sesión.',
  'Cuidados', 'Los mismos que un diente propio, sin morder objetos duros.', {salto=>1}],
 ['cirugia-oral', "Cirugía oral · $MARCA", 'Cirugía oral',
  'Extracción de muelas del juicio, frenectomías y pequeñas cirugías con anestesia local, y lo que hay que hacer después.',
  'Hacemos en la clínica la mayoría de cirugías orales con anestesia local, sin ingreso y con alta el mismo día.',
  'Muelas del juicio', 'Se extraen si no tienen espacio o dan problemas repetidos.',
  'El postoperatorio', 'Frío local, dieta blanda dos días y la medicación que te indiquemos.', {}],
 ['higiene-dental', "Higiene dental · $MARCA", 'Limpieza e higiene dental',
  'Qué incluye una limpieza profesional, cada cuánto conviene hacerla y cómo mejorar el cepillado en casa para que dure más.',
  'Una limpieza profesional retira el sarro que el cepillo no alcanza. Conviene una o dos veces al año.',
  'Qué incluye', 'Ultrasonidos, pulido y revisión de encías.',
  'En casa', 'Cepillo suave, dos minutos, dos veces al día, e hilo por la noche.', {salto=>1}],
 ['urgencias-dentales', "Urgencias dentales · $MARCA", 'Urgencias dentales',
  'Qué hacer ante un dolor de muelas fuerte, un diente roto o un golpe, y cómo conseguir cita de urgencia en el mismo día.',
  'Guardamos huecos cada día para urgencias. Si te duele, llama por la mañana y te vemos ese mismo día.',
  'Dolor fuerte', 'Analgésico habitual y frío por fuera, nunca calor.',
  'Diente roto o caído', 'Guarda el trozo en leche y ven cuanto antes.', {}],
 ['sedacion-consciente', "Sedación consciente · $MARCA", 'Sedación consciente',
  'Tratamientos dentales con sedación consciente para pacientes con miedo al dentista: cómo funciona y qué se nota.',
  'La sedación consciente relaja sin dormir del todo. Sigues respondiendo, pero sin ansiedad.',
  'Cómo funciona', 'La administra un anestesista en la propia clínica.',
  'Después', 'Hay que venir acompañado y no conducir ese día.', {}],
 ['radiologia-3d', "Radiología 3D · $MARCA", 'Radiología dental en 3D',
  'Para qué sirve un escáner dental en tres dimensiones, cuándo se pide y qué dosis de radiación supone frente a otras pruebas.',
  'El escáner 3D enseña el hueso por dentro. Es imprescindible para planificar un implante con seguridad.',
  'Cuándo se pide', 'Antes de un implante, una cirugía de muelas del juicio o una ortodoncia compleja.',
  'Dosis', 'Muy baja, parecida a la de un viaje en avión.', {}],
 ['bruxismo', "Bruxismo · $MARCA", 'Bruxismo: apretar los dientes',
  'Señales de bruxismo, por qué desgasta los dientes y cómo protege una férula de descarga hecha a medida durante la noche.',
  'Apretar o rechinar los dientes, sobre todo de noche, desgasta el esmalte y carga la mandíbula.',
  'Señales', 'Dolor al despertar, dientes planos o sensibles y tensión en la mandíbula.',
  'La férula', 'Una férula a medida reparte la fuerza y protege los dientes mientras duermes.', {salto=>1}],
 ['equipo', "Equipo · $MARCA", 'Nuestro equipo',
  'Quién te atiende en la clínica: odontología general, ortodoncia, cirugía e higiene, con años de experiencia cada una.',
  'Somos un equipo pequeño. Te atiende siempre la misma persona en cada tratamiento.',
  'Especialidades', 'Odontología general, ortodoncia, cirugía oral, periodoncia e higiene.',
  'Formación', 'Todo el equipo se forma cada año en técnicas nuevas.', {}],
 ['instalaciones', "Instalaciones · $MARCA", 'Instalaciones de la clínica',
  'Cuatro gabinetes, esterilización a la vista y radiología en la propia clínica, con acceso sin escalones para todos.',
  'Cuatro gabinetes luminosos, sala de esterilización a la vista y radiología en la propia clínica.',
  'Accesibilidad', 'Entrada sin escalones y baño adaptado.',
  'Esterilización', 'Cada instrumento se esteriliza y se abre delante de ti.', {}],
 ['precios', "Precios · $MARCA", 'Precios orientativos',
  'Precios orientativos de los tratamientos más habituales. El presupuesto definitivo se da siempre por escrito tras la visita.',
  'Estos precios son orientativos. El presupuesto final lo damos por escrito después de la primera visita.',
  'Qué incluye', 'Cada precio incluye las revisiones del propio tratamiento.',
  'Sin sorpresas', 'Si algo cambia a mitad de tratamiento, te lo decimos antes de hacerlo.', {}],
 ['financiacion', "Financiación · $MARCA", 'Financiación sin intereses',
  'Cómo pagar un tratamiento largo en cuotas sin intereses, qué documentación se pide y en cuánto tiempo se aprueba.',
  'Puedes pagar los tratamientos largos en cuotas mensuales sin intereses.',
  'Requisitos', 'Un documento de identidad y una cuenta bancaria.',
  'Plazos', 'Hasta veinticuatro meses según el importe.', {}],
 ['primera-visita', "Primera visita · $MARCA", 'Tu primera visita',
  'Qué pasa en la primera visita: revisión, radiografía si hace falta, plan de tratamiento y presupuesto por escrito.',
  'La primera visita dura unos cuarenta minutos. Salimos con un plan claro y un presupuesto por escrito.',
  'Qué traer', 'Tus radiografías anteriores si las tienes y la lista de medicamentos que tomas.',
  'Qué te llevas', 'Un plan de tratamiento por escrito, con fases y precios.', {salto=>1}],
 ['preguntas-frecuentes', "Preguntas frecuentes · $MARCA", 'Preguntas frecuentes',
  'Respuestas cortas a las dudas más habituales: horarios, formas de pago, urgencias, niños y miedo al dentista.',
  'Reunimos aquí las preguntas que más nos hacen en recepción.',
  'Horarios', 'De lunes a viernes, mañana y tarde.',
  'Pagos', 'Efectivo, tarjeta y financiación en cuotas.', {}],
 ['opiniones', "Opiniones de pacientes · $MARCA", 'Lo que dicen nuestros pacientes',
  'Opiniones de pacientes de la clínica sobre el trato, las explicaciones y los resultados de sus tratamientos.',
  'Pedimos a cada paciente que nos cuente cómo le ha ido. Estas son algunas de sus respuestas, con su permiso.',
  'El trato', 'Lo que más valoran es que se les explique todo antes de empezar.',
  'Los resultados', 'Y que el presupuesto no cambie a mitad de camino.', {}],
 ['blog', "Blog · $MARCA", 'Blog de salud dental',
  'Artículos cortos sobre cepillado, sensibilidad, implantes, ortodoncia en adultos, encías y alimentación para los dientes.',
  'Artículos cortos y claros para cuidar tus dientes entre visita y visita.',
  'Lo último', 'Cepillado, sensibilidad, implantes, ortodoncia en adultos y encías.',
  'Cada mes', 'Publicamos un artículo nuevo cada mes.', {}],
 ['blog/cepillado-correcto', "Cómo cepillarse bien · $MARCA", 'Cómo cepillarse los dientes bien',
  'La técnica de cepillado que recomendamos en consulta, cuánto tiempo dedicarle y qué cepillo elegir según tus encías.',
  'Dos minutos, dos veces al día y sin apretar. Parece poco, pero casi nadie llega a los dos minutos.',
  'La técnica', 'Movimientos cortos, inclinando el cepillo hacia la encía.',
  'El cepillo', 'Suave o medio. Uno duro desgasta el esmalte y retrae la encía.', {}],
 ['blog/sensibilidad-dental', "Sensibilidad dental · $MARCA", 'Por qué tengo los dientes sensibles',
  'Causas más comunes de la sensibilidad dental al frío y al dulce, qué pasta ayuda y cuándo conviene pedir cita.',
  'La sensibilidad aparece cuando la dentina queda expuesta, por desgaste o por encías retraídas.',
  'Qué ayuda', 'Una pasta para dientes sensibles durante unas semanas.',
  'Cuándo venir', 'Si dura más de dos semanas o duele sin estímulo.', {salto=>1}],
 ['blog/implante-o-puente', "Implante o puente · $MARCA", 'Implante o puente: cuál elegir',
  'Ventajas e inconvenientes de un implante frente a un puente para reponer un diente, con precios y plazos comparados.',
  'Para reponer un diente hay dos caminos habituales: un implante o un puente sobre los dientes vecinos.',
  'El implante', 'No toca los dientes de al lado, pero tarda más.',
  'El puente', 'Es más rápido, pero hay que tallar los dientes vecinos.', {}],
 ['blog/ortodoncia-adultos', "Ortodoncia en adultos · $MARCA", 'Ortodoncia en adultos',
  'Nunca es tarde para la ortodoncia: qué opciones hay para adultos, cuánto dura y cómo encaja con la vida laboral.',
  'Cada vez más adultos se ponen ortodoncia. Los alineadores y los brackets estéticos apenas se notan.',
  'Duración', 'Algo más que en niños, porque el hueso ya no crece.',
  'En el trabajo', 'Los alineadores se quitan para comer y no se ven al hablar.', {}],
 ['blog/blanqueamiento-mitos', "Mitos del blanqueamiento · $MARCA", 'Cinco mitos del blanqueamiento',
  'Lo que es verdad y lo que no sobre el blanqueamiento dental: sensibilidad, esmalte, duración y remedios caseros.',
  'Del blanqueamiento se dicen muchas cosas. Repasamos las más repetidas en consulta.',
  'El esmalte', 'Un blanqueamiento bien hecho no daña el esmalte.',
  'Remedios caseros', 'El bicarbonato y el limón desgastan, no blanquean.', {}],
 ['blog/dieta-y-caries', "Dieta y caries · $MARCA", 'Qué comer para evitar caries',
  'Relación entre la dieta y la caries: la frecuencia del azúcar importa más que la cantidad. Consejos fáciles de aplicar.',
  'No es solo cuánto azúcar tomas, sino cuántas veces al día. Cada toma ataca el esmalte durante un rato.',
  'Picar entre horas', 'Es lo que más caries causa.',
  'Mejor con agua', 'Beber agua después de comer ayuda a limpiar.', {salto=>1}],
 ['blog/encias-que-sangran', "Encías que sangran · $MARCA", 'Me sangran las encías: qué hago',
  'Por qué sangran las encías al cepillarse, cuándo es gingivitis y qué tratamiento funciona para que deje de pasar.',
  'Si te sangran las encías al cepillarte, no dejes de cepillarte: es la primera señal de inflamación.',
  'La causa', 'Casi siempre es placa acumulada en el borde de la encía.',
  'El tratamiento', 'Una limpieza profesional y mejorar el cepillado.', {}],
 ['blog/muelas-del-juicio', "Muelas del juicio · $MARCA", 'Hay que quitar las muelas del juicio',
  'Cuándo conviene extraer las muelas del juicio y cuándo es mejor dejarlas, según su posición y los síntomas que den.',
  'No todas las muelas del juicio hay que quitarlas. Depende del espacio y de si dan problemas.',
  'Cuándo sí', 'Si se infectan a menudo o empujan a las demás.',
  'Cuándo no', 'Si han salido bien y se pueden limpiar.', {salto=>1}],
 ['contacto', "Contacto · $MARCA", 'Contacto',
  'Escríbenos para pedir cita o resolver una duda. Contestamos en el mismo día laborable, por correo o por teléfono.',
  'Escríbenos y te contestamos en el mismo día laborable.',
  'Formulario', 'Déjanos tu nombre, tu correo y lo que necesitas.',
  'Horario', 'De lunes a viernes, mañana y tarde.', {form=>1}],
 ['cita-online', "Pedir cita · $MARCA", 'Pedir cita',
  'Elige día y hora para tu primera visita o una revisión. Te confirmamos la cita por correo en menos de un día.',
  'Elige el tipo de visita y te proponemos las primeras horas libres.',
  'Revisión', 'Cuarenta minutos, con radiografía si hace falta.',
  'Urgencia', 'Si te duele, marca urgencia y te vemos hoy.', {}],
 ['aviso-legal', "Aviso legal · $MARCA", 'Aviso legal',
  'Datos del titular de este sitio web de pruebas, condiciones de uso y responsabilidad sobre los contenidos publicados.',
  'Este sitio es ficticio y existe solo para probar un control de calidad. Ningún dato de esta página corresponde a una clínica real.',
  'Condiciones de uso', 'El contenido es orientativo y no sustituye a una consulta.',
  'Propiedad intelectual', 'Los textos y las imágenes pertenecen a la clínica.', {}],
 ['politica-privacidad', "Política de privacidad · $MARCA", 'Política de privacidad',
  'Qué datos recoge el formulario de contacto, para qué se usan, quién los trata y cómo ejercer tus derechos sobre ellos.',
  'El formulario de contacto recoge tu nombre, tu correo y el mensaje que escribas, solo para contestarte.',
  'Tus derechos', 'Puedes pedir acceso, rectificación o supresión escribiendo por el formulario.',
  'Conservación', 'Guardamos los mensajes el tiempo necesario para atender tu consulta.', {}],
 ['mapa-web', "Mapa web · $MARCA", 'Mapa del sitio',
  'Todas las páginas del sitio en una sola lista: tratamientos, información práctica, blog, contacto y textos legales.',
  'Todas las páginas del sitio, agrupadas.',
  'Tratamientos', 'Todos los tratamientos de la clínica.',
  'Información', 'Equipo, instalaciones, precios y contacto.', {mapa=>1}],
 ['politica-cookies', "Política de cookies · $MARCA", 'Política de cookies',
  'Qué cookies usa este sitio, para qué sirve cada una y cómo cambiar tu elección en cualquier momento desde el banner.',
  'Este sitio usa cookies propias necesarias y, si las aceptas, cookies de medición y de publicidad.',
  'Qué guardamos', 'Tu elección sobre las cookies y, si la das, visitas agregadas y conversiones de anuncios.',
  'Cómo cambiarla', 'Abre el banner desde el pie de cualquier página.', {politica=>1}],
);
die "la tabla tiene que tener 40 paginas y tiene ".scalar(@P)."\n" unless @P == 40;

# ── PIEZAS COMUNES ──────────────────────────────────────────────────────────
sub url_de { my $s = shift; return $s eq '' ? "$HOST/" : "$HOST/$s" }
sub esc { my $t = shift; $t =~ s/&/&amp;/g; $t =~ s/</&lt;/g; $t =~ s/>/&gt;/g; $t =~ s/"/&quot;/g; return $t }

sub cabeza {
    my ($title, $desc, $canon, $extra) = @_;
    $extra //= '';
    my $t = esc($title); my $d = esc($desc);
    return <<"HTML";
<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$t</title>
<meta name="description" content="$d">
<link rel="canonical" href="$canon">
<meta property="og:title" content="$t">
<meta property="og:image" content="$HOST/img/portada.png">
<meta property="og:image:alt" content="Sillón de la clínica junto a una ventana grande">
<meta name="twitter:card" content="summary_large_image">
$extra<link rel="icon" href="/favicon.svg" type="image/svg+xml">
<link rel="stylesheet" href="/styles.css">
<script>window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments);}gtag('consent','default',{ad_storage:'denied',ad_user_data:'denied',ad_personalization:'denied',analytics_storage:'denied'});</script>
<script>(function(w,d,s,l,i){w[l]=w[l]||[];w[l].push({'gtm.start':new Date().getTime(),event:'gtm.js'});var f=d.getElementsByTagName(s)[0],j=d.createElement(s),dl=l!='dataLayer'?'&l='+l:'';j.async=true;j.src='https://www.googletagmanager.com/gtm.js?id='+i+dl;f.parentNode.insertBefore(j,f);})(window,document,'script','dataLayer','GTM-SITED01');</script>
<!-- etiquetas de terceros: otro HOST (terceros.example). Ver _generar.pl -->
<script async src="http://terceros.example/etiquetas/contenedor.js"></script>
<script type="application/ld+json">{"\@context":"https://schema.org","\@type":"Dentist","name":"$MARCA","url":"$HOST/"}</script>
<script defer src="/script.js"></script>
</head>
HTML
}

my $CABECERA = <<"HTML";
<a class="skip" href="#main">Saltar al contenido</a>
<header class="cab">
<a class="marca" href="/" aria-label="Inicio"><img src="/img/logo.png" alt="$MARCA" width="120" height="36"></a>
<nav aria-label="Principal"><a href="/tratamientos">Tratamientos</a> <a href="/equipo">Equipo</a> <a href="/precios">Precios</a> <a href="/blog">Blog</a> <a href="/contacto">Contacto</a></nav>
</header>
HTML

my $PIE = <<'HTML';
<footer class="pie">
<p>Sitio ficticio de pruebas. Ninguna clínica real está detrás de estas páginas.</p>
<p><a href="/aviso-legal">Aviso legal</a> · <a href="/politica-privacidad">Privacidad</a> · <a href="/politica-cookies">Cookies</a> · <a href="/mapa-web">Mapa web</a></p>
</footer>
HTML

# El banner de cookies de la version VIEJA: las casillas de analitica y de
# publicidad salen MARCADAS (MED-06). La de «necesarias» tambien, y esa es
# legitima: el gate la exime por nombre.
my $BANNER = <<'HTML';
<div class="cc" role="dialog" aria-label="Preferencias de cookies">
<p>Usamos cookies propias necesarias y, si las aceptas, de medición y de publicidad. <a href="/politica-cookies">Más información</a></p>
<label><input type="checkbox" data-cc="necesarias" checked disabled> Necesarias</label>
<label><input type="checkbox" data-cc="analitica" checked> Analítica</label>
<label><input type="checkbox" data-cc="publicidad" checked> Publicidad</label>
<button type="button" class="cc__btn">Guardar</button>
</div>
HTML

my $CTA = '<a class="btn" href="/cita-online" data-event="click_cita">Pedir cita</a>';

sub pagina {
    my ($i) = @_;
    my ($slug, $title, $h1, $desc, $p1, $ha, $pa, $hb, $pb, $f) = @{ $P[$i] };
    my $h = cabeza($title, $desc, url_de($slug));
    $h .= "<body>\n$CABECERA<main id=\"main\">\n";
    # 🔴 el <h1> en UNA linea: el bloque «arbol roto» de tests.sh lo quita con
    #    un `perl -pe` por lineas y luego exige que no quede ningun «<h1».
    $h .= "<section class=\"intro\">\n<h1>".esc($h1)."</h1>\n<p>".esc($p1)."</p>\n";
    $h .= "<p>$CTA</p>\n" unless $f->{politica};
    if ($f->{img}) {
        $h .= "<img class=\"portada\" src=\"/img/portada.png\" alt=\"Sillón de la clínica junto a una ventana grande\" width=\"640\" height=\"360\">\n";
    } elsif (!$f->{politica}) {
        $h .= "<img class=\"ilustra\" src=\"/img/sonrisa.png\" alt=\"\" width=\"320\" height=\"180\">\n";
    }
    $h .= "</section>\n";
    if ($f->{politica}) {
        # 🔴 MED-08: la frase del borrador, EN VIVO. Y ni una palabra de a que
        #    empresa se mandan los datos de medicion y publicidad (MED-07).
        $h .= "<section>\n<p class=\"aviso\">Texto pendiente de revisión jurídica.</p>\n"
            . "<ul>\n<li>Necesarias: guardan tu elección sobre las cookies. Duran un año.</li>\n"
            . "<li>Medición: cuentan visitas de forma agregada. Son de terceros y solo se instalan si las aceptas.</li>\n"
            . "<li>Publicidad: miden si un anuncio acaba en una cita. Son de terceros y solo se instalan si las aceptas.</li>\n</ul>\n"
            . "</section>\n";
    }
    $h .= "<section>\n<h2>".esc($ha)."</h2>\n<p>".esc($pa)."</p>\n</section>\n";
    # `salto`: la segunda seccion titula en <h4> justo despues de un <h2>. Es el
    # defecto de la version vieja que A11Y-08 caza (h2->h4).
    my $nb = $f->{salto} ? 'h4' : 'h2';
    $h .= "<section>\n<$nb>".esc($hb)."</$nb>\n<p>".esc($pb)."</p>\n</section>\n";
    if ($f->{form}) {
        $h .= <<'HTML';
<section>
<form class="contacto" action="/enviar.php" method="post">
<label>Nombre <input type="text" name="nombre" autocomplete="given-name" required></label>
<label>Correo <input type="email" name="email" autocomplete="email" required></label>
<label>Mensaje <textarea name="mensaje" rows="4"></textarea></label>
<div class="errores" aria-live="polite"></div>
<button type="submit" class="btn">Enviar</button>
</form>
</section>
HTML
    }
    if ($f->{mapa}) {
        $h .= "<section>\n<ul>\n";
        $h .= "<li><a href=\"/".$_->[0]."\">".esc($_->[2])."</a></li>\n" for grep { $_->[0] ne '' && $_->[0] ne 'mapa-web' } @P;
        $h .= "</ul>\n</section>\n";
    }
    if ($slug eq 'tratamientos' || $slug eq 'blog') {
        my $pre = $slug eq 'blog' ? 'blog/' : '';
        my @hijos = grep { $slug eq 'blog' ? $_->[0] =~ m{^blog/} : ($_->[0] ne '' && $_->[0] !~ m{/} && $_->[0] =~ /^(implantes|ortodoncia|endodoncia|periodoncia|blanqueamiento|protesis|odontopediatria|estetica|carillas|cirugia|higiene|urgencias|sedacion|radiologia|bruxismo)/) } @P;
        $h .= "<section>\n<ul>\n";
        $h .= "<li><a href=\"/".$_->[0]."\">".esc($_->[2])."</a></li>\n" for @hijos;
        $h .= "</ul>\n</section>\n";
    }
    $h .= "</main>\n$PIE$BANNER</body>\n</html>\n";
    return $h;
}

# ── LAS 40 PAGINAS, IGUALES EN LOS DOS ARBOLES ──────────────────────────────
for my $i (0 .. $#P) {
    my $slug = $P[$i][0];
    a_los_dos($slug eq '' ? 'index.html' : "$slug.html", pagina($i));
}

# gracias/ · la conversion. Emite su evento en el MARCADO (data-thanks) y
# script.js lo empuja al dataLayer. El contenedor NO lo escucha (MED-03).
# ⚠️ Ningun comentario que cite un evento: MED-03 lee este cuerpo EN CRUDO
#    (sin quitar comentarios), y un nombre citado contaria como emitido.
{
    my $h = cabeza("Gracias · $MARCA", 'Hemos recibido tu mensaje y te contestamos en el mismo día laborable, por correo o por teléfono.',
                   "$HOST/gracias/", qq{<meta name="robots" content="noindex">\n});
    $h .= "<body>\n$CABECERA<main id=\"main\" data-thanks=\"page_view_gracias\">\n"
        . "<section>\n<h1>Gracias, hemos recibido tu mensaje</h1>\n<p>Te contestamos en el mismo día laborable.</p>\n"
        . "<p><a href=\"/\">Volver al inicio</a></p>\n</section>\n</main>\n$PIE</body>\n</html>\n";
    a_los_dos('gracias/index.html', $h);
}

# 404 · una buena: h1, y salidas vivas. Igual en los dos (el candidato solo
# puede decir que su CONTENIDO cumple; el estado lo da el host).
{
    my $h = cabeza("Página no encontrada · $MARCA", 'La página que buscas no existe o ha cambiado de dirección. Desde aquí puedes volver a las más visitadas.',
                   "$HOST/404", qq{<meta name="robots" content="noindex">\n});
    $h .= "<body>\n$CABECERA<main id=\"main\">\n<section>\n<h1>No encontramos esa página</h1>\n"
        . "<p>Puede que haya cambiado de dirección. Estas son las más visitadas:</p>\n"
        . "<ul><li><a href=\"/tratamientos\">Tratamientos</a></li><li><a href=\"/cita-online\">Pedir cita</a></li><li><a href=\"/urgencias-dentales\">Urgencias</a></li><li><a href=\"/contacto\">Contacto</a></li></ul>\n"
        . "</section>\n</main>\n$PIE</body>\n</html>\n";
    a_los_dos('404.html', $h);
}

# sitemap (40 URLs, en el orden de la tabla) y robots
{
    my $x = qq{<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n};
    $x .= "  <url><loc>".url_de($_->[0])."</loc></url>\n" for @P;
    $x .= "</urlset>\n";
    a_los_dos('sitemap.xml', $x);
    a_los_dos('robots.txt', "User-agent: *\nAllow: /\nSitemap: $HOST/sitemap.xml\n");
}

# script.js · IGUAL en los dos. Lee data-event, data-thanks y data-cc.
a_los_dos('script.js', <<'JS');
/* Clinica Dental Ejemplo · sitio ficticio del banco de pruebas de qa-master */
(function () {
  'use strict';
  window.dataLayer = window.dataLayer || [];
  // Cada enlace con data-event empuja su nombre al dataLayer al pulsarlo.
  document.addEventListener('click', function (ev) {
    var el = ev.target.closest('[data-event]');
    if (el) window.dataLayer.push({ event: el.getAttribute('data-event') });
  });
  // La pagina de gracias declara su evento en el marcado.
  var gracias = document.querySelector('[data-thanks]');
  if (gracias) window.dataLayer.push({ event: gracias.getAttribute('data-thanks') });
  // Banner de cookies: lee las casillas y actualiza el consentimiento.
  var cc = document.querySelector('.cc');
  if (cc) {
    cc.querySelector('.cc__btn').addEventListener('click', function () {
      var elegido = {};
      cc.querySelectorAll('[data-cc]').forEach(function (c) { elegido[c.dataset.cc] = c.checked; });
      gtag('consent', 'update', {
        analytics_storage: elegido.analitica ? 'granted' : 'denied',
        ad_storage: elegido.publicidad ? 'granted' : 'denied'
      });
      cc.hidden = true;
    });
  }
  // Formulario: el boton se deshabilita mientras se envia.
  var form = document.querySelector('form.contacto');
  if (form) {
    form.addEventListener('submit', function () {
      var b = form.querySelector('button[type=submit]');
      b.disabled = true;
      b.textContent = 'Enviando...';
    });
  }
})();
JS

# styles.css · la UNICA pagina de texto que difiere entre los dos arboles.
sub hoja {
    my ($L) = @_;
    return <<"CSS";
/* Clinica Dental Ejemplo · sitio ficticio del banco de pruebas de qa-master */
:root {
  --background: oklch(0.99 0.005 210);
  --foreground: oklch(0.25 0.02 250);
  --primary: oklch($L 0.09 210);
  --primary-foreground: oklch(0.99 0.005 210);
  --muted: oklch(0.45 0.02 250);
  --surface: #ffffff;
  --radius: 10px;
}
* { box-sizing: border-box; }
body { margin: 0; background: var(--background); color: var(--foreground); font-family: system-ui, -apple-system, "Segoe UI", sans-serif; line-height: 1.6; }
a { color: var(--primary); }
.skip { position: absolute; left: -999px; top: 0; padding: 8px 12px; background: var(--foreground); color: var(--background); }
.skip:focus { left: 8px; }
.cab { display: flex; justify-content: space-between; align-items: center; padding: 12px 24px; }
.cab nav a { margin-left: 16px; color: var(--foreground); text-decoration: none; }
main { max-width: 860px; margin: 0 auto; padding: 24px; }
section { margin: 32px 0; }
h1, h2, h3, h4 { line-height: 1.2; color: var(--foreground); }
.btn { display: inline-block; padding: 12px 20px; border: 0; border-radius: var(--radius); background: var(--primary); color: var(--primary-foreground); text-decoration: none; font-weight: 600; }
.aviso { color: var(--muted); font-style: italic; }
.portada, .ilustra { max-width: 100%; height: auto; border-radius: var(--radius); }
.pie { padding: 24px; background: var(--foreground); color: var(--background); }
.pie a { color: var(--background); }
.cc { position: fixed; left: 16px; right: 16px; bottom: 16px; padding: 16px; border-radius: var(--radius); background: var(--surface); color: var(--foreground); box-shadow: 0 4px 24px rgba(0, 0, 0, 0.15); }
.cc label { margin-right: 12px; }
.cc__btn { padding: 8px 16px; border: 0; border-radius: var(--radius); background: var(--primary); color: var(--primary-foreground); }
.contacto label { display: block; margin-bottom: 12px; }
.contacto input, .contacto textarea { display: block; width: 100%; max-width: 480px; margin-top: 4px; padding: 10px 12px; border: 1px solid; border-radius: 6px; font: inherit; }
.contacto .errores { min-height: 1.5em; margin: 8px 0; }
h1 { font-size: 2.25rem; margin: 0 0 16px; letter-spacing: -0.01em; }
h2 { font-size: 1.5rem; margin: 0 0 12px; }
h3, h4 { font-size: 1.15rem; margin: 20px 0 8px; }
p { margin: 0 0 12px; max-width: 68ch; }
ul { margin: 0 0 16px; padding-left: 20px; }
li { margin-bottom: 6px; }
img { display: block; }
.intro { display: grid; gap: 16px; align-items: start; }
.intro .btn { justify-self: start; }
.marca img { width: 120px; height: auto; }
.cab nav { display: flex; flex-wrap: wrap; gap: 4px 0; }
.pie p { margin: 0 auto 8px; max-width: 860px; font-size: 0.9rem; }
.cc p { margin-bottom: 8px; font-size: 0.95rem; }
.cc[hidden] { display: none; }
[hidden] { display: none !important; }
CSS
}
escribe("$SITIO/styles.css", hoja('0.58'));    # la VIEJA: 4,01:1, no llega a AA
escribe("$REPO/styles.css",  hoja('0.54'));    # la ARREGLADA: 4,79:1

# favicon.svg · SOLO en el repo. En produccion la URL da 404 (REN-07/REN-13).
escribe("$REPO/favicon.svg", <<'SVG');
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect width="32" height="32" rx="7" fill="#1f6f7a"/><path d="M9 9c3-2 5 0 7 0s4-2 7 0c2 2 1 6 0 9-1 3-1 6-3 6s-2-5-4-5-2 5-4 5-2-3-3-6c-1-3-2-7 0-9z" fill="#fff"/></svg>
SVG

# enviar.php · SOLO en produccion: el receptor. El proxy no ejecuta PHP; con
# `status /enviar.php 405` (en _prod.txt) contesta a un GET como un receptor
# bien puesto. En el repo los receptores viven en _deploy/ y no se sirven.
escribe("$SITIO/enviar.php", "<?php\n// Receptor ficticio del formulario de contacto. A un GET contesta 405.\n");

# ── _migrate/origen/ · la web VIEJA del cliente, SOLO en el repo ────────────
#  Evidencia de la migracion; no se despliega y no es codigo nuestro. Lleva
#  data-* de su plantilla que no lee nadie: si MED-05 escaneara esta carpeta
#  los acusaria (es lo que hacia antes del 11-ago-2026).
escribe("$REPO/_migrate/origen/index.html", <<'HTML');
<!DOCTYPE html>
<html lang="es">
<head><meta charset="utf-8"><title>Clinica Dental Ejemplo - Inicio (web anterior, capturada para la migracion)</title></head>
<body class="home page-template-default">
<div class="slider" data-slider-autoplay="true" data-slider-speed="600">
<div class="slide"><h2>Tu sonrisa en buenas manos</h2></div>
</div>
<section class="bloque" data-parallax="scroll" data-wow-delay="0.3s">
<h1>Bienvenidos a nuestra clinica</h1>
<p>Pagina de la web anterior, guardada tal cual para comparar la migracion.</p>
<a href="#" class="boton" data-toggle="modal">Pide cita</a>
</section>
</body>
</html>
HTML
escribe("$REPO/_migrate/origen/tratamientos.html", <<'HTML');
<!DOCTYPE html>
<html lang="es">
<head><meta charset="utf-8"><title>Tratamientos - Clinica Dental Ejemplo (web anterior)</title></head>
<body class="page-template-default">
<div class="acordeon" data-accordion-index="0"><h3>Implantes</h3><p>Texto de la web anterior.</p></div>
<div class="acordeon" data-accordion-index="1"><h3>Ortodoncia</h3><p>Texto de la web anterior.</p></div>
</body>
</html>
HTML

# ── IMAGENES · PNG de verdad, generados aqui ────────────────────────────────
#  Pesan en el cable lo que pesan en disco (el proxy no comprime binarios), y
#  esa es la «web propia» contra la que se mide la proporcion de terceros.
#  Generador pseudoaleatorio propio (xorshift32) y no `rand`: asi el arbol sale
#  IGUAL byte a byte en cualquier maquina, que es lo que permite regenerarlo.
my $semilla;
sub azar { $semilla ^= ($semilla << 13) & 0xFFFFFFFF; $semilla ^= $semilla >> 17; $semilla ^= ($semilla << 5) & 0xFFFFFFFF; return $semilla & 0xFFFFFFFF }
sub png {
    my ($w, $h, $densidad, $sem, $fondo) = @_;
    $semilla = $sem;
    my $crudo = '';
    for my $y (0 .. $h - 1) {
        $crudo .= "\0";
        for my $x (0 .. $w - 1) {
            my @c = $fondo->($x, $y);
            @c = map { my $v = $_ + (azar() % 5) - 2; $v < 0 ? 0 : $v > 255 ? 255 : $v } @c if azar() % 1000 < $densidad;
            $crudo .= pack('C3', @c);
        }
    }
    my $trozo = sub { my ($t, $d) = @_; pack('N', length $d) . $t . $d . pack('N', crc32($t . $d)) };
    return "\x89PNG\r\n\x1a\n" . $trozo->('IHDR', pack('NNCCCCC', $w, $h, 8, 2, 0, 0, 0))
         . $trozo->('IDAT', compress($crudo, 9)) . $trozo->('IEND', '');
}
#  El PNG MAS GRANDE que no pasa de $tope bytes: se busca la densidad de ruido.
sub png_de {
    my ($w, $h, $tope, $sem, $fondo) = @_;
    my ($lo, $hi, $mejor) = (0, 1000, png($w, $h, 0, $sem, $fondo));
    die "ni sin ruido cabe en $tope B\n" if length($mejor) > $tope;
    while ($lo < $hi) {
        my $m = int(($lo + $hi + 1) / 2);
        my $p = png($w, $h, $m, $sem, $fondo);
        if (length($p) <= $tope) { ($lo, $mejor) = ($m, $p) } else { $hi = $m - 1 }
    }
    return $mejor;
}
my %png = (
    # logo: por debajo del suelo de 4 KB de REN-02 (a un logo no se le mide B/px)
    'img/logo.png'    => png_de(120, 36, 3900, 11, sub { my ($x, $y) = @_; $x < 36 ? (31, 111, 122) : (250, 252, 252) }),
    # portada de la home: 320x180, declarada a 640x360 (~0,13 B/px)
    'img/portada.png' => png_de(320, 180, 30000, 12, sub { my ($x, $y) = @_; (200 + int($x / 8), 220 - int($y / 6), 230) }),
    # ilustracion comun de todas las paginas menos /politica-cookies
    'img/sonrisa.png' => png_de(96, 54, 2900, 13, sub { my ($x, $y) = @_; (235, 240 - int($y / 2), 245) }),
);
a_los_dos($_, $png{$_}, 1) for sort keys %png;
$semilla = 20260922;

# ── TERCEROS · el relleno de las etiquetas, SOLO en produccion ──────────────
#  Cadenas alfanumericas pseudoaleatorias (sin + ni /: dentro de cada cadena no
#  hay frontera de palabra, asi que el barrido de fugas no puede casar nada).
{
    my @al = ('A'..'Z', 'a'..'z', '0'..'9');
    my $js = "/* Etiquetas de terceros SINTETICAS del banco de qa-master (site-d.example).\n"
           . "   Relleno pseudoaleatorio con semilla fija: no ejecuta nada. Existe para que\n"
           . "   REN-05 mida un contenedor de etiquetas del peso de uno real, EN EL CABLE.\n"
           . "   Ver fixtures-sites/site-d.example/_generar.pl. */\n"
           . "(function () {\n  var relleno = [\n";
    my $n = 0;
    my $objetivo = 102 * 1024;     # bytes comprimidos
    my $cuerpo = '';
    while (1) {
        $cuerpo .= '    "' . join('', map { $al[azar() % 62] } 1 .. 64) . "\",\n";
        $n++;
        next if $n % 5;
        my $z; gzip(\($js . $cuerpo) => \$z) or die $GzipError;
        last if length($z) >= $objetivo;
    }
    $js .= $cuerpo . "    \"\"\n  ];\n  window.__etiquetas = relleno.length;\n})();\n";
    escribe(abs_path("$SITIO/..") . "/terceros.example/etiquetas/contenedor.js", $js);
}
print "escritos: $SITIO y $REPO\n";
