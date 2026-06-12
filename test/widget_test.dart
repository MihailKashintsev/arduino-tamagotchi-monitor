import 'package:arduino_tamagotchi_monitor/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows monitor shell', (tester) async {
    await tester.pumpWidget(const TamagotchiMonitorApp());

    expect(find.text('Arduino Pet Link'), findsWidgets);
    expect(find.text('Тамагочи'), findsOneWidget);
    expect(find.text('HM-10 устройства'), findsOneWidget);
  });
}
