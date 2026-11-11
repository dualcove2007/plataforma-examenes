/// URL de la API. Por defecto apunta al backend de tu PC desde el emulador de
/// Android. Para un celular real se cambia al compilar, sin tocar el código:
///   flutter build apk --release --dart-define=API_URL=http://192.168.1.50:8000/api
const baseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://10.0.2.2:8000/api',
);
