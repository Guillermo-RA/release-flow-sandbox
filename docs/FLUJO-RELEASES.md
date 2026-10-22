# Flujo de trabajo por hitos y releases

**Cada hito de Jira se convierte en una GitHub Release, y cada release en un despliegue.** Hacer push a una rama ya no despliega nada. Volver a una versión estable consiste en desplegar una release anterior, y tarda segundos.

**El recorrido de un hito, de principio a fin:**

1. **Jira:** se crea la Fix Version v1.4.0 y se asignan las tareas.
2. **GitHub:** cada tarea va en su rama (KEY-123) → PR → main.
3. **Pre-release v1.4.0-rc.1** → se despliega sola en **staging**.
4. **QA en staging.** Si hay un bug: se corrige y se publica un nuevo rc (vuelta al paso 3). Si todo está bien: paso 5.
5. **Release v1.4.0**, sobre el mismo commit que el rc aprobado → **producción**, tras aprobación.
6. **Jira:** la versión v1.4.0 se marca como Released.
7. **Si algo falla en producción:** rollback, desplegando de nuevo una versión anterior (por ejemplo, v1.3.2).

## 1. Nombres y equivalencias

| Concepto | Jira | GitHub | Entorno |
|---|---|---|---|
| Hito | Fix Version v1.4.0 | Release v1.4.0 (tag) | Producción |
| Candidata | — | Pre-release v1.4.0-rc.1, v1.4.0-rc.2… | Staging |
| Hotfix | Fix Version v1.4.1 | Release v1.4.1 | Staging → Producción |
| Tarea | KEY-123 | Rama feat/KEY-123-…, PR "FEAT:#KEY-123: …" | — |

**Versionado SemVer** (MAYOR.MENOR.PARCHE):
- Un hito nuevo sube el MENOR: v1.4.0 → v1.5.0.
- Un hotfix sube el PARCHE: v1.4.0 → v1.4.1.
- Un cambio incompatible (BREAKING CHANGE) sube el MAYOR: v1.4.0 → v2.0.0.

## 2. Ciclo de un hito

1. **Planificar en Jira.** En la sección Releases del proyecto se crea la versión v1.4.0, con fecha objetivo, y se pone v1.4.0 en el campo Fix Version de sus tareas.
2. **Desarrollar.** Cada tarea sigue el camino: rama corta desde main → PR a main → revisión → squash merge. Cada PR:
   - lleva la clave Jira en la rama, el título y el commit;
   - añade su cambio al CHANGELOG.md, en la sección [Unreleased];
   - rellena la plantilla de PR y lleva una label: feature, bug, hotfix, chore o breaking-change, y además migration si hay migraciones.

   Claude Code hace todo esto con el comando /cerrar-tarea.
3. **Congelar el hito.** Con todas las tareas terminadas, se mergea un PR "CHORE: prepara release v1.4.0", con la label ignore-for-release. Ese PR renombra la sección [Unreleased] del CHANGELOG a "[v1.4.0] - fecha".
4. **Release candidate.** Se crea la pre-release v1.4.0-rc.1 desde main, y se despliega sola en **staging**.
5. **QA en staging.** Si aparece un bug, se corrige con un PR y se publica v1.4.0-rc.2, que vuelve a staging. Si mientras tanto main tiene que aceptar trabajo del hito siguiente, se crea la rama release/1.4.x desde el rc, y los siguientes rc salen de ahí.
6. **Release final.** Se crea v1.4.0 **sobre el mismo commit** que el último rc validado. El workflow rechaza una release final que no coincida con ningún rc. Se despliega en **producción**, tras aprobación si el entorno la exige.
7. **Cierre en Jira.** Cuando el despliegue termina bien, el workflow marca v1.4.0 como Released en Jira (si está configurado). Las tareas que no entraron se mueven a v1.5.0.

**Cómo se publican las releases.** Hay dos maneras:
- **Desde Claude Code:** /release rc v1.4.0 para el rc, y /release final v1.4.0 para la final. Claude prepara el comando, lo enseña y espera confirmación antes de publicar.
- **Desde la web de GitHub:**
  - Releases → Draft a new release.
  - Para un rc, marcar "Set as a pre-release".
  - Para la final, elegir como destino el commit del último rc.
  - Pulsar "Generate release notes" y pegar encima la sección del hito que hay en el CHANGELOG.

## 3. Hotfix

- **Si main no tiene nada nuevo desde la última versión final:** el fix va por el camino normal. PR a main → v1.4.1-rc.1 → staging → v1.4.1.
- **Si main ya lleva trabajo de v1.5.0:**
  1. Se crea la rama release/1.4.x a partir del tag v1.4.0.
  2. Se hace un PR del fix contra release/1.4.x, y se lleva el mismo fix a main con otro PR o con cherry-pick.
  3. Se publica v1.4.1-rc.1 y luego v1.4.1, siempre desde la rama release/1.4.x.

