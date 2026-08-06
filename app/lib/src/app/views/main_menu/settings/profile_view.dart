part of 'settings_view.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({
    super.key,
    required this.tokens,
    required this.language,
    required this.displayName,
    required this.portraitAsset,
    required this.profileStats,
    required this.progression,
    required this.cloudSignedIn,
    required this.onDisplayNameChanged,
    required this.onPortraitChanged,
    required this.onCloudDeleteAccount,
    required this.menuRemoteConnection,
    required this.profileController,
    required this.onStartDailyChallenge,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final String displayName;
  final String portraitAsset;
  final KolkhozProfileStats profileStats;
  final ProgressionState progression;
  final bool cloudSignedIn;
  final ValueChanged<String>? onDisplayNameChanged;
  final ValueChanged<String>? onPortraitChanged;
  final Future<void> Function()? onCloudDeleteAccount;
  final MenuRemoteConnection? menuRemoteConnection;
  final ProfileController? profileController;
  final Future<void> Function()? onStartDailyChallenge;

  @override
  State<ProfileView> createState() => _ProfilePanelState();
}

class _ProfilePanelState extends State<ProfileView> {
  late final TextEditingController displayNameController;
  late String lastSubmittedName;
  OnlineDailyChallenge? dailyChallenge;
  bool dailyLoading = false;

  List<OnlineRecentGame> get recentGames =>
      widget.profileController?.recentGames ?? const [];
  bool get recentGamesLoading =>
      widget.profileController?.recentGamesBusy ?? false;
  Object? get recentGamesError => widget.profileController?.recentGamesError;

  @override
  void initState() {
    super.initState();
    lastSubmittedName = widget.displayName;
    displayNameController = TextEditingController(text: widget.displayName);
    displayNameController.addListener(notifyDisplayNameChanged);
    widget.profileController?.addListener(_handleProfileChanged);
    if (widget.cloudSignedIn) _scheduleCloudLoads();
  }

  Future<void> loadDailyChallenge() async {
    final connection = widget.menuRemoteConnection;
    if (connection == null) return;
    setState(() => dailyLoading = true);
    try {
      final value = await connection.fetchDailyChallenge();
      if (mounted) setState(() => dailyChallenge = value);
    } catch (_) {
      // Profile history remains usable when the optional challenge is offline.
    } finally {
      if (mounted) setState(() => dailyLoading = false);
    }
  }

  Future<void> loadRecentGames() async {
    await widget.profileController?.loadRecentGames();
  }

