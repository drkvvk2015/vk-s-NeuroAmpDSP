import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:neuroamp_app/bootstrap.dart';

void main() {
  testWidgets('NeuroAmp home page smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: NeuroAmpApp()));

    expect(find.text('NeuroAmp DSP Console'), findsOneWidget);
    expect(find.byType(ProviderScope), findsOneWidget);
  });
}
