import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kolkhoz_app/src/app/settings/settings.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/game_lobby.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/c_engine_bridge.dart';
import 'package:kolkhoz_app/src/app/profile/models/profile_remote_models.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/remote_game_engine/game_session_models.dart';
import 'package:kolkhoz_app/src/app/views/shared/app_text.dart';
import 'package:kolkhoz_app/src/app/views/shared/art_direction.dart';
import 'package:kolkhoz_app/src/app/views/shared/chrome_button.dart';
import 'package:kolkhoz_app/src/app/views/shared/deadline_countdown.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'package:kolkhoz_app/src/app/views/shared/field_plan_assets.dart';
import 'package:kolkhoz_app/src/app/views/shared/field_plan_typography.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_constants.dart';
import 'package:kolkhoz_app/src/app/views/shared/display_text.dart';
import 'package:kolkhoz_app/src/app/profile/views/player_profile_panel.dart';
import 'package:kolkhoz_app/src/app/views/shared/printed_underlay.dart';
import '../main_menu_view.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/remote_game_engine/remote_lobby_projection.dart';
import 'package:kolkhoz_app/src/app/views/game/views/components/board_widgets.dart';

class CreateGameView extends StatefulWidget {
  const CreateGameView({
    super.key,
    required this.tokens,
    required this.language,
    required this.selectedPreset,
    required this.customVariants,
    required this.playerControllers,
    required this.gameLobby,
    required this.demoMode,
    required this.variants,
    required this.displayName,
    required this.portraitAsset,
    required this.profileStats,
    required this.favoriteSetup,
    required this.lastStartedSetup,
    required this.comradesSummary,
    required this.compactRail,
    required this.onStart,
    required this.onHostOnline,
    this.onHostOnlineSeries,
    required this.onInviteOnlineComrades,
    required this.onComradeRequestToUser,
    required this.onRememberStartedSetup,
    required this.hostedInviteCode,
    required this.onlineSessionUpdate,
    required this.showHostedInviteCode,
    required this.onKickOnlinePlayer,
    required this.onEnterOnlineGame,
    required this.onCancelOnlineGame,
    required this.onPresetChanged,
    required this.onCustomVariantsChanged,
    required this.onPlayerControllersChanged,
    required this.onSaveFavoriteSetup,
    required this.onUseFavoriteSetup,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozGamePreset selectedPreset;
  final KolkhozGameVariants customVariants;
  final List<KolkhozPlayerController> playerControllers;
  final GameLobby? gameLobby;
  final bool demoMode;
  final KolkhozGameVariants variants;
  final String displayName;
  final String portraitAsset;
  final KolkhozProfileStats profileStats;
  final KolkhozFavoriteSetup? favoriteSetup;
  final KolkhozFavoriteSetup? lastStartedSetup;
  final OnlineComradesResponse comradesSummary;
  final bool compactRail;
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
    Uri baseURL,
    List<KolkhozPlayerController> controllers,
    bool enterImmediately,
    bool ranked,
    bool browserJoinable,
    int bestOf,
  )?
  onHostOnlineSeries;
  final Future<void> Function(String sessionID, List<String> userIDs)?
  onInviteOnlineComrades;
  final Future<void> Function(String userID)? onComradeRequestToUser;
  final void Function(
    List<KolkhozPlayerController> controllers,
    List<String> lobbySeats,
    bool browserJoinable,
  )?
  onRememberStartedSetup;
  final String? hostedInviteCode;
  final OnlineSessionUpdate? onlineSessionUpdate;
  final bool showHostedInviteCode;
  final Future<void> Function(int playerID)? onKickOnlinePlayer;
  final VoidCallback onEnterOnlineGame;
  final VoidCallback? onCancelOnlineGame;
  final ValueChanged<KolkhozGamePreset> onPresetChanged;
  final ValueChanged<KolkhozGameVariants> onCustomVariantsChanged;
  final ValueChanged<List<KolkhozPlayerController>> onPlayerControllersChanged;
  final VoidCallback? onSaveFavoriteSetup;
  final VoidCallback? onUseFavoriteSetup;

  @override
  State<CreateGameView> createState() => _VariantPanelState();
}

class _VariantPanelState extends State<CreateGameView> {
  static const setupPageKey = ValueKey('create-game-setup-page');
  static const lobbyPageKey = ValueKey('create-game-lobby-page');

  late List<_LobbySeatChoice> seatChoices;
  final Set<String> invitedLobbyComradeUserIDs = {};
  final Set<String> invitingLobbyComradeUserIDs = {};
  final seatSelectorWheelKey = GlobalKey<_SeatSelectorWheelState>();
  int? selectedSeatPlayerID;
  bool changingSelectedSeat = false;
  bool showingSeatLobby = false;
  bool startingOnline = false;
  bool browserJoinable = true;
  int bestOf = 1;
  String? onlineStatus;
  bool onlineStatusIsError = false;
  bool onlineStatusDisablesAction = false;

  @override
  void initState() {
    super.initState();
    seatChoices = _initialSeatChoices();
    browserJoinable = widget.lastStartedSetup?.browserJoinable ?? true;
    showingSeatLobby = widget.lastStartedSetup != null && !widget.demoMode;
  }

  @override
  void didUpdateWidget(covariant CreateGameView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.demoMode && !oldWidget.demoMode) {
      showingSeatLobby = false;
    }
    if (widget.lastStartedSetup != oldWidget.lastStartedSetup &&
        widget.lastStartedSetup != null &&
        !showingSeatLobby &&
        !widget.demoMode) {
      seatChoices = _initialSeatChoices();
      browserJoinable = widget.lastStartedSetup!.browserJoinable;
      showingSeatLobby = true;
    }
  }

  List<_LobbySeatChoice> _initialSeatChoices() {
    final lastStartedSetup = widget.lastStartedSetup;
    if (lastStartedSetup == null || widget.demoMode) {
      return _LobbySeatChoice.emptySetupChoices();
    }
    return _LobbySeatChoice.fromStoredValues(
      lastStartedSetup.lobbySeats,
      fallbackControllers: lastStartedSetup.controllers,
    );
  }

  List<_LobbySeatChoice> get effectiveSeatChoices {
    if (widget.demoMode) {
      return _LobbySeatChoice.fromControllers(
        KolkhozPlayerController.demoControllers,
      );
    }
    return seatChoices;
  }

  List<KolkhozPlayerController> get effectiveControllers {
    return _LobbySeatChoice.toControllers(effectiveSeatChoices);
  }

  bool get hasOnlineSeats =>
      effectiveSeatChoices.contains(_LobbySeatChoice.online) ||
      effectiveSeatChoices.contains(_LobbySeatChoice.comrade);

  bool get hasUnassignedSeats =>
      effectiveSeatChoices.contains(_LobbySeatChoice.empty);

  void setOnlineStatus(String? message) {
    onlineStatus = message;
    onlineStatusIsError = false;
    onlineStatusDisablesAction = false;
  }

  void setOnlineFailure(Object exception) {
    onlineStatus = onlineFailureStatusMessage(exception, widget.language);
    onlineStatusIsError = true;
    onlineStatusDisablesAction = false;
  }

  void setSeatChoice(int playerID, _LobbySeatChoice choice) {
    final previousChoice = effectiveSeatChoices[playerID];
    final next = List<_LobbySeatChoice>.of(effectiveSeatChoices);
    next[playerID] = choice;
    final exclusive = _LobbySeatChoice.withExclusiveHumanMode(
      next,
      changedPlayerID: playerID,
    );
    setState(() {
      seatChoices = exclusive;
      if (choice == _LobbySeatChoice.comrade) {
        browserJoinable = false;
      } else if (previousChoice == _LobbySeatChoice.comrade &&
          choice == _LobbySeatChoice.online) {
        browserJoinable = true;
      }
      setOnlineStatus(null);
    });
    widget.onPlayerControllersChanged(
      _LobbySeatChoice.toControllers(exclusive),
    );
  }

  Future<void> startGame() async {
    if (!hasOnlineSeats) {
      rememberEffectiveSetup();
      widget.onPlayerControllersChanged(effectiveControllers);
      widget.onStart();
      return;
    }
    if (startingOnline) {
      return;
    }
    setState(() {
      startingOnline = true;
      invitedLobbyComradeUserIDs.clear();
      invitingLobbyComradeUserIDs.clear();
      setOnlineStatus(null);
    });
    try {
      if (bestOf == 1 || widget.onHostOnlineSeries == null) {
        await widget.onHostOnline(
          onlineServerURL,
          effectiveControllers,
          false,
          false,
          browserJoinable,
        );
      } else {
        await widget.onHostOnlineSeries!(
          onlineServerURL,
          effectiveControllers,
          false,
          false,
          browserJoinable,
          bestOf,
        );
      }
      rememberEffectiveSetup();
    } catch (exception) {
      if (!mounted) {
        return;
      }
      setState(() {
        setOnlineFailure(exception);
      });
    } finally {
      if (mounted) {
        setState(() => startingOnline = false);
      }
    }
  }

