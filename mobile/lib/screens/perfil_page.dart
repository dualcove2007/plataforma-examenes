import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/foto_picker.dart';
import '../widgets/sesion.dart';
import '../widgets/ui.dart';
import 'notificaciones_page.dart';

/// Abre el perfil encima de la pantalla actual (admin y docente lo usan desde su cabecera).
Future<void> abrirPerfil(BuildContext context, ApiService api) =>
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PerfilPage(api: api, enRuta: true)),
    );

/// Perfil del usuario: su foto, sus datos, notificaciones y cierre de sesión.
class PerfilPage extends StatefulWidget {
  final ApiService api;

  /// true cuando se abre encima de otra pantalla: muestra el botón de volver.
  final bool enRuta;
  const PerfilPage({super.key, required this.api, this.enRuta = false});

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  late Future<int> noLeidas = _contar();
  bool _subiendo = false;

  Future<void> _menuFoto() async {
    final tiene = widget.api.usuario?['foto_version'] != null;
    final accion = await menuFoto(context, tieneFoto: tiene);
    if (accion == null || !mounted) return;
    try {
      if (accion == AccionFoto.quitar) {
        setState(() => _subiendo = true);
        await widget.api.quitarMiFoto();
        if (mounted) mostrarAviso(context, 'Foto eliminada');
      } else {
        final f = await seleccionarFoto(accion);
        if (f == null || !mounted) return;
        setState(() => _subiendo = true);
        await widget.api.cambiarMiFoto(f.bytes, f.nombre);
        if (mounted) mostrarAviso(context, 'Foto actualizada');
      }
    } catch (e) {
      if (mounted) mostrarAviso(context, mensajeError(e), error: true);
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  Future<int> _contar() => widget.api.noLeidas().catchError((_) => 0);

  Future<void> _abrirNotificaciones() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NotificacionesPage(api: widget.api)),
    );
    if (mounted) setState(() => noLeidas = _contar());
  }

  /// "2026-11-02T14:05:00Z" → "2 nov 2026" (sin la hora).
  String _soloFecha(String? iso) {
    final completa = fechaCorta(iso);
    final coma = completa.indexOf(',');
    return coma == -1 ? completa : completa.substring(0, coma);
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.api.usuario ?? const <String, dynamic>{};
    final nombre = '${u['nombre'] ?? 'Usuario'}';
    final rol = u['rol'] as String?;
    final estilo = EstiloRol.de(rol);
    final version = u['foto_version'] as String?;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: Column(
        children: [
          CabeceraSeccion(
            titulo: 'Mi perfil',
            subtitulo: 'Tu cuenta y tus avisos',
            icono: Icons.person_rounded,
            seccion: Seccion.perfil,
            leading: widget.enRuta
                ? IconButton(
                    tooltip: 'Volver',
                    color: Seccion.perfil.texto,
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : null,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                PanelCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _subiendo ? null : _menuFoto,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            AvatarUsuario(
                              api: widget.api,
                              nombre: nombre,
                              version: version,
                              tam: 88,
                              color: estilo.color,
                              grosorBorde: 3,
                            ),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Paleta.verde,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: _subiendo
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.photo_camera_rounded,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _subiendo ? null : _menuFoto,
                        child: Text(
                          version == null ? 'Agregar foto' : 'Cambiar foto',
                        ),
                      ),
                      Text(
                        nombre,
                        textAlign: TextAlign.center,
                        style: t.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${u['email'] ?? ''}',
                        style: const TextStyle(color: Paleta.tintaSuave),
                      ),
                      const SizedBox(height: 10),
                      Etiqueta(
                        rol ?? 'Sin rol',
                        icono: estilo.icono,
                        fondo: estilo.suave,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                PanelCard(
                  child: Column(
                    children: [
                      _Fila(
                        Icons.mail_outline_rounded,
                        Paleta.cieloSuave,
                        'Correo',
                        '${u['email'] ?? '—'}',
                      ),
                      const Divider(height: 24),
                      _Fila(
                        estilo.icono,
                        estilo.suave,
                        'Rol',
                        rol ?? '—',
                      ),
                      const Divider(height: 24),
                      _Fila(
                        Icons.calendar_month_rounded,
                        Paleta.mielSuave,
                        'Miembro desde',
                        _soloFecha(u['fecha_creacion'] as String?),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<int>(
                  future: noLeidas,
                  builder: (context, snap) {
                    final n = snap.data ?? 0;
                    return PanelCard(
                      onTap: _abrirNotificaciones,
                      child: Row(
                        children: [
                          const IconBadge(
                            Icons.notifications_rounded,
                            fondo: Paleta.lilaSuave,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Notificaciones',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  n == 0
                                      ? 'Estás al día'
                                      : n == 1
                                      ? '1 sin leer'
                                      : '$n sin leer',
                                  style: const TextStyle(
                                    color: Paleta.tintaSuave,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (n > 0)
                            Etiqueta('$n', fondo: Paleta.coralSuave),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Paleta.tintaSuave,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: const Color(0xFFB3261E),
                    side: const BorderSide(color: Paleta.coral, width: 1.5),
                  ),
                  onPressed: () => cerrarSesion(context, widget.api),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Cerrar sesión'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  final IconData icono;
  final Color fondo;
  final String titulo;
  final String valor;
  const _Fila(this.icono, this.fondo, this.titulo, this.valor);

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconBadge(icono, fondo: fondo, tam: 40),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Paleta.tintaSuave,
              ),
            ),
            Text(valor, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    ],
  );
}
