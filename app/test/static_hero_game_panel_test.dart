import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/app/settings/animation_speed.dart';
import 'package:kolkhoz_app/src/app/settings/settings.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/game_ui_state.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_constants.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import 'package:kolkhoz_app/src/app/views/game/game_view.dart';
import 'package:kolkhoz_app/src/app/views/game/views/static_hero/static_hero_game_panel.dart';
import 'package:kolkhoz_app/src/app/views/shared/field_plan_typography.dart';

import 'support/layout_scenarios.dart';

void main() {
  testWidgets('production trick panel frames the current winner', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _loadFonts(tester);
    _clearImageCache();
    await _precacheHeroUnderlays(tester);

    final model = fieldPlanFourCardTrickModel();
    await _pumpBoard(tester, model, settle: false);

    final trickCard = find.byKey(const Key('static-hero-trick-card-wheat-12'));
    final trickCardBox = tester.renderObject<RenderBox>(trickCard);
    final visualCardWidth =
        (trickCardBox.localToGlobal(Offset(trickCardBox.size.width, 0)) -
                trickCardBox.localToGlobal(Offset.zero))
            .distance;
    expect(
      visualCardWidth / trickCardBox.size.width,
      closeTo(staticHeroTrickCardScale, 0.001),
    );

    final winningCards = tester
        .widgetList<GameCard>(find.byType(GameCard))
        .where((card) => card.winningTrick)
        .toList();
    expect(winningCards, hasLength(1));
    expect(winningCards.single.card.id, 'wheat-12');
    expect(
      find.descendant(
        of: find.byKey(const Key('static-hero-trick-card-wheat-12')),
        matching: find.byKey(const ValueKey('winning-trick-card-frame')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('player-portrait-1-inspect')),
        matching: find.byKey(const ValueKey('winning-trick-player-frame')),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('winning-trick-player-frame')),
      findsOneWidget,
    );
    for (final (seatID, cardID) in [
      (2, 'sunflower-8'),
      (3, 'potato-10'),
      (1, 'wheat-12'),
      (0, 'beet-6'),
    ]) {
      final profileCenter = tester
          .getCenter(find.byKey(Key('player-portrait-$seatID-inspect')))
          .dy;
      final cardCenter = tester
          .getCenter(find.byKey(Key('static-hero-trick-card-$cardID')))
          .dy;
      if (seatID == 2 || seatID == 3) {
        expect(profileCenter, greaterThan(cardCenter));
      } else {
        expect(profileCenter, lessThan(cardCenter));
      }
    }
    for (final seat in model.table.seats) {
      final cellarCount =
          seat.plot.effectiveHiddenCardCount +
          seat.plot.stacks.fold<int>(
            0,
            (total, stack) => total + stack.effectiveHiddenCardCount,
          );
      expect(
        find.byKey(Key('player-profile-portrait-${seat.id}')),
        findsOneWidget,
      );
      expect(
        find.byKey(Key('player-profile-medals-${seat.id}')),
        findsOneWidget,
      );
      for (var index = 0; index < model.table.maxTricks; index++) {
        expect(
          find.byKey(Key('player-profile-medal-${seat.id}-$index')),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(
          of: find.byKey(Key('player-profile-plot-${seat.id}')),
          matching: find.text('${seat.visibleScore}'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(Key('player-profile-cellar-${seat.id}')),
          matching: find.text('$cellarCount'),
        ),
        findsOneWidget,
      );
    }
    final topProfileYs = [
      for (final seatID in [2, 3])
        tester.getCenter(find.byKey(Key('player-portrait-$seatID-inspect'))).dy,
    ];
    final bottomProfileYs = [
      for (final seatID in [1, 0])
        tester.getCenter(find.byKey(Key('player-portrait-$seatID-inspect'))).dy,
    ];
    expect(topProfileYs.reduce(math.max) - topProfileYs.reduce(math.min), 0);
    expect(
      bottomProfileYs.reduce(math.max) - bottomProfileYs.reduce(math.min),
      0,
    );
    expect(bottomProfileYs.first, greaterThan(topProfileYs.first));

    for (final seatID in [2, 1]) {
      final profile = _visualRect(
        tester,
        find.byKey(Key('player-portrait-$seatID-inspect')),
      );
      final cardID = seatID == 2 ? 'sunflower-8' : 'wheat-12';
      final card = _trickCardVisualRect(tester, cardID);
      expect(profile.right, lessThanOrEqualTo(card.left));
    }
    for (final seatID in [3, 0]) {
      final profile = _visualRect(
        tester,
        find.byKey(Key('player-portrait-$seatID-inspect')),
      );
      final cardID = seatID == 3 ? 'potato-10' : 'beet-6';
      final card = _trickCardVisualRect(tester, cardID);
      expect(card.right, lessThanOrEqualTo(profile.left));
    }
    _expectTrickCardGaps(tester);
    _expectTrickCardsInsidePlayfield(tester);
    _expectTrickProfilesAnchoredToCards(tester);
    _expectPlotZonesAnchoredToProfiles(tester);
    _expectTrickLayoutVerticallyCentered(tester);
    _expectTrickProfileHorizontalGaps(tester);
    _expectLeftPlotFansBuildOutward(tester);
    await expectLater(
      find.byKey(const Key('production-board-capture')),
      matchesGoldenFile('static_hero_production/brigade.png'),
    );
  });

  testWidgets('large trick cards clear profiles at phone landscape size', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(640, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _loadFonts(tester);
    await _precacheHeroUnderlays(tester);

    await _pumpBoard(tester, fieldPlanFourCardTrickModel(), settle: false);

    for (final (seatID, cardID) in [(2, 'sunflower-8'), (1, 'wheat-12')]) {
      final profile = _visualRect(
        tester,
        find.byKey(Key('player-portrait-$seatID-inspect')),
      );
      final card = _trickCardVisualRect(tester, cardID);
      expect(profile.right, lessThanOrEqualTo(card.left));
    }
    for (final (seatID, cardID) in [(3, 'potato-10'), (0, 'beet-6')]) {
      final profile = _visualRect(
        tester,
        find.byKey(Key('player-portrait-$seatID-inspect')),
      );
      final card = _trickCardVisualRect(tester, cardID);
      expect(card.right, lessThanOrEqualTo(profile.left));
    }
    _expectTrickCardGaps(tester);
    _expectTrickCardsInsidePlayfield(tester);
    _expectTrickProfilesAnchoredToCards(tester);
    _expectPlotZonesAnchoredToProfiles(tester);
    _expectTrickLayoutVerticallyCentered(tester);
    _expectTrickProfileHorizontalGaps(tester);
    _expectLeftPlotFansBuildOutward(tester);
  });

  testWidgets('long player names leave room for every medal at phone size', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(640, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _loadFonts(tester);
    await _precacheHeroUnderlays(tester);

    final base = fieldPlanFourCardTrickModel();
    final model = _withViewer(
      base,
      base.viewer.seatID ?? 0,
      namesBySeat: const {0: 'Player 1', 1: 'Ivan', 2: 'Dmitri', 3: 'Alyosha'},
      medalsBySeat: {
        for (final seat in base.table.seats) seat.id: base.table.maxTricks,
      },
    );
    await _pumpBoard(
      tester,
      model,
      settle: false,
      textScaler: const TextScaler.linear(1.2),
    );

    for (final seat in model.table.seats) {
      final profile = _visualRect(
        tester,
        find.byKey(Key('player-portrait-${seat.id}-inspect')),
      );
      for (var index = 0; index < model.table.maxTricks; index++) {
        final medal = _visualRect(
          tester,
          find.byKey(Key('player-profile-medal-${seat.id}-$index')),
        );
        expect(medal.left, greaterThanOrEqualTo(profile.left));
        expect(medal.right, lessThanOrEqualTo(profile.right));
      }
    }
  });

  testWidgets('selected plot and cellar cards use the green swap frame', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(640, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _loadFonts(tester);
    await _precacheHeroUnderlays(tester);

    final base = fieldPlanFourCardTrickModel();
    for (final (cardID, zone) in [
      ('beet-10', plotZoneRevealed),
      ('potato-6', plotZoneHidden),
    ]) {
      final model = _withViewer(
        base,
        base.viewer.seatID ?? 0,
        selection: SelectionState(
          handCardID: 'wheat-11',
          plotCardID: cardID,
          plotZone: zone,
          assignmentCardID: null,
        ),
      );
      await _pumpBoard(tester, model, settle: false);

      final frame = tester.widget<Container>(
        find.byKey(ValueKey('swap-selected-plot-card-$cardID')),
      );
      final decoration = frame.foregroundDecoration! as BoxDecoration;
      expect(
        decoration.border!.top.color,
        KolkhozAppearance.light.tokens.colors.green,
      );
    }
  });

  testWidgets('online opponent cellar counts render as card backs', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(640, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _loadFonts(tester);
    await _precacheHeroUnderlays(tester);

    final model = _withViewer(
      fieldPlanFourCardTrickModel(),
      0,
      plotsBySeat: const {
        1: PlotState(
          revealed: [],
          hidden: [],
          hiddenCardCount: 3,
          stacks: [
            PlotStackState(revealed: [], hidden: [], hiddenCardCount: 2),
          ],
        ),
      },
    );
    await _pumpBoard(tester, model, settle: false);

    final opponentPlot = find.byKey(const Key('static-hero-plot-zone-1'));
    for (var index = 0; index < 5; index++) {
      final cardBack = find.descendant(
        of: opponentPlot,
        matching: find.byKey(ValueKey('poster-fan-paint-seat-1-cellar-$index')),
      );
      expect(cardBack, findsOneWidget);
      expect(
        find.descendant(of: cardBack, matching: find.byType(ScaledCardBack)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: cardBack, matching: find.byType(MotionTrackedCard)),
        findsNothing,
      );
    }
  });

  testWidgets('poster fans accept duplicate card faces', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _loadFonts(tester);
    await _precacheHeroUnderlays(tester);

    final base = _scenario('assignment_jobs').model;
    final wheat = base.table.jobs.firstWhere((job) => job.suit == 'wheat');
    final duplicate = wheat.assignedCards.first;
    final model = _withViewer(
      base,
      base.viewer.seatID ?? 0,
      jobs: [
        Job(
          suit: wheat.suit,
          hours: wheat.hours,
          requiredHours: wheat.requiredHours,
          claimed: wheat.claimed,
          reward: wheat.reward,
          assignedCards: [duplicate, duplicate],
          validAssignmentTarget: wheat.validAssignmentTarget,
          highlighted: wheat.highlighted,
        ),
        ...base.table.jobs.where((job) => job.suit != 'wheat'),
      ],
    );

    await _pumpBoard(tester, model, settle: false);

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(ValueKey('poster-fan-layer-${duplicate.id}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('poster-fan-layer-${duplicate.id}-1')),
      findsOneWidget,
    );
  });

  testWidgets('field jobs fill the illustrated plots on desktop', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _loadFonts(tester);
    _clearImageCache();
    await _precacheHeroUnderlays(tester);

    await _pumpBoard(tester, _scenario('assignment_jobs').model);
    _expectFieldGeometry(tester);
    await expectLater(
      find.byKey(const Key('production-board-capture')),
      matchesGoldenFile('static_hero_production/fields.png'),
    );
  });

  testWidgets('field jobs remain aligned at phone landscape size', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(640, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _loadFonts(tester);
    await _precacheHeroUnderlays(tester);

    await _pumpBoard(tester, _scenario('assignment_jobs').model);
    _expectFieldGeometry(tester);
  });

  testWidgets('field-art medals pulse when a player is one trick from Hero', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _loadFonts(tester);

    final base = fieldPlanFourCardTrickModel();
    final model = _withViewer(
      base,
      base.viewer.seatID ?? 0,
      medalsBySeat: {2: base.table.maxTricks - 1},
    );
    await _pumpBoard(tester, model, settle: false);

    expect(find.byKey(const ValueKey('hero-medal-warning')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('player-profile-medals-2')),
        matching: find.byType(AnimatedSwitcher),
      ),
      findsNWidgets(model.table.maxTricks),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 1200,
          height: 760,
          child: StaticHeroGamePanel(
            kind: StaticHeroGamePanelKind.brigade,
            model: model,
            tokens: KolkhozAppearance.light.tokens,
            language: KolkhozLanguage.en,
            heroOfSovietUnion: false,
            showPlanningPanel: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('hero-medal-warning')), findsNothing);
  });

  testWidgets('production board renders all three static hero panels', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _loadFonts(tester);
    await _precacheHeroUnderlays(tester);

    await _pumpBoard(tester, _scenario('trick_brigade').model, settle: false);
    expect(
      find.byKey(const Key('production-static-hero-brigade')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('static-hero-trick-card-sunflower-12')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('static-hero-trick-card-sunflower-12')),
        matching: find.byType(MotionTrackedCard),
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is MotionTrackedRegion &&
            widget.motionKey == playerCardMotionSourceKey(2),
      ),
      findsOneWidget,
    );
    final bot1TrickCard = tester.getCenter(
      find.byKey(const Key('static-hero-trick-card-sunflower-12')),
    );
    final bot2TrickCard = tester.getCenter(
      find.byKey(const Key('static-hero-trick-card-sunflower-8')),
    );
    expect((bot1TrickCard.dx - bot2TrickCard.dx).abs(), lessThan(2));
    expect(bot2TrickCard.dy, lessThan(bot1TrickCard.dy));
    LegalAction? selectedAction;
    await _pumpBoard(
      tester,
      _scenario('assignment_jobs').model,
      onAction: (action) => selectedAction = action,
      settle: false,
    );
    expect(
      find.byKey(const Key('production-static-hero-fields')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('static-hero-job-wheat')));
    expect(selectedAction?.kind, actionAssign);
    expect(selectedAction?.engineAction.targetSuit, 'wheat');
    await _pumpBoard(
      tester,
      _scenario('sent_north_history').model,
      settle: false,
    );
    expect(
      find.byKey(const Key('production-static-hero-north')),
      findsOneWidget,
    );
    for (var year = 1; year <= finalGameYear; year++) {
      expect(find.byKey(Key('static-hero-north-year-$year')), findsOneWidget);
    }
  });

  testWidgets('brigade seats and trick cards rotate around the viewer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _loadFonts(tester);

    await _pumpBoard(
      tester,
      _withViewer(_scenario('trick_brigade').model, 2),
      settle: false,
    );
    final viewerPortrait = tester.getCenter(
      find.byKey(const Key('player-portrait-2-inspect')),
    );
    final lowerLeftPortrait = tester.getCenter(
      find.byKey(const Key('player-portrait-3-inspect')),
    );
    final upperRightPortrait = tester.getCenter(
      find.byKey(const Key('player-portrait-1-inspect')),
    );
    expect(viewerPortrait.dx, greaterThan(lowerLeftPortrait.dx));
    expect(viewerPortrait.dy, greaterThan(upperRightPortrait.dy));

    final upperRightTrickCard = tester.getCenter(
      find.byKey(const Key('static-hero-trick-card-sunflower-12')),
    );
    final viewerTrickCard = tester.getCenter(
      find.byKey(const Key('static-hero-trick-card-sunflower-8')),
    );
    expect((upperRightTrickCard.dx - viewerTrickCard.dx).abs(), lessThan(2));
    expect(viewerTrickCard.dy, greaterThan(upperRightTrickCard.dy));
  });
}

