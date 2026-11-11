# App móvil — Plataforma de Exámenes (Flutter)

App para Android/iOS que consume la API Django del proyecto.

## Qué incluye

- **Varios roles en una cuenta**: el admin puede darle a un usuario más de un rol
  (ej. Administrador y Docente) desde el formulario de usuario. Con ese correo, al
  iniciar sesión la app pregunta con qué rol entrar; la sesión guardada conserva ese rol.
- **Login** con diseño propio (ilustración, íconos, validaciones). Según el rol
  entra al panel de administrador, docente o estudiante.
- **Sesión persistente**: el refresh token se guarda cifrado en el teléfono
  (`flutter_secure_storage`). Al abrir la app se retoma la sesión sin pedir la
  contraseña; solo «Cerrar sesión» (o una sesión vencida/revocada) vuelve al login.
  Si al abrir no hay internet, la sesión no se borra: se ofrece reintentar.
- **Listas paginadas**: todas las listas muestran 10 registros por página con
  botones «anterior / siguiente» y el rango visible (`ListaPaginada` y
  `PaginadorBarra` en `lib/widgets/ui.dart`).
- **Foto de perfil**: el administrador la puede poner al registrar o editar un
  usuario, y cada usuario (de cualquier rol) la agrega, cambia o quita desde su
  perfil (en admin y docente: botón con su foto en la cabecera del inicio).
  JPG o PNG, máx. 5 MB; se sirve por la API autenticada, no como archivo público.
- **Contraseñas** (se validan en la app y en el backend): mínimo 8 caracteres,
  letras y números, al menos un carácter especial y sin 3 o más números
  consecutivos (123 o 321 no; 12 o 23 sí). El generador del formulario de
  usuarios siempre cumple las reglas.
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
- **Docente**: inicio, bancos y preguntas, exámenes (crear, asignar, publicar) y
  resultados con revisión de preguntas abiertas.

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
    docente/       panel del docente
    arranque_page.dart         retoma la sesión guardada al abrir la app
    perfil_page.dart           perfil y foto, compartido por todos los roles
    notificaciones_page.dart   compartida por todos los roles
  utils/       reglas de contraseña (clave.dart)
```

## Generar el APK para celulares

```bash
cd mobile
flutter build apk --release --dart-define=API_URL=http://<IP-DE-TU-PC>:8000/api
```

El archivo queda en `mobile/build/app/outputs/flutter-apk/app-release.apk`. El celular
debe poder llegar al backend: misma red wifi que el PC (con el puerto 8000 abierto en el
firewall y la IP en `ALLOWED_HOSTS` de `docker-compose.yml`) o un backend publicado en
internet. El APK se firma con la llave de depuración; para Play Store hace falta una
llave propia.
