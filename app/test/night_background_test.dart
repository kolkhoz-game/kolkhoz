import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/app/settings/settings.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/engine_values.dart';
import 'package:kolkhoz_app/src/app/views/game/views/static_hero/static_hero_game_panel.dart';
import 'package:kolkhoz_app/src/app/views/main_menu/main_menu_view.dart';
import 'package:kolkhoz_app/src/app/views/shared/field_plan_assets.dart';
import 'package:kolkhoz_app/src/app/views/shared/printed_underlay.dart';

import 'support/layout_scenarios.dart';

void main() {
  test('menu appearance selects registered day and night plates', () {
    expect(
      fieldPlanMenuBackgroundPathFor(dark: false),
      fieldPlanMenuBackgroundPath,
    );
    expect(
      fieldPlanMenuBackgroundPathFor(dark: true),
      fieldPlanMenuDarkBackgroundPath,
    );
  });

  test(
    'static hero appearance selects every registered day and night plate',
    () {
      for (final (region, light, dark) in [
        (
          'brigade',
          fieldPlanStaticHeroBrigadeBackgroundPath,
          fieldPlanStaticHeroBrigadeDarkBackgroundPath,
        ),
        (
          'fields',
          fieldPlanStaticHeroFieldsBackgroundPath,
          fieldPlanStaticHeroFieldsDarkBackgroundPath,
        ),
        (
          'north',
          fieldPlanStaticHeroNorthBackgroundPath,
          fieldPlanStaticHeroNorthDarkBackgroundPath,
        ),
      ]) {
        expect(
          fieldPlanStaticHeroBackgroundPathFor(region: region, dark: false),
          light,
        );
        expect(
          fieldPlanStaticHeroBackgroundPathFor(region: region, dark: true),
          dark,
        );
        expect(File(light).existsSync(), isTrue);
        expect(File(dark).existsSync(), isTrue);
      }
    },
  );

  testWidgets('dark lobby renders the night menu plate', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StandaloneLobby(
          tokens: KolkhozAppearance.dark.tokens,
          language: KolkhozLanguage.en,
          appearance: KolkhozAppearance.dark,
          onStart: () {},
          selectedPreset: KolkhozGamePreset.kolkhoz,
          customVariants: KolkhozGameVariants.kolkhoz,
          playerControllers: KolkhozPlayerController.defaultControllers,
          demoMode: true,
          showingRules: false,
          showingOnline: false,
          onHostOnline: (_, _, _, _, _) async => 'session',
          onJoinOnline: (_, _, _) async {},
          onEnterOnlineGame: () {},
          onPresetChanged: (_) {},
          onCustomVariantsChanged: (_) {},
          onPlayerControllersChanged: (_) {},
          onRulesPressed: () {},
          onOfflinePressed: () {},
          onOnlinePressed: () {},
          onTutorialPressed: () {},
          onLanguageToggle: () {},
          onAppearanceToggle: () {},
        ),
      ),
    );

    final image = tester.widget<Image>(
      find.byKey(const Key('field-plan-menu-background')),
    );
    expect(
      (image.image as AssetImage).assetName,
      fieldPlanMenuDarkBackgroundPath,
    );
    final surface = find.byType(PrintedPaperSurface);
    expect(surface, findsOneWidget);
    expect(
      find
          .descendant(of: surface, matching: find.byType(ColoredBox))
          .evaluate()
          .map((element) => element.widget)
          .whereType<ColoredBox>()
          .any(
            (box) => box.color == KolkhozAppearance.dark.tokens.colors.panel,
          ),
      isTrue,
    );
    final demoModeText = tester.widget<Text>(find.text('DEMO MODE'));
    expect(
      demoModeText.style?.color,
      KolkhozAppearance.dark.tokens.colors.cream,
    );
  });

  testWidgets('dark gameplay panels render their night plates', (tester) async {
    final model = fieldPlanFourCardTrickModel();
    for (final (kind, path) in [
      (
        StaticHeroGamePanelKind.brigade,
        fieldPlanStaticHeroBrigadeDarkBackgroundPath,
      ),
      (
        StaticHeroGamePanelKind.fields,
        fieldPlanStaticHeroFieldsDarkBackgroundPath,
      ),
      (
        StaticHeroGamePanelKind.north,
        fieldPlanStaticHeroNorthDarkBackgroundPath,
      ),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: StaticHeroGamePanel(
            kind: kind,
            model: model,
            tokens: KolkhozAppearance.dark.tokens,
            language: KolkhozLanguage.en,
            showPlanningPanel: false,
          ),
        ),
      );

      final image = tester.widget<Image>(
        find.byKey(Key('static-hero-${kind.name}-background')),
      );
      expect((image.image as AssetImage).assetName, path);
    }
  });
}
