import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/app/settings/settings.dart';
import 'package:kolkhoz_app/src/app/profile/profile_controller/profile_remote_connection.dart';
import 'package:kolkhoz_app/src/app/profile/profile_controller/profile_controller.dart';
import 'package:kolkhoz_app/src/app/remote_connection/remote_connection.dart';
import 'package:kolkhoz_app/src/app/views/main_menu/main_menu_controller/menu_remote_connection.dart';
import 'package:kolkhoz_app/src/app/views/main_menu/main_menu_controller/main_menu_controller.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/c_engine_bridge.dart';
import 'package:kolkhoz_app/src/app/app.dart';
import 'package:kolkhoz_app/src/app/profile/models/profile_remote_models.dart';
import 'package:kolkhoz_app/src/app/views/main_menu/main_menu_controller/menu_remote_models.dart';
import 'package:page_flip/page_flip.dart';

const _comrades = OnlineComradesResponse(
  userID: 'nadia',
  comradeCode: 'NADIA',
  comrades: [
    OnlineComradeProfile(
      userID: 'boris',
      displayName: 'Boris',
      avatarURL: 'worker2',
      comradeCode: 'BORIS',
      isOnline: true,
      inLobby: true,
    ),
    OnlineComradeProfile(
      userID: 'irina',
      displayName: 'Irina',
      avatarURL: 'worker3',
      comradeCode: 'IRINA',
      isOnline: true,
      inGame: true,
    ),
  ],
  incomingRequests: [
    OnlineComradeProfile(
      userID: 'mikhail',
      displayName: 'Mikhail',
      avatarURL: 'worker4',
      comradeCode: 'MIKHA',
    ),
  ],
);

void main() {
  testWidgets('main menu supports reading-order keyboard navigation', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semantics = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    for (final appearance in KolkhozAppearance.values) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(
        MaterialApp(
          theme: kolkhozTheme(appearance.tokens),
          home: SizedBox.expand(child: _lobby(appearance: appearance)),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final createGame = find.descendant(
        of: find.byKey(const Key('field-plan-menu-local')),
        matching: find.bySemanticsLabel('Create Game'),
      );
      expect(
        tester
            .getSemantics(createGame)
            .flagsCollection
            .isFocused
            .toBoolOrNull(),
        isTrue,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final joinGame = find.descendant(
        of: find.byKey(const Key('field-plan-menu-online')),
        matching: find.bySemanticsLabel('Join Game'),
      );
      expect(
        tester.getSemantics(joinGame).flagsCollection.isFocused.toBoolOrNull(),
        isTrue,
        reason: appearance.name,
      );
    }
    semantics.dispose();
  });

  testWidgets('add players curls between notebook pages', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semantics = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    await tester.pumpWidget(
      MaterialApp(home: SizedBox.expand(child: _lobby())),
    );
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    final addPlayers = find.bySemanticsLabel('ADD PLAYERS');
    expect(tester.getSemantics(addPlayers).flagsCollection.isButton, isTrue);
    expect(
      find.byKey(const Key('create-game-notebook-binding')),
      findsOneWidget,
    );

    expect(
      find.byKey(const ValueKey('create-game-setup-page')),
      findsOneWidget,
    );

    await tester.tap(addPlayers);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byKey(const Key('create-game-page-curl')), findsOneWidget);
    expect(find.byKey(const Key('create-game-binding-rear')), findsOneWidget);
    expect(
      find.byKey(const Key('create-game-binding-contact')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('create-game-notebook-binding')),
      findsOneWidget,
    );
    expect(
      (tester
                  .widget<CustomPaint>(
                    find.byKey(const Key('create-game-page-curl')),
                  )
                  .painter
              as PageFlipEffect)
          .amount
          .status,
      AnimationStatus.reverse,
    );
    expect(
      tester
          .widget<AbsorbPointer>(
            find.byKey(const Key('create-game-page-turn-input-guard')),
          )
          .absorbing,
      isTrue,
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<AbsorbPointer>(
            find.byKey(const Key('create-game-page-turn-input-guard')),
          )
          .absorbing,
      isFalse,
    );
    expect(find.bySemanticsLabel('ADD PLAYERS'), findsNothing);
    expect(find.bySemanticsLabel('BACK TO SETUP'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('create-game-lobby-page')),
      findsOneWidget,
    );

    await tester.tap(find.bySemanticsLabel('BACK TO SETUP'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byKey(const Key('create-game-page-curl')), findsOneWidget);
    expect(
      (tester
                  .widget<CustomPaint>(
                    find.byKey(const Key('create-game-page-curl')),
                  )
                  .painter
              as PageFlipEffect)
          .amount
          .status,
      AnimationStatus.forward,
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('ADD PLAYERS'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('notebook route skips the page turn for reduced motion', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1152, 768));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: SizedBox.expand(child: _lobby()),
      ),
    );

    await tester.tap(find.bySemanticsLabel('ADD PLAYERS'));
    await tester.pump();

    expect(find.byKey(const Key('create-game-page-curl')), findsNothing);
    expect(find.bySemanticsLabel('BACK TO SETUP'), findsOneWidget);
  });
}

