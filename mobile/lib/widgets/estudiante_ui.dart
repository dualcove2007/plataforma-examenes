import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ui.dart';

/// Igual que NOTA_APROBATORIA del backend (core/settings/base.py).
const notaAprobatoria = 3.0;

// ───────────────────────── Notas y fechas ─────────────────────────

/// El backend manda los decimales como texto ("4.50"); esto acepta ambos.
double? aNumero(dynamic v) => v == null ? null : double.tryParse('$v');

/// "4.50" → "4.5", "3.75" → "3.75", null → "—".
String formatearNota(dynamic v) {
  final n = aNumero(v);
  if (n == null) return '—';
  return n.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
}

/// true/false si hay nota; null si todavía no se puede saber.
bool? aprobo(dynamic nota) {
  final n = aNumero(nota);
  return n == null ? null : n >= notaAprobatoria;
}

/// "35 min", "5 h", "3 d".
String tiempoHasta(DateTime fin, [DateTime? ahora]) {
  final d = fin.difference(ahora ?? DateTime.now());
  if (d.isNegative) return '0 min';
  if (d.inMinutes < 60) return '${d.inMinutes < 1 ? 1 : d.inMinutes} min';
  if (d.inHours < 24) return '${d.inHours} h';
  return '${d.inDays} d';
}

// ───────────────────────── Estado de un examen ─────────────────────────

enum FaseExamen { enCurso, disponible, proximo, cerrado, completado }

class EstadoExamen {
  final FaseExamen fase;
  final String texto;
  final IconData icono;
  final Color color;
  final Color suave;
  const EstadoExamen(this.fase, this.texto, this.icono, this.color, this.suave);

  /// Se puede entrar a presentarlo (o continuar) ahora mismo.
  bool get abierto => fase == FaseExamen.enCurso || fase == FaseExamen.disponible;
}

/// Calcula en qué punto está una asignación. Espera el mapa que arma
/// `ApiService.examenesConIntentos()` (trae `usados` y `en_curso`).
/// La palabra final siempre la tiene el servidor; esto solo ordena la pantalla.
EstadoExamen estadoExamen(Map<String, dynamic> e, [DateTime? ahora]) {
  final t = ahora ?? DateTime.now();
  final usados = (e['usados'] as int?) ?? 0;
  final permitidos = (e['intentos_permitidos'] as int?) ?? 1;
  final inicio = DateTime.tryParse('${e['fecha_inicio']}')?.toLocal();
  final fin = DateTime.tryParse('${e['fecha_fin']}')?.toLocal();
  final cerrado =
      e['examen_estado'] != 'publicado' || (fin != null && t.isAfter(fin));

  if (e['en_curso'] == true && !cerrado) {
    return const EstadoExamen(
      FaseExamen.enCurso,
      'En curso',
      Icons.play_circle_rounded,
      Paleta.cielo,
      Paleta.cieloSuave,
    );
  }
  if (usados >= permitidos) {
    return const EstadoExamen(
      FaseExamen.completado,
      'Completado',
      Icons.task_alt_rounded,
      Paleta.lila,
      Paleta.lilaSuave,
    );
  }
  if (cerrado) {
    return const EstadoExamen(
      FaseExamen.cerrado,
      'Cerrado',
      Icons.lock_clock_rounded,
      Paleta.coral,
      Paleta.coralSuave,
    );
  }
  if (inicio != null && t.isBefore(inicio)) {
    return const EstadoExamen(
      FaseExamen.proximo,
      'Próximo',
      Icons.schedule_rounded,
      Paleta.miel,
      Paleta.mielSuave,
    );
  }
  return const EstadoExamen(
    FaseExamen.disponible,
    'Disponible',
    Icons.rocket_launch_rounded,
    Paleta.verde,
    Paleta.verdeSuave,
  );
}

// ───────────────────────── Materias: ícono y color ─────────────────────────

IconData iconoMateria(String nombre) {
  final n = nombre.toLowerCase();
  bool tiene(List<String> palabras) => palabras.any(n.contains);
  if (tiene(['mate', 'cálcul', 'calcul', 'álgebra', 'algebra', 'estadíst'])) {
    return Icons.calculate_rounded;
  }
  if (tiene(['inglés', 'ingles', 'idioma', 'lengua', 'lenguaje', 'español'])) {
    return Icons.translate_rounded;
  }
  if (tiene(['física', 'fisica', 'quím', 'quim', 'ciencia'])) {
    return Icons.science_rounded;
  }
  if (tiene(['biolog'])) return Icons.biotech_rounded;
  if (tiene(['histor', 'social', 'geograf'])) return Icons.public_rounded;
  if (tiene(['program', 'inform', 'sistema', 'software', 'datos', 'redes'])) {
    return Icons.computer_rounded;
  }
  if (tiene(['arte', 'dibujo', 'diseño', 'diseno', 'música', 'musica'])) {
    return Icons.palette_rounded;
  }
  if (tiene(['ética', 'etica', 'filosof', 'psicolog'])) {
    return Icons.psychology_rounded;
  }
  return Icons.menu_book_rounded;
}

