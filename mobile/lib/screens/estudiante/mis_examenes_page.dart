import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../widgets/estudiante_ui.dart';
import '../../widgets/ui.dart';
import '../../theme/app_theme.dart';
import 'abrir_examen.dart';

enum _Filtro { todos, abiertos, completados, cerrados }

/// Lista de exámenes asignados, con filtros por estado.
class MisExamenesPage extends StatefulWidget {
  final ApiService api;
  const MisExamenesPage({super.key, required this.api});

  @override
  State<MisExamenesPage> createState() => _MisExamenesPageState();
}

class _MisExamenesPageState extends State<MisExamenesPage> {
  late Future<List<Map<String, dynamic>>> futuro = widget.api
      .examenesConIntentos();
  _Filtro filtro = _Filtro.todos;
  final _scroll = ScrollController();
  int _pagina = 1;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _recargar() =>
      setState(() => futuro = widget.api.examenesConIntentos());

  Future<void> _abrir(Map<String, dynamic> e) async {
    await abrirExamen(context, widget.api, e);
    if (mounted) _recargar();
  }

  bool _pasa(Map<String, dynamic> e) {
    final fase = estadoExamen(e).fase;
    return switch (filtro) {
      _Filtro.todos => true,
      _Filtro.abiertos =>
        fase == FaseExamen.enCurso ||
            fase == FaseExamen.disponible ||
            fase == FaseExamen.proximo,
      _Filtro.completados => fase == FaseExamen.completado,
      _Filtro.cerrados => fase == FaseExamen.cerrado,
    };
  }

  /// Primero lo que se puede presentar ya; dentro de cada grupo, lo que cierra antes.
  List<Map<String, dynamic>> _ordenar(List<Map<String, dynamic>> lista) {
    final copia = [...lista.where(_pasa)];
    copia.sort((a, b) {
      final porFase = estadoExamen(a).fase.index.compareTo(
        estadoExamen(b).fase.index,
      );
      if (porFase != 0) return porFase;
      final fa = DateTime.tryParse('${a['fecha_fin']}');
      final fb = DateTime.tryParse('${b['fecha_fin']}');
      if (fa == null || fb == null) return 0;
      return fa.compareTo(fb);
    });
    return copia;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        const CabeceraSeccion(
          titulo: 'Mis exámenes',
          subtitulo: 'Tus evaluaciones asignadas',
          icono: Icons.assignment_rounded,
          seccion: Seccion.examenes,
        ),
        const SizedBox(height: 12),
        FilaFiltros<_Filtro>(
          valor: filtro,
          onCambio: (v) => setState(() {
            filtro = v;
            _pagina = 1;
          }),
          opciones: const [
            OpcionFiltro('Todos', _Filtro.todos, Icons.apps_rounded),
            OpcionFiltro(
              'Por presentar',
              _Filtro.abiertos,
              Icons.rocket_launch_rounded,
            ),
            OpcionFiltro(
              'Completados',
              _Filtro.completados,
              Icons.task_alt_rounded,
            ),
            OpcionFiltro('Cerrados', _Filtro.cerrados, Icons.lock_clock_rounded),
          ],
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: futuro,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return EstadoError(
                  mensaje: mensajeError(snap.error!),
                  onReintentar: _recargar,
                );
              }
              final items = _ordenar(snap.data!);
              final totalPaginas = totalPaginasDe(items.length);
              final pagina = _pagina > totalPaginas ? totalPaginas : _pagina;
              final visibles = items
                  .skip((pagina - 1) * tamanoPagina)
                  .take(tamanoPagina)
                  .toList();
              return RefreshIndicator(
                onRefresh: () async {
                  _recargar();
                  await futuro;
                },
                child: items.isEmpty
                    ? LayoutBuilder(
                        builder: (_, c) => SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: SizedBox(
                            height: c.maxHeight,
                            child: EstadoVacio(
                              titulo: snap.data!.isEmpty
                                  ? 'Sin exámenes asignados'
                                  : 'Nada en esta categoría',
                              mensaje: snap.data!.isEmpty
                                  ? 'Cuando un docente te asigne un examen, aparecerá aquí.'
                                  : 'Prueba con otro filtro.',
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: _scroll,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: visibles.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          if (i == visibles.length) {
                            return PaginadorBarra(
                              pagina: pagina,
                              totalPaginas: totalPaginas,
                              total: items.length,
                              onIr: (p) {
                                setState(() => _pagina = p);
                                if (_scroll.hasClients) _scroll.jumpTo(0);
                              },
                            );
                          }
                          return TarjetaExamen(
                            examen: visibles[i],
                            onTap: () => _abrir(visibles[i]),
                          );
                        },
                      ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
