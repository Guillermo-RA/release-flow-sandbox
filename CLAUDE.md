# <Nombre del proyecto>

<Una o dos frases: qué es el proyecto y para quién.>

<!-- flujo-releases:inicio -->
## Flujo de trabajo: hitos, releases y despliegues

### Datos del proyecto
- Jira: proyecto <KEY> en https://10code.atlassian.net. Cada tarea está en https://10code.atlassian.net/browse/<KEY>-123.
- Staging: <url-staging>. Producción: <url-produccion>.
- Stack: Laravel + Inertia (<React | Vue>) en Docker. El workflow de despliegue es .github/workflows/deploy.yml (hecho a partir de la plantilla deploy-inertia.yml).
- Tests y linters (los de 10code-inertia-template; ajustar si cambian):
  - vendor/bin/pest
  - vendor/bin/pint --test
  - vendor/bin/phpstan analyse
  - vendor/bin/rector --dry-run
  - npm run test:lint
  - npm run test:types

### Modelo
- **Hito de Jira = Fix Version = GitHub Release**, todos con el mismo nombre en formato SemVer: vX.Y.Z.
  - Un hito nuevo sube el MENOR (v1.4.0).
  - Un hotfix sube el PARCHE (v1.4.1).
  - Un BREAKING CHANGE sube el MAYOR (v2.0.0).
- **Hacer push a una rama nunca despliega.** Solo despliegan las releases:
  - Una pre-release vX.Y.Z-rc.N (release candidate, "versión candidata") se despliega en **staging**.
  - Una release vX.Y.Z se despliega en **producción**. Tiene que estar exactamente en el commit de un rc ya validado; el workflow lo comprueba.
  - **Rollback:** consiste en volver a desplegar una versión anterior ya publicada, lanzando el workflow Deploy a mano con esa versión y el entorno. Se hace con /release rollback. Si la versión sigue en el servidor o en el registro de imágenes, no se recompila.
- **Ramas:**
  - main es la única rama larga.
  - El trabajo va en ramas cortas llamadas tipo/<KEY>-123-descripcion. El tipo es feat, fix, hotfix, chore, refactor o docs.
  - Cada rama → PR a main → squash merge.
  - Las ramas release/X.Y.x solo se crean para estabilizar un hito, o para un hotfix mientras main ya lleva trabajo del hito siguiente.
- **Commits y título del PR:** formato "PREFIJO:#<KEY>-123: descripción", con los prefijos FEAT, FIX, HOTFIX, REFACTOR, DOCS, TEST o CHORE. La clave de Jira es obligatoria: así GitHub for Jira enlaza ramas, PRs y despliegues con la tarea.

### Reglas para Claude
- **Cuando te pidan hacer una tarea** a partir de una clave de Jira ("haz la tarea <KEY>-123"), usa la skill /empezar-tarea. La skill:
  1. lee la tarea, sus comentarios, las tareas enlazadas y las páginas de Confluence que enlace;
  2. resume lo que ha entendido y pregunta las dudas importantes antes de escribir código;
  3. crea la rama desde la base correcta;
  4. implementa la tarea y termina con /cerrar-tarea.
- **Al terminar una tarea**, usa la skill /cerrar-tarea. Hace esto:
  1. Comprueba que los tests y linters pasan.
  2. Anota el cambio en los changelogs, en la sección [Unreleased] (o en la del hito en estabilización, si es una corrección de ese hito):
     - CHANGELOG-INTERNO.md, siempre: una línea técnica por PR, incluidos refactors, dependencias, CI, tests y documentación.
     - CHANGELOG.md, solo si el cambio es visible para quien usa el producto: una línea escrita para el usuario, con las categorías de Keep a Changelog (Añadido, Cambiado, Corregido, Eliminado, Migraciones, Seguridad).
     - Cada línea termina con el enlace a la tarea de Jira.
  3. Abre el PR con la plantilla .github/pull_request_template.md rellena del todo y con una label: feature, bug, hotfix, chore o breaking-change. Si hay migraciones, añade también la label migration. Las notas de la release se agrupan por esas labels; los PRs con label chore no aparecen en ellas.
- **No crees tags, releases ni despliegues** salvo que el usuario lo pida expresamente. Para eso está la skill /release, que siempre enseña el comando y espera confirmación.
- No modifiques .github/workflows/deploy.yml ni la configuración de entornos salvo que te lo pidan.
- En Jira, no cambies estados ni escribas comentarios salvo que te lo pidan. Leer sí puedes, siempre.

### Compatibilidad con rollback (obligatorio)
El rollback solo devuelve **el código** a una versión anterior. La base de datos, el .env compartido y las colas se quedan como estén. Por eso, cada release tiene que funcionar con el esquema y la configuración de la release siguiente:
- **Migraciones solo aditivas** (técnica expand/contract): tablas nuevas, columnas que admiten vacío o tienen valor por defecto, índices. En el mismo PR está prohibido renombrar o borrar columnas o tablas, o cambiar tipos, que use la versión anterior. Para renombrar o borrar hacen falta tres releases:
  1. Release N: añadir lo nuevo, escribir en lo viejo y en lo nuevo, y migrar los datos.
  2. Release N+1: leer solo lo nuevo.
  3. Release N+2: borrar lo viejo.
- Nunca uses migrate:rollback como forma de deshacer un despliegue.
- Las migraciones de datos deben poder ejecutarse varias veces sin efecto adicional (idempotentes), y el PR lleva la label migration.
- **Variables de entorno nuevas:** con valor por defecto en el código y documentadas en .env.example. La versión anterior tiene que poder arrancar con el .env nuevo.
- **Jobs en cola:** no renombres un Job ni cambies sus parámetros en la misma release en la que deja de existir el anterior, porque puede haber jobs encolados por la otra versión.
- **Inertia:**
  - No sobrescribas el método version() de HandleInertiaRequests. Tiene que seguir devolviendo parent::version(), el hash de los assets de Vite. Es lo que obliga a recargar a los navegadores con assets de otra versión tras un despliegue o un rollback.
  - Inertia no comprueba la versión en los POST: si renombras un campo de un formulario, el backend debe aceptar también el nombre viejo durante una release.
  - Las props de página son el contrato entre Laravel y el frontend. Cámbialas en el mismo PR en los dos lados.
  - Nunca pongas secretos en variables VITE_, porque se incrustan en el JavaScript. Si añades una variable VITE_ nueva, avisa de que hay que añadirla a DOCKER_BUILD_ARGS en los Environments de GitHub.
  - Si añades al docker compose un servicio que ejecute código de la app (workers, SSR, Reverb), debe usar la misma imagen PHP y la misma versión (APP_VERSION) que el resto.
- **Versión desplegada.** Es la que se muestra y la que se envía a Sentry como release, nunca el identificador del commit:
  - Backend: variable APP_VERSION, accesible como config('app.version') y compartida con el frontend como prop appVersion.
  - Frontend: import.meta.env.VITE_APP_VERSION.
  - Proyectos sin Docker: el fichero VERSION de la release, o NEXT_PUBLIC_APP_VERSION en Next.js.

### Jira desde Claude Code
Con el MCP de Atlassian conectado:
- Se puede leer cualquier tarea solo con su clave (herramienta getJiraIssue).
- Se pueden buscar las tareas de un hito con JQL. Por ejemplo, las pendientes de v1.4.0: fixVersion = v1.4.0 AND statusCategory != Done.

El proyecto incluye el fichero .mcp.json con el servidor atlassian. La primera vez, ejecuta /mcp en Claude Code e inicia sesión con tu cuenta de Atlassian.
<!-- flujo-releases:fin -->
