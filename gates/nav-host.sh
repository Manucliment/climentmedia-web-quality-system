# =============================================================================
#  nav-host.sh  ·  de donde sale el host de medida  (se CARGA con `.`, no se corre)
# =============================================================================
#  El host de medida es el servidor Linux desde el que se abren las webs con
#  Chrome: alli `--window-size` se respeta, y en Windows no (baja a ~500 px).
#  Es un dato de la MAQUINA que corre esto, no de la web ni del repo, y en un
#  repo publico no puede ir escrito.
#
#  🔴 POR QUE ESTE FICHERO EXISTE (21-sep-2026)
#  Al anonimizar el repo el nombre real se cambio por el marcador `example-host`
#  en CUATRO sitios, cada uno con su lectura escrita a mano: el paso 6 de
#  deploy.sh y los bancos de densidad, movil y formulario. Ninguno llegaba a
#  ninguna parte y los cuatro lo decian como un fallo de red:
#    · la puerta: 77 despliegues (26-ago a 17-sep) sin medir lo servido;
#    · los tres bancos: NO MEDIDO en cada bateria, asi que el verde de
#      `run-all.sh` no llevaba dentro ni una medida en el servidor.
#  Se arreglo primero la puerta sola y los bancos siguieron igual: un arreglo
#  que no sale del sitio donde se encontro. Por eso la lectura vive AQUI, una
#  vez, y todos la cargan.
#
#  ORDEN, de mas especifico a menos:
#    1) NAV_HOST (o BROWSER_HOST, el nombre de la plantilla en ingles), del
#       entorno o del deploy.conf de la web que ya se haya cargado;
#    2) la linea NAV_HOST=... de config/nav-host.local.conf -- fuera de git por
#       `*.conf`, igual que leak-terms.local.conf. NAV_HOST_CONF cambia la ruta
#       (los bancos la usan para no leer la configuracion de quien los corre);
#    3) nada. Quien llama dice «NAV_HOST sin configurar» y NO intenta ningun
#       host: un marcador que «no conecta» se lee como red, y es configuracion.
#
#  ⚠️ El fichero local se escribe a mano, y el Bloc de notas lo guarda con
#     finales CRLF. Sin el `tr -d '\r'` el host llega con un retorno de carro
#     pegado, `ssh` no lo encuentra y el mensaje lo esconde (es invisible).
#
#  ⚠️ Sin `BASH_SOURCE`: dos de los bancos que lo cargan empiezan por #!/bin/sh.
#     Por eso quien llama pasa la carpeta gates/ como argumento.
#
#     uso:   . "$REF/nav-host.sh"
#            HOST="$(nav_host "$REF")"
#            [ -n "$HOST" ] || { echo "NO MEDIDO: NAV_HOST sin configurar"; ... }
#            echo "leido de: $(nav_host_conf "$REF")"
# =============================================================================

nav_host_conf() {   # <carpeta gates/>  ->  la ruta del fichero local que se lee
  printf '%s' "${NAV_HOST_CONF:-$1/config/nav-host.local.conf}"
}

nav_host() {        # <carpeta gates/>  ->  el host, o nada
  _nh="${NAV_HOST:-${BROWSER_HOST:-}}"
  _nh_conf="$(nav_host_conf "$1")"
  if [ -z "$_nh" ] && [ -f "$_nh_conf" ]; then
    _nh="$(tr -d '\r' < "$_nh_conf" | tr '\t' ' ' \
           | sed -n "s/^NAV_HOST=[\"']\{0,1\}\([^\"' ]*\).*/\1/p" | head -1)"
  fi
  printf '%s' "$_nh"
}