LayoutScenario _scenario(String name) =>
    layoutScenarios.firstWhere((scenario) => scenario.name == name);

TableViewModel _withViewer(
  TableViewModel model,
  int viewerSeatID, {
  Map<int, int> medalsBySeat = const {},
  Map<int, String> namesBySeat = const {},
  Map<int, PlotState> plotsBySeat = const {},
  List<Job>? jobs,
  SelectionState? selection,
}) {
  return TableViewModel(
    viewer: Viewer(seatID: viewerSeatID, privacyMode: model.viewer.privacyMode),
    table: TableState(
      year: model.table.year,
      phase: model.table.phase,
      phasePrompt: model.table.phasePrompt,
      currentPlayerID: model.table.currentPlayerID,
      trump: model.table.trump,
      isFamine: model.table.isFamine,
      maxTricks: model.table.maxTricks,
      seats: [
        for (final seat in model.table.seats)
          Seat(
            id: seat.id,
            name: namesBySeat[seat.id] ?? seat.name,
            controller: seat.controller,
            portraitAsset: seat.portraitAsset,
            isViewer: seat.id == viewerSeatID,
            isCurrentTurn: seat.isCurrentTurn,
            isBrigadeLeader: seat.isBrigadeLeader,
            hand: seat.hand,
            hiddenHandCount: seat.hiddenHandCount,
            plot: plotsBySeat[seat.id] ?? seat.plot,
            medals: medalsBySeat[seat.id] ?? seat.medals,
            bankedMedals: seat.bankedMedals,
            visibleScore: seat.visibleScore,
            profileStats: seat.profileStats,
            profileUserID: seat.profileUserID,
            statusText: seat.statusText,
          ),
      ],
      jobs: jobs ?? model.table.jobs,
      trick: model.table.trick,
      lastTrick: model.table.lastTrick,
      requisitionEvents: model.table.requisitionEvents,
      exiledByYear: model.table.exiledByYear,
      scoreboard: model.table.scoreboard,
      gameResult: model.table.gameResult,
      finalYearTrumpCard: model.table.finalYearTrumpCard,
    ),
    panels: model.panels,
    selection: selection ?? model.selection,
    legalActions: model.legalActions,
    seed: model.seed,
  );
}

