# datitles: guía para agentes

Créditos finales para DaVinci Resolve: un Fuse de Lua (`Fuses/datitles.fuse`) que maqueta y dibuja
el rollo, y el título de Edit page que lo envuelve (`Templates/Edit/Titles/datitles.setting`).
Repo público, AGPL-3.0-only. `AGENTS.md` es el archivo canónico y
`CLAUDE.md` es un hard link.

## reglas

- Fusion corre LuaJIT (Lua 5.1): nada de `//`, `utf8.*`, `goto` ni `string.pack`.
- En lizeth no hay Resolve. Valida cada cambio con el simulador y mira los PNG:

  ```sh
  DATITLES_PYTHON=~/ml/envs/vision/bin/python dev/preview -t ejemplos/ejemplo.txt -s 45
  ```

  Los PNG quedan en `~/.cache/datitles/preview` (no en `/tmp`, que vive en RAM). El simulador
  prueba la maqueta y el `.setting`, no la API real: las llamadas de dibujo siguen `drawstring`
  del Example 6 del Fuse SDK. Lo que dependa de Fusion de verdad se lo pides a Diego en Resolve.
- Si agregas, quitas o reordenas una entrada del Fuse, actualiza el `.setting` (orden, `Default`
  y grupos plegables). `dev/preview` falla si no cuadran.
- El texto por omisión vive en dos lados (`DEFAULT_TEXT` del Fuse y `Credits` del `.setting`) y
  tienen que ser iguales; el simulador lo revisa.
- El repo no nombra proyectos, películas ni personas reales: los ejemplos usan "Nombre Apellido".
- Textos en español sin rayas largas ni medias y con comillas rectas.
- Commits en español, de una línea, sin trailers.
