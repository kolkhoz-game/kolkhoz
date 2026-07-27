import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/app/views/shared/chrome_button.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'package:kolkhoz_app/src/app/views/shared/pixel_text.dart';

void main() {
  testWidgets('chrome buttons expose one labeled button action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ChromeAssetButton(
            label: 'Create game',
            tokens: defaultDesignTokens,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            textSize: PixelTextSize.caption,
            uppercase: false,
            onPressed: () {},
          ),
        ),
      ),
    );

    final button = find.bySemanticsLabel('Create game');
    expect(button, findsOneWidget);
    final node = tester.getSemantics(button);
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isEnabled.toBoolOrNull(), isTrue);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    semantics.dispose();
  });

  testWidgets('disabled chrome buttons expose no tap action', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: ChromeAssetButton(
            label: 'Use favorite',
            tokens: defaultDesignTokens,
            backgroundColor: Colors.grey,
            textColor: Colors.black,
            textSize: PixelTextSize.caption,
            uppercase: false,
            enabled: false,
          ),
        ),
      ),
    );

    final node = tester.getSemantics(find.bySemanticsLabel('Use favorite'));
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isEnabled.toBoolOrNull(), isFalse);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    semantics.dispose();
  });
}
