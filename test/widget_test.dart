import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valat_rene/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('navigates between operations sections', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ValatReneApp(repository: OperationsRepository(screenshotMode: false)),
    );
    await tester.pumpAndSettle();

    expect(find.text('VALAT RENE'), findsOneWidget);
    expect(find.text('Work queues'), findsOneWidget);

    await tester.tap(find.text('Logistics').last);
    await tester.pumpAndSettle();

    expect(find.text('Containers'), findsWidgets);
    expect(find.text('Supplies'), findsWidgets);

    await tester.tap(find.text('Team').last);
    await tester.pumpAndSettle();

    expect(find.text('Team attendance'), findsOneWidget);
  });

  testWidgets('creates and persists a local task record', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ValatReneApp(repository: OperationsRepository(screenshotMode: false)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('create-record')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('record-title-field')),
      'Count outbound pallets',
    );
    final saveButton = find.byKey(const ValueKey('save-record-button'));
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tasks').last);
    await tester.pumpAndSettle();

    expect(find.text('Count outbound pallets'), findsOneWidget);
  });
}
