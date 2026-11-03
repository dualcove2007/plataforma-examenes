import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ui.dart';

// ───────────────────────── Preguntas ─────────────────────────

class EstiloTipo {
  final String texto;
  final IconData icono;
  final Color suave;
  const EstiloTipo(this.texto, this.icono, this.suave);
}

const tiposPregunta = <String, EstiloTipo>{
  'opcion_unica': EstiloTipo(
    'Opción única',
    Icons.radio_button_checked_rounded,
    Paleta.verdeSuave,
  ),
  'opcion_multiple': EstiloTipo(
    'Opción múltiple',
    Icons.checklist_rounded,
    Paleta.cieloSuave,
  ),
  'verdadero_falso': EstiloTipo(
    'Verdadero o falso',
    Icons.rule_rounded,
    Paleta.mielSuave,
  ),
  'abierta': EstiloTipo('Abierta', Icons.edit_note_rounded, Paleta.lilaSuave),
};

EstiloTipo estiloTipo(String? tipo) =>
    tiposPregunta[tipo] ??
    const EstiloTipo('Pregunta', Icons.help_outline_rounded, Paleta.crema);

const dificultades = <String, EstiloTipo>{
  'facil': EstiloTipo(
    'Fácil',
    Icons.sentiment_satisfied_rounded,
    Paleta.verdeSuave,
  ),
  'media': EstiloTipo(
    'Media',
    Icons.sentiment_neutral_rounded,
    Paleta.mielSuave,
  ),
  'dificil': EstiloTipo(
    'Difícil',
    Icons.local_fire_department_rounded,
    Paleta.coralSuave,
  ),
};

EstiloTipo estiloDificultad(String? d) =>
    dificultades[d] ??
    const EstiloTipo('Media', Icons.sentiment_neutral_rounded, Paleta.mielSuave);

/// "2.0" → "2", "1.5" → "1.5".
String formatearPuntaje(dynamic v) {
  final n = v is num ? v.toDouble() : double.tryParse('$v');
  if (n == null) return '—';
  return n == n.roundToDouble()
      ? n.toStringAsFixed(0)
      : n.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
}

// ───────────────────────── Exámenes ─────────────────────────

class EstiloEstadoExamen {
  final String texto;
  final IconData icono;
  final Color suave;
  const EstiloEstadoExamen(this.texto, this.icono, this.suave);
}

EstiloEstadoExamen estiloEstadoExamen(String? estado) {
  switch (estado) {
    case 'publicado':
      return const EstiloEstadoExamen(
        'Publicado',
        Icons.rocket_launch_rounded,
        Paleta.verdeSuave,
      );
    case 'cerrado':
      return const EstiloEstadoExamen(
        'Cerrado',
        Icons.lock_rounded,
        Paleta.coralSuave,
      );
    case 'archivado':
      return const EstiloEstadoExamen(
        'Archivado',
        Icons.inventory_2_rounded,
        Paleta.lilaSuave,
      );
    default:
      return const EstiloEstadoExamen(
        'Borrador',
        Icons.edit_note_rounded,
        Paleta.mielSuave,
      );
  }
}

// ───────────────────────── Revisión de resultados ─────────────────────────

EstiloEstadoExamen estiloRevision(String? estado) {
  switch (estado) {
    case 'revisado':
      return const EstiloEstadoExamen(
        'Revisado',
        Icons.verified_rounded,
        Paleta.verdeSuave,
      );
    case 'en_revision':
      return const EstiloEstadoExamen(
        'En revisión',
        Icons.hourglass_top_rounded,
        Paleta.cieloSuave,
      );
    default:
      return const EstiloEstadoExamen(
        'Pendiente',
        Icons.pending_actions_rounded,
        Paleta.mielSuave,
      );
  }
}

// ───────────────────────── Piezas comunes ─────────────────────────

/// Caja roja con el mensaje de error de un formulario.
class CajaError extends StatelessWidget {
  final String mensaje;
  const CajaError(this.mensaje, {super.key});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Paleta.coralSuave,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_rounded, color: Color(0xFFB3261E)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            mensaje,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

/// Botón "volver" para las cabeceras de pantallas que se abren encima.
Widget botonVolver(BuildContext context) => IconButton(
  tooltip: 'Volver',
  icon: const Icon(Icons.arrow_back_rounded),
  onPressed: () => Navigator.of(context).pop(),
);

/// Título de bloque dentro de una pantalla.
class TituloBloque extends StatelessWidget {
  final String texto;
  final IconData icono;
  final Widget? accion;
  const TituloBloque(this.texto, this.icono, {super.key, this.accion});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icono, size: 20, color: Paleta.tintaSuave),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          texto,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      if (accion != null) accion!,
    ],
  );
}

/// Campo de solo lectura que abre un selector de fecha y hora.
class CampoFechaHora extends StatelessWidget {
  final String etiqueta;
  final IconData icono;
  final DateTime? valor;
  final ValueChanged<DateTime> onCambio;
  const CampoFechaHora({
    super.key,
    required this.etiqueta,
    required this.icono,
    required this.valor,
    required this.onCambio,
  });

  Future<void> _elegir(BuildContext context) async {
    final ahora = DateTime.now();
    final base = valor ?? ahora;
    final fecha = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(ahora.year - 1),
      lastDate: DateTime(ahora.year + 3),
    );
    if (fecha == null || !context.mounted) return;
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (hora == null) return;
    onCambio(
      DateTime(fecha.year, fecha.month, fecha.day, hora.hour, hora.minute),
    );
  }

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: () => _elegir(context),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: etiqueta,
        prefixIcon: Icon(icono),
        suffixIcon: const Icon(Icons.edit_calendar_rounded),
      ),
      child: Text(
        valor == null ? 'Toca para elegir' : fechaCorta(valor!.toIso8601String()),
        style: TextStyle(
          color: valor == null ? Paleta.tintaSuave : Paleta.tinta,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
