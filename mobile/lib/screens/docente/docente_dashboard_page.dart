import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/docente_ui.dart';
import '../../widgets/sesion.dart';
import '../../widgets/ui.dart';
import '../notificaciones_page.dart';
import 'examen_form_page.dart';

class _Datos {
  final Map<String, dynamic> est;
  final int bancos;
  const _Datos(this.est, this.bancos);
}

/// Inicio del docente: resumen de sus exámenes y accesos rápidos.
class DocenteDashboardPage extends StatefulWidget {
  final ApiService api;
  final ValueChanged<int> onIrA;
  const DocenteDashboardPage({
    super.key,
    required this.api,
    required this.onIrA,
  });

  @override
  State<DocenteDashboardPage> createState() => _DocenteDashboardPageState();
}

class _DocenteDashboardPageState extends State<DocenteDashboardPage> {
  late Future<_Datos> futuro = _cargar();

  Future<_Datos> _cargar() async {
    final res = await Future.wait<Object>([
      widget.api.estadisticas(),
      widget.api.bancosPagina(1).then((p) => p.total),
    ]);
    return _Datos(res[0] as Map<String, dynamic>, res[1] as int);
  }

  void _recargar() => setState(() => futuro = _cargar());

  Future<void> _nuevoExamen() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ExamenFormPage(api: widget.api)),
    );
    if (ok == true) {
      _recargar();
      widget.onIrA(2);
    }
  }

  void _abrirNotificaciones() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NotificacionesPage(api: widget.api)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombre = '${widget.api.usuario?['nombre'] ?? 'docente'}'
        .split(' ')
        .first;
    return Scaffold(
      body: Column(
        children: [
          CabeceraSeccion(
            titulo: 'Hola, $nombre',
            subtitulo: 'Panel docente',
            icono: Icons.waving_hand_rounded,
            seccion: Seccion.inicio,
            acciones: [
              IconButton(
                tooltip: 'Notificaciones',
                color: Colors.white,
                icon: const Icon(Icons.notifications_rounded),
                onPressed: _abrirNotificaciones,
              ),
              IconButton(
                tooltip: 'Cerrar sesión',
                color: Colors.white,
                icon: const Icon(Icons.logout_rounded),
                onPressed: () => cerrarSesion(context, widget.api),
              ),
            ],
          ),
          Expanded(
            child: FutureBuilder<_Datos>(
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
                return RefreshIndicator(
                  onRefresh: () async {
                    _recargar();
                    await futuro;
                  },
                  child: _contenido(snap.data!),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _contenido(_Datos d) {
    final t = Theme.of(context).textTheme;
    final ex = (d.est['examenes'] as Map).cast<String, dynamic>();
    final res = (d.est['resultados'] as Map).cast<String, dynamic>();
    final porExamen = List<Map<String, dynamic>>.from(
      (d.est['por_examen'] as List?) ?? const [],
    );
    final tasa = res['tasa_aprobacion'];
    final promedio = res['promedio_nota'];
    final pendientes = (res['pendientes_revision'] as int?) ?? 0;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // Bienvenida con ilustración
        PanelCard(
          color: Paleta.cieloSuave,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pendientes > 0
                          ? 'Tienes $pendientes por revisar'
                          : 'Todo al día',
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pendientes > 0
                          ? 'Hay respuestas esperando tu calificación.'
                          : 'Crea un examen nuevo y asígnalo a tus estudiantes.',
                      style: const TextStyle(color: Paleta.tintaSuave),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: pendientes > 0
                          ? () => widget.onIrA(3)
                          : _nuevoExamen,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      icon: Icon(
                        pendientes > 0
                            ? Icons.fact_check_rounded
                            : Icons.add_task_rounded,
                      ),
                      label: Text(pendientes > 0 ? 'Revisar ahora' : 'Nuevo examen'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SvgPicture.asset('assets/images/docente_hero.svg', width: 112),
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
              Icons.folder_copy_rounded,
              Paleta.lilaSuave,
              '${d.bancos}',
              'Bancos',
            ),
            _Stat(
              Icons.assignment_rounded,
              Paleta.mielSuave,
              '${ex['total']}',
              'Exámenes',
            ),
            _Stat(
              Icons.pending_actions_rounded,
              Paleta.coralSuave,
              '$pendientes',
              'Por revisar',
            ),
            _Stat(
              Icons.emoji_events_rounded,
              Paleta.verdeSuave,
              tasa == null ? '—' : '$tasa %',
              'Aprobación',
            ),
            _Stat(
              Icons.grade_rounded,
              Paleta.cieloSuave,
              promedio == null ? '—' : '$promedio',
              'Nota promedio',
            ),
            _Stat(
              Icons.rocket_launch_rounded,
              Paleta.verdeSuave,
              '${ex['publicado'] ?? 0}',
              'Publicados',
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Exámenes recientes
        PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TituloBloque('Exámenes recientes', Icons.history_rounded),
              const SizedBox(height: 12),
              if (porExamen.isEmpty)
                const Text(
                  'Aún no has creado exámenes.',
                  style: TextStyle(color: Paleta.tintaSuave),
                )
              else
                for (final e in porExamen.take(5)) ...[
                  _FilaExamen(e),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text(
          'Accesos rápidos',
          style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _Acceso(
                Icons.folder_copy_rounded,
                'Bancos',
                Paleta.lilaSuave,
                () => widget.onIrA(1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Acceso(
                Icons.assignment_rounded,
                'Exámenes',
                Paleta.mielSuave,
                () => widget.onIrA(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Acceso(
                Icons.fact_check_rounded,
                'Resultados',
                Paleta.cieloSuave,
                () => widget.onIrA(3),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FilaExamen extends StatelessWidget {
  final Map<String, dynamic> e;
  const _FilaExamen(this.e);

  @override
  Widget build(BuildContext context) {
    final estilo = estiloEstadoExamen('${e['estado']}');
    final asignados = (e['asignados'] as int?) ?? 0;
    final presentaron = (e['presentaron'] as int?) ?? 0;
    return Row(
      children: [
        IconBadge(estilo.icono, fondo: estilo.suave, tam: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${e['titulo']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                '$presentaron de $asignados presentaron',
                style: const TextStyle(
                  color: Paleta.tintaSuave,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
        Etiqueta(estilo.texto, fondo: estilo.suave),
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

class _Acceso extends StatelessWidget {
  final IconData icono;
  final String texto;
  final Color fondo;
  final VoidCallback onTap;
  const _Acceso(this.icono, this.texto, this.fondo, this.onTap);

  @override
  Widget build(BuildContext context) => PanelCard(
    onTap: onTap,
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Column(
      children: [
        IconBadge(icono, fondo: fondo, tam: 42),
        const SizedBox(height: 8),
        Text(
          texto,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ],
    ),
  );
}
