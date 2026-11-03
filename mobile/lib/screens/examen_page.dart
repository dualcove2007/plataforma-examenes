import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'resultado_page.dart';

class ExamenPage extends StatefulWidget {
  final ApiService api;
  final int asignacionId;
  final String titulo;
  const ExamenPage({
    super.key,
    required this.api,
    required this.asignacionId,
    required this.titulo,
  });

  @override
  State<ExamenPage> createState() => _ExamenPageState();
}

class _ExamenPageState extends State<ExamenPage> {
  Map<String, dynamic>? intento;
  String? error;
  int segundos = 0;
  Timer? reloj;
  bool enviando = false;
  final Map<int, Set<int>> seleccion = {};
  final Map<int, TextEditingController> textos = {};

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  @override
  void dispose() {
    reloj?.cancel();
    for (final c in textos.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _limpio(Object e) => e.toString().replaceFirst('Exception: ', '');

  void _aviso(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _arrancarReloj() {
    reloj?.cancel();
    reloj = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Future<void> _iniciar() async {
    try {
      final d = await widget.api.iniciarIntento(widget.asignacionId);
      for (final p in d['preguntas'] as List) {
        final id = p['pregunta'] as int;
        final r = p['respuesta'];
        seleccion[id] = r == null ? <int>{} : Set<int>.from(r['opciones'] as List);
        if (p['tipo'] == 'abierta') {
          textos[id] = TextEditingController(
            text: r == null ? '' : '${r['texto_respuesta']}',
          );
        }
      }
      if (!mounted) return;
      setState(() {
        intento = d;
        segundos = d['segundos_restantes'] as int;
      });
      _arrancarReloj();
    } catch (e) {
      if (mounted) setState(() => error = _limpio(e));
    }
  }

  void _tick() {
    if (segundos <= 0) return;
    setState(() => segundos--);
    if (segundos == 0) _enviar(automatico: true);
  }

  Future<void> _guardar(int preguntaId) async {
    try {
      final s = await widget.api.responder(
        intento!['id'] as int,
        preguntaId,
        opciones: (seleccion[preguntaId] ?? <int>{}).toList(),
        texto: textos[preguntaId]?.text ?? '',
      );
      if (mounted) setState(() => segundos = s);
    } catch (e) {
      if (mounted) _aviso(_limpio(e));
    }
  }

  void _elegir(int preguntaId, int opcionId, bool multiple) {
    final s = seleccion[preguntaId]!;
    setState(() {
      if (multiple) {
        if (s.contains(opcionId)) {
          s.remove(opcionId);
        } else {
          s.add(opcionId);
        }
      } else {
        s
          ..clear()
          ..add(opcionId);
      }
    });
    _guardar(preguntaId);
  }

  Future<void> _enviar({bool automatico = false}) async {
    if (enviando) return;
    if (!automatico) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Enviar examen'),
          content: const Text('Una vez enviado no podrás cambiar tus respuestas.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enviar'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => enviando = true);
    reloj?.cancel();
    try {
      if (!automatico) {
        for (final e in textos.entries) {
          if (e.value.text.trim().isNotEmpty) await _guardar(e.key);
        }
      }
      final res = await widget.api.enviar(intento!['id'] as int);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ResultadoPage(resultado: res)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => enviando = false);
      _aviso(_limpio(e));
      if (segundos > 0) _arrancarReloj();
    }
  }

  String get _tiempo {
    final m = (segundos ~/ 60).toString().padLeft(2, '0');
    final s = (segundos % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  IconData _icono(String tipo, bool marcada) {
    if (tipo == 'opcion_multiple') {
      return marcada ? Icons.check_box : Icons.check_box_outline_blank;
    }
    return marcada ? Icons.radio_button_checked : Icons.radio_button_unchecked;
  }

  Widget _tarjeta(int i, Map<String, dynamic> p) {
    final id = p['pregunta'] as int;
    final tipo = p['tipo'] as String;
    final opciones = List<Map<String, dynamic>>.from(p['opciones']);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${i + 1}. ${p['enunciado']}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('${p['puntaje']} pts', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            if (tipo == 'abierta')
              Focus(
                onFocusChange: (tiene) {
                  if (!tiene) _guardar(id);
                },
                child: TextField(
                  controller: textos[id],
                  maxLines: 5,
                  maxLength: 5000,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Escribe tu respuesta',
                  ),
                ),
              )
            else
              for (final o in opciones)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_icono(tipo, seleccion[id]!.contains(o['id']))),
                  title: Text('${o['texto']}'),
                  onTap: enviando
                      ? null
                      : () => _elegir(id, o['id'] as int, tipo == 'opcion_multiple'),
                ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.titulo)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(error!, textAlign: TextAlign.center),
          ),
        ),
      );
    }
    if (intento == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.titulo)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final preguntas = List<Map<String, dynamic>>.from(intento!['preguntas']);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titulo),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                _tiempo,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: segundos < 60 ? Colors.red : null,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: preguntas.length + 1,
        itemBuilder: (_, i) {
          if (i == preguntas.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: FilledButton(
                onPressed: enviando ? null : () => _enviar(),
                child: Text(enviando ? 'Enviando...' : 'Enviar examen'),
              ),
            );
          }
          return _tarjeta(i, preguntas[i]);
        },
      ),
    );
  }
}