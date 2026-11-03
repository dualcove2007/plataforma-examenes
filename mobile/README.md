# App móvil — Plataforma de Exámenes (Flutter)

App para Android/iOS que consume la API Django del proyecto.

## Qué incluye

- **Login** con diseño propio (ilustración, íconos, validaciones). Según el rol
  entra al panel de administrador o a la vista de exámenes.
- **Panel de administrador** (navegación inferior):
  - **Inicio**: estadísticas (usuarios, exámenes, intentos, aprobación) y accesos rápidos.
  - **Usuarios**: lista con búsqueda y filtros por rol/estado, **registro de usuarios**,
    edición, cambio de contraseña, activar/desactivar. Incluye generador de contraseñas.
  - **Materias**: crear, editar y eliminar.
  - **Roles**: editar descripción y encender/apagar permisos.
  - **Auditoría**: movimientos con búsqueda, filtros y detalle.
- **Estudiante** (navegación inferior):
  - **Inicio**: saludo, exámenes por presentar, promedio, siguiente examen y últimos
    resultados. La campana abre las notificaciones.
  - **Exámenes**: lista con filtros (por presentar, completados, cerrados) y estado de
    cada uno (disponible, en curso, próximo, cerrado, completado). Al tocar uno se abre
    una hoja con duración, preguntas, intentos y reglas, y recién ahí se empieza.
  - **Presentar examen**: una pregunta por pantalla, cronómetro siempre visible,
    navegador numerado, guardado automático y envío con confirmación. Si el tiempo
    se acaba, se envía solo. El tiempo se calcula contra la hora límite, así que no
    se desfasa si la app queda en segundo plano.
  - **Resultado**: nota, aprobado/reprobado o «en revisión». Cuando el docente ya
    revisó y el examen cerró, muestra el detalle pregunta por pregunta.
  - **Resultados**: historial de notas. **Materias**: catálogo con búsqueda.
  - **Perfil**: datos de la cuenta, notificaciones y cerrar sesión.
- **Docente**: por ahora solo una pantalla provisional con cierre de sesión (el panel
  completo es el siguiente avance).

### Vigilancia durante el examen

Igual que la web, la app avisa al backend (`POST /intentos/<id>/eventos/`, tipo
`salida_pestana`) cuando el estudiante saca la app del primer plano durante un examen,
y el docente lo ve en el resultado. La hoja previa al examen se lo informa al estudiante.
La app no registra pegado de texto (`pegado`), que la web sí reporta.

## Estilo

Plano, sin degradados: fondo crema, verde teal como color principal y acentos
miel, coral, cielo y lila. Los colores y el tema están en `lib/theme/app_theme.dart`;
los componentes compartidos en `lib/widgets/ui.dart`; las ilustraciones
(SVG) en `assets/images/`.

## Cómo correrla

```bash
cd mobile
flutter pub get
flutter run
```

La URL de la API está en `lib/config.dart` (`http://10.0.2.2:8000/api` apunta al
backend de tu PC desde el emulador de Android). En un celular físico usa la IP de
tu PC en la red local y agrega esa IP a `ALLOWED_HOSTS` del backend.

Usuarios de prueba (`python manage.py seed`): `admin@demo.com`,
`docente@demo.com` y `estudiante@demo.com`, contraseña `Demo12345*`.

## Estructura

```
lib/
  theme/       paleta y tema
  widgets/     componentes compartidos
                 ui.dart             tarjetas, cabeceras, lista paginada...
                 estudiante_ui.dart  estado de un examen, nota, tarjeta de examen
  services/    ApiService (JWT con renovación automática)
  screens/
    admin/         panel del administrador
    estudiante/    panel del estudiante
    docente/       panel del docente (provisional)
    notificaciones_page.dart   compartida por todos los roles
```
