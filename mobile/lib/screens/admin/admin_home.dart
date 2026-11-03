import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import 'admin_dashboard_page.dart';
import 'admin_materias_page.dart';
import 'auditoria_page.dart';
import 'roles_page.dart';
import 'usuarios_page.dart';

/// Contenedor del panel de administración con navegación inferior.
/// Cada pestaña se crea la primera vez que se visita y conserva su estado.
class AdminHome extends StatefulWidget {
  final ApiService api;
  const AdminHome({super.key, required this.api});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int tab = 0;
  final _visitadas = <int>{0};

  void _ir(int i) => setState(() {
    tab = i;
    _visitadas.add(i);
  });

  Widget _pagina(int i) => switch (i) {
    0 => AdminDashboardPage(api: widget.api, onIrA: _ir),
    1 => UsuariosPage(api: widget.api),
    2 => AdminMateriasPage(api: widget.api),
    3 => RolesPage(api: widget.api),
    _ => AuditoriaPage(api: widget.api),
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: tab,
      children: [
        for (var i = 0; i < 5; i++)
          _visitadas.contains(i) ? _pagina(i) : const SizedBox.shrink(),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: _ir,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard_rounded),
          label: 'Inicio',
        ),
        NavigationDestination(
          icon: Icon(Icons.group_outlined),
          selectedIcon: Icon(Icons.group_rounded),
          label: 'Usuarios',
        ),
        NavigationDestination(
          icon: Icon(Icons.menu_book_outlined),
          selectedIcon: Icon(Icons.menu_book_rounded),
          label: 'Materias',
        ),
        NavigationDestination(
          icon: Icon(Icons.shield_outlined),
          selectedIcon: Icon(Icons.shield_rounded),
          label: 'Roles',
        ),
        NavigationDestination(
          icon: Icon(Icons.history_outlined),
          selectedIcon: Icon(Icons.history_rounded),
          label: 'Auditoría',
        ),
      ],
    ),
  );
}
