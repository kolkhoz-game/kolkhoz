part of '../widget_test.dart';

void registerTutorialAndLayoutTests() {
  late TutorialContent tutorialContent;

  setUpAll(() async {
    tutorialContent = await loadBaseTutorialContent();
  });

  testWidgets('tutorial walkthrough advances, backs up, and closes', (
    tester,
  ) async {
    var closed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 844,
          height: 390,
          child: TutorialWalkthroughOverlay(
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
            content: tutorialContent,
            onClose: () => closed = true,
          ),
        ),
      ),
    );

    expect(findAppText('WELCOME TO THE COLLECTIVE'), findsOneWidget);
    expect(find.byKey(const ValueKey('tutorial-dot-0')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tutorial-next')));
    await tester.pump();
    expect(findAppText('YOUR HAND'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tutorial-back')));
    await tester.pump();
    expect(findAppText('WELCOME TO THE COLLECTIVE'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tutorial-close')));
    expect(closed, isTrue);
  });

  testWidgets('tutorial auto-advances when the live game satisfies a step', (
    tester,
  ) async {
    Widget wrap(TableViewModel model) => MaterialApp(
      home: SizedBox(
        width: 844,
        height: 390,
        child: TutorialWalkthroughOverlay(
          tokens: defaultDesignTokens,
          language: KolkhozLanguage.en,
          content: tutorialContent,
          onClose: () {},
          model: model,
        ),
      ),
    );

    // Base model: trump chosen, trick phase, no cards played yet.
    await tester.pumpWidget(wrap(runtimeModel()));

    // Resuming in the trick phase opens the relevant live lesson.
    expect(findAppText('PLAY A CARD'), findsOneWidget);

    // A card lands on the table: the step should advance on its own.
    await tester.pumpWidget(wrap(runtimeModelWithTrickPlay()));
    await tester.pump();
    expect(findAppText('TAKING THE TRICK'), findsOneWidget);

    // Let the celebration flash timer finish so no timers are pending.
    await tester.pump(const Duration(milliseconds: 1700));
  });

  testWidgets('Misha opens the basic assignment lesson on the third trick', (
    tester,
  ) async {
    Widget wrap(TableViewModel model) => MaterialApp(
      home: SizedBox(
        width: 844,
        height: 390,
        child: TutorialWalkthroughOverlay(
          tokens: defaultDesignTokens,
          language: KolkhozLanguage.en,
          content: tutorialContent,
          onClose: () {},
          model: model,
        ),
      ),
    );

    await tester.pumpWidget(wrap(runtimeModel()));
    await tester.pumpWidget(wrap(runtimeModelWithTrickPlay()));
    await tester.pump();
    expect(findAppText('TAKING THE TRICK'), findsOneWidget);

    final base = runtimeModel();
    final firstJob = base.table.jobs.first;
    final jobs = [
      Job(
        suit: firstJob.suit,
        hours: firstJob.hours,
        requiredHours: firstJob.requiredHours,
        claimed: firstJob.claimed,
        reward: firstJob.reward,
        assignedCards: [
          testCard(
            id: 'wheat-10',
            suit: 'wheat',
            value: 10,
            assignmentRound: 2,
          ),
        ],
        validAssignmentTarget: firstJob.validAssignmentTarget,
        highlighted: firstJob.highlighted,
      ),
      ...base.table.jobs.skip(1),
    ];
    final thirdTrickAssignment = runtimeModelWith(
      year: 1,
      phase: phaseAssignment,
      selection: SelectionState.empty,
      jobs: jobs,
      lastTrick: Trick(
        winnerSeatID: base.viewer.seatID,
        plays: [
          TrickPlay(
            seatID: base.viewer.seatID!,
            card: testCard(id: 'potato-13', suit: 'potato', value: 13),
          ),
        ],
      ),
    );

    await tester.pumpWidget(wrap(thirdTrickAssignment));
    await tester.pump();

    expect(findAppText('YOU ARE THE BRIGADE LEADER'), findsOneWidget);
    expect(find.textContaining('all four go to the same'), findsOneWidget);
    expect(find.byKey(const Key('tutorial-expand')), findsNothing);

    await tester.tap(find.byKey(const Key('tutorial-next')));
    await tester.pump();
    expect(find.byKey(const Key('tutorial-expand')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1700));
  });

  testWidgets('tutorial collapses out of the way while a play is pending', (
    tester,
  ) async {
    Widget wrap(TableViewModel model) => MaterialApp(
      home: SizedBox(
        width: 844,
        height: 390,
        child: TutorialWalkthroughOverlay(
          tokens: defaultDesignTokens,
          language: KolkhozLanguage.en,
          content: tutorialContent,
          onClose: () {},
          model: model,
        ),
      ),
    );

    await tester.pumpWidget(wrap(runtimeModel()));
    expect(findAppText('PLAY A CARD'), findsOneWidget);

    // Selecting a trick card folds the panel into the corner badge.
    await tester.pumpWidget(wrap(runtimeModelWithSelectedHandCard()));
    await tester.pump();
    expect(findAppText('PLAY A CARD'), findsNothing);
    expect(find.byKey(const Key('tutorial-expand')), findsOneWidget);

    // The badge can be re-opened manually.
    await tester.tap(find.byKey(const Key('tutorial-expand')));
    await tester.pump();
    expect(findAppText('PLAY A CARD'), findsOneWidget);

    // Clearing the pending play keeps the panel open.
    await tester.pumpWidget(wrap(runtimeModel()));
    await tester.pump();
    expect(findAppText('PLAY A CARD'), findsOneWidget);
    expect(find.byKey(const Key('tutorial-expand')), findsNothing);
  });

  testWidgets('tutorial walkthrough done closes on final step', (tester) async {
    var closed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 844,
          height: 390,
          child: TutorialWalkthroughOverlay(
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
            content: TutorialContent(
              orientationHeader: tutorialContent.orientationHeader,
              orientationBeginLabel: tutorialContent.orientationBeginLabel,
              orientationStops: tutorialContent.orientationStops,
              firstMatchStepId: tutorialContent.steps.last.id,
              steps: [tutorialContent.steps.last],
            ),
            onClose: () => closed = true,
            model: runtimeModel(),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('tutorial-next')));
    expect(closed, isTrue);
  });

  testWidgets('tutorial walkthrough follows selected language', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 844,
          height: 390,
          child: TutorialWalkthroughOverlay(
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.ru,
            content: tutorialContent,
            onClose: () {},
          ),
        ),
      ),
    );

    expect(findAppText('ДОБРО ПОЖАЛОВАТЬ В КОЛХОЗ'), findsOneWidget);
    expect(find.textContaining('Матч длится пять лет'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is ChromeScaledLabel && widget.text == 'Далее',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Year 0 tour unlocks the scripted match after its final stop', (
    tester,
  ) async {
    var unlocked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 844,
          height: 390,
          child: TutorialWalkthroughOverlay(
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
            content: tutorialContent,
            onClose: () {},
            onOrientationComplete: () => unlocked = true,
          ),
        ),
      ),
    );

    expect(findAppText('YEAR 0 · ORIENTATION'), findsOneWidget);
    for (
      var stop = 0;
      stop < tutorialContent.orientationStops.length;
      stop += 1
    ) {
      await tester.tap(find.byKey(const Key('tutorial-next')));
      await tester.pump();
    }
    expect(unlocked, isTrue);
    expect(findAppText("THIS YEAR'S REWARDS"), findsOneWidget);
  });

  testWidgets('reward lesson pauses before the AI trump lesson', (
    tester,
  ) async {
    String? continuedWith;
    final rewardAction = testLegalAction(
      kind: actionCompleteTutorialRewardLesson,
      label: 'Continue to trump',
    );
    final model = runtimeModelWith(
      year: 1,
      phase: phasePlanning,
      selection: SelectionState.empty,
      jobs: runtimeModel().table.jobs,
      legalActions: [rewardAction],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 844,
          height: 390,
          child: TutorialWalkthroughOverlay(
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
            content: tutorialContent,
            model: model,
            onClose: () {},
            onContinueAction: (kind) => continuedWith = kind,
          ),
        ),
      ),
    );

    expect(findAppText("THIS YEAR'S REWARDS"), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1700));
    expect(findAppText("THIS YEAR'S REWARDS"), findsOneWidget);

    await tester.tap(find.byKey(const Key('tutorial-next')));
    await tester.pump();

    expect(continuedWith, actionCompleteTutorialRewardLesson);
    expect(findAppText('THE TRUMP CROP'), findsOneWidget);
  });

  test('tutorial panels move away from the highlighted hand', () {
    expect(tutorialPanelAlignment(TutorialFocus.hand), Alignment.topRight);
    expect(tutorialPanelAlignment(TutorialFocus.jobs), Alignment.bottomRight);
    expect(tutorialPanelAlignment(TutorialFocus.table), Alignment.bottomRight);
  });

  testWidgets('Year 0 can suppress the planning reward overlay', (
    tester,
  ) async {
    final model = runtimeModelWith(
      phase: phasePlanning,
      selection: SelectionState.empty,
      jobs: runtimeModel().table.jobs,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 900,
          height: 520,
          child: BoardPlayArea(
            model: model,
            tokens: defaultDesignTokens,
            metrics: ResponsiveBoardMetrics.fromSize(
              const Size(900, 520),
              defaultDesignTokens,
            ),
            language: KolkhozLanguage.en,
            appearance: KolkhozAppearance.dark,
            suppressPlanningOverlay: true,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('planning-phase-overlay')), findsNothing);
  });

  testWidgets('Year 2 hands the swap lesson to requisition at the failure', (
    tester,
  ) async {
    Widget wrap(TableViewModel model) => MaterialApp(
      home: SizedBox(
        width: 844,
        height: 390,
        child: TutorialWalkthroughOverlay(
          tokens: defaultDesignTokens,
          language: KolkhozLanguage.en,
          content: tutorialContent,
          onClose: () {},
          model: model,
        ),
      ),
    );

    final base = runtimeModel();
    TableViewModel yearTwoModel({
      required String phase,
      List<int> completedRounds = const [],
      bool learnerWon = false,
    }) {
      final firstJob = base.table.jobs.first;
      return runtimeModelWith(
        year: 2,
        phase: phase,
        selection: SelectionState.empty,
        jobs: [
          Job(
            suit: firstJob.suit,
            hours: firstJob.hours,
            requiredHours: firstJob.requiredHours,
            claimed: firstJob.claimed,
            reward: firstJob.reward,
            assignedCards: [
              for (final round in completedRounds)
                testCard(
                  id: 'wheat-$round',
                  suit: 'wheat',
                  value: 10,
                  assignmentRound: round,
                ),
            ],
            validAssignmentTarget: firstJob.validAssignmentTarget,
            highlighted: firstJob.highlighted,
          ),
          ...base.table.jobs.skip(1),
        ],
        lastTrick: learnerWon
            ? Trick(
                winnerSeatID: base.viewer.seatID,
                plays: [
                  TrickPlay(
                    seatID: base.viewer.seatID!,
                    card: testCard(id: 'wheat-trump', suit: 'wheat', value: 10),
                  ),
                ],
              )
            : base.table.lastTrick,
      );
    }

    await tester.pumpWidget(wrap(yearTwoModel(phase: phaseSwap)));
    expect(findAppText('THE YEARLY SWAP'), findsOneWidget);

    await tester.pumpWidget(
      wrap(
        yearTwoModel(
          phase: phaseAssignment,
          completedRounds: const [1],
          learnerWon: true,
        ),
      ),
    );
    await tester.pump();
    expect(findAppText('ONE TRICK, TWO JOBS'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1700));

    await tester.pumpWidget(
      wrap(
        yearTwoModel(
          phase: phaseAssignment,
          completedRounds: const [1, 2, 3],
          learnerWon: true,
        ),
      ),
    );
    await tester.pump();
    expect(findAppText('CHOOSE THE JOB, NOT THE SUIT'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1700));

    await tester.pumpWidget(
      wrap(
        yearTwoModel(
          phase: phaseRequisition,
          completedRounds: const [1, 2, 3, 4],
        ),
      ),
    );
    await tester.pump();
    expect(findAppText('THIS IS REQUISITION'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1700));
  });

  testWidgets('Year 3 pauses on the forced Saboteur before the AI overtrumps', (
    tester,
  ) async {
    String? continuedWith;
    Widget wrap(TableViewModel model) => MaterialApp(
      home: SizedBox(
        width: 844,
        height: 390,
        child: TutorialWalkthroughOverlay(
          tokens: defaultDesignTokens,
          language: KolkhozLanguage.en,
          content: tutorialContent,
          onClose: () {},
          onContinueAction: (kind) => continuedWith = kind,
          model: model,
        ),
      ),
    );

    final paused = runtimeModelWith(
      year: 3,
      phase: phaseTrick,
      selection: SelectionState.empty,
      jobs: runtimeModel().table.jobs,
      legalActions: [
        testLegalAction(
          kind: actionCompleteTutorialSaboteurFollowLesson,
          label: 'Continue the trick',
        ),
      ],
    );
    await tester.pumpWidget(wrap(paused));
    expect(findAppText('THE SABOTEUR ALWAYS FOLLOWS'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tutorial-next')));
    await tester.pump();
    expect(continuedWith, actionCompleteTutorialSaboteurFollowLesson);
    expect(find.byKey(const Key('tutorial-expand')), findsOneWidget);

    final base = runtimeModel();
    final assignment = runtimeModelWith(
      year: 3,
      phase: phaseAssignment,
      selection: SelectionState.empty,
      jobs: base.table.jobs,
      legalActions: const [],
      lastTrick: Trick(
        winnerSeatID: 1,
        plays: [
          TrickPlay(
            seatID: 0,
            card: testCard(id: 'wrecker-0', suit: wreckerSuit, value: 0),
          ),
          TrickPlay(
            seatID: 1,
            card: testCard(id: 'sunflower-11', suit: 'sunflower', value: 11),
          ),
        ],
      ),
    );
    await tester.pumpWidget(wrap(assignment));
    await tester.pump();
    expect(findAppText('THE SABOTEUR POISONS A JOB'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1700));
  });

  testWidgets(
    'tutorial stays hands-off in Year 4 then teaches famine and ends',
    (tester) async {
      TableViewModel model({
        required int year,
        required String phase,
        bool isFamine = false,
        int maxTricks = 4,
        Trick? lastTrick,
        List<Seat>? seats,
        List<RequisitionEvent>? requisitionEvents,
      }) => runtimeModelWith(
        year: year,
        phase: phase,
        isFamine: isFamine,
        maxTricks: maxTricks,
        selection: SelectionState.empty,
        jobs: runtimeModel().table.jobs,
        lastTrick: lastTrick,
        seats: seats,
        requisitionEvents: requisitionEvents,
      );

      Widget wrap(TableViewModel value) => MaterialApp(
        home: SizedBox(
          width: 844,
          height: 390,
          child: TutorialWalkthroughOverlay(
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
            content: tutorialContent,
            onClose: () {},
            model: value,
          ),
        ),
      );

      await tester.pumpWidget(
        wrap(
          model(
            year: 3,
            phase: phaseAssignment,
            lastTrick: Trick(
              winnerSeatID: 1,
              plays: [
                TrickPlay(
                  seatID: 0,
                  card: testCard(id: 'wrecker-0', suit: wreckerSuit, value: 0),
                ),
              ],
            ),
          ),
        ),
      );
      expect(findAppText('THE SABOTEUR POISONS A JOB'), findsOneWidget);

      await tester.tap(find.byKey(const Key('tutorial-next')));
      await tester.pump();
      expect(find.byKey(const Key('tutorial-expand')), findsOneWidget);

      await tester.pumpWidget(wrap(model(year: 4, phase: phaseTrick)));
      await tester.pump();
      expect(find.byKey(const Key('tutorial-expand')), findsOneWidget);
      expect(findAppText('YEAR FIVE IS FAMINE'), findsNothing);

      await tester.pumpWidget(
        wrap(
          model(year: 5, phase: phasePlanning, isFamine: true, maxTricks: 3),
        ),
      );
      await tester.pump();
      expect(findAppText('YEAR FIVE IS FAMINE'), findsOneWidget);
      expect(
        findAppText('MAKE THE HIGHLIGHTED SWAP, THEN PLAY THREE TRICKS.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 1700));

      final famineSeats = [
        for (final seat in runtimeModel().table.seats)
          seat.id == 0 ? seatWithMedals(seat, 2) : seat,
      ];
      await tester.pumpWidget(
        wrap(
          model(
            year: 5,
            phase: phaseTrick,
            isFamine: true,
            maxTricks: 3,
            seats: famineSeats,
          ),
        ),
      );
      await tester.pump();
      expect(findAppText('ONE TRICK FROM HISTORY'), findsOneWidget);
      expect(findAppText('WIN THE FINAL TRICK.'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1700));

      await tester.tap(find.byKey(const Key('tutorial-next')));
      await tester.pump();
      expect(find.byKey(const Key('tutorial-expand')), findsOneWidget);

      final heroSeats = [
        for (final seat in runtimeModel().table.seats)
          seat.id == 0 ? seatWithMedals(seat, 3) : seat,
      ];
      await tester.pumpWidget(
        wrap(
          model(
            year: 5,
            phase: phaseRequisition,
            isFamine: true,
            maxTricks: 3,
            seats: heroSeats,
            requisitionEvents: const [
              RequisitionEvent(
                seatID: 0,
                suit: 'wheat',
                card: null,
                message: 'Protected from requisition.',
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(findAppText('HERO OF SOCIALIST LABOR'), findsOneWidget);
      expect(
        findAppText('YOUR CELLAR IS SAFE FROM THE FINAL REQUISITION.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 1700));

      await tester.pumpWidget(wrap(model(year: 5, phase: phaseGameOver)));
      await tester.pump();
      expect(findAppText('HIGHEST FINAL CELLAR WINS'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1700));
    },
  );

  test('board content width caps extra-wide desktop layouts', () {
    expect(boardPlayableContentWidth(900), 900);
    expect(boardPlayableContentWidth(1800), boardContentWidthMax);
  });

  test('compact board shell is portrait-only', () {
    expect(
      shouldUseCompactBoardShell(contentWidth: 430, contentHeight: 760),
      isTrue,
    );
    expect(
      shouldUseCompactBoardShell(contentWidth: 667, contentHeight: 375),
      isFalse,
    );
  });

  testWidgets('narrow board uses compact grid and bottom toolbar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: KolkhozBoard(
          model: runtimeModel(),
          tokens: defaultDesignTokens,
          language: KolkhozLanguage.en,
          appearance: KolkhozAppearance.dark,
        ),
      ),
    );

    expect(find.byType(CompactBoardShell), findsOneWidget);
    expect(find.byType(BoardRail), findsNothing);
    expect(find.byType(CompactBoardToolbar), findsOneWidget);
    expect(
      find.byKey(const Key('production-static-hero-brigade')),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byType(CompactBoardToolbar)).height,
      compactBoardToolbarCollapsedHeight,
    );

    await tester.tap(find.byKey(const Key('compact-toolbar-resize-handle')));
    await tester.pump();

    expect(
      tester.getSize(find.byType(CompactBoardToolbar)).height,
      compactBoardToolbarExpandedHeight,
    );
  });

  testWidgets('landscape phone uses the floating board chrome', (tester) async {
    await tester.binding.setSurfaceSize(const Size(667, 375));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: KolkhozBoard(
          model: runtimeModel(),
          tokens: defaultDesignTokens,
          language: KolkhozLanguage.en,
          appearance: KolkhozAppearance.dark,
        ),
      ),
    );

    expect(find.byType(CompactBoardShell), findsNothing);
    expect(find.byType(CompactBoardToolbar), findsNothing);
    expect(find.byType(BoardRail), findsNothing);
    expect(find.byType(BoardViewMenu), findsOneWidget);
    expect(find.byType(TopInfoStrip), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TopInfoStrip),
        matching: find.byType(RailStatusIcon),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(BoardViewMenu),
        matching: find.byType(RailStatusIcon),
      ),
      findsNothing,
    );
    expect(
      find.byKey(const Key('production-static-hero-brigade')),
      findsOneWidget,
    );
  });

  testWidgets('compact fallback keeps four seat columns in landscape', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(667, 375));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrigadePanel(
            model: runtimeModel(),
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
            compact: true,
          ),
        ),
      ),
    );

    final seatPositions = tester
        .widgetList<BrigadePlayerColumn>(find.byType(BrigadePlayerColumn))
        .map((seat) => tester.getTopLeft(find.byWidget(seat)))
        .toList();
    expect(seatPositions, hasLength(4));
    expect(seatPositions.map((position) => position.dy).toSet(), hasLength(1));
  });

  testWidgets('player portrait expands in-game player info in place', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: KolkhozBoard(
          model: runtimeModel(),
          tokens: defaultDesignTokens,
          language: KolkhozLanguage.en,
          appearance: KolkhozAppearance.dark,
        ),
      ),
    );

    final portrait = tester.widget<TactileButton>(
      find.byKey(const Key('player-portrait-0-inspect')),
    );
    portrait.onPressed!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(Dialog), findsNothing);
    expect(find.byKey(const Key('player-info-panel-0')), findsOneWidget);
    expect(find.textContaining('PLAYER'), findsOneWidget);
    expect(find.textContaining('SCORE'), findsOneWidget);
    expect(find.textContaining('HAND'), findsOneWidget);
  });

  testWidgets('expanded player info closes through a tactile footer', (
    tester,
  ) async {
    var closed = false;
    final model = runtimeModel();
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 360,
          height: 420,
          child: ExpandedPlayerInfoPanel(
            seat: model.table.seats.first,
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
            maxTricks: model.table.maxTricks,
            onClose: () => closed = true,
          ),
        ),
      ),
    );

    final closeSemantics = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.button == true &&
          widget.properties.label == 'Cancel',
    );
    expect(closeSemantics, findsOneWidget);
    await tester.tap(closeSemantics);
    expect(closed, isTrue);
  });

  test('brigade display helpers project column geometry', () {
    final spacing = brigadeColumnSpacing(1200);
    expect(spacing, 14);
    expect(
      brigadeExpandedColumnWidth(
        maxWidth: 1200,
        columnCount: 4,
        spacing: spacing,
      ),
      closeTo(289.5, 0.0001),
    );
    expect(brigadeColumnHeight(640), 632);
    expect(brigadeColumnContentWidth(289.5), 273.5);
    expect(brigadePlayerPanelWidth(289.5), 273.5);
    expect(brigadePlayerPanelHeight(273.5), closeTo(106.6324, 0.0001));
    expect(
      brigadePlayObjectWidth(columnWidth: 289.5, minWidth: 70),
      closeTo(246.15, 0.0001),
    );
    expect(brigadePlayObjectHeight(100, 1.42), 142);
    expect(
      brigadeContentColumnHeight(
        playerPanelHeight: 106.6324,
        playObjectHeight: 349.533,
      ),
      closeTo(480.1654, 0.0001),
    );
    expect(
      brigadePanelHeightForWidth(
        maxWidth: 1200,
        columnCount: 4,
        minCardWidth: 70,
        cardAspectRatio: 1.42,
      ),
      closeTo(488.1654, 0.0001),
    );
    expect(
      brigadePlayObjectMaxHeight(360, 106.6324),
      closeTo(229.3676, 0.0001),
    );
    expect(
      brigadePlayObjectFittingWidth(
        desiredWidth: 246.15,
        maxHeight: 229.3676,
        aspectRatio: 1.42,
      ),
      closeTo(161.5265, 0.0001),
    );
  });

  test('phase display helpers provide UI labels without engine projection', () {
    final model = runtimeModel();
    expect(hotSeatPhaseLine(model), 'Year 1 - Trick');
    expect(
      hotSeatPhaseLine(model, language: KolkhozLanguage.ru),
      'Год 1 - Взятка',
    );
  });

  test('card art display helpers project asset paths and pip positions', () {
    final jack = testCard(id: 'wheat-11', suit: 'wheat', value: 11, rank: 'J');
    final queen = testCard(id: 'beet-12', suit: 'beet', value: 12, rank: 'Q');
    final nomenklaturaQueen = testCard(
      id: 'beet-12',
      suit: 'beet',
      value: 12,
      rank: 'Q',
      nomenclature: true,
    );
    final wrecker = testCard(
      id: 'wrecker-0',
      suit: wreckerSuit,
      value: 0,
      rank: 'S',
    );
    final seat = testSeat(id: 0, name: 'You');

    expect(faceRankName(jack), 'jack');
    expect(cardRankDisplayLabel(jack), 'J 11');
    expect(cardRankDisplayLabel(queen), 'Q 12');
    expect(
      cardRankDisplayLabel(testCard(id: 'wheat-10', suit: 'wheat', value: 10)),
      '10',
    );
    expect(
      faceAssetPath(jack),
      'assets/art/field_plan/cards/faces/face-jack-wheat.png',
    );
    expect(
      faceAssetPath(nomenklaturaQueen),
      'assets/art/field_plan/cards/faces/face-queen-beet-nomenklatura.png',
    );
    expect(physicalDeckFaceCaption(nomenklaturaQueen), 'Доносчица');
    expect(faceRankName(wrecker), 'saboteur');
    expect(cardRankDisplayLabel(wrecker), 'S 0');
    expect(faceArtWidth(defaultDesignTokens.card.large), 31.5);
    expect(facePortraitArtWidth(jack, defaultDesignTokens.card.large), 63);
    expect(
      facePortraitArtWidth(wrecker, defaultDesignTokens.card.large),
      40.95,
    );
    expect(
      faceAssetPath(wrecker),
      'assets/art/field_plan/cards/faces/face-saboteur.png',
    );
    expect(portraitAssetPath(seat), fieldPlanPlayerForewoman.fieldPlanPath);
    expect(
      cardTemplateAssetPath(
        card: jack,
        tokens: defaultDesignTokens,
        trump: 'wheat',
      ),
      'assets/art/field_plan/cards/frames/card-frame-trump-dark.png',
    );
    expect(
      cardTemplateAssetPath(
        card: jack,
        tokens: lightDesignTokens,
        trump: 'beet',
      ),
      'assets/art/field_plan/cards/frames/card-frame-wheat.png',
    );
    expect(
      cardTemplateAssetPath(
        card: jack,
        tokens: defaultDesignTokens,
        trump: null,
      ),
      'assets/art/field_plan/cards/frames/card-frame-wheat-dark.png',
    );
    expect(cardUsesTrumpTemplate(card: wrecker, trump: 'beet'), isTrue);
    expect(
      cardTemplateAssetPath(
        card: wrecker,
        tokens: lightDesignTokens,
        trump: null,
      ),
      'assets/art/field_plan/cards/frames/card-frame-trump.png',
    );
    expect(pipPositions(12), hasLength(10));
    expect(
      displayTextSizeForCardRank(defaultDesignTokens.card.small),
      DisplayTextSize.xSmall,
    );
    expect(
      displayTextSizeForCardRank(defaultDesignTokens.card.large),
      DisplayTextSize.cardRank,
    );
    expect(displayTextScaleForCardRank(defaultDesignTokens.card.large), 1);
    expect(
      displayTextSizeForCardFaceValue(defaultDesignTokens.card.large),
      DisplayTextSize.caption2,
    );
    expect(cardCornerHorizontalInset(defaultDesignTokens.card.large), 0);
    expect(
      cardTopCornerVerticalInset(defaultDesignTokens.card.large),
      closeTo(-0.5964, 0.001),
    );
    expect(cardBottomCornerVerticalInset(defaultDesignTokens.card.large), 0);
    expect(
      cardFaceValueRankGap(defaultDesignTokens.card.large),
      closeTo(3.84, 0.001),
    );
    expect(
      cardCornerRankSuitGap(defaultDesignTokens.card.large),
      closeTo(0.1, 0.001),
    );
    expect(
      cardBottomCornerRankSuitGap(defaultDesignTokens.card.large),
      closeTo(0.8, 0.001),
    );
    expect(
      cardCornerSuitOutwardOffset(defaultDesignTokens.card.large),
      closeTo(1.2, 0.001),
    );
    expect(
      cardCornerSuitVisualSize(jack, defaultDesignTokens.card.large),
      closeTo(11, 0.001),
    );
    expect(
      cardCornerSuitVisualSize(wrecker, defaultDesignTokens.card.large),
      closeTo(16.5, 0.001),
    );
    expect(
      cardCornerSuitTowardRankOffset(defaultDesignTokens.card.large),
      closeTo(2.5, 0.001),
    );
    expect(
      cardBottomCornerRankDownOffset(defaultDesignTokens.card.large),
      closeTo(2, 0.001),
    );
    expect(
      cardCornerRankVisualHeight(defaultDesignTokens.card.large),
      closeTo(24, 0.001),
    );
    final oversizedCard = scaledHandTrayCardSize(
      defaultDesignTokens.card.large,
      404,
    );
    expect(displayTextSizeForCardRank(oversizedCard), DisplayTextSize.cardRank);
    expect(displayTextScaleForCardRank(oversizedCard), cardRankTextMaxScale);
    expect(cardCornerRankVisualHeight(oversizedCard), closeTo(34.8, 0.001));
  });

  test('panel title display helpers scale and fade predictably', () {
    expect(panelTitleScale(100), panelTitleScaleMin);
    expect(panelTitleScale(520), 1);
    expect(panelTitleIconSize(520), panelTitleIconSizeBase);
    expect(panelTitleHorizontalPadding(260), 9 * panelTitleScaleMin);
    expect(panelTitleOrnamentOpacity(300, urgent: false), 0);
    expect(panelTitleOrnamentOpacity(520, urgent: false), 0.52);
    expect(panelTitleOrnamentOpacity(520, urgent: true), 0.42);
  });

  test('hot seat display helpers clamp size and choose local player', () {
    final base = runtimeModel();
    final remoteCurrentModel = TableViewModel(
      viewer: base.viewer,
      table: TableState(
        year: base.table.year,
        phase: base.table.phase,
        phasePrompt: base.table.phasePrompt,
        currentPlayerID: 1,
        trump: base.table.trump,
        isFamine: base.table.isFamine,
        maxTricks: base.table.maxTricks,
        seats: [
          testSeat(id: 0, name: 'Local', controller: controllerHuman),
          testSeat(id: 1, name: 'Remote', controller: controllerRemoteHuman),
          testSeat(id: 2, name: 'AI'),
          testSeat(id: 3, name: 'AI 2'),
        ],
        jobs: base.table.jobs,
        trick: base.table.trick,
        lastTrick: base.table.lastTrick,
        requisitionEvents: base.table.requisitionEvents,
        exiledByYear: base.table.exiledByYear,
        scoreboard: base.table.scoreboard,
        gameResult: base.table.gameResult,
      ),
      panels: base.panels,
      selection: base.selection,
      legalActions: base.legalActions,
    );

    expect(hotSeatPanelWidth(100), hotSeatPanelMinWidth);
    expect(hotSeatPanelWidth(1000), hotSeatPanelMaxWidth);
    expect(hotSeatPortraitSlotSize(100), hotSeatPortraitMinSize);
    expect(hotSeatPortraitSlotSize(1000), hotSeatPortraitMaxSize);
    expect(hotSeatPrivacyPlayer(remoteCurrentModel).id, 0);
  });

  test('selected swap action requires exact hand plot and zone match', () {
    final selection = SelectionState.empty.copyWith(
      handCardID: 'wheat-7',
      plotCardID: 'beet-10',
      plotZone: plotZoneHidden,
    );

    expect(isSelectedSwapAction(selection, swapAction()), isTrue);
    expect(
      isSelectedSwapAction(
        selection.copyWith(clearHandCardID: true),
        swapAction(),
      ),
      isFalse,
    );
    expect(
      isSelectedSwapAction(
        selection,
        swapAction(plotCard: const EngineCardValue(suit: 3, value: 11)),
      ),
      isFalse,
    );
    expect(isSelectedSwapAction(selection, swapAction(plotZone: 1)), isFalse);
  });

  test('engine action exposure follows viewer seat instead of seat zero', () {
    expect(
      shouldExposeActionForViewer(
        action: playAction(playerID: 2),
        selection: SelectionState.empty,
        viewerSeatID: 2,
      ),
      isTrue,
    );
    expect(
      shouldExposeActionForViewer(
        action: playAction(playerID: 0),
        selection: SelectionState.empty,
        viewerSeatID: 2,
      ),
      isFalse,
    );
    expect(
      shouldExposeActionForViewer(
        action: const CEngineActionValue(
          kind: kcActionContinueAfterRequisition,
          playerID: -1,
          suit: -1,
          card: EngineCardValue(suit: -1, value: 0),
          handCard: EngineCardValue(suit: -1, value: 0),
          plotCard: EngineCardValue(suit: -1, value: 0),
          plotZone: -1,
          targetSuit: -1,
        ),
        selection: SelectionState.empty,
        viewerSeatID: 2,
      ),
      isTrue,
    );
  });

  test('raw engine actions drive swap and play card affordances', () {
    final actions = [
      playAction(card: const EngineCardValue(suit: 1, value: 12)),
      swapAction(),
      swapAction(
        handCard: const EngineCardValue(suit: 2, value: 8),
        plotCard: const EngineCardValue(suit: 0, value: 9),
        plotZone: 1,
      ),
      swapAction(
        handCard: const EngineCardValue(suit: 3, value: 6),
        plotCard: const EngineCardValue(suit: 2, value: 11),
        plotZone: 0,
      ),
      const CEngineActionValue(
        kind: kcActionSelectRequisitionCard,
        playerID: 0,
        suit: -1,
        card: EngineCardValue(suit: 1, value: 13),
        handCard: EngineCardValue(suit: -1, value: 0),
        plotCard: EngineCardValue(suit: -1, value: 0),
        plotZone: 0,
        targetSuit: -1,
      ),
    ];

    expect(handActionCardIDs(actions, 0), {
      'sunflower-12',
      'wheat-7',
      'potato-8',
      'beet-6',
    });
    expect(plotActionCardIDs(actions, plotZoneHidden), {
      'beet-10',
      'potato-11',
      'sunflower-13',
    });
    expect(plotActionCardIDs(actions, plotZoneHidden, playerID: 0), {
      'beet-10',
      'potato-11',
      'sunflower-13',
    });
    expect(plotActionCardIDs(actions, plotZoneHidden, playerID: 1), isEmpty);
    expect(plotActionCardIDs(actions, plotZoneRevealed), {'wheat-9'});
  });
}