Widget _lobby({KolkhozAppearance appearance = KolkhozAppearance.dark}) {
  return StandaloneLobby(
    tokens: appearance.tokens,
    language: KolkhozLanguage.en,
    appearance: appearance,
    onStart: () {},
    selectedPreset: KolkhozGamePreset.kolkhoz,
    customVariants: KolkhozGameVariants.kolkhoz,
    playerControllers: KolkhozPlayerController.defaultControllers,
    showingRules: false,
    showingOnline: false,
    showingProfile: false,
    initialSettingsTab: KolkhozSettingsTab.profile,
    displayName: 'Nadia',
    portraitAsset: 'worker1',
    profileStats: const KolkhozProfileStats(
      offlinePlays: 12,
      offlineWins: 8,
      onlinePlays: 7,
      onlineWins: 4,
      casualRating: 1084,
      rating: 1142,
      totalWins: 12,
      totalLosses: 7,
    ),
    comradesSummary: _comrades,
    cloudConfigured: true,
    cloudReady: true,
    cloudSignedIn: true,
    cloudEmail: 'nadia@example.com',
    cloudAuthMessage: 'Profile loaded.',
    onHostOnline: (_, _, _, _, _) async => 'ABCDE',
    onJoinOnline: (_, _, _) async {},
    onMatchmakeOnline: (_, _, _) async => 'ABCDE',
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
    menuRemoteConnection: _TestMenuRemoteConnection(),
    mainMenuController: MainMenuController(
      _TestMenuRemoteConnection(),
      () => true,
      () => null,
    ),
    profileController: ProfileController(
      connection: _testRemoteConnection(),
      remoteConnection: _TestProfileRemoteConnection(),
    ),
  );
}

RemoteConnection _testRemoteConnection() => RemoteConnection(
  baseURL: Uri.parse('http://test.invalid'),
  accessTokenProvider: () async => null,
  deviceID: '',
  activeSessionID: () => null,
);

class _TestMenuRemoteConnection extends MenuRemoteConnection {
  _TestMenuRemoteConnection() : super(_testRemoteConnection());

  @override
  Future<List<OnlineSessionListing>> fetchSessions() async => const [
    OnlineSessionListing(
      sessionID: 'session-one',
      openSeats: [2, 3],
      occupiedSeats: [0, 1],
      controllers: KolkhozPlayerController.defaultControllers,
      playerProfiles: [
        OnlinePlayerProfile(
          playerID: 0,
          userID: 'mira',
          displayName: 'Mira',
          avatarURL: 'worker3',
        ),
        OnlinePlayerProfile(
          playerID: 1,
          userID: 'boris',
          displayName: 'Boris',
          avatarURL: 'worker2',
        ),
      ],
      ranked: false,
      actionLogCount: 18,
      createdAt: 1,
      expiresAt: 9999999999,
    ),
  ];

  @override
  Future<OnlineServerStatus> fetchServerStatus() async =>
      const OnlineServerStatus(citizensOnline: 16);
}

class _TestProfileRemoteConnection extends ProfileRemoteConnection {
  _TestProfileRemoteConnection() : super(_testRemoteConnection());

  @override
  Future<OnlineComradesResponse> fetchComrades() async => _comrades;
}
