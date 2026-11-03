import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'materias_page.dart';
import 'mis_examenes_page.dart';

class HomePage extends StatefulWidget {
  final ApiService api;
  const HomePage({super.key, required this.api});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final paginas = [
      MisExamenesPage(api: widget.api),
      MateriasPage(api: widget.api),
    ];
    return Scaffold(
      body: paginas[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.assignment), label: 'Mis exámenes'),
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'Materias'),
        ],
      ),
    );
  }
}