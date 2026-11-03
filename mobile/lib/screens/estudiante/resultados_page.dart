import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/estudiante_ui.dart';
import '../../widgets/ui.dart';
import 'resultado_page.dart';

/// Historial de notas del estudiante.
class ResultadosPage extends StatelessWidget {
  final ApiService api;
  const ResultadosPage({super.key, required this.api});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        const CabeceraSeccion(
          titulo: 'Mis resultados',
          subtitulo: 'Tus notas y revisiones',
          icono: Icons.emoji_events_rounded,
          seccion: Seccion.resultados,
        ),
        Expanded(
          child: ListaPaginada(
            cargar: api.misResultados,
            vacio: const EstadoVacio(
              titulo: 'Aún no hay resultados',
              mensaje: 'Cuando presentes un examen, tu nota aparecerá aquí.',
            ),
            itemBuilder: (context, r) => _TarjetaResultado(
              r: r,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ResultadoPage(api: api, resultado: r),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _TarjetaResultado extends StatelessWidget {
  final Map<String, dynamic> r;
  final VoidCallback onTap;
  const _TarjetaResultado({required this.r, required this.onTap});

  @override
  Widget build(BuildContext context) => PanelCard(
    onTap: onTap,
    child: Row(
      children: [
        NotaCirculo(r['nota_final'], tam: 56),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${r['examen_titulo'] ?? ''}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                'Intento ${r['numero_intento'] ?? '—'}',
                style: const TextStyle(color: Paleta.tintaSuave),
              ),
              const SizedBox(height: 8),
              etiquetaResultado(r['nota_final'], r['estado_revision'] as String?),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: Paleta.tintaSuave),
      ],
    ),
  );
}
