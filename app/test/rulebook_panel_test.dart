import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/app/app.dart';
import 'package:kolkhoz_app/src/app/settings/settings.dart';
import 'package:kolkhoz_app/src/app/views/shared/chrome_button.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'package:kolkhoz_app/src/app/views/shared/printed_underlay.dart';
import 'package:kolkhoz_app/src/app/views/shared/rule_content.dart';

void main() {
  testWidgets('How to Play panel separates the visual guide and rulebook', (
    tester,
  ) async {
    var tutorialPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 844,
          height: 390,
          child: RulesView(
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
            onTutorialPressed: () => tutorialPressed = true,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('how-to-play-tab')), findsOneWidget);
    expect(find.byKey(const Key('rules-tab')), findsOneWidget);
    expect(find.text('One year at a glance'), findsOneWidget);
    expect(find.text('Set up the collective'), findsOneWidget);
    expect(find.text('Play one year'), findsOneWidget);
    expect(find.text(kolkhozBaseRulebookTitle), findsNothing);

    await tester.tap(find.byKey(const Key('rules-tab')));
    await tester.pumpAndSettle();

    expect(kolkhozBaseRulebook, hasLength(40));
    expect(find.text(kolkhozBaseRulebookTitle.toUpperCase()), findsOneWidget);
    expect(find.text(kolkhozBaseRulebookPlayerCount), findsOneWidget);
    expect(find.text('1. Game Setup (Игровой Набор):'), findsOneWidget);
    expect(find.text('2. Playing a Year (Ход Игры):'), findsOneWidget);
    expect(
      find.text('3. End of Game (Конец Игры и Итоговый Подсчет Очков):'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Sum the face values of the cards (J/Q/K/Joker are 11/12/13/0) '
        'remaining in their cellar and plot. This includes hidden cards and '
        'revealed cards. The player with the highest total wins. If there is '
        'a tie, the player with the most cards in their cellar and plot wins. '
        'If there is still a tie, then both players are sent to the north and '
        'the player with the next highest amount wins.',
      ),
      findsOneWidget,
    );

    final scrollable = find.descendant(
      of: find.byKey(const Key('how-to-play-rulebook-scroll')),
      matching: find.byType(Scrollable),
    );
    expect(
      tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
      greaterThan(0),
    );

    await tester.tap(find.bySemanticsLabel('TUTORIAL'));
    expect(tutorialPressed, isTrue);
  });

  testWidgets('rules panels derive their palette from active design tokens', (
    tester,
  ) async {
    for (final tokens in [defaultDesignTokens, lightDesignTokens]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: kolkhozTheme(tokens),
          home: SizedBox(
            width: 844,
            height: 390,
            child: RulesView(
              key: ValueKey(tokens.usesLightAppearance),
              tokens: tokens,
              language: KolkhozLanguage.en,
              onTutorialPressed: () {},
            ),
          ),
        ),
      );

      expect(
        tester
            .widget<PrintedPaperSurface>(find.byType(PrintedPaperSurface))
            .color,
        tokens.colors.panel,
      );
      expect(
        tester.widget<Text>(find.text('One year at a glance')).style?.color,
        tokens.colors.cream,
      );

      await tester.tap(find.byKey(const Key('rules-tab')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(find.text(kolkhozBaseRulebookPlayerCount))
            .style
            ?.color,
        tokens.usesLightAppearance
            ? tokens.colors.onAccent
            : tokens.colors.black,
      );
    }
  });

  testWidgets('saved tutorial exposes resume and restart actions', (
    tester,
  ) async {
    var resumed = false;
    var restarted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 844,
          height: 390,
          child: RulesView(
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
            hasTutorialProgress: true,
            onTutorialPressed: () => resumed = true,
            onRestartTutorialPressed: () => restarted = true,
          ),
        ),
      ),
    );

    Finder chromeLabel(String label) => find.byWidgetPredicate(
      (widget) => widget is ChromeScaledLabel && widget.text == label,
    );
    await tester.tap(chromeLabel('RESUME TUTORIAL'));
    await tester.tap(chromeLabel('RESTART TUTORIAL'));
    expect(resumed, isTrue);
    expect(restarted, isTrue);
  });
}
