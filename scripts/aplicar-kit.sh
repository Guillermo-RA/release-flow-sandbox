#!/usr/bin/env bash
# Copia el flujo por releases a un proyecto que ya existe (por ejemplo, uno
# creado desde 10code-inertia-template). Después hay que ejecutar, dentro de
# ese proyecto, scripts/inicializar-proyecto.sh.
#
# Uso:
#   scripts/aplicar-kit.sh /ruta/al/proyecto
#
# Nunca sobrescribe: si un fichero ya existe en el destino, lo deja como está y
# lo avisa al final. El CLAUDE.md existente no se reemplaza: se le añade el
# bloque del flujo al final.
set -euo pipefail

DESTINO="${1:-}"
[ -n "$DESTINO" ] || { sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
[ -d "$DESTINO/.git" ] || { echo "Error: $DESTINO no es la raíz de un repositorio git" >&2; exit 1; }
ORIGEN="$(cd "$(dirname "$0")/.." && pwd)"
DESTINO="$(cd "$DESTINO" && pwd)"
[ "$ORIGEN" != "$DESTINO" ] || { echo "Error: el destino es la propia plantilla" >&2; exit 1; }

COPIADOS=() OMITIDOS=()
copiar() {
  local rel="$1"
  if [ -e "$DESTINO/$rel" ]; then
    OMITIDOS+=("$rel")
  else
    mkdir -p "$(dirname "$DESTINO/$rel")"
    cp "$ORIGEN/$rel" "$DESTINO/$rel"
    COPIADOS+=("$rel")
  fi
}

cd "$ORIGEN"
for rel in .github/workflows/deploy.yml .github/workflows/jira-release.yml .github/release.yml \
           .github/pull_request_template.md .mcp.json CHANGELOG.md CHANGELOG-INTERNO.md docs/FLUJO-RELEASES.md \
           scripts/inicializar-proyecto.sh plantillas/*.yml .claude/skills/*/SKILL.md; do
  copiar "$rel"
done

# CLAUDE.md: se copia entero si no existe; si existe, se añade solo el bloque del flujo.
if [ ! -e "$DESTINO/CLAUDE.md" ]; then
  copiar CLAUDE.md
elif grep -q "flujo-releases:inicio" "$DESTINO/CLAUDE.md"; then
  OMITIDOS+=("CLAUDE.md (ya tiene el bloque del flujo)")
else
  { echo; sed -n '/flujo-releases:inicio/,/flujo-releases:fin/p' CLAUDE.md; } >> "$DESTINO/CLAUDE.md"
  COPIADOS+=("CLAUDE.md (bloque del flujo añadido al final)")
fi

if [ ${#COPIADOS[@]} -gt 0 ]; then
  echo "Copiado a $DESTINO:"
  printf '  + %s\n' "${COPIADOS[@]}"
else
  echo "No había nada nuevo que copiar a $DESTINO."
fi
if [ ${#OMITIDOS[@]} -gt 0 ]; then
  echo "Ya existían y NO se han tocado (revísalos a mano):"
  printf '  = %s\n' "${OMITIDOS[@]}"
  if printf '%s\n' "${OMITIDOS[@]}" | grep -qx ".mcp.json"; then
    echo '    Para .mcp.json, añade dentro de "mcpServers":'
    echo '      "atlassian": { "type": "http", "url": "https://mcp.atlassian.com/v1/mcp" }'
  fi
fi

# Workflows antiguos que despliegan con push: hay que desactivarlos en la transición.
ANTIGUOS=$(cd "$DESTINO" && grep -lE '^\s*push:' .github/workflows/*.y*ml 2>/dev/null | grep -v -e deploy.yml -e jira-release.yml || true)
if [ -n "$ANTIGUOS" ]; then
  echo "Workflows que todavía despliegan con push (cámbialos a workflow_dispatch y bórralos tras la transición):"
  printf '  ! %s\n' $ANTIGUOS
fi

echo
echo "Siguiente paso:"
echo "  cd \"$DESTINO\" && scripts/inicializar-proyecto.sh --jira <CLAVE> --runner <nombre-runner>"
