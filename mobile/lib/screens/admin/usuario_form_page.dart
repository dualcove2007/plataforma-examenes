import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/clave.dart';
import '../../widgets/avatar.dart';
import '../../widgets/foto_picker.dart';
import '../../widgets/ui.dart';

/// Registro (usuario == null) o edición de un usuario. Solo el admin llega aquí.
class UsuarioFormPage extends StatefulWidget {
  final ApiService api;
  final Map<String, dynamic>? usuario;
  const UsuarioFormPage({super.key, required this.api, this.usuario});

  @override
  State<UsuarioFormPage> createState() => _UsuarioFormPageState();
}

class _UsuarioFormPageState extends State<UsuarioFormPage> {
  final _form = GlobalKey<FormState>();
  late final nombre = TextEditingController(
    text: widget.usuario?['nombre'] as String? ?? '',
  );
  late final email = TextEditingController(
    text: widget.usuario?['email'] as String? ?? '',
  );
  final clave = TextEditingController();

  List<Map<String, dynamic>>? _roles;
  String? _errorRoles;
  int? _rolId; // rol principal de la cuenta
  final Set<int> _rolesIds = {}; // todos los roles con los que puede entrar
  Set<int> _rolesOriginales = {}; // al editar: los que ya tenía
  bool _activo = true;
  bool _verClave = false;
  bool _guardando = false;
  String? _error;
  FotoElegida? _foto; // foto nueva elegida (aún sin subir)
  bool _quitarFoto = false; // al editar: quitar la foto actual

  bool get _tieneFoto =>
      _foto != null ||
      (_editando && !_quitarFoto && widget.usuario!['foto_version'] != null);

  bool get _editando => widget.usuario != null;
  bool get _esYo =>
      _editando && widget.usuario!['id'] == widget.api.usuario?['id'];

  @override
  void initState() {
    super.initState();
    if (_editando) {
      _rolId = widget.usuario!['rol'] as int?;
      _rolesIds.addAll(
        ((widget.usuario!['roles'] as List?) ?? [_rolId]).whereType<int>(),
      );
      _rolesOriginales = {..._rolesIds};
      _activo = widget.usuario!['activo'] == true;
    }
    _cargarRoles();
  }

  @override
  void dispose() {
    nombre.dispose();
    email.dispose();
    clave.dispose();
    super.dispose();
  }

  Future<void> _cargarRoles() async {
    setState(() => _errorRoles = null);
    try {
      final r = await widget.api.roles();
      if (!mounted) return;
      setState(() {
        _roles = r;
        // Al registrar, el rol por defecto es Estudiante.
        if (_rolId == null) {
          _rolId =
              r.firstWhere(
                    (x) => x['nombre'] == 'Estudiante',
                    orElse: () => r.first,
                  )['id']
                  as int?;
          _rolesIds.add(_rolId!);
        }
      });
    } catch (e) {
      if (mounted) setState(() => _errorRoles = mensajeError(e));
    }
  }

  /// El servidor devuelve los roles que guardó. Si no coinciden con los
  /// marcados, el backend que está corriendo no es la versión nueva.
  void _verificarRoles(Map<String, dynamic> respuesta) {
    final guardados = ((respuesta['roles'] as List?) ?? const [])
        .whereType<int>()
        .toSet();
    if (guardados.length != _rolesIds.length ||
        !guardados.containsAll(_rolesIds)) {
      throw Exception(
        'El servidor no guardó los roles marcados. Reinicia el backend con '
        'el código nuevo y vuelve a guardar.',
      );
    }
  }

  /// Marca o desmarca un rol. El principal siempre es uno de los marcados.
  void _alternarRol(int id) => setState(() {
    if (_rolesIds.contains(id)) {
      if (_rolesIds.length == 1) return; // siempre debe quedar uno
      _rolesIds.remove(id);
      if (_rolId == id) _rolId = _rolesIds.first;
    } else {
      _rolesIds.add(id);
    }
  });

  Future<void> _elegirFoto() async {
    final accion = await menuFoto(context, tieneFoto: _tieneFoto);
    if (accion == null || !mounted) return;
    if (accion == AccionFoto.quitar) {
      setState(() {
        _foto = null;
        _quitarFoto = _editando && widget.usuario!['foto_version'] != null;
      });
      return;
    }
    try {
      final f = await seleccionarFoto(accion);
      if (f != null && mounted) {
        setState(() {
          _foto = f;
          _quitarFoto = false;
        });
      }
    } catch (e) {
      if (mounted) mostrarAviso(context, mensajeError(e), error: true);
    }
  }

