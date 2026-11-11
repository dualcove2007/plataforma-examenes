import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'home_segun_rol.dart';
import 'login_page.dart';

/// Primera pantalla: si quedó una sesión guardada en el teléfono la retoma y
/// entra directo al panel; si no, muestra el login.
class ArranquePage extends StatefulWidget {
  const ArranquePage({super.key});

  @override
  State<ArranquePage> createState() => _ArranquePageState();
}

class _ArranquePageState extends State<ArranquePage> {
  final api = ApiService();
  String? _error;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    setState(() => _error = null);
    try {
      final hay = await api.restaurarSesion();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => hay ? homeSegunRol(api) : const LoginPage(),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = mensajeError(e));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: _error == null
          ? const CircularProgressIndicator()
          : Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const IconBadge(
                    Icons.wifi_off_rounded,
                    fondo: Paleta.coralSuave,
                    tam: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _iniciar,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reintentar'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    ),
                    child: const Text('Iniciar sesión de nuevo'),
                  ),
                ],
              ),
            ),
    ),
  );
}
