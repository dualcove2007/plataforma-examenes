import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('La app abre en la pantalla de inicio de sesión', (tester) async {
    await tester.pumpWidget(const App());

    expect(find.text('Plataforma de Exámenes'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Correo electrónico'), findsOneWidget);
  });
}
