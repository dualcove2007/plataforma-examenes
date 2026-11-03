import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/estudiante_ui.dart';
import '../../widgets/ui.dart';

/// Resultado de un intento. Se usa justo después de enviar el examen
/// ([recienEnviado]) y al abrir una nota desde "Mis resultados".
///
/// [resultado] es el resumen que entrega el backend (`ResultadoSerializer`):
/// `nota_final` llega null mientras el docente no termine de revisar.
class ResultadoPage extends StatefulWidget {
  final ApiService api;
  final Map<String, dynamic> resultado;
  final bool recienEnviado;
  const ResultadoPage({
    super.key,
    required this.api,
    required this.resultado,
    this.recienEnviado = false,
  });

  @override
  State<ResultadoPage> createState() => _ResultadoPageState();
}

class _ResultadoPageState extends State<ResultadoPage> {
  Future<Map<String, dynamic>>? _detalle;

  @override
  void initState() {
    super.initState();
    final r = widget.resultado;
    // El detalle por pregunta solo existe cuando ya fue revisado.
    if (r['estado_revision'] == 'revisado' && r['id'] is int) {
      _detalle = widget.api.miResultado(r['id'] as int);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.resultado;
    final nota = r['nota_final'];
    final ap = aprobo(nota);
    final t = Theme.of(context).textTheme;

    final seccion = ap == null
        ? Seccion.catalogo
        : ap
        ? Seccion.inicio
        : Seccion.resultados;
    final icono = ap == null
        ? Icons.hourglass_top_rounded
        : ap
        ? Icons.emoji_events_rounded
        : Icons.trending_up_rounded;
    final ilustracion = ap == null
        ? 'resultado_pendiente'
        : ap
        ? 'resultado_aprobado'
        : 'resultado_reprobado';
    final titulo = ap == null
        ? 'Examen enviado'
        : ap
        ? '¡Aprobaste!'
        : 'Sigue intentando';
    final mensaje = ap == null
        ? 'Tu examen quedó guardado. La nota aparecerá cuando tu docente '
              'termine la revisión y te avisaremos con una notificación.'
        : ap
        ? 'Superaste la nota mínima de ${formatearNota(notaAprobatoria)}. '
              '¡Buen trabajo!'
        : 'No alcanzaste la nota mínima de ${formatearNota(notaAprobatoria)}. '
              'Repasa los temas y, si te quedan intentos, vuelve a intentarlo.';
    final hayPuntaje = r['puntaje_total'] != null;

    return Scaffold(
      body: Column(
        children: [
          CabeceraSeccion(
            titulo: widget.recienEnviado ? 'Examen enviado' : 'Resultado',
            subtitulo: '${r['examen_titulo'] ?? ''}',
            icono: icono,
            seccion: seccion,
            leading: IconButton(
              tooltip: 'Volver',
              color: seccion.texto,
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                PanelCard(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                  child: Column(
                    children: [
                      SvgPicture.asset(
                        'assets/images/$ilustracion.svg',
                        height: 170,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        titulo,
                        textAlign: TextAlign.center,
                        style: t.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (ap != null) ...[
                        const SizedBox(height: 14),
                        NotaCirculo(nota, tam: 96),
                        const SizedBox(height: 8),
                        if (hayPuntaje)
                          Text(
                            '${formatearNota(r['puntaje_total'])} de '
                            '${formatearNota(r['puntaje_maximo'])} puntos',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Paleta.tintaSuave,
                            ),
                          ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        mensaje,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Paleta.tintaSuave,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _Dato(
                        Icons.replay_rounded,
                        Paleta.lilaSuave,
                        'Intento',
                        Text(
                          '${r['numero_intento'] ?? '—'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Dato(
                        Icons.fact_check_rounded,
                        Paleta.cieloSuave,
                        'Revisión',
                        _etiquetaRevision('${r['estado_revision']}'),
                      ),
                    ),
                  ],
                ),
                if (_detalle != null) ...[
                  const SizedBox(height: 20),
                  FutureBuilder<Map<String, dynamic>>(
                    future: _detalle,
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snap.hasError) {
                        return PanelCard(
                          color: Paleta.coralSuave,
                          child: Row(
                            children: [
                              const Icon(Icons.cloud_off_rounded),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'No se pudo cargar el detalle. '
                                  '${mensajeError(snap.error!)}',
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return _detalleRespuestas(snap.data!);
                    },
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: Text(
                    widget.recienEnviado ? 'Volver a mis exámenes' : 'Volver',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _etiquetaRevision(String estado) => switch (estado) {
    'revisado' => const Etiqueta(
      'Revisado',
      icono: Icons.check_circle_rounded,
      fondo: Paleta.verdeSuave,
    ),
    'en_revision' => const Etiqueta(
      'En revisión',
      icono: Icons.hourglass_top_rounded,
      fondo: Paleta.mielSuave,
    ),
    _ => const Etiqueta(
      'Pendiente',
      icono: Icons.schedule_rounded,
      fondo: Paleta.mielSuave,
    ),
  };

  Widget _detalleRespuestas(Map<String, dynamic> d) {
    if (d['detalle_disponible'] != true) {
      return const PanelCard(
        color: Paleta.cieloSuave,
        child: Row(
          children: [
            Icon(Icons.info_rounded),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'El detalle de tus respuestas estará disponible cuando el '
                'examen cierre.',
              ),
            ),
          ],
        ),
      );
    }
    final respuestas = List<Map<String, dynamic>>.from(
      (d['respuestas'] as List?) ?? const [],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Revisión de respuestas',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < respuestas.length; i++) ...[
          _Respuesta(numero: i + 1, r: respuestas[i]),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  final IconData icono;
  final Color fondo;
  final String titulo;
  final Widget valor;
  const _Dato(this.icono, this.fondo, this.titulo, this.valor);

  @override
  Widget build(BuildContext context) => PanelCard(
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        IconBadge(icono, fondo: fondo, tam: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Paleta.tintaSuave,
                ),
              ),
              const SizedBox(height: 2),
              valor,
            ],
          ),
        ),
      ],
    ),
  );
}

class _Respuesta extends StatelessWidget {
  final int numero;
  final Map<String, dynamic> r;
  const _Respuesta({required this.numero, required this.r});

  @override
  Widget build(BuildContext context) {
    final correcta = r['es_correcta']; // true / false / null (abierta sin calificar)
    final (icono, fondo) = correcta == true
        ? (Icons.check_circle_rounded, Paleta.verdeSuave)
        : correcta == false
        ? (Icons.cancel_rounded, Paleta.coralSuave)
        : (Icons.edit_note_rounded, Paleta.mielSuave);

    final seleccionadas = List<Map<String, dynamic>>.from(
      (r['opciones_seleccionadas'] as List?) ?? const [],
    );
    final texto = '${r['texto_respuesta'] ?? ''}'.trim();
    final miRespuesta = r['tipo'] == 'abierta'
        ? (texto.isEmpty ? 'Sin responder' : texto)
        : (seleccionadas.isEmpty
              ? 'Sin responder'
              : seleccionadas.map((o) => '${o['texto']}').join(', '));
    final correctas = List<Map<String, dynamic>>.from(
      (r['opciones_correctas'] as List?) ?? const [],
    );

    return PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(icono, fondo: fondo, tam: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$numero. ${r['enunciado'] ?? ''}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${formatearNota(r['puntaje_obtenido'])}/'
                '${formatearNota(r['puntaje_maximo'])}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Paleta.tintaSuave,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _Linea('Tu respuesta', miRespuesta),
          if (correcta == false && correctas.isNotEmpty) ...[
            const SizedBox(height: 6),
            _Linea(
              correctas.length == 1 ? 'Respuesta correcta' : 'Respuestas correctas',
              correctas.map((o) => '${o['texto']}').join(', '),
            ),
          ],
        ],
      ),
    );
  }
}

class _Linea extends StatelessWidget {
  final String etiqueta;
  final String texto;
  const _Linea(this.etiqueta, this.texto);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        etiqueta,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Paleta.tintaSuave,
        ),
      ),
      Text(texto, style: const TextStyle(height: 1.3)),
    ],
  );
}
