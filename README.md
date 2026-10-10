# Plataforma de Exámenes en Línea

Aplicación web para crear bancos de preguntas, armar y publicar exámenes, que los
estudiantes los presenten con temporizador y que los docentes revisen y califiquen.

- **Backend:** Django 5.2 + Django REST Framework, autenticación JWT
- **Base de datos:** PostgreSQL 16
- **Tareas programadas:** Celery + Redis
- **Frontend:** Angular 22

## Funcionalidades

- Roles: Administrador, Docente y Estudiante, con permisos por rol
- Materias, bancos de preguntas y preguntas (opción única, múltiple, verdadero/falso y abiertas)
- Importación y exportación de preguntas en Excel
- Exámenes con ventana de fechas, duración, intentos permitidos y asignación a estudiantes
- Intentos con temporizador, guardado automático y calificación automática
- Revisión docente de preguntas abiertas
- Notificaciones por publicación, asignación y revisión
- Adjuntos (PDF, PNG, JPG) en exámenes y preguntas
- Reportes: notas en Excel, constancia en PDF y estadísticas en el dashboard
- Auditoría de cambios

## Requisitos

- Docker y Docker Compose (para la forma rápida)
- Para desarrollo sin contenedores: Python 3.14, Node.js 22 y npm

## Inicio rápido con Docker

1. Crea el archivo de entorno y edítalo con tus valores:

```bash
   cp .env.example .env
```

   Cambia al menos `SECRET_KEY` y `POSTGRES_PASSWORD`.

2. Construye y levanta todo:

```bash
   docker compose up -d --build
```

3. Crea los roles, permisos y usuarios de prueba (se puede repetir sin duplicar):

```bash
   docker compose exec backend python manage.py seed
```

4. Abre la aplicación:

   | Servicio | URL |
   |---|---|
   | Aplicación (Angular) | http://localhost:8080 |
   | API | http://localhost:8000/api/ |
   | Documentación de la API (Swagger) | http://localhost:8000/api/docs/ |
   | Admin de Django | http://localhost:8000/admin/ |

Servicios del compose: `db`, `redis`, `backend` (gunicorn), `worker` (Celery),
`beat` (Celery beat) y `frontend` (nginx). Al arrancar, el backend aplica las
migraciones automáticamente.

Si cambias código, reconstruye con `docker compose up -d --build`.

### Usuarios de prueba

El comando `seed` crea estos usuarios con la contraseña `Demo12345*`:

| Correo | Rol |
|---|---|
| admin@demo.com | Administrador |
| docente@demo.com | Docente |
| estudiante@demo.com | Estudiante |

> **Solo para desarrollo.** Esa contraseña es pública. En cualquier entorno real
> elige otra al sembrar (`seed --password "OtraClave"`) o cámbiala después:
> `docker compose exec backend python manage.py changepassword correo@del.usuario`

## Desarrollo local (sin contenedores para la app)

Deja solo la base y Redis en Docker:

```bash
docker compose up -d db redis
```

Si tenías los contenedores `backend`, `worker`, `beat` o `frontend` arriba,
detenlos antes para liberar los puertos:

```bash
docker compose stop backend worker beat frontend
```

### Backend

En tu `.env` usa `POSTGRES_HOST=localhost` y `POSTGRES_PORT=5433` (el puerto que
publica el compose). Desde `backend/`:

```bash
python -m venv .venv
source .venv/bin/activate        # En Windows: .venv\Scripts\activate
pip install -r requirements.txt
python manage.py migrate
python manage.py seed
python manage.py runserver
```

Celery, cada proceso en su propia terminal y también desde `backend/`:

```bash
celery -A core worker -l info
celery -A core beat -l info
```

En Windows el worker necesita el pool `solo`:
`celery -A core worker -l info --pool=solo`

### Frontend

Desde `frontend/`:

```bash
npm install
ng serve
```

Queda en http://localhost:4200. La URL de la API está en
`frontend/src/environments/environment.ts` (`http://localhost:8000/api`).

## Pruebas

