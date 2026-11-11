import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/sesion.dart';
import '../../widgets/ui.dart';
import '../perfil_page.dart';
import 'usuario_form_page.dart';

class _Datos {
  final Map<String, dynamic> est;
  final int totalUsuarios;
  final int activos;
  final List<Map<String, dynamic>> roles;
  final Map<int, int> porRol;
  const _Datos(
    this.est,
    this.totalUsuarios,
    this.activos,
    this.roles,
    this.porRol,
  );
}

class AdminDashboardPage extends StatefulWidget {
  final ApiService api;
  final ValueChanged<int> onIrA;
  const AdminDashboardPage({super.key, required this.api, required this.onIrA});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late Future<_Datos> futuro = _cargar();

  Future<_Datos> _cargar() async {
    final api = widget.api;
    final roles = await api.roles();
    final res = await Future.wait<Object>([
      api.estadisticas(),
      api.contarUsuarios(),
      api.contarUsuarios(activo: true),
      for (final r in roles) api.contarUsuarios(rol: r['id'] as int),
    ]);
    return _Datos(
      res[0] as Map<String, dynamic>,
      res[1] as int,
      res[2] as int,
      roles,
      {
        for (var i = 0; i < roles.length; i++)
          roles[i]['id'] as int: res[3 + i] as int,
      },
    );
  }

  void _recargar() => setState(() => futuro = _cargar());

  Future<void> _registrar() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => UsuarioFormPage(api: widget.api)),
    );
    if (ok == true) _recargar();
  }

  @override
  Widget build(BuildContext context) {
    final nombre = '${widget.api.usuario?['nombre'] ?? 'Admin'}'
        .split(' ')
        .first;
    return Scaffold(
      body: Column(
        children: [
          CabeceraSeccion(
            titulo: 'Hola, $nombre',
            subtitulo: 'Panel de administración',
            icono: Icons.waving_hand_rounded,
            seccion: Seccion.inicio,
            acciones: [
              IconButton(
                tooltip: 'Mi perfil',
                onPressed: () async {
                  await abrirPerfil(context, widget.api);
                  if (mounted) setState(() {});
                },
                icon: AvatarUsuario(
                  api: widget.api,
                  nombre: '${widget.api.usuario?['nombre'] ?? ''}',
                  version: widget.api.usuario?['foto_version'] as String?,
                  tam: 36,
                  color: Colors.white,
                  colorBorde: Colors.white,
                ),
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
    final est = d.est;
    final ex = (est['examenes'] as Map).cast<String, dynamic>();
    final intentos = (est['intentos'] as Map).cast<String, dynamic>();
    final res = (est['resultados'] as Map).cast<String, dynamic>();
    final tasa = res['tasa_aprobacion'];
    final t = Theme.of(context).textTheme;

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
                      'Todo bajo control',
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Registra usuarios y gestiona permisos desde aquí.',
                      style: TextStyle(color: Paleta.tintaSuave),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _registrar,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Registrar usuario'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SvgPicture.asset('assets/images/admin_hero.svg', width: 112),
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
              Icons.group_rounded,
              Paleta.verdeSuave,
              '${d.totalUsuarios}',
              'Usuarios',
            ),
            _Stat(
              Icons.verified_user_rounded,
              Paleta.cieloSuave,
              '${d.activos}',
              'Cuentas activas',
            ),
            _Stat(
              Icons.assignment_rounded,
              Paleta.mielSuave,
              '${ex['total']}',
              'Exámenes',
            ),
            _Stat(
              Icons.edit_note_rounded,
              Paleta.lilaSuave,
              '${intentos['total']}',
              'Intentos',
            ),
            _Stat(
              Icons.pending_actions_rounded,
              Paleta.coralSuave,
              '${res['pendientes_revision']}',
              'Por revisar',
            ),
            _Stat(
              Icons.emoji_events_rounded,
              Paleta.verdeSuave,
              tasa == null ? '—' : '$tasa %',
              'Aprobación',
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Usuarios por rol
        PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Usuarios por rol',
                style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              for (final r in d.roles) ...[
                _BarraRol(
                  nombre: '${r['nombre']}',
                  cantidad: d.porRol[r['id']] ?? 0,
                  total: d.totalUsuarios,
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Exámenes por estado
        PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Exámenes por estado',
                style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in ex.entries)
                    if (e.key != 'total')
                      Etiqueta(
                        '${_capitalizar(e.key)}: ${e.value}',
                        icono: Icons.circle,
                        fondo: Paleta.crema,
                      ),
                ],
              ),
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
                Icons.menu_book_rounded,
                'Materias',
                Paleta.mielSuave,
                () => widget.onIrA(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Acceso(
                Icons.shield_rounded,
                'Roles',
                Paleta.lilaSuave,
                () => widget.onIrA(3),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Acceso(
                Icons.history_rounded,
                'Auditoría',
                Paleta.coralSuave,
                () => widget.onIrA(4),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _capitalizar(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
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
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800, height: 1.1),
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

class _BarraRol extends StatelessWidget {
  final String nombre;
  final int cantidad;
  final int total;
  const _BarraRol({
    required this.nombre,
    required this.cantidad,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final estilo = EstiloRol.de(nombre);
    return Row(
      children: [
        IconBadge(estilo.icono, fondo: estilo.suave, tam: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      nombre,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '$cantidad',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : cantidad / total,
                  minHeight: 8,
                  color: estilo.color,
                  backgroundColor: estilo.suave,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
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
