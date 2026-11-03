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
  bool get esDocente => usuario?['rol'] == 'Docente';
  bool get esEstudiante => usuario?['rol'] == 'Estudiante';

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
    'titulo': 'Título',
    'materia': 'Materia',
    'banco': 'Banco',
    'enunciado': 'Enunciado',
    'tipo': 'Tipo',
    'dificultad': 'Dificultad',
    'puntaje': 'Puntaje',
    'opciones': 'Opciones',
    'pregunta': 'Pregunta',
    'estudiantes': 'Estudiantes',
    'calificaciones': 'Calificaciones',
    'fecha_inicio': 'Inicio',
    'fecha_fin': 'Fin',
    'duracion_minutos': 'Duración',
    'intentos_permitidos': 'Intentos',
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

  /// Mis exámenes + cuántos intentos llevo (`usados`) y si tengo uno abierto
  /// con tiempo (`en_curso`). Los intentos anulados no cuentan.
  Future<List<Map<String, dynamic>>> examenesConIntentos() async {
    final res = await Future.wait([misExamenes(), intentos()]);
    final examenes = res[0];
    final intentosAll = res[1];
    return [
      for (final e in examenes)
        {
          ...e,
          'usados': intentosAll
              .where(
                (i) => i['asignacion'] == e['id'] && i['estado'] != 'anulado',
              )
              .length,
          'en_curso': intentosAll.any(
            (i) =>
                i['asignacion'] == e['id'] &&
                i['estado'] == 'en_progreso' &&
                ((i['segundos_restantes'] as int?) ?? 0) > 0,
          ),
        },
    ];
  }

  /// Anti-trampa (igual que la web): avisa cuando el estudiante sale del examen.
  /// Es "de mejor esfuerzo": si falla la red no interrumpe el examen.
  Future<void> registrarEvento(
    int intentoId,
    String tipo, {
    int? duracionSegundos,
  }) async {
    try {
      await _post('/intentos/$intentoId/eventos/', {
        'tipo': tipo,
        if (duracionSegundos != null) 'duracion_segundos': duracionSegundos,
      });
    } catch (_) {}
  }

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

  /// Resultados del estudiante (la nota llega null mientras no esté revisada).
  Future<Pagina> misResultados(int pagina) =>
      _pagina('/mis-resultados/', pagina);

  Future<List<Map<String, dynamic>>> misResultadosTodos() =>
      _lista('/mis-resultados/');

  /// Detalle: incluye `respuestas` solo si el examen ya cerró y fue revisado.
  Future<Map<String, dynamic>> miResultado(int id) async =>
      _mapa(_ok(await _get('/mis-resultados/$id/')));

  // ───────────────────────── Notificaciones (cualquier rol) ─────────────────────────

  Future<Pagina> notificaciones(int pagina, {bool? leida}) =>
      _pagina('/notificaciones/', pagina, {'leida': leida?.toString()});

  Future<int> noLeidas() async =>
      _mapa(_ok(await _get('/notificaciones/no-leidas/')))['no_leidas'] as int;

  Future<void> marcarLeida(int id) async {
    _ok(await _post('/notificaciones/$id/marcar-leida/'));
  }

  Future<void> marcarTodasLeidas() async {
    _ok(await _post('/notificaciones/marcar-todas/'));
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

  // ───────────────────────── Docente: bancos de preguntas ─────────────────────────

  Future<Pagina> bancosPagina(
    int pagina, {
    String? buscar,
    int? materia,
    bool? activo,
  }) => _pagina('/bancos/', pagina, {
    'search': buscar,
    'materia': materia?.toString(),
    'activo': activo?.toString(),
  });

  Future<Map<String, dynamic>> crearBanco(Map<String, dynamic> datos) async =>
      _mapa(_ok(await _post('/bancos/', datos)));

  Future<Map<String, dynamic>> actualizarBanco(
    int id,
    Map<String, dynamic> datos,
  ) async => _mapa(_ok(await _patch('/bancos/$id/', datos)));

  /// Sin preguntas se borra; con preguntas solo se desactiva.
  /// Devuelve el mensaje del servidor para mostrárselo al docente.
  Future<String> eliminarBanco(int id) async =>
      '${_mapa(_ok(await _delete('/bancos/$id/')))['mensaje']}';

  // ───────────────────────── Docente: preguntas ─────────────────────────

  Future<Pagina> preguntasPagina(
    int pagina, {
    String? buscar,
    int? banco,
    int? materia,
    String? tipo,
    bool? activo,
  }) => _pagina('/preguntas/', pagina, {
    'search': buscar,
    'banco': banco?.toString(),
    'materia': materia?.toString(),
    'tipo': tipo,
    'activo': activo?.toString(),
  });

  Future<Map<String, dynamic>> crearPregunta(
    Map<String, dynamic> datos,
  ) async => _mapa(_ok(await _post('/preguntas/', datos)));

  Future<Map<String, dynamic>> actualizarPregunta(
    int id,
    Map<String, dynamic> datos,
  ) async => _mapa(_ok(await _patch('/preguntas/$id/', datos)));

  Future<String> eliminarPregunta(int id) async =>
      '${_mapa(_ok(await _delete('/preguntas/$id/')))['mensaje']}';

  // ───────────────────────── Docente: exámenes ─────────────────────────

  Future<Pagina> examenesPagina(
    int pagina, {
    String? buscar,
    String? estado,
  }) => _pagina('/examenes/', pagina, {'search': buscar, 'estado': estado});

  /// Detalle con `preguntas` (cada una con sus opciones y puntaje).
  Future<Map<String, dynamic>> examen(int id) async =>
      _mapa(_ok(await _get('/examenes/$id/')));

  Future<Map<String, dynamic>> crearExamen(Map<String, dynamic> datos) async =>
      _mapa(_ok(await _post('/examenes/', datos)));

  Future<Map<String, dynamic>> actualizarExamen(
    int id,
    Map<String, dynamic> datos,
  ) async => _mapa(_ok(await _patch('/examenes/$id/', datos)));

  /// Solo se borran exámenes en borrador.
  Future<void> eliminarExamen(int id) async {
    _ok(await _delete('/examenes/$id/'));
  }

  /// [accion]: `publicar`, `cerrar` o `archivar`.
  Future<void> cambiarEstadoExamen(int id, String accion) async {
    _ok(await _post('/examenes/$id/$accion/'));
  }

  Future<void> agregarPreguntaExamen(
    int examenId,
    int preguntaId, {
    double? puntaje,
  }) async {
    _ok(
      await _post('/examenes/$examenId/agregar-pregunta/', {
        'pregunta': preguntaId,
        if (puntaje != null) 'puntaje': puntaje,
      }),
    );
  }

  Future<void> quitarPreguntaExamen(int examenId, int preguntaId) async {
    _ok(
      await _post('/examenes/$examenId/quitar-pregunta/', {
        'pregunta': preguntaId,
      }),
    );
  }

  /// Devuelve cuántos estudiantes se asignaron de verdad (los repetidos no cuentan).
  Future<int> asignarEstudiantes(int examenId, List<int> ids) async {
    final r = _mapa(
      _ok(await _post('/examenes/$examenId/asignar/', {'estudiantes': ids})),
    );
    return (r['asignados'] as int?) ?? 0;
  }

  Future<List<Map<String, dynamic>>> asignaciones(int examenId) async =>
      List<Map<String, dynamic>>.from(
        _json(_ok(await _get('/examenes/$examenId/asignaciones/'))),
      );

  /// Estudiantes activos, para asignarlos a un examen.
  Future<Pagina> estudiantesPagina(int pagina, {String? buscar}) =>
      _pagina('/estudiantes/', pagina, {'search': buscar});

  // ───────────────────────── Docente: resultados y calificación ─────────────────────────

  Future<Pagina> resultadosPagina(
    int pagina, {
    String? buscar,
    int? examen,
    String? revision,
  }) => _pagina('/resultados/', pagina, {
    'search': buscar,
    'examen': examen?.toString(),
    'estado_revision': revision,
  });

  /// Detalle con `respuestas` y `alertas` (anti-trampa).
  Future<Map<String, dynamic>> resultado(int id) async =>
      _mapa(_ok(await _get('/resultados/$id/')));

  /// [calificaciones]: lista de `{respuesta: id, puntaje: n}` (solo abiertas).
  Future<Map<String, dynamic>> calificar(
    int resultadoId,
    List<Map<String, dynamic>> calificaciones,
  ) async => _mapa(
    _ok(
      await _post('/resultados/$resultadoId/calificar/', {
        'calificaciones': calificaciones,
      }),
    ),
  );
}
