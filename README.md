#1. Estrategia de Branching

A continuación se responde se estará definiendo una estrategia clara para cada rol del equipo.

##1.1 Desarrolladores – Gitflow (2.5%)

El equipo de desarrollo sigue un modelo estructurado para planificar releases y trabajar en paralelo sin afectar producción.

- main: código en producción (protegida, solo merges vía PR).
- develop: integración estable para la próxima release.
- feature/<nombre-corto>: nuevas funcionalidades; se crean desde develop y vuelven a develop vía PR y revisión.
- release/<versión>: estabilización previa al release (correcciones menores, docs); se mergea a main y a develop.
- hotfix/<versión>: correcciones críticas desde main; tras validar, se mergea a main y a develop.

Convenciones: usar PRs con revisión obligatoria, CI verde antes de merge, nombres descriptivos y pequeños lotes de cambio.

Rationale: mayor control del versionamiento, menor riesgo en producción y mejor coordinación entre equipos.

##1.2 Operaciones – GitHub Flow (2.5%)

El equipo de operaciones sigue un modelo ligero para cambios operativos y de despliegue continuo.

- main siempre desplegable; cambios pequeños y frecuentes.
- ramas cortas: fix/<tema>, chore/<tarea>, hotfix/<incidencia>; creadas desde main.
- PR a main con revisión; al merge se dispara CD hacia el entorno objetivo.
- hotfix: se prioriza, prueba rápida, merge a main y despliegue inmediato.

Guardas: checks de CI obligatorios, políticas de protección en main y approvals requeridos.

Rationale: simplicidad, agilidad y tiempos de recuperación cortos, alineado a objetivos de disponibilidad.