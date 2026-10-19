# datitles

Créditos finales para DaVinci Resolve que suben de abajo hacia arriba: título grande en rojo,
roles y nombres a dos columnas alrededor del centro y departamentos en mono espaciada. Escribes
los créditos como texto, sueltas el título en la línea de tiempo y el rollo dura lo que dure el
clip.

![Un cuadro de créditos hecho con datitles](docs/preview.png)

## qué trae

- `Fuses/datitles.fuse`: el Fuse que acomoda y dibuja los créditos.
- `Templates/Edit/Titles/datitles.setting`: el título de Fusion para el Edit page.
- `ejemplos/ejemplo.txt`: unos créditos con todas las marcas, para copiar y adaptar.

Es Lua puro (sin DCTL ni OFX), así que corre en Resolve gratis y en Studio.

## instalar

macOS o Linux:

```sh
git clone https://github.com/donutinit/datitles
cd datitles
./install.sh
```

En Windows copia los dos archivos a mano dentro de
`%APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\`:

- `Fuses\datitles.fuse` a `Fuses\`
- `Templates\Edit\Titles\datitles.setting` a `Templates\Edit\Titles\`

Reinicia Resolve. El título queda en Effects > Toolbox > Titles > Fusion Titles > datitles.

Usa League Gothic, Newsreader e IBM Plex Mono (las tres en Google Fonts, licencia OFL). Si no las
tienes instaladas, cámbialas en Tipografía.

No va en `.drfx` porque ese paquete solo instala plantillas: el Fuse vive en otra carpeta y no hay
forma documentada de que Resolve lo saque del paquete.

## cómo se escriben los créditos

Todo va en el campo Créditos, una línea por cosa:

| Escribes | Sale |
|---|---|
| `# Título` | título grande en rojo; varias líneas `#` seguidas forman un solo título |
| `## Fin` | cierre en display mediano |
| `Dirección \| Nombre Apellido` | fila a dos columnas: rol a la izquierda, nombre a la derecha |
| `\| Nombre Apellido` | solo el nombre, en la columna derecha |
| `Fotografía e iluminación` | línea centrada en mono, para departamentos y notas |
| línea vacía | separa bloques |

```
# Título
# de la película

Dirección | Nombre Apellido
Guion | Nombre Apellido

Fotografía e iluminación
Dirección de fotografía | Nombre Apellido
Data manager | Nombre Apellido

## Fin

Ciudad, País
```

Los roles y nombres largos parten línea dentro de su columna.

## controles

- **Animación.** Con "Todo el clip" el rollo entra por abajo en el primer cuadro y sale por arriba
  en el último: para ir más lento, alarga el clip. Con "Manual" manda el slider Progreso (0 a 1),
  que puedes animar con keyframes.
- **Tipografía.** Las tres fuentes, cada una con su estilo.
- **Medidas.** El texto se mide en porcentaje del alto del cuadro y todo lo demás en múltiplos
  del texto, así que al cambiar el tamaño se escala todo junto.
- **Colores.** Fondo, título, nombres y cierre, roles y mono. Apaga "Fondo sólido" para usar los
  créditos encima de otro clip.

Para un ritmo de lectura cómodo (unas dos filas por segundo), el Fuse escribe en la consola
(Workspace > Console) cuántos segundos debería durar el clip.

## probar sin Resolve

`dev/preview` simula la parte de la API de Fusion que usa el Fuse: revisa que el `.setting` cuadre
con el Fuse, lo corre con LuaJIT y dibuja algunos cuadros en PNG con las fuentes instaladas.
Necesita `luajit`, Python con Pillow y `fc-match`.

```sh
dev/preview -t ejemplos/ejemplo.txt -s 45
```

El simulador no reemplaza a Resolve: confirma la maqueta y que las llamadas sigan los ejemplos
del Fuse SDK, no cómo se comporta Fusion de verdad.

## estado

Versión 0.1. Probada con el simulador; falta probarla a fondo en Resolve. Si algo no se ve bien,
abre un issue con tu versión de Resolve y una captura.

## in English

datitles is a DaVinci Resolve Fusion title that renders a rolling end-credits crawl from plain
text (`Role | Name`, `# Title`, `## Closing`, plain lines for departments). It ships as a Lua Fuse
plus an Edit page title template; run `./install.sh` on macOS or Linux, or copy both files into
your Fusion folder on Windows. Works on the free version.

## licencia

[AGPL-3.0-only](LICENSE). Copyright (C) 2026 Von Diego.
