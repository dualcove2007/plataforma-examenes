import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/docente_ui.dart';
import '../../widgets/estudiante_ui.dart';
import '../../widgets/ui.dart';
import 'preguntas_page.dart';

/// Bancos de preguntas del docente (agrupan preguntas por materia).
class BancosPage extends StatefulWidget {
  final ApiService api;
  const BancosPage({super.key, required this.api});

  @override
  State<BancosPage> createState() => _BancosPageState();
}

class _BancosPageState extends State<BancosPage> {
  final _lista = GlobalKey<ListaPaginadaState>();
  String _buscar = '';
  bool? _activo = true;

  Future<void> _abrirHoja([Map<String, dynamic>? banco]) async {
    final cambio = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BancoHoja(api: widget.api, banco: banco),
    );
    if (cambio == true) _lista.currentState?.recargar();
  }

  Future<void> _abrirPreguntas(Map<String, dynamic> banco) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PreguntasPage(api: widget.api, banco: banco),
      ),
    );
    // Al volver puede haber cambiado el total de preguntas.
    _lista.currentState?.recargar();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: FloatingActionButton.extended(
      heroTag: null,
      onPressed: () => _abrirHoja(),
      icon: const Icon(Icons.add_rounded),
      label: const Text('Nuevo banco'),
    ),
    body: Column(
      children: [
        const CabeceraSeccion(
          titulo: 'Bancos de preguntas',
          subtitulo: 'Tu biblioteca por materia',
          icono: Icons.folder_copy_rounded,
          seccion: Seccion.catalogo,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: CampoBusqueda(
            hint: 'Buscar banco',
            onCambio: (v) => setState(() => _buscar = v),
          ),
        ),
        FilaFiltros<bool?>(
          opciones: const [
            OpcionFiltro('Activos', true, Icons.check_circle_outline_rounded),
            OpcionFiltro('Inactivos', false, Icons.block_rounded),
            OpcionFiltro('Todos', null, Icons.layers_rounded),
          ],
          valor: _activo,
          onCambio: (v) => setState(() => _activo = v),
        ),
        Expanded(
          child: ListaPaginada(
            key: _lista,
            filtro: '$_buscar|$_activo',
            cargar: (p) =>
                widget.api.bancosPagina(p, buscar: _buscar, activo: _activo),
            itemBuilder: (_, b) {
              final total = (b['total_preguntas'] as int?) ?? 0;
              final activo = b['activo'] == true;
              final desc = '${b['descripcion'] ?? ''}'.trim();
              final materia = '${b['materia_nombre'] ?? ''}';
              final id = b['id'] as int;
              return PanelCard(
                onTap: () => _abrirPreguntas(b),
                child: Row(
                  children: [
                    IconBadge(
                      iconoMateria(materia),
                      fondo: colorSuaveMateria(id),
                      tam: 48,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${b['titulo']}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15.5,
                            ),
                          ),
                          if (desc.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                desc,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Paleta.tintaSuave,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              Etiqueta(
                                materia,
                                icono: Icons.menu_book_rounded,
                                fondo: Paleta.crema,
                              ),
                              Etiqueta(
                                '$total ${total == 1 ? 'pregunta' : 'preguntas'}',
                                icono: Icons.quiz_rounded,
                                fondo: Paleta.cieloSuave,
                              ),
                              if (!activo)
                                const Etiqueta(
                                  'Inactivo',
                                  icono: Icons.block_rounded,
                                  fondo: Paleta.coralSuave,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Editar banco',
                      icon: const Icon(Icons.edit_rounded),
                      color: Paleta.tintaSuave,
                      onPressed: () => _abrirHoja(b),
                    ),
                  ],
                ),
              );
            },
            vacio: const EstadoVacio(
              titulo: 'Aún no tienes bancos',
              mensaje:
                  'Crea un banco con “Nuevo banco” y llénalo de preguntas.',
            ),
          ),
        ),
      ],
    ),
  );
}

class _BancoHoja extends StatefulWidget {
  final ApiService api;
  final Map<String, dynamic>? banco;
  const _BancoHoja({required this.api, this.banco});

  @override
  State<_BancoHoja> createState() => _BancoHojaState();
}

class _BancoHojaState extends State<_BancoHoja> {
  final _form = GlobalKey<FormState>();
  late final titulo = TextEditingController(
    text: widget.banco?['titulo'] as String? ?? '',
  );
  late final desc = TextEditingController(
    text: widget.banco?['descripcion'] as String? ?? '',
  );
  late int? materia = widget.banco?['materia'] as int?;
  late bool activo = widget.banco?['activo'] != false;
  late final Future<List<Map<String, dynamic>>> _materias = widget.api
      .materias();
  bool _trabajando = false;
  String? _error;

  bool get _editando => widget.banco != null;

  @override
  void dispose() {
    titulo.dispose();
    desc.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _trabajando = true;
      _error = null;
    });
    final datos = {
      'materia': materia,
      'titulo': titulo.text.trim(),
      'descripcion': desc.text.trim(),
      if (_editando) 'activo': activo,
    };
    try {
      if (_editando) {
        await widget.api.actualizarBanco(widget.banco!['id'] as int, datos);
      } else {
        await widget.api.crearBanco(datos);
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
      titulo: 'Eliminar banco',
      mensaje:
          '¿Eliminar “${widget.banco!['titulo']}”? Si ya tiene preguntas, '
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
      final mensaje = await widget.api.eliminarBanco(
        widget.banco!['id'] as int,
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
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      20,
      0,
      20,
      20 + MediaQuery.of(context).viewInsets.bottom,
    ),
    child: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(
                _editando ? Icons.edit_rounded : Icons.create_new_folder_rounded,
                fondo: Paleta.lilaSuave,
                tam: 44,
              ),
              const SizedBox(width: 12),
              Text(
                _editando ? 'Editar banco' : 'Nuevo banco',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 18),
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
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Título',
              prefixIcon: Icon(Icons.folder_outlined),
            ),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Escribe el título' : null,
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: desc,
            maxLength: 255,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Descripción (opcional)',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          if (_editando)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Banco activo',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('Los inactivos no admiten preguntas nuevas'),
              value: activo,
              onChanged: (v) => setState(() => activo = v),
            ),
          const SizedBox(height: 8),
          if (_error != null) CajaError(_error!),
          FilledButton.icon(
            onPressed: _trabajando ? null : _guardar,
            icon: const Icon(Icons.save_rounded),
            label: Text(_trabajando ? 'Guardando...' : 'Guardar'),
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
              label: const Text('Eliminar banco'),
            ),
          ],
        ],
      ),
    ),
  );
}
