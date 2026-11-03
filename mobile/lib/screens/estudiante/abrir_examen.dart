import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/estudiante_ui.dart';
import '../../widgets/ui.dart';
import 'examen_page.dart';

/// Punto de entrada único para presentar un examen (lo usan Inicio y Mis exámenes).
///
/// - Si el examen está abierto, muestra una hoja con las reglas y, al confirmar,
///   abre la pantalla del examen. Devuelve cuando el estudiante vuelve.
/// - Si no está abierto, avisa por qué.
///
/// El llamador debe recargar sus datos al terminar `await abrirExamen(...)`.
Future<void> abrirExamen(
  BuildContext context,
  ApiService api,
  Map<String, dynamic> examen,
) async {
  final est = estadoExamen(examen);
  if (!est.abierto) {
    mostrarAviso(context, _motivo(examen, est), error: true);
    return;
  }
  final comenzar = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _HojaIntro(examen: examen, est: est),
  );
  if (comenzar != true || !context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ExamenPage(
        api: api,
        asignacionId: examen['id'] as int,
        titulo: '${examen['titulo']}',
      ),
    ),
  );
}

String _motivo(Map<String, dynamic> e, EstadoExamen est) {
  switch (est.fase) {
    case FaseExamen.proximo:
      return 'Este examen abre el ${fechaCorta('${e['fecha_inicio']}')}.';
    case FaseExamen.completado:
      return 'Ya usaste todos tus intentos de este examen.';
    default:
      return 'Este examen ya cerró.';
  }
}

class _HojaIntro extends StatelessWidget {
  final Map<String, dynamic> examen;
  final EstadoExamen est;
  const _HojaIntro({required this.examen, required this.est});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final usados = (examen['usados'] as int?) ?? 0;
    final permitidos = (examen['intentos_permitidos'] as int?) ?? 1;
    final retoma = est.fase == FaseExamen.enCurso;
    final restantes = permitidos - usados;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBadge(
                  iconoMateria('${examen['materia'] ?? ''}'),
                  fondo: est.suave,
                  tam: 52,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${examen['titulo'] ?? ''}',
                        style: t.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${examen['materia'] ?? ''}',
                        style: const TextStyle(color: Paleta.tintaSuave),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _Dato(
                    Icons.timer_rounded,
                    '${examen['duracion_minutos']} min',
                    'Duración',
                    Paleta.mielSuave,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Dato(
                    Icons.quiz_rounded,
                    '${examen['total_preguntas']}',
                    'Preguntas',
                    Paleta.cieloSuave,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Dato(
                    Icons.replay_rounded,
                    '$restantes de $permitidos',
                    'Intentos libres',
                    Paleta.lilaSuave,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Antes de empezar',
              style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const _Regla(
              Icons.hourglass_bottom_rounded,
              'El tiempo corre desde que empiezas y no se detiene aunque salgas de la app.',
            ),
            const _Regla(
              Icons.save_rounded,
              'Tus respuestas se guardan solas mientras avanzas.',
            ),
            const _Regla(
              Icons.visibility_rounded,
              'Si sales de la app durante el examen, quedará registrado y tu docente podrá verlo.',
            ),
            const _Regla(
              Icons.send_rounded,
              'Al terminar el tiempo, el examen se envía automáticamente.',
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: Icon(
                retoma ? Icons.play_arrow_rounded : Icons.rocket_launch_rounded,
              ),
              label: Text(retoma ? 'Continuar examen' : 'Comenzar examen'),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Ahora no'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  final IconData icono;
  final String valor;
  final String etiqueta;
  final Color fondo;
  const _Dato(this.icono, this.valor, this.etiqueta, this.fondo);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    decoration: BoxDecoration(
      color: fondo,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Icon(icono, size: 22),
        const SizedBox(height: 6),
        Text(
          valor,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        Text(
          etiqueta,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Paleta.tintaSuave,
          ),
        ),
      ],
    ),
  );
}

class _Regla extends StatelessWidget {
  final IconData icono;
  final String texto;
  const _Regla(this.icono, this.texto);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 20, color: Paleta.verde),
        const SizedBox(width: 10),
        Expanded(
          child: Text(texto, style: const TextStyle(height: 1.3)),
        ),
      ],
    ),
  );
}
