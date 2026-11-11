import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/ui.dart';
import 'usuario_form_page.dart';

class UsuariosPage extends StatefulWidget {
  final ApiService api;
  const UsuariosPage({super.key, required this.api});

  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  final _lista = GlobalKey<ListaPaginadaState>();
  String _buscar = '';
  int? _rol;
  bool? _activo;
  List<Map<String, dynamic>> _roles = [];

  @override
  void initState() {
    super.initState();
    _cargarRoles();
  }

  Future<void> _cargarRoles() async {
    try {
      final r = await widget.api.roles();
      if (mounted) setState(() => _roles = r);
    } catch (_) {
      // Sin roles igual se puede listar; solo faltan los filtros por rol.
    }
  }

  Future<void> _abrirForm([Map<String, dynamic>? u]) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UsuarioFormPage(api: widget.api, usuario: u),
      ),
    );
    if (ok == true) _lista.currentState?.recargar();
  }

  Future<void> _cambiarEstado(Map<String, dynamic> u) async {
    final activar = u['activo'] != true;
    if (!activar) {
      final ok = await confirmar(
        context,
        titulo: 'Desactivar cuenta',
        mensaje:
            '${u['nombre']} ya no podrá iniciar sesión. Su historial se conserva.',
        textoConfirmar: 'Desactivar',
        icono: Icons.person_off_rounded,
        peligro: true,
      );
      if (!ok || !mounted) return;
    }
    try {
      if (activar) {
        await widget.api.actualizarUsuario(u['id'] as int, {'activo': true});
      } else {
        await widget.api.desactivarUsuario(u['id'] as int);
      }
      if (!mounted) return;
      mostrarAviso(context, activar ? 'Cuenta activada' : 'Cuenta desactivada');
      _lista.currentState?.recargar();
    } catch (e) {
      if (mounted) mostrarAviso(context, mensajeError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: FloatingActionButton.extended(
      heroTag: null,
      onPressed: () => _abrirForm(),
      icon: const Icon(Icons.person_add_alt_1_rounded),
      label: const Text('Registrar'),
    ),
    body: Column(
      children: [
        const CabeceraSeccion(
          titulo: 'Usuarios',
          subtitulo: 'Registra y administra cuentas',
          icono: Icons.group_rounded,
          seccion: Seccion.usuarios,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: CampoBusqueda(
            hint: 'Buscar por nombre o correo',
            onCambio: (v) => setState(() => _buscar = v),
          ),
        ),
        FilaFiltros<int?>(
          valor: _rol,
          onCambio: (v) => setState(() => _rol = v),
          opciones: [
            const OpcionFiltro<int?>('Todos', null, Icons.apps_rounded),
            for (final r in _roles)
              OpcionFiltro<int?>(
                '${r['nombre']}',
                r['id'] as int,
                EstiloRol.de('${r['nombre']}').icono,
              ),
          ],
        ),
        const SizedBox(height: 8),
        FilaFiltros<bool?>(
          valor: _activo,
          onCambio: (v) => setState(() => _activo = v),
          opciones: const [
            OpcionFiltro<bool?>('Cualquier estado', null),
            OpcionFiltro<bool?>('Activos', true, Icons.check_circle_rounded),
            OpcionFiltro<bool?>('Inactivos', false, Icons.block_rounded),
          ],
        ),
        Expanded(
          child: ListaPaginada(
            key: _lista,
            filtro: '$_buscar|$_rol|$_activo',
            cargar: (p) => widget.api.usuarios(
              p,
              buscar: _buscar,
              rol: _rol,
              activo: _activo,
            ),
            itemBuilder: (_, u) => _TarjetaUsuario(
              api: widget.api,
              usuario: u,
              esYo: u['id'] == widget.api.usuario?['id'],
              onEditar: () => _abrirForm(u),
              onCambiarEstado: () => _cambiarEstado(u),
            ),
            vacio: const EstadoVacio(
              titulo: 'Sin resultados',
              mensaje:
                  'No hay usuarios con esos filtros.\n'
                  'Toca “Registrar” para crear uno nuevo.',
            ),
          ),
        ),
      ],
    ),
  );
}

class _TarjetaUsuario extends StatelessWidget {
  final ApiService api;
  final Map<String, dynamic> usuario;
  final bool esYo;
  final VoidCallback onEditar;
  final VoidCallback onCambiarEstado;
  const _TarjetaUsuario({
    required this.api,
    required this.usuario,
    required this.esYo,
    required this.onEditar,
    required this.onCambiarEstado,
  });

  @override
  Widget build(BuildContext context) {
    final rol = '${usuario['rol_nombre']}';
    final estilo = EstiloRol.de(rol);
    final activo = usuario['activo'] == true;
    final nombre = '${usuario['nombre']}'.trim();
    return Opacity(
      opacity: activo ? 1 : 0.65,
      child: PanelCard(
        onTap: onEditar,
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        child: Row(
          children: [
            AvatarUsuario(
              api: api,
              nombre: nombre,
              usuarioId: usuario['id'] as int,
              version: usuario['foto_version'] as String?,
              color: estilo.color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    esYo ? '$nombre (tú)' : nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15.5,
                    ),
                  ),
                  Text(
                    '${usuario['email']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Paleta.tintaSuave,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Etiqueta(rol, icono: estilo.icono, fondo: estilo.suave),
                      if (!activo)
                        const Etiqueta(
                          'Inactivo',
                          icono: Icons.block_rounded,
                          fondo: Paleta.coralSuave,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (v) => v == 'editar' ? onEditar() : onCambiarEstado(),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'editar',
                  child: ListTile(
                    leading: Icon(Icons.edit_rounded),
                    title: Text('Editar'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (!esYo)
                  PopupMenuItem(
                    value: 'estado',
                    child: ListTile(
                      leading: Icon(
                        activo
                            ? Icons.person_off_rounded
                            : Icons.person_rounded,
                      ),
                      title: Text(activo ? 'Desactivar' : 'Activar'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