  void _scheduleCloudLoads() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.cloudSignedIn) return;
      unawaited(loadRecentGames());
      if (KolkhozIdentityRuntime.instance.player?.portable == true) {
        unawaited(loadDailyChallenge());
      }
    });
  }

  @override
  void didUpdateWidget(covariant ProfileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileController != widget.profileController) {
      oldWidget.profileController?.removeListener(_handleProfileChanged);
      widget.profileController?.addListener(_handleProfileChanged);
    }
    if (!oldWidget.cloudSignedIn && widget.cloudSignedIn) {
      _scheduleCloudLoads();
    }
    if (widget.displayName != lastSubmittedName &&
        widget.displayName != displayNameController.text) {
      displayNameController.text = widget.displayName;
      lastSubmittedName = widget.displayName;
    }
  }

  @override
  void dispose() {
    widget.profileController?.removeListener(_handleProfileChanged);
    displayNameController.removeListener(notifyDisplayNameChanged);
    displayNameController.dispose();
    super.dispose();
  }

  void _handleProfileChanged() {
    if (mounted) setState(() {});
  }

  void notifyDisplayNameChanged() {
    final next = displayNameController.text;
    if (next == lastSubmittedName) {
      return;
    }
    lastSubmittedName = next;
    widget.onDisplayNameChanged?.call(next);
  }

  Future<void> showPortraitPicker() async {
    if (widget.onPortraitChanged == null) {
      return;
    }
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.tokens.colors.panel,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.tokens.colors.gold.withValues(alpha: 0.72),
            ),
            boxShadow: [
              BoxShadow(
                color: widget.tokens.colors.black.withValues(alpha: 0.42),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final asset in profilePortraitAssets)
                _ProfilePortraitChoice(
                  tokens: widget.tokens,
                  asset: asset,
                  selected: widget.portraitAsset == asset,
                  unlocked: isProfilePortraitUnlocked(
                    widget.progression,
                    asset,
                  ),
                  onPressed:
                      isProfilePortraitUnlocked(widget.progression, asset)
                      ? () => Navigator.of(context).pop(asset)
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && selected != widget.portraitAsset) {
      widget.onPortraitChanged?.call(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                if (widget.cloudSignedIn) ...[
                  PlayerProfilePanel(
                    tokens: widget.tokens,
                    displayName: displayNameController.text.trim().isEmpty
                        ? defaultProfileDisplayName
                        : displayNameController.text.trim(),
                    portraitAsset: widget.portraitAsset,
                    active: true,
                    portraitSelected: true,
                    portraitSize: 74,
                    minHeight: 94,
                    padding: const EdgeInsets.all(10),
                    onPortraitPressed: widget.onPortraitChanged == null
                        ? null
                        : showPortraitPicker,
                    portraitSemanticsLabel: widget.portraitAsset,
                    title: TextField(
                      controller: displayNameController,
                      enabled: widget.onDisplayNameChanged != null,
                      maxLength: 24,
                      minLines: 1,
                      maxLines: 1,
                      style: kolkhozFontStyle.copyWith(
                        color: widget.tokens.colors.cream,
                        fontSize: 28,
                        height: 1.0,
                        fontWeight: FontWeight.w700,
                      ),
                      cursorColor: widget.tokens.colors.goldBright,
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: defaultProfileDisplayName,
                        hintStyle: kolkhozFontStyle.copyWith(
                          color: widget.tokens.colors.creamDim.withValues(
                            alpha: 0.74,
                          ),
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                        border: InputBorder.none,
                        isCollapsed: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 8,
                    children: [
                      Text(
                        widget.language.strings.kolkhozappStats,
                        style: kolkhozFontStyle.copyWith(
                          color: widget.tokens.colors.gold,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columnCount = constraints.maxWidth >= 520
                              ? 3
                              : 1;
                          return PlayerProfileStatsGrid(
                            tokens: widget.tokens,
                            groups: kolkhozProfileStatGroups(
                              stats: widget.profileStats,
                              language: widget.language,
                            ),
                            columnsForWidth: (_) => columnCount,
                          );
                        },
                      ),
                      _RecentGamesPanel(
                        tokens: widget.tokens,
                        language: widget.language,
                        games: recentGames,
                        loading: recentGamesLoading,
                        error: recentGamesError,
                        onRetry: loadRecentGames,
                        profileController: widget.profileController,
                      ),
                      if (KolkhozIdentityRuntime.instance.player?.portable ==
                          true)
                        _DailyChallengePanel(
                          tokens: widget.tokens,
                          language: widget.language,
                          challenge: dailyChallenge,
                          loading: dailyLoading,
                          onPlay: widget.onStartDailyChallenge,
                        ),
                    ],
                  ),
                ],
                PlayerIdentityPanel(
                  tokens: widget.tokens,
                  displayName: widget.displayName,
                  onDeleteAccount: widget.onCloudDeleteAccount,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentGamesPanel extends StatelessWidget {
  const _RecentGamesPanel({
    required this.tokens,
    required this.language,
    required this.games,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.profileController,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final List<OnlineRecentGame> games;
  final bool loading;
  final Object? error;
  final VoidCallback onRetry;
  final ProfileController? profileController;

  String placement(int rank) => switch (rank) {
    1 => language.strings.profileFirstPlace,
    2 => language.strings.profileSecondPlace,
    3 => language.strings.profileThirdPlace,
    _ => language.strings.profileOtherPlace(rank: rank),
  };

  String date(double seconds) {
    final value = DateTime.fromMillisecondsSinceEpoch(
      (seconds * 1000).round(),
    ).toLocal();
    if (language == KolkhozLanguage.ru) {
      final day = value.day.toString().padLeft(2, '0');
      final month = value.month.toString().padLeft(2, '0');
      return '$day.$month.${value.year}';
    }
    return '${value.month}/${value.day}/${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 7,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                language.strings.profileRecentGames,
                style: kolkhozFontStyle.copyWith(
                  color: tokens.colors.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (error != null)
              TactileTextButton(
                onPressed: onRetry,
                child: Text(language.strings.profileRetry),
              ),
          ],
        ),
        if (loading)
          const LinearProgressIndicator(minHeight: 2)
        else if (error != null)
          Text(
            language.strings.profileRecentResultsUnavailable,
            style: kolkhozFontStyle.copyWith(color: tokens.colors.creamDim),
          )
        else if (games.isEmpty)
          Text(
            language.strings.profileNoCompletedOnlineGames,
            style: kolkhozFontStyle.copyWith(color: tokens.colors.creamDim),
          )
        else
          for (final game in games)
            TactileButton(
              enabled: profileController != null,
              onPressed: profileController == null
                  ? null
                  : () => showDialog<void>(
                      context: context,
                      builder: (context) => _ReplayDialog(
                        tokens: tokens,
                        language: language,
                        replay: profileController!.fetchReplay(game.sessionID),
                      ),
                    ),
              child: Container(
                key: Key('recent-game-${game.sessionID}'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: tokens.colors.black.withValues(alpha: 0.22),
                  border: Border.all(
                    color: game.won
                        ? tokens.colors.gold.withValues(alpha: 0.7)
                        : tokens.colors.creamDim.withValues(alpha: 0.25),
                  ),
                  borderRadius: BorderRadius.circular(tokens.radius.sm),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: language == KolkhozLanguage.ru ? 72 : 48,
                      child: Text(
                        game.won
                            ? language.strings.profileWin
                            : placement(game.rank),
                        style: kolkhozFontStyle.copyWith(
                          color: game.won
                              ? tokens.colors.goldBright
                              : tokens.colors.cream,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${language.strings.profilePoints(score: game.score)}  •  '
                        '${(game.ranked ? language.strings.kolkhozappRanked : language.strings.kolkhozappCasual).toUpperCase()}',
                        style: kolkhozFontStyle.copyWith(
                          color: tokens.colors.cream,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      date(game.completedAt),
                      style: kolkhozFontStyle.copyWith(
                        color: tokens.colors.creamDim,
                        fontSize: 11,
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

class _DailyChallengePanel extends StatelessWidget {
  const _DailyChallengePanel({
    required this.tokens,
    required this.language,
    required this.challenge,
    required this.loading,
    required this.onPlay,
  });
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final OnlineDailyChallenge? challenge;
  final bool loading;
  final Future<void> Function()? onPlay;

  @override
  Widget build(BuildContext context) {
    final value = challenge;
    return Container(
      key: const Key('daily-collective-challenge'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tokens.colors.gold.withValues(alpha: 0.1),
        border: Border.all(color: tokens.colors.gold.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(tokens.radius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          Text(
            language.strings.profileDailyChallenge,
            style: kolkhozFontStyle.copyWith(
              color: tokens.colors.goldBright,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (loading)
            const LinearProgressIndicator(minHeight: 2)
          else ...[
            Text(
              value?.bestScore == null
                  ? language.strings.profileDailyChallengeDescription
                  : language.strings.profilePersonalBest(
                      score: value!.bestScore!,
                    ),
              style: kolkhozFontStyle.copyWith(color: tokens.colors.cream),
            ),
            if (value != null && value.leaders.isNotEmpty)
              Text(
                language.strings.profileLeader(
                  name: value.leaders.first.displayName,
                  score: value.leaders.first.score,
                ),
                style: kolkhozFontStyle.copyWith(color: tokens.colors.creamDim),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TactileTextButton(
                key: const Key('daily-challenge-play-button'),
                onPressed: onPlay == null ? null : () => onPlay!(),
                child: Text(
                  value?.bestScore == null
                      ? language.strings.profilePlay
                      : language.strings.profilePlayAgain,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReplayDialog extends StatefulWidget {
  const _ReplayDialog({
    required this.tokens,
    required this.language,
    required this.replay,
  });
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final Future<OnlineGameReplay> replay;
  @override
  State<_ReplayDialog> createState() => _ReplayDialogState();
}

class _ReplayDialogState extends State<_ReplayDialog> {
  int revision = 0;

  String actionLabel(OnlineReplayEvent event) {
    final action = event.action;
    return [
      'R${event.revision}',
      widget.language.strings.profileAction(kind: action.kind.toString()),
      'P${action.playerID + 1}',
      if (action.card.isValid) '${action.card.suit}-${action.card.value}',
    ].join('  ');
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: widget.tokens.colors.panel,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680, maxHeight: 640),
      child: FutureBuilder<OnlineGameReplay>(
        future: widget.replay,
        builder: (context, snapshot) {
          final replay = snapshot.data;
          if (replay == null) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            );
          }
          final events = replay.events;
          final selected = events.isEmpty
              ? null
              : events[revision.clamp(0, events.length - 1)];
          return Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                Text(
                  widget.language.strings.profileMatchReplay,
                  style: kolkhozFontStyle.copyWith(
                    color: widget.tokens.colors.goldBright,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  widget.language.strings.profileReplaySummary(
                    seed: replay.seed,
                    mode:
                        (replay.ranked
                                ? widget.language.strings.kolkhozappRanked
                                : widget.language.strings.kolkhozappCasual)
                            .toUpperCase(),
                    count: events.length,
                  ),
                ),
                Wrap(
                  spacing: 12,
                  children: [
                    for (final result in replay.results)
                      Text(
                        '${result.rank}. ${result.displayName} ${result.score}',
                      ),
                  ],
                ),
                const Divider(),
                if (selected != null) ...[
                  Text(
                    actionLabel(selected),
                    key: const Key('replay-current-action'),
                  ),
                  Slider(
                    value: revision.toDouble(),
                    min: 0,
                    max: (events.length - 1).toDouble(),
                    divisions: events.length - 1 > 0 ? events.length - 1 : null,
                    onChanged: (value) =>
                        setState(() => revision = value.round()),
                  ),
                  Row(
                    children: [
                      TactileTextButton(
                        onPressed: revision == 0
                            ? null
                            : () => setState(() => revision--),
                        child: Text(widget.language.strings.profilePrevious),
                      ),
                      TactileTextButton(
                        onPressed: revision >= events.length - 1
                            ? null
                            : () => setState(() => revision++),
                        child: Text(widget.language.strings.profileNext),
                      ),
                      const Spacer(),
                      Text('${revision + 1}/${events.length}'),
                    ],
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: events.length,
                      itemBuilder: (context, index) =>
                          MechanicalSelectionSurface(
                            selected: index == revision,
                            onPressed: () => setState(() => revision = index),
                            child: ListTile(
                              dense: true,
                              selected: index == revision,
                              title: Text(actionLabel(events[index])),
                            ),
                          ),
                    ),
                  ),
                ] else
                  Expanded(
                    child: Center(
                      child: Text(
                        widget.language.strings.profileNoRecordedActions,
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TactileTextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(widget.language.strings.profileClose),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
