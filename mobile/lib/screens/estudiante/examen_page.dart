import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import 'resultado_page.dart';

/// Presentar un examen: una pregunta por pantalla, con el tiempo siempre a la vista.
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

class _ExamenPageState extends State<ExamenPage> with WidgetsBindingObserver {
  Map<String, dynamic>? intento;
  String? error;

  /// Segundos que quedan. Se calculan contra [_limite] (no restando de a uno)
  /// para que no se desfasen si la app pasa a segundo plano.
  int segundos = 0;
  DateTime _limite = DateTime.now();
  Timer? reloj;

  bool enviando = false;
  int actual = 0;
  DateTime? _salida; // cuándo la app salió del primer plano

  final Map<int, Set<int>> seleccion = {};
  final Map<int, TextEditingController> textos = {};

  List<Map<String, dynamic>> get _preguntas =>
      List<Map<String, dynamic>>.from(intento!['preguntas'] as List);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _iniciar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    reloj?.cancel();
    for (final c in textos.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ───────────────────────── Anti-trampa (igual que la web) ─────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (intento == null || enviando) return;
    if (estado == AppLifecycleState.paused) {
      _salida ??= DateTime.now();
    } else if (estado == AppLifecycleState.resumed) {
      final desde = _salida;
      _salida = null;
      _tick(); // el reloj pudo quedarse dormido mientras estaba fuera
      if (desde != null) {
        final s = DateTime.now().difference(desde).inSeconds;
        if (s >= 1) {
          widget.api.registrarEvento(
            intento!['id'] as int,
            'salida_pestana',
            duracionSegundos: s,
          );
        }
      }
    }
  }

  // ───────────────────────── Carga y reloj ─────────────────────────