Future<void> _pumpBoard(
  WidgetTester tester,
  TableViewModel model, {
  ValueChanged<LegalAction>? onAction,
  bool settle = true,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: fieldPlanDisplayFontFamily),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: RepaintBoundary(
            key: const Key('production-board-capture'),
            child: KolkhozBoard(
              model: model,
              tokens: KolkhozAppearance.light.tokens,
              language: KolkhozLanguage.en,
              appearance: KolkhozAppearance.light,
              animationSpeed: GameAnimationSpeed.instant,
              onAction: onAction,
            ),
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}

Future<void> _loadFonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    final display = FontLoader(fieldPlanDisplayFontFamily)
      ..addFont(
        rootBundle.load(
          'assets/art/field_plan/shared/fonts/PTSansNarrow-Bold.ttf',
        ),
      );
    final body = FontLoader(fieldPlanBodyFontFamily)
      ..addFont(
        rootBundle.load('assets/art/field_plan/shared/fonts/PTSans-Bold.ttf'),
      );
    await Future.wait([display.load(), body.load()]);
  });
}

Future<void> _precacheHeroUnderlays(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: SizedBox()));
  final imageContext = tester.element(find.byType(SizedBox));
  await tester.runAsync(
    () => Future.wait([
      for (final panel in ['brigade', 'fields', 'north'])
        precacheImage(
          AssetImage(
            'assets/art/field_plan/game/backgrounds/'
            'static-hero-$panel-underlay-v1.png',
          ),
          imageContext,
        ),
    ]),
  );
}