Backend, desde `backend/` (usa una base temporal `test_<POSTGRES_DB>`, no toca tus datos):

```bash
pytest
```

Frontend, desde `frontend/`:

```bash
ng test
```

## Roles y permisos

| Rol | Puede |
|---|---|
| Administrador | Gestionar usuarios, roles y materias; ver todos los resultados, reportes y auditoría |
| Docente | Gestionar bancos, preguntas y exámenes; asignar; calificar respuestas abiertas; reportes de sus exámenes |
| Estudiante | Presentar los exámenes que tiene asignados y ver sus propios resultados |

La autorización definitiva se aplica siempre en el backend. Los guards de Angular
solo controlan la navegación.

## Reglas importantes

- La nota va de 0 a 5 y la nota mínima para aprobar es `NOTA_APROBATORIA = 3.0`
  (`backend/core/settings/base.py`).
- Durante un intento no se envía al estudiante cuál opción es la correcta.
- Las preguntas abiertas con texto quedan pendientes de revisión docente.
- Adjuntos: PDF hasta 10 MB; PNG y JPG hasta 5 MB. Se valida el contenido real del
  archivo, no solo la extensión. Solo se pueden modificar mientras el examen (o la
  pregunta) no esté publicado.
- Los estudiantes solo ven adjuntos de exámenes publicados que tienen asignados.

## Tareas programadas (Celery)

| Tarea | Frecuencia | Qué hace |
|---|---|---|
| `attempts.expirar_intentos_vencidos` | Cada 60 s | Cierra y califica los intentos cuyo tiempo venció (5 s de tolerancia) |
| `exams.cerrar_examenes_vencidos` | Cada 300 s | Pasa a «cerrado» los exámenes publicados cuya fecha de fin ya pasó (60 s de margen) |

Ambas son idempotentes: ejecutarlas varias veces no duplica nada.

## Estructura

```
backend/
  core/            configuración (settings: base, dev, prod), Celery, urls
  apps/
    authentication/  usuarios, roles, permisos, JWT
    question_banks/  materias, bancos, preguntas, Excel
    exams/           exámenes, asignaciones, tareas
    attempts/        intentos, respuestas, calificación
    notifications/   notificaciones
    files/           adjuntos
    reports/         Excel de notas, constancia PDF, estadísticas
    audit/           historial de cambios
frontend/
  src/app/
    core/            sesión, interceptor, guards, utilidades
    features/        pantallas por módulo
docs/   mockups, diagrama ER y normalización
```

## Documentación

- [Mockups de las interfaces](docs/mockups.pdf)
- [Diagrama entidad-relación](docs/diagrama-er.png)
- [Normalización (1FN, 2FN, 3FN)](docs/normalizacion.pdf)


## Configuración por entorno

Variables que lee el backend (`.env` en local; en Docker las define el compose):

| Variable | Uso |
|---|---|
| `SECRET_KEY` | Clave de Django. Obligatoria |
| `DEBUG` | Solo aplica en desarrollo; `core.settings.prod` fuerza `False` |
| `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_HOST`, `POSTGRES_PORT` | Conexión a PostgreSQL |
| `REDIS_URL` | Broker de Celery |
| `ALLOWED_HOSTS` | Solo prod. Lista separada por comas |
| `CORS_ALLOWED_ORIGINS` | Solo prod. Orígenes del frontend, separados por comas |
| `CSRF_TRUSTED_ORIGINS` | Solo prod. Necesaria para el admin detrás de un proxy |

## Notas para un despliegue real

- La URL de la API queda fija en el bundle de Angular (`environment.ts`). Para otro
  servidor, cámbiala y reconstruye el frontend, o sirve la API detrás de nginx en la
  misma ruta.
- Define `ALLOWED_HOSTS`, `CORS_ALLOWED_ORIGINS` y `CSRF_TRUSTED_ORIGINS` con tus dominios
  y sirve todo bajo HTTPS.
- No uses la contraseña de los usuarios de prueba.
- Nunca subas el `.env`; si un secreto se expuso, rótalo.