  Future<void> _iniciar() async {
    try {
      final d = await widget.api.iniciarIntento(widget.asignacionId);
      for (final p in d['preguntas'] as List) {
        final id = p['pregunta'] as int;
        final r = p['respuesta'];
        seleccion[id] = r == null
            ? <int>{}
            : Set<int>.from(r['opciones'] as List);
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
        _limite = DateTime.now().add(Duration(seconds: segundos));
      });
      _arrancarReloj();
    } catch (e) {
      if (mounted) setState(() => error = mensajeError(e));
    }
  }

  void _arrancarReloj() {
    reloj?.cancel();
    reloj = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted || intento == null || enviando) return;
    final restante = _limite.difference(DateTime.now()).inSeconds;
    final nuevo = restante < 0 ? 0 : restante;
    if (nuevo != segundos) setState(() => segundos = nuevo);
    if (nuevo == 0) _enviar(automatico: true);
  }

  String get _tiempo {
    final h = segundos ~/ 3600;
    final m = ((segundos % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (segundos % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  // ───────────────────────── Respuestas ─────────────────────────

  bool _respondida(Map<String, dynamic> p) {
    final id = p['pregunta'] as int;
    if (p['tipo'] == 'abierta') {
      return (textos[id]?.text.trim() ?? '').isNotEmpty;
    }
    return (seleccion[id] ?? <int>{}).isNotEmpty;
  }

  int get _respondidas => _preguntas.where(_respondida).length;

  Future<void> _guardar(int preguntaId) async {
    try {
      final s = await widget.api.responder(
        intento!['id'] as int,
        preguntaId,
        opciones: (seleccion[preguntaId] ?? <int>{}).toList(),
        texto: textos[preguntaId]?.text ?? '',
      );
      // El servidor es quien manda con el tiempo: nos resincronizamos.
      if (mounted) {
        setState(() {
          segundos = s;
          _limite = DateTime.now().add(Duration(seconds: s));
        });
      }
    } catch (e) {
      if (mounted) mostrarAviso(context, mensajeError(e), error: true);
    }
  }

  void _elegir(int preguntaId, int opcionId, bool multiple) {
    final s = seleccion[preguntaId]!;
    setState(() {
      if (multiple) {
        if (!s.remove(opcionId)) s.add(opcionId);
      } else {
        s
          ..clear()
          ..add(opcionId);
      }
    });
    _guardar(preguntaId);
  }

  /// Cambia de pregunta guardando antes lo que se haya escrito en una abierta.
  void _ir(int i) {
    if (i < 0 || i >= _preguntas.length || i == actual) return;
    final p = _preguntas[actual];
    if (p['tipo'] == 'abierta') _guardar(p['pregunta'] as int);
    FocusScope.of(context).unfocus();
    setState(() => actual = i);
  }

  // ───────────────────────── Enviar y salir ─────────────────────────

  Future<void> _enviar({bool automatico = false}) async {
    if (enviando) return;
    if (!automatico) {
      final faltan = _preguntas.length - _respondidas;
      final ok = await confirmar(
        context,
        titulo: 'Enviar examen',
        mensaje: faltan > 0
            ? 'Te faltan $faltan ${faltan == 1 ? 'pregunta' : 'preguntas'} por responder. '
                  'Una vez enviado no podrás cambiar tus respuestas.'
            : 'Una vez enviado no podrás cambiar tus respuestas.',
        textoConfirmar: 'Enviar',
        icono: Icons.send_rounded,
      );
      if (!ok || !mounted) return;
    }
    setState(() => enviando = true);
    reloj?.cancel();
    try {
      // Guarda las respuestas abiertas que hayan quedado sin guardar.
      for (final e in textos.entries) {
        if (e.value.text.trim().isNotEmpty) await _guardar(e.key);
      }
      final res = await widget.api.enviar(intento!['id'] as int);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultadoPage(
            api: widget.api,
            resultado: res,
            recienEnviado: true,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => enviando = false);
      mostrarAviso(context, mensajeError(e), error: true);
      if (_limite.isAfter(DateTime.now())) _arrancarReloj();
    }
  }

  Future<void> _salir() async {
    final ok = await confirmar(
      context,
      titulo: 'Salir del examen',
      mensaje:
          'Tu progreso queda guardado, pero el tiempo sigue corriendo. '
          'Puedes volver a entrar mientras te quede tiempo.',
      textoConfirmar: 'Salir',
      icono: Icons.exit_to_app_rounded,
      peligro: true,
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  // ───────────────────────── Pantalla ─────────────────────────

  @override
  Widget build(BuildContext context) {
    if (error != null) return _Aviso(titulo: widget.titulo, mensaje: error!);
    if (intento == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.titulo)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final preguntas = _preguntas;
    final esUltima = actual == preguntas.length - 1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !enviando) _salir();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          body: Column(
            children: [
              _Cabecera(
                titulo: widget.titulo,
                tiempo: _tiempo,
                urgente: segundos < 60,
                actual: actual,
                total: preguntas.length,
                respondidas: _respondidas,
                onSalir: enviando ? null : _salir,
              ),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: _tarjeta(preguntas[actual]),
                ),
              ),
              _Pie(
                total: preguntas.length,
                actual: actual,
                respondida: [for (final p in preguntas) _respondida(p)],
                enviando: enviando,
                esUltima: esUltima,
                onIr: _ir,
                onEnviar: () => _enviar(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (String, IconData) _tipo(String tipo) => switch (tipo) {
    'opcion_multiple' => ('Selección múltiple', Icons.checklist_rounded),
    'verdadero_falso' => ('Verdadero o falso', Icons.rule_rounded),
    'abierta' => ('Respuesta abierta', Icons.edit_note_rounded),
    _ => ('Selección única', Icons.radio_button_checked_rounded),
  };

  Widget _tarjeta(Map<String, dynamic> p) {
    final id = p['pregunta'] as int;
    final tipo = p['tipo'] as String;
    final (textoTipo, iconoTipo) = _tipo(tipo);
    final opciones = List<Map<String, dynamic>>.from(p['opciones'] as List);
    final multiple = tipo == 'opcion_multiple';
    final t = Theme.of(context).textTheme;

    return PanelCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Etiqueta(textoTipo, icono: iconoTipo, fondo: Paleta.cieloSuave),
              Etiqueta(
                '${p['puntaje']} pts',
                icono: Icons.star_rounded,
                fondo: Paleta.mielSuave,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${p['enunciado']}',
            style: t.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          if (multiple) ...[
            const SizedBox(height: 6),
            const Text(
              'Puedes marcar varias opciones.',
              style: TextStyle(color: Paleta.tintaSuave),
            ),
          ],
          const SizedBox(height: 16),
          if (tipo == 'abierta')
            Focus(
              onFocusChange: (tiene) {
                if (!tiene) _guardar(id);
              },
              child: TextField(
                controller: textos[id],
                enabled: !enviando,
                minLines: 6,
                maxLines: 10,
                maxLength: 5000,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Escribe tu respuesta aquí',
                ),
              ),
            )
          else
            for (var i = 0; i < opciones.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _Opcion(
                  letra: String.fromCharCode(65 + i),
                  texto: '${opciones[i]['texto']}',
                  marcada: seleccion[id]!.contains(opciones[i]['id']),
                  multiple: multiple,
                  onTap: enviando
                      ? null
                      : () => _elegir(id, opciones[i]['id'] as int, multiple),
                ),
              ),
        ],
      ),
    );
  }
}

// ───────────────────────── Piezas de la pantalla ─────────────────────────

class _Cabecera extends StatelessWidget {
  final String titulo;
  final String tiempo;
  final bool urgente;
  final int actual;
  final int total;
  final int respondidas;
  final VoidCallback? onSalir;
  const _Cabecera({
    required this.titulo,
    required this.tiempo,
    required this.urgente,
    required this.actual,
    required this.total,
    required this.respondidas,
    required this.onSalir,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      color: Paleta.verde,
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
    ),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 16, 18),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Salir',
                  color: Colors.white,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onSalir,
                ),
                Expanded(
                  child: Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: urgente ? Paleta.coral : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        urgente
                            ? Icons.alarm_rounded
                            : Icons.timer_rounded,
                        size: 18,
                        color: Paleta.tinta,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tiempo,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Paleta.tinta,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'Pregunta ${actual + 1} de $total',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$respondidas respondidas',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : respondidas / total,
                      minHeight: 8,
                      color: Paleta.miel,
                      backgroundColor: Paleta.verdeClaro,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Opcion extends StatelessWidget {
  final String letra;
  final String texto;
  final bool marcada;
  final bool multiple;
  final VoidCallback? onTap;
  const _Opcion({
    required this.letra,
    required this.texto,
    required this.marcada,
    required this.multiple,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: marcada ? Paleta.verdeSuave : Colors.white,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: marcada ? Paleta.verde : Paleta.borde,
        width: marcada ? 2 : 1.5,
      ),
    ),
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: marcada ? Paleta.verde : Paleta.crema,
                shape: multiple ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: multiple ? BorderRadius.circular(10) : null,
              ),
              child: marcada
                  ? const Icon(Icons.check_rounded, color: Colors.white)
                  : Text(
                      letra,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Paleta.tintaSuave,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                texto,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.3,
                  fontWeight: marcada ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Pie extends StatelessWidget {
  final int total;
  final int actual;
  final List<bool> respondida;
  final bool enviando;
  final bool esUltima;
  final ValueChanged<int> onIr;
  final VoidCallback onEnviar;
  const _Pie({
    required this.total,
    required this.actual,
    required this.respondida,
    required this.enviando,
    required this.esUltima,
    required this.onIr,
    required this.onEnviar,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Paleta.borde, width: 1.5)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: total,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final esActual = i == actual;
                  final hecha = respondida[i];
                  return InkWell(
                    onTap: enviando ? null : () => onIr(i),
                    borderRadius: BorderRadius.circular(21),
                    child: Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: esActual
                            ? Paleta.verde
                            : hecha
                            ? Paleta.verdeSuave
                            : Colors.white,
                        border: Border.all(
                          color: esActual || hecha
                              ? Paleta.verde
                              : Paleta.borde,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: esActual ? Colors.white : Paleta.tinta,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: enviando || actual == 0
                      ? null
                      : () => onIr(actual - 1),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Anterior'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: esUltima
                      ? FilledButton.icon(
                          onPressed: enviando ? null : onEnviar,
                          icon: enviando
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                          label: Text(enviando ? 'Enviando...' : 'Enviar examen'),
                        )
                      : FilledButton.icon(
                          onPressed: enviando ? null : () => onIr(actual + 1),
                          icon: const Icon(Icons.arrow_forward_rounded),
                          iconAlignment: IconAlignment.end,
                          label: const Text('Siguiente'),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Pantalla de error al iniciar (sin intentos, fuera de fecha, sin conexión...).
class _Aviso extends StatelessWidget {
  final String titulo;
  final String mensaje;
  const _Aviso({required this.titulo, required this.mensaje});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(titulo)),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const IconBadge(
              Icons.lock_clock_rounded,
              fondo: Paleta.coralSuave,
              tam: 72,
            ),
            const SizedBox(height: 16),
            Text(
              'No se pudo abrir el examen',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Paleta.tintaSuave),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(180, 50)),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Volver'),
            ),
          ],
        ),
      ),
    ),
  );
}
