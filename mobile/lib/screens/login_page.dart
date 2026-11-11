import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'home_segun_rol.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final api = ApiService();
  final _form = GlobalKey<FormState>();
  final email = TextEditingController();
  final pass = TextEditingController();
  String? error;
  bool cargando = false;
  bool ocultar = true;

  @override
  void dispose() {
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  Future<void> entrar() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      cargando = true;
      error = null;
    });
    try {
      await api.login(email.text.trim(), pass.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => homeSegunRol(api)),
      );
    } catch (e) {
      if (mounted) setState(() => error = mensajeError(e));
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Paleta.crema,
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            children: [
              // ── Cabecera con ilustración ──
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Paleta.verde,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(40),
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const IconBadge(
                              Icons.school_rounded,
                              fondo: Paleta.miel,
                              tam: 44,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Plataforma de Exámenes',
                              style: t.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SvgPicture.asset(
                          'assets/images/login_hero.svg',
                          height: 190,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Formulario ──
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¡Hola de nuevo! 👋',
                        style: t.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Inicia sesión para continuar con tus exámenes.',
                        style: TextStyle(color: Paleta.tintaSuave),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return 'Escribe tu correo';
                          if (!s.contains('@')) return 'Correo no válido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: pass,
                        obscureText: ocultar,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => cargando ? null : entrar(),
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip: ocultar ? 'Mostrar' : 'Ocultar',
                            icon: Icon(
                              ocultar
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setState(() => ocultar = !ocultar),
                          ),
                        ),
                        validator: (v) =>
                            (v ?? '').isEmpty ? 'Escribe tu contraseña' : null,
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Paleta.coralSuave,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_rounded,
                                color: Color(0xFFB3261E),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  error!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: cargando ? null : entrar,
                        icon: cargando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.login_rounded),
                        label: Text(cargando ? 'Entrando...' : 'Entrar'),
                      ),
                      const SizedBox(height: 28),
                      const Center(
                        child: Text(
                          'Acceso para',
                          style: TextStyle(
                            color: Paleta.tintaSuave,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Etiqueta(
                            'Administradores',
                            icono: Icons.admin_panel_settings_rounded,
                            fondo: Paleta.lilaSuave,
                          ),
                          Etiqueta(
                            'Docentes',
                            icono: Icons.cast_for_education_rounded,
                            fondo: Paleta.cieloSuave,
                          ),
                          Etiqueta(
                            'Estudiantes',
                            icono: Icons.school_rounded,
                            fondo: Paleta.mielSuave,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
