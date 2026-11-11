import 'dart:math';

/// Una regla de contraseña y si la clave escrita la cumple.
class ReglaClave {
  final String texto;
  final bool cumple;
  const ReglaClave(this.texto, this.cumple);
}

bool _esDigito(int c) => c >= 48 && c <= 57;

/// True si hay 3 o más dígitos seguidos que suben (123) o bajan (321) de uno en
/// uno. Dos seguidos (12, 23) sí se permiten.
bool tieneNumerosConsecutivos(String s) {
  for (var i = 0; i + 2 < s.length; i++) {
    final a = s.codeUnitAt(i), b = s.codeUnitAt(i + 1), c = s.codeUnitAt(i + 2);
    if (!_esDigito(a) || !_esDigito(b) || !_esDigito(c)) continue;
    if ((b - a == 1 && c - b == 1) || (a - b == 1 && b - c == 1)) return true;
  }
  return false;
}

final _letra = RegExp(r'\p{L}', unicode: true);
final _numero = RegExp(r'[0-9]');
final _especial = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);

/// Las reglas, en el orden en que se muestran al escribir.
List<ReglaClave> evaluarClave(String s) => [
  ReglaClave('8 caracteres o más', s.length >= 8),
  ReglaClave('Letras y números', _letra.hasMatch(s) && _numero.hasMatch(s)),
  ReglaClave('Un carácter especial (* . - _ #)', _especial.hasMatch(s)),
  ReglaClave(
    'Sin 3 números seguidos (123, 321)',
    s.isNotEmpty && !tieneNumerosConsecutivos(s),
  ),
];

/// Mensaje del primer problema, o null si la contraseña es válida.
/// Son las mismas reglas que valida el backend.
String? validarClave(String s) {
  if (s.length < 8) return 'Mínimo 8 caracteres';
  if (!_letra.hasMatch(s)) return 'Debe incluir al menos una letra';
  if (!_numero.hasMatch(s)) return 'Debe incluir al menos un número';
  if (!_especial.hasMatch(s)) {
    return 'Debe incluir un carácter especial (por ejemplo * . - _ #)';
  }
  if (tieneNumerosConsecutivos(s)) {
    return 'No puede tener 3 o más números seguidos (123, 321)';
  }
  return null;
}

/// Genera una contraseña aleatoria que cumple todas las reglas.
String generarClave() {
  const letras = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ';
  const numeros = '23456789';
  const especiales = '*#-_.!@';
  final r = Random.secure();
  while (true) {
    final c = <String>[
      for (var i = 0; i < 8; i++) letras[r.nextInt(letras.length)],
      for (var i = 0; i < 3; i++) numeros[r.nextInt(numeros.length)],
      especiales[r.nextInt(especiales.length)],
    ]..shuffle(r);
    final clave = c.join();
    if (validarClave(clave) == null) return clave;
  }
}
