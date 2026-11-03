import 'package:flutter/material.dart';

class ResultadoPage extends StatelessWidget {
  final Map<String, dynamic> resultado;
  const ResultadoPage({super.key, required this.resultado});

  @override
  Widget build(BuildContext context) {
    final nota = resultado['nota_final'];
    final puntaje = resultado['puntaje_total'];
    final maximo = resultado['puntaje_maximo'];
    final tema = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Resultado')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${resultado['examen_titulo']}',
                style: tema.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (nota == null)
                const Text(
                  'Tu examen fue enviado. La nota se mostrará cuando el docente termine la revisión.',
                  textAlign: TextAlign.center,
                )
              else ...[
                Text('$nota', style: tema.displayMedium),
                Text('$puntaje / $maximo puntos'),
              ],
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Volver'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}