---
name: client-site
description: TODO el trabajo web nuestro y de cliente, en cuatro caminos. (1) HACER una web - migrarla (Lovable, WordPress, lo que sea) o construirla de cero. (2) MEJORAR una web que ya existe y es nuestra - arreglar defectos, rediseno, auditoria. (3) ANADIR PAGINAS a una web ya publicada - landing, guia, comparativa, ficha, ciudad. (4) ITERAR SEO o DISENO en una web viva. Usar SIEMPRE que se toque una web - tambien para una sola pagina o un solo arreglo - y cuando alguien pregunte que cuesta una web, por que una pagina no convierte o no rankea, o si una web cumple el estandar. Incluye los gates que lo verifican (maqueta, densidad, CPL, enlazado, rendimiento, accesibilidad, medicion) y la puerta de despliegue.
---

# Web de cliente · Web Quality System

> **Esta carpeta ES el repositorio publico.** No hay una copia interna y otra publicada:
> es la misma. https://github.com/Manucliment/climentmedia-web-quality-system
>
> Antes habia dos —esta skill en castellano y el repo en ingles— y divergian: el falso
> positivo de `MED-05` hubo que arreglarlo **dos veces, a mano**, una en cada copia, el
> mismo dia. Ahora hay una. **Lo que se commitee aqui es publico**, asi que nada de
> nombres de cliente, rutas de esta maquina ni capturas de webs ajenas.

## 🔴 EMPIEZA AQUI: cuatro trabajos, cuatro caminos

**No leas los 18 documentos de `blueprint/`.** Abre el camino de tu trabajo y el te dice
que abrir, cuando. Cada paso lleva: que se hace · el comando · el gate que lo cierra · que
se rompe si te lo saltas.

| Tu trabajo | Camino |
|---|---|
| **Hacer una web** (migrar o de cero) | [`paths/1-new-site.md`](paths/1-new-site.md) |
| **Mejorar una web que ya es nuestra** | [`paths/2-improve-site.md`](paths/2-improve-site.md) |
| **Anadir una pagina** a una web publicada | [`paths/3-add-page.md`](paths/3-add-page.md) |
| **Iterar SEO o diseno** en una web viva | [`paths/4-iterate-seo-design.md`](paths/4-iterate-seo-design.md) |

**Por que existen** (medido, 10-ago-2026): de 256 reglas del estandar, **102 no tenian
ningun gate** y **106 no se habian comprobado nunca en ninguna web**. En las reglas que YA
existian mientras se trabajaba una web el incumplimiento es del **44%**, frente al **59%**
de las escritas despues. **Tener la regla escrita delante mejora el cumplimiento quince
puntos y nada mas.** Por eso el entregable no es documentacion: es un camino, una matriz
generada y una puerta que no se abre sin recibo.

## Los dos momentos que no son opcionales

```bash
perl gates/qa-master.pl <URL> --repo DIR --candidate
```

```bash
bash gates/deploy.sh <REPO> --upload
```

El primero mide **el arbol que vas a subir** y escribe el recibo. El segundo es la puerta:
sin recibo valido no llega a la linea que sube, y despues comprueba que **lo servido es lo
medido**. Ninguno sustituye al otro — sin `--candidate` mides *produccion*, y el recibo
sella entonces un arbol cuyo veredicto salio de medir otra cosa.

## Donde esta cada cosa

| | |
|---|---|
| `paths/` | los cuatro caminos. **Se empieza aqui.** |
| `blueprint/` | el metodo, 18 documentos de consulta |
| `gates/` | 37 programas y sus bancos · empieza por [`gates/README.md`](gates/README.md) |
| `docs/traps.md` | el registro de trampas · **leelo antes de depurar nada** |
| `checklists/` | el QA que cierra un proyecto y el sprint de pagina |
| `CLAUDE.md` | como conducir esto siendo un agente: las cinco reglas |

## Las 3 reglas que mandan

1. **Su codigo manda.** Si el cliente da su repo, se lee ANTES de mirar una captura. La web
   publicada sirve para comparar el resultado, no para deducir el original: **miente por
   omision**.
2. **Nunca reportes una medida que no has tomado.** Una consulta al DOM no es mirar. Si no
   pudiste medirlo, la linea dice `NO MEDIDO` con el motivo — **una linea que falta se lee
   como un aprobado**.
3. **Sospecha del instrumento antes que del sitio.** De 110 defectos documentados aqui,
   **41 eran del instrumento**. Si un barrido dice que varias cosas estan rotas a la vez,
   el sospechoso es el barrido.

## Correr los gates

```bash
bash gates/run-all.sh --fast
```

Lee las tres ultimas lineas: el total, y **que bancos NO se han medido**. `NO MEDIDO` no es
un aprobado, y el runner los nombra para que un hueco no pueda ser silencioso.
