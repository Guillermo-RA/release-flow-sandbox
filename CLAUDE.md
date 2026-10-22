# release-flow-sandbox

App de prueba: `build.sh` genera `dist/index.html` a partir de `app/greeting.txt`.

## Flujo de trabajo: hitos, releases y despliegues

### Datos del proyecto
- Jira: proyecto `SANDBOX` en https://10code.atlassian.net (tareas: `https://10code.atlassian.net/browse/SANDBOX-123`)
- Staging: (local) · Producción: (local)
- Workflow de despliegue: `.github/workflows/deploy.yml` (sandbox)
- Tests y linters: `./build.sh`

### Modelo
- **Hito de Jira = Fix Version = GitHub Release**, todos con el mismo nombre SemVer: `vX.Y.Z`.
  - Hito nuevo → sube el *minor* (`v1.4.0`). Hotfix → sube el *patch* (`v1.4.1`). `BREAKING CHANGE` → sube el *major*.
- **Hacer push a una rama nunca despliega.** Solo despliegan las releases:
  - Pre-release `vX.Y.Z-rc.N` → **staging**
  - Release `vX.Y.Z` → **producción**. Tiene que ser exactamente el commit de un rc ya validado; el workflow lo comprueba.
  - **Rollback** = volver a desplegar una versión anterior ya publicada: `gh workflow run deploy.yml -f version=vX.Y.Z -f environment=production`. No se recompila si la versión sigue en el servidor o en el registry.
- **Ramas:** `main` es la única rama larga. El trabajo va en ramas cortas `<tipo>/SANDBOX-123-slug` (`feat`, `fix`, `hotfix`, `chore`, `refactor`, `docs`) → PR a `main` → squash merge. `release/X.Y.x` solo se crea para estabilizar un hito o para un hotfix mientras `main` ya lleva trabajo del siguiente.
- Commits y título del PR: `PREFIJO:#SANDBOX-123: descripción` (FEAT, FIX, HOTFIX, REFACTOR, DOCS, TEST, CHORE). La clave de Jira es obligatoria: así GitHub for Jira enlaza ramas, PRs y despliegues con la tarea.

### Reglas para Claude
- **Al empezar una tarea** a partir de una clave Jira, usa la skill `/empezar-tarea SANDBOX-123`: lee la tarea con el MCP de Atlassian y crea la rama desde la base correcta.
- **Al terminar una tarea**, usa la skill `/cerrar-tarea`. Hace esto:
  1. Tests y linters en verde.
  2. Añade el cambio a `CHANGELOG.md` en `## [Unreleased]`, o en la sección del hito en estabilización si es una corrección de ese hito. Formato Keep a Changelog con las categorías Añadido / Cambiado / Corregido / Eliminado / Migraciones / Seguridad. Una línea por cambio visible, escrita para quien usa el producto, terminada en `([SANDBOX-123](https://10code.atlassian.net/browse/SANDBOX-123))`. Los cambios internos no van.
  3. Abre el PR con `.github/pull_request_template.md` rellena del todo y una label: `feature`, `bug`, `hotfix`, `chore` o `breaking-change`, más `migration` si hay migraciones. Las notas de la release se agrupan por esas labels.
- **No crees tags, releases ni despliegues** (`gh release create`, `git push --tags`, `gh workflow run deploy.yml`) salvo que el usuario lo pida expresamente. Para eso está `/release`, que siempre enseña el comando y espera confirmación.
- No modifiques `.github/workflows/deploy.yml` ni la configuración de entornos salvo que te lo pidan.
- No cambies estados ni escribas comentarios en Jira salvo que te lo pidan. Leer sí puedes, siempre.

### Compatibilidad con rollback (obligatorio)
El rollback solo devuelve **el código** a una versión anterior. La base de datos, el `.env` compartido y las colas se quedan como estén. Por eso, cada release tiene que funcionar con el esquema y la configuración de la release siguiente:
- **Migraciones solo aditivas** (*expand/contract*): tablas nuevas, columnas nullable o con default, índices. Prohibido en el mismo PR renombrar o borrar columnas o tablas, o cambiar tipos, que use la versión anterior. Para renombrar o borrar:
  1. Release N: añadir lo nuevo, escribir en ambos y migrar datos.
  2. Release N+1: leer solo lo nuevo.
  3. Release N+2: borrar lo viejo.
- Nunca uses `migrate:rollback` como forma de deshacer un despliegue.
- Las migraciones de datos deben ser idempotentes, y el PR lleva la label `migration`.
- **Variables de entorno nuevas** con valor por defecto en el código y documentadas en `.env.example`. La versión anterior tiene que poder arrancar con el `.env` nuevo.
- **Jobs en cola:** no renombres ni cambies la firma de un Job en el mismo release en el que deja de existir el anterior. Puede haber jobs encolados por la otra versión.
- La versión desplegada está en el fichero `VERSION` de la raíz de la release (Laravel) o en `NEXT_PUBLIC_APP_VERSION` (Next.js). Para mostrarla o enviarla a Sentry, usa eso y no el SHA.

### Jira desde Claude Code
Con el MCP de Atlassian conectado, se puede leer cualquier tarea solo con su clave (`getJiraIssue`) o buscar por hito con JQL (`fixVersion = vX.Y.Z AND statusCategory != Done`). El proyecto incluye `.mcp.json` con el servidor `atlassian`. La primera vez, ejecuta `/mcp` en Claude Code y autentícate con tu cuenta de Atlassian.
