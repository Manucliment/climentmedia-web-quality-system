/* FIXTURE. La cara CONTRARIA del de al lado: la politica nombra a Meta y aqui NO
   se carga ningun pixel, ni desde el contenedor ni desde este fichero.

   Es el caso para el que existe MED-07b -"una politica que sobra tambien es una
   politica falsa, y se audita igual"- y esta aqui por un motivo concreto: al
   ensanchar MED-07 el 8-sep-2026 para que mire tambien el JavaScript del propio
   sitio, lo facil es dejar MED-07b ciego. Este fixture exige que siga viendo. */
document.querySelector("form").addEventListener("submit", function (e) {
  e.target.querySelector("button").disabled = true;
});
