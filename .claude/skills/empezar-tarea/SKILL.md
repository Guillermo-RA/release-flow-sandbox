---
name: empezar-tarea
description: Empieza a trabajar en una tarea de Jira a partir de su clave (p. ej. OGOV-123). Lee la tarea con el MCP de Atlassian, resume el alcance y crea la rama correcta. Usar cuando el usuario diga "empieza la tarea X", "trabaja en KEY-123" o pase solo una clave de Jira.
argument-hint: "<CLAVE-JIRA>"
---

# Empezar tarea $ARGUMENTS

1. **Leer la tarea** con el MCP de Atlassian (`getJiraIssue`, `view: "evidence"`; el cloudId se obtiene una vez con `getAccessibleAtlassianResources`). Si el MCP no está disponible, pide al usuario que lo conecte (ver «Jira desde Claude Code» en el CLAUDE.md) o que pegue la descripción.
   Extrae: resumen, tipo (historia, error…), descripción, criterios de aceptación, **Fix Version (hito)**, subtareas y tareas enlazadas.

2. **Comprobar el hito.**
   - Sin Fix Version: avisa al usuario. Es probable que esté sin planificar. No inventes uno.
   - Fix Version de parche (`vX.Y.Z` con Z > 0) cuya versión `vX.Y.0` ya está publicada: es un **hotfix**. La base es la rama `release/X.Y.x` si existe, o `main` si no hay trabajo sin publicar (ver CLAUDE.md).
   - En cualquier otro caso, la base es `main`.

3. **Resumir el plan** al usuario en pocas líneas: qué se pide, qué partes del código parece tocar, dudas o huecos en la descripción y si hará falta migración. Si hay ambigüedades importantes, pregunta antes de escribir código.

4. **Crear la rama** desde la base actualizada:
   ```bash
   git fetch origin
   git switch -c <tipo>/<CLAVE>-<slug-corto> origin/<base>
   ```
   `<tipo>`: `feat`, `fix`, `hotfix`, `chore`, `refactor` o `docs`. `<slug-corto>`: 3-6 palabras en kebab-case y sin tildes.

5. No cambies el estado de la tarea en Jira ni escribas comentarios sin que el usuario lo pida.
