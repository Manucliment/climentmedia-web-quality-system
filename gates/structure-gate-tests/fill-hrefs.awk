# Sustituye los href="#" de placeholder por destinos reales, rotando la lista.
# Se hace con index()/substr(), NO con sub()/gsub(): en awk el & del reemplazo
# tambien significa "lo que caso" y esta pagina esta llena de entidades HTML.
#
# 🔴 SOLO DENTRO DE <main>. Antes sustituia en TODO el fichero, y los <style> de
#    los moldes llevan comentarios que citan `href="#"` como texto. Ese comentario
#    se comia el primer destino de la rotacion (/contacto/), asi que las DOS
#    acciones del heroe acababan en /servicios/ y /casos/ — ninguna de conversion.
#    El gate lo cazaba como «HERO que ENLACA, no que convierte», y tenia razon:
#    el defecto era real, solo que lo habia metido el generador, no el molde.
#    Restringirlo a <main> arregla las dos cosas: el heroe recibe /contacto/ (que
#    es el primero de la lista) y los comentarios del CSS dejan de reescribirse.
BEGIN{ n=split("/contacto/,/servicios/,/casos/,/precios/,/zonas/,/guia/", D, ",") ; k=0 ; dentro=0 }
/<main[ >]/ { dentro=1 }
/<\/main>/  { print; dentro=0; next }
{
  if (!dentro) { print; next }
  line=$0; out=""
  while ((p = index(line, "href=\"#\"")) > 0) {
    k = k % n + 1
    out = out substr(line, 1, p-1) "href=\"" D[k] "\""
    line = substr(line, p + 8)
  }
  print out line
}
