import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';

const _colores = [
  Paleta.verdeSuave,
  Paleta.cieloSuave,
  Paleta.mielSuave,
  Paleta.lilaSuave,
  Paleta.coralSuave,
];

class AdminMateriasPage extends StatefulWidget {
  final ApiService api;
  const AdminMateriasPage({super.key, required this.api});

  @override
  State<AdminMateriasPage> createState() => _AdminMateriasPageState();
}

class _AdminMateriasPageState extends State<AdminMateriasPage> {
  final _lista = GlobalKey<ListaPaginadaState>();
  String _buscar = '';

  Future<void> _abrirHoja([Map<String, dynamic>? m]) async {
    final cambio = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MateriaHoja(api: widget.api, materia: m),
    );
    if (cambio == true) _lista.currentState?.recargar();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: FloatingActionButton.extended(
      heroTag: null,
      onPressed: () => _abrirHoja(),
      icon: const Icon(Icons.add_rounded),
      label: const Text('Nueva materia'),
    ),
    body: Column(
      children: [
        const CabeceraSeccion(
          titulo: 'Materias',
          subtitulo: 'Organiza los bancos y exámenes',
          icono: Icons.menu_book_rounded,
          seccion: Seccion.materias,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: CampoBusqueda(
            hint: 'Buscar materia',
            onCambio: (v) => setState(() => _buscar = v),
          ),
        ),
        Expanded(
          child: ListaPaginada(
            key: _lista,
            filtro: _buscar,
            cargar: (p) => widget.api.materiasPagina(p, buscar: _buscar),
            itemBuilder: (_, m) {
              final id = m['id'] as int;
              final desc = '${m['descripcion'] ?? ''}'.trim();
              return PanelCard(
                onTap: () => _abrirHoja(m),
                child: Row(
                  children: [
                    IconBadge(
                      Icons.menu_book_rounded,
                      fondo: _colores[id % _colores.length],
                      tam: 46,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${m['nombre']}',
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
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Paleta.tintaSuave,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Paleta.tintaSuave,
                    ),
                  ],
                ),
              );
            },
            vacio: const EstadoVacio(
              titulo: 'Aún no hay materias',
              mensaje: 'Crea la primera con el botón “Nueva materia”.',
            ),
          ),
        ),
      ],
    ),
  );
}

class _MateriaHoja extends StatefulWidget {
  final ApiService api;
  final Map<String, dynamic>? materia;
  const _MateriaHoja({required this.api, this.materia});

  @override
  State<_MateriaHoja> createState() => _MateriaHojaState();
}

class _MateriaHojaState extends State<_MateriaHoja> {
  final _form = GlobalKey<FormState>();
  late final nombre = TextEditingController(
    text: widget.materia?['nombre'] as String? ?? '',
  );
  late final desc = TextEditingController(
    text: widget.materia?['descripcion'] as String? ?? '',
  );
  bool _trabajando = false;
  String? _error;

  bool get _editando => widget.materia != null;

  @override
  void dispose() {
    nombre.dispose();
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
      'nombre': nombre.text.trim(),
      'descripcion': desc.text.trim(),
    };
    try {
      if (_editando) {
        await widget.api.actualizarMateria(widget.materia!['id'] as int, datos);
      } else {
        await widget.api.crearMateria(datos);
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
      titulo: 'Eliminar materia',
      mensaje:
          '¿Eliminar “${widget.materia!['nombre']}”? '
          'Si tiene bancos o exámenes asociados, no se podrá borrar.',
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
      await widget.api.eliminarMateria(widget.materia!['id'] as int);
      if (mounted) Navigator.pop(context, true);
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
                _editando ? Icons.edit_rounded : Icons.add_rounded,
                fondo: Paleta.mielSuave,
                tam: 44,
              ),
              const SizedBox(width: 12),
              Text(
                _editando ? 'Editar materia' : 'Nueva materia',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: nombre,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              prefixIcon: Icon(Icons.menu_book_outlined),
            ),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Escribe el nombre' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: desc,
            maxLength: 255,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Descripción (opcional)',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          if (_error != null)
            Container(
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
                      _error!,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
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
              label: const Text('Eliminar materia'),
            ),
          ],
        ],
      ),
    ),
  );
}
