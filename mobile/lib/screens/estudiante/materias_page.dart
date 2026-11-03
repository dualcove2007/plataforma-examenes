import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/estudiante_ui.dart';
import '../../widgets/ui.dart';

/// Catálogo de materias, con búsqueda.
class MateriasPage extends StatefulWidget {
  final ApiService api;
  const MateriasPage({super.key, required this.api});

  @override
  State<MateriasPage> createState() => _MateriasPageState();
}

class _MateriasPageState extends State<MateriasPage> {
  String _q = '';

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        const CabeceraSeccion(
          titulo: 'Materias',
          subtitulo: 'Las áreas de tus exámenes',
          icono: Icons.menu_book_rounded,
          seccion: Seccion.catalogo,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: CampoBusqueda(
            hint: 'Buscar materia',
            onCambio: (v) => setState(() => _q = v),
          ),
        ),
        Expanded(
          child: ListaPaginada(
            filtro: _q,
            cargar: (p) => widget.api.materiasPagina(p, buscar: _q),
            vacio: EstadoVacio(
              titulo: _q.isEmpty ? 'Sin materias' : 'Sin resultados',
              mensaje: _q.isEmpty
                  ? 'Todavía no hay materias registradas.'
                  : 'No encontramos materias con "$_q".',
            ),
            itemBuilder: (_, m) {
              final nombre = '${m['nombre'] ?? ''}';
              final descripcion = '${m['descripcion'] ?? ''}'.trim();
              return PanelCard(
                child: Row(
                  children: [
                    IconBadge(
                      iconoMateria(nombre),
                      fondo: colorSuaveMateria((m['id'] as int?) ?? 0),
                      tam: 48,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nombre,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          if (descripcion.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              descripcion,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Paleta.tintaSuave),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