## 4. Rollback

Hacer rollback es **desplegar una release anterior**. No se borra ni se edita nada.

- **Desde la web:**
  1. En GitHub, ir a Actions → Deploy → Run workflow.
  2. Indicar la versión (por ejemplo, v1.3.2) y el entorno (production).
- **Desde Claude Code:** /release rollback v1.3.2 production.

Si esa versión sigue en el servidor (se conservan las 5 últimas) o en el registro de imágenes Docker, se reactiva al momento. Si no, se vuelve a compilar desde su tag, lo que tarda algo más. Las migraciones de base de datos no se deshacen (ver punto 5). Después se abre la incidencia en Jira y se corrige con un parche (v1.4.1).

**Para saber qué versión hay desplegada y desde cuándo:**
- en la pestaña Deployments del repositorio en GitHub;
- en la propia tarea de Jira, que muestra los despliegues gracias a GitHub for Jira;
- en el servidor, en los ficheros CURRENT_VERSION y deploy-history.log.

## 5. La regla de oro: cada versión debe convivir con la siguiente

El rollback revierte **solo el código**. La base de datos, el fichero .env compartido, los ficheros subidos y las colas de trabajos no vuelven atrás. Por eso:

- **Migraciones solo aditivas** en cada release: tablas nuevas, columnas nuevas con valor por defecto o que admiten vacío, índices. Para renombrar o borrar una columna hacen falta tres releases (técnica expand/contract):
  1. Primera release: añadir lo nuevo y escribir en lo viejo y en lo nuevo.
  2. Segunda: leer solo lo nuevo.
  3. Tercera: borrar lo viejo.
- **Nunca** se deshacen migraciones en producción (migrate:rollback) como forma de deshacer un despliegue.
- **Variables de entorno nuevas** siempre con valor por defecto en el código.
- **Trabajos en cola (jobs)**: no se renombran ni cambian sus parámetros de golpe.

### En proyectos Laravel + Inertia

Backend y frontend viajan en la misma imagen Docker y cambian juntos al desplegar o hacer rollback. Aun así, hay que cuidar estos puntos:

- **No modificar el método version() de HandleInertiaRequests.** Debe seguir devolviendo parent::version(), que es el hash de los assets de Vite. Gracias a eso, tras un despliegue o un rollback, cualquier navegador que tenga abierta otra versión recarga la página entera en la siguiente navegación. Con un valor fijo, el navegador seguiría ejecutando JavaScript de otra versión.
- **Formularios abiertos en pestañas antiguas.** Inertia solo comprueba la versión al navegar (peticiones GET), así que un formulario enviado desde una pestaña vieja llega al backend nuevo. Si se renombra un campo de un formulario, el backend debe aceptar también el nombre viejo durante una release.
- **Las variables VITE_ se incrustan en el JavaScript al compilar.** Por eso se genera una imagen por entorno, cada una con sus valores (variable DOCKER_BUILD_ARGS en GitHub). Nunca se ponen secretos en variables VITE_, porque cualquiera puede leerlas en el navegador.
- **Misma versión en todos los servicios.** php, horizon, cron, reverb y, si existe, el proceso de renderizado en servidor (SSR) usan la misma imagen y la misma versión. Si uno se queda en otra versión, se mezcla código de dos releases.
- **Versión visible.** La versión llega al backend como APP_VERSION y al frontend como VITE_APP_VERSION. Se usa para mostrarla en la aplicación (por ejemplo, en el pie de página) y para identificar la release en Sentry, en lugar del identificador del commit.

## 6. Montarlo en un repositorio

**Para empezar:** crear el repositorio desde la plantilla (botón "Use this template" en GitHub) o, si el proyecto ya existe, copiar el kit con scripts/aplicar-kit.sh. Después, ejecutar una vez scripts/inicializar-proyecto.sh: elige la variante de despliegue, rellena la clave de Jira y el runner, y crea en GitHub las labels, los environments y las variables de Jira. Lo que no puede hacer el script (secretos, protecciones, Jira) lo lista al terminar.

**Ficheros** que trae la plantilla:

