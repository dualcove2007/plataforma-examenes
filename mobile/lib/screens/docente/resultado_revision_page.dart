import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/docente_ui.dart';
import '../../widgets/estudiante_ui.dart';
import '../../widgets/ui.dart';

/// Revisión de un intento: respuestas, alertas anti-trampa y calificación
/// de las preguntas abiertas.
class ResultadoRevisionPage extends StatefulWidget {
  final ApiService api;
  final int resultadoId;
  const ResultadoRevisionPage({
    super.key,
    required this.api,
    required this.resultadoId,
  });

  @override
  State<ResultadoRevisionPage> createState() => _ResultadoRevisionPageState();
}

class _ResultadoRevisionPageState extends State<ResultadoRevisionPage> {
  Map<String, dynamic>? _r;
  final _notas = <int, TextEditingController>{};
  bool _cargando = true;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    for (final c in _notas.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<Map<String, dynamic>> get _respuestas =>
      List<Map<String, dynamic>>.from(_r?['respuestas'] ?? const []);

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) setState(() => _cargando = true);
    try {
      final r = await widget.api.resultado(widget.resultadoId);
      if (!mounted) return;
      for (final c in _notas.values) {
        c.dispose();
      }
      _notas.clear();
      for (final x in List<Map<String, dynamic>>.from(r['respuestas'] ?? [])) {
        if (x['tipo'] == 'abierta') {
          final p = x['puntaje_obtenido'];
          _notas[x['id'] as int] = TextEditingController(
            text: p == null ? '' : formatearPuntaje(p),
          );
        }
      }
      setState(() {
        _r = r;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = mensajeError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    final maximos = {
      for (final x in _respuestas)
        if (x['tipo'] == 'abierta') (x['id'] as int): aNumero(x['puntaje_maximo']),
    };
    final lista = <Map<String, dynamic>>[];
    for (final e in _notas.entries) {
      final texto = e.value.text.trim().replaceAll(',', '.');
      if (texto.isEmpty) continue;
      final n = double.tryParse(texto);
      final max = maximos[e.key];
      if (n == null || n < 0 || (max != null && n > max)) {
        mostrarAviso(
          context,
          max == null
              ? 'Revisa los puntajes escritos.'
              : 'Cada puntaje debe estar entre 0 y ${formatearPuntaje(max)}.',
          error: true,
        );
        return;
      }
      lista.add({'respuesta': e.key, 'puntaje': n});
    }
    if (lista.isEmpty) {
      mostrarAviso(context, 'Escribe al menos un puntaje.', error: true);
      return;
    }
    setState(() => _guardando = true);
    try {
      await widget.api.calificar(widget.resultadoId, lista);
      if (!mounted) return;
      mostrarAviso(context, 'Calificaciones guardadas');
      await _cargar(silencioso: true);
    } catch (e) {
      if (mounted) mostrarAviso(context, mensajeError(e), error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    return Scaffold(
      bottomNavigationBar: _notas.isEmpty
          ? null
          : Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Paleta.borde, width: 1.5),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: FilledButton.icon(
                    onPressed: _guardando ? null : _guardar,
                    icon: const Icon(Icons.save_rounded),
                    label: Text(
                      _guardando ? 'Guardando...' : 'Guardar calificaciones',
                    ),
                  ),
                ),
              ),
            ),
      body: Column(
        children: [
          CabeceraSeccion(
            titulo: r == null ? 'Revisión' : '${r['estudiante']}',
            subtitulo: r == null
                ? 'Cargando...'
                : '${r['examen_titulo']} · intento ${r['numero_intento']}',
            icono: Icons.fact_check_rounded,
            seccion: Seccion.resultados,
            leading: botonVolver(context),
          ),
          Expanded(child: _cuerpo()),
        ],
      ),
    );
  }

