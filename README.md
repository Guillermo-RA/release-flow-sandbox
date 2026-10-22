# Plantilla de proyecto: flujo por hitos y releases

Plantilla para arrancar proyectos con esta forma de trabajar:

- **Cada hito de Jira es una GitHub Release**, con el mismo nombre (v1.4.0).
- **Cada release es un despliegue.** Una pre-release v1.4.0-rc.1 va a staging y la release v1.4.0 va a producción. Hacer push a una rama no despliega nada.
- **Rollback** a cualquier versión publicada, en segundos.
- **Claude Code integrado.** Se le pide "haz la tarea PRO-123": lee la tarea en Jira, pregunta las dudas, implementa, anota el cambio en el CHANGELOG y abre el PR con la plantilla rellena.

La guía completa para el equipo está en [docs/FLUJO-RELEASES.md](docs/FLUJO-RELEASES.md).

## Qué incluye

| Ruta | Para qué |
|---|---|
| .github/workflows/deploy.yml | Despliegue por release y rollback. Por defecto, Laravel + Inertia en Docker |
| .github/workflows/jira-release.yml | Marca la versión de Jira como Released al llegar a producción |
| .github/release.yml | Agrupa las notas de cada release por tipo de cambio |
| .github/pull_request_template.md | Plantilla de PR |
| .claude/skills/ | Comandos de Claude Code: /empezar-tarea, /cerrar-tarea y /release |
| .mcp.json | Conexión de Claude Code con Jira (MCP de Atlassian) |
| CLAUDE.md | Instrucciones para Claude Code sobre el flujo |
| CHANGELOG.md | Registro de cambios para usuarios; se publica en las notas de cada release |
| CHANGELOG-INTERNO.md | Registro técnico de todos los cambios, incluidos refactors y mantenimiento |
| plantillas/ | Variantes del workflow de despliegue: inertia (Docker), laravel y nextjs (sin Docker) |
| scripts/ | Configuración inicial y copia del kit a proyectos existentes |

La plantilla **no incluye código de aplicación**. La base Laravel + Inertia (Dockerfiles, docker compose, Ansible) sale de 10code-inertia-template. Esta plantilla añade encima el flujo de trabajo.

## Proyecto nuevo

1. En GitHub, pulsa **Use this template → Create a new repository**.
2. Añade la base de la aplicación, por ejemplo copiando 10code-inertia-template.
3. Clona el repositorio nuevo y ejecuta una vez:

   ```bash
   scripts/inicializar-proyecto.sh --jira PRO --runner miproyecto --nombre "Mi proyecto"
   ```

   - `--jira`: clave del proyecto en Jira.
   - `--runner`: nombre de los runners self-hosted. El workflow usa los grupos miproyecto-staging y miproyecto-production.
   - `--stack laravel` o `--stack nextjs`: para proyectos sin Docker (por defecto, inertia).

4. Revisa los cambios con `git diff` y haz commit.
5. Completa lo que el script lista al terminar: secretos, variables de cada entorno, protecciones de production y conexión con Jira.

## Proyecto existente

Desde un clon de esta plantilla:

```bash
scripts/aplicar-kit.sh /ruta/al/proyecto
cd /ruta/al/proyecto
scripts/inicializar-proyecto.sh --jira PRO --runner miproyecto
```

aplicar-kit.sh nunca sobrescribe ficheros:
- Si el proyecto ya tiene un CLAUDE.md, le añade el bloque del flujo al final.
- Si ya tiene un .mcp.json, te dice qué añadir.
- Avisa de los workflows antiguos que todavía despliegan con push. Durante la transición se cambian a lanzamiento manual, y después se borran.

## Requisitos

- GitHub CLI (gh) con sesión iniciada, para la parte de configuración de GitHub. Con `--sin-github`, el script solo cambia ficheros.
- Runners self-hosted en los servidores de staging y producción.
- Para la integración con Jira: la app GitHub for Jira y los secretos JIRA_USER_EMAIL y JIRA_API_TOKEN.
