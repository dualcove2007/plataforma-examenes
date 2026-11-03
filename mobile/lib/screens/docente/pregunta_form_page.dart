import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/docente_ui.dart';
import '../../widgets/ui.dart';

class _Opcion {
  final TextEditingController c;
  bool correcta;
  _Opcion([String texto = '', this.correcta = false])
    : c = TextEditingController(text: texto);
}

/// Crear o editar una pregunta. Las opciones cambian según el tipo:
/// única, múltiple, verdadero/falso o abierta (sin opciones).
class PreguntaFormPage extends StatefulWidget {
  final ApiService api;
  final Map<String, dynamic> banco;
  final Map<String, dynamic>? pregunta;
  const PreguntaFormPage({
    super.key,
    required this.api,
    required this.banco,
    this.pregunta,
  });

  @override
  State<PreguntaFormPage> createState() => _PreguntaFormPageState();
}

class _PreguntaFormPageState extends State<PreguntaFormPage> {
  final _form = GlobalKey<FormState>();
  late final enunciado = TextEditingController(
    text: widget.pregunta?['enunciado'] as String? ?? '',
  );
  late final puntaje = TextEditingController(
    text: formatearPuntaje(widget.pregunta?['puntaje'] ?? 1),
  );
  late String tipo = widget.pregunta?['tipo'] as String? ?? 'opcion_unica';
  late String dificultad =
      widget.pregunta?['dificultad'] as String? ?? 'media';
  late bool activa = widget.pregunta?['activo'] != false;
  bool verdaderoEsCorrecto = true;
  final opciones = <_Opcion>[];
  bool _trabajando = false;
  String? _error;

  bool get _editando => widget.pregunta != null;
  bool get _conOpciones => tipo == 'opcion_unica' || tipo == 'opcion_multiple';

  @override
  void initState() {
    super.initState();
    final guardadas = List<Map<String, dynamic>>.from(
      (widget.pregunta?['opciones'] as List?) ?? const [],
    );
    if (tipo == 'verdadero_falso') {
      final correcta = guardadas.where((o) => o['es_correcta'] == true);
      if (correcta.isNotEmpty) {
        verdaderoEsCorrecto = '${correcta.first['texto']}'
            .toLowerCase()
            .startsWith('verdad');
      }
    } else if (_conOpciones) {
      for (final o in guardadas) {
        opciones.add(_Opcion('${o['texto']}', o['es_correcta'] == true));
      }
    }
    _asegurarMinimo();
  }

  @override
  void dispose() {
    enunciado.dispose();
    puntaje.dispose();
    for (final o in opciones) {
      o.c.dispose();
    }
    super.dispose();
  }

  void _asegurarMinimo() {
    if (!_conOpciones) return;
    while (opciones.length < 2) {
      opciones.add(_Opcion());
    }
  }

  void _cambiarTipo(String nuevo) {
    if (nuevo == tipo) return;
    setState(() {
      tipo = nuevo;
      if (nuevo == 'opcion_unica') {
        // Solo puede quedar una respuesta correcta.
        var vista = false;
        for (final o in opciones) {
          if (o.correcta && vista) o.correcta = false;
          if (o.correcta) vista = true;
        }
      }
      _asegurarMinimo();
    });
  }

  void _marcar(int i) => setState(() {
    if (tipo == 'opcion_unica') {
      for (var j = 0; j < opciones.length; j++) {
        opciones[j].correcta = j == i;
      }
    } else {
      opciones[i].correcta = !opciones[i].correcta;
    }
  });

  void _agregar() => setState(() => opciones.add(_Opcion()));

  void _quitar(int i) => setState(() {
    opciones.removeAt(i).c.dispose();
  });