void _clearImageCache() {
  PaintingBinding.instance.imageCache
    ..clear()
    ..clearLiveImages();
}

Rect _visualRect(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  final corners = [
    box.localToGlobal(Offset.zero),
    box.localToGlobal(Offset(box.size.width, 0)),
    box.localToGlobal(Offset(0, box.size.height)),
    box.localToGlobal(box.size.bottomRight(Offset.zero)),
  ];
  final left = corners.map((point) => point.dx).reduce(math.min);
  final top = corners.map((point) => point.dy).reduce(math.min);
  final right = corners.map((point) => point.dx).reduce(math.max);
  final bottom = corners.map((point) => point.dy).reduce(math.max);
  return Rect.fromLTRB(left, top, right, bottom);
}

Rect _trickCardVisualRect(WidgetTester tester, String cardID) {
  return _visualRect(
    tester,
    find.descendant(
      of: find.byKey(Key('static-hero-trick-card-$cardID')),
      matching: find.byType(GameCard),
    ),
  );
}

void _expectTrickCardGaps(WidgetTester tester) {
  const minimumGap = 2.0;
  final topLeft = _trickCardVisualRect(tester, 'sunflower-8');
  final topRight = _trickCardVisualRect(tester, 'potato-10');
  final bottomLeft = _trickCardVisualRect(tester, 'wheat-12');
  final bottomRight = _trickCardVisualRect(tester, 'beet-6');

  expect(topLeft.right + minimumGap, lessThanOrEqualTo(topRight.left));
  expect(bottomLeft.right + minimumGap, lessThanOrEqualTo(bottomRight.left));
  expect(topLeft.bottom + minimumGap, lessThanOrEqualTo(bottomLeft.top));
  expect(topRight.bottom + minimumGap, lessThanOrEqualTo(bottomRight.top));
}