  Widget _cuerpo() {
    if (_cargando && _r == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final r = _r;
    if (r == null) {
      return EstadoError(
        mensaje: _error ?? 'No se pudo cargar el resultado.',
        onReintentar: _cargar,
      );
    }
    final rev = estiloRevision('${r['estado_revision']}');
    final alertas = (r['alertas'] as Map?)?.cast<String, dynamic>();
    final respuestas = _respuestas;
    final t = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: () => _cargar(silencioso: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ── Resumen ──
          PanelCard(
            child: Row(
              children: [
                NotaCirculo(r['nota_final'], tam: 76),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${formatearPuntaje(r['puntaje_total'])} de ${formatearPuntaje(r['puntaje_maximo'])} puntos',
                        style: t.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${r['estudiante_email']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Paleta.tintaSuave,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Etiqueta(rev.texto, icono: rev.icono, fondo: rev.suave),
                          if (r['estado_revision'] == 'revisado')
                            etiquetaResultado(r['nota_final'], 'revisado'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Alertas anti-trampa ──
          if (alertas != null) _TarjetaAlertas(alertas),
          const SizedBox(height: 22),

          TituloBloque('Respuestas (${respuestas.length})', Icons.quiz_rounded),
          const SizedBox(height: 10),
          if (respuestas.isEmpty)
            const PanelCard(
              child: Text(
                'El estudiante no respondió ninguna pregunta.',
                style: TextStyle(color: Paleta.tintaSuave),
              ),
            )
          else
            for (var i = 0; i < respuestas.length; i++) ...[
              _TarjetaRespuesta(
                numero: i + 1,
                r: respuestas[i],
                controlador: _notas[respuestas[i]['id'] as int],
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _TarjetaAlertas extends StatelessWidget {
  final Map<String, dynamic> a;
  const _TarjetaAlertas(this.a);

  @override
  Widget build(BuildContext context) {
    final salidas = (a['salidas_pestana'] as int?) ?? 0;
    final segundos = (a['segundos_fuera'] as int?) ?? 0;
    final pegados = (a['pegados'] as int?) ?? 0;
    final limpio = salidas == 0 && pegados == 0;
    return PanelCard(
      color: limpio ? Paleta.verdeSuave : Paleta.coralSuave,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(
            limpio ? Icons.verified_user_rounded : Icons.warning_amber_rounded,
            fondo: Colors.white,
            tam: 44,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  limpio ? 'Sin alertas de vigilancia' : 'Posible comportamiento sospechoso',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                if (limpio)
                  const Text(
                    'No salió de la pantalla ni pegó texto durante el examen.',
                  )
                else
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      if (salidas > 0)
                        DatoIcono(
                          Icons.exit_to_app_rounded,
                          '$salidas ${salidas == 1 ? 'salida' : 'salidas'} · ${_duracion(segundos)} fuera',
                        ),
                      if (pegados > 0)
                        DatoIcono(
                          Icons.content_paste_rounded,
                          '$pegados ${pegados == 1 ? 'pegado' : 'pegados'}',
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _duracion(int s) {
    if (s < 60) return '$s s';
    final m = s ~/ 60;
    final r = s % 60;
    return r == 0 ? '$m min' : '$m min $r s';
  }
}

class _TarjetaRespuesta extends StatelessWidget {
  final int numero;
  final Map<String, dynamic> r;
  final TextEditingController? controlador;
  const _TarjetaRespuesta({
    required this.numero,
    required this.r,
    required this.controlador,
  });

  @override
  Widget build(BuildContext context) {
    final tipo = estiloTipo('${r['tipo']}');
    final abierta = r['tipo'] == 'abierta';
    final seleccion = List<Map<String, dynamic>>.from(
      r['opciones_seleccionadas'] ?? const [],
    );
    final max = formatearPuntaje(r['puntaje_maximo']);
    final obtenido = r['puntaje_obtenido'];

    IconData icono;
    Color color;
    if (abierta) {
      icono = obtenido == null
          ? Icons.hourglass_top_rounded
          : Icons.edit_note_rounded;
      color = obtenido == null ? Paleta.miel : Paleta.lila;
    } else if (r['es_correcta'] == true) {
      icono = Icons.check_circle_rounded;
      color = Paleta.verde;
    } else {
      icono = Icons.cancel_rounded;
      color = Paleta.coral;
    }

    final texto = '${r['texto_respuesta'] ?? ''}'.trim();

    return PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icono, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$numero. ${r['enunciado']}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Etiqueta(tipo.texto, icono: tipo.icono, fondo: tipo.suave),
              Etiqueta(
                obtenido == null
                    ? 'Sin calificar · máx. $max'
                    : '${formatearPuntaje(obtenido)} / $max pts',
                icono: Icons.star_rounded,
                fondo: Paleta.crema,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (abierta) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Paleta.crema,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                texto.isEmpty ? 'Sin respuesta' : texto,
                style: TextStyle(
                  height: 1.35,
                  color: texto.isEmpty ? Paleta.tintaSuave : Paleta.tinta,
                  fontStyle: texto.isEmpty ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
            if (controlador != null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: controlador,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Puntaje (0 a $max)',
                  prefixIcon: const Icon(Icons.grade_outlined),
                ),
              ),
            ],
          ] else if (seleccion.isEmpty)
            const Text(
              'Sin responder',
              style: TextStyle(
                color: Paleta.tintaSuave,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            for (final o in seleccion)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.subdirectory_arrow_right_rounded,
                      size: 18,
                      color: Paleta.tintaSuave,
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: Text('${o['texto']}')),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