  /// Devuelve el mensaje de error de las opciones, o null si están bien.
  String? _validarOpciones(List<_Opcion> llenas) {
    if (llenas.length < 2) return 'Escribe al menos 2 opciones.';
    final correctas = llenas.where((o) => o.correcta).length;
    if (tipo == 'opcion_unica' && correctas != 1) {
      return 'Marca exactamente 1 opción correcta.';
    }
    if (tipo == 'opcion_multiple' && correctas < 1) {
      return 'Marca al menos 1 opción correcta.';
    }
    return null;
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;

    final pts = double.tryParse(puntaje.text.trim().replaceAll(',', '.'));
    if (pts == null || pts <= 0) {
      setState(() => _error = 'El puntaje debe ser mayor que 0.');
      return;
    }

    List<Map<String, dynamic>> ops;
    if (tipo == 'abierta') {
      ops = [];
    } else if (tipo == 'verdadero_falso') {
      ops = [
        {'texto': 'Verdadero', 'es_correcta': verdaderoEsCorrecto},
        {'texto': 'Falso', 'es_correcta': !verdaderoEsCorrecto},
      ];
    } else {
      final llenas = opciones.where((o) => o.c.text.trim().isNotEmpty).toList();
      final problema = _validarOpciones(llenas);
      if (problema != null) {
        setState(() => _error = problema);
        return;
      }
      ops = [
        for (final o in llenas)
          {'texto': o.c.text.trim(), 'es_correcta': o.correcta},
      ];
    }

    setState(() {
      _trabajando = true;
      _error = null;
    });
    final datos = <String, dynamic>{
      if (!_editando) 'banco': widget.banco['id'],
      'enunciado': enunciado.text.trim(),
      'tipo': tipo,
      'dificultad': dificultad,
      'puntaje': pts,
      'opciones': ops,
      if (_editando) 'activo': activa,
    };
    try {
      if (_editando) {
        await widget.api.actualizarPregunta(
          widget.pregunta!['id'] as int,
          datos,
        );
      } else {
        await widget.api.crearPregunta(datos);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = mensajeError(e));
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  Future<void> _eliminar() async {
    final ok = await confirmar(
      context,
      titulo: 'Eliminar pregunta',
      mensaje:
          '¿Eliminar esta pregunta? Si ya se usó en un examen, '
          'solo se desactivará para conservar el historial.',
      textoConfirmar: 'Eliminar',
      icono: Icons.delete_rounded,
      peligro: true,
    );
    if (!ok || !mounted) return;
    setState(() {
      _trabajando = true;
      _error = null;
    });
    try {
      final mensaje = await widget.api.eliminarPregunta(
        widget.pregunta!['id'] as int,
      );
      if (!mounted) return;
      final nav = Navigator.of(context);
      mostrarAviso(context, mensaje);
      nav.pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = mensajeError(e));
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: Column(
        children: [
          CabeceraSeccion(
            titulo: _editando ? 'Editar pregunta' : 'Nueva pregunta',
            subtitulo: '${widget.banco['titulo']}',
            icono: _editando ? Icons.edit_rounded : Icons.add_comment_rounded,
            seccion: Seccion.catalogo,
            leading: botonVolver(context),
          ),
          Expanded(
            child: Form(
              key: _form,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                children: [
                  const TituloBloque('Tipo de pregunta', Icons.category_rounded),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in tiposPregunta.entries)
                        ChoiceChip(
                          avatar: Icon(e.value.icono, size: 18),
                          label: Text(e.value.texto),
                          selected: tipo == e.key,
                          onSelected: (_) => _cambiarTipo(e.key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: enunciado,
                    minLines: 3,
                    maxLines: 8,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Enunciado',
                      alignLabelWithHint: true,
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(bottom: 52),
                        child: Icon(Icons.help_outline_rounded),
                      ),
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Escribe la pregunta' : null,
                  ),
                  const SizedBox(height: 20),
                  const TituloBloque('Dificultad', Icons.speed_rounded),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in dificultades.entries)
                        ChoiceChip(
                          avatar: Icon(e.value.icono, size: 18),
                          label: Text(e.value.texto),
                          selected: dificultad == e.key,
                          onSelected: (_) => setState(() => dificultad = e.key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: puntaje,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Puntaje',
                      prefixIcon: Icon(Icons.star_outline_rounded),
                    ),
                    validator: (v) {
                      final n = double.tryParse(
                        (v ?? '').trim().replaceAll(',', '.'),
                      );
                      return n == null || n <= 0 ? 'Escribe un puntaje > 0' : null;
                    },
                  ),
                  const SizedBox(height: 22),
                  ..._bloqueRespuestas(t),
                  if (_editando)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Pregunta activa',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text(
                        'Las inactivas no se pueden agregar a exámenes',
                      ),
                      value: activa,
                      onChanged: (v) => setState(() => activa = v),
                    ),
                  const SizedBox(height: 10),
                  if (_error != null) CajaError(_error!),
                  FilledButton.icon(
                    onPressed: _trabajando ? null : _guardar,
                    icon: const Icon(Icons.save_rounded),
                    label: Text(_trabajando ? 'Guardando...' : 'Guardar pregunta'),
                  ),
                  if (_editando) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _trabajando ? null : _eliminar,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        foregroundColor: const Color(0xFFB3261E),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Eliminar pregunta'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _bloqueRespuestas(TextTheme t) {
    if (tipo == 'abierta') {
      return [
        PanelCard(
          color: Paleta.lilaSuave,
          child: const Row(
            children: [
              Icon(Icons.edit_note_rounded, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Las preguntas abiertas no llevan opciones: tú las calificas '
                  'a mano cuando el estudiante responde.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ];
    }

    if (tipo == 'verdadero_falso') {
      return [
        const TituloBloque('¿Cuál es la respuesta correcta?', Icons.rule_rounded),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _OpcionVF(
                texto: 'Verdadero',
                icono: Icons.check_circle_rounded,
                seleccionada: verdaderoEsCorrecto,
                color: Paleta.verdeSuave,
                onTap: () => setState(() => verdaderoEsCorrecto = true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _OpcionVF(
                texto: 'Falso',
                icono: Icons.cancel_rounded,
                seleccionada: !verdaderoEsCorrecto,
                color: Paleta.coralSuave,
                onTap: () => setState(() => verdaderoEsCorrecto = false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ];
    }

    final multiple = tipo == 'opcion_multiple';
    return [
      TituloBloque(
        multiple ? 'Opciones (marca las correctas)' : 'Opciones (marca la correcta)',
        Icons.list_alt_rounded,
      ),
      const SizedBox(height: 10),
      for (var i = 0; i < opciones.length; i++)
        Padding(
          key: ObjectKey(opciones[i]),
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Marcar como correcta',
                onPressed: () => _marcar(i),
                icon: Icon(
                  multiple
                      ? (opciones[i].correcta
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded)
                      : (opciones[i].correcta
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded),
                  color: opciones[i].correcta ? Paleta.verde : Paleta.tintaSuave,
                ),
              ),
              Expanded(
                child: TextFormField(
                  controller: opciones[i].c,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: [LengthLimitingTextInputFormatter(500)],
                  decoration: InputDecoration(labelText: 'Opción ${i + 1}'),
                ),
              ),
              if (opciones.length > 2)
                IconButton(
                  tooltip: 'Quitar opción',
                  onPressed: () => _quitar(i),
                  icon: const Icon(Icons.close_rounded),
                  color: Paleta.tintaSuave,
                ),
            ],
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: opciones.length >= 8 ? null : _agregar,
          icon: const Icon(Icons.add_circle_outline_rounded),
          label: const Text('Agregar opción'),
        ),
      ),
      const SizedBox(height: 8),
    ];
  }
}

class _OpcionVF extends StatelessWidget {
  final String texto;
  final IconData icono;
  final bool seleccionada;
  final Color color;
  final VoidCallback onTap;
  const _OpcionVF({
    required this.texto,
    required this.icono,
    required this.seleccionada,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => PanelCard(
    onTap: onTap,
    color: seleccionada ? color : Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Column(
      children: [
        Icon(icono, size: 32, color: seleccionada ? Paleta.tinta : Paleta.tintaSuave),
        const SizedBox(height: 6),
        Text(
          texto,
          style: TextStyle(
            fontWeight: seleccionada ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