void _expectTrickCardsInsidePlayfield(WidgetTester tester) {
  final playfield = _visualRect(
    tester,
    find.byKey(const Key('production-static-hero-brigade')),
  );
  for (final cardID in ['sunflower-8', 'potato-10', 'wheat-12', 'beet-6']) {
    final card = _trickCardVisualRect(tester, cardID);
    expect(card.top, greaterThanOrEqualTo(playfield.top));
    expect(card.bottom, lessThanOrEqualTo(playfield.bottom));
  }
}

void _expectTrickProfilesAnchoredToCards(WidgetTester tester) {
  for (final (seatID, cardID) in [(2, 'sunflower-8'), (3, 'potato-10')]) {
    final profile = _visualRect(
      tester,
      find.byKey(Key('player-portrait-$seatID-inspect')),
    );
    final card = _trickCardVisualRect(tester, cardID);
    expect(profile.bottom, closeTo(card.bottom, 0.01));
  }
  for (final (seatID, cardID) in [(1, 'wheat-12'), (0, 'beet-6')]) {
    final profile = _visualRect(
      tester,
      find.byKey(Key('player-portrait-$seatID-inspect')),
    );
    final card = _trickCardVisualRect(tester, cardID);
    expect(profile.top, closeTo(card.top, 0.01));
  }
}

