## Tarea

<!-- Clave(s) Jira y enlace. El hito (Fix Version) en el que entra este cambio. -->
- Jira: [KEY-123](https://10code.atlassian.net/browse/KEY-123)
- Hito: `vX.Y.Z`

## Qué cambia

<!-- 2-5 frases: qué problema resuelve y cómo. Pensado para quien revisa, no un volcado del diff. -->

## Tipo de cambio

<!-- Marca uno. Tiene que coincidir con la label del PR (las notas de la release se agrupan por label). -->
- [ ] ✨ Funcionalidad (`feature`)
- [ ] 🐛 Corrección (`bug`)
- [ ] 🚑 Hotfix sobre una versión ya publicada (`hotfix`)
- [ ] 🔧 Refactor / mantenimiento / docs (`chore`)
- [ ] 💥 Incompatible: rompe API, requiere cambio de infraestructura o subida de versión mayor (`breaking-change`)

## Cómo probarlo

<!-- Pasos concretos para validarlo en local o en staging. Tests añadidos o modificados. -->
1.

## Compatibilidad con rollback

<!-- Todo despliegue debe poder revertirse a la versión anterior sin tocar la base de datos. -->
- [ ] Sin migraciones
- [ ] Con migraciones **compatibles con la versión anterior** (solo añaden; nada se renombra ni se borra en este PR) — label `migration`
- [ ] Variables de entorno nuevas: tienen valor por defecto y están documentadas en `.env.example`
- [ ] No hay variables de entorno nuevas

<!-- Si algo de esto no se cumple, explica aquí por qué y cuál es el plan de vuelta atrás. -->

## Checklist

- [ ] `CHANGELOG.md` actualizado en `[Unreleased]` (o en la sección del hito en estabilización)
- [ ] Tests y linters pasan en local
- [ ] El PR va contra `main` (o contra `release/X.Y.x` si es un hotfix)
