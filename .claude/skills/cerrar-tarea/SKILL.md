---
name: cerrar-tarea
description: Cierra la tarea en curso. Verifica tests y linters, anota el cambio en CHANGELOG.md, hace commit con el formato del proyecto y abre el PR con la plantilla rellena y la label correcta. Usar cuando el usuario diga "cierra la tarea", "abre el PR", "termina esto" o al acabar el trabajo de una tarea Jira.
argument-hint: "[CLAVE-JIRA]"
---

# Cerrar tarea $ARGUMENTS

1. **Contexto.** Clave Jira: la del argumento o, si no, la del nombre de la rama (`feat/OGOV-123-…`). Si tienes el MCP de Atlassian, relee la tarea para comprobar que se cumplen los criterios de aceptación y para conocer su Fix Version (hito).

2. **Verificar.** Ejecuta los tests y linters del proyecto (ver CLAUDE.md). Si algo falla, arréglalo o informa al usuario y para. No abras un PR en rojo sin decirlo.

3. **Revisar la compatibilidad con rollback** del diff (`git diff origin/main...HEAD`):
   - ¿Hay migraciones? Solo pueden **añadir** (tablas, columnas nullable o con default, índices). Si renombran, borran o cambian el tipo de algo que usa la versión anterior, para y propón dividirlas (expand/contract, ver CLAUDE.md).
   - ¿Hay variables de entorno nuevas? Necesitan valor por defecto y estar en `.env.example`.

4. **CHANGELOG.md.** Añade una línea por cada cambio visible en la sección correcta:
   - Normalmente en `## [Unreleased]`.
   - Si la tarea es una corrección del hito en estabilización (ya tiene sección `## [vX.Y.Z]` sin publicar como release final), va en esa sección.
   - Categoría: `Añadido`, `Cambiado`, `Corregido`, `Eliminado`, `Migraciones` o `Seguridad`. Crea el encabezado `###` si no existe.
   - Escribe para quien usa el producto, no para quien lee el código, y termina con el enlace: `([OGOV-123](https://10code.atlassian.net/browse/OGOV-123))`.
   - Los cambios puramente internos (refactor, tests, CI) no van al CHANGELOG.

5. **Commit** con el formato del proyecto: `PREFIJO:#CLAVE: descripción` (p. ej. `FIX:#OGOV-123: corrige el import de catálogos sin entity name`). Prefijos: FEAT, FIX, HOTFIX, REFACTOR, DOCS, TEST, CHORE. Añade `BREAKING CHANGE` al final del cuerpo si aplica.

6. **PR.** Push de la rama y PR contra `main`, o contra `release/X.Y.x` si es un hotfix. Usa la plantilla `.github/pull_request_template.md` **rellena del todo** (borra los comentarios `<!-- -->` y marca las casillas que correspondan):
   ```bash
   git push -u origin HEAD
   gh pr create --base main --title "FIX:#OGOV-123: …" --body-file <fichero-temporal> --label bug
   ```
   Label según el tipo: `feature`, `bug`, `hotfix`, `chore` o `breaking-change`. Añade también `migration` si hay migraciones. Si una label no existe en el repo, créala con `gh label create`.

7. **Informar** al usuario con el enlace al PR y lo que no hayas podido verificar. No comentes en Jira ni cambies el estado de la tarea salvo que te lo pida.
