import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kolkhoz_app/src/app/settings/animation_speed.dart';
import 'package:kolkhoz_app/src/app/profile/profile_controller/profile_controller.dart';
import 'package:kolkhoz_app/src/app/profile/profile_controller/progression.dart';
import 'package:kolkhoz_app/src/app/settings/settings.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/game_lobby.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/c_engine_bridge.dart';
import 'package:kolkhoz_app/src/app/profile/models/profile_remote_models.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/remote_game_engine/game_session_models.dart';
import 'package:kolkhoz_app/src/app/views/main_menu/main_menu_controller/menu_remote_connection.dart';
import 'package:kolkhoz_app/src/app/views/main_menu/main_menu_controller/main_menu_controller.dart';
import 'package:kolkhoz_app/src/app/views/shared/app_text.dart';
import 'package:kolkhoz_app/src/app/views/shared/chrome_button.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'package:kolkhoz_app/src/app/views/shared/field_plan_assets.dart';
import 'package:kolkhoz_app/src/app/views/shared/field_plan_typography.dart';
import 'package:kolkhoz_app/src/app/views/shared/display_text.dart';
import 'package:kolkhoz_app/src/app/profile/views/progression_overview.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import 'package:kolkhoz_app/src/app/views/game/views/components/display/table_display.dart';
import 'create_game/create_game_view.dart';
import 'create_game/variant_controls.dart';
import 'join_game/join_game_view.dart';
import 'settings/leaderboard_view.dart';
import 'settings/settings_view.dart';
import 'package:kolkhoz_app/src/app/views/game/views/settings/game_settings_view.dart';

export 'create_game/create_game_view.dart';
export 'create_game/variant_controls.dart';
export 'join_game/join_game_view.dart';
export 'settings/leaderboard_view.dart';
export 'settings/settings_view.dart';

Future<void> _noopOnlineSync() async {}

KolkhozGamePreset presetForVariants(KolkhozGameVariants variants) {
  if (sameVariants(variants, KolkhozGameVariants.kolkhoz)) {
    return KolkhozGamePreset.kolkhoz;
  }
  return KolkhozGamePreset.custom;
}

bool sameVariants(KolkhozGameVariants left, KolkhozGameVariants right) {
  return left.deckType == right.deckType &&
      left.maxYears == right.maxYears &&
      left.nomenclature == right.nomenclature &&
      left.allowSwap == right.allowSwap &&
      left.northernStyle == right.northernStyle &&
      left.miceVariant == right.miceVariant &&
      left.ordenNachalniku == right.ordenNachalniku &&
      left.medalsCount == right.medalsCount &&
      left.accumulateJobs == right.accumulateJobs &&
      left.heroOfSovietUnion == right.heroOfSovietUnion &&
      left.wreckerCard == right.wreckerCard &&
      left.finalYearTrump == right.finalYearTrump &&
      left.passCards == right.passCards &&
      left.highestCardsRequisition == right.highestCardsRequisition &&
      left.lottoRewards == right.lottoRewards;
}

KolkhozGameVariants migrateLegacyKolkhozVariants(KolkhozGameVariants variants) {
  final legacyKolkhoz = KolkhozGameVariants.kolkhoz.copyWith(passCards: true);
  return sameVariants(variants, legacyKolkhoz)
      ? KolkhozGameVariants.kolkhoz
      : variants;
}

String gameResultShareText({
  required TableViewModel model,
  required int seed,
  required KolkhozGameVariants variants,
  required KolkhozLanguage language,
}) {
  final scores = model.table.gameResult?.scores ?? model.table.scoreboard;
  final winnerID =
      model.table.gameResult?.winnerSeatID ?? inferredWinnerID(scores);
  final winnerScore = finalScoreForSeat(scores, winnerID);
  final winnerName = model.table.seats
      .firstWhere(
        (seat) => seat.id == winnerID,
        orElse: () => model.table.seats.first,
      )
      .name;
  final setup = [
    presetTitle(presetForVariants(variants), language),
    '${variants.deckType} cards',
    '${variants.maxYears} years',
  ].join(' / ');
  final scoreLine = model.table.seats
      .map((seat) => '${seat.name} ${finalScoreForSeat(scores, seat.id)}')
      .join(', ');
  return [
    'Kolkhoz result',
    'Winner: $winnerName - $winnerScore',
    'Scores: $scoreLine',
    'Setup: $setup',
    'Seed: $seed',
  ].join('\n');
}

enum KolkhozGamePreset {
  kolkhoz,
  littleKolkhoz,
  campStyle,
  custom;

  String get title {
    return switch (this) {
      KolkhozGamePreset.kolkhoz => 'Kolkhoz',
      KolkhozGamePreset.littleKolkhoz => 'Little Kolkhoz',
      KolkhozGamePreset.campStyle => 'Camp Style',
      KolkhozGamePreset.custom => 'Custom',
    };
  }

  KolkhozGameVariants? get variants {
    return switch (this) {
      KolkhozGamePreset.kolkhoz => KolkhozGameVariants.kolkhoz,
      KolkhozGamePreset.littleKolkhoz => KolkhozGameVariants.littleKolkhoz,
      KolkhozGamePreset.campStyle => KolkhozGameVariants.campStyle,
      KolkhozGamePreset.custom => null,
    };
  }

  String? get iconAsset {
    return switch (this) {
      KolkhozGamePreset.kolkhoz => fieldPlanPresetKolkhoz.fieldPlanPath,
      KolkhozGamePreset.littleKolkhoz =>
        fieldPlanPresetLittleKolkhoz.fieldPlanPath,
      KolkhozGamePreset.campStyle => fieldPlanPresetCampStyle.fieldPlanPath,
      KolkhozGamePreset.custom => null,
    };
  }
}

const betaGamePresets = [KolkhozGamePreset.kolkhoz, KolkhozGamePreset.custom];

