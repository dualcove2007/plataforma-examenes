import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/docente_ui.dart';
import '../../widgets/estudiante_ui.dart';
import '../../widgets/ui.dart';
import 'examen_detalle_page.dart';
import 'examen_form_page.dart';

/// Exámenes que creó el docente.
class DocenteExamenesPage extends StatefulWidget {
  final ApiService api;
  const DocenteExamenesPage({super.key, required this.api});

  @override
  State<DocenteExamenesPage> createState() => _DocenteExamenesPageState();
}

class _DocenteExamenesPageState extends State<DocenteExamenesPage> {
  final _lista = GlobalKey<ListaPaginadaState>();
  String _buscar = '';
  String? _estado;

  Future<void> _nuevo() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ExamenFormPage(api: widget.api)),
    );
    if (ok == true) _lista.currentState?.recargar();
  }

  Future<void> _abrir(Map<String, dynamic> examen) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ExamenDetallePage(api: widget.api, examenId: examen['id'] as int),
      ),
    );
    // Pudo cambiar de estado, de título o de preguntas.
    _lista.currentState?.recargar();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: FloatingActionButton.extended(
      heroTag: null,
      onPressed: _nuevo,
      icon: const Icon(Icons.add_rounded),
      label: const Text('Nuevo examen'),
    ),
    body: Column(
      children: [
        const CabeceraSeccion(
          titulo: 'Mis exámenes',
          subtitulo: 'Crea, publica y asigna',
          icono: Icons.assignment_rounded,
          seccion: Seccion.examenes,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: CampoBusqueda(
            hint: 'Buscar examen',
            onCambio: (v) => setState(() => _buscar = v),
          ),
        ),
        FilaFiltros<String?>(
          opciones: const [
            OpcionFiltro('Todos', null, Icons.layers_rounded),
            OpcionFiltro('Borrador', 'borrador', Icons.edit_note_rounded),
            OpcionFiltro('Publicados', 'publicado', Icons.rocket_launch_rounded),
            OpcionFiltro('Cerrados', 'cerrado', Icons.lock_rounded),
            OpcionFiltro('Archivados', 'archivado', Icons.inventory_2_rounded),
          ],
          valor: _estado,
          onCambio: (v) => setState(() => _estado = v),
        ),
        Expanded(
          child: ListaPaginada(
            key: _lista,
            filtro: '$_buscar|$_estado',
            cargar: (p) =>
                widget.api.examenesPagina(p, buscar: _buscar, estado: _estado),
            itemBuilder: (_, e) {
              final estilo = estiloEstadoExamen('${e['estado']}');
              final materia = '${e['materia_nombre'] ?? ''}';
              final preguntas = (e['total_preguntas'] as int?) ?? 0;
              return PanelCard(
                onTap: () => _abrir(e),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconBadge(
                          iconoMateria(materia),
                          fondo: estilo.suave,
                          tam: 46,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${e['titulo']}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                materia,
                                style: const TextStyle(
                                  color: Paleta.tintaSuave,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Etiqueta(
                          estilo.texto,
                          icono: estilo.icono,
                          fondo: estilo.suave,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      children: [
                        DatoIcono(
                          Icons.event_rounded,
                          fechaCorta('${e['fecha_inicio']}'),
                        ),
                        DatoIcono(
                          Icons.timer_rounded,
                          '${e['duracion_minutos']} min',
                        ),
                        DatoIcono(
                          Icons.quiz_rounded,
                          '$preguntas ${preguntas == 1 ? 'pregunta' : 'preguntas'}',
                        ),
                        DatoIcono(
                          Icons.replay_rounded,
                          '${e['intentos_permitidos']} ${e['intentos_permitidos'] == 1 ? 'intento' : 'intentos'}',
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
            vacio: const EstadoVacio(
              titulo: 'Aún no hay exámenes',
              mensaje: 'Crea el primero con el botón “Nuevo examen”.',
            ),
          ),
        ),
      ],
    ),
  );
}
