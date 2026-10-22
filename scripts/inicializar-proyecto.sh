#!/usr/bin/env bash
# Configura un proyecto recién creado desde esta plantilla (o al que se ha
# aplicado el kit con scripts/aplicar-kit.sh). Se ejecuta una vez, desde
# cualquier carpeta del repositorio.
#
# Uso:
#   scripts/inicializar-proyecto.sh --jira PRO --runner miproyecto [opciones]
#
#   --jira CLAVE       clave del proyecto en Jira (PRO, OGOV…)            (obligatoria)
#   --runner NOMBRE    grupo/label de los runners self-hosted del proyecto (obligatoria)
#                      (el workflow usa NOMBRE-staging y NOMBRE-production como grupos)
#   --stack STACK      inertia (por defecto) | laravel | nextjs
#   --nombre "TEXTO"   nombre del proyecto para el título del CLAUDE.md
#   --sin-github       solo cambia ficheros; no toca labels, environments ni variables
#
# Qué hace:
#   1. Copia plantillas/deploy-<stack>.yml a .github/workflows/deploy.yml con el runner.
#   2. Rellena la clave de Jira en CLAUDE.md y en la plantilla de PR.
#   3. Con gh: crea las labels, los environments staging y production, y las
#      variables JIRA_BASE_URL y JIRA_PROJECT_KEY.
#   4. Lista lo que queda por hacer a mano (secretos, protecciones, Jira).
# No hace commit: revisa los cambios con git diff y haz tú el commit.
set -euo pipefail

JIRA_KEY="" RUNNER="" STACK="inertia" NOMBRE="" GITHUB=1
while [ $# -gt 0 ]; do
  case "$1" in
    --jira) JIRA_KEY="${2:-}"; shift 2 ;;
    --runner) RUNNER="${2:-}"; shift 2 ;;
    --stack) STACK="${2:-}"; shift 2 ;;
    --nombre) NOMBRE="${2:-}"; shift 2 ;;
    --sin-github) GITHUB=0; shift ;;
    -h|--help) sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Opción desconocida: $1 (usa --help)" >&2; exit 1 ;;
  esac
done

error() { echo "Error: $*" >&2; exit 1; }
[ -n "$JIRA_KEY" ] || error "falta --jira (usa --help)"
[ -n "$RUNNER" ] || error "falta --runner (usa --help)"
[[ "$JIRA_KEY" =~ ^[A-Z][A-Z0-9]+$ ]] || error "la clave de Jira debe ir en mayúsculas, p. ej. PRO"
[[ "$RUNNER" =~ ^[A-Za-z0-9._-]+$ ]] || error "el nombre del runner solo admite letras, números, '.', '_' y '-'"
case "$STACK" in inertia|laravel|nextjs) ;; *) error "--stack debe ser inertia, laravel o nextjs" ;; esac

cd "$(git rev-parse --show-toplevel)"
[ -f "plantillas/deploy-$STACK.yml" ] || error "no encuentro plantillas/deploy-$STACK.yml"
[ -f CLAUDE.md ] || error "no encuentro CLAUDE.md"

# Sustitución literal (sin expresiones regulares) en un fichero.
# Compatible con el bash 3.2 de macOS, que no admite comillas en el reemplazo de ${var//a/b}.
sustituir() {
  local fichero="$1" buscar="$2" poner="$3" resto resultado=""
  resto="$(cat "$fichero")"
  while [[ "$resto" == *"$buscar"* ]]; do
    resultado+="${resto%%"$buscar"*}$poner"
    resto="${resto#*"$buscar"}"
  done
  printf '%s\n' "$resultado$resto" > "$fichero"
}

echo "1. Workflow de despliegue ($STACK)"
cp "plantillas/deploy-$STACK.yml" .github/workflows/deploy.yml
sustituir .github/workflows/deploy.yml "MIPROYECTO" "$RUNNER"