class StandaloneLobby extends StatelessWidget {
  const StandaloneLobby({
    required this.tokens,
    required this.language,
    required this.appearance,
    this.cardBack = KolkhozCardBack.classic,
    required this.onStart,
    this.onResumeLocalGame,
    required this.selectedPreset,
    required this.customVariants,
    required this.playerControllers,
    this.gameLobby,
    this.demoMode = false,
    this.animationSpeed = defaultGameAnimationSpeed,
    this.confirmNewGame = true,
    this.confirmMainMenu = true,
    this.showInvalidTapHints = true,
    this.soundEnabled = true,
    this.showingHome = false,
    required this.showingRules,
    required this.showingOnline,
    required this.onHostOnline,
    this.onHostOnlineSeries,
    this.onInviteOnlineComrades,
    required this.onJoinOnline,
    this.onWatchOnline,
    this.onRememberStartedSetup,
    this.onMatchmakeOnline,
    this.onKickOnlinePlayer,
    required this.onEnterOnlineGame,
    this.onSyncActiveSession = _noopOnlineSync,
    this.onCancelOnlineGame,
    required this.onPresetChanged,
    required this.onCustomVariantsChanged,
    required this.onPlayerControllersChanged,
    this.onAnimationSpeedChanged,
    this.onConfirmNewGameChanged,
    this.onConfirmMainMenuChanged,
    this.onShowInvalidTapHintsChanged,
    this.onSoundEnabledChanged,
    required this.onRulesPressed,
    required this.onOfflinePressed,
    required this.onOnlinePressed,
    required this.onTutorialPressed,
    this.hasTutorialProgress = false,
    this.onRestartTutorialPressed,
    required this.onLanguageToggle,
    required this.onAppearanceToggle,
    this.onCardBackChanged,
    this.showingProfile = false,
    this.profileFeaturesEnabled = true,
    this.initialSettingsTab = KolkhozSettingsTab.profile,
    this.hostedInviteCode,
    this.onlineSessionUpdate,
    this.showHostedInviteCode = false,
    this.displayName = defaultProfileDisplayName,
    this.portraitAsset = defaultProfilePortraitAsset,
    this.profileStats = defaultProfileStats,
    this.progression = const ProgressionState(),
    this.unlockedCardBacks = const {
      KolkhozCardBack.classic,
      KolkhozCardBack.harvest,
      KolkhozCardBack.granary,
      KolkhozCardBack.winter,
    },
    this.favoriteSetup,
    this.lastStartedSetup,
    this.comradesSummary = const OnlineComradesResponse(),
    this.cloudConfigured = false,
    this.cloudReady = false,
    this.cloudSignedIn = false,
    this.cloudEmail,
    this.cloudAuthBusy = false,
    this.cloudAuthMessage,
    this.cloudAuthIsError = false,
    this.onProfilePressed,
    this.onSettingsPressed,
    this.onDisplayNameChanged,
    this.onPortraitChanged,
    this.onSaveFavoriteSetup,
    this.onUseFavoriteSetup,
    this.onCloudSignIn,
    this.onCloudSignUp,
    this.onCloudResetPassword,
    this.onCloudDeleteAccount,
    this.onComradeRequestToUser,
    this.menuRemoteConnection,
    this.mainMenuController,
    this.profileController,
    this.onStartDailyChallenge,
    this.error,
    super.key,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozAppearance appearance;
  final KolkhozCardBack cardBack;
  final VoidCallback onStart;
  final VoidCallback? onResumeLocalGame;
  final KolkhozGamePreset selectedPreset;
  final KolkhozGameVariants customVariants;
  final List<KolkhozPlayerController> playerControllers;
  final GameLobby? gameLobby;
  final bool demoMode;
  final GameAnimationSpeed animationSpeed;
  final bool confirmNewGame;
  final bool confirmMainMenu;
  final bool showInvalidTapHints;
  final bool soundEnabled;
  final bool showingHome;
  final bool showingRules;
  final bool showingOnline;
  final bool showingProfile;
  final bool profileFeaturesEnabled;
  final KolkhozSettingsTab initialSettingsTab;
  final String? hostedInviteCode;
  final OnlineSessionUpdate? onlineSessionUpdate;
  final bool showHostedInviteCode;
  final String displayName;
  final String portraitAsset;
  final KolkhozProfileStats profileStats;
  final ProgressionState progression;
  final Set<KolkhozCardBack> unlockedCardBacks;
  final KolkhozFavoriteSetup? favoriteSetup;
  final KolkhozFavoriteSetup? lastStartedSetup;
  final OnlineComradesResponse comradesSummary;
  final bool cloudConfigured;
  final bool cloudReady;
  final bool cloudSignedIn;
  final String? cloudEmail;
  final bool cloudAuthBusy;
  final String? cloudAuthMessage;
  final bool cloudAuthIsError;
  final Future<String> Function(
    Uri baseURL,
    List<KolkhozPlayerController> controllers,
    bool enterImmediately,
    bool ranked,
    bool browserJoinable,
  )
  onHostOnline;
  final Future<String> Function(
    Uri,
    List<KolkhozPlayerController>,
    bool,
    bool,
    bool,
    int,
  )?
  onHostOnlineSeries;
  final Future<void> Function(String sessionID, List<String> userIDs)?
  onInviteOnlineComrades;
  final Future<void> Function(
    Uri baseURL,
    String inviteCode,
    int? preferredPlayerID,
  )
  onJoinOnline;
  final Future<void> Function(Uri baseURL, String sessionID)? onWatchOnline;
  final void Function(
    List<KolkhozPlayerController> controllers,
    List<String> lobbySeats,
    bool browserJoinable,
  )?
  onRememberStartedSetup;
  final Future<String> Function(
    Uri baseURL,
    bool rankedOnly,
    bool comradesOnly,
  )?
  onMatchmakeOnline;
  final Future<void> Function(int playerID)? onKickOnlinePlayer;
  final VoidCallback onEnterOnlineGame;
  final Future<void> Function() onSyncActiveSession;
  final VoidCallback? onCancelOnlineGame;
  final ValueChanged<KolkhozGamePreset> onPresetChanged;
  final ValueChanged<KolkhozGameVariants> onCustomVariantsChanged;
  final ValueChanged<List<KolkhozPlayerController>> onPlayerControllersChanged;
  final ValueChanged<GameAnimationSpeed>? onAnimationSpeedChanged;
  final ValueChanged<bool>? onConfirmNewGameChanged;
  final ValueChanged<bool>? onConfirmMainMenuChanged;
  final ValueChanged<bool>? onShowInvalidTapHintsChanged;
  final ValueChanged<bool>? onSoundEnabledChanged;
  final VoidCallback onRulesPressed;
  final VoidCallback onOfflinePressed;
  final VoidCallback onOnlinePressed;
  final VoidCallback onTutorialPressed;
  final bool hasTutorialProgress;
  final VoidCallback? onRestartTutorialPressed;
  final VoidCallback onLanguageToggle;
  final VoidCallback onAppearanceToggle;
  final ValueChanged<KolkhozCardBack>? onCardBackChanged;
  final VoidCallback? onProfilePressed;
  final VoidCallback? onSettingsPressed;
  final ValueChanged<String>? onDisplayNameChanged;
  final ValueChanged<String>? onPortraitChanged;
  final VoidCallback? onSaveFavoriteSetup;
  final VoidCallback? onUseFavoriteSetup;
  final Future<void> Function(String email, String password)? onCloudSignIn;
  final Future<void> Function(String email, String password)? onCloudSignUp;
  final Future<void> Function(String email)? onCloudResetPassword;
  final Future<void> Function()? onCloudDeleteAccount;
  final Future<void> Function(String userID)? onComradeRequestToUser;
  final MenuRemoteConnection? menuRemoteConnection;
  final MainMenuController? mainMenuController;
  final ProfileController? profileController;
  final Future<void> Function()? onStartDailyChallenge;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final backgroundPath = fieldPlanMenuBackgroundPathFor(
      dark: appearance == KolkhozAppearance.dark,
    );
    return Scaffold(
      backgroundColor: const Color(0xff171712),
      body: Stack(
        fit: StackFit.expand,
        children: [
          KeyedSubtree(
            key: ValueKey(backgroundPath),
            child: Image.asset(
              backgroundPath,
              key: const Key('field-plan-menu-background'),
              fit: BoxFit.cover,
              alignment: Alignment.center,
              filterQuality: FilterQuality.high,
            ),
          ),
          const _FieldPlanMenuSceneTreatment(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final usableWidth = constraints.maxWidth;
                final usableHeight = constraints.maxHeight.isFinite
                    ? constraints.maxHeight
                    : 640.0;
                final wide = usableWidth >= 560 && usableWidth > usableHeight;
                final shortLandscape = wide && usableHeight < 520;
                final showCornerProfile =
                    profileFeaturesEnabled && wide && usableHeight >= 620;
                final outerPadding = shortLandscape
                    ? 8.0
                    : wide
                    ? 10.0
                    : 18.0;
                final spacing = shortLandscape
                    ? 6.0
                    : wide
                    ? 12.0
                    : 18.0;
                final contentWidth = math.max(
                  280.0,
                  usableWidth - outerPadding * 2,
                );
                final contentHeight = math.max(
                  300.0,
                  usableHeight - outerPadding * 2,
                );
                final railWidth = wide
                    ? (contentWidth * (shortLandscape ? 0.37 : 0.34)).clamp(
                        shortLandscape ? 220.0 : 210.0,
                        shortLandscape ? 250.0 : 455.0,
                      )
                    : contentWidth;
                final panelWidth = wide
                    ? math.max(300.0, contentWidth - railWidth - spacing)
                    : contentWidth;
                final panelTop = showCornerProfile ? 92.0 : 0.0;
                final panelHeight = wide
                    ? math.max(280.0, contentHeight - panelTop)
                    : math.max(440.0, usableHeight * 0.72);
                final railHeight = wide
                    ? contentHeight
                    : (usableHeight * 0.38).clamp(250.0, 360.0);

                final menuRail = SizedBox(
                  width: railWidth,
                  height: railHeight,
                  child: _FieldPlanMenuRail(
                    language: language,
                    appearance: appearance,
                    compact: shortLandscape,
                    showingHome: showingHome,
                    showingRules: showingRules,
                    showingOnline: showingOnline,
                    showingProfile: showingProfile,
                    settingsSelected:
                        showingProfile &&
                        initialSettingsTab != KolkhozSettingsTab.profile,
                    demoMode: demoMode,
                    cloudConfigured: cloudConfigured,
                    cloudReady: cloudReady,
                    cloudSignedIn: cloudSignedIn,
                    cloudAuthBusy: cloudAuthBusy,
                    comradeRequestCount:
                        comradesSummary.incomingRequests.length,
                    displayName: displayName,
                    portraitAsset: portraitAsset,
                    onResumeLocalGame: onResumeLocalGame,
                    onOfflinePressed: onOfflinePressed,
                    onOnlinePressed: onOnlinePressed,
                    onProfilePressed: onProfilePressed,
                    profileFeaturesEnabled: profileFeaturesEnabled,
                    onSettingsPressed: onSettingsPressed,
                    onRulesPressed: onRulesPressed,
                    onLanguageToggle: onLanguageToggle,
                    onAppearanceToggle: onAppearanceToggle,
                  ),
                );
                final panel = SizedBox(
                  width: panelWidth,
                  height: panelHeight,
                  child: _LobbyPanel(
                    tokens: tokens,
                    language: language,
                    selectedPreset: selectedPreset,
                    customVariants: customVariants,
                    playerControllers: playerControllers,
                    gameLobby: gameLobby,
                    demoMode: demoMode,
                    appearance: appearance,
                    cardBack: cardBack,
                    compactRail: shortLandscape,
                    animationSpeed: animationSpeed,
                    confirmNewGame: confirmNewGame,
                    confirmMainMenu: confirmMainMenu,
                    showInvalidTapHints: showInvalidTapHints,
                    soundEnabled: soundEnabled,
                    showingRules: showingRules,
                    showingOnline: showingOnline,
                    showingProfile: showingProfile,
                    profileFeaturesEnabled: profileFeaturesEnabled,
                    initialSettingsTab: initialSettingsTab,
                    hostedInviteCode: hostedInviteCode,
                    onlineSessionUpdate: onlineSessionUpdate,
                    showHostedInviteCode: showHostedInviteCode,
                    displayName: displayName,
                    portraitAsset: portraitAsset,
                    profileStats: profileStats,
                    progression: progression,
                    unlockedCardBacks: unlockedCardBacks,
                    favoriteSetup: favoriteSetup,
                    lastStartedSetup: lastStartedSetup,
                    comradesSummary: comradesSummary,
                    cloudConfigured: cloudConfigured,
                    cloudReady: cloudReady,
                    cloudSignedIn: cloudSignedIn,
                    cloudEmail: cloudEmail,
                    cloudAuthBusy: cloudAuthBusy,
                    cloudAuthMessage: cloudAuthMessage,
                    cloudAuthIsError: cloudAuthIsError,
                    onTutorialPressed: onTutorialPressed,
                    hasTutorialProgress: hasTutorialProgress,
                    onRestartTutorialPressed: onRestartTutorialPressed,
                    onStart: onStart,
                    onHostOnline: onHostOnline,
                    onHostOnlineSeries: onHostOnlineSeries,
                    onInviteOnlineComrades: onInviteOnlineComrades,
                    onJoinOnline: onJoinOnline,
                    onWatchOnline: onWatchOnline,
                    onRememberStartedSetup: onRememberStartedSetup,
                    onMatchmakeOnline: onMatchmakeOnline,
                    onKickOnlinePlayer: onKickOnlinePlayer,
                    onEnterOnlineGame: onEnterOnlineGame,
                    onSyncActiveSession: onSyncActiveSession,
                    onCancelOnlineGame: onCancelOnlineGame,
                    onPresetChanged: onPresetChanged,
                    onCustomVariantsChanged: onCustomVariantsChanged,
                    onPlayerControllersChanged: onPlayerControllersChanged,
                    onAnimationSpeedChanged: onAnimationSpeedChanged,
                    onConfirmNewGameChanged: onConfirmNewGameChanged,
                    onConfirmMainMenuChanged: onConfirmMainMenuChanged,
                    onShowInvalidTapHintsChanged: onShowInvalidTapHintsChanged,
                    onSoundEnabledChanged: onSoundEnabledChanged,
                    onLanguageToggle: onLanguageToggle,
                    onAppearanceToggle: onAppearanceToggle,
                    onCardBackChanged: onCardBackChanged,
                    onDisplayNameChanged: onDisplayNameChanged,
                    onPortraitChanged: onPortraitChanged,
                    onSaveFavoriteSetup: onSaveFavoriteSetup,
                    onUseFavoriteSetup: onUseFavoriteSetup,
                    onCloudSignIn: onCloudSignIn,
                    onCloudSignUp: onCloudSignUp,
                    onCloudResetPassword: onCloudResetPassword,
                    onCloudDeleteAccount: onCloudDeleteAccount,
                    onComradeRequestToUser: onComradeRequestToUser,
                    menuRemoteConnection: menuRemoteConnection,
                    mainMenuController: mainMenuController,
                    profileController: profileController,
                    onStartDailyChallenge: onStartDailyChallenge,
                  ),
                );

                return SingleChildScrollView(
                  padding: EdgeInsets.all(outerPadding),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: contentWidth,
                      child: Stack(
                        children: [
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                menuRail,
                                if (!showingHome) ...[
                                  SizedBox(width: spacing),
                                  Padding(
                                    padding: EdgeInsets.only(top: panelTop),
                                    child: panel,
                                  ),
                                ],
                              ],
                            )
                          else
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                menuRail,
                                if (!showingHome) ...[
                                  SizedBox(height: spacing),
                                  panel,
                                ],
                              ],
                            ),
                          if (showCornerProfile)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: _FieldPlanProfilePlaque(
                                displayName: displayName,
                                portraitAsset: portraitAsset,
                                cloudSignedIn: cloudSignedIn,
                                badgeCount:
                                    comradesSummary.incomingRequests.length,
                                selected:
                                    showingProfile &&
                                    initialSettingsTab ==
                                        KolkhozSettingsTab.profile,
                                onPressed: onProfilePressed,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldPlanMenuSceneTreatment extends StatelessWidget {
  const _FieldPlanMenuSceneTreatment();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xbd151713),
                  Color(0x68151713),
                  Color(0x12151713),
                  Color(0x00151713),
                ],
                stops: [0, 0.28, 0.58, 0.82],
              ),
            ),
          ),
          Opacity(
            opacity: 0.055,
            child: Image.asset(
              'assets/art/field_plan/shared/textures/paper-light.png',
              fit: BoxFit.none,
              repeat: ImageRepeat.repeat,
              color: const Color(0xff705c3b),
              colorBlendMode: BlendMode.multiply,
              filterQuality: FilterQuality.low,
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0x99211e17), width: 7),
              gradient: const RadialGradient(
                radius: 1.08,
                colors: [Colors.transparent, Color(0x32110f0c)],
                stops: [0.62, 1],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldPlanMenuRail extends StatelessWidget {
  const _FieldPlanMenuRail({
    required this.language,
    required this.appearance,
    required this.compact,
    required this.showingHome,
    required this.showingRules,
    required this.showingOnline,
    required this.showingProfile,
    required this.settingsSelected,
    required this.demoMode,
    required this.cloudConfigured,
    required this.cloudReady,
    required this.cloudSignedIn,
    required this.cloudAuthBusy,
    required this.comradeRequestCount,
    required this.displayName,
    required this.portraitAsset,
    required this.onResumeLocalGame,
    required this.onOfflinePressed,
    required this.onOnlinePressed,
    required this.onProfilePressed,
    required this.profileFeaturesEnabled,
    required this.onSettingsPressed,
    required this.onRulesPressed,
    required this.onLanguageToggle,
    required this.onAppearanceToggle,
  });

  final KolkhozLanguage language;
  final KolkhozAppearance appearance;
  final bool compact;
  final bool showingHome;
  final bool showingRules;
  final bool showingOnline;
  final bool showingProfile;
  final bool settingsSelected;
  final bool demoMode;
  final bool cloudConfigured;
  final bool cloudReady;
  final bool cloudSignedIn;
  final bool cloudAuthBusy;
  final int comradeRequestCount;
  final String displayName;
  final String portraitAsset;
  final VoidCallback? onResumeLocalGame;
  final VoidCallback onOfflinePressed;
  final VoidCallback onOnlinePressed;
  final VoidCallback? onProfilePressed;
  final bool profileFeaturesEnabled;
  final VoidCallback? onSettingsPressed;
  final VoidCallback onRulesPressed;
  final VoidCallback onLanguageToggle;
  final VoidCallback onAppearanceToggle;

  @override
  Widget build(BuildContext context) {
    final localSelected =
        !showingHome && !showingRules && !showingOnline && !showingProfile;
    final hasResume = onResumeLocalGame != null;
    final mainButtonHeight = compact
        ? hasResume
              ? 42.0
              : 48.0
        : hasResume
        ? 60.0
        : 68.0;
    final gap = compact ? 6.0 : 10.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final titleHeight = compact
            ? (constraints.maxWidth / 3).clamp(72.0, 84.0)
            : (constraints.maxWidth / 3).clamp(112.0, 180.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: titleHeight, child: const _FieldPlanTitleBanner()),
            SizedBox(height: gap),
            if (onResumeLocalGame case final onResume?) ...[
              _FieldPlanMenuButton(
                key: const Key('field-plan-menu-resume'),
                label: language.strings.lobbyResumeGame,
                pictogram: fieldPlanToolbarConfirmIconPath,
                selected: false,
                height: mainButtonHeight,
                onPressed: onResume,
              ),
              SizedBox(height: gap),
            ],
            _FieldPlanMenuButton(
              key: const Key('field-plan-menu-local'),
              label: language.t(
                demoMode
                    ? KolkhozText.lobbyPlayDemo
                    : KolkhozText.lobbyCreateGame,
              ),
              pictogram: fieldPlanCreateGamePictogram.fieldPlanPath,
              selected: localSelected,
              height: mainButtonHeight,
              onPressed: onOfflinePressed,
            ),
            SizedBox(height: gap),
            _FieldPlanMenuButton(
              key: const Key('field-plan-menu-online'),
              label: language.strings.lobbyJoinGame,
              pictogram: demoMode
                  ? 'assets/ui/Icons/icon-lock.png'
                  : fieldPlanJoinGamePictogram.fieldPlanPath,
              selected: showingOnline,
              enabled: !demoMode,
              height: mainButtonHeight,
              onPressed: onOnlinePressed,
            ),
            SizedBox(height: gap),
            _FieldPlanMenuButton(
              key: const Key('field-plan-menu-rules'),
              label: language.strings.lobbyHowToPlay,
              pictogram: fieldPlanHowToPlayPictogram.fieldPlanPath,
              selected: showingRules,
              height: mainButtonHeight,
              onPressed: onRulesPressed,
            ),
            SizedBox(height: compact ? 7 : 12),
            _FieldPlanUtilityStrip(
              language: language,
              appearance: appearance,
              compact: compact,
              profileSelected: showingProfile && !settingsSelected,
              settingsSelected: settingsSelected,
              cloudConfigured: cloudConfigured,
              cloudReady: cloudReady,
              cloudSignedIn: cloudSignedIn,
              cloudAuthBusy: cloudAuthBusy,
              badgeCount: comradeRequestCount,
              onProfilePressed: onProfilePressed,
              profileFeaturesEnabled: profileFeaturesEnabled,
              onSettingsPressed: onSettingsPressed ?? onProfilePressed,
              onLanguageToggle: onLanguageToggle,
              onAppearanceToggle: onAppearanceToggle,
            ),
            if (!compact) ...[
              const Spacer(),
              Text(
                language.strings.kolkhozappGameBy,
                textAlign: TextAlign.left,
                style: fieldPlanBodyStrongTextStyle.copyWith(
                  color: const Color(0xffddc590),
                  fontSize: 11,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                language.strings.kolkhozappWilliamTheisen,
                textAlign: TextAlign.left,
                style: fieldPlanBodyStrongTextStyle.copyWith(
                  color: const Color(0xffddc590),
                  fontSize: 11,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _FieldPlanTitleBanner extends StatelessWidget {
  const _FieldPlanTitleBanner();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/art/field_plan/menu-title-splash-v2.png',
      key: const Key('field-plan-title-banner'),
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      filterQuality: FilterQuality.high,
    );
  }
}

class _FieldPlanMenuButton extends StatelessWidget {
  const _FieldPlanMenuButton({
    required this.label,
    required this.pictogram,
    required this.selected,
    required this.height,
    required this.onPressed,
    this.enabled = true,
    super.key,
  });

  final String label;
  final String pictogram;
  final bool selected;
  final bool enabled;
  final double height;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final fill = selected ? const Color(0xffaa3022) : const Color(0xffddcda5);
    final ink = selected ? const Color(0xfff0dfb7) : const Color(0xff20221d);
    final clipper = _FieldPlanButtonClipper(pointed: selected);
    final content = ClipPath(
      clipper: clipper,
      child: Material(
        color: fill,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            height * 0.27,
            height * 0.12,
            selected ? height * 0.55 : height * 0.28,
            height * 0.12,
          ),
          child: Row(
            children: [
              Image.asset(
                pictogram,
                width: height * 0.56,
                height: height * 0.56,
                color: ink,
                colorBlendMode: BlendMode.srcIn,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) =>
                    Icon(Icons.star, size: height * 0.48, color: ink),
              ),
              SizedBox(width: height * 0.2),
              Expanded(
                child: FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    style: fieldPlanDisplayTextStyle.copyWith(
                      color: ink,
                      fontSize: height * 0.48,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: TactileControlSurface(
          enabled: enabled,
          onPressed: onPressed,
          pressTravel: 4,
          hoverLift: -2,
          hoverScale: 1.012,
          child: SizedBox(
            height: height,
            child: CustomPaint(
              painter: _FieldPlanButtonBorderPainter(
                pointed: selected,
                shadow: true,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldPlanUtilityStrip extends StatelessWidget {
  const _FieldPlanUtilityStrip({
    required this.language,
    required this.appearance,
    required this.compact,
    required this.profileSelected,
    required this.settingsSelected,
    required this.cloudConfigured,
    required this.cloudReady,
    required this.cloudSignedIn,
    required this.cloudAuthBusy,
    required this.badgeCount,
    required this.onProfilePressed,
    required this.profileFeaturesEnabled,
    required this.onSettingsPressed,
    required this.onLanguageToggle,
    required this.onAppearanceToggle,
  });

  final KolkhozLanguage language;
  final KolkhozAppearance appearance;
  final bool compact;
  final bool profileSelected;
  final bool settingsSelected;
  final bool cloudConfigured;
  final bool cloudReady;
  final bool cloudSignedIn;
  final bool cloudAuthBusy;
  final int badgeCount;
  final VoidCallback? onProfilePressed;
  final bool profileFeaturesEnabled;
  final VoidCallback? onSettingsPressed;
  final VoidCallback onLanguageToggle;
  final VoidCallback onAppearanceToggle;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xee20221d),
          border: Border.all(color: const Color(0xffc8ae72), width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0xaa11120f), offset: Offset(4, 5)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            if (profileFeaturesEnabled)
              _FieldPlanCompactUtilityButton(
                label: KolkhozSettingsTab.profile.title(language),
                icon: Icons.person,
                badgeCount: badgeCount,
                selected: profileSelected,
                onPressed: onProfilePressed,
              ),
            _FieldPlanCompactUtilityButton(
              key: const Key('field-plan-menu-language'),
              label: language.strings.lobbyLanguage,
              asset: language.toggleIconAsset,
              onPressed: onLanguageToggle,
            ),
            _FieldPlanCompactUtilityButton(
              key: const Key('field-plan-menu-theme'),
              label: language.strings.lobbyTheme,
              asset: appearance.toggleIconAsset,
              onPressed: onAppearanceToggle,
            ),
            _FieldPlanCompactUtilityButton(
              key: const Key('field-plan-menu-settings'),
              label: language.strings.lobbySettings,
              icon: Icons.settings,
              selected: settingsSelected,
              onPressed: onSettingsPressed,
            ),
          ],
        ),
      );
    }
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xee20221d),
        border: Border.all(color: const Color(0xffc8ae72), width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0xaa11120f), offset: Offset(5, 6)),
        ],
      ),
      child: Row(
        children: [
          if (profileFeaturesEnabled)
            Expanded(
              child: _FieldPlanUtilityButton(
                label: KolkhozSettingsTab.profile.title(language),
                icon: Icons.person,
                selected: profileSelected,
                badgeCount: badgeCount,
                onPressed: onProfilePressed,
              ),
            ),
          _FieldPlanUtilityIconButton(
            key: const Key('field-plan-menu-language'),
            label: language.strings.lobbyLanguage,
            tooltip: language.toggleTitle,
            asset: language.toggleIconAsset,
            onPressed: onLanguageToggle,
          ),
          _FieldPlanUtilityIconButton(
            key: const Key('field-plan-menu-theme'),
            label: language.strings.lobbyTheme,
            tooltip: appearance.toggleTitle(language),
            asset: appearance.toggleIconAsset,
            onPressed: onAppearanceToggle,
          ),
          Expanded(
            child: _FieldPlanUtilityButton(
              key: const Key('field-plan-menu-settings'),
              label: language.strings.lobbySettings,
              icon: Icons.settings,
              selected: settingsSelected,
              onPressed: onSettingsPressed,
            ),
          ),
          _FieldPlanCloudStatus(
            configured: cloudConfigured,
            ready: cloudReady,
            signedIn: cloudSignedIn,
            busy: cloudAuthBusy,
          ),
        ],
      ),
    );
  }
}

class _FieldPlanCompactUtilityButton extends StatelessWidget {
  const _FieldPlanCompactUtilityButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.asset,
    this.selected = false,
    this.badgeCount = 0,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? asset;
  final bool selected;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xfff0dfb7) : const Color(0xffd2bb83);
    final visual = icon != null
        ? Icon(icon, size: 22, color: color)
        : Image.asset(
            asset!,
            width: 22,
            height: 22,
            filterQuality: FilterQuality.high,
            isAntiAlias: true,
          );
    return Tooltip(
      message: label,
      child: Semantics(
        container: true,
        button: true,
        selected: selected,
        enabled: onPressed != null,
        label: label,
        child: ExcludeSemantics(
          child: TactileControlSurface(
            enabled: onPressed != null,
            onPressed: onPressed,
            pressTravel: 2.5,
            hoverLift: -1,
            hoverScale: 1.08,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  visual,
                  if (badgeCount > 0)
                    Positioned(
                      right: -7,
                      top: -6,
                      child: _FieldPlanBadge(count: badgeCount),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldPlanUtilityButton extends StatelessWidget {
  const _FieldPlanUtilityButton({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
    this.badgeCount = 0,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onPressed;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xfff0dfb7) : const Color(0xffd2bb83);
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      enabled: onPressed != null,
      label: label,
      child: ExcludeSemantics(
        child: TactileControlSurface(
          enabled: onPressed != null,
          onPressed: onPressed,
          pressTravel: 2.5,
          hoverLift: -1,
          hoverScale: 1.025,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 22, color: color),
                  if (badgeCount > 0)
                    Positioned(
                      right: -7,
                      top: -6,
                      child: _FieldPlanBadge(count: badgeCount),
                    ),
                ],
              ),
              const SizedBox(width: 5),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    style: fieldPlanDisplayTextStyle.copyWith(
                      color: color,
                      fontSize: 14,
                      letterSpacing: 0.9,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldPlanUtilityIconButton extends StatelessWidget {
  const _FieldPlanUtilityIconButton({
    super.key,
    required this.label,
    required this.tooltip,
    required this.asset,
    required this.onPressed,
  });

  final String label;
  final String tooltip;
  final String asset;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: label,
        child: TactileControlSurface(
          onPressed: onPressed,
          pressTravel: 2.5,
          hoverLift: -1,
          hoverScale: 1.08,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: Image.asset(
              asset,
              width: 23,
              height: 23,
              filterQuality: FilterQuality.high,
              isAntiAlias: true,
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldPlanCloudStatus extends StatelessWidget {
  const _FieldPlanCloudStatus({
    required this.configured,
    required this.ready,
    required this.signedIn,
    required this.busy,
  });

  final bool configured;
  final bool ready;
  final bool signedIn;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final color = !configured
        ? const Color(0xffbc4a32)
        : busy || !ready
        ? const Color(0xffd0a74f)
        : signedIn
        ? const Color(0xff8ca163)
        : const Color(0xff7f7767);
    return Padding(
      padding: const EdgeInsets.only(right: 3),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xffe2ce9a)),
        ),
      ),
    );
  }
}

class _FieldPlanProfilePlaque extends StatelessWidget {
  const _FieldPlanProfilePlaque({
    required this.displayName,
    required this.portraitAsset,
    required this.cloudSignedIn,
    required this.badgeCount,
    required this.selected,
    required this.onPressed,
  });

  final String displayName;
  final String portraitAsset;
  final bool cloudSignedIn;
  final int badgeCount;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      enabled: onPressed != null,
      label: KolkhozSettingsTab.profile.title(
        Localizations.localeOf(context).languageCode == 'ru'
            ? KolkhozLanguage.ru
            : KolkhozLanguage.en,
      ),
      child: Material(
        color: Colors.transparent,
        child: TactileControlSurface(
          key: const Key('field-plan-profile-plaque'),
          enabled: onPressed != null,
          onPressed: onPressed,
          pressTravel: 4,
          hoverLift: -2,
          hoverScale: 1.012,
          child: Container(
            width: 340,
            height: 76,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xf221231f),
              border: Border.all(
                color: selected
                    ? const Color(0xffc44a30)
                    : const Color(0xffc8ae72),
                width: 3,
              ),
              boxShadow: const [
                BoxShadow(color: Color(0xaa11120f), offset: Offset(5, 6)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xffd9c797),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xffc23b29),
                      width: 4,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      _fieldPlanPortraitPath(portraitAsset),
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'COMRADE ${displayName.toUpperCase()}',
                      maxLines: 1,
                      style: fieldPlanDisplayTextStyle.copyWith(
                        color: const Color(0xffead7a6),
                        fontSize: 25,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      cloudSignedIn ? Icons.star : Icons.star_border,
                      color: const Color(0xffb43827),
                      size: 26,
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        right: -7,
                        top: -6,
                        child: _FieldPlanBadge(count: badgeCount),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldPlanBadge extends StatelessWidget {
  const _FieldPlanBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 17),
      height: 17,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: const Color(0xffb43827),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xffead7a6)),
      ),
      child: Center(
        child: Text(
          count > 9 ? '9+' : '$count',
          style: fieldPlanDisplayTextStyle.copyWith(
            color: const Color(0xfff0dfb7),
            fontSize: 10,
            height: 1,
          ),
        ),
      ),
    );
  }
}

String _fieldPlanPortraitPath(String portraitAsset) {
  return fieldPlanPlayerPortraitPath(portraitAsset);
}

class _FieldPlanButtonClipper extends CustomClipper<Path> {
  const _FieldPlanButtonClipper({required this.pointed});

  final bool pointed;

  @override
  Path getClip(Size size) {
    if (!pointed) return Path()..addRect(Offset.zero & size);
    final tip = math.min(size.width * 0.09, size.height * 0.5);
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width - tip, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width - tip, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant _FieldPlanButtonClipper oldClipper) =>
      pointed != oldClipper.pointed;
}

class _FieldPlanButtonBorderPainter extends CustomPainter {
  const _FieldPlanButtonBorderPainter({
    required this.pointed,
    required this.shadow,
  });

  final bool pointed;
  final bool shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _FieldPlanButtonClipper(pointed: pointed).getClip(size);
    if (shadow) {
      canvas.drawPath(
        path.shift(const Offset(5, 6)),
        Paint()..color = const Color(0xaa11120f),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xff292820)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _FieldPlanButtonBorderPainter oldDelegate) =>
      pointed != oldDelegate.pointed || shadow != oldDelegate.shadow;
}

DisplayTextSize buttonContentTextSize(double buttonHeight) {
  final targetFontSize = buttonHeight * 0.40;
  if (targetFontSize <= 9) {
    return DisplayTextSize.xSmall;
  }
  if (targetFontSize <= 10.5) {
    return DisplayTextSize.small;
  }
  if (targetFontSize <= 12) {
    return DisplayTextSize.caption2;
  }
  if (targetFontSize <= 15) {
    return DisplayTextSize.caption;
  }
  if (targetFontSize <= 18.5) {
    return DisplayTextSize.headline;
  }
  if (targetFontSize <= 22) {
    return DisplayTextSize.title;
  }
  return DisplayTextSize.cardRank;
}

class _LobbyPanel extends StatelessWidget {
  const _LobbyPanel({
    required this.tokens,
    required this.language,
    required this.selectedPreset,
    required this.customVariants,
    required this.playerControllers,
    required this.gameLobby,
    required this.demoMode,
    required this.appearance,
    required this.cardBack,
    required this.compactRail,
    this.animationSpeed = defaultGameAnimationSpeed,
    this.confirmNewGame = true,
    this.confirmMainMenu = true,
    this.showInvalidTapHints = true,
    this.soundEnabled = true,
    required this.showingRules,
    required this.showingOnline,
    required this.showingProfile,
    required this.profileFeaturesEnabled,
    required this.initialSettingsTab,
    required this.hostedInviteCode,
    required this.onlineSessionUpdate,
    required this.showHostedInviteCode,
    required this.displayName,
    required this.portraitAsset,
    required this.profileStats,
    required this.progression,
    required this.unlockedCardBacks,
    required this.favoriteSetup,
    required this.lastStartedSetup,
    required this.comradesSummary,
    required this.cloudConfigured,
    required this.cloudReady,
    required this.cloudSignedIn,
    required this.cloudEmail,
    required this.cloudAuthBusy,
    required this.cloudAuthMessage,
    required this.cloudAuthIsError,
    required this.onTutorialPressed,
    this.hasTutorialProgress = false,
    this.onRestartTutorialPressed,
    required this.onStart,
    required this.onHostOnline,
    required this.onHostOnlineSeries,
    required this.onInviteOnlineComrades,
    required this.onJoinOnline,
    required this.onWatchOnline,
    required this.onRememberStartedSetup,
    required this.onMatchmakeOnline,
    required this.onKickOnlinePlayer,
    required this.onEnterOnlineGame,
    required this.onSyncActiveSession,
    required this.onCancelOnlineGame,
    required this.onPresetChanged,
    required this.onCustomVariantsChanged,
    required this.onPlayerControllersChanged,
    this.onAnimationSpeedChanged,
    this.onConfirmNewGameChanged,
    this.onConfirmMainMenuChanged,
    this.onShowInvalidTapHintsChanged,
    this.onSoundEnabledChanged,
    required this.onLanguageToggle,
    required this.onAppearanceToggle,
    required this.onCardBackChanged,
    required this.onDisplayNameChanged,
    required this.onPortraitChanged,
    required this.onSaveFavoriteSetup,
    required this.onUseFavoriteSetup,
    required this.onCloudSignIn,
    required this.onCloudSignUp,
    required this.onCloudResetPassword,
    required this.onCloudDeleteAccount,
    required this.onComradeRequestToUser,
    required this.menuRemoteConnection,
    required this.mainMenuController,
    required this.profileController,
    required this.onStartDailyChallenge,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozGamePreset selectedPreset;
  final KolkhozGameVariants customVariants;
  final List<KolkhozPlayerController> playerControllers;
  final GameLobby? gameLobby;
  final bool demoMode;
  final KolkhozAppearance appearance;
  final KolkhozCardBack cardBack;
  final bool compactRail;
  final GameAnimationSpeed animationSpeed;
  final bool confirmNewGame;
  final bool confirmMainMenu;
  final bool showInvalidTapHints;
  final bool soundEnabled;
  final bool showingRules;
  final bool showingOnline;
  final bool showingProfile;
  final bool profileFeaturesEnabled;
  final KolkhozSettingsTab initialSettingsTab;
  final String? hostedInviteCode;
  final OnlineSessionUpdate? onlineSessionUpdate;
  final bool showHostedInviteCode;
  final String displayName;
  final String portraitAsset;
  final KolkhozProfileStats profileStats;
  final ProgressionState progression;
  final Set<KolkhozCardBack> unlockedCardBacks;
  final KolkhozFavoriteSetup? favoriteSetup;
  final KolkhozFavoriteSetup? lastStartedSetup;
  final OnlineComradesResponse comradesSummary;
  final bool cloudConfigured;
  final bool cloudReady;
  final bool cloudSignedIn;
  final String? cloudEmail;
  final bool cloudAuthBusy;
  final String? cloudAuthMessage;
  final bool cloudAuthIsError;
  final VoidCallback onTutorialPressed;
  final bool hasTutorialProgress;
  final VoidCallback? onRestartTutorialPressed;
  final VoidCallback onStart;
  final Future<String> Function(
    Uri baseURL,
    List<KolkhozPlayerController> controllers,
    bool enterImmediately,
    bool ranked,
    bool browserJoinable,
  )
  onHostOnline;
  final Future<String> Function(
    Uri,
    List<KolkhozPlayerController>,
    bool,
    bool,
    bool,
    int,
  )?
  onHostOnlineSeries;
  final Future<void> Function(String sessionID, List<String> userIDs)?
  onInviteOnlineComrades;
  final Future<void> Function(
    Uri baseURL,
    String inviteCode,
    int? preferredPlayerID,
  )
  onJoinOnline;
  final Future<void> Function(Uri baseURL, String sessionID)? onWatchOnline;
  final void Function(
    List<KolkhozPlayerController> controllers,
    List<String> lobbySeats,
    bool browserJoinable,
  )?
  onRememberStartedSetup;
  final Future<String> Function(
    Uri baseURL,
    bool rankedOnly,
    bool comradesOnly,
  )?
  onMatchmakeOnline;
  final Future<void> Function(int playerID)? onKickOnlinePlayer;
  final VoidCallback onEnterOnlineGame;
  final Future<void> Function() onSyncActiveSession;
  final VoidCallback? onCancelOnlineGame;
  final ValueChanged<KolkhozGamePreset> onPresetChanged;
  final ValueChanged<KolkhozGameVariants> onCustomVariantsChanged;
  final ValueChanged<List<KolkhozPlayerController>> onPlayerControllersChanged;
  final ValueChanged<GameAnimationSpeed>? onAnimationSpeedChanged;
  final ValueChanged<bool>? onConfirmNewGameChanged;
  final ValueChanged<bool>? onConfirmMainMenuChanged;
  final ValueChanged<bool>? onShowInvalidTapHintsChanged;
  final ValueChanged<bool>? onSoundEnabledChanged;
  final VoidCallback onLanguageToggle;
  final VoidCallback onAppearanceToggle;
  final ValueChanged<KolkhozCardBack>? onCardBackChanged;
  final ValueChanged<String>? onDisplayNameChanged;
  final ValueChanged<String>? onPortraitChanged;
  final VoidCallback? onSaveFavoriteSetup;
  final VoidCallback? onUseFavoriteSetup;
  final Future<void> Function(String email, String password)? onCloudSignIn;
  final Future<void> Function(String email, String password)? onCloudSignUp;
  final Future<void> Function(String email)? onCloudResetPassword;
  final Future<void> Function()? onCloudDeleteAccount;
  final Future<void> Function(String userID)? onComradeRequestToUser;
  final MenuRemoteConnection? menuRemoteConnection;
  final MainMenuController? mainMenuController;
  final ProfileController? profileController;
  final Future<void> Function()? onStartDailyChallenge;

  @override
  Widget build(BuildContext context) {
    final variants = demoMode
        ? KolkhozGameVariants.demoKolkhoz
        : selectedPreset.variants ?? customVariants;
    final creatingGame = !showingProfile && !showingOnline && !showingRules;
    final variantPanel = CreateGameView(
      tokens: tokens,
      language: language,
      selectedPreset: selectedPreset,
      customVariants: customVariants,
      playerControllers: playerControllers,
      gameLobby: gameLobby,
      demoMode: demoMode,
      variants: variants,
      displayName: displayName,
      portraitAsset: portraitAsset,
      profileStats: profileStats,
      favoriteSetup: favoriteSetup,
      lastStartedSetup: lastStartedSetup,
      comradesSummary: comradesSummary,
      compactRail: compactRail,
      onStart: onStart,
      onHostOnline: onHostOnline,
      onHostOnlineSeries: onHostOnlineSeries,
      onInviteOnlineComrades: onInviteOnlineComrades,
      onComradeRequestToUser: onComradeRequestToUser,
      onRememberStartedSetup: onRememberStartedSetup,
      hostedInviteCode: hostedInviteCode,
      onlineSessionUpdate: onlineSessionUpdate,
      showHostedInviteCode: showHostedInviteCode,
      onKickOnlinePlayer: onKickOnlinePlayer,
      onEnterOnlineGame: onEnterOnlineGame,
      onCancelOnlineGame: onCancelOnlineGame,
      onPresetChanged: onPresetChanged,
      onCustomVariantsChanged: onCustomVariantsChanged,
      onPlayerControllersChanged: onPlayerControllersChanged,
      onSaveFavoriteSetup: onSaveFavoriteSetup,
      onUseFavoriteSetup: onUseFavoriteSetup,
    );
    final secondaryPanelKind = showingProfile
        ? 'profile-$initialSettingsTab'
        : showingOnline
        ? 'online'
        : showingRules
        ? 'rules'
        : 'none';
    final secondaryPanel = showingProfile
        ? SettingsPanel(
            tokens: tokens,
            language: language,
            appearance: appearance,
            cardBack: cardBack,
            animationSpeed: animationSpeed,
            confirmNewGame: confirmNewGame,
            confirmMainMenu: confirmMainMenu,
            showInvalidTapHints: showInvalidTapHints,
            soundEnabled: soundEnabled,
            displayName: displayName,
            portraitAsset: portraitAsset,
            profileStats: profileStats,
            progression: progression,
            unlockedCardBacks: unlockedCardBacks,
            comradesSummary: comradesSummary,
            cloudConfigured: cloudConfigured,
            cloudReady: cloudReady,
            cloudSignedIn: cloudSignedIn,
            cloudEmail: cloudEmail,
            cloudAuthBusy: cloudAuthBusy,
            cloudAuthMessage: cloudAuthMessage,
            cloudAuthIsError: cloudAuthIsError,
            initialTab: initialSettingsTab,
            profileFeaturesEnabled: profileFeaturesEnabled,
            onStart: onStart,
            onTutorialPressed: onTutorialPressed,
            onAnimationSpeedChanged: onAnimationSpeedChanged,
            onConfirmNewGameChanged: onConfirmNewGameChanged,
            onConfirmMainMenuChanged: onConfirmMainMenuChanged,
            onShowInvalidTapHintsChanged: onShowInvalidTapHintsChanged,
            onSoundEnabledChanged: onSoundEnabledChanged,
            onLanguageToggle: onLanguageToggle,
            onAppearanceToggle: onAppearanceToggle,
            onCardBackChanged: onCardBackChanged,
            onDisplayNameChanged: onDisplayNameChanged,
            onPortraitChanged: onPortraitChanged,
            onCloudSignIn: onCloudSignIn,
            onCloudSignUp: onCloudSignUp,
            onCloudResetPassword: onCloudResetPassword,
            onCloudDeleteAccount: onCloudDeleteAccount,
            menuRemoteConnection: menuRemoteConnection,
            profileController: profileController,
            onStartDailyChallenge: onStartDailyChallenge,
          )
        : showingOnline
        ? JoinGameView(
            tokens: tokens,
            language: language,
            hostedInviteCode: hostedInviteCode,
            onlineSessionUpdate: onlineSessionUpdate,
            gameLobby: gameLobby,
            showHostedInviteCode: showHostedInviteCode,
            onJoinOnline: onJoinOnline,
            onWatchOnline: onWatchOnline,
            onMatchmakeOnline: onMatchmakeOnline,
            onKickOnlinePlayer: onKickOnlinePlayer,
            onEnterOnlineGame: onEnterOnlineGame,
            onSyncActiveSession: onSyncActiveSession,
            onCancelOnlineGame: onCancelOnlineGame,
            comradesSummary: comradesSummary,
            onComradeRequestToUser: onComradeRequestToUser,
            mainMenuController: mainMenuController,
            profileController: profileController,
          )
        : showingRules
        ? RulesView(
            tokens: tokens,
            language: language,
            onTutorialPressed: onTutorialPressed,
            hasTutorialProgress: hasTutorialProgress,
            onRestartTutorialPressed: onRestartTutorialPressed,
          )
        : const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.colors.panel.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(tokens.radius.panelOuter),
        border: Border.all(color: tokens.colors.gold.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: tokens.colors.black.withValues(alpha: 0.36),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Offstage(offstage: !creatingGame, child: variantPanel),
          if (!creatingGame)
            MechanicalPanelSwitcher(
              panelKey: secondaryPanelKind,
              child: secondaryPanel,
            ),
        ],
      ),
    );
  }
}

enum KolkhozSettingsTab {
  profile,
  leaderboard,
  progress,
  comrades,
  admin,
  assist,
  display,
  rules;

  String title(KolkhozLanguage language) {
    return switch (this) {
      KolkhozSettingsTab.profile => language.strings.kolkhozappProfile,
      KolkhozSettingsTab.leaderboard => language.strings.kolkhozappLeaderboard,
      KolkhozSettingsTab.progress => language.strings.kolkhozappProgress,
      KolkhozSettingsTab.comrades => language.strings.kolkhozappComrades,
      KolkhozSettingsTab.admin => 'OPERATIONS',
      KolkhozSettingsTab.assist => OptionsMenuTab.assist.title(language),
      KolkhozSettingsTab.display => OptionsMenuTab.display.title(language),
      KolkhozSettingsTab.rules => OptionsMenuTab.rules.title(language),
    };
  }

  String get iconAsset {
    return switch (this) {
      KolkhozSettingsTab.profile =>
        'assets/art/field_plan/shared/pictograms/profile.png',
      KolkhozSettingsTab.leaderboard => fieldPlanMedalIconPath,
      KolkhozSettingsTab.progress => fieldPlanMedalIconPath,
      KolkhozSettingsTab.comrades =>
        'assets/art/field_plan/shared/pictograms/friends-list.png',
      KolkhozSettingsTab.admin => 'assets/ui/Icons/icon-settings-session.png',
      KolkhozSettingsTab.assist => OptionsMenuTab.assist.iconAsset,
      KolkhozSettingsTab.display => OptionsMenuTab.display.iconAsset,
      KolkhozSettingsTab.rules => OptionsMenuTab.rules.iconAsset,
    };
  }
}

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({
    super.key,
    required this.tokens,
    required this.language,
    required this.appearance,
    required this.cardBack,
    required this.animationSpeed,
    required this.confirmNewGame,
    required this.confirmMainMenu,
    required this.showInvalidTapHints,
    required this.soundEnabled,
    required this.displayName,
    required this.portraitAsset,
    required this.profileStats,
    required this.progression,
    required this.unlockedCardBacks,
    required this.comradesSummary,
    required this.cloudConfigured,
    required this.cloudReady,
    required this.cloudSignedIn,
    required this.cloudEmail,
    required this.cloudAuthBusy,
    required this.cloudAuthMessage,
    required this.cloudAuthIsError,
    required this.initialTab,
    this.profileFeaturesEnabled = true,
    required this.onStart,
    required this.onTutorialPressed,
    required this.onAnimationSpeedChanged,
    required this.onConfirmNewGameChanged,
    required this.onConfirmMainMenuChanged,
    required this.onShowInvalidTapHintsChanged,
    required this.onSoundEnabledChanged,
    required this.onLanguageToggle,
    required this.onAppearanceToggle,
    required this.onCardBackChanged,
    required this.onDisplayNameChanged,
    required this.onPortraitChanged,
    required this.onCloudSignIn,
    required this.onCloudSignUp,
    required this.onCloudResetPassword,
    required this.onCloudDeleteAccount,
    required this.menuRemoteConnection,
    required this.profileController,
    required this.onStartDailyChallenge,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozAppearance appearance;
  final KolkhozCardBack cardBack;
  final GameAnimationSpeed animationSpeed;
  final bool confirmNewGame;
  final bool confirmMainMenu;
  final bool showInvalidTapHints;
  final bool soundEnabled;
  final String displayName;
  final String portraitAsset;
  final KolkhozProfileStats profileStats;
  final ProgressionState progression;
  final Set<KolkhozCardBack> unlockedCardBacks;
  final OnlineComradesResponse comradesSummary;
  final bool cloudConfigured;
  final bool cloudReady;
  final bool cloudSignedIn;
  final String? cloudEmail;
  final bool cloudAuthBusy;
  final String? cloudAuthMessage;
  final bool cloudAuthIsError;
  final KolkhozSettingsTab initialTab;
  final bool profileFeaturesEnabled;
  final VoidCallback onStart;
  final VoidCallback onTutorialPressed;
  final ValueChanged<GameAnimationSpeed>? onAnimationSpeedChanged;
  final ValueChanged<bool>? onConfirmNewGameChanged;
  final ValueChanged<bool>? onConfirmMainMenuChanged;
  final ValueChanged<bool>? onShowInvalidTapHintsChanged;
  final ValueChanged<bool>? onSoundEnabledChanged;
  final VoidCallback onLanguageToggle;
  final VoidCallback onAppearanceToggle;
  final ValueChanged<KolkhozCardBack>? onCardBackChanged;
  final ValueChanged<String>? onDisplayNameChanged;
  final ValueChanged<String>? onPortraitChanged;
  final Future<void> Function(String email, String password)? onCloudSignIn;
  final Future<void> Function(String email, String password)? onCloudSignUp;
  final Future<void> Function(String email)? onCloudResetPassword;
  final Future<void> Function()? onCloudDeleteAccount;
  final MenuRemoteConnection? menuRemoteConnection;
  final ProfileController? profileController;
  final Future<void> Function()? onStartDailyChallenge;

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  late KolkhozSettingsTab selectedTab = _effectiveTab(widget.initialTab);

  KolkhozSettingsTab _effectiveTab(KolkhozSettingsTab tab) {
    return widget.profileFeaturesEnabled ? tab : KolkhozSettingsTab.display;
  }

  @override
  void didUpdateWidget(covariant SettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab ||
        oldWidget.profileFeaturesEnabled != widget.profileFeaturesEnabled) {
      selectedTab = _effectiveTab(widget.initialTab);
    }
  }

  Widget _tabBody() {
    return switch (selectedTab) {
      KolkhozSettingsTab.profile => ProfileView(
        tokens: widget.tokens,
        language: widget.language,
        displayName: widget.displayName,
        portraitAsset: widget.portraitAsset,
        profileStats: widget.profileStats,
        progression: widget.progression,
        cloudSignedIn: widget.cloudSignedIn,
        onDisplayNameChanged: widget.onDisplayNameChanged,
        onPortraitChanged: widget.onPortraitChanged,
        onCloudDeleteAccount: widget.onCloudDeleteAccount,
        menuRemoteConnection: widget.menuRemoteConnection,
        profileController: widget.profileController,
        onStartDailyChallenge: widget.onStartDailyChallenge,
      ),
      KolkhozSettingsTab.leaderboard => LeaderboardView(
        tokens: widget.tokens,
        language: widget.language,
        profileController: widget.profileController,
        signedIn: widget.cloudSignedIn,
      ),
      KolkhozSettingsTab.progress => ProgressionOverview(
        state: widget.progression,
        tokens: widget.tokens,
      ),
      KolkhozSettingsTab.comrades =>
        widget.cloudSignedIn
            ? ComradesView(
                tokens: widget.tokens,
                language: widget.language,
                profileController: widget.profileController,
              )
            : SingleChildScrollView(
                child: CloudAuthView(
                  tokens: widget.tokens,
                  language: widget.language,
                  configured: widget.cloudConfigured,
                  ready: widget.cloudReady,
                  busy: widget.cloudAuthBusy,
                  message: widget.cloudAuthMessage,
                  messageIsError: widget.cloudAuthIsError,
                  onSignIn: widget.onCloudSignIn,
                  onSignUp: widget.onCloudSignUp,
                  onResetPassword: widget.onCloudResetPassword,
                ),
              ),
      KolkhozSettingsTab.admin => AdminOperationsView(
        tokens: widget.tokens,
        remoteConnection: widget.menuRemoteConnection,
      ),
      KolkhozSettingsTab.assist => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            OptionsSessionControls(
              tokens: widget.tokens,
              language: widget.language,
              onNewGame: widget.onStart,
              onTutorial: widget.onTutorialPressed,
              confirmNewGame: widget.confirmNewGame,
              onConfirmNewGameChanged: widget.onConfirmNewGameChanged,
              confirmMainMenu: widget.confirmMainMenu,
              onConfirmMainMenuChanged: widget.onConfirmMainMenuChanged,
            ),
            MainMenuGoldDivider(tokens: widget.tokens),
            OptionsAssistControls(
              tokens: widget.tokens,
              language: widget.language,
              showInvalidTapHints: widget.showInvalidTapHints,
              onShowInvalidTapHintsChanged: widget.onShowInvalidTapHintsChanged,
            ),
          ],
        ),
      ),
      KolkhozSettingsTab.display => SingleChildScrollView(
        child: OptionsDisplayControls(
          tokens: widget.tokens,
          language: widget.language,
          appearance: widget.appearance,
          cardBack: widget.cardBack,
          animationSpeed: widget.animationSpeed,
          soundEnabled: widget.soundEnabled,
          onSoundEnabledChanged: widget.onSoundEnabledChanged,
          onAnimationSpeedChanged: widget.onAnimationSpeedChanged,
          onLanguageToggle: widget.onLanguageToggle,
          onAppearanceToggle: widget.onAppearanceToggle,
          onCardBackChanged: widget.onCardBackChanged,
          unlockedCardBacks: widget.unlockedCardBacks,
        ),
      ),
      KolkhozSettingsTab.rules => SingleChildScrollView(
        child: OptionsMenuRules(
          tokens: widget.tokens,
          language: widget.language,
        ),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.profileFeaturesEnabled) {
      return SingleChildScrollView(
        child: OptionsDisplayControls(
          tokens: widget.tokens,
          language: widget.language,
          appearance: widget.appearance,
          animationSpeed: widget.animationSpeed,
          soundEnabled: widget.soundEnabled,
          onSoundEnabledChanged: widget.onSoundEnabledChanged,
          onAnimationSpeedChanged: widget.onAnimationSpeedChanged,
          onLanguageToggle: widget.onLanguageToggle,
          onAppearanceToggle: widget.onAppearanceToggle,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = optionsMenuTabSpacing;
            final tabWidth = math.max(
              92.0,
              (constraints.maxWidth - spacing * 4) / 5,
            );
            final tabHeight = (tabWidth * 0.30).clamp(38.0, 52.0);
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                spacing: spacing,
                children: [
                  for (final tab in KolkhozSettingsTab.values)
                    SizedBox(
                      width: tabWidth,
                      child: _SettingsTabButton(
                        tokens: widget.tokens,
                        label: tab.title(widget.language),
                        iconAsset: tab.iconAsset,
                        selected: selectedTab == tab,
                        height: tabHeight,
                        onPressed: () => setState(() => selectedTab = tab),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        MainMenuGoldDivider(tokens: widget.tokens),
        Expanded(
          child: MechanicalPanelSwitcher(
            panelKey: selectedTab,
            child: _tabBody(),
          ),
        ),
      ],
    );
  }
}

class _SettingsTabButton extends StatelessWidget {
  const _SettingsTabButton({
    required this.tokens,
    required this.label,
    required this.iconAsset,
    required this.selected,
    required this.height,
    required this.onPressed,
  });

  final DesignTokens tokens;
  final String label;
  final String iconAsset;
  final bool selected;
  final double height;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final iconSize = (height * 0.72).clamp(24.0, 38.0);
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: Tooltip(
          message: label,
          child: ChromeAssetButton(
            label: label,
            tokens: tokens,
            backgroundAsset: selected
                ? chromeButtonPrimaryAsset
                : chromeButtonSecondaryAsset,
            textColor: selected
                ? tokens.colors.onAccent
                : tokens.colors.cardInk,
            textSize: _settingsTabTextSize(height),
            onPressed: onPressed,
            iconAsset: iconAsset,
            iconSize: iconSize,
            height: height,
            padding: EdgeInsets.symmetric(
              horizontal: (height * 0.08).clamp(3.0, 6.0),
            ),
            spacing: (height * 0.08).clamp(3.0, 5.0),
            expandLabel: false,
          ),
        ),
      ),
    );
  }
}

DisplayTextSize _settingsTabTextSize(double height) {
  final targetFontSize = height * 0.58;
  if (targetFontSize <= 10.5) {
    return DisplayTextSize.small;
  }
  if (targetFontSize <= 12) {
    return DisplayTextSize.caption2;
  }
  if (targetFontSize <= 15) {
    return DisplayTextSize.caption;
  }
  if (targetFontSize <= 18.5) {
    return DisplayTextSize.headline;
  }
  return DisplayTextSize.title;
}