void _expectPlotZonesAnchoredToProfiles(WidgetTester tester) {
  const gap = 2.0;
  final playfield = _visualRect(
    tester,
    find.byKey(const Key('production-static-hero-brigade')),
  );
  final plotPadding = 4 * (playfield.height / 410).clamp(0.45, 1);
  for (final (seatID, cardID) in [
    (2, 'sunflower-8'),
    (3, 'potato-10'),
    (1, 'wheat-12'),
    (0, 'beet-6'),
  ]) {
    final profile = _visualRect(
      tester,
      find.byKey(Key('player-portrait-$seatID-inspect')),
    );
    final plotZone = _visualRect(
      tester,
      find.byKey(Key('static-hero-plot-zone-$seatID')),
    );
    final card = _trickCardVisualRect(tester, cardID);
    final isLeftColumn = seatID == 2 || seatID == 1;
    final isTopRow = seatID == 2 || seatID == 3;

    expect(
      isLeftColumn ? plotZone.right : plotZone.left,
      closeTo(isLeftColumn ? profile.right : profile.left, 0.01),
    );
    expect(
      isTopRow ? plotZone.bottom + gap : plotZone.top - gap,
      closeTo(isTopRow ? profile.top : profile.bottom, 0.01),
    );
    expect(
      isTopRow ? plotZone.top + plotPadding : plotZone.bottom - plotPadding,
      isTopRow
          ? lessThanOrEqualTo(card.top)
          : greaterThanOrEqualTo(card.bottom),
    );
    final profileGap = isTopRow
        ? profile.top - (plotZone.bottom - plotPadding)
        : plotZone.top + plotPadding - profile.bottom;
    final playfieldGap = isTopRow
        ? plotZone.top + plotPadding - playfield.top
        : playfield.bottom - (plotZone.bottom - plotPadding);
    expect(playfieldGap, closeTo(profileGap, 0.01));
  }
}

void _expectTrickLayoutVerticallyCentered(WidgetTester tester) {
  final playfield = _visualRect(
    tester,
    find.byKey(const Key('production-static-hero-brigade')),
  );
  final top = math.min(
    _trickCardVisualRect(tester, 'sunflower-8').top,
    _trickCardVisualRect(tester, 'potato-10').top,
  );
  final bottom = math.max(
    _trickCardVisualRect(tester, 'wheat-12').bottom,
    _trickCardVisualRect(tester, 'beet-6').bottom,
  );
  expect((top + bottom) / 2, closeTo(playfield.center.dy, 0.01));
}

