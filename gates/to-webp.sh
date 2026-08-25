#!/usr/bin/env bash
# =============================================================================
#  to-webp.sh - convierte las imagenes del sitio a WebP y las redimensiona
# =============================================================================
#  POR QUE EXISTE:
#  Su portada pide 7,17 MB, y 6,99 MB son diez JPG. Una de sus imagenes mide
#  7900x5267 (41 megapixeles) para mostrarse a 820 px de ancho: Chrome headless
#  ni la pinta a tiempo, y en un movil real pasa lo mismo.
#
#  En esta maquina no hay ImageMagick, ni cwebp, ni Pillow, ni sharp.
#  SI hay ffmpeg con libwebp, y hace las dos cosas de una pasada.
#
#  Emite tambien un JSON con las dimensiones NUEVAS: el generador las necesita
#  para reservar el hueco. Una dimension inventada desplaza el layout igual que
#  ninguna, solo que en otra direccion.
# =============================================================================
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

ORIGEN="${1:-assets/media}"
DESTINO="${2:-assets/img}"
ANCHO_MAX="${3:-1600}"
CALIDAD="${4:-80}"

command -v ffmpeg >/dev/null || { echo "falta ffmpeg"; exit 1; }
mkdir -p "$DESTINO"

antes=0; despues=0; n=0; fallos=0
echo "[" > /tmp/dims.json
primero=1

for f in "$ORIGEN"/*; do
  [ -f "$f" ] || continue
  nombre=$(basename "$f")
  base="${nombre%.*}"
  ext="${nombre##*.}"
  case "$(printf '%s' "$ext" | tr 'A-Z' 'a-z')" in
    jpg|jpeg|png) ;;
    *) continue ;;
  esac

  # dimensiones de origen
  wh=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height \
       -of csv=s=x:p=0 "$f" 2>/dev/null)
  w0="${wh%x*}"; h0="${wh#*x}"
  [ -z "$w0" ] && { echo "  ?? no se puede leer $nombre"; fallos=$((fallos+1)); continue; }

  # solo se reduce, nunca se agranda
  if [ "$w0" -gt "$ANCHO_MAX" ]; then
    filtro="scale=$ANCHO_MAX:-2"
    w1=$ANCHO_MAX
    h1=$(( h0 * ANCHO_MAX / w0 ))
    h1=$(( h1 - h1 % 2 ))
  else
    filtro="scale=iw:ih"
    w1=$w0; h1=$h0
  fi

  salida="$DESTINO/$base.webp"
  if ffmpeg -hide_banner -loglevel error -y -i "$f" -vf "$filtro" \
       -c:v libwebp -quality "$CALIDAD" -compression_level 6 "$salida" 2>/dev/null; then
    a=$(wc -c < "$f"); d=$(wc -c < "$salida")
    antes=$((antes+a)); despues=$((despues+d)); n=$((n+1))
    [ $primero -eq 0 ] && echo "," >> /tmp/dims.json
    primero=0
    printf '{"orig":"%s","webp":"%s","w":%s,"h":%s,"antes":%s,"despues":%s}' \
      "$nombre" "$base.webp" "$w1" "$h1" "$a" "$d" >> /tmp/dims.json
    printf '  %-52s %6sK -> %5sK  %sx%s\n' "$base.webp" $((a/1024)) $((d/1024)) "$w1" "$h1"
  else
    echo "  FALLO $nombre"; fallos=$((fallos+1))
  fi
done

echo "]" >> /tmp/dims.json
cp /tmp/dims.json _spec/imagenes.json

echo
echo "  convertidas : $n    fallos: $fallos"
printf '  antes       : %s MB\n' "$(echo "scale=1; $antes/1048576" | bc)"
printf '  despues     : %s MB\n' "$(echo "scale=1; $despues/1048576" | bc)"
if [ "$antes" -gt 0 ]; then
  printf '  reduccion   : %s%%\n' "$(( 100 - despues * 100 / antes ))"
fi
