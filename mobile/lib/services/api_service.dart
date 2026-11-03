import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

/// Una página de resultados del backend (paginación de DRF).
class Pagina {
  final List<Map<String, dynamic>> items;
  final int total;
  final bool hayMas;
  const Pagina(this.items, this.total, this.hayMas);
}

class ApiService {
  String? _access;
  String? _refresh;

  /// Usuario que inició sesión (lo devuelve el login).
  Map<String, dynamic>? usuario;

  bool get esAdmin => usuario?['rol'] == 'Administrador';

  bool tienePermiso(String codigo) =>
      ((usuario?['permisos'] as List?) ?? const []).contains(codigo);

  // ───────────────────────── Sesión ─────────────────────────

  Future<void> login(String email, String password) async {
    final http.Response r;
    try {
      r = await http
          .post(
            Uri.parse('$baseUrl/auth/login/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw Exception('No se pudo conectar con el servidor.');
    }
    if (r.statusCode == 400 || r.statusCode == 401) {
      throw Exception('Email o contraseña incorrectos');
    }
    if (r.statusCode != 200) throw Exception(_mensaje(r));
    _guardarTokens(_json(r));
  }

  /// Revoca el refresh token en el servidor y borra la sesión local.
  Future<void> logout() async {
    try {
      if (_refresh != null) await _post('/auth/logout/', {'refresh': _refresh});
    } catch (_) {
      // Si falla la red igual cerramos la sesión localmente.
    }
    _access = null;
    _refresh = null;
    usuario = null;
  }

  void _guardarTokens(Map<String, dynamic> d) {
    _access = d['access'];
    _refresh = d['refresh'];
    if (d['usuario'] is Map) {
      usuario = Map<String, dynamic>.from(d['usuario']);
    }
  }

  Future<bool> _renovar() async {
    if (_refresh == null) return false;
    final r = await http.post(
      Uri.parse('$baseUrl/auth/refresh/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh': _refresh}),
    );
    if (r.statusCode != 200) return false;
    _guardarTokens(_json(r));
    return true;
  }

  // ───────────────────────── HTTP base ─────────────────────────

  Future<http.Response> _req(
    String metodo,
    String ruta, [
    Map<String, dynamic>? body,
  ]) async {
    Future<http.Response> pedir() async {
      final req = http.Request(metodo, Uri.parse('$baseUrl$ruta'));
      req.headers['Authorization'] = 'Bearer $_access';
      if (body != null) {
        req.headers['Content-Type'] = 'application/json';
        req.body = jsonEncode(body);
      }
      return http.Response.fromStream(await req.send());
    }

    var r = await pedir();
    if (r.statusCode == 401 && await _renovar()) r = await pedir();
    return r;
  }

  Future<http.Response> _get(String ruta) => _req('GET', ruta);
  Future<http.Response> _post(String ruta, [Map<String, dynamic>? body]) =>
      _req('POST', ruta, body ?? {});
  Future<http.Response> _patch(String ruta, Map<String, dynamic> body) =>
      _req('PATCH', ruta, body);
  Future<http.Response> _delete(String ruta) => _req('DELETE', ruta);

  /// Lanza una excepción con el mensaje del servidor si la respuesta no es 2xx.
  http.Response _ok(http.Response r) {
    if (r.statusCode >= 200 && r.statusCode < 300) return r;
    if (r.statusCode == 401) {
      throw Exception('Tu sesión expiró. Vuelve a iniciar sesión.');
    }
    throw Exception(_mensaje(r));
  }

  dynamic _json(http.Response r) => jsonDecode(utf8.decode(r.bodyBytes));

  Map<String, dynamic> _mapa(http.Response r) =>
      Map<String, dynamic>.from(_json(r));

  static const _etiquetas = {
    'nombre': 'Nombre',
    'email': 'Correo',
    'password': 'Contraseña',
    'rol': 'Rol',
    'descripcion': 'Descripción',
    'permisos': 'Permisos',
    'non_field_errors': 'Error',
  };

  String _aplanar(dynamic d) {
    if (d is Map) {
      return d.entries
          .map((e) => '${_etiquetas[e.key] ?? e.key}: ${_aplanar(e.value)}')
          .join(' · ');
    }
    if (d is List) return d.map(_aplanar).join(' ');
    return '$d';
  }

  String _mensaje(http.Response r) {
    try {
      final e = _json(r)['error'];
      final m = '${e['mensaje']}';
      return e['detalles'] != null ? '$m ${_aplanar(e['detalles'])}' : m;
    } catch (_) {
      return 'Error (${r.statusCode})';
    }
  }

  // ───────────────────────── Listas ─────────────────────────

  Future<Pagina> _pagina(
    String ruta,
    int pagina, [
    Map<String, String?> params = const {},
  ]) async {
    final q = <String, String>{
      for (final e in params.entries)
        if (e.value != null && e.value!.isNotEmpty) e.key: e.value!,
      'page': '$pagina',
    };
    final r = _ok(await _get('$ruta?${Uri(queryParameters: q).query}'));
    final d = _json(r);
    return Pagina(
      List<Map<String, dynamic>>.from(d['results']),
      d['count'] as int,
      d['next'] != null,
    );
  }

  /// Trae todas las páginas de una lista (para listas cortas).
  Future<List<Map<String, dynamic>>> _lista(String ruta) async {
    final todos = <Map<String, dynamic>>[];
    for (var p = 1; ; p++) {
      final pag = await _pagina(ruta, p);
      todos.addAll(pag.items);
      if (!pag.hayMas) return todos;
    }
  }

  // ───────────────────────── Estudiante ─────────────────────────

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

  // ───────────────────────── Administrador: usuarios ─────────────────────────

  Future<Pagina> usuarios(
    int pagina, {
    String? buscar,
    int? rol,
    bool? activo,
  }) => _pagina('/usuarios/', pagina, {
    'search': buscar,
    'rol': rol?.toString(),
    'activo': activo?.toString(),
  });

  Future<int> contarUsuarios({int? rol, bool? activo}) async =>
      (await usuarios(1, rol: rol, activo: activo)).total;

  Future<Map<String, dynamic>> crearUsuario(Map<String, dynamic> datos) async =>
      _mapa(_ok(await _post('/usuarios/', datos)));

  Future<Map<String, dynamic>> actualizarUsuario(
    int id,
    Map<String, dynamic> datos,
  ) async => _mapa(_ok(await _patch('/usuarios/$id/', datos)));

  /// El backend no borra: desactiva la cuenta y cierra sus sesiones.
  Future<void> desactivarUsuario(int id) async {
    _ok(await _delete('/usuarios/$id/'));
  }

  // ───────────────────────── Administrador: roles y permisos ─────────────────────────

  Future<List<Map<String, dynamic>>> roles() async =>
      List<Map<String, dynamic>>.from(_json(_ok(await _get('/roles/'))));

  Future<List<Map<String, dynamic>>> permisos() async =>
      List<Map<String, dynamic>>.from(_json(_ok(await _get('/permisos/'))));

  Future<Map<String, dynamic>> actualizarRol(
    int id,
    Map<String, dynamic> datos,
  ) async => _mapa(_ok(await _patch('/roles/$id/', datos)));

  // ───────────────────────── Administrador: materias ─────────────────────────

  Future<Pagina> materiasPagina(int pagina, {String? buscar}) =>
      _pagina('/materias/', pagina, {'search': buscar});

  Future<Map<String, dynamic>> crearMateria(Map<String, dynamic> datos) async =>
      _mapa(_ok(await _post('/materias/', datos)));

  Future<Map<String, dynamic>> actualizarMateria(
    int id,
    Map<String, dynamic> datos,
  ) async => _mapa(_ok(await _patch('/materias/$id/', datos)));

  Future<void> eliminarMateria(int id) async {
    _ok(await _delete('/materias/$id/'));
  }

  // ───────────────────────── Administrador: auditoría y reportes ─────────────────────────

  Future<Pagina> auditoria(int pagina, {String? buscar, String? accion}) =>
      _pagina('/auditoria/', pagina, {'search': buscar, 'accion': accion});

  Future<Map<String, dynamic>> estadisticas() async =>
      _mapa(_ok(await _get('/reportes/estadisticas/')));
}
