import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/docente_ui.dart';
import '../../widgets/estudiante_ui.dart';
import '../../widgets/ui.dart';
import 'resultado_revision_page.dart';

/// Resultados de los estudiantes en los exámenes del docente.
/// Si recibe [examenId] se abre encima (con botón volver) y filtra por ese examen.
class DocenteResultadosPage extends StatefulWidget {
  final ApiService api;
  final int? examenId;
  final String? examenTitulo;
  const DocenteResultadosPage({
    super.key,
    required this.api,
    this.examenId,
    this.examenTitulo,
  });

  @override
  State<DocenteResultadosPage> createState() => _DocenteResultadosPageState();
}

class _DocenteResultadosPageState extends State<DocenteResultadosPage> {
  final _lista = GlobalKey<ListaPaginadaState>();
  String _buscar = '';
  String? _revision;

  bool get _enPestana => widget.examenId == null;

  Future<void> _abrir(Map<String, dynamic> r) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ResultadoRevisionPage(api: widget.api, resultadoId: r['id'] as int),
      ),
    );
    // Pudo cambiar la nota o el estado de revisión.
    _lista.currentState?.recargar();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        CabeceraSeccion(
          titulo: _enPestana ? 'Resultados' : 'Resultados del examen',
          subtitulo: _enPestana
              ? 'Revisa y califica a tus estudiantes'
              : '${widget.examenTitulo}',
          icono: Icons.fact_check_rounded,
          seccion: Seccion.resultados,
          leading: _enPestana ? null : botonVolver(context),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: CampoBusqueda(
            hint: 'Buscar estudiante',
            onCambio: (v) => setState(() => _buscar = v),
          ),
        ),
        FilaFiltros<String?>(
          opciones: const [
            OpcionFiltro('Todos', null, Icons.layers_rounded),
            OpcionFiltro('Pendientes', 'pendiente', Icons.pending_actions_rounded),
            OpcionFiltro('En revisión', 'en_revision', Icons.hourglass_top_rounded),
            OpcionFiltro('Revisados', 'revisado', Icons.verified_rounded),
          ],
          valor: _revision,
          onCambio: (v) => setState(() => _revision = v),
        ),
        Expanded(
          child: ListaPaginada(
            key: _lista,
            filtro: '$_buscar|$_revision',
            cargar: (p) => widget.api.resultadosPagina(
              p,
              buscar: _buscar,
              examen: widget.examenId,
              revision: _revision,
            ),
            itemBuilder: (_, r) {
              final rev = estiloRevision('${r['estado_revision']}');
              return PanelCard(
                onTap: () => _abrir(r),
                child: Row(
                  children: [
                    NotaCirculo(r['nota_final'], tam: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${r['estudiante']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${r['examen_titulo']} · intento ${r['numero_intento']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Paleta.tintaSuave,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Etiqueta(
                            rev.texto,
                            icono: rev.icono,
                            fondo: rev.suave,
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
              titulo: 'Sin resultados',
              mensaje:
                  'Cuando tus estudiantes presenten los exámenes, aparecerán aquí.',
            ),
          ),
        ),
      ],
    ),
  );
}
