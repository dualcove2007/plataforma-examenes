import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

/// Notificaciones del usuario (sirve para cualquier rol).
class NotificacionesPage extends StatefulWidget {
  final ApiService api;
  const NotificacionesPage({super.key, required this.api});

  @override
  State<NotificacionesPage> createState() => _NotificacionesPageState();
}

class _NotificacionesPageState extends State<NotificacionesPage> {
  final _lista = GlobalKey<ListaPaginadaState>();
  bool _soloNuevas = false;

  Future<void> _marcarTodas() async {
    try {
      await widget.api.marcarTodasLeidas();
      if (!mounted) return;
      mostrarAviso(context, 'Todo quedó como leído');
      _lista.currentState?.recargar();
    } catch (e) {
      if (mounted) mostrarAviso(context, mensajeError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        CabeceraSeccion(
          titulo: 'Notificaciones',
          subtitulo: 'Avisos de tus exámenes y notas',
          icono: Icons.notifications_rounded,
          seccion: Seccion.catalogo,
          leading: IconButton(
            tooltip: 'Volver',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
          acciones: [
            IconButton(
              tooltip: 'Marcar todas como leídas',
              icon: const Icon(Icons.done_all_rounded),
              onPressed: _marcarTodas,
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilaFiltros<bool>(
          opciones: const [
            OpcionFiltro('Todas', false, Icons.notifications_none_rounded),
            OpcionFiltro('Sin leer', true, Icons.mark_email_unread_rounded),
          ],
          valor: _soloNuevas,
          onCambio: (v) => setState(() => _soloNuevas = v),
        ),
        Expanded(
          child: ListaPaginada(
            key: _lista,
            filtro: _soloNuevas,
            cargar: (p) =>
                widget.api.notificaciones(p, leida: _soloNuevas ? false : null),
            vacio: EstadoVacio(
              titulo: _soloNuevas ? 'Todo al día' : 'Sin notificaciones',
              mensaje: _soloNuevas
                  ? 'No tienes notificaciones sin leer.'
                  : 'Aquí aparecerán los avisos de tus exámenes.',
            ),
            itemBuilder: (_, n) => _Tarjeta(api: widget.api, n: n),
          ),
        ),
      ],
    ),
  );
}

class _Tarjeta extends StatefulWidget {
  final ApiService api;
  final Map<String, dynamic> n;
  const _Tarjeta({required this.api, required this.n});

  @override
  State<_Tarjeta> createState() => _TarjetaState();
}

class _TarjetaState extends State<_Tarjeta> {
  late bool leida = widget.n['leida'] == true;

  (IconData, Color) get _estilo => switch (widget.n['tipo']) {
    'examen_asignado' => (Icons.assignment_ind_rounded, Paleta.cieloSuave),
    'examen_publicado' => (Icons.campaign_rounded, Paleta.mielSuave),
    'resultado_revisado' => (Icons.emoji_events_rounded, Paleta.verdeSuave),
    _ => (Icons.notifications_rounded, Paleta.lilaSuave),
  };

  Future<void> _abrir() async {
    if (leida) return;
    setState(() => leida = true);
    try {
      await widget.api.marcarLeida(widget.n['id'] as int);
    } catch (e) {
      if (!mounted) return;
      setState(() => leida = false);
      mostrarAviso(context, mensajeError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icono, fondo) = _estilo;
    return PanelCard(
      color: leida ? Colors.white : Paleta.mielSuave,
      onTap: _abrir,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icono, fondo: leida ? fondo : Colors.white, tam: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.n['titulo'] ?? ''}',
                  style: TextStyle(
                    fontWeight: leida ? FontWeight.w700 : FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.n['mensaje'] ?? ''}',
                  style: const TextStyle(color: Paleta.tintaSuave),
                ),
                const SizedBox(height: 6),
                Text(
                  fechaCorta(widget.n['fecha_creacion'] as String?),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Paleta.tintaSuave,
                  ),
                ),
              ],
            ),
          ),
          if (!leida)
            Container(
              margin: const EdgeInsets.only(left: 8, top: 4),
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Paleta.coral,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
