import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';

class RolesPage extends StatefulWidget {
  final ApiService api;
  const RolesPage({super.key, required this.api});

  @override
  State<RolesPage> createState() => _RolesPageState();
}

class _RolesPageState extends State<RolesPage> {
  late Future<List<Map<String, dynamic>>> futuro = widget.api.roles();

  void _recargar() => setState(() => futuro = widget.api.roles());

  Future<void> _editar(Map<String, dynamic> rol) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RolEditarPage(api: widget.api, rol: rol),
      ),
    );
    if (ok == true) _recargar();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        const CabeceraSeccion(
          titulo: 'Roles y permisos',
          subtitulo: 'Define qué puede hacer cada rol',
          icono: Icons.shield_rounded,
          seccion: Seccion.roles,
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
              final roles = snap.data!;
              return RefreshIndicator(
                onRefresh: () async {
                  _recargar();
                  await futuro;
                },
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: roles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final r = roles[i];
                    final estilo = EstiloRol.de('${r['nombre']}');
                    final n = (r['permisos'] as List).length;
                    return PanelCard(
                      onTap: () => _editar(r),
                      child: Row(
                        children: [
                          IconBadge(estilo.icono, fondo: estilo.suave, tam: 50),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${r['nombre']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                if ('${r['descripcion']}'.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      '${r['descripcion']}',
                                      style: const TextStyle(
                                        color: Paleta.tintaSuave,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Etiqueta(
                                  '$n permisos',
                                  icono: Icons.key_rounded,
                                  fondo: Paleta.crema,
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
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

const _iconosGrupo = {
  'usuarios': Icons.group_rounded,
  'roles': Icons.shield_rounded,
  'materias': Icons.menu_book_rounded,
  'bancos': Icons.inventory_2_rounded,
  'preguntas': Icons.quiz_rounded,
  'examenes': Icons.assignment_rounded,
  'resultados': Icons.fact_check_rounded,
  'reportes': Icons.bar_chart_rounded,
  'auditoria': Icons.history_rounded,
};

/// Edita la descripción de un rol y enciende/apaga sus permisos.
class RolEditarPage extends StatefulWidget {
  final ApiService api;
  final Map<String, dynamic> rol;
  const RolEditarPage({super.key, required this.api, required this.rol});

  @override
  State<RolEditarPage> createState() => _RolEditarPageState();
}

class _RolEditarPageState extends State<RolEditarPage> {
  late final Future<List<Map<String, dynamic>>> _permisos = widget.api
      .permisos();
  late final Set<int> _sel = (widget.rol['permisos'] as List)
      .map((e) => e as int)
      .toSet();
  late final desc = TextEditingController(
    text: '${widget.rol['descripcion'] ?? ''}',
  );
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    desc.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.api.actualizarRol(widget.rol['id'] as int, {
        'descripcion': desc.text.trim(),
        'permisos': _sel.toList(),
      });
      if (!mounted) return;
      mostrarAviso(context, 'Rol actualizado');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = mensajeError(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estilo = EstiloRol.de('${widget.rol['nombre']}');
    return Scaffold(
      appBar: AppBar(title: Text('Rol: ${widget.rol['nombre']}')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _permisos,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text(mensajeError(snap.error!)));
          }
          final permisos = snap.data!;
          final grupos = <String, List<Map<String, dynamic>>>{};
          for (final p in permisos) {
            final g = '${p['nombre']}'.split('.').first;
            grupos.putIfAbsent(g, () => []).add(p);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              PanelCard(
                color: estilo.suave,
                child: Row(
                  children: [
                    IconBadge(estilo.icono, fondo: Colors.white, tam: 48),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        '${_sel.length} de ${permisos.length} permisos activos',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: desc,
                maxLength: 255,
                decoration: const InputDecoration(
                  labelText: 'Descripción del rol',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              for (final g in grupos.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 10),
                  child: Row(
                    children: [
                      Icon(
                        _iconosGrupo[g.key] ?? Icons.key_rounded,
                        size: 20,
                        color: Paleta.verde,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        g.key[0].toUpperCase() + g.key.substring(1),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15.5,
                        ),
                      ),
                    ],
                  ),
                ),
                PanelCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < g.value.length; i++) ...[
                        if (i > 0) const Divider(),
                        SwitchListTile(
                          value: _sel.contains(g.value[i]['id']),
                          onChanged: (v) => setState(() {
                            final id = g.value[i]['id'] as int;
                            v ? _sel.add(id) : _sel.remove(id);
                          }),
                          title: Text(
                            '${g.value[i]['descripcion']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                            ),
                          ),
                          subtitle: Text(
                            '${g.value[i]['nombre']}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Paleta.tintaSuave,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Paleta.coralSuave,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_rounded, color: Color(0xFFB3261E)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _guardando ? null : _guardar,
                icon: const Icon(Icons.save_rounded),
                label: Text(_guardando ? 'Guardando...' : 'Guardar cambios'),
              ),
            ],
          );
        },
      ),
    );
  }
}
