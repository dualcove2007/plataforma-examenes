import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/estudiante_ui.dart';
import '../../widgets/ui.dart';
import '../notificaciones_page.dart';
import 'abrir_examen.dart';
import 'resultado_page.dart';

class _Datos {
  final List<Map<String, dynamic>> examenes;
  final List<Map<String, dynamic>> resultados;
  final int noLeidas;
  const _Datos(this.examenes, this.resultados, this.noLeidas);
}

/// Pantalla de inicio del estudiante: qué tiene pendiente y cómo le va.
class InicioPage extends StatefulWidget {
  final ApiService api;

  /// Cambia de pestaña en el contenedor (1 = exámenes, 2 = resultados).
  final ValueChanged<int> onIrA;
  const InicioPage({super.key, required this.api, required this.onIrA});

  @override
  State<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends State<InicioPage> {
  late Future<_Datos> futuro = _cargar();

  Future<_Datos> _cargar() async {
    final api = widget.api;
    final res = await Future.wait<Object>([
      api.examenesConIntentos(),
      api.misResultadosTodos(),
      // Si falla el contador no debe tumbar el inicio.
      api.noLeidas().catchError((_) => 0),
    ]);
    return _Datos(
      res[0] as List<Map<String, dynamic>>,
      res[1] as List<Map<String, dynamic>>,
      res[2] as int,
    );
  }

  void _recargar() => setState(() => futuro = _cargar());

  Future<void> _abrirExamen(Map<String, dynamic> e) async {
    await abrirExamen(context, widget.api, e);
    if (mounted) _recargar();
  }

  Future<void> _abrirNotificaciones() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NotificacionesPage(api: widget.api)),
    );
    if (mounted) _recargar();
  }

  @override
  Widget build(BuildContext context) {
    final nombre = '${widget.api.usuario?['nombre'] ?? 'estudiante'}'
        .split(' ')
        .first;
    return Scaffold(
      body: FutureBuilder<_Datos>(
        future: futuro,
        builder: (context, snap) {
          final cargado = snap.connectionState == ConnectionState.done;
          final noLeidas = snap.data?.noLeidas ?? 0;
          return Column(
            children: [
              CabeceraSeccion(
                titulo: 'Hola, $nombre',
                subtitulo: 'Listo para tus exámenes',
                icono: Icons.waving_hand_rounded,
                seccion: Seccion.inicio,
                acciones: [
                  IconButton(
                    tooltip: 'Notificaciones',
                    color: Colors.white,
                    icon: Badge(
                      isLabelVisible: noLeidas > 0,
                      backgroundColor: Paleta.coral,
                      textColor: Paleta.tinta,
                      label: Text(noLeidas > 9 ? '9+' : '$noLeidas'),
                      child: const Icon(Icons.notifications_rounded),
                    ),
                    onPressed: _abrirNotificaciones,
                  ),
                ],
              ),
              Expanded(
                child: !cargado
                    ? const Center(child: CircularProgressIndicator())
                    : snap.hasError
                    ? EstadoError(
                        mensaje: mensajeError(snap.error!),
                        onReintentar: _recargar,
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          _recargar();
                          await futuro;
                        },
                        child: _contenido(snap.data!),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _contenido(_Datos d) {
    final t = Theme.of(context).textTheme;
    final abiertos = d.examenes.where((e) => estadoExamen(e).abierto).toList()
      ..sort((a, b) {
        final porFase = estadoExamen(a).fase.index.compareTo(
          estadoExamen(b).fase.index,
        );
        if (porFase != 0) return porFase;
        final fa = DateTime.tryParse('${a['fecha_fin']}');
        final fb = DateTime.tryParse('${b['fecha_fin']}');
        return (fa == null || fb == null) ? 0 : fa.compareTo(fb);
      });
    final siguiente = abiertos.isEmpty ? null : abiertos.first;

    final notas = <double>[
      for (final r in d.resultados)
        if (aNumero(r['nota_final']) != null) aNumero(r['nota_final'])!,
    ];
    final promedio = notas.isEmpty
        ? null
        : notas.reduce((a, b) => a + b) / notas.length;
    final porRevisar = d.resultados
        .where((r) => aNumero(r['nota_final']) == null)
        .length;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // Bienvenida con ilustración
        PanelCard(
          color: Paleta.mielSuave,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      abiertos.isEmpty
                          ? '¡Estás al día!'
                          : abiertos.length == 1
                          ? 'Tienes 1 examen por presentar'
                          : 'Tienes ${abiertos.length} exámenes por presentar',
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      abiertos.isEmpty
                          ? 'No hay exámenes pendientes por ahora.'
                          : 'Entra cuando estés listo y con tiempo.',
                      style: const TextStyle(color: Paleta.tintaSuave),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => widget.onIrA(1),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      icon: const Icon(Icons.assignment_rounded),
                      label: const Text('Mis exámenes'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SvgPicture.asset('assets/images/estudiante_hero.svg', width: 112),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Números clave
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: [
            _Stat(
              Icons.rocket_launch_rounded,
              Paleta.verdeSuave,
              '${abiertos.length}',
              'Por presentar',
            ),
            _Stat(
              Icons.task_alt_rounded,
              Paleta.lilaSuave,
              '${d.resultados.length}',
              'Presentados',
            ),
            _Stat(
              Icons.insights_rounded,
              Paleta.cieloSuave,
              promedio == null ? '—' : formatearNota(promedio),
              'Promedio',
            ),
            _Stat(
              Icons.pending_actions_rounded,
              Paleta.mielSuave,
              '$porRevisar',
              'En revisión',
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Siguiente examen
        if (siguiente != null) ...[
          Text(
            'Siguiente examen',
            style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          TarjetaExamen(examen: siguiente, onTap: () => _abrirExamen(siguiente)),
          const SizedBox(height: 20),
        ],

        // Últimos resultados
        Row(
          children: [
            Expanded(
              child: Text(
                'Últimos resultados',
                style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            if (d.resultados.isNotEmpty)
              TextButton(
                onPressed: () => widget.onIrA(2),
                child: const Text('Ver todos'),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (d.resultados.isEmpty)
          const PanelCard(
            child: Row(
              children: [
                IconBadge(Icons.emoji_events_rounded, fondo: Paleta.cieloSuave),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Cuando presentes un examen, tu nota aparecerá aquí.',
                    style: TextStyle(color: Paleta.tintaSuave),
                  ),
                ),
              ],
            ),
          )
        else
          for (final r in d.resultados.take(3)) ...[
            PanelCard(
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        ResultadoPage(api: widget.api, resultado: r),
                  ),
                );
              },
              child: Row(
                children: [
                  NotaCirculo(r['nota_final'], tam: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${r['examen_titulo'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Intento ${r['numero_intento'] ?? '—'}',
                          style: const TextStyle(color: Paleta.tintaSuave),
                        ),
                      ],
                    ),
                  ),
                  etiquetaResultado(
                    r['nota_final'],
                    r['estado_revision'] as String?,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icono;
  final Color fondo;
  final String valor;
  final String etiqueta;
  const _Stat(this.icono, this.fondo, this.valor, this.etiqueta);

  @override
  Widget build(BuildContext context) => PanelCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconBadge(icono, fondo: fondo, tam: 38),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              valor,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            Text(
              etiqueta,
              style: const TextStyle(
                color: Paleta.tintaSuave,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
