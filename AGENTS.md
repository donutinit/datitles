# datitles: guía para agentes

Títulos para DaVinci Resolve: créditos que suben, tarjetas de inicio, cintillos y un efecto de
película. Los títulos son Fuses de Lua envueltos en plantillas de Fusion para el Edit page; la
película es una plantilla hecha solo con nodos de Fusion. Repo público, AGPL-3.0-only. `AGENTS.md`
es el archivo canónico y `CLAUDE.md` es un hard link.

## dónde está cada cosa

- `src/`: el código de los Fuses. `src/comun.lua` es lo compartido; `src/creditos.lua` y
  `src/cintillo.lua` son cada Fuse, con una línea `-- @comun` donde va lo compartido.
- `Fuses/`: los Fuses que arma `dev/build` desde `src/`. No se editan a mano.
- `Templates/Edit/Titles/Datitles/`: los títulos (créditos, inicio, clásico, papel y cintillo).
- `Templates/Edit/Effects/Datitles/`: la película.

## reglas

- Fusion corre LuaJIT (Lua 5.1): nada de `//`, `utf8.*`, `goto` ni `string.pack`.
- Si cambias algo en `src/`, corre `dev/build`. `dev/preview` falla si un Fuse no está al día.
- En lizeth no hay Resolve. Valida cada cambio con el simulador y mira los PNG:

  ```sh
  dev/preview -t ejemplos/ejemplo.txt -s 45
  dev/preview -p inicio -t ejemplos/inicio.txt -s 36
  dev/preview -p cintillo -s 5 -v "Name=Nombre Apellido" -v Role=Dirección 60
  dev/preview -p pelicula -s 10 120
  ```

  Los PNG quedan en `~/.cache/datitles/preview` (no en `/tmp`, que vive en RAM). `-p` elige la
  plantilla y `-v ID=VALOR` cambia una entrada sin tocarla. Usa el `python3` del sistema, con
  Pillow y numpy; otro con `DATITLES_PYTHON`. El simulador prueba la maqueta y las plantillas, no
  la API real: las llamadas de dibujo siguen `drawstring` del Example 6 del Fuse SDK y la película
  se aproxima con numpy. Lo que dependa de Fusion de verdad se lo pides a Diego en Resolve.
- `dev/preview` revisa todas las plantillas cada vez. Una plantilla publica entradas que existen,
  en el orden del Fuse, con su `Default` igual al valor que la plantilla le pone o, si no le pone
  ninguno, al del Fuse. Lo que no publica necesita valor en la plantilla o ir dentro de un grupo
  plegable que tampoco publica. Si agregas, quitas o reordenas una entrada de un Fuse, actualiza
  todas sus plantillas.
- Una entrada nueva lleva un valor por omisión que deje igual lo que ya había: los proyectos
  viejos la reciben así.
- El id con que se registra un Fuse (`datitles`, `datitles_cintillo`) no cambia: las líneas de
  tiempo lo guardan.
- El texto por omisión de los créditos vive en dos lados (`DEFAULT_TEXT` de `src/creditos.lua` y
  `Credits` de `datitles creditos.setting`) y tienen que ser iguales; el simulador lo revisa. Las
  demás plantillas pueden traer su propio texto.
- Las fuentes de las plantillas son libres (OFL) y tienen que estar instaladas en lizeth:
  `dev/metrics.py` falla si `fc-match` devuelve otra.
- El repo no nombra proyectos, películas ni personas reales: los ejemplos usan "Nombre Apellido".
- Nombres de archivo sin acentos: macOS y Linux los guardan distinto y git los ve como dos.
- Textos en español sin rayas largas ni medias y con comillas rectas.
- Commits en español, de una línea, sin trailers.
