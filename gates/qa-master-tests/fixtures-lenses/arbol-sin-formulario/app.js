/* Como el sitio no tiene ni un <form>, toda su conversion son clics salientes. */
function copiar(text) {
  var ta = document.createElement("textarea");
  ta.value = text;
  ta.setAttribute("readonly", "");
  document.body.appendChild(ta); ta.select(); document.execCommand("copy"); ta.remove();
}