echo "2. Clave de Jira ($JIRA_KEY)"
sustituir CLAUDE.md "<KEY>" "$JIRA_KEY"
[ -f .github/pull_request_template.md ] && sustituir .github/pull_request_template.md "KEY-123" "$JIRA_KEY-123"
[ -n "$NOMBRE" ] && sustituir CLAUDE.md "<Nombre del proyecto>" "$NOMBRE"
case "$STACK" in
  laravel) sustituir CLAUDE.md "Laravel + Inertia (<React | Vue>) en Docker. El workflow de despliegue es .github/workflows/deploy.yml (hecho a partir de la plantilla deploy-inertia.yml)." \
             "Laravel sin Docker, con carpetas releases/ y symlink current en el servidor. El workflow de despliegue es .github/workflows/deploy.yml (hecho a partir de la plantilla deploy-laravel.yml)." ;;
  nextjs) sustituir CLAUDE.md "Laravel + Inertia (<React | Vue>) en Docker. El workflow de despliegue es .github/workflows/deploy.yml (hecho a partir de la plantilla deploy-inertia.yml)." \
             "Next.js sin Docker, con carpetas releases/, symlink current y supervisor en el servidor. El workflow de despliegue es .github/workflows/deploy.yml (hecho a partir de la plantilla deploy-nextjs.yml)." ;;
esac

if [ "$GITHUB" = 1 ]; then
  command -v gh >/dev/null || error "necesito gh (GitHub CLI) instalado y con sesión iniciada, o usa --sin-github"
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
  echo "3. Configuración de GitHub en $REPO"
  for l in "feature:0e8a16:Funcionalidad nueva" "bug:d73a4a:Corrección" "hotfix:b60205:Corrección urgente sobre una versión publicada" \
           "chore:cccccc:Mantenimiento, refactor o documentación" "breaking-change:5319e7:Cambio incompatible" \
           "migration:fbca04:Incluye migraciones de base de datos" "ignore-for-release:eeeeee:No aparece en las notas de la release"; do
    IFS=: read -r nombre color descripcion <<< "$l"
    gh label create "$nombre" --color "$color" --description "$descripcion" --repo "$REPO" --force >/dev/null
  done
  echo "   - labels creadas"
  for e in staging production; do gh api -X PUT "repos/$REPO/environments/$e" --silent; done
  echo "   - environments staging y production creados"
  gh variable set JIRA_BASE_URL --repo "$REPO" --body "https://10code.atlassian.net"
  gh variable set JIRA_PROJECT_KEY --repo "$REPO" --body "$JIRA_KEY"
  echo "   - variables JIRA_BASE_URL y JIRA_PROJECT_KEY definidas"
else
  echo "3. Configuración de GitHub: omitida (--sin-github)"
fi

echo
echo "Queda por hacer a mano (detalles en docs/FLUJO-RELEASES.md, punto 6):"
case "$STACK" in
  inertia) echo "  - Variables de cada environment: DOCKER_BUILD_ARGS y, según el modo de despliegue,"
           echo "    ENV_FILE_PATH + MIGRATE_COMMAND (docker compose) o ANSIBLE_PATH + USER (Ansible)."
           echo "  - Secretos: GHCR_TOKEN y, si se usa Reverb, VITE_REVERB_APP_KEY." ;;
  laravel) echo "  - Variables de cada environment: DEPLOY_PATH y, si se migra en el despliegue, MIGRATE_COMMAND."
           echo "  - Secreto: LARAVEL_ENV_ENCRYPTION_KEY." ;;
  nextjs)  echo "  - Variables de cada environment: DEPLOY_PATH, SUPERVISOR_PROGRAM y DOTENV." ;;
esac
echo "  - Secretos JIRA_USER_EMAIL y JIRA_API_TOKEN (sin ellos, el paso de Jira solo avisa)."
echo "  - En production: Required reviewers y, en Deployment branches and tags, main y tags v*."
echo "  - Rulesets: PR obligatorio en main; tags v* protegidos contra borrado y modificación."
echo "  - Jira: crear la primera Fix Version (p. ej. v0.1.0) y conectar GitHub for Jira."
echo "  - Cuando todo esté listo, puedes borrar las carpetas plantillas/ y scripts/."
echo
echo "Revisa los cambios con: git diff"