void _expectTrickProfileHorizontalGaps(WidgetTester tester) {
  final playfield = _visualRect(
    tester,
    find.byKey(const Key('production-static-hero-brigade')),
  );
  final minimumGap = 8 * (playfield.height / 410).clamp(0.45, 1);
  for (final (seatID, cardID) in [(2, 'sunflower-8'), (1, 'wheat-12')]) {
    final profile = _visualRect(
      tester,
      find.byKey(Key('player-portrait-$seatID-inspect')),
    );
    final card = _trickCardVisualRect(tester, cardID);
    expect(card.left - profile.right, greaterThanOrEqualTo(minimumGap));
  }
  for (final (seatID, cardID) in [(3, 'potato-10'), (0, 'beet-6')]) {
    final profile = _visualRect(
      tester,
      find.byKey(Key('player-portrait-$seatID-inspect')),
    );
    final card = _trickCardVisualRect(tester, cardID);
    expect(profile.left - card.right, greaterThanOrEqualTo(minimumGap));
  }
}

void _expectLeftPlotFansBuildOutward(WidgetTester tester) {
  for (final seatID in [2, 1]) {
    final fanCards = find
        .descendant(
          of: find.byKey(Key('static-hero-plot-zone-$seatID')),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget.key is ValueKey<String> &&
                (widget.key! as ValueKey<String>).value.startsWith(
                  'poster-fan-paint-',
                ),
          ),
        )
        .evaluate()
        .toList();
    expect(fanCards.length, greaterThanOrEqualTo(2));
    final bottomCard = find.byKey(fanCards.first.widget.key!);
    final topCard = find.byKey(fanCards.last.widget.key!);
    expect(
      tester.getCenter(bottomCard).dx,
      greaterThan(tester.getCenter(topCard).dx),
    );
  }
}

