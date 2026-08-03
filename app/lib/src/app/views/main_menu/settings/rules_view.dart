part of 'settings_view.dart';

class _RulesPalette extends InheritedWidget {
  _RulesPalette({required this.tokens, required super.child})
    : surface = tokens.colors.panel,
      raisedSurface = tokens.colors.iron,
      text = tokens.colors.cream,
      accent = tokens.colors.red,
      onAccent = tokens.colors.onAccent,
      highlight = tokens.colors.gold,
      onHighlight = tokens.usesLightAppearance
          ? tokens.colors.onAccent
          : tokens.colors.black,
      mutedSurface = tokens.colors.steel,
      onMutedSurface = tokens.usesLightAppearance
          ? tokens.colors.onAccent
          : tokens.colors.cream,
      deepSurface = tokens.colors.black,
      onDeepSurface = tokens.colors.cream;

  final DesignTokens tokens;
  final Color surface;
  final Color raisedSurface;
  final Color text;
  final Color accent;
  final Color onAccent;
  final Color highlight;
  final Color onHighlight;
  final Color mutedSurface;
  final Color onMutedSurface;
  final Color deepSurface;
  final Color onDeepSurface;

  static _RulesPalette of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_RulesPalette>()!;
  }

  @override
  bool updateShouldNotify(_RulesPalette oldWidget) =>
      tokens != oldWidget.tokens;
}

enum _RulesViewTab { howToPlay, rules }