| Fichero | Para qué |
|---|---|
| .github/workflows/deploy.yml (sale de plantillas/deploy-inertia.yml) | **Por defecto.** Laravel + Inertia en Docker (convenciones de 10code-inertia-template), con despliegue por docker compose o Ansible. El script pone el nombre de los runners del proyecto |
| plantillas/deploy-laravel.yml o plantillas/deploy-nextjs.yml (el script copia la elegida a deploy.yml) | Proyectos sin Docker, con carpetas de versiones en el servidor (ogov, ogov-front) |
| .github/workflows/jira-release.yml | Marca la versión de Jira como Released |
| .github/release.yml | Agrupa las notas de cada release por tipo de cambio |
| .github/pull_request_template.md | Plantilla de PR (Claude la rellena) |
| CHANGELOG.md | Registro de cambios, versión a versión |
| .claude/skills (empezar-tarea, cerrar-tarea, release) | Comandos de Claude Code |
| .mcp.json | Conexión de Claude Code con Jira |
| CLAUDE.md | Instrucciones para Claude Code, con el bloque del flujo |
| scripts/inicializar-proyecto.sh y scripts/aplicar-kit.sh | Configuración inicial y copia del kit a proyectos existentes |

**Ajustes de GitHub** (pestaña Settings del repositorio):
- **Environments: crear "staging" y "production".**
  - Variables de cada uno: las que indica la cabecera de la plantilla elegida (DEPLOY_PATH, ENV_FILE_PATH, MIGRATE_COMMAND, DOCKER_BUILD_ARGS…).
  - En production, activar "Required reviewers" (alguien aprueba cada despliegue). En "Deployment branches and tags", permitir solo la rama main y los tags que empiezan por v. En repositorios privados, estas protecciones exigen plan Team o Enterprise.
- **Secrets:**
  - GHCR_TOKEN, en proyectos Docker, o LARAVEL_ENV_ENCRYPTION_KEY, en proyectos sin Docker;
  - JIRA_USER_EMAIL y JIRA_API_TOKEN, para la integración con Jira.
- **Variables del repositorio:** JIRA_BASE_URL = https://10code.atlassian.net y JIRA_PROJECT_KEY = la clave del proyecto en Jira.
- **Rulesets (reglas de protección):**
  - Rama main: PR obligatorio y sin push directo.
  - Tags que empiezan por v: solo los mantenedores pueden crearlos, y nadie puede borrarlos ni moverlos. Si está disponible, activar también "Immutable releases".
- **Labels:** feature, bug, hotfix, chore, breaking-change, migration, ignore-for-release.

**Jira:**
- Instalar la app GitHub for Jira y conectar la organización de GitHub. Con eso, en cada tarea aparecen sus ramas, PRs y despliegues, y los entornos staging y production se reconocen solos.
- Adaptar los estados del tablero al nuevo flujo:
  - En curso → En revisión (PR) → En main → En staging (rc) → Publicado.
  - El estado actual "En staging por aprobar" depende de la rama staging, que desaparece.

**Proyectos existentes (ogov, etc.):**
1. Crear el tag v1.0.0 sobre el commit que hay hoy en producción.
2. Durante una transición, cambiar los workflows actuales de despliegue (cd-main.yml, cd-staging.yml) para que solo se lancen a mano. Después, borrarlos.
3. Dejar de usar las ramas staging y develop para desplegar.

Las carpetas de versiones antiguas del servidor desaparecen solas con la limpieza automática.

## 7. Limpieza de imágenes en 10code-product

La organización 10code-product tiene un workflow de limpieza (cleanup-org-packages.yml, en el repositorio .github) que se ejecuta los días 1 y 15 de cada mes y deja **solo 2 versiones** de cada imagen Docker. Con eso, el rollback de los proyectos Docker casi siempre tendría que recompilar. Funcionaría, pero más lento, y no garantiza una imagen idéntica a la que estaba en producción.

**Propuesta:** para las imágenes de producción, conservar 10 versiones (min-versions-to-keep: 10) o excluirlas de la limpieza.

## Glosario

- **Release:** versión publicada en GitHub (sección Releases), asociada a un tag de git como v1.4.0. En este flujo, publicar una release despliega.
- **rc (release candidate, "versión candidata"):** una versión que podría ser la final, pero que antes se prueba en staging.
  - Se publica como pre-release con el sufijo -rc y un número: v1.4.0-rc.1, v1.4.0-rc.2…
  - Si aparece un bug, se corrige y se publica el siguiente rc.
  - Cuando un rc se da por bueno, la versión final v1.4.0 se crea sobre su mismo commit. Así, a producción llega exactamente lo que se probó.
- **Pre-release:** casilla de GitHub que marca una release como no definitiva. Aquí equivale a "va a staging".
- **SemVer:** formato de versión MAYOR.MENOR.PARCHE. Se sube el MENOR con cada hito, el PARCHE con cada hotfix y el MAYOR con un cambio incompatible.
- **Hotfix:** corrección urgente de una versión ya publicada en producción (v1.4.0 → v1.4.1).
- **Rollback:** volver a desplegar una versión anterior ya publicada.
- **Expand/contract:** hacer los cambios de base de datos en varias releases (primero añadir, luego dejar de usar, al final borrar), para que cada versión funcione con el esquema de la siguiente.
