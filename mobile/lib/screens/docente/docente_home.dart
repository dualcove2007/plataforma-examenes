import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/sesion.dart';
import '../../widgets/ui.dart';

/// Panel del docente. PROVISIONAL: mientras se construye el panel completo
/// (bancos de preguntas, exámenes, asignación y revisión) solo muestra un aviso
/// y permite cerrar sesión, para que el docente no caiga en la vista de estudiante.
class DocenteHome extends StatelessWidget {
  final ApiService api;
  const DocenteHome({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    final nombre = '${api.usuario?['nombre'] ?? 'docente'}'.split(' ').first;
    return Scaffold(
      body: Column(
        children: [
          CabeceraSeccion(
            titulo: 'Hola, $nombre',
            subtitulo: 'Panel docente',
            icono: Icons.cast_for_education_rounded,
            seccion: Seccion.resultados,
            acciones: [
              IconButton(
                tooltip: 'Cerrar sesión',
                icon: const Icon(Icons.logout_rounded),
                onPressed: () => cerrarSesion(context, api),
              ),
            ],
          ),
          const Expanded(
            child: EstadoVacio(
              titulo: 'Estamos preparando tu panel',
              mensaje:
                  'Muy pronto podrás crear exámenes, asignarlos y revisar respuestas desde aquí.',
            ),
          ),
        ],
      ),
    );
  }
}