  /// Sube o quita la foto del usuario ya guardado. Devuelve un aviso si falla.
  Future<String?> _guardarFoto(int id) async {
    try {
      if (_foto != null) {
        await widget.api.subirFotoUsuario(id, _foto!.bytes, _foto!.nombre);
      } else if (_quitarFoto) {
        await widget.api.quitarFotoUsuario(id);
      }
      return null;
    } catch (e) {
      return 'Los datos se guardaron, pero la foto no: ${mensajeError(e)}';
    }
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    if (_rolId == null || _rolesIds.isEmpty) {
      mostrarAviso(context, 'Elige al menos un rol', error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _guardando = true;
      _error = null;
    });
    final datos = <String, dynamic>{
      'nombre': nombre.text.trim(),
      'email': email.text.trim().toLowerCase(),
      'rol': _rolId,
      'roles': _rolesIds.toList(),
      'activo': _activo,
      if (clave.text.isNotEmpty) 'password': clave.text,
    };
    try {
      if (_editando) {
        final id = widget.usuario!['id'] as int;
        final guardado = await widget.api.actualizarUsuario(id, datos);
        _verificarRoles(guardado);
        if (!mounted) return;
        final avisoFoto = await _guardarFoto(id);
        if (!mounted) return;
        if (avisoFoto != null) mostrarAviso(context, avisoFoto, error: true);
        Navigator.pop(context, true);
      } else {
        final nuevo = await widget.api.crearUsuario(datos);
        _verificarRoles(nuevo);
        if (!mounted) return;
        final avisoFoto = await _guardarFoto(nuevo['id'] as int);
        if (!mounted) return;
        await _dialogoExito(
          datos['email'] as String,
          clave.text,
          avisoFoto: avisoFoto,
        );
        if (!mounted) return;
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) setState(() => _error = mensajeError(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _dialogoExito(
    String correo,
    String password, {
    String? avisoFoto,
  }) {
    var copiado = false;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          icon: const IconBadge(
            Icons.check_rounded,
            fondo: Paleta.verdeSuave,
            tam: 60,
          ),
          title: const Text(
            '¡Usuario registrado!',
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Entrégale estos datos. La contraseña no se vuelve a mostrar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Paleta.tintaSuave),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Paleta.crema,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Paleta.borde, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Correo',
                      style: TextStyle(
                        color: Paleta.tintaSuave,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SelectableText(
                      correo,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Contraseña',
                      style: TextStyle(
                        color: Paleta.tintaSuave,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SelectableText(
                      password,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              if (avisoFoto != null) ...[
                const SizedBox(height: 10),
                Text(
                  avisoFoto,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFB3261E),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: 'Correo: $correo\nContraseña: $password'),
                );
                setD(() => copiado = true);
              },
              icon: Icon(copiado ? Icons.check_rounded : Icons.copy_rounded),
              label: Text(copiado ? '¡Copiado!' : 'Copiar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Listo'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _titulo(String t, IconData i) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 10),
    child: Row(
      children: [
        Icon(i, size: 20, color: Paleta.verde),
        const SizedBox(width: 8),
        Text(
          t,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
        ),
      ],
    ),
  );

  Widget _vistaFoto() {
    const tam = 84.0;
    if (_foto != null) {
      return ClipOval(
        child: Image.memory(
          _foto!.bytes,
          width: tam,
          height: tam,
          fit: BoxFit.cover,
        ),
      );
    }
    final u = widget.usuario;
    return AvatarUsuario(
      api: widget.api,
      nombre: nombre.text,
      usuarioId: u?['id'] as int?,
      version: _quitarFoto ? null : u?['foto_version'] as String?,
      tam: tam,
      grosorBorde: 2.5,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar usuario' : 'Registrar usuario'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            PanelCard(
              color: Paleta.cieloSuave,
              child: Row(
                children: [
                  IconBadge(
                    _editando
                        ? Icons.manage_accounts_rounded
                        : Icons.person_add_alt_1_rounded,
                    fondo: Colors.white,
                    tam: 48,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _editando
                          ? 'Cambia los datos de la cuenta. Si escribes una '
                                'contraseña nueva, se cerrarán sus sesiones abiertas.'
                          : 'El usuario entrará con este correo y contraseña. '
                                'Cada cuenta la crea un administrador.',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            _titulo('Foto de perfil', Icons.photo_camera_rounded),
            Row(
              children: [
                _vistaFoto(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _guardando ? null : _elegirFoto,
                        icon: const Icon(Icons.add_a_photo_rounded),
                        label: Text(
                          _tieneFoto ? 'Cambiar o quitar' : 'Agregar foto',
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Opcional. JPG o PNG.',
                        style: TextStyle(
                          color: Paleta.tintaSuave,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            _titulo('Datos personales', Icons.badge_rounded),
            TextFormField(
              controller: nombre,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nombre completo',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Escribe el nombre' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return 'Escribe el correo';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) {
                  return 'Correo no válido';
                }
                return null;
              },
            ),
            _titulo('Contraseña', Icons.key_rounded),
            TextFormField(
              controller: clave,
              obscureText: !_verClave,
              decoration: InputDecoration(
                labelText: _editando
                    ? 'Nueva contraseña (opcional)'
                    : 'Contraseña',
                helperText: _editando
                    ? 'Déjala vacía para no cambiarla'
                    : 'Letras, números y un carácter especial',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Generar contraseña',
                      icon: const Icon(Icons.casino_rounded),
                      onPressed: () => setState(() {
                        clave.text = generarClave();
                        _verClave = true;
                      }),
                    ),
                    IconButton(
                      tooltip: _verClave ? 'Ocultar' : 'Mostrar',
                      icon: Icon(
                        _verClave
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () => setState(() => _verClave = !_verClave),
                    ),
                  ],
                ),
              ),
              validator: (v) {
                final s = v ?? '';
                if (!_editando && s.isEmpty)
                  return 'La contraseña es obligatoria';
                return s.isEmpty ? null : validarClave(s);
              },
            ),
            _ReglasClave(controller: clave, opcional: _editando),
            _titulo('Roles', Icons.shield_rounded),
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'Puedes marcar varios. Si tiene más de uno, al iniciar sesión '
                'elegirá con cuál entrar.',
                style: TextStyle(color: Paleta.tintaSuave, fontSize: 13),
              ),
            ),
            if (_roles == null && _errorRoles == null)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorRoles != null)
              EstadoError(mensaje: _errorRoles!, onReintentar: _cargarRoles)
            else
              PanelCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (final r in _roles!)
                      CheckboxListTile(
                        value: _rolesIds.contains(r['id']),
                        // Sobre sí mismo solo puede agregar roles, no quitarlos.
                        onChanged: _esYo && _rolesOriginales.contains(r['id'])
                            ? null
                            : (_) => _alternarRol(r['id'] as int),
                        controlAffinity: ListTileControlAffinity.trailing,
                        secondary: IconBadge(
                          EstiloRol.de('${r['nombre']}').icono,
                          fondo: EstiloRol.de('${r['nombre']}').suave,
                          tam: 40,
                        ),
                        title: Text(
                          '${r['nombre']}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
              ),
            if (_esYo)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'No puedes quitarte roles a ti mismo.',
                  style: TextStyle(color: Paleta.tintaSuave, fontSize: 13),
                ),
              ),
            const SizedBox(height: 18),
            PanelCard(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: SwitchListTile(
                value: _activo,
                onChanged: _esYo ? null : (v) => setState(() => _activo = v),
                secondary: IconBadge(
                  _activo ? Icons.check_circle_rounded : Icons.block_rounded,
                  fondo: _activo ? Paleta.verdeSuave : Paleta.coralSuave,
                  tam: 40,
                ),
                title: const Text(
                  'Cuenta activa',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  _esYo
                      ? 'No puedes desactivar tu propia cuenta'
                      : _activo
                      ? 'Puede iniciar sesión'
                      : 'No podrá iniciar sesión',
                ),
              ),
            ),
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
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _guardando ? null : _guardar,
              icon: _guardando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _editando ? Icons.save_rounded : Icons.person_add_rounded,
                    ),
              label: Text(
                _guardando
                    ? 'Guardando...'
                    : _editando
                    ? 'Guardar cambios'
                    : 'Registrar usuario',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lista de reglas que se va marcando mientras se escribe la contraseña.
class _ReglasClave extends StatelessWidget {
  final TextEditingController controller;
  final bool opcional;
  const _ReglasClave({required this.controller, required this.opcional});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<TextEditingValue>(
    valueListenable: controller,
    builder: (_, v, __) {
      if (opcional && v.text.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 10, left: 4),
        child: Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (final r in evaluarClave(v.text))
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    r.cumple
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color: r.cumple ? Paleta.verde : Paleta.tintaSuave,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    r.texto,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: r.cumple ? Paleta.verde : Paleta.tintaSuave,
                    ),
                  ),
                ],
              ),
          ],
        ),
      );
    },
  );
}
