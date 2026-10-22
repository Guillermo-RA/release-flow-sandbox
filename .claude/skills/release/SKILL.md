---
name: release
description: Prepara y publica releases del proyecto siguiendo el flujo por hitos. Hay un release candidate para staging, la release final para producción, el hotfix y el rollback. Solo bajo petición explícita del usuario.
argument-hint: "rc <vX.Y.Z> | final <vX.Y.Z> | hotfix <vX.Y.Z> | rollback <vX.Y.Z> <entorno> | estado"
disable-model-invocation: true
---

# Release: $ARGUMENTS

Publicar una release **despliega**: un rc va a staging y una final a producción. Antes de cada `gh release create`, `git push` de tags o `gh workflow run`, enséñale al usuario el comando exacto y espera su confirmación.

## estado

```bash
git fetch origin --tags
gh release list --limit 10
git tag --sort=-v:refname | head -10
git log --oneline "$(git describe --tags --abbrev=0 --match 'v*' --exclude '*-rc.*' origin/main)"..origin/main
```
Resume: última versión final, rcs pendientes y lo que hay en `main` sin publicar. Si hay MCP de Atlassian, añade las tareas del siguiente hito (`fixVersion = vX.Y.Z`) que no estén terminadas.

## rc vX.Y.Z

1. Comprueba en Jira (si hay MCP) que las tareas con `fixVersion = vX.Y.Z` están terminadas. Si no, avisa.
2. **Primer rc del hito:** abre un PR `CHORE: prepara release vX.Y.Z` que en `CHANGELOG.md` convierta `## [Unreleased]` en `## [vX.Y.Z] - AAAA-MM-DD` y deje un `## [Unreleased]` vacío encima. Espera a que se mergee.
3. Siguiente número de rc: `git tag -l 'vX.Y.Z-rc.*' --sort=-v:refname | head -1` más uno (o `rc.1`).
4. Crear el rc desde `main` (o desde `release/X.Y.x` si existe para este hito):
   ```bash
   PREV=$(git tag -l 'v*' --sort=-v:refname | grep -v -- '-rc\.' | head -1)
   gh release create vX.Y.Z-rc.N --target main --prerelease --title "vX.Y.Z-rc.N" \
     --notes "$(awk '/^## \[vX.Y.Z\]/{f=1;next} /^## \[/{f=0} f' CHANGELOG.md)" \
     --generate-notes --notes-start-tag "$PREV"
   ```
5. Enlace al workflow Deploy en curso (`gh run list --workflow deploy.yml --limit 1`).

## final vX.Y.Z

Promociona **el mismo commit** del último rc validado en staging. Nunca crees la final desde una rama cuyo HEAD sea distinto al del rc:
```bash
RC=$(git tag -l 'vX.Y.Z-rc.*' --sort=-v:refname | head -1)
PREV=$(git tag -l 'v*' --sort=-v:refname | grep -v -- '-rc\.' | head -1)
gh release create vX.Y.Z --target "$(git rev-list -n 1 "$RC")" --title "vX.Y.Z" \
  --notes "$(awk '/^## \[vX.Y.Z\]/{f=1;next} /^## \[/{f=0} f' CHANGELOG.md)" \
  --generate-notes --notes-start-tag "$PREV"
```
Producción puede requerir aprobación en GitHub (Environment `production`). Avisa al usuario.

## hotfix vX.Y.Z

1. Si `main` no tiene nada sin publicar desde la última final, el hotfix va por el flujo normal: PR a `main`, `rc` y `final`.
2. Si `main` ya tiene trabajo del siguiente hito, crea la rama de mantenimiento si no existe y lleva el fix allí:
   ```bash
   git switch -c release/X.Y.x vX.Y.0   # o la última vX.Y.* publicada
   git push -u origin release/X.Y.x
   ```
   PR del fix contra `release/X.Y.x` y otro PR (o cherry-pick) del mismo fix contra `main`. Después, `rc` y `final` con `--target release/X.Y.x`. En las notas, `--notes-start-tag` debe ser la versión anterior **de esa misma línea** (`vX.Y.(Z-1)`), no la última publicada. Si ya existe una versión mayor publicada, añade `--latest=false`.

## rollback vX.Y.Z entorno

Volver atrás es desplegar una versión ya publicada. No se borra ni se edita ninguna release:
```bash
gh workflow run deploy.yml -f version=vX.Y.Z -f environment=production
gh run watch "$(gh run list --workflow deploy.yml --limit 1 --json databaseId -q '.[0].databaseId')"
```
Antes, comprueba con `git diff vX.Y.Z <versión-actual> -- database/migrations` si alguna migración intermedia rompe la compatibilidad, y avisa si es así. Después recuerda al usuario abrir una tarea en Jira para el fallo y arreglarlo hacia delante con un parche (`vX.Y.Z+1`).
