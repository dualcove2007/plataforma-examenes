import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
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
  int? _rolId;
  bool _activo = true;
  bool _verClave = false;
  bool _guardando = false;
  String? _error;

  bool get _editando => widget.usuario != null;
  bool get _esYo =>
      _editando && widget.usuario!['id'] == widget.api.usuario?['id'];

  @override
  void initState() {
    super.initState();
    if (_editando) {
      _rolId = widget.usuario!['rol'] as int?;
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
        _rolId ??=
            r.firstWhere(
                  (x) => x['nombre'] == 'Estudiante',
                  orElse: () => r.first,
                )['id']
                as int?;
      });
    } catch (e) {
      if (mounted) setState(() => _errorRoles = mensajeError(e));
    }
  }

  String _generarClave() {
    const car = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    final base = List.generate(10, (_) => car[r.nextInt(car.length)]).join();
    return '$base*';
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    if (_rolId == null) {
      mostrarAviso(context, 'Elige un rol', error: true);
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
      'activo': _activo,
      if (clave.text.isNotEmpty) 'password': clave.text,
    };
    try {
      if (_editando) {
        await widget.api.actualizarUsuario(widget.usuario!['id'] as int, datos);
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        await widget.api.crearUsuario(datos);
        if (!mounted) return;
        await _dialogoExito(datos['email'] as String, clave.text);
        if (!mounted) return;
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) setState(() => _error = mensajeError(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _dialogoExito(String correo, String password) {
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
                    : 'Mínimo 8 caracteres, no solo números',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Generar contraseña',
                      icon: const Icon(Icons.casino_rounded),
                      onPressed: () => setState(() {
                        clave.text = _generarClave();
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
                if (s.isNotEmpty && s.length < 8) return 'Mínimo 8 caracteres';
                return null;
              },
            ),
            _titulo('Rol', Icons.shield_rounded),
            if (_roles == null && _errorRoles == null)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorRoles != null)
              EstadoError(mensaje: _errorRoles!, onReintentar: _cargarRoles)
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in _roles!)
                    ChoiceChip(
                      avatar: Icon(
                        EstiloRol.de('${r['nombre']}').icono,
                        size: 18,
                      ),
                      label: Text('${r['nombre']}'),
                      selected: _rolId == r['id'],
                      selectedColor: EstiloRol.de('${r['nombre']}').suave,
                      onSelected: _esYo
                          ? null
                          : (_) => setState(() => _rolId = r['id'] as int),
                    ),
                ],
              ),
            if (_esYo)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'No puedes cambiar tu propio rol.',
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
