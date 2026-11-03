import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import 'bancos_page.dart';
import 'docente_dashboard_page.dart';
import 'examenes_page.dart';
import 'resultados_page.dart';

/// Contenedor del docente con navegación inferior.
///
/// Igual que en el estudiante, cada pestaña se vuelve a crear al visitarla
/// para mostrar datos frescos (por ejemplo, los resultados que acaban de llegar).
class DocenteHome extends StatefulWidget {
  final ApiService api;
  const DocenteHome({super.key, required this.api});

  @override
  State<DocenteHome> createState() => _DocenteHomeState();
}

class _DocenteHomeState extends State<DocenteHome> {
  int tab = 0;

  Widget _pagina() => switch (tab) {
    0 => DocenteDashboardPage(
      key: const ValueKey('inicio'),
      api: widget.api,
      onIrA: (i) => setState(() => tab = i),
    ),
    1 => BancosPage(key: const ValueKey('bancos'), api: widget.api),
    2 => DocenteExamenesPage(key: const ValueKey('examenes'), api: widget.api),
    _ => DocenteResultadosPage(
      key: const ValueKey('resultados'),
      api: widget.api,
    ),
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
          icon: Icon(Icons.folder_copy_outlined),
          selectedIcon: Icon(Icons.folder_copy_rounded),
          label: 'Bancos',
        ),
        NavigationDestination(
          icon: Icon(Icons.assignment_outlined),
          selectedIcon: Icon(Icons.assignment_rounded),
          label: 'Exámenes',
        ),
        NavigationDestination(
          icon: Icon(Icons.fact_check_outlined),
          selectedIcon: Icon(Icons.fact_check_rounded),
          label: 'Resultados',
        ),
      ],
    ),
  );
}
