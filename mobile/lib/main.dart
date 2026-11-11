import 'package:flutter/material.dart';

import 'screens/arranque_page.dart';
import 'theme/app_theme.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Exámenes',
    debugShowCheckedModeBanner: false,
    theme: construirTema(),
    home: const ArranquePage(),
  );
}