  Future<void> inviteComradeToHostedLobby(
    String sessionID,
    String userID,
  ) async {
    if (widget.onInviteOnlineComrades == null ||
        invitedLobbyComradeUserIDs.contains(userID) ||
        invitingLobbyComradeUserIDs.contains(userID)) {
      return;
    }
    setState(() {
      invitingLobbyComradeUserIDs.add(userID);
      setOnlineStatus(null);
    });
    try {
      await widget.onInviteOnlineComrades!(sessionID, [userID]);
      if (mounted) {
        setState(() => invitedLobbyComradeUserIDs.add(userID));
      }
    } catch (exception) {
      if (mounted) {
        setState(() => setOnlineFailure(exception));
      }
    } finally {
      if (mounted) {
        setState(() => invitingLobbyComradeUserIDs.remove(userID));
      }
    }
  }

  void rememberEffectiveSetup() {
    widget.onRememberStartedSetup?.call(
      effectiveControllers,
      _LobbySeatChoice.storedValues(effectiveSeatChoices),
      browserJoinable,
    );
  }

  void useFavoriteSetup() {
    final favorite = widget.favoriteSetup;
    if (favorite == null || widget.demoMode) {
      return;
    }
    setState(() {
      seatChoices = _LobbySeatChoice.fromControllers(favorite.controllers);
      setOnlineStatus(null);
    });
    widget.onUseFavoriteSetup?.call();
  }

  Future<void> copyHostedInviteCode(String inviteCode) async {
    await Clipboard.setData(ClipboardData(text: inviteCode));
    if (!mounted) {
      return;
    }
    setState(() {
      setOnlineStatus(widget.language.strings.kolkhozappCopied);
    });
  }

  @override
  Widget build(BuildContext context) => Navigator(
    pages: [
      MaterialPage<void>(key: setupPageKey, child: _buildSetupStep()),
      if (showingSeatLobby && !widget.demoMode)
        MaterialPage<void>(key: lobbyPageKey, child: _buildLobbyStep()),
    ],
    onDidRemovePage: (page) {
      if (page.key == lobbyPageKey && showingSeatLobby) {
        setState(() => showingSeatLobby = false);
      }
    },
  );

  void showLobbyStep(bool show) {
    if (showingSeatLobby == show) {
      return;
    }
    setState(() {
      showingSeatLobby = show;
      if (!show) {
        selectedSeatPlayerID = null;
      }
    });
  }

  Future<void> toggleSeatSelector(int playerID) async {
    if (changingSelectedSeat) {
      return;
    }
    changingSelectedSeat = true;
    final previousPlayerID = selectedSeatPlayerID;
    try {
      if (previousPlayerID != null) {
        await seatSelectorWheelKey.currentState?.returnToStart();
      }
      if (!mounted) {
        return;
      }
      setState(() {
        selectedSeatPlayerID = previousPlayerID == playerID ? null : playerID;
      });
      if (previousPlayerID != playerID) {
        await WidgetsBinding.instance.endOfFrame;
        await seatSelectorWheelKey.currentState?.ratchetToSelection();
      }
    } finally {
      changingSelectedSeat = false;
    }
  }

  Widget _buildSetupStep() => _buildFieldPlanSetupStep();

