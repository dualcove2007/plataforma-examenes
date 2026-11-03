import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/docente_ui.dart';
import '../../widgets/ui.dart';

/// Crear o editar un examen (solo se edita en borrador).
/// Devuelve `true` al guardar.
class ExamenFormPage extends StatefulWidget {
  final ApiService api;
  final Map<String, dynamic>? examen;
  const ExamenFormPage({super.key, required this.api, this.examen});

  @override
  State<ExamenFormPage> createState() => _ExamenFormPageState();
}

class _ExamenFormPageState extends State<ExamenFormPage> {
  final _form = GlobalKey<FormState>();
  late final titulo = TextEditingController(
    text: widget.examen?['titulo'] as String? ?? '',
  );
  late final desc = TextEditingController(
    text: widget.examen?['descripcion'] as String? ?? '',
  );
  late final duracion = TextEditingController(
    text: '${widget.examen?['duracion_minutos'] ?? 60}',
  );
  late final intentos = TextEditingController(
    text: '${widget.examen?['intentos_permitidos'] ?? 1}',
  );
  late int? materia = widget.examen?['materia'] as int?;
  late DateTime? inicio = _leer(widget.examen?['fecha_inicio']) ?? _porDefecto();
  late DateTime? fin =
      _leer(widget.examen?['fecha_fin']) ??
      _porDefecto().add(const Duration(hours: 2));
  late final Future<List<Map<String, dynamic>>> _materias = widget.api
      .materias();
  bool _trabajando = false;
  String? _error;

  bool get _editando => widget.examen != null;

  static DateTime? _leer(dynamic iso) =>
      iso == null ? null : DateTime.tryParse('$iso')?.toLocal();

  /// Mañana a las 8:00, como punto de partida razonable.
  static DateTime _porDefecto() {
    final m = DateTime.now().add(const Duration(days: 1));
    return DateTime(m.year, m.month, m.day, 8);
  }

  @override
  void dispose() {
    titulo.dispose();
    desc.dispose();
    duracion.dispose();
    intentos.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    if (inicio == null || fin == null) {
      setState(() => _error = 'Elige la fecha de inicio y la de fin.');
      return;
    }
    if (!fin!.isAfter(inicio!)) {
      setState(() => _error = 'El fin debe ser posterior al inicio.');
      return;
    }
    setState(() {
      _trabajando = true;
      _error = null;
    });
    final datos = {
      'materia': materia,
      'titulo': titulo.text.trim(),
      'descripcion': desc.text.trim(),
      'fecha_inicio': inicio!.toUtc().toIso8601String(),
      'fecha_fin': fin!.toUtc().toIso8601String(),
      'duracion_minutos': int.parse(duracion.text.trim()),
      'intentos_permitidos': int.parse(intentos.text.trim()),
    };
    try {
      if (_editando) {
        await widget.api.actualizarExamen(widget.examen!['id'] as int, datos);
      } else {
        await widget.api.crearExamen(datos);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = mensajeError(e));
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  String? _entero(String? v, int min, int max, String nombre) {
    final n = int.tryParse((v ?? '').trim());
    if (n == null) return 'Escribe un número';
    if (n < min || n > max) return '$nombre: entre $min y $max';
    return null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        CabeceraSeccion(
          titulo: _editando ? 'Editar examen' : 'Nuevo examen',
          subtitulo: _editando
              ? 'Solo se edita mientras es borrador'
              : 'Luego agregas preguntas y asignas',
          icono: _editando ? Icons.edit_rounded : Icons.add_task_rounded,
          seccion: Seccion.examenes,
          leading: botonVolver(context),
        ),
        Expanded(
          child: Form(
            key: _form,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              children: [
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _materias,
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return CajaError(mensajeError(snap.error!));
                    }
                    final lista = snap.data ?? const [];
                    return DropdownButtonFormField<int>(
                      initialValue: lista.any((m) => m['id'] == materia)
                          ? materia
                          : null,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Materia',
                        prefixIcon: const Icon(Icons.menu_book_outlined),
                        helperText: snap.hasData ? null : 'Cargando materias...',
                      ),
                      items: [
                        for (final m in lista)
                          DropdownMenuItem(
                            value: m['id'] as int,
                            child: Text(
                              '${m['nombre']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => materia = v),
                      validator: (v) => v == null ? 'Elige una materia' : null,
                    );
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: titulo,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Escribe el título' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: desc,
                  minLines: 2,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Instrucciones (opcional)',
                    alignLabelWithHint: true,
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: 30),
                      child: Icon(Icons.notes_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const TituloBloque('Ventana de tiempo', Icons.event_available_rounded),
                const SizedBox(height: 10),
                CampoFechaHora(
                  etiqueta: 'Abre',
                  icono: Icons.play_circle_outline_rounded,
                  valor: inicio,
                  onCambio: (v) => setState(() => inicio = v),
                ),
                const SizedBox(height: 14),
                CampoFechaHora(
                  etiqueta: 'Cierra',
                  icono: Icons.stop_circle_outlined,
                  valor: fin,
                  onCambio: (v) => setState(() => fin = v),
                ),
                const SizedBox(height: 22),
                const TituloBloque('Reglas', Icons.tune_rounded),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: duracion,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duración (min)',
                          prefixIcon: Icon(Icons.timer_outlined),
                        ),
                        validator: (v) => _entero(v, 1, 600, 'Duración'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: intentos,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Intentos',
                          prefixIcon: Icon(Icons.replay_rounded),
                        ),
                        validator: (v) => _entero(v, 1, 10, 'Intentos'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                if (_error != null) CajaError(_error!),
                FilledButton.icon(
                  onPressed: _trabajando ? null : _guardar,
                  icon: const Icon(Icons.save_rounded),
                  label: Text(_trabajando ? 'Guardando...' : 'Guardar examen'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
