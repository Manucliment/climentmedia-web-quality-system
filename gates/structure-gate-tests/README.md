# Pruebas de `gate-estructura.js`

Un gate que solo se ha visto en verde no prueba nada. Estos son los controles con
los que se calibro el 10-ago-2026, para poder repetirlos cuando se toque el gate.

## La pareja que importa

`prose-fabricated.html` y `guide-laid-out.html` llevan **los mismos 32 parrafos**,
palabra por palabra. La segunda tiene ademas tabla, acordeon y cierre, o sea
**mas texto** (1810 palabras contra 1401).

| | veredicto | esPaginaProsa |
|---|---|---|
| `prose-fabricated.html` | **FALLA** | **true** |
| `guide-laid-out.html` | **PASA** | false |

Si algun dia las dos dan lo mismo, el gate ha dejado de medir maqueta y esta
midiendo cantidad de texto. Es la unica prueba que hay que mirar siempre.

## Como se corren

```bash
./battery.sh                                   # las 12 comprobaciones a 1440
./run-gate.sh     id fichero.html <base> '{}'  # una suelta, escritorio
./run-gate-390.sh id fichero.html <base> '{}'  # una suelta, 390px REALES
```

`run-gate-390.sh` carga la pagina en un `<iframe width=390>`: Chrome headless en
Windows **clampa `--window-size` a ~500px**, asi que pedir 390 daria un recorte
disfrazado de movil. **Comprobar siempre el `innerWidth` de la salida** antes de
creerse ninguna cifra.

Las paginas reales (climentmedia, site-a, site-c, site-d) se bajan con `curl` y se
miden con `<base href>` para que resuelvan su CSS y para que el gate vea la ruta
y el origen de verdad. **No estan versionadas aqui: cambian** — y por eso
`P2-bcficha`, `P3-bchome` y `F3-privaci` dan `REVISAR` desde el 10-ago-2026 por
reglas VIEJAS sobre HTML NUEVO (verificado reconstruyendo el gate sin los cambios
de ese dia: ya fallaban los tres). Ver el comentario de `battery.sh`.

## Los dos fixtures congelados

`mould-home-broken.html` y `contrast-control.html` **no se regeneran**: son la
prueba de que el gate ve dos fallos que antes no veia.

- **`mould-home-broken.html`** es la home compuesta antes de que los moldes pasaran
  a `_base.css`. Cuatro de sus siete secciones estan a 568px en vez de 1120 y la
  rejilla cae a 173-189px por celda, porque los moldes compartian el nombre
  `.sec__in` y al concatenar sus `<style>` ganaba el ultimo. **El gate la daba por
  buena**: `VEREDICTO: PASA · fallos: [] · cplMediana: null`. Ese `null` era la
  pista — la unica medida de anchura que habia no llegaba a ejecutarse porque
  ningun parrafo suyo alcanza 200 caracteres. Un control positivo que aprueba en
  vacio no calibra el gate, lo exime. Hoy FALLA por `ANCHO-MIN`.
- **`contrast-control.html`** lleva **4 casos que deben fallar y 4 que deben
  pasar** en la misma pagina, con los ratios anotados. Dos estan en `oklch`, que
  es donde `getComputedStyle` devuelve `oklch(...)` en vez de `rgb(...)`: sin
  resolver el color, la regla mediria basura. Dos valores estan contra
  referencias publicadas (`#999999` = 2,85:1 y `#6b7280` = 4,83:1, el gray-500 de
  Tailwind) para que se vea que la aritmetica es la de WCAG y no una mia.

## Los gates de los MOLDES (10-ago-2026)

Estos no juzgan una pagina: juzgan el repertorio de `../moldes/`. Se corren todos
con **una orden**, y cada uno tiene su control negativo.

```bash
bash battery-layout.sh          # los cuatro de abajo, en orden
```

| script | que impide | control negativo |
|---|---|---|
| `chk-collisions.pl` | que dos moldes declaren el mismo selector, que un molde pise el chasis (`.sec`, `.sec__in`, `.btn`…), que declare `:root`/`body`/`h2` global, o que use una clase sin su prefijo `.mNN-` | `fixtures-collision/` — **seis** ficheros, uno por regla (C1..C6). `test-collisions.sh` los corre y comprueba ademas que un molde roto suelto no contamina el positivo |
| `measure-contrast.sh` | que un cambio de color de marca en `_tokens.css` deje texto por debajo de AA sin que nadie se entere | `fixtures-contrast/tenue-de-cliente.html` — un `--tenue` de cliente plausible que **tiene que fallar** |
| `measure-layout.sh` / `-390.sh` | que un molde se salga de su ancho, desborde, o pierda el CPL | el `innerWidth` va impreso el primero: si no es el pedido, la medida se tira |
| `run-gate.sh P1-molde` | que el repertorio bien usado no pase el gate de estructura | es el control positivo de siempre |

**Por que existen.** Los 19 moldes traian cada uno su `<style>` entero, quince
definian `.sec__in` con **cinco anchos distintos**, y al componer ganaba el
ultimo: **33 de los 45 contenedores de las 7 composiciones estaban fuera de su
ancho**, y la home daba 4 de 7 secciones a 568px. Ademas habia **6 elementos por
debajo de AA** en los moldes (peor: 3,04:1) que nadie habia visto, porque el
contraste no se ve mirando. Ninguna de las dos cosas da error: la pagina solo
sale mas estrecha y un poco mas gris.

`layout-summary.pl` convierte los JSON en las tres tablas que se leen:
`anchos` · `contraste` · `cpl`. La sonda es `measure-layout.js`.

## Generadores

`mk-prose.sh`, `mk-guide.sh` y `mk-mould.sh` regeneran los tres ficheros. El
tercero compone una pagina a partir de los moldes de `../moldes/` en el orden que
se le pase por argumento (⚠️ el que traia salia de `10-vocabulario §6`, tabla
**borrada** el 10-ago; la fuente unica es `09-tipos-de-pagina.md §2` y a ese
orden le falta `proceso`/05 — ver la cabecera de `mk-mould.sh`), y
`fill-hrefs.awk` sustituye sus `href="#"`
de plantilla por destinos reales (con `index()`/`substr()`, **no** con `gsub()`:
en awk el `&` del reemplazo tambien significa «lo que caso» y estas paginas
estan llenas de entidades HTML).