class RulesView extends StatefulWidget {
  const RulesView({
    super.key,
    required this.tokens,
    required this.language,
    required this.onTutorialPressed,
    this.hasTutorialProgress = false,
    this.onRestartTutorialPressed,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final VoidCallback onTutorialPressed;
  final bool hasTutorialProgress;
  final VoidCallback? onRestartTutorialPressed;

  @override
  State<RulesView> createState() => _RulesViewState();
}

class _RulesViewState extends State<RulesView> {
  _RulesViewTab selectedTab = _RulesViewTab.howToPlay;

  @override
  Widget build(BuildContext context) {
    final strings = widget.language.strings;
    final colors = widget.tokens.colors;
    return _RulesPalette(
      tokens: widget.tokens,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _RulesTabButton(
                  key: const Key('how-to-play-tab'),
                  label: strings.boardOptionspanelHowToPlay,
                  iconPath: fieldPlanHowToPlayPictogram.fieldPlanPath,
                  selected: selectedTab == _RulesViewTab.howToPlay,
                  tokens: widget.tokens,
                  onPressed: () {
                    setState(() => selectedTab = _RulesViewTab.howToPlay);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RulesTabButton(
                  key: const Key('rules-tab'),
                  label: strings.boardOptionspanelRules,
                  iconPath: 'assets/ui/Icons/icon-rules-scroll.png',
                  selected: selectedTab == _RulesViewTab.rules,
                  tokens: widget.tokens,
                  onPressed: () {
                    setState(() => selectedTab = _RulesViewTab.rules);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: colors.gold, width: 2),
                ),
                child: PrintedPaperSurface(
                  tokens: widget.tokens,
                  color: colors.panel,
                  textureOpacity: 0.08,
                  child: MechanicalPanelSwitcher(
                    panelKey: selectedTab,
                    child: switch (selectedTab) {
                      _RulesViewTab.howToPlay => const _HowToPlayPage(),
                      _RulesViewTab.rules => const _CompleteRulesPage(),
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            spacing: 8,
            children: [
              if (widget.hasTutorialProgress &&
                  widget.onRestartTutorialPressed != null)
                SizedBox(
                  width: 190,
                  height: 44,
                  child: ChromeAssetButton.command(
                    label: widget.language == KolkhozLanguage.ru
                        ? 'НАЧАТЬ ЗАНОВО'
                        : 'RESTART TUTORIAL',
                    tokens: widget.tokens,
                    prominent: false,
                    onPressed: widget.onRestartTutorialPressed!,
                    iconAsset: fieldPlanToolbarUndoIconPath,
                    iconSize: 20,
                  ),
                ),
              SizedBox(
                width: 220,
                height: 44,
                child: ChromeAssetButton.command(
                  label: widget.hasTutorialProgress
                      ? (widget.language == KolkhozLanguage.ru
                            ? 'ПРОДОЛЖИТЬ ОБУЧЕНИЕ'
                            : 'RESUME TUTORIAL')
                      : strings.kolkhozappTutorial,
                  prominent: true,
                  tokens: widget.tokens,
                  onPressed: widget.onTutorialPressed,
                  iconAsset: fieldPlanHowToPlayPictogram.fieldPlanPath,
                  iconSize: 22,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RulesTabButton extends StatelessWidget {
  const _RulesTabButton({
    required this.label,
    required this.iconPath,
    required this.selected,
    required this.tokens,
    required this.onPressed,
    super.key,
  });

  final String label;
  final String iconPath;
  final bool selected;
  final DesignTokens tokens;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? tokens.colors.onAccent : tokens.colors.gold;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: MechanicalSelectionSurface(
        selected: selected,
        onPressed: onPressed,
        child: Material(
          color: selected ? tokens.colors.red : tokens.colors.iron,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected
                    ? tokens.colors.onAccent
                    : tokens.colors.gold.withValues(alpha: 0.66),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  iconPath,
                  width: 28,
                  height: 28,
                  filterQuality: FilterQuality.medium,
                  isAntiAlias: true,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: fieldPlanDisplayTextStyle.copyWith(
                      color: foreground,
                      fontSize: 18,
                      letterSpacing: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HowToPlayPage extends StatelessWidget {
  const _HowToPlayPage();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const Key('how-to-play-overview-scroll'),
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HowToPlayHeader(),
              SizedBox(height: 18),
              _SetupOverview(),
              SizedBox(height: 18),
              _YearOverview(),
              SizedBox(height: 18),
              _QuickReferenceOverview(),
              SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _HowToPlayHeader extends StatelessWidget {
  const _HowToPlayHeader();

  @override
  Widget build(BuildContext context) {
    final palette = _RulesPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.text, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const _LeafletIcon(
            'assets/art/field_plan/ledger/variants/'
            'variant_five_year_plan.png',
            size: 78,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'THE FIVE-YEAR PLAN',
                  style: fieldPlanDisplayTextStyle.copyWith(
                    color: palette.accent,
                    fontSize: 18,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'One year at a glance',
                  style: TextStyle(
                    fontFamily: 'Podkova',
                    color: palette.text,
                    fontSize: 34,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: const [
                    _LeafletBadge(label: '3–4 PLAYERS'),
                    _LeafletBadge(label: 'ABOUT 30 MINUTES'),
                    _LeafletBadge(label: '5 YEARS'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeafletBadge extends StatelessWidget {
  const _LeafletBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = _RulesPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      color: palette.highlight,
      child: Text(
        label,
        style: fieldPlanDisplayTextStyle.copyWith(
          color: palette.onHighlight,
          fontSize: 13,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SetupOverview extends StatelessWidget {
  const _SetupOverview();

  @override
  Widget build(BuildContext context) {
    final palette = _RulesPalette.of(context);
    return _LeafletSection(
      eyebrow: 'BEFORE YEAR ONE',
      title: 'Set up the collective',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Build four reward piles—one for each crop.',
            style: fieldPlanBodyStrongTextStyle.copyWith(
              color: palette.text,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          const Wrap(
            alignment: WrapAlignment.spaceAround,
            spacing: 8,
            runSpacing: 10,
            children: [
              _CropSetupIcon(label: 'WHEAT', iconPath: fieldPlanWheatIconPath),
              _CropSetupIcon(
                label: 'SUNFLOWER',
                iconPath: fieldPlanSunflowerIconPath,
              ),
              _CropSetupIcon(
                label: 'POTATO',
                iconPath: fieldPlanPotatoIconPath,
              ),
              _CropSetupIcon(label: 'BEET', iconPath: fieldPlanBeetIconPath),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 680
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: width,
                    child: const _SetupChecklistItem(
                      iconPaths: [
                        'assets/art/field_plan/ledger/variants/'
                            'variant_saboteur.png',
                      ],
                      title: 'WORKERS DECK',
                      body: 'Shuffle the remaining cards with the Saboteur.',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: const _SetupChecklistItem(
                      iconPaths: [
                        fieldPlanPlotIconPath,
                        fieldPlanCellarIconPath,
                      ],
                      title: 'PLAYER AREAS',
                      body:
                          'Give each player a face-up Plot and hidden Cellar.',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: const _SetupChecklistItem(
                      iconPaths: [
                        fieldPlanMedalIconPath,
                        fieldPlanNavigationNorthPath,
                      ],
                      title: 'TABLE SUPPLY',
                      body: 'Place four Medal cards and the North nearby.',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: const _SetupChecklistItem(
                      iconPaths: [
                        'assets/art/field_plan/ledger/variants/'
                            'variant_five_year_plan.png',
                      ],
                      title: 'CENTRAL PLANNER',
                      body: 'Give the Planner card to the dealer.',
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CropSetupIcon extends StatelessWidget {
  const _CropSetupIcon({required this.label, required this.iconPath});

  final String label;
  final String iconPath;

  @override
  Widget build(BuildContext context) {
    final palette = _RulesPalette.of(context);
    return SizedBox(
      width: 118,
      child: Column(
        children: [
          _LeafletIcon(iconPath, size: 66),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: fieldPlanDisplayTextStyle.copyWith(
              color: palette.text,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupChecklistItem extends StatelessWidget {
  const _SetupChecklistItem({
    required this.iconPaths,
    required this.title,
    required this.body,
  });

  final List<String> iconPaths;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final palette = _RulesPalette.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.raisedSurface.withValues(alpha: 0.56),
        border: Border.all(color: palette.highlight),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final path in iconPaths)
                  Flexible(child: _LeafletIcon(path, size: 48)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: fieldPlanDisplayTextStyle.copyWith(
                    color: palette.accent,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: fieldPlanBodyTextStyle.copyWith(
                    color: palette.text,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _YearOverview extends StatelessWidget {
  const _YearOverview();

  static const steps = [
    _HowStep(
      title: 'PLAN',
      body: 'Deal hands, reveal four rewards, and choose trump.',
      iconPath:
          'assets/art/field_plan/ledger/variants/variant_five_year_plan.png',
    ),
    _HowStep(
      title: 'PLAY A TRICK',
      body: 'Follow suit. Highest trump—or highest led suit—wins.',
      iconPath: fieldPlanToolbarPlayIconPath,
    ),
    _HowStep(
      title: 'ASSIGN THE WORK',
      body: 'The winner takes a Medal and assigns all four cards.',
      iconPath: fieldPlanToolbarAssignIconPath,
    ),
    _HowStep(
      title: 'COMPLETE FIELDS',
      body: 'Reach 40 hours with four players or 32 with three.',
      iconPath: 'assets/ui/Icons/icon-status-reward-claimed.png',
    ),
    _HowStep(
      title: 'BANK & REQUISITION',
      body: 'Bank the last card, resolve failed fields, then pass left.',
      iconPath:
          'assets/art/field_plan/ledger/variants/'
          'variant_highest_cards_requisition.png',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = _RulesPalette.of(context);
    return _LeafletSection(
      eyebrow: 'THE FIVE-YEAR PLAN',
      title: 'Play one year',
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            _HowStepRow(number: i + 1, step: steps[i]),
            if (i != steps.length - 1) const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _YearCountCard(
                  title: 'YEARS 1–4',
                  body: '5 cards • 4 tricks',
                  color: palette.highlight,
                  foreground: palette.onHighlight,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _YearCountCard(
                  title: 'YEAR 5: FAMINE',
                  body: '4 cards • 3 tricks',
                  color: palette.mutedSurface,
                  foreground: palette.onMutedSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HowStep {
  const _HowStep({
    required this.title,
    required this.body,
    required this.iconPath,
  });

  final String title;
  final String body;
  final String iconPath;
}

class _HowStepRow extends StatelessWidget {
  const _HowStepRow({required this.number, required this.step});

  final int number;
  final _HowStep step;

  @override
  Widget build(BuildContext context) {
    final palette = _RulesPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 14, 9),
      decoration: BoxDecoration(
        color: palette.raisedSurface.withValues(alpha: 0.58),
        border: Border(left: BorderSide(color: palette.accent, width: 7)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 66,
            height: 60,
            child: Stack(
              children: [
                Center(child: _LeafletIcon(step.iconPath, size: 58)),
                Positioned(
                  left: 0,
                  top: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: palette.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$number',
                      style: fieldPlanDisplayTextStyle.copyWith(
                        color: palette.onAccent,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: fieldPlanDisplayTextStyle.copyWith(
                    color: palette.text,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  step.body,
                  style: fieldPlanBodyTextStyle.copyWith(
                    color: palette.text,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _YearCountCard extends StatelessWidget {
  const _YearCountCard({
    required this.title,
    required this.body,
    required this.color,
    required this.foreground,
  });

  final String title;
  final String body;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: fieldPlanDisplayTextStyle.copyWith(
              color: foreground,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            body,
            style: fieldPlanBodyTextStyle.copyWith(
              color: foreground,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickReferenceOverview extends StatelessWidget {
  const _QuickReferenceOverview();

  static const entries = [
    _QuickEntry(
      title: 'TRICK',
      body: 'Follow suit. Highest trump—or led suit—wins.',
      iconPath: fieldPlanToolbarPlayIconPath,
    ),
    _QuickEntry(
      title: 'ASSIGN',
      body: 'Use any field whose suit appeared in the trick.',
      iconPath: fieldPlanToolbarAssignIconPath,
    ),
    _QuickEntry(
      title: 'COMPLETE',
      body: '40 hours (4P) • 32 hours (3P).',
      iconPath: 'assets/ui/Icons/icon-status-reward-claimed.png',
    ),
    _QuickEntry(
      title: 'REQUISITION',
      body: 'Take the highest eligible cards from failed suits.',
      iconPath:
          'assets/art/field_plan/ledger/variants/'
          'variant_highest_cards_requisition.png',
    ),
    _QuickEntry(
      title: 'SCORE',
      body: 'After year five, total Plot + Cellar.',
      iconPath: 'assets/ui/Icons/icon-crop-seal.png',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = _RulesPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      color: palette.mutedSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KEEP THIS VISIBLE',
                      style: fieldPlanDisplayTextStyle.copyWith(
                        color: palette.highlight,
                        fontSize: 14,
                        letterSpacing: 1.6,
                      ),
                    ),
                    Text(
                      'Quick reference',
                      style: TextStyle(
                        fontFamily: 'Podkova',
                        color: palette.onMutedSurface,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const _LeafletIcon(fieldPlanMedalIconPath, size: 54),
            ],
          ),
          const SizedBox(height: 9),
          Container(height: 2, color: palette.highlight),
          const SizedBox(height: 8),
          for (final entry in entries) _QuickReferenceRow(entry: entry),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            color: palette.deepSurface,
            child: Row(
              children: [
                const _LeafletIcon(
                  'assets/art/field_plan/ledger/variants/'
                  'variant_saboteur.png',
                  size: 42,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'SABOTEUR: 0 hours • every suit • its field fails.',
                    style: fieldPlanDisplayTextStyle.copyWith(
                      color: palette.onDeepSurface,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickEntry {
  const _QuickEntry({
    required this.title,
    required this.body,
    required this.iconPath,
  });

  final String title;
  final String body;
  final String iconPath;
}

class _QuickReferenceRow extends StatelessWidget {
  const _QuickReferenceRow({required this.entry});

  final _QuickEntry entry;

  @override
  Widget build(BuildContext context) {
    final palette = _RulesPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: palette.accent, width: 6)),
      ),
      child: Row(
        children: [
          SizedBox(width: 56, child: _LeafletIcon(entry.iconPath, size: 42)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: fieldPlanDisplayTextStyle.copyWith(
                    color: palette.highlight,
                    fontSize: 15,
                  ),
                ),
                Text(
                  entry.body,
                  style: fieldPlanBodyTextStyle.copyWith(
                    color: palette.onMutedSurface,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompleteRulesPage extends StatelessWidget {
  const _CompleteRulesPage();

  @override
  Widget build(BuildContext context) {
    final sections = _rulebookSections();
    return SingleChildScrollView(
      key: const Key('how-to-play-rulebook-scroll'),
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _RulebookHeading(),
              const SizedBox(height: 16),
              for (var i = 0; i < sections.length; i++) ...[
                _VisualRulebookSection(section: sections[i], index: i),
                if (i != sections.length - 1) const SizedBox(height: 14),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _RulebookHeading extends StatelessWidget {
  const _RulebookHeading();

  @override
  Widget build(BuildContext context) {
    final palette = _RulesPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.highlight,
        border: Border(
          bottom: BorderSide(color: palette.onHighlight, width: 3),
        ),
      ),
      child: Row(
        children: [
          const _LeafletIcon('assets/ui/Icons/icon-rules-scroll.png', size: 64),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kolkhozBaseRulebookTitle.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Podkova',
                    color: palette.onHighlight,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  kolkhozBaseRulebookPlayerCount,
                  style: fieldPlanBodyStrongTextStyle.copyWith(
                    color: palette.onHighlight,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RulebookSectionData {
  const _RulebookSectionData({required this.title, required this.blocks});

  final String title;
  final List<RulebookBlock> blocks;
}

List<_RulebookSectionData> _rulebookSections() {
  final sections = <_RulebookSectionData>[];
  String? title;
  var blocks = <RulebookBlock>[];
  for (final block in kolkhozBaseRulebook) {
    if (block.kind == RulebookBlockKind.sectionTitle) {
      if (title != null) {
        sections.add(_RulebookSectionData(title: title, blocks: blocks));
      }
      title = block.text;
      blocks = <RulebookBlock>[];
    } else {
      blocks.add(block);
    }
  }
  if (title != null) {
    sections.add(_RulebookSectionData(title: title, blocks: blocks));
  }
  return sections;
}

class _VisualRulebookSection extends StatelessWidget {
  const _VisualRulebookSection({required this.section, required this.index});

  final _RulebookSectionData section;
  final int index;

  static const icons = [
    'assets/art/field_plan/ledger/variants/variant_deck.png',
    'assets/art/field_plan/ledger/variants/variant_five_year_plan.png',
    'assets/ui/Icons/icon-crop-seal.png',
  ];

  @override
  Widget build(BuildContext context) {
    final palette = _RulesPalette.of(context);
    final emphasized = index == 1;
    return Container(
      decoration: BoxDecoration(
        color: palette.raisedSurface.withValues(alpha: 0.66),
        border: Border.all(color: palette.highlight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: emphasized ? palette.accent : palette.highlight,
            child: Row(
              children: [
                _LeafletIcon(icons[index.clamp(0, icons.length - 1)], size: 48),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    section.title,
                    style: fieldPlanDisplayTextStyle.copyWith(
                      color: emphasized
                          ? palette.onAccent
                          : palette.onHighlight,
                      fontSize: 19,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < section.blocks.length; i++) ...[
                  _VisualRulebookBlock(block: section.blocks[i]),
                  if (i != section.blocks.length - 1) const SizedBox(height: 7),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VisualRulebookBlock extends StatelessWidget {
  const _VisualRulebookBlock({required this.block});

  final RulebookBlock block;

  @override
  Widget build(BuildContext context) {
    final palette = _RulesPalette.of(context);
    final bodyStyle = fieldPlanBodyTextStyle.copyWith(
      color: palette.text,
      fontSize: 15,
      height: 1.28,
    );
    return switch (block.kind) {
      RulebookBlockKind.sectionTitle => const SizedBox.shrink(),
      RulebookBlockKind.subsectionTitle => Container(
        padding: const EdgeInsets.fromLTRB(10, 7, 10, 6),
        decoration: BoxDecoration(
          color: palette.mutedSurface,
          border: Border(left: BorderSide(color: palette.accent, width: 6)),
        ),
        child: Row(
          children: [
            _LeafletIcon(_subsectionIcon(block.text), size: 34),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                block.text,
                style: fieldPlanDisplayTextStyle.copyWith(
                  color: palette.onMutedSurface,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
      RulebookBlockKind.groupTitle => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          color: palette.highlight,
          child: Text(
            block.text.toUpperCase(),
            style: fieldPlanDisplayTextStyle.copyWith(
              color: palette.onHighlight,
              fontSize: 14,
            ),
          ),
        ),
      ),
      RulebookBlockKind.paragraph => Text(block.text, style: bodyStyle),
      RulebookBlockKind.bullet => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(top: 6, right: 10),
            color: palette.accent,
          ),
          Expanded(child: Text(block.text, style: bodyStyle)),
        ],
      ),
    };
  }

  String _subsectionIcon(String text) {
    if (text.contains('Planning')) {
      return 'assets/art/field_plan/ledger/variants/'
          'variant_five_year_plan.png';
    }
    if (text.contains('Tricks')) return fieldPlanToolbarPlayIconPath;
    if (text.contains('Requisition')) {
      return 'assets/art/field_plan/ledger/variants/'
          'variant_highest_cards_requisition.png';
    }
    if (text.contains('End of Year')) {
      return 'assets/art/field_plan/ledger/variants/'
          'variant_pass_cards.png';
    }
    return fieldPlanCellarIconPath;
  }
}

class _LeafletSection extends StatelessWidget {
  const _LeafletSection({
    required this.eyebrow,
    required this.title,
    required this.child,
  });

  final String eyebrow;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = _RulesPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.72),
        border: Border.all(color: palette.highlight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            eyebrow,
            style: fieldPlanDisplayTextStyle.copyWith(
              color: palette.accent,
              fontSize: 15,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Podkova',
              color: palette.text,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Container(height: 2, color: palette.text),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _LeafletIcon extends StatelessWidget {
  const _LeafletIcon(this.path, {required this.size});

  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      path,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      isAntiAlias: true,
      errorBuilder: (_, _, _) => SizedBox.square(dimension: size),
    );
  }
}
