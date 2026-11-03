import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class ApiService {
  String? _access;
  String? _refresh;

  Future<void> login(String email, String password) async {
    final r = await http.post(
      Uri.parse('$baseUrl/auth/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (r.statusCode != 200) {
      throw Exception('Email o contraseña incorrectos');
    }
    _guardarTokens(jsonDecode(r.body));
  }

  void _guardarTokens(Map<String, dynamic> d) {
    _access = d['access'];
    _refresh = d['refresh'];
  }

  Future<bool> _renovar() async {
    if (_refresh == null) return false;
    final r = await http.post(
      Uri.parse('$baseUrl/auth/refresh/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh': _refresh}),
    );
    if (r.statusCode != 200) return false;
    _guardarTokens(jsonDecode(r.body));
    return true;
  }

  Future<http.Response> _get(String ruta) async {
    Future<http.Response> pedir() => http.get(
          Uri.parse('$baseUrl$ruta'),
          headers: {'Authorization': 'Bearer $_access'},
        );
    var r = await pedir();
    if (r.statusCode == 401 && await _renovar()) r = await pedir();
    return r;
  }

  Future<http.Response> _post(String ruta, [Map<String, dynamic>? body]) async {
    Future<http.Response> pedir() => http.post(
          Uri.parse('$baseUrl$ruta'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_access',
          },
          body: jsonEncode(body ?? {}),
        );
    var r = await pedir();
    if (r.statusCode == 401 && await _renovar()) r = await pedir();
    return r;
  }

  String _mensaje(http.Response r) {
    try {
      final e = jsonDecode(utf8.decode(r.bodyBytes))['error'];
      final m = '${e['mensaje']}';
      return e['detalles'] != null ? '$m ${e['detalles']}' : m;
    } catch (_) {
      return 'Error (${r.statusCode})';
    }
  }

  Map<String, dynamic> _mapa(http.Response r) =>
      Map<String, dynamic>.from(jsonDecode(utf8.decode(r.bodyBytes)));

  Future<List<Map<String, dynamic>>> _lista(String ruta) async {
    final r = await _get(ruta);
    if (r.statusCode != 200) {
      throw Exception('No se pudo cargar la lista (${r.statusCode})');
    }
    final data = jsonDecode(utf8.decode(r.bodyBytes));
    return List<Map<String, dynamic>>.from(data['results']);
  }

  Future<List<Map<String, dynamic>>> materias() => _lista('/materias/');
  Future<List<Map<String, dynamic>>> misExamenes() => _lista('/mis-examenes/');
  Future<List<Map<String, dynamic>>> intentos() => _lista('/intentos/');

  Future<Map<String, dynamic>> iniciarIntento(int asignacionId) async {
    final r = await _post('/intentos/', {'asignacion': asignacionId});
    if (r.statusCode != 200 && r.statusCode != 201) {
      throw Exception(_mensaje(r));
    }
    return _mapa(r);
  }

  /// Devuelve los segundos que le quedan al intento (los calcula el servidor).
  Future<int> responder(
    int intentoId,
    int preguntaId, {
    List<int> opciones = const [],
    String texto = '',
  }) async {
    final r = await _post('/intentos/$intentoId/responder/', {
      'pregunta': preguntaId,
      'opciones': opciones,
      'texto_respuesta': texto,
    });
    if (r.statusCode != 200) throw Exception(_mensaje(r));
    return _mapa(r)['segundos_restantes'] as int;
  }

  Future<Map<String, dynamic>> enviar(int intentoId) async {
    final r = await _post('/intentos/$intentoId/enviar/');
    if (r.statusCode != 200) throw Exception(_mensaje(r));
    return _mapa(r);
  }
}