void _expectFieldGeometry(WidgetTester tester) {
  final panel = tester.getRect(
    find.byKey(const Key('production-static-hero-fields')),
  );
  final jobs = {
    for (final suit in ['wheat', 'beet', 'sunflower', 'potato'])
      suit: tester.getRect(find.byKey(Key('static-hero-job-$suit'))),
  };
  final wheat = jobs['wheat']!;
  final beet = jobs['beet']!;
  final sunflower = jobs['sunflower']!;
  final potato = jobs['potato']!;

  for (final rect in jobs.values) {
    expect(panel.contains(rect.topLeft), isTrue);
    expect(panel.contains(rect.bottomRight), isTrue);
  }
  expect(wheat.overlaps(beet), isFalse);
  expect(wheat.overlaps(sunflower), isFalse);
  expect(beet.overlaps(potato), isFalse);
  expect(sunflower.overlaps(potato), isFalse);
  expect(wheat.left, closeTo(sunflower.left, 0.01));
  expect(wheat.right, closeTo(sunflower.right, 0.01));
  expect(beet.left, closeTo(potato.left, 0.01));
  expect(beet.right, closeTo(potato.right, 0.01));
  expect(wheat.top, closeTo(beet.top, 0.01));
  expect(wheat.bottom, closeTo(beet.bottom, 0.01));
  expect(sunflower.top, closeTo(potato.top, 0.01));
  expect(sunflower.bottom, closeTo(potato.bottom, 0.01));
  expect(wheat.width, greaterThan(panel.width * 0.45));
  expect(wheat.height, greaterThan(panel.height * 0.30));
  expect(sunflower.height, greaterThan(panel.height * 0.40));

  for (final entry in jobs.entries) {
    final normalized = staticHeroJobRects[entry.key]!;
    final job = entry.value;
    expect(job.left, closeTo(panel.left + panel.width * normalized.left, 0.01));
    expect(job.top, closeTo(panel.top + panel.height * normalized.top, 0.01));
    expect(job.width, closeTo(panel.width * normalized.width, 0.01));
    expect(job.height, closeTo(panel.height * normalized.height, 0.01));
  }

  final counters = {
    for (final suit in jobs.keys)
      suit: tester.getRect(find.byKey(Key('static-hero-job-counter-$suit'))),
  };
  final rewards = {
    for (final suit in jobs.keys)
      suit: tester.getRect(find.byKey(Key('static-hero-job-reward-$suit'))),
  };
  final assignments = {
    for (final suit in jobs.keys)
      suit: tester.getRect(find.byKey(Key('static-hero-job-assignment-$suit'))),
  };
  final markers = {
    for (final suit in jobs.keys)
      suit: tester.getRect(find.byKey(Key('static-hero-job-marker-$suit'))),
  };
  for (final suit in jobs.keys) {
    final job = jobs[suit]!;
    final counter = counters[suit]!;
    final reward = rewards[suit]!;
    final assignment = assignments[suit]!;
    final marker = markers[suit]!;
    expect(panel.contains(counter.topLeft), isTrue);
    expect(panel.contains(counter.bottomRight), isTrue);
    expect(
      panel.contains(reward.topLeft),
      isTrue,
      reason: '$suit reward $reward must start inside $panel',
    );
    expect(
      panel.contains(reward.bottomRight),
      isTrue,
      reason: '$suit reward $reward must end inside $panel',
    );
    final expectedScale = (panel.height / 410).clamp(0.45, 1).toDouble() * 1.5;
    expect(reward.width, closeTo(64 * expectedScale, 0.01));
    expect(reward.center.dx, closeTo(counter.center.dx, 0.01));
    expect(assignment.left, greaterThanOrEqualTo(job.left - 0.01));
    expect(assignment.right, lessThanOrEqualTo(job.right + 0.01));
    expect(assignment.top, greaterThanOrEqualTo(job.top));
    expect(assignment.bottom, lessThanOrEqualTo(job.bottom));
    expect(assignment.overlaps(marker), isFalse);
    expect(assignment.top, closeTo(job.top, 0.01));
    expect(assignment.bottom, closeTo(job.bottom, 0.01));
    expect(assignment.width, greaterThan(job.width * 0.65));

    final isLeftColumn = suit == 'wheat' || suit == 'sunflower';
    final isTopRow = suit == 'wheat' || suit == 'beet';
    expect(job.contains(counter.topLeft), isTrue);
    expect(job.contains(counter.bottomRight), isTrue);
    expect(
      counter.center.dx,
      isLeftColumn ? greaterThan(job.center.dx) : lessThan(job.center.dx),
    );
    expect(
      isLeftColumn ? assignment.left : assignment.right,
      closeTo(isLeftColumn ? job.left : job.right, 0.01),
    );
    expect(
      counter.center.dy,
      isTopRow ? greaterThan(job.center.dy) : lessThan(job.center.dy),
    );
    expect(
      isTopRow ? reward.bottom : counter.bottom,
      lessThan(isTopRow ? counter.top : reward.top),
    );

    final counterText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(Key('static-hero-job-counter-$suit')),
        matching: find.byType(Text),
      ),
    );
    expect(counterText.style!.fontSize, closeTo(10 * expectedScale, 0.01));
    expect(counter.width, closeTo(64 * expectedScale, 0.01));
    expect(counter.height, closeTo(18 * expectedScale, 0.01));
    expect(
      find.descendant(
        of: find.byKey(Key('static-hero-job-counter-$suit')),
        matching: find.byType(FittedBox),
      ),
      findsOneWidget,
    );
  }
  final counterWidth = counters.values.first.width;
  final counterHeight = counters.values.first.height;
  final rewardWidth = rewards.values.first.width;
  for (final counter in counters.values) {
    expect(counter.width, closeTo(counterWidth, 0.01));
    expect(counter.height, closeTo(counterHeight, 0.01));
  }
  for (final reward in rewards.values) {
    expect(reward.width, closeTo(rewardWidth, 0.01));
  }
  expect(counters['wheat']!.right, lessThan(counters['beet']!.left));
  expect(counters['sunflower']!.right, lessThan(counters['potato']!.left));
  expect(counters['wheat']!.bottom, lessThan(counters['sunflower']!.top));
  expect(counters['beet']!.bottom, lessThan(counters['potato']!.top));

  for (final entry in jobs.entries) {
    final motionTarget = tester.getRect(
      find.byWidgetPredicate(
        (widget) =>
            widget is MotionTrackedRegion &&
            widget.motionKey == jobFieldMotionTargetKey(entry.key),
      ),
    );
    expect(
      (motionTarget.center - entry.value.center).distance,
      lessThanOrEqualTo(panel.shortestSide * 0.015),
    );
    expect(motionTarget.width, closeTo(entry.value.width, panel.width * 0.01));
    expect(
      motionTarget.height,
      closeTo(entry.value.height, panel.height * 0.02),
    );
  }
}
