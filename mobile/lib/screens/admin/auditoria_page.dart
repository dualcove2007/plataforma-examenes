import 'dart:convert';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';

class AuditoriaPage extends StatefulWidget {
  final ApiService api;
  const AuditoriaPage({super.key, required this.api});

  @override
  State<AuditoriaPage> createState() => _AuditoriaPageState();
}

class _AuditoriaPageState extends State<AuditoriaPage> {
  String _buscar = '';
  String? _accion;

  static (IconData, Color) _estilo(String accion) => switch (accion) {
    'login' => (Icons.login_rounded, Paleta.verdeSuave),
    'logout' => (Icons.logout_rounded, Paleta.cieloSuave),
    'login_fallido' => (Icons.gpp_maybe_rounded, Paleta.coralSuave),
    'crear' => (Icons.add_circle_rounded, Paleta.verdeSuave),
    'editar' => (Icons.edit_rounded, Paleta.mielSuave),
    'eliminar' => (Icons.delete_rounded, Paleta.coralSuave),
    _ => (Icons.bolt_rounded, Paleta.lilaSuave),
  };

  void _detalle(Map<String, dynamic> a) {
    final (icono, color) = _estilo('${a['accion']}');
    final det = a['detalle'];
    final hayDetalle = det is Map && det.isNotEmpty;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconBadge(icono, fondo: color, tam: 46),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${a['accion']} · ${a['entidad']}',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Fila(
                Icons.person_rounded,
                'Usuario',
                '${a['usuario_nombre'] ?? 'Anónimo'}',
              ),
              _Fila(
                Icons.tag_rounded,
                'Registro',
                '${a['entidad_id']}'.isEmpty ? '—' : '${a['entidad_id']}',
              ),
              _Fila(Icons.schedule_rounded, 'Fecha', fechaCorta(a['fecha'])),
              _Fila(Icons.language_rounded, 'IP', '${a['ip_address'] ?? '—'}'),
              if (hayDetalle) ...[
                const SizedBox(height: 12),
                const Text(
                  'Detalle',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Paleta.crema,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Paleta.borde, width: 1.5),
                  ),
                  child: SelectableText(
                    const JsonEncoder.withIndent('  ').convert(det),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        const CabeceraSeccion(
          titulo: 'Auditoría',
          subtitulo: 'Quién hizo qué y cuándo',
          icono: Icons.history_rounded,
          seccion: Seccion.auditoria,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: CampoBusqueda(
            hint: 'Buscar por usuario, acción o entidad',
            onCambio: (v) => setState(() => _buscar = v),
          ),
        ),
        FilaFiltros<String?>(
          valor: _accion,
          onCambio: (v) => setState(() => _accion = v),
          opciones: const [
            OpcionFiltro<String?>('Todas', null, Icons.apps_rounded),
            OpcionFiltro<String?>('Ingresos', 'login', Icons.login_rounded),
            OpcionFiltro<String?>(
              'Fallidos',
              'login_fallido',
              Icons.gpp_maybe_rounded,
            ),
            OpcionFiltro<String?>(
              'Creaciones',
              'crear',
              Icons.add_circle_rounded,
            ),
            OpcionFiltro<String?>('Ediciones', 'editar', Icons.edit_rounded),
            OpcionFiltro<String?>(
              'Eliminaciones',
              'eliminar',
              Icons.delete_rounded,
            ),
          ],
        ),
        Expanded(
          child: ListaPaginada(
            filtro: '$_buscar|$_accion',
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            cargar: (p) =>
                widget.api.auditoria(p, buscar: _buscar, accion: _accion),
            itemBuilder: (_, a) {
              final (icono, color) = _estilo('${a['accion']}');
              final id = '${a['entidad_id']}';
              return PanelCard(
                onTap: () => _detalle(a),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    IconBadge(icono, fondo: color, tam: 42),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${a['accion']} · ${a['entidad']}'
                            '${id.isEmpty ? '' : ' #$id'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${a['usuario_nombre'] ?? 'Anónimo'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Paleta.tintaSuave,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            fechaCorta(a['fecha']),
                            style: const TextStyle(
                              color: Paleta.tintaSuave,
                              fontSize: 12,
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
              titulo: 'Sin movimientos',
              mensaje: 'No hay registros de auditoría con esos filtros.',
            ),
          ),
        ),
      ],
    ),
  );
}

class _Fila extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final String valor;
  const _Fila(this.icono, this.etiqueta, this.valor);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Icon(icono, size: 20, color: Paleta.tintaSuave),
        const SizedBox(width: 10),
        Text('$etiqueta: ', style: const TextStyle(color: Paleta.tintaSuave)),
        Expanded(
          child: Text(
            valor,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}
