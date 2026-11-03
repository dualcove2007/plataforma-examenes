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
- **Estudiante**: mis exámenes, presentar examen, resultados, materias.

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
  widgets/     componentes compartidos (tarjetas, cabeceras, lista paginada...)
  services/    ApiService (JWT con renovación automática)
  screens/
    admin/     panel del administrador
```
