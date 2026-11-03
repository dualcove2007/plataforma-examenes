import 'package:flutter/material.dart';
import '../services/api_service.dart';

class MateriasPage extends StatelessWidget {
  final ApiService api;
  const MateriasPage({super.key, required this.api});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Materias')),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: api.materias(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('${snap.error}'));
            }
            final items = snap.data!;
            if (items.isEmpty) {
              return const Center(child: Text('No hay materias'));
            }
            return ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) => ListTile(
                leading: const Icon(Icons.menu_book),
                title: Text(items[i]['nombre'] ?? ''),
                subtitle: Text(items[i]['descripcion'] ?? ''),
              ),
            );
          },
        ),
      );
}