  Widget _buildFieldPlanSetupStep() {
    final custom =
        widget.selectedPreset == KolkhozGamePreset.custom && !widget.demoMode;
    return PrintedPaperSurface(
      tokens: widget.tokens,
      child: Padding(
        padding: EdgeInsets.all(widget.compactRail ? 8 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: widget.compactRail ? 7 : 10,
          children: [
            _FieldPlanPresetSelector(
              tokens: widget.tokens,
              language: widget.language,
              selectedPreset: widget.selectedPreset,
              compact: widget.compactRail,
              onPresetChanged: widget.demoMode ? null : widget.onPresetChanged,
            ),
            Expanded(
              child: KolkhozScrollbar(
                tokens: widget.tokens,
                childBuilder: (context, scrollController) =>
                    SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.only(right: 8, bottom: 12),
                      child: custom
                          ? CustomVariantOptions(
                              tokens: widget.tokens,
                              language: widget.language,
                              variants: widget.customVariants,
                              compact: widget.compactRail,
                              onChanged: widget.onCustomVariantsChanged,
                            )
                          : _FieldPlanVariantLedger(
                              tokens: widget.tokens,
                              language: widget.language,
                              variants: widget.variants,
                              demoMode: widget.demoMode,
                              compact: widget.compactRail,
                            ),
                    ),
              ),
            ),
            if (widget.demoMode)
              _primaryCommandButton(
                label: widget.language.strings.kolkhozappStartDemo,
                iconAsset: 'assets/ui/Icons/icon-demo.png',
                onPressed: startGame,
              )
            else
              _setupCommandRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildLobbyStep() {
    final hostedOnlineUpdate = widget.showHostedInviteCode
        ? widget.onlineSessionUpdate
        : null;
    if (hostedOnlineUpdate != null) {
      return _buildHostedOnlineLobbyStep(hostedOnlineUpdate);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        _PresetSummaryStrip(
          tokens: widget.tokens,
          language: widget.language,
          variants: widget.variants,
          compact: widget.compactRail,
        ),
        if (onlineStatus != null &&
            (!onlineStatusIsError || !onlineStatusDisablesAction))
          OnlineStatusBanner(
            tokens: widget.tokens,
            message: onlineStatus!,
            isError: onlineStatusIsError,
          ),
        MainMenuGoldDivider(tokens: widget.tokens),
        Expanded(
          child: KolkhozScrollbar(
            tokens: widget.tokens,
            childBuilder: (context, scrollController) => SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.only(right: 10, bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 10,
                  children: [
                    _SeatLobbyEditor(
                      tokens: widget.tokens,
                      language: widget.language,
                      choices: effectiveSeatChoices,
                      displayName: widget.displayName,
                      portraitAsset: widget.portraitAsset,
                      profileStats: widget.profileStats,
                      selectedPlayerID: selectedSeatPlayerID,
                      onSeatPressed: widget.demoMode
                          ? null
                          : toggleSeatSelector,
                      compact: widget.compactRail,
                    ),
                    if (hasOnlineSeats)
                      _MatchFormatSelector(
                        tokens: widget.tokens,
                        value: bestOf,
                        enabled: true,
                        onChanged: (value) => setState(() => bestOf = value),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (selectedSeatPlayerID case final playerID?)
          _SeatSelectorWheel(
            key: seatSelectorWheelKey,
            tokens: widget.tokens,
            language: widget.language,
            playerID: playerID,
            choice: effectiveSeatChoices[playerID],
            options: _LobbySeatChoice.optionsForPlayer(playerID)
                .where(
                  (option) => _LobbySeatChoice.isOptionEnabledForPlayer(
                    playerID,
                    effectiveSeatChoices,
                    option,
                  ),
                )
                .toList(),
            compact: widget.compactRail,
            onChanged: (choice) => setSeatChoice(playerID, choice),
          ),
        _lobbyCommandRow(),
      ],
    );
  }

  Widget _lobbyCommandRow() {
    final height = widget.compactRail ? 50.0 : 56.0;
    return Row(
      spacing: 8,
      children: [
        SizedBox(
          width: widget.compactRail ? 154 : 190,
          child: _backToSetupButton(height: height),
        ),
        _OnlineGameOptionToggle(
          tokens: widget.tokens,
          title: widget.language.strings.kolkhozappAccess,
          label: browserJoinable
              ? widget.language.strings.kolkhozappBrowser
              : widget.language.strings.kolkhozappLocked,
          selected: browserJoinable,
          enabled: hasOnlineSeats,
          iconAsset: browserJoinable
              ? 'assets/art/field_plan/shared/pictograms/online.png'
              : 'assets/ui/Icons/icon-lock.png',
          onTap: () => setState(() => browserJoinable = !browserJoinable),
        ),
        Expanded(
          child: _primaryCommandButton(
            label: _startButtonLabel(),
            iconAsset: _startButtonIconAsset(),
            onPressed:
                startingOnline || _startButtonShowsBan() || hasUnassignedSeats
                ? null
                : startGame,
            enabled: !_startButtonShowsBan() && !hasUnassignedSeats,
          ),
        ),
      ],
    );
  }

  Widget _backToSetupButton({
    required double height,
    Key? key,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: height,
      child: ChromeAssetButton.command(
        key: key,
        label: widget.language.strings.kolkhozappBackToSetup,
        prominent: false,
        tokens: widget.tokens,
        iconAsset: fieldPlanToolbarUndoIconPath,
        iconSize: widget.compactRail ? 18 : 22,
        textSize: widget.compactRail
            ? DisplayTextSize.caption
            : DisplayTextSize.headline,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        expandLabel: false,
        onPressed: onPressed ?? () => showLobbyStep(false),
      ),
    );
  }

  Widget _buildHostedOnlineLobbyStep(OnlineSessionUpdate update) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        _PresetSummaryStrip(
          tokens: widget.tokens,
          language: widget.language,
          variants: widget.variants,
          compact: widget.compactRail,
          ranked: update.ranked,
        ),
        if (onlineStatus != null)
          OnlineStatusBanner(
            tokens: widget.tokens,
            message: onlineStatus!,
            isError: onlineStatusIsError,
          ),
        MainMenuGoldDivider(tokens: widget.tokens),
        if (!update.started &&
            effectiveSeatChoices.contains(_LobbySeatChoice.comrade))
          _HostedComradeInviteStrip(
            tokens: widget.tokens,
            language: widget.language,
            comrades: widget.comradesSummary.comrades,
            invitedUserIDs: invitedLobbyComradeUserIDs,
            invitingUserIDs: invitingLobbyComradeUserIDs,
            compact: widget.compactRail,
            onInvite: widget.onInviteOnlineComrades == null
                ? null
                : (userID) =>
                      inviteComradeToHostedLobby(update.sessionID, userID),
          ),
        Expanded(
          child: OnlineWaitingRoomPanel(
            tokens: widget.tokens,
            language: widget.language,
            update: update,
            lobby:
                widget.gameLobby ??
                gameLobbyFromOnlineUpdate(
                  update,
                  viewerSeatID: update.viewerID,
                ),
            inviteCode: widget.hostedInviteCode,
            onCopyInviteCode: widget.hostedInviteCode == null
                ? null
                : () =>
                      unawaited(copyHostedInviteCode(widget.hostedInviteCode!)),
            showHeaderCancel: false,
            showInviteCard: false,
            showJoinButton: false,
            showDetails: false,
            currentUserID: widget.comradesSummary.userID,
            comradeUserIDs: widget.comradesSummary.userIDs,
            incomingComradeRequestUserIDs: {
              for (final request in widget.comradesSummary.incomingRequests)
                request.userID,
            },
            outgoingComradeRequestUserIDs: {
              for (final request in widget.comradesSummary.outgoingRequests)
                request.userID,
            },
            onComradeRequestToUser: widget.onComradeRequestToUser,
            canKickPlayers: !update.started,
            onKickPlayer: widget.onKickOnlinePlayer,
            onEnterOnlineGame: widget.onEnterOnlineGame,
            onCancelOnlineGame: widget.onCancelOnlineGame,
          ),
        ),
        _hostedLobbyCommandRow(update),
      ],
    );
  }

  Widget _hostedLobbyCommandRow(OnlineSessionUpdate update) {
    final height = widget.compactRail ? 50.0 : 56.0;
    return Row(
      spacing: 8,
      children: [
        SizedBox(
          width: widget.compactRail ? 154 : 190,
          child: _backToSetupButton(
            height: height,
            key: const Key('hosted-online-back-to-setup'),
            onPressed: widget.onCancelOnlineGame ?? () => showLobbyStep(false),
          ),
        ),
        if (widget.hostedInviteCode != null)
          SizedBox(
            width: widget.compactRail ? 134 : 164,
            child: Semantics(
              button: true,
              label:
                  '${widget.language.strings.kolkhozappInviteCode} ${widget.hostedInviteCode!}',
              child: ExcludeSemantics(
                child: Tooltip(
                  message: widget.language.strings.kolkhozappCopyCode,
                  child: TactileControlSurface(
                    onPressed: () => unawaited(
                      copyHostedInviteCode(widget.hostedInviteCode!),
                    ),
                    pressTravel: 3,
                    hoverLift: -1,
                    hoverScale: 1.025,
                    child: SizedBox(
                      height: height,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const Positioned.fill(
                            child: ChromeButtonBackground(
                              asset: chromeButtonSecondaryAsset,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 9),
                            child: Row(
                              spacing: 7,
                              children: [
                                const MainMenuAssetIcon(
                                  'assets/art/field_plan/shared/pictograms/add-friend.png',
                                  size: 22,
                                ),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    spacing: 2,
                                    children: [
                                      ChromeScaledLabel(
                                        widget
                                            .language
                                            .strings
                                            .kolkhozappInviteCode,
                                        color: widget.tokens.colors.cardInk,
                                        size: DisplayTextSize.xSmall,
                                        textAlign: TextAlign.start,
                                      ),
                                      ChromeScaledLabel(
                                        widget.hostedInviteCode!,
                                        color: widget.tokens.colors.cardInk,
                                        size: DisplayTextSize.caption,
                                        textAlign: TextAlign.start,
                                      ),
                                    ],
                                  ),
                                ),
                                const MainMenuAssetIcon(
                                  fieldPlanToolbarConfirmIconPath,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          child: DeadlineCountdownBuilder(
            deadlineEpochSeconds: update.started
                ? null
                : update.lobbyCountdownEndsAt,
            serverEpochSeconds: update.serverTime,
            maxSeconds: 30,
            builder: (context, countdownSeconds) {
              final waitingLabel = countdownSeconds == null
                  ? widget.language.strings.kolkhozappWaitingForPlayers
                  : widget.language.strings.kolkhozappGameStartsInValue1s(
                      value1: countdownSeconds,
                    );
              return WaitingRoomEnterButton(
                tokens: widget.tokens,
                language: widget.language,
                tableReady: update.started,
                waitingLabel: waitingLabel,
                height: height,
                onPressed: widget.onEnterOnlineGame,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _primaryCommandButton({
    required String label,
    required String iconAsset,
    required VoidCallback? onPressed,
    bool enabled = true,
  }) {
    return SizedBox(
      height: widget.compactRail ? 50.0 : 56.0,
      child: ChromeAssetButton.command(
        width: double.infinity,
        padding: widget.compactRail
            ? const EdgeInsets.symmetric(horizontal: 8)
            : null,
        label: label,
        prominent: true,
        tokens: widget.tokens,
        onPressed: onPressed,
        enabled: enabled,
        disabledOpacity: 0.72,
        iconAsset: iconAsset,
        iconSize: widget.compactRail ? 22 : 28,
        textSize: widget.compactRail
            ? DisplayTextSize.headline
            : DisplayTextSize.title,
        expandLabel: false,
      ),
    );
  }

  Widget _setupCommandRow() {
    final height = widget.compactRail ? 50.0 : 56.0;
    final secondaryTextSize = widget.compactRail
        ? DisplayTextSize.caption
        : DisplayTextSize.headline;
    return Row(
      spacing: 8,
      children: [
        Expanded(
          child: SizedBox(
            height: height,
            child: ChromeAssetButton.command(
              label: widget.language.strings.kolkhozappSaveFavorite,
              prominent: false,
              tokens: widget.tokens,
              onPressed: widget.onSaveFavoriteSetup,
              textSize: secondaryTextSize,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              expandLabel: false,
              surfaceKey: const Key('save-favorite-setup-button'),
            ),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: height,
            child: ChromeAssetButton.command(
              label: widget.language.strings.kolkhozappUseFavorite,
              prominent: false,
              tokens: widget.tokens,
              onPressed: widget.favoriteSetup != null ? useFavoriteSetup : null,
              enabled: widget.favoriteSetup != null,
              textSize: secondaryTextSize,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              expandLabel: false,
              surfaceKey: const Key('use-favorite-setup-button'),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: height,
            child: ChromeAssetButton.command(
              width: double.infinity,
              label: widget.language.strings.kolkhozappContinueToLobby,
              prominent: true,
              tokens: widget.tokens,
              onPressed: () => showLobbyStep(true),
              iconAsset:
                  'assets/art/field_plan/shared/pictograms/add-friend.png',
              iconSize: widget.compactRail ? 22 : 28,
              textSize: widget.compactRail
                  ? DisplayTextSize.headline
                  : DisplayTextSize.title,
              padding: widget.compactRail
                  ? const EdgeInsets.symmetric(horizontal: 8)
                  : null,
              expandLabel: false,
            ),
          ),
        ),
      ],
    );
  }

  bool _startButtonShowsBan() {
    return onlineStatus != null && onlineStatusDisablesAction;
  }

  String _startButtonLabel() {
    if (_startButtonShowsBan()) {
      return onlineStatus!;
    }
    if (startingOnline) {
      return widget.language.strings.kolkhozappWorking;
    }
    if (hasOnlineSeats) {
      return widget.language.strings.kolkhozappStartOnlineGame;
    }
    return widget.language.strings.kolkhozappStartOfflineGame;
  }

  String _startButtonIconAsset() {
    if (_startButtonShowsBan()) {
      return 'assets/ui/Icons/icon-warning.png';
    }
    return fieldPlanCreateGamePictogram.fieldPlanPath;
  }
}

class _MatchFormatSelector extends StatelessWidget {
  const _MatchFormatSelector({
    required this.tokens,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final DesignTokens tokens;
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        Text(
          'MATCH FORMAT',
          style: kolkhozFontStyle.copyWith(
            color: tokens.colors.gold,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        Row(
          spacing: 8,
          children: [
            for (final option in const [
              (1, 'SINGLE', 'assets/ui/Icons/icon-match-single.png'),
              (3, 'BEST OF 3', 'assets/ui/Icons/icon-match-best-of-3.png'),
              (5, 'BEST OF 5', 'assets/ui/Icons/icon-match-best-of-5.png'),
            ])
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: ChromeAssetButton.command(
                    label: option.$2,
                    prominent: value == option.$1,
                    tokens: tokens,
                    iconAsset: option.$3,
                    iconSize: 28,
                    expandLabel: false,
                    onPressed: enabled ? () => onChanged(option.$1) : null,
                    surfaceKey: Key('match-format-${option.$1}'),
                  ),
                ),
              ),
          ],
        ),
        Text(
          value == 1
              ? 'ONE GAME'
              : 'FIRST TO ${value ~/ 2 + 1} WINS • SEATS MAY CHANGE BETWEEN GAMES',
          style: kolkhozFontStyle.copyWith(
            color: tokens.colors.creamDim,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PresetSummaryStrip extends StatelessWidget {
  const _PresetSummaryStrip({
    required this.tokens,
    required this.language,
    required this.variants,
    required this.compact,
    this.ranked,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozGameVariants variants;
  final bool compact;
  final bool? ranked;

  @override
  Widget build(BuildContext context) {
    final majorPreset = presetForVariants(variants);
    final icons = [
      if (majorPreset.iconAsset != null)
        _VariantHeaderIconData(
          label: presetTitle(majorPreset, language),
          description: VariantRowData.summaryRows(
            variants,
          ).map((row) => row.localizedTitle(language, variants)).join(' • '),
          iconAsset: majorPreset.iconAsset!,
          showLabel: true,
        ),
      for (final row in VariantRowData.summaryRows(variants))
        _VariantHeaderIconData(
          label: row.localizedTitle(language, variants),
          description: row.localizedDescription(language, variants),
          iconAsset: row.iconAssetFor(variants),
        ),
      if (ranked != null)
        _VariantHeaderIconData(
          label: language.t(
            ranked!
                ? KolkhozText.kolkhozappRanked
                : KolkhozText.kolkhozappCasual,
          ),
          iconAsset: ranked!
              ? fieldPlanMedalIconPath
              : fieldPlanHowToPlayPictogram.fieldPlanPath,
        ),
    ];
    return Align(
      alignment: Alignment.center,
      child: Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: compact ? 5 : 7,
        runSpacing: compact ? 5 : 7,
        children: [
          for (final icon in icons)
            _VariantHeaderIconChip(
              label: icon.label,
              description: icon.description,
              iconAsset: icon.iconAsset,
              showLabel: icon.showLabel,
              tokens: tokens,
              compact: compact,
            ),
        ],
      ),
    );
  }
}

class _VariantHeaderIconData {
  const _VariantHeaderIconData({
    required this.label,
    this.description = '',
    required this.iconAsset,
    this.showLabel = false,
  });

  final String label;
  final String description;
  final String iconAsset;
  final bool showLabel;
}

class _VariantHeaderIconChip extends StatelessWidget {
  const _VariantHeaderIconChip({
    required this.label,
    required this.description,
    required this.iconAsset,
    required this.showLabel,
    required this.tokens,
    required this.compact,
  });

  final String label;
  final String description;
  final String iconAsset;
  final bool showLabel;
  final DesignTokens tokens;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final width = showLabel
        ? (compact ? 128.0 : 154.0)
        : (compact ? 42.0 : 48.0);
    final height = compact ? 38.0 : 44.0;
    final iconSize = showLabel
        ? (compact ? 25.0 : 29.0)
        : (compact ? 28.0 : 33.0);
    final tooltipKey = GlobalKey<TooltipState>();
    void showTooltip() => tooltipKey.currentState?.ensureTooltipVisible();
    final tooltipText = TextSpan(
      style: kolkhozFontStyle.copyWith(
        color: tokens.colors.cardInk,
        fontSize: compact ? 13 : 14,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      children: [
        TextSpan(
          text: label.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        if (description.isNotEmpty) TextSpan(text: '\n$description'),
      ],
    );
    return Semantics(
      button: true,
      label: label,
      onTap: showTooltip,
      child: ExcludeSemantics(
        child: TactileControlSurface(
          onPressed: showTooltip,
          pressTravel: 2,
          hoverLift: -1,
          hoverScale: 1.04,
          child: Tooltip(
            key: tooltipKey,
            richMessage: tooltipText,
            triggerMode: TooltipTriggerMode.manual,
            waitDuration: const Duration(milliseconds: 250),
            showDuration: const Duration(seconds: 8),
            exitDuration: const Duration(milliseconds: 150),
            preferBelow: true,
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: tokens.colors.cardFill,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: tokens.colors.gold.withValues(alpha: 0.82),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: tokens.colors.black.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Positioned.fill(
                    child: ChromeButtonBackground(
                      asset: chromeButtonPrimaryAsset,
                    ),
                  ),
                  if (showLabel)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 8 : 10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        spacing: compact ? 5 : 7,
                        children: [
                          VariantIcon(iconAsset, size: iconSize),
                          Expanded(
                            child: ChromeScaledLabel(
                              label,
                              color: tokens.colors.onAccent,
                              size: compact
                                  ? DisplayTextSize.caption2
                                  : DisplayTextSize.caption,
                              uppercase: false,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    VariantIcon(iconAsset, size: iconSize),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldPlanPresetSelector extends StatelessWidget {
  const _FieldPlanPresetSelector({
    required this.tokens,
    required this.language,
    required this.selectedPreset,
    required this.compact,
    required this.onPresetChanged,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozGamePreset selectedPreset;
  final bool compact;
  final ValueChanged<KolkhozGamePreset>? onPresetChanged;

  ArtAssetRef _assetFor(KolkhozGamePreset preset) => switch (preset) {
    KolkhozGamePreset.kolkhoz => fieldPlanPresetKolkhoz,
    KolkhozGamePreset.littleKolkhoz => fieldPlanPresetLittleKolkhoz,
    KolkhozGamePreset.campStyle => fieldPlanPresetCampStyle,
    KolkhozGamePreset.custom => fieldPlanPresetCustom,
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 650;
        final height = compact || narrow ? 60.0 : 76.0;
        return SizedBox(
          height: narrow ? height * 2 + 6 : height,
          child: GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: narrow ? 2 : 4,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: narrow
                ? constraints.maxWidth / 2 / height
                : constraints.maxWidth / 4 / height,
            children: [
              for (final preset in betaGamePresets)
                Semantics(
                  button: true,
                  selected: selectedPreset == preset,
                  label: presetTitle(preset, language),
                  child: MechanicalSelectionSurface(
                    key: Key('field-plan-preset-${preset.name}'),
                    selected: selectedPreset == preset,
                    enabled: onPresetChanged != null,
                    onPressed: onPresetChanged == null
                        ? null
                        : () => onPresetChanged!(preset),
                    child: PrintedUnderlay(
                      tokens: tokens,
                      tone: selectedPreset == preset
                          ? PrintedUnderlayTone.primary
                          : PrintedUnderlayTone.neutral,
                      focused: selectedPreset == preset,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ArtAssetImage(
                            asset: _assetFor(preset),
                            width: compact ? 34 : 46,
                            height: compact ? 34 : 46,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              presetTitle(preset, language).toUpperCase(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: fieldPlanDisplayTextStyle.copyWith(
                                color: selectedPreset == preset
                                    ? tokens.colors.onAccent
                                    : tokens.colors.cream,
                                fontSize: compact ? 14 : 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FieldPlanVariantLedger extends StatelessWidget {
  const _FieldPlanVariantLedger({
    required this.tokens,
    required this.language,
    required this.variants,
    required this.demoMode,
    required this.compact,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozGameVariants variants;
  final bool demoMode;
  final bool compact;

  ArtAssetRef? _newAssetFor(VariantRowData row) {
    if (identical(row, VariantRowData.deckType)) {
      return fieldPlanVariantDeckFor(variants.deckType);
    }
    if (identical(row, VariantRowData.maxYears)) {
      return fieldPlanVariantFiveYearPlan;
    }
    if (identical(row, VariantRowData.allowSwap)) {
      return fieldPlanVariantSwapCards;
    }
    if (identical(row, VariantRowData.passCards)) {
      return fieldPlanVariantPassCards;
    }
    if (identical(row, VariantRowData.finalYearTrump)) {
      return fieldPlanVariantFinalYearTrump;
    }
    if (identical(row, VariantRowData.lottoRewards)) {
      return fieldPlanVariantLottoRewards;
    }
    if (identical(row, VariantRowData.managedEconomy)) {
      return fieldPlanVariantFiveYearPlanFourYears;
    }
    if (identical(row, VariantRowData.accumulateJobs)) {
      return fieldPlanVariantStakhanovite;
    }
    if (identical(row, VariantRowData.wrecker)) {
      return fieldPlanVariantSaboteur;
    }
    return null;
  }

  Widget _iconFor(VariantRowData row) {
    final newAsset = _newAssetFor(row);
    if (newAsset != null) {
      return ArtAssetImage(asset: newAsset, fit: BoxFit.contain);
    }
    return VariantIcon(row.iconAssetFor(variants), size: compact ? 42 : 56);
  }

  @override
  Widget build(BuildContext context) {
    final rows = VariantRowData.summaryRows(variants, demoMode: demoMode);
    return Column(
      spacing: compact ? 6 : 8,
      children: [
        for (var index = 0; index < rows.length; index++)
          SizedBox(
            height: compact ? 68 : 84,
            child: PrintedUnderlay(
              tokens: tokens,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 14,
                vertical: 6,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: compact ? 30 : 40,
                    child: Text(
                      '${index + 1}'.padLeft(2, '0'),
                      style: fieldPlanDisplayTextStyle.copyWith(
                        color: tokens.colors.red,
                        fontSize: compact ? 22 : 28,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: compact ? 50 : 66,
                    child: _iconFor(rows[index]),
                  ),
                  SizedBox(width: compact ? 8 : 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rows[index]
                              .localizedTitle(language, variants)
                              .toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: fieldPlanDisplayTextStyle.copyWith(
                            color: tokens.colors.cream,
                            fontSize: compact ? 17 : 23,
                          ),
                        ),
                        if (!compact &&
                            rows[index]
                                .localizedDescription(language, variants)
                                .isNotEmpty)
                          Text(
                            rows[index].localizedDescription(
                              language,
                              variants,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: fieldPlanBodyTextStyle.copyWith(
                              color: tokens.colors.creamDim,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                  PrintedSelectionStamp(size: 30, color: tokens.colors.red),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SeatLobbyEditor extends StatelessWidget {
  const _SeatLobbyEditor({
    required this.tokens,
    required this.language,
    required this.choices,
    required this.displayName,
    required this.portraitAsset,
    required this.profileStats,
    required this.selectedPlayerID,
    required this.onSeatPressed,
    required this.compact,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final List<_LobbySeatChoice> choices;
  final String displayName;
  final String portraitAsset;
  final KolkhozProfileStats profileStats;
  final int? selectedPlayerID;
  final ValueChanged<int>? onSeatPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final normalized = _LobbySeatChoice.normalized(choices);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = constraints.maxWidth >= 660 && !compact
            ? 4
            : constraints.maxWidth >= 430
            ? 2
            : 1;
        const spacing = 8.0;
        final columnWidth =
            (constraints.maxWidth - spacing * (columnCount - 1)) / columnCount;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var playerID = 0; playerID < kolkhozPlayerCount; playerID += 1)
              SizedBox(
                width: columnWidth,
                child: _SeatLobbyColumn(
                  tokens: tokens,
                  language: language,
                  playerID: playerID,
                  choice: normalized[playerID],
                  displayName: displayName,
                  portraitAsset: portraitAsset,
                  profileStats: profileStats,
                  selected: selectedPlayerID == playerID,
                  onPressed: onSeatPressed == null || playerID == 0
                      ? null
                      : () => onSeatPressed!(playerID),
                  compact: compact,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SeatLobbyColumn extends StatelessWidget {
  const _SeatLobbyColumn({
    required this.tokens,
    required this.language,
    required this.playerID,
    required this.choice,
    required this.displayName,
    required this.portraitAsset,
    required this.profileStats,
    required this.selected,
    required this.onPressed,
    required this.compact,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final int playerID;
  final _LobbySeatChoice choice;
  final String displayName;
  final String portraitAsset;
  final KolkhozProfileStats profileStats;
  final bool selected;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final playerLabel = language.strings.kolkhozappPValue1(
      value1: playerID + 1,
    );
    final localProfile = playerID == 0 && choice == _LobbySeatChoice.local;
    final occupantLabel = localProfile
        ? displayName
        : choice.shortTitle(language);
    final subtitle = localProfile
        ? profileRatingSummary(language, profileStats)
        : choice == _LobbySeatChoice.empty
        ? language.strings.kolkhozappOpen
        : choice.shortTitle(language);
    final semanticLabel = '$playerLabel $occupantLabel';
    final card = PlayerProfileBadge(
      tokens: tokens,
      displayName: occupantLabel,
      portraitAsset: localProfile
          ? portraitAsset
          : _seatPortraitAsset(playerID, choice),
      seatLabel: playerLabel,
      subtitle: subtitle,
      subtitleIconAsset: localProfile ? null : choice.iconAsset,
      portraitSize: compact ? 42 : 48,
      minHeight: compact ? 78 : 92,
      active: playerID == 0 || selected,
      muted: choice == _LobbySeatChoice.empty,
      trailing: onPressed == null
          ? null
          : Icon(
              selected ? Icons.expand_less : Icons.expand_more,
              color: selected
                  ? tokens.colors.red
                  : tokens.colors.cardInk.withValues(alpha: 0.62),
              size: compact ? 20 : 22,
            ),
    );
    return Semantics(
      button: true,
      enabled: onPressed != null,
      selected: selected,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Tooltip(
          message: semanticLabel,
          child: MechanicalSelectionSurface(
            selected: selected,
            enabled: onPressed != null,
            onPressed: onPressed,
            child: card,
          ),
        ),
      ),
    );
  }

  String _seatPortraitAsset(int playerID, _LobbySeatChoice choice) {
    if (choice == _LobbySeatChoice.empty) {
      return 'worker${playerID + 1}';
    }
    final iconAsset = choice.iconAsset;
    const prefix = 'assets/ui/';
    const suffix = '.png';
    if (iconAsset.startsWith(prefix) && iconAsset.endsWith(suffix)) {
      return iconAsset.substring(
        prefix.length,
        iconAsset.length - suffix.length,
      );
    }
    return 'worker${playerID + 1}';
  }
}

class _SeatSelectorWheel extends StatefulWidget {
  const _SeatSelectorWheel({
    super.key,
    required this.tokens,
    required this.language,
    required this.playerID,
    required this.choice,
    required this.options,
    required this.compact,
    required this.onChanged,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final int playerID;
  final _LobbySeatChoice choice;
  final List<_LobbySeatChoice> options;
  final bool compact;
  final ValueChanged<_LobbySeatChoice> onChanged;

  @override
  State<_SeatSelectorWheel> createState() => _SeatSelectorWheelState();
}

class _SeatSelectorWheelState extends State<_SeatSelectorWheel> {
  static const viewportFraction = 0.18;
  late PageController controller;
  bool returningToStart = false;
  bool ratchetingToSelection = false;
  bool snappingToWell = false;
  bool userDragging = false;
  bool userDragMoved = false;
  double? userDragStartPage;
  int? returnNotch;

  double? get currentPage =>
      controller.positions.length == 1 ? controller.page : null;
  bool get mechanicallyAnimating => returningToStart || ratchetingToSelection;

  List<_LobbySeatChoice> get slots {
    final available = widget.options.toSet();
    final ordered = <_LobbySeatChoice>[
      _LobbySeatChoice.easyAI,
      _LobbySeatChoice.mediumAI,
      _LobbySeatChoice.hardAI,
      _LobbySeatChoice.local,
      _LobbySeatChoice.comrade,
      _LobbySeatChoice.online,
    ].where(available.contains).toList();
    if (!available.contains(_LobbySeatChoice.empty)) {
      return ordered;
    }
    return [_LobbySeatChoice.empty, ...ordered, _LobbySeatChoice.empty];
  }

  @override
  void initState() {
    super.initState();
    controller = _makeController(0);
  }

  PageController _makeController(int initialPage) {
    final next = PageController(
      initialPage: initialPage,
      viewportFraction: viewportFraction,
    );
    next.addListener(_handleControllerTick);
    return next;
  }

  @override
  void didUpdateWidget(covariant _SeatSelectorWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.options, widget.options)) {
      controller.removeListener(_handleControllerTick);
      controller.dispose();
      controller = _makeController(_indexForChoice(widget.choice));
      return;
    }
  }

  int _indexForChoice(_LobbySeatChoice choice, {double? nearPage}) {
    final matches = <int>[
      for (var index = 0; index < slots.length; index += 1)
        if (slots[index] == choice) index,
    ];
    if (matches.isEmpty) {
      return 0;
    }
    if (nearPage == null) {
      return matches.first;
    }
    return matches.reduce(
      (nearest, candidate) =>
          (candidate - nearPage).abs() < (nearest - nearPage).abs()
          ? candidate
          : nearest,
    );
  }

  void _handleControllerTick() {
    if (!mechanicallyAnimating || !controller.hasClients) {
      return;
    }
    final notch = currentPage?.round();
    if (notch == null || notch == returnNotch) {
      return;
    }
    returnNotch = notch;
    unawaited(HapticFeedback.selectionClick());
  }

  Future<void> returnToStart() async {
    if (!controller.hasClients || mechanicallyAnimating) {
      return;
    }
    returningToStart = true;
    returnNotch = currentPage?.round();
    try {
      final position = controller.position;
      final notchExtent = position.viewportDimension * viewportFraction;
      final woundPixels = math.min(
        position.pixels + notchExtent * 0.14,
        position.maxScrollExtent,
      );
      unawaited(HapticFeedback.lightImpact());
      if ((woundPixels - position.pixels).abs() > 0.5) {
        await controller.animateTo(
          woundPixels,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOutCubic,
        );
      }
      final distance = (currentPage ?? 0).abs();
      await controller.animateToPage(
        0,
        duration: Duration(
          milliseconds: (240 + distance * 75).round().clamp(260, 680),
        ),
        curve: Curves.easeInCubic,
      );
      unawaited(HapticFeedback.mediumImpact());
      // Let the pointer visibly rest on the first blank slot before the
      // selector closes or begins ratcheting toward another seat.
      await Future<void>.delayed(const Duration(milliseconds: 120));
    } finally {
      returningToStart = false;
      returnNotch = null;
    }
  }

  Future<void> ratchetToSelection() async {
    if (!controller.hasClients || mechanicallyAnimating) {
      return;
    }
    final target = _indexForChoice(widget.choice, nearPage: 0);
    if (target == 0) {
      return;
    }
    ratchetingToSelection = true;
    returnNotch = currentPage?.round() ?? 0;
    try {
      unawaited(HapticFeedback.lightImpact());
      await controller.animateToPage(
        target,
        duration: Duration(milliseconds: (210 + target * 75).clamp(285, 680)),
        curve: Curves.easeOutCubic,
      );
      unawaited(HapticFeedback.mediumImpact());
    } finally {
      ratchetingToSelection = false;
      returnNotch = null;
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (mechanicallyAnimating || snappingToWell) {
      return false;
    }
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      userDragging = true;
      userDragMoved = false;
      userDragStartPage = currentPage;
      return false;
    }
    if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      userDragging = true;
      userDragStartPage ??= currentPage;
      final startPage = userDragStartPage;
      final page = currentPage;
      if ((notification.scrollDelta?.abs() ?? 0) > 0.5 ||
          (startPage != null &&
              page != null &&
              (page - startPage).abs() >= 0.04)) {
        userDragMoved = true;
      }
      return false;
    }
    if (notification is ScrollEndNotification && userDragging) {
      final shouldSnap = userDragMoved;
      userDragging = false;
      userDragMoved = false;
      userDragStartPage = null;
      if (shouldSnap) {
        unawaited(_snapToNearestWell());
      }
    }
    return false;
  }

  Future<void> _snapToNearestWell() async {
    // Let Scrollable finish dismissing its drag activity before installing the
    // short snap animation; starting it inside ScrollEndNotification is
    // immediately cancelled by the outgoing activity on some platforms.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted ||
        userDragging ||
        mechanicallyAnimating ||
        !controller.hasClients ||
        slots.isEmpty) {
      return;
    }
    final page = currentPage;
    if (page == null) {
      return;
    }
    snappingToWell = true;
    final index = page.round().clamp(0, slots.length - 1);
    final activeController = controller;
    try {
      await activeController.animateToPage(
        index,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
      );
    } finally {
      snappingToWell = false;
    }
    if (!mounted || controller != activeController || index >= slots.length) {
      return;
    }
    final option = slots[index];
    if (option != widget.choice) {
      widget.onChanged(option);
    }
  }

  void _adjustSemantics(int delta) {
    if (mechanicallyAnimating || snappingToWell || slots.isEmpty) {
      return;
    }
    final page = currentPage ?? controller.initialPage.toDouble();
    final currentIndex = _indexForChoice(widget.choice, nearPage: page);
    final targetIndex = currentIndex + delta;
    if (targetIndex < 0 || targetIndex >= slots.length) {
      return;
    }
    final option = slots[targetIndex];
    if (option != widget.choice) {
      widget.onChanged(option);
    }
    if (controller.hasClients) {
      unawaited(
        controller.animateToPage(
          targetIndex,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  @override
  void dispose() {
    controller.removeListener(_handleControllerTick);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerLabel = widget.language.strings.kolkhozappPValue1(
      value1: widget.playerID + 1,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final baseWidth = constraints.maxWidth * 0.8;
        final baseHeight = baseWidth * 760 / 1356;
        final baseLeft = (constraints.maxWidth - baseWidth) / 2;
        final wellSize = widget.compact ? 64.0 : 72.0;
        final naturalVisibleHeight = baseWidth * 0.169 + wellSize / 2;
        final trayHeight = naturalVisibleHeight.clamp(
          widget.compact ? 124.0 : 144.0,
          widget.compact ? 180.0 : 240.0,
        );
        const selectorAngle = -math.pi / 6;
        final wellRadius = baseWidth * 0.2;
        final dialCenter = Offset(constraints.maxWidth / 2, baseHeight * 0.48);
        final selectedWellCenter = Offset(
          dialCenter.dx + math.cos(selectorAngle) * wellRadius,
          dialCenter.dy + math.sin(selectorAngle) * wellRadius,
        );
        final pointerWidth = math.min(
          baseWidth * 0.126,
          widget.compact ? 83.0 : 102.0,
        );
        final pointerHeight = pointerWidth * 508 / 680;
        final pointerTip =
            selectedWellCenter +
            Offset(math.cos(selectorAngle), math.sin(selectorAngle)) *
                (wellSize * 0.23);
        // A compact, finite pitch keeps the wells grouped like a telephone
        // dial while the blank end stops make its open range apparent.
        const angleStep = math.pi / 6.5;
        final semanticPage = currentPage ?? controller.initialPage.toDouble();
        final semanticIndex = _indexForChoice(
          widget.choice,
          nearPage: semanticPage,
        );
        final previousOption = semanticIndex > 0
            ? slots[semanticIndex - 1]
            : null;
        final nextOption = semanticIndex < slots.length - 1
            ? slots[semanticIndex + 1]
            : null;
        final semanticLabel = widget.language == KolkhozLanguage.en
            ? '$playerLabel controller'
            : '$playerLabel контроллер';
        return SizedBox(
          height: trayHeight,
          child: ClipRect(
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  left: baseLeft,
                  top: 0,
                  width: baseWidth,
                  height: baseHeight,
                  child: Image.asset(
                    'assets/art/field_plan/shared/controls/'
                    'rotary-seat-selector-base-v2.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: controller,
                      builder: (context, _) {
                        final currentPage = controller.hasClients
                            ? this.currentPage ??
                                  _indexForChoice(widget.choice).toDouble()
                            : _indexForChoice(widget.choice).toDouble();
                        final indices =
                            List<int>.generate(slots.length, (index) => index)
                              ..sort((a, b) {
                                final aDistance = (a - currentPage).abs();
                                final bDistance = (b - currentPage).abs();
                                return bDistance.compareTo(aDistance);
                              });
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (final index in indices)
                              _positionedRotaryOption(
                                index: index,
                                option: slots[index],
                                currentPage: currentPage,
                                dialCenter: dialCenter,
                                radius: wellRadius,
                                selectorAngle: selectorAngle,
                                angleStep: angleStep,
                                wellSize: wellSize,
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  left: pointerTip.dx - pointerWidth * 0.03,
                  top: pointerTip.dy - pointerHeight * 0.92,
                  width: pointerWidth,
                  height: pointerHeight,
                  child: IgnorePointer(
                    child: Image.asset(
                      'assets/art/field_plan/shared/controls/'
                      'rotary-seat-selector-pointer-v2.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Semantics(
                    key: ValueKey(
                      'seat-selector-accessibility-${widget.playerID + 1}',
                    ),
                    container: true,
                    label: semanticLabel,
                    value: slots[semanticIndex].shortTitle(widget.language),
                    decreasedValue: previousOption?.shortTitle(widget.language),
                    increasedValue: nextOption?.shortTitle(widget.language),
                    onDecrease: previousOption == null
                        ? null
                        : () => _adjustSemantics(-1),
                    onIncrease: nextOption == null
                        ? null
                        : () => _adjustSemantics(1),
                    child: ExcludeSemantics(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: _handleScrollNotification,
                        child: PageView.builder(
                          key: ValueKey(
                            'seat-selector-wheel-${widget.playerID + 1}',
                          ),
                          controller: controller,
                          padEnds: true,
                          pageSnapping: false,
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          itemCount: slots.length,
                          itemBuilder: (context, index) =>
                              const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _positionedRotaryOption({
    required int index,
    required _LobbySeatChoice option,
    required double currentPage,
    required Offset dialCenter,
    required double radius,
    required double selectorAngle,
    required double angleStep,
    required double wellSize,
  }) {
    if (option == _LobbySeatChoice.empty) {
      return const SizedBox.shrink();
    }
    final pageOffset = index - currentPage;
    final distance = pageOffset.abs();
    final angle = selectorAngle + pageOffset * angleStep;
    final center = Offset(
      dialCenter.dx + math.cos(angle) * radius,
      dialCenter.dy + math.sin(angle) * radius,
    );
    final opacity = (1 - distance * 0.22).clamp(0.2, 1.0);
    final scale = (1 - distance * 0.06).clamp(0.78, 1.0);
    final label = option.shortTitle(widget.language);
    return Positioned(
      left: center.dx - wellSize / 2,
      top: center.dy - wellSize / 2,
      width: wellSize,
      height: wellSize,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: _RotarySeatWell(
            tokens: widget.tokens,
            iconAsset: option.iconAsset,
            selected: distance < 0.5,
            label: label,
            compact: widget.compact,
          ),
        ),
      ),
    );
  }
}

class _RotarySeatWell extends StatelessWidget {
  const _RotarySeatWell({
    required this.tokens,
    required this.iconAsset,
    required this.selected,
    required this.label,
    required this.compact,
  });

  final DesignTokens tokens;
  final String iconAsset;
  final bool selected;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected
                ? tokens.colors.red
                : tokens.colors.cardInk.withValues(alpha: 0.94),
            border: Border.all(
              color: selected ? tokens.colors.cream : tokens.colors.gold,
              width: selected ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: tokens.colors.cardInk.withValues(alpha: 0.45),
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 7, 6, 5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MainMenuAssetIcon(
                  iconAsset,
                  size: compact ? 25 : 28,
                  opacity: selected ? 1 : 0.82,
                ),
                const SizedBox(height: 1),
                Expanded(
                  child: ChromeScaledLabel(
                    label,
                    color: selected ? tokens.colors.cream : tokens.colors.gold,
                    size: DisplayTextSize.caption2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HostedComradeInviteStrip extends StatelessWidget {
  const _HostedComradeInviteStrip({
    required this.tokens,
    required this.language,
    required this.comrades,
    required this.invitedUserIDs,
    required this.invitingUserIDs,
    required this.compact,
    required this.onInvite,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final List<OnlineComradeProfile> comrades;
  final Set<String> invitedUserIDs;
  final Set<String> invitingUserIDs;
  final bool compact;
  final Future<void> Function(String userID)? onInvite;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 48 : 56,
      child: Row(
        spacing: 8,
        children: [
          MainMenuAssetIcon(
            'assets/art/field_plan/shared/pictograms/comrade.png',
            size: compact ? 22 : 26,
          ),
          ChromeScaledLabel(
            language.strings.kolkhozappComrades,
            color: tokens.colors.cardInk,
            size: compact ? DisplayTextSize.caption2 : DisplayTextSize.caption,
          ),
          Expanded(
            child: comrades.isEmpty
                ? ChromeScaledLabel(
                    language.strings.kolkhozappNoComrades,
                    color: tokens.colors.cardInk.withValues(alpha: 0.62),
                    size: DisplayTextSize.caption2,
                    textAlign: TextAlign.start,
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: comrades.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final comrade = comrades[index];
                      final invited = invitedUserIDs.contains(comrade.userID);
                      final inviting = invitingUserIDs.contains(comrade.userID);
                      final enabled = onInvite != null && !invited && !inviting;
                      final actionLabel = invited || inviting
                          ? language.strings.kolkhozappPending
                          : language.strings.kolkhozappGameInvite;
                      final semanticLabel =
                          '${comrade.displayLabel} $actionLabel';
                      return Semantics(
                        button: true,
                        enabled: enabled,
                        label: semanticLabel,
                        child: ExcludeSemantics(
                          child: Tooltip(
                            message: semanticLabel,
                            child: Opacity(
                              opacity: enabled ? 1 : 0.64,
                              child: TactileControlSurface(
                                key: ValueKey(
                                  'hosted-comrade-invite-${comrade.userID}',
                                ),
                                enabled: enabled,
                                onPressed: enabled
                                    ? () => unawaited(onInvite!(comrade.userID))
                                    : null,
                                pressTravel: 3,
                                hoverLift: -1,
                                hoverScale: 1.025,
                                child: SizedBox(
                                  width: compact ? 132 : 154,
                                  child: VariantRowBackground(
                                    tokens: tokens,
                                    active: invited || inviting,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 5,
                                    ),
                                    child: Row(
                                      spacing: 7,
                                      children: [
                                        PlayerProfilePortraitImage(
                                          tokens: tokens,
                                          asset:
                                              comrade.portraitAsset ??
                                              defaultProfilePortraitAsset,
                                          size: compact ? 28 : 32,
                                          selected: invited || inviting,
                                        ),
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            spacing: 1,
                                            children: [
                                              ChromeScaledLabel(
                                                comrade.displayLabel,
                                                color: tokens.colors.cardInk,
                                                size: DisplayTextSize.caption2,
                                                textAlign: TextAlign.start,
                                              ),
                                              ChromeScaledLabel(
                                                actionLabel,
                                                color: tokens.colors.cardInk
                                                    .withValues(alpha: 0.66),
                                                size: DisplayTextSize.xSmall,
                                                textAlign: TextAlign.start,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
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

class _OnlineGameOptionToggle extends StatelessWidget {
  const _OnlineGameOptionToggle({
    required this.tokens,
    required this.title,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.iconAsset,
    required this.onTap,
  });

  final DesignTokens tokens;
  final String title;
  final String label;
  final bool selected;
  final bool enabled;
  final String iconAsset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? tokens.colors.activeSurfaceText
        : tokens.colors.cardInk;
    return Semantics(
      button: true,
      enabled: enabled,
      toggled: selected,
      label: label,
      child: ExcludeSemantics(
        child: Tooltip(
          message: label,
          child: Opacity(
            opacity: enabled ? 1 : 0.58,
            child: MechanicalSelectionSurface(
              selected: selected,
              enabled: enabled,
              onPressed: enabled ? onTap : null,
              child: SizedBox(
                width: 138,
                height: 62,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: ChromeButtonBackground(
                        asset: selected
                            ? chromeButtonPrimaryAsset
                            : chromeButtonSecondaryAsset,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 7),
                      child: Row(
                        spacing: 8,
                        children: [
                          MainMenuAssetIcon(
                            iconAsset,
                            size: 30,
                            opacity: selected ? 1 : 0.82,
                          ),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              spacing: 2,
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  height: 13,
                                  child: ChromeScaledLabel(
                                    title,
                                    color: foreground.withValues(alpha: 0.68),
                                    size: DisplayTextSize.caption2,
                                  ),
                                ),
                                SizedBox(
                                  width: double.infinity,
                                  height: 18,
                                  child: ChromeScaledLabel(
                                    label,
                                    color: foreground,
                                    size: DisplayTextSize.caption,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _LobbySeatChoice {
  empty,
  local,
  online,
  comrade,
  easyAI,
  mediumAI,
  hardAI;

  static List<_LobbySeatChoice> emptySetupChoices() {
    return const [
      _LobbySeatChoice.local,
      _LobbySeatChoice.empty,
      _LobbySeatChoice.empty,
      _LobbySeatChoice.empty,
    ];
  }

  static List<_LobbySeatChoice> fromControllers(
    List<KolkhozPlayerController> controllers,
  ) {
    final normalized = KolkhozPlayerController.normalized(controllers);
    return [for (final controller in normalized) fromController(controller)];
  }

  static List<_LobbySeatChoice> fromStoredValues(
    List<String> values, {
    required List<KolkhozPlayerController> fallbackControllers,
  }) {
    if (values.isEmpty) {
      return fromControllers(fallbackControllers);
    }
    try {
      return withExclusiveHumanMode(
        normalized([
          for (final value in values)
            _LobbySeatChoice.values.firstWhere(
              (choice) => choice.name == value,
            ),
        ]),
      );
    } catch (_) {
      return fromControllers(fallbackControllers);
    }
  }

  static _LobbySeatChoice fromController(KolkhozPlayerController controller) {
    return switch (controller) {
      KolkhozPlayerController.human => _LobbySeatChoice.local,
      KolkhozPlayerController.heuristicAI => _LobbySeatChoice.easyAI,
      KolkhozPlayerController.mediumAI => _LobbySeatChoice.mediumAI,
      KolkhozPlayerController.neuralAI => _LobbySeatChoice.hardAI,
    };
  }

  static List<_LobbySeatChoice> normalized(List<_LobbySeatChoice> choices) {
    final normalized = List<_LobbySeatChoice>.generate(
      kolkhozPlayerCount,
      (index) => index < choices.length
          ? choices[index]
          : fromController(KolkhozPlayerController.defaultControllers[index]),
    );
    if (normalized.first == _LobbySeatChoice.empty ||
        normalized.first == _LobbySeatChoice.online ||
        normalized.first == _LobbySeatChoice.comrade) {
      normalized[0] = _LobbySeatChoice.local;
    }
    if (!normalized.any((choice) => choice == _LobbySeatChoice.local)) {
      normalized[0] = _LobbySeatChoice.local;
    }
    return normalized;
  }

  static List<_LobbySeatChoice> optionsForPlayer(int playerID) {
    if (playerID == 0) {
      return const [local];
    }
    return const [
      _LobbySeatChoice.empty,
      _LobbySeatChoice.easyAI,
      _LobbySeatChoice.mediumAI,
      _LobbySeatChoice.hardAI,
      _LobbySeatChoice.local,
      _LobbySeatChoice.comrade,
      _LobbySeatChoice.online,
    ];
  }

  static bool isOptionEnabledForPlayer(
    int playerID,
    List<_LobbySeatChoice> choices,
    _LobbySeatChoice option,
  ) {
    if (playerID == 0) {
      return option == _LobbySeatChoice.local;
    }
    if (option != _LobbySeatChoice.local &&
        option != _LobbySeatChoice.online &&
        option != _LobbySeatChoice.comrade) {
      return true;
    }
    final normalized = _LobbySeatChoice.normalized(choices);
    final otherSeats = [
      for (var index = 1; index < kolkhozPlayerCount; index += 1)
        if (index != playerID) normalized[index],
    ];
    if (option == _LobbySeatChoice.local) {
      return !otherSeats.contains(_LobbySeatChoice.online);
    }
    return !otherSeats.contains(_LobbySeatChoice.local);
  }

  static List<_LobbySeatChoice> withExclusiveHumanMode(
    List<_LobbySeatChoice> choices, {
    int? changedPlayerID,
  }) {
    final normalized = _LobbySeatChoice.normalized(choices);
    var chosenHumanMode = _LobbySeatChoice.local;
    if (changedPlayerID != null &&
        changedPlayerID > 0 &&
        changedPlayerID < kolkhozPlayerCount &&
        normalized[changedPlayerID].isHumanSeat) {
      chosenHumanMode = normalized[changedPlayerID];
    } else {
      for (var index = 1; index < kolkhozPlayerCount; index += 1) {
        if (normalized[index].isHumanSeat) {
          chosenHumanMode = normalized[index];
        }
      }
    }
    for (var index = 1; index < kolkhozPlayerCount; index += 1) {
      final choice = normalized[index];
      final incompatible =
          (choice == _LobbySeatChoice.online &&
              chosenHumanMode == _LobbySeatChoice.local) ||
          (choice == _LobbySeatChoice.comrade &&
              chosenHumanMode == _LobbySeatChoice.local) ||
          (choice == _LobbySeatChoice.local &&
              (chosenHumanMode == _LobbySeatChoice.online ||
                  chosenHumanMode == _LobbySeatChoice.comrade)) ||
          (choice == _LobbySeatChoice.online &&
              chosenHumanMode == _LobbySeatChoice.comrade) ||
          (choice == _LobbySeatChoice.comrade &&
              chosenHumanMode == _LobbySeatChoice.online);
      if (incompatible) {
        normalized[index] = _LobbySeatChoice.empty;
      }
    }
    return normalized;
  }

  static List<KolkhozPlayerController> toControllers(
    List<_LobbySeatChoice> choices,
  ) {
    return KolkhozPlayerController.normalized([
      for (final choice in normalized(choices)) choice.controller,
    ]);
  }

  static List<String> storedValues(List<_LobbySeatChoice> choices) {
    return [for (final choice in normalized(choices)) choice.name];
  }

  bool get isHumanSeat {
    return this == _LobbySeatChoice.local ||
        this == _LobbySeatChoice.online ||
        this == _LobbySeatChoice.comrade;
  }

  KolkhozPlayerController get controller {
    return switch (this) {
      _LobbySeatChoice.empty => KolkhozPlayerController.neuralAI,
      _LobbySeatChoice.local ||
      _LobbySeatChoice.online ||
      _LobbySeatChoice.comrade => KolkhozPlayerController.human,
      _LobbySeatChoice.easyAI => KolkhozPlayerController.heuristicAI,
      _LobbySeatChoice.mediumAI => KolkhozPlayerController.mediumAI,
      _LobbySeatChoice.hardAI => KolkhozPlayerController.neuralAI,
    };
  }

  String shortTitle(KolkhozLanguage language) {
    return switch (this) {
      _LobbySeatChoice.empty => language.strings.kolkhozappOpen,
      _LobbySeatChoice.local => language.strings.kolkhozappHotseat,
      _LobbySeatChoice.online => language.strings.kolkhozappOnline,
      _LobbySeatChoice.comrade => language.strings.kolkhozappComrade,
      _LobbySeatChoice.easyAI => KolkhozPlayerController.heuristicAI.shortTitle(
        language,
      ),
      _LobbySeatChoice.mediumAI => KolkhozPlayerController.mediumAI.shortTitle(
        language,
      ),
      _LobbySeatChoice.hardAI => KolkhozPlayerController.neuralAI.shortTitle(
        language,
      ),
    };
  }

  String get iconAsset {
    return switch (this) {
      _LobbySeatChoice.empty =>
        'assets/art/field_plan/shared/pictograms/human-seat.png',
      _LobbySeatChoice.local =>
        'assets/art/field_plan/shared/pictograms/controller-hotseat-player.png',
      _LobbySeatChoice.online =>
        'assets/art/field_plan/shared/pictograms/controller-online-player.png',
      _LobbySeatChoice.comrade =>
        'assets/art/field_plan/shared/pictograms/comrade.png',
      _LobbySeatChoice.easyAI =>
        'assets/art/field_plan/shared/pictograms/controller-easy-ai.png',
      _LobbySeatChoice.mediumAI =>
        'assets/art/field_plan/shared/pictograms/controller-medium-ai.png',
      _LobbySeatChoice.hardAI =>
        'assets/art/field_plan/shared/pictograms/controller-hard-ai.png',
    };
  }
}

class ImageTabButton extends StatelessWidget {
  const ImageTabButton({
    super.key,
    required this.tokens,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.iconAsset,
    this.iconSize = 18,
    this.height = 48,
    this.textSize = DisplayTextSize.caption,
    this.horizontalPadding,
    this.contentSpacing = 8,
  });

  final DesignTokens tokens;
  final String label;
  final bool selected;
  final VoidCallback? onPressed;
  final String? iconAsset;
  final double iconSize;
  final double height;
  final DisplayTextSize textSize;
  final double? horizontalPadding;
  final double contentSpacing;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final active = selected && enabled;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: ChromeAssetButton(
          label: enabled ? label : '',
          backgroundAsset: active
              ? chromeButtonPrimaryAsset
              : chromeButtonSecondaryAsset,
          tokens: tokens,
          textColor: active
              ? tokens.colors.onAccent
              : tokens.colors.cardInk.withValues(alpha: enabled ? 1 : 0.58),
          textSize: textSize,
          onPressed: onPressed,
          iconAsset: enabled ? iconAsset : 'assets/ui/Icons/icon-lock.png',
          iconSize: iconSize,
          height: height,
          padding: EdgeInsets.fromLTRB(
            enabled && iconAsset == null ? 10 : horizontalPadding ?? 14,
            3,
            horizontalPadding == null ? 10 : horizontalPadding!,
            0,
          ),
          spacing: enabled ? contentSpacing : 0,
          expandLabel: false,
          uppercase: enabled,
          enabled: enabled,
          disabledOpacity: 0.56,
          boxShadow: active
              ? [
                  BoxShadow(
                    color: tokens.colors.gold.withValues(alpha: 0.18),
                    blurRadius: 5,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}
