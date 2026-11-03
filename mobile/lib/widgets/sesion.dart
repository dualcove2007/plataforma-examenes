import 'package:flutter/material.dart';

import '../screens/login_page.dart';
import '../services/api_service.dart';
import 'ui.dart';

/// Pregunta, revoca la sesión en el servidor y vuelve al login.
Future<void> cerrarSesion(BuildContext context, ApiService api) async {
  final ok = await confirmar(
    context,
    titulo: 'Cerrar sesión',
    mensaje: '¿Seguro que quieres salir de tu cuenta?',
    textoConfirmar: 'Salir',
    icono: Icons.logout_rounded,
    peligro: true,
  );
  if (!ok) return;
  await api.logout();
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginPage()),
    (_) => false,
  );
}