const _coloresMateria = [
  Paleta.verdeSuave,
  Paleta.cieloSuave,
  Paleta.mielSuave,
  Paleta.lilaSuave,
  Paleta.coralSuave,
];

/// Color suave que rota según la posición, para que las listas no sean grises.
Color colorSuaveMateria(int indice) =>
    _coloresMateria[indice % _coloresMateria.length];

// ───────────────────────── Piezas ─────────────────────────

/// Ícono pequeño con texto ("30 min", "10 preguntas").
class DatoIcono extends StatelessWidget {
  final IconData icono;
  final String texto;
  const DatoIcono(this.icono, this.texto, {super.key});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icono, size: 16, color: Paleta.tintaSuave),
      const SizedBox(width: 4),
      Text(
        texto,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Paleta.tintaSuave,
        ),
      ),
    ],
  );
}

/// Círculo con la nota: verde si aprobó, coral si no, miel si está pendiente.
class NotaCirculo extends StatelessWidget {
  final dynamic nota;
  final double tam;
  const NotaCirculo(this.nota, {super.key, this.tam = 56});

  @override
  Widget build(BuildContext context) {
    final ap = aprobo(nota);
    final fondo = ap == null
        ? Paleta.mielSuave
        : ap
        ? Paleta.verdeSuave
        : Paleta.coralSuave;
    final borde = ap == null
        ? Paleta.miel
        : ap
        ? Paleta.verde
        : Paleta.coral;
    return Container(
      width: tam,
      height: tam,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fondo,
        shape: BoxShape.circle,
        border: Border.all(color: borde, width: 3),
      ),
      child: ap == null
          ? Icon(Icons.hourglass_top_rounded, size: tam * 0.42)
          : Text(
              formatearNota(nota),
              style: TextStyle(
                fontSize: tam * 0.34,
                fontWeight: FontWeight.w800,
                color: Paleta.tinta,
              ),
            ),
    );
  }
}

/// "Aprobado", "Reprobado" o "En revisión" según la nota y el estado de revisión.
Widget etiquetaResultado(dynamic nota, String? revision) {
  final ap = aprobo(nota);
  if (ap == true) {
    return const Etiqueta(
      'Aprobado',
      icono: Icons.check_circle_rounded,
      fondo: Paleta.verdeSuave,
    );
  }
  if (ap == false) {
    return const Etiqueta(
      'Reprobado',
      icono: Icons.cancel_rounded,
      fondo: Paleta.coralSuave,
    );
  }
  return Etiqueta(
    revision == 'en_revision' ? 'En revisión' : 'Por revisar',
    icono: Icons.hourglass_top_rounded,
    fondo: Paleta.mielSuave,
  );
}

/// Tarjeta de un examen asignado.
class TarjetaExamen extends StatelessWidget {
  final Map<String, dynamic> examen;
  final VoidCallback? onTap;
  const TarjetaExamen({super.key, required this.examen, this.onTap});

  String _pie(EstadoExamen est) {
    final inicio = DateTime.tryParse('${examen['fecha_inicio']}')?.toLocal();
    final fin = DateTime.tryParse('${examen['fecha_fin']}')?.toLocal();
    switch (est.fase) {
      case FaseExamen.enCurso:
      case FaseExamen.disponible:
        return fin == null
            ? 'Disponible ahora'
            : 'Cierra en ${tiempoHasta(fin)} · ${fechaCorta('${examen['fecha_fin']}')}';
      case FaseExamen.proximo:
        return inicio == null
            ? 'Próximamente'
            : 'Abre ${fechaCorta('${examen['fecha_inicio']}')}';
      case FaseExamen.cerrado:
        return fin == null
            ? 'Cerrado'
            : 'Cerró ${fechaCorta('${examen['fecha_fin']}')}';
      case FaseExamen.completado:
        return 'Ya usaste todos tus intentos';
    }
  }

  @override
  Widget build(BuildContext context) {
    final est = estadoExamen(examen);
    final usados = (examen['usados'] as int?) ?? 0;
    final permitidos = (examen['intentos_permitidos'] as int?) ?? 1;
    final t = Theme.of(context).textTheme;
    return PanelCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(
                iconoMateria('${examen['materia'] ?? ''}'),
                fondo: est.suave,
                tam: 46,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${examen['titulo'] ?? ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${examen['materia'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Paleta.tintaSuave),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Etiqueta(est.texto, icono: est.icono, fondo: est.suave),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              DatoIcono(
                Icons.timer_rounded,
                '${examen['duracion_minutos']} min',
              ),
              DatoIcono(
                Icons.quiz_rounded,
                '${examen['total_preguntas']} preguntas',
              ),
              DatoIcono(Icons.replay_rounded, 'Intentos $usados/$permitidos'),
            ],
          ),
          const Divider(height: 22),
          Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                size: 18,
                color: Paleta.tintaSuave,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _pie(est),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Paleta.tintaSuave,
                  ),
                ),
              ),
              if (est.abierto)
                Icon(Icons.arrow_forward_rounded, color: est.color),
            ],
          ),
        ],
      ),
    );
  }
}
