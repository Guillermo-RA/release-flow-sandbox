#!/usr/bin/env bash
# "Build" de la app de prueba: genera dist/index.html con la versión y el saludo.
set -euo pipefail
mkdir -p dist
printf '<title>Sandbox</title><h1>%s</h1><p>versión %s</p>\n' "$(cat app/greeting.txt)" "$(cat VERSION 2>/dev/null || echo dev)" > dist/index.html
