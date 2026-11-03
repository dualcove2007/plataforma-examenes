import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final api = ApiService();
  final email = TextEditingController();
  final pass = TextEditingController();
  String? error;
  bool cargando = false;
  bool ocultar = true;

  Future<void> entrar() async {
    setState(() {
      cargando = true;
      error = null;
    });
    try {
      await api.login(email.text.trim(), pass.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomePage(api: api)),
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
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Correo'),
              ),
              TextField(
                controller: pass,
                obscureText: ocultar,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  suffixIcon: IconButton(
                    icon: Icon(ocultar ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => ocultar = !ocultar),
                  ),
                ),
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