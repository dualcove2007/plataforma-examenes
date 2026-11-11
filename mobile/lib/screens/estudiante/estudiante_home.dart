import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import 'inicio_page.dart';
import 'materias_page.dart';
import 'mis_examenes_page.dart';
import '../perfil_page.dart';
import 'resultados_page.dart';

/// Contenedor del estudiante con navegación inferior.
///
/// A diferencia del panel de admin, aquí cada pestaña se vuelve a crear al
/// visitarla: así siempre muestra datos frescos (por ejemplo, la nota que
/// acaba de salir después de presentar un examen).
class EstudianteHome extends StatefulWidget {
  final ApiService api;
  const EstudianteHome({super.key, required this.api});

  @override
  State<EstudianteHome> createState() => _EstudianteHomeState();
}

class _EstudianteHomeState extends State<EstudianteHome> {
  int tab = 0;

  Widget _pagina() => switch (tab) {
    0 => InicioPage(
      key: const ValueKey('inicio'),
      api: widget.api,
      onIrA: (i) => setState(() => tab = i),
    ),
    1 => MisExamenesPage(key: const ValueKey('examenes'), api: widget.api),
    2 => ResultadosPage(key: const ValueKey('resultados'), api: widget.api),
    3 => MateriasPage(key: const ValueKey('materias'), api: widget.api),
    _ => PerfilPage(key: const ValueKey('perfil'), api: widget.api),
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    body: _pagina(),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (i) => setState(() => tab = i),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Inicio',
        ),
        NavigationDestination(
          icon: Icon(Icons.assignment_outlined),
          selectedIcon: Icon(Icons.assignment_rounded),
          label: 'Exámenes',
        ),
        NavigationDestination(
          icon: Icon(Icons.emoji_events_outlined),
          selectedIcon: Icon(Icons.emoji_events_rounded),
          label: 'Resultados',
        ),
        NavigationDestination(
          icon: Icon(Icons.menu_book_outlined),
          selectedIcon: Icon(Icons.menu_book_rounded),
          label: 'Materias',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Perfil',
        ),
      ],
    ),
  );
}
