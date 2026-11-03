import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/sesion.dart';
import 'examen_page.dart';

class MisExamenesPage extends StatefulWidget {
  final ApiService api;
  const MisExamenesPage({super.key, required this.api});

  @override
  State<MisExamenesPage> createState() => _MisExamenesPageState();
}

class _MisExamenesPageState extends State<MisExamenesPage> {
  late Future<List<Map<String, dynamic>>> futuro = _cargar();

  Future<List<Map<String, dynamic>>> _cargar() async {
    final res = await Future.wait([
      widget.api.misExamenes(),
      widget.api.intentos(),
    ]);
    final examenes = res[0];
    final intentos = res[1];
    return [
      for (final e in examenes)
        {
          ...e,
          'usados': intentos
              .where((i) => i['asignacion'] == e['id'] && i['estado'] != 'anulado')
              .length,
        },
    ];
  }

  void _recargar() => setState(() => futuro = _cargar());

  Future<void> _abrir(Map<String, dynamic> e) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExamenPage(
          api: widget.api,
          asignacionId: e['id'] as int,
          titulo: '${e['titulo']}',
        ),
      ),
    );
    if (mounted) _recargar();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Mis exámenes'),
          actions: [
            IconButton(
              tooltip: 'Cerrar sesión',
              icon: const Icon(Icons.logout_rounded),
              onPressed: () => cerrarSesion(context, widget.api),
            ),
          ],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: futuro,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('${snap.error}'));
            }
            final items = snap.data!;
            if (items.isEmpty) {
              return const Center(child: Text('No tienes exámenes asignados'));
            }
            return RefreshIndicator(
              onRefresh: () async {
                _recargar();
                await futuro;
              },
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final e = items[i];
                  final usados = e['usados'] as int;
                  final permitidos = e['intentos_permitidos'] as int;
                  final agotado = usados >= permitidos;
                  final abierto = e['examen_estado'] == 'publicado' && !agotado;
                  return ListTile(
                    leading: const Icon(Icons.assignment),
                    title: Text(e['titulo'] ?? ''),
                    subtitle: Text(
                      '${e['materia']} · ${e['duracion_minutos']} min · '
                      '${e['total_preguntas']} preguntas\n'
                      'Intentos: $usados de $permitidos',
                    ),
                    isThreeLine: true,
                    trailing: Text(agotado ? 'Completado' : '${e['estado']}'),
                    enabled: abierto,
                    onTap: abierto ? () => _abrir(e) : null,
                  );
                },
              ),
            );
          },
        ),
      );
}