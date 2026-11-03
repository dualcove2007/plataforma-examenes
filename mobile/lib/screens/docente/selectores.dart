import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/docente_ui.dart';
import '../../widgets/ui.dart';

/// Barra inferior con el botón de confirmar la selección.
class _BarraSeleccion extends StatelessWidget {
  final int cantidad;
  final String texto;
  final VoidCallback onConfirmar;
  const _BarraSeleccion({
    required this.cantidad,
    required this.texto,
    required this.onConfirmar,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Paleta.borde, width: 1.5)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: FilledButton.icon(
          onPressed: cantidad == 0 ? null : onConfirmar,
          icon: const Icon(Icons.check_rounded),
          label: Text(cantidad == 0 ? 'Elige al menos uno' : '$texto ($cantidad)'),
        ),
      ),
    ),
  );
}

// ───────────────────────── Preguntas ─────────────────────────

/// Elige preguntas activas de la materia del examen. Devuelve la lista elegida.
class SelectorPreguntasPage extends StatefulWidget {
  final ApiService api;
  final int materiaId;
  final String materiaNombre;

  /// Ids de preguntas que ya están en el examen.
  final Set<int> yaEnExamen;
  const SelectorPreguntasPage({
    super.key,
    required this.api,
    required this.materiaId,
    required this.materiaNombre,
    required this.yaEnExamen,
  });

  @override
  State<SelectorPreguntasPage> createState() => _SelectorPreguntasPageState();
}

class _SelectorPreguntasPageState extends State<SelectorPreguntasPage> {
  final _elegidas = <int, Map<String, dynamic>>{};
  String _buscar = '';

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: _BarraSeleccion(
      cantidad: _elegidas.length,
      texto: 'Agregar al examen',
      onConfirmar: () => Navigator.pop(context, _elegidas.values.toList()),
    ),
    body: Column(
      children: [
        CabeceraSeccion(
          titulo: 'Agregar preguntas',
          subtitulo: 'De tus bancos de ${widget.materiaNombre}',
          icono: Icons.playlist_add_rounded,
          seccion: Seccion.examenes,
          leading: botonVolver(context),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: CampoBusqueda(
            hint: 'Buscar pregunta',
            onCambio: (v) => setState(() => _buscar = v),
          ),
        ),
        Expanded(
          child: ListaPaginada(
            filtro: _buscar,
            cargar: (p) => widget.api.preguntasPagina(
              p,
              materia: widget.materiaId,
              buscar: _buscar,
              activo: true,
            ),
            itemBuilder: (_, p) {
              final id = p['id'] as int;
              final yaEsta = widget.yaEnExamen.contains(id);
              final marcada = _elegidas.containsKey(id);
              final tipo = estiloTipo('${p['tipo']}');
              return PanelCard(
                color: yaEsta
                    ? Paleta.crema
                    : marcada
                    ? Paleta.verdeSuave
                    : Colors.white,
                onTap: yaEsta
                    ? null
                    : () => setState(() {
                        if (marcada) {
                          _elegidas.remove(id);
                        } else {
                          _elegidas[id] = p;
                        }
                      }),
                child: Row(
                  children: [
                    Icon(
                      yaEsta
                          ? Icons.check_circle_rounded
                          : marcada
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      color: yaEsta
                          ? Paleta.tintaSuave
                          : marcada
                          ? Paleta.verde
                          : Paleta.tintaSuave,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${p['enunciado']}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              Etiqueta(
                                tipo.texto,
                                icono: tipo.icono,
                                fondo: tipo.suave,
                              ),
                              Etiqueta(
                                '${formatearPuntaje(p['puntaje'])} pts',
                                icono: Icons.star_rounded,
                                fondo: Paleta.crema,
                              ),
                              if (yaEsta)
                                const Etiqueta(
                                  'Ya está en el examen',
                                  fondo: Paleta.mielSuave,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
            vacio: const EstadoVacio(
              titulo: 'No hay preguntas disponibles',
              mensaje:
                  'Crea preguntas en un banco de esta materia y vuelve a intentarlo.',
            ),
          ),
        ),
      ],
    ),
  );
}

// ───────────────────────── Estudiantes ─────────────────────────

/// Elige estudiantes activos para asignarles el examen. Devuelve sus ids.
class SelectorEstudiantesPage extends StatefulWidget {
  final ApiService api;

  /// Estudiantes que ya tienen el examen asignado.
  final Set<int> yaAsignados;
  const SelectorEstudiantesPage({
    super.key,
    required this.api,
    required this.yaAsignados,
  });

  @override
  State<SelectorEstudiantesPage> createState() =>
      _SelectorEstudiantesPageState();
}

class _SelectorEstudiantesPageState extends State<SelectorEstudiantesPage> {
  final _elegidos = <int>{};
  String _buscar = '';

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: _BarraSeleccion(
      cantidad: _elegidos.length,
      texto: 'Asignar',
      onConfirmar: () => Navigator.pop(context, _elegidos.toList()),
    ),
    body: Column(
      children: [
        CabeceraSeccion(
          titulo: 'Asignar estudiantes',
          subtitulo: 'Quienes podrán presentar el examen',
          icono: Icons.group_add_rounded,
          seccion: Seccion.examenes,
          leading: botonVolver(context),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: CampoBusqueda(
            hint: 'Buscar por nombre o correo',
            onCambio: (v) => setState(() => _buscar = v),
          ),
        ),
        Expanded(
          child: ListaPaginada(
            filtro: _buscar,
            cargar: (p) => widget.api.estudiantesPagina(p, buscar: _buscar),
            itemBuilder: (_, u) {
              final id = u['id'] as int;
              final yaEsta = widget.yaAsignados.contains(id);
              final marcado = _elegidos.contains(id);
              final nombre = '${u['nombre']}';
              return PanelCard(
                color: yaEsta
                    ? Paleta.crema
                    : marcado
                    ? Paleta.verdeSuave
                    : Colors.white,
                onTap: yaEsta
                    ? null
                    : () => setState(() {
                        if (marcado) {
                          _elegidos.remove(id);
                        } else {
                          _elegidos.add(id);
                        }
                      }),
                child: Row(
                  children: [
                    CircleAvatar(
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
                            '${u['email']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Paleta.tintaSuave,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (yaEsta)
                      const Etiqueta('Ya asignado', fondo: Paleta.mielSuave)
                    else
                      Icon(
                        marcado
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        color: marcado ? Paleta.verde : Paleta.tintaSuave,
                      ),
                  ],
                ),
              );
            },
            vacio: const EstadoVacio(
              titulo: 'No hay estudiantes',
              mensaje: 'No se encontraron estudiantes activos con esa búsqueda.',
            ),
          ),
        ),
      ],
    ),
  );
}
