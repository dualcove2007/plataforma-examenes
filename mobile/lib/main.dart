import 'package:flutter/material.dart';
import 'api_service.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Exámenes',
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: const LoginPage(),
      );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final api = ApiService();
  final email = TextEditingController(text: 'estudiante@demo.com');
  final pass = TextEditingController(text: 'Demo12345*');
  String? error;
  bool cargando = false;

  Future<void> entrar() async {
    setState(() {
      cargando = true;
      error = null;
    });
    try {
      await api.login(email.text.trim(), pass.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => MateriasPage(api: api)),
      );
    } catch (e) {
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Iniciar sesión')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              TextField(
                controller: email,
                decoration: const InputDecoration(labelText: 'Correo'),
              ),
              TextField(
                controller: pass,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Contraseña'),
              ),
              const SizedBox(height: 16),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              FilledButton(
                onPressed: cargando ? null : entrar,
                child: Text(cargando ? 'Entrando...' : 'Entrar'),
              ),
            ],
          ),
        ),
      );
}

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