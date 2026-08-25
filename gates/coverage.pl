#!/usr/bin/perl
# =============================================================================
#  coverage.pl · CUANTAS COMPROBACIONES TIENEN CASO, Y CUALES NO
# =============================================================================
#    perl coverage.pl            # el resumen
#    perl coverage.pl --cuales   # ademas, la lista de las que no tienen
#
#  🔴 POR QUE EXISTE. La regla 5 de `00-formula.md` dice que ningun check entra
#     sin fixture rojo y verde. Es la regla mas facil de escribir y la mas facil
#     de incumplir, porque **incumplirla no se nota**: un check sin caso se ve
#     igual de verde que uno probado, y solo se distingue el dia que falla en
#     una web de cliente.
#
#     Este programa la hace CONTABLE. No bloquea nada -- y es a proposito: hoy
#     hay decenas sin caso, y un gate que sale en rojo desde el primer dia se
#     apaga. Lo que hace es dar UN numero que solo puede subir escribiendo
#     pruebas, y que no se puede maquillar midiendo menos.
#
#  ⚠️ QUE SIGNIFICA «TIENE CASO» AQUI, para que nadie lea de mas: que el ID
#     aparece en algun fichero del banco de ese programa. Eso NO garantiza que
#     el caso sea bueno, ni que se haya visto en rojo. Es el suelo, no el techo.
#     Un ID que ni siquiera aparece, en cambio, es seguro que no tiene prueba.
# =============================================================================
use strict;
use warnings;

my $CUALES = grep { $_ eq '--cuales' || $_ eq '--which' } @ARGV;   # English alias
my ($DIR) = $0 =~ m{^(.*)[\\/][^\\/]+$};
$DIR = '.' unless defined $DIR && $DIR ne '';

# programa => carpeta de su banco
my @PARES = (
    ['qa-master.pl',     'qa-master-tests',    'las 5 lentes'],
    ['linking-gate.pl',  'crawl-links-tests', 'las reglas de enlazado'],
    ['audit-vs-spec.pl',  'audit-vs-spec-tests', 'la spec contra el arbol'],
    ['doc-gate.pl',       'doc-gate-tests',      'la documentacion'],
);

sub slurp { my $f = shift; open my $h, '<:raw', $f or return ''; local $/; my $c = <$h>; close $h; $c }

# todo el texto de un banco, de una sola vez
sub texto_banco {
    my $d = shift;
    return '' unless -d $d;
    my $t = '';
    opendir(my $dh, $d) or return '';
    for my $e (sort readdir $dh) {
        next if $e =~ /^\./;
        my $p = "$d/$e";
        if (-d $p) { $t .= texto_banco($p) }
        # solo los ficheros de PRUEBA, no los fixtures binarios ni los .html
        elsif ($e =~ /\.(pl|sh|js|md|txt)$/) { $t .= slurp($p) }
    }
    closedir $dh;
    return $t;
}

printf "===== COBERTURA DE COMPROBACIONES · cuantas tienen caso =====\n\n";
my ($T_ids, $T_con) = (0, 0);
my @detalle;

for my $par (@PARES) {
    my ($prog, $banco, $que) = @$par;
    my $src = slurp("$DIR/$prog");
    unless ($src) { printf "  %-20s no encuentro el programa\n", $prog; next }

    my %ids;
    # los dos patrones con que se declaran hoy
    $ids{$1} = 1 while $src =~ /id\s*=>\s*'([A-Z][A-Z0-9]*-[0-9]+[a-z]?)'/g;
    # 🔴 18-ago-2026 · SOLO LEIA LA COMILLA SIMPLE, y `linking-gate.pl:63`
    #  declara R1 con comillas DOBLES: bad("R1 profundidad <= $lim clics", ...).
    #  Efecto: R1 no existia para este contador, el denominador salia 10 en vez
    #  de 11, y el programa publicaba «enlazado-gate 10 de 10 = 100%» sobre una
    #  regla que no habia mirado. Un contador anclado a su propio grep se cree a
    #  si mismo -- la misma enfermedad del §14 y del §44.
    $ids{$1} = 1 while $src =~ /\b(?:ok|bad|avis|nv)\(['"](R[0-9]{1,2})\b/g;
    $ids{$1} = 1 while $src =~ /\b(?:ok|bad|avis|nv)\(['"](D[0-9])['"]/g;

    my @ids = sort keys %ids;
    unless (@ids) { printf "  %-20s no emite IDs que sepa leer\n", $prog; next }

    my $texto = texto_banco("$DIR/$banco");
    my (@con, @sin);
    for my $id (@ids) {
        # \b no vale: los IDs llevan guion, y «SEO-1» casaria dentro de «SEO-10».
        if ($texto =~ /\Q$id\E(?![0-9A-Za-z])/) { push @con, $id } else { push @sin, $id }
    }
    my $pct = @ids ? int(100 * @con / @ids) : 0;
    printf "  %-20s %3d de %3d con caso (%2d%%)   %s\n",
           $prog, scalar(@con), scalar(@ids), $pct,
           (-d "$DIR/$banco" ? $que : "SIN BANCO — $banco no existe");
    push @detalle, [$prog, \@sin] if @sin;
    $T_ids += @ids; $T_con += @con;
}

printf "\n  TOTAL: %d de %d comprobaciones tienen caso (%d%%)\n",
       $T_con, $T_ids, ($T_ids ? int(100 * $T_con / $T_ids) : 0);

# 🔴 18-ago-2026 · Y DE CUANTOS PROGRAMAS. Este porcentaje se leia como «la
#  cobertura del instrumento» y no lo es: @PARES tiene 4 entradas y la carpeta
#  tiene muchos mas programas. Un numero alto sobre una cuarta parte del parque
#  tranquiliza mas de lo que informa, y asi es como acabe diciendo «89%» de un
#  instrumento cuyo 71% no tiene con que fallar. El alcance se imprime SIEMPRE,
#  no bajo una bandera: lo que no se ve, no se corrige.
{
    opendir(my $dh, $DIR) or last;
    my @progs = grep { /\.(pl|sh|js)$/ && !/-pruebas|autoprueba|^pruebas-/ } readdir $dh;
    closedir $dh;
    my %medido = map { $_->[0] => 1 } @PARES;
    my @fuera = sort grep { !$medido{$_} } @progs;
    printf "  ALCANCE: mide %d programas de %d. NO mide: %s\n",
           scalar(@PARES), scalar(@progs), (@fuera ? join(' ', @fuera) : '(ninguno)');
    print  "  Ese % es de los 4 medidos, NO del instrumento entero.\n" if @fuera;
}

if ($CUALES) {
    for my $d (@detalle) {
        my ($prog, $sin) = @$d;
        printf "\n  sin caso en %s (%d):\n", $prog, scalar @$sin;
        my @l = @$sin;
        while (@l) { my @linea = splice(@l, 0, 10); print "    ", join(' ', @linea), "\n" }
    }
} elsif (@detalle) {
    print "  (--cuales para ver cuales)\n";
}

print "\n  Este numero no bloquea nada y solo sube escribiendo pruebas.\n";
print "  ⚠️ «Tiene caso» = el ID aparece en su banco. No dice que el caso sea\n";
print "     bueno ni que se haya visto en ROJO. Es el suelo, no el techo.\n";
exit 0;
