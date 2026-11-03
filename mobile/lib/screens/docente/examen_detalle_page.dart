import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/docente_ui.dart';
import '../../widgets/estudiante_ui.dart';
import '../../widgets/ui.dart';
import 'examen_form_page.dart';
import 'resultados_page.dart';
import 'selectores.dart';

/// Todo lo del examen en un solo lugar: datos, estado, preguntas y asignados.
class ExamenDetallePage extends StatefulWidget {
  final ApiService api;
  final int examenId;
  const ExamenDetallePage({
    super.key,
    required this.api,
    required this.examenId,
  });

  @override
  State<ExamenDetallePage> createState() => _ExamenDetallePageState();
}

class _ExamenDetallePageState extends State<ExamenDetallePage> {
  Map<String, dynamic>? _ex;
  List<Map<String, dynamic>> _asig = const [];
  bool _cargando = true;
  bool _trabajando = false;
  String? _error;

  ApiService get api => widget.api;
  String get _estado => '${_ex?['estado']}';
  bool get _borrador => _estado == 'borrador';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) setState(() => _cargando = true);
    try {
      final res = await Future.wait<Object>([
        api.examen(widget.examenId),
        api.asignaciones(widget.examenId),
      ]);
      if (!mounted) return;
      setState(() {
        _ex = res[0] as Map<String, dynamic>;
        _asig = res[1] as List<Map<String, dynamic>>;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = mensajeError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Ejecuta una acción que puede fallar mostrando el error en un aviso.
  Future<void> _hacer(
    Future<void> Function() accion, {
    String? exito,
    bool recargar = true,
  }) async {
    setState(() => _trabajando = true);
    try {
      await accion();
      if (!mounted) return;
      if (exito != null) mostrarAviso(context, exito);
      if (recargar) await _cargar(silencioso: true);
    } catch (e) {
      if (mounted) mostrarAviso(context, mensajeError(e), error: true);
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  Future<void> _cambiarEstado({
    required String accion,
    required String titulo,
    required String mensaje,
    required IconData icono,
    required String exito,
    bool peligro = false,
  }) async {
    final ok = await confirmar(
      context,
      titulo: titulo,
      mensaje: mensaje,
      textoConfirmar: titulo,
      icono: icono,
      peligro: peligro,
    );
    if (!ok || !mounted) return;
    await _hacer(
      () => api.cambiarEstadoExamen(widget.examenId, accion),
      exito: exito,
    );
  }

  Future<void> _editar() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ExamenFormPage(api: api, examen: _ex),
      ),
    );
    if (ok == true) await _cargar(silencioso: true);
  }

  Future<void> _eliminar() async {
    final ok = await confirmar(
      context,
      titulo: 'Eliminar',
      mensaje: '¿Eliminar “${_ex!['titulo']}”? Esta acción no se puede deshacer.',
      textoConfirmar: 'Eliminar',
      icono: Icons.delete_rounded,
      peligro: true,
    );
    if (!ok || !mounted) return;
    setState(() => _trabajando = true);
    try {
      await api.eliminarExamen(widget.examenId);
      if (!mounted) return;
      final nav = Navigator.of(context);
      mostrarAviso(context, 'Examen eliminado');
      nav.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _trabajando = false);
        mostrarAviso(context, mensajeError(e), error: true);
      }
    }
  }

  Future<void> _agregarPreguntas() async {
    final yaEstan = {
      for (final p in List<Map<String, dynamic>>.from(_ex!['preguntas'] ?? []))
        p['pregunta'] as int,
    };
    final elegidas = await Navigator.of(context)
        .push<List<Map<String, dynamic>>>(
          MaterialPageRoute(
            builder: (_) => SelectorPreguntasPage(
              api: api,
              materiaId: _ex!['materia'] as int,
              materiaNombre: '${_ex!['materia_nombre']}',
              yaEnExamen: yaEstan,
            ),
          ),
        );
    if (elegidas == null || elegidas.isEmpty || !mounted) return;
    await _hacer(() async {
      for (final p in elegidas) {
        await api.agregarPreguntaExamen(widget.examenId, p['id'] as int);
      }
    }, exito: '${elegidas.length} ${elegidas.length == 1 ? 'pregunta agregada' : 'preguntas agregadas'}');
  }

  Future<void> _quitarPregunta(Map<String, dynamic> item) async {
    final ok = await confirmar(
      context,
      titulo: 'Quitar',
      mensaje: '¿Quitar esta pregunta del examen? Seguirá en tu banco.',
      textoConfirmar: 'Quitar',
      icono: Icons.remove_circle_rounded,
      peligro: true,
    );
    if (!ok || !mounted) return;
    await _hacer(
      () => api.quitarPreguntaExamen(widget.examenId, item['pregunta'] as int),
      exito: 'Pregunta quitada',
    );
  }

  Future<void> _asignar() async {
    final ids = await Navigator.of(context).push<List<int>>(
      MaterialPageRoute(
        builder: (_) => SelectorEstudiantesPage(
          api: api,
          yaAsignados: {for (final a in _asig) a['estudiante'] as int},
        ),
      ),
    );
    if (ids == null || ids.isEmpty || !mounted) return;
    await _hacer(() async {
      final nuevos = await api.asignarEstudiantes(widget.examenId, ids);
      if (mounted) {
        mostrarAviso(
          context,
          nuevos == 1 ? '1 estudiante asignado' : '$nuevos estudiantes asignados',
        );
      }
    });
  }

  void _verResultados() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocenteResultadosPage(
          api: api,
          examenId: widget.examenId,
          examenTitulo: '${_ex!['titulo']}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estilo = estiloEstadoExamen(_estado);
    return Scaffold(
      body: Column(
        children: [
          CabeceraSeccion(
            titulo: _ex == null ? 'Examen' : '${_ex!['titulo']}',
            subtitulo: _ex == null
                ? 'Cargando...'
                : '${_ex!['materia_nombre']} · ${estilo.texto}',
            icono: _ex == null ? Icons.assignment_rounded : estilo.icono,
            seccion: Seccion.examenes,
            leading: botonVolver(context),
          ),
          if (_trabajando) const LinearProgressIndicator(minHeight: 3),
          Expanded(child: _cuerpo()),
        ],
      ),
    );
  }

  Widget _cuerpo() {
    if (_cargando && _ex == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_ex == null) {
      return EstadoError(
        mensaje: _error ?? 'No se pudo cargar el examen.',
        onReintentar: _cargar,
      );
    }
    final ex = _ex!;
    final preguntas = List<Map<String, dynamic>>.from(ex['preguntas'] ?? []);
    final desc = '${ex['descripcion'] ?? ''}'.trim();
    final t = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: () => _cargar(silencioso: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ── Datos ──
          PanelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (desc.isNotEmpty) ...[
                  Text(desc, style: const TextStyle(height: 1.35)),
                  const SizedBox(height: 14),
                ],
                Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  children: [
                    DatoIcono(
                      Icons.play_circle_outline_rounded,
                      'Abre ${fechaCorta('${ex['fecha_inicio']}')}',
                    ),
                    DatoIcono(
                      Icons.stop_circle_outlined,
                      'Cierra ${fechaCorta('${ex['fecha_fin']}')}',
                    ),
                    DatoIcono(
                      Icons.timer_rounded,
                      '${ex['duracion_minutos']} min por intento',
                    ),
                    DatoIcono(
                      Icons.replay_rounded,
                      '${ex['intentos_permitidos']} ${ex['intentos_permitidos'] == 1 ? 'intento' : 'intentos'}',
                    ),
                    DatoIcono(
                      Icons.star_rounded,
                      '${formatearPuntaje(ex['puntaje_total'] ?? 0)} pts en total',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Acciones según el estado ──
          ..._acciones(),
          const SizedBox(height: 22),

          // ── Preguntas ──
          TituloBloque(
            'Preguntas (${preguntas.length})',
            Icons.quiz_rounded,
            accion: _borrador
                ? TextButton.icon(
                    onPressed: _trabajando ? null : _agregarPreguntas,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: const Text('Agregar'),
                  )
                : null,
          ),
          const SizedBox(height: 10),
          if (preguntas.isEmpty)
            PanelCard(
              color: Paleta.mielSuave,
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _borrador
                          ? 'Aún no tiene preguntas. Agrégalas para poder publicarlo.'
                          : 'Este examen no tiene preguntas.',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            )
          else
            for (final p in preguntas) ...[
              _FilaPregunta(
                item: p,
                onQuitar: _borrador && !_trabajando
                    ? () => _quitarPregunta(p)
                    : null,
              ),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 14),

          // ── Asignados ──
          TituloBloque(
            'Estudiantes asignados (${_asig.length})',
            Icons.groups_rounded,
            accion: (_borrador || _estado == 'publicado')
                ? TextButton.icon(
                    onPressed: _trabajando ? null : _asignar,
                    icon: const Icon(Icons.group_add_rounded),
                    label: const Text('Asignar'),
                  )
                : null,
          ),
          const SizedBox(height: 10),
          if (_asig.isEmpty)
            PanelCard(
              color: Paleta.cieloSuave,
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Nadie tiene este examen asignado todavía.',
                      style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            )
          else
            PanelCard(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
              child: Column(
                children: [
                  for (var i = 0; i < _asig.length; i++) ...[
                    if (i > 0) const Divider(),
                    _FilaAsignado(_asig[i]),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _acciones() {
    final bloqueado = _trabajando;
    final botones = <Widget>[];

    if (_borrador) {
      botones.addAll([
        FilledButton.icon(
          onPressed: bloqueado
              ? null
              : () => _cambiarEstado(
                  accion: 'publicar',
                  titulo: 'Publicar',
                  mensaje:
                      'Los estudiantes asignados recibirán una notificación y '
                      'ya no podrás editar el examen ni sus preguntas.',
                  icono: Icons.rocket_launch_rounded,
                  exito: 'Examen publicado',
                ),
          icon: const Icon(Icons.rocket_launch_rounded),
          label: const Text('Publicar examen'),
        ),
        OutlinedButton.icon(
          onPressed: bloqueado ? null : _editar,
          icon: const Icon(Icons.edit_rounded),
          label: const Text('Editar datos'),
        ),
        OutlinedButton.icon(
          onPressed: bloqueado
              ? null
              : () => _cambiarEstado(
                  accion: 'archivar',
                  titulo: 'Archivar',
                  mensaje: 'El examen quedará archivado y no podrá publicarse.',
                  icono: Icons.inventory_2_rounded,
                  exito: 'Examen archivado',
                ),
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('Archivar'),
        ),
        OutlinedButton.icon(
          onPressed: bloqueado ? null : _eliminar,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFB3261E),
          ),
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Eliminar'),
        ),
      ]);
    } else if (_estado == 'publicado') {
      botones.addAll([
        FilledButton.icon(
          onPressed: bloqueado
              ? null
              : () => _cambiarEstado(
                  accion: 'cerrar',
                  titulo: 'Cerrar',
                  mensaje:
                      'Nadie más podrá presentar este examen. '
                      'Podrás revisar y calificar los resultados.',
                  icono: Icons.lock_rounded,
                  exito: 'Examen cerrado',
                  peligro: true,
                ),
          style: FilledButton.styleFrom(
            backgroundColor: Paleta.coral,
            foregroundColor: Paleta.tinta,
          ),
          icon: const Icon(Icons.lock_rounded),
          label: const Text('Cerrar examen'),
        ),
        OutlinedButton.icon(
          onPressed: _verResultados,
          icon: const Icon(Icons.fact_check_rounded),
          label: const Text('Ver resultados'),
        ),
      ]);
    } else if (_estado == 'cerrado') {
      botones.addAll([
        FilledButton.icon(
          onPressed: _verResultados,
          icon: const Icon(Icons.fact_check_rounded),
          label: const Text('Revisar resultados'),
        ),
        OutlinedButton.icon(
          onPressed: bloqueado
              ? null
              : () => _cambiarEstado(
                  accion: 'archivar',
                  titulo: 'Archivar',
                  mensaje: 'El examen quedará archivado.',
                  icono: Icons.inventory_2_rounded,
                  exito: 'Examen archivado',
                ),
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('Archivar'),
        ),
      ]);
    } else {
      botones.add(
        OutlinedButton.icon(
          onPressed: _verResultados,
          icon: const Icon(Icons.fact_check_rounded),
          label: const Text('Ver resultados'),
        ),
      );
    }

    return [
      for (var i = 0; i < botones.length; i++) ...[
        if (i > 0) const SizedBox(height: 10),
        botones[i],
      ],
    ];
  }
}

class _FilaPregunta extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback? onQuitar;
  const _FilaPregunta({required this.item, this.onQuitar});

  @override
  Widget build(BuildContext context) {
    final tipo = estiloTipo('${item['tipo']}');
    return PanelCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tipo.suave,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              '${item['orden']}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item['enunciado']}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Etiqueta(tipo.texto, icono: tipo.icono, fondo: tipo.suave),
                    Etiqueta(
                      '${formatearPuntaje(item['puntaje'])} pts',
                      icono: Icons.star_rounded,
                      fondo: Paleta.crema,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onQuitar != null)
            IconButton(
              tooltip: 'Quitar del examen',
              onPressed: onQuitar,
              icon: const Icon(Icons.remove_circle_outline_rounded),
              color: const Color(0xFFB3261E),
            ),
        ],
      ),
    );
  }
}

class _FilaAsignado extends StatelessWidget {
  final Map<String, dynamic> a;
  const _FilaAsignado(this.a);

  @override
  Widget build(BuildContext context) {
    final nombre = '${a['estudiante_nombre']}';
    final (texto, fondo) = switch ('${a['estado']}') {
      'completado' => ('Completado', Paleta.verdeSuave),
      'en_progreso' => ('En progreso', Paleta.cieloSuave),
      'vencido' => ('Vencido', Paleta.coralSuave),
      _ => ('Pendiente', Paleta.mielSuave),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Paleta.mielSuave,
            foregroundColor: Paleta.tinta,
            child: Text(
              nombre.isEmpty ? '?' : nombre[0].toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${a['estudiante_email']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Paleta.tintaSuave,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          Etiqueta(texto, fondo: fondo),
        ],
      ),
    );
  }
}
