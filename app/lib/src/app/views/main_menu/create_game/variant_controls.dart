import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kolkhoz_app/src/app/settings/settings.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/engine_values.dart';
import 'package:kolkhoz_app/src/app/views/shared/app_text.dart';
import 'package:kolkhoz_app/src/app/views/shared/chrome_button.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'package:kolkhoz_app/src/app/views/shared/field_plan_assets.dart';
import 'package:kolkhoz_app/src/app/views/shared/display_text.dart';
import '../main_menu_view.dart';

class VariantIcon extends StatelessWidget {
  const VariantIcon(
    this.asset, {
    super.key,
    required this.size,
    this.opacity = 1,
  });

  final String asset;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) =>
      MainMenuAssetIcon(asset, size: size, opacity: opacity);
}

class VariantRowData {
  VariantRowData({
    this.titleKey,
    this.descriptionKey,
    this.iconAsset,
    this.titleFor,
    this.descriptionFor,
    this.iconAssetForVariants,
    required this.valueOf,
    required this.withValue,
    this.visibleInCustom = _alwaysVisible,
  });

  final KolkhozText? titleKey;
  final KolkhozText? descriptionKey;
  final String? iconAsset;
  final String Function(KolkhozGameVariants variants, KolkhozLanguage language)?
  titleFor;
  final String Function(KolkhozGameVariants variants, KolkhozLanguage language)?
  descriptionFor;
  final String Function(KolkhozGameVariants variants)? iconAssetForVariants;
  final bool Function(KolkhozGameVariants variants) valueOf;
  final KolkhozGameVariants Function(KolkhozGameVariants variants, bool value)
  withValue;
  final bool Function(KolkhozGameVariants variants) visibleInCustom;

  static final deckType = VariantRowData(
    titleFor: (variants, language) =>
        language.strings.variantValue1CardDeck(value1: variants.deckType),
    descriptionFor: (variants, language) => '',
    iconAssetForVariants: (variants) =>
        fieldPlanVariantDeckFor(variants.deckType).fieldPlanPath,
    valueOf: (variants) => true,
    withValue: (variants, value) => variants,
  );
  static final maxYears = VariantRowData(
    titleFor: (variants, language) =>
        language.strings.variantValue1YearPlan(value1: variants.maxYears),
    descriptionFor: (variants, language) => '',
    iconAssetForVariants: (variants) =>
        fieldPlanVariantFiveYearPlan.fieldPlanPath,
    valueOf: (variants) => true,
    withValue: (variants, value) => variants,
  );
  static final nomenclature = VariantRowData(
    titleKey: KolkhozText.variantNomenklaturaTitle,
    descriptionKey: KolkhozText.variantNomenklaturaDescription,
    iconAsset: fieldPlanVariantNomenklatura.fieldPlanPath,
    valueOf: (variants) => variants.nomenclature,
    withValue: (variants, value) => variants.copyWith(nomenclature: value),
  );
  static final allowSwap = VariantRowData(
    titleKey: KolkhozText.variantSwapTitle,
    descriptionKey: KolkhozText.variantSwapDescription,
    iconAsset: fieldPlanVariantSwapCards.fieldPlanPath,
    valueOf: (variants) => variants.allowSwap,
    withValue: (variants, value) => variants.copyWith(allowSwap: value),
  );
  static final northernStyle = VariantRowData(
    titleKey: KolkhozText.variantNorthernStyleTitle,
    descriptionKey: KolkhozText.variantNorthernStyleDescription,
    iconAsset: fieldPlanVariantNorthernStyle.fieldPlanPath,
    valueOf: (variants) => variants.northernStyle,
    withValue: (variants, value) => variants.copyWith(
      northernStyle: value,
      managedEconomy: value ? false : variants.managedEconomy,
    ),
  );
  static final miceVariant = VariantRowData(
    titleKey: KolkhozText.variantMiceTitle,
    descriptionKey: KolkhozText.variantMiceDescription,
    iconAsset: fieldPlanVariantMice.fieldPlanPath,
    valueOf: (variants) => variants.miceVariant,
    withValue: (variants, value) => variants.copyWith(miceVariant: value),
  );
  static final ordenNachalniku = VariantRowData(
    titleKey: KolkhozText.variantOrdenNachalnikuTitle,
    descriptionKey: KolkhozText.variantOrdenNachalnikuDescription,
    iconAsset: fieldPlanVariantOrderToBoss.fieldPlanPath,
    valueOf: (variants) => variants.ordenNachalniku,
    withValue: (variants, value) => variants.copyWith(ordenNachalniku: value),
    visibleInCustom: (variants) => variants.deckType == 36,
  );
  static final medalsCount = VariantRowData(
    titleKey: KolkhozText.variantMedalsTitle,
    descriptionKey: KolkhozText.variantMedalsDescription,
    iconAsset: fieldPlanVariantMedals.fieldPlanPath,
    valueOf: (variants) => variants.medalsCount,
    withValue: (variants, value) => variants.copyWith(medalsCount: value),
  );
  static final heroOfSovietUnion = VariantRowData(
    titleKey: KolkhozText.variantHeroTitle,
    descriptionKey: KolkhozText.variantHeroDescription,
    iconAsset: fieldPlanVariantHero.fieldPlanPath,
    valueOf: (variants) => variants.heroOfSovietUnion,
    withValue: (variants, value) => variants.copyWith(heroOfSovietUnion: value),
  );
  static final accumulateJobs = VariantRowData(
    titleKey: KolkhozText.variantAccumulationTitle,
    descriptionKey: KolkhozText.variantAccumulationDescription,
    iconAsset: fieldPlanVariantStakhanovite.fieldPlanPath,
    valueOf: (variants) => variants.accumulateJobs,
    withValue: (variants, value) => variants.copyWith(accumulateJobs: value),
    visibleInCustom: (variants) => variants.deckType != 36,
  );
  static final wrecker = VariantRowData(
    titleKey: KolkhozText.variantWreckerTitle,
    descriptionKey: KolkhozText.variantWreckerDescription,
    iconAsset: fieldPlanVariantSaboteur.fieldPlanPath,
    valueOf: (variants) => variants.wreckerCard,
    withValue: (variants, value) => variants.copyWith(
      wreckerCard: value,
      finalYearTrump: value ? variants.finalYearTrump : false,
    ),
  );
  static final finalYearTrump = VariantRowData(
    titleKey: KolkhozText.variantFinalYearTrumpTitle,
    descriptionKey: KolkhozText.variantFinalYearTrumpDescription,
    iconAsset: fieldPlanVariantFinalYearTrump.fieldPlanPath,
    valueOf: (variants) => variants.finalYearTrump,
    withValue: (variants, value) => variants.copyWith(finalYearTrump: value),
    visibleInCustom: (variants) => variants.wreckerCard,
  );
  static final passCards = VariantRowData(
    titleKey: KolkhozText.variantPassCardsTitle,
    descriptionKey: KolkhozText.variantPassCardsDescription,
    iconAsset: fieldPlanVariantPassCards.fieldPlanPath,
    valueOf: (variants) => variants.passCards,
    withValue: (variants, value) => variants.copyWith(passCards: value),
  );
  static final lottoRewards = VariantRowData(
    titleKey: KolkhozText.variantLottoRewardsTitle,
    descriptionKey: KolkhozText.variantLottoRewardsDescription,
    iconAsset: fieldPlanVariantLottoRewards.fieldPlanPath,
    valueOf: (variants) => variants.lottoRewards,
    withValue: (variants, value) => variants.copyWith(
      lottoRewards: value,
      managedEconomy: value ? false : variants.managedEconomy,
    ),
    visibleInCustom: (variants) => variants.deckType != 36,
  );
  static final managedEconomy = VariantRowData(
    titleKey: KolkhozText.variantManagedEconomyTitle,
    descriptionKey: KolkhozText.variantManagedEconomyDescription,
    iconAsset: fieldPlanVariantFiveYearPlanFourYears.fieldPlanPath,
    valueOf: (variants) => variants.managedEconomy,
    withValue: (variants, value) => variants.copyWith(
      managedEconomy: value,
      lottoRewards: value ? false : variants.lottoRewards,
    ),
    visibleInCustom: (variants) =>
        variants.deckType != 36 && !variants.northernStyle,
  );
  static final demoMode = VariantRowData(
    titleKey: KolkhozText.variantDemoModeTitle,
    descriptionKey: KolkhozText.variantDemoModeDescription,
    iconAsset: fieldPlanYearIconPath(5),
    valueOf: (variants) => false,
    withValue: (variants, value) => variants,
    visibleInCustom: (variants) => false,
  );

  static final all = [
    nomenclature,
    allowSwap,
    northernStyle,
    miceVariant,
    ordenNachalniku,
    medalsCount,
    heroOfSovietUnion,
    accumulateJobs,
    wrecker,
    finalYearTrump,
    passCards,
    lottoRewards,
    managedEconomy,
  ];

  static List<VariantRowData> enabledRows(
    KolkhozGameVariants variants, {
    bool demoMode = false,
  }) => [
    if (demoMode) VariantRowData.demoMode,
    for (final row in all)
      if (row.valueOf(variants)) row,
  ];

  static List<VariantRowData> summaryRows(
    KolkhozGameVariants variants, {
    bool demoMode = false,
  }) => [deckType, maxYears, ...enabledRows(variants, demoMode: demoMode)];

  static List<VariantRowData> configurableRows(KolkhozGameVariants variants) =>
      [
        deckType,
        maxYears,
        for (final row in all)
          if (row.visibleInCustom(variants)) row,
      ];

  String localizedTitle(
    KolkhozLanguage language,
    KolkhozGameVariants variants,
  ) {
    final builder = titleFor;
    if (builder != null) {
      return builder(variants, language);
    }
    return language.t(titleKey!);
  }

  String localizedDescription(
    KolkhozLanguage language,
    KolkhozGameVariants variants,
  ) {
    final builder = descriptionFor;
    if (builder != null) {
      return builder(variants, language);
    }
    return language.t(descriptionKey!);
  }

  String iconAssetFor(KolkhozGameVariants variants) {
    final builder = iconAssetForVariants;
    if (builder != null) {
      return builder(variants);
    }
    return iconAsset!;
  }
}

bool _alwaysVisible(KolkhozGameVariants variants) => true;

extension ControllerLobbyLabels on KolkhozPlayerController {
  String shortTitle(KolkhozLanguage language) {
    return switch (this) {
      KolkhozPlayerController.human => language.strings.kolkhozappHuman,
      KolkhozPlayerController.heuristicAI => language.strings.kolkhozappEasy,
      KolkhozPlayerController.mediumAI => language.strings.kolkhozappMedium,
      KolkhozPlayerController.neuralAI => language.strings.kolkhozappHard,
    };
  }
}

String presetTitle(KolkhozGamePreset preset, KolkhozLanguage language) {
  return switch (preset) {
    KolkhozGamePreset.kolkhoz => language.strings.presetKolkhoz,
    KolkhozGamePreset.littleKolkhoz => language.strings.presetLittleKolkhoz,
    KolkhozGamePreset.campStyle => language.strings.presetCampStyle,
    KolkhozGamePreset.custom => language.strings.presetCustom,
  };
}

class PresetSummary extends StatefulWidget {
  const PresetSummary({
    super.key,
    required this.tokens,
    required this.language,
    required this.variants,
    this.demoMode = false,
    this.compact = false,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozGameVariants variants;
  final bool demoMode;
  final bool compact;

  @override
  State<PresetSummary> createState() => _PresetSummaryState();
}

class _PresetSummaryState extends State<PresetSummary> {
  int selectedRowIndex = 0;

  @override
  void didUpdateWidget(covariant PresetSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    final rows = VariantRowData.summaryRows(
      widget.variants,
      demoMode: widget.demoMode,
    );
    if (selectedRowIndex >= rows.length) {
      selectedRowIndex = math.max(0, rows.length - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = VariantRowData.summaryRows(
      widget.variants,
      demoMode: widget.demoMode,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = _variantInfoScale(constraints.maxWidth);
        final selectedRow = rows.isEmpty ? null : rows[selectedRowIndex];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: widget.compact ? 6 : 8 + 2 * scale,
          children: [
            if (widget.compact && rows.isNotEmpty) ...[
              _VariantIconStrip(
                tokens: widget.tokens,
                language: widget.language,
                variants: widget.variants,
                rows: rows,
                selectedIndex: selectedRowIndex,
                onSelected: (index) => setState(() {
                  selectedRowIndex = index;
                }),
              ),
              if (selectedRow != null)
                _VariantReadOnlyRow(
                  tokens: widget.tokens,
                  language: widget.language,
                  variants: widget.variants,
                  row: selectedRow,
                  scale: 0,
                  compact: true,
                ),
            ] else
              for (final row in rows)
                _VariantReadOnlyRow(
                  tokens: widget.tokens,
                  language: widget.language,
                  variants: widget.variants,
                  row: row,
                  scale: scale,
                ),
          ],
        );
      },
    );
  }
}

class CustomVariantOptions extends StatefulWidget {
  const CustomVariantOptions({
    super.key,
    required this.tokens,
    required this.language,
    required this.variants,
    required this.compact,
    required this.onChanged,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozGameVariants variants;
  final bool compact;
  final ValueChanged<KolkhozGameVariants> onChanged;

  @override
  State<CustomVariantOptions> createState() => _CustomVariantOptionsState();
}

class _CustomVariantOptionsState extends State<CustomVariantOptions> {
  int selectedRowIndex = 0;

  @override
  void didUpdateWidget(covariant CustomVariantOptions oldWidget) {
    super.didUpdateWidget(oldWidget);
    final rows = VariantRowData.configurableRows(widget.variants);
    if (selectedRowIndex >= rows.length) {
      selectedRowIndex = math.max(0, rows.length - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = _variantInfoScale(constraints.maxWidth);
        final rows = VariantRowData.configurableRows(widget.variants);
        final selectedRow = rows.isEmpty ? null : rows[selectedRowIndex];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: widget.compact ? 6 : 8 + 2 * scale,
          children: [
            if (widget.compact && rows.isNotEmpty) ...[
              _VariantIconStrip(
                tokens: widget.tokens,
                language: widget.language,
                variants: widget.variants,
                rows: rows,
                selectedIndex: selectedRowIndex,
                onSelected: (index) => setState(() {
                  selectedRowIndex = index;
                }),
              ),
              if (selectedRow != null) _customRow(selectedRow, scale: 0),
            ] else
              for (final row in rows) _customRow(row, scale: scale),
          ],
        );
      },
    );
  }

  Widget _customRow(VariantRowData row, {required double scale}) {
    if (row == VariantRowData.deckType) {
      return _DeckVariantToggleRow(
        tokens: widget.tokens,
        language: widget.language,
        variants: widget.variants,
        scale: scale,
        compact: widget.compact,
        onChanged: widget.onChanged,
      );
    }
    if (row == VariantRowData.maxYears) {
      return _YearVariantToggleRow(
        tokens: widget.tokens,
        language: widget.language,
        variants: widget.variants,
        scale: scale,
        compact: widget.compact,
        onChanged: widget.onChanged,
      );
    }
    return _VariantToggleRow(
      tokens: widget.tokens,
      language: widget.language,
      variants: widget.variants,
      row: row,
      value: row.valueOf(widget.variants),
      scale: scale,
      compact: widget.compact,
      onChanged: (value) =>
          widget.onChanged(row.withValue(widget.variants, value)),
    );
  }
}

class _DeckVariantToggleRow extends StatelessWidget {
  const _DeckVariantToggleRow({
    required this.tokens,
    required this.language,
    required this.variants,
    required this.scale,
    required this.compact,
    required this.onChanged,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozGameVariants variants;
  final double scale;
  final bool compact;
  final ValueChanged<KolkhozGameVariants> onChanged;

  @override
  Widget build(BuildContext context) {
    final deckButtonHeight = compact ? 52.0 : 58 + 16 * scale;
    final deckIconSize = compact
        ? (deckButtonHeight * 0.72).clamp(34.0, 40.0)
        : 32 + 12 * scale;
    final deckTextSize = compact
        ? buttonContentTextSize(deckButtonHeight)
        : scale > 0.38
        ? DisplayTextSize.cardRank
        : DisplayTextSize.title;
    final deckPadding = compact ? 7.0 : 14 + 8 * scale;
    final deckSpacing = compact ? 6.0 : 8.0;
    return Row(
      spacing: compact ? 6 : 6 + 4 * scale,
      children: [
        Expanded(
          child: ImageTabButton(
            tokens: tokens,
            label: language.strings.variantDeck52Cards,
            iconAsset: fieldPlanVariantDeck52.fieldPlanPath,
            iconSize: deckIconSize,
            selected: variants.deckType == 52,
            height: deckButtonHeight,
            textSize: deckTextSize,
            horizontalPadding: deckPadding,
            contentSpacing: deckSpacing,
            onPressed: () => onChanged(
              variants.copyWith(deckType: 52, ordenNachalniku: false),
            ),
          ),
        ),
        Expanded(
          child: ImageTabButton(
            tokens: tokens,
            label: language.strings.variantDeck36Cards,
            iconAsset: fieldPlanVariantDeck36.fieldPlanPath,
            iconSize: deckIconSize,
            selected: variants.deckType == 36,
            height: deckButtonHeight,
            textSize: deckTextSize,
            horizontalPadding: deckPadding,
            contentSpacing: deckSpacing,
            onPressed: () => onChanged(
              variants.copyWith(
                deckType: 36,
                accumulateJobs: false,
                lottoRewards: false,
                managedEconomy: false,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _YearVariantToggleRow extends StatelessWidget {
  const _YearVariantToggleRow({
    required this.tokens,
    required this.language,
    required this.variants,
    required this.scale,
    required this.compact,
    required this.onChanged,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozGameVariants variants;
  final double scale;
  final bool compact;
  final ValueChanged<KolkhozGameVariants> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: compact ? 7 : 8 + 2 * scale,
      runSpacing: compact ? 7 : 8 + 2 * scale,
      children: [
        for (var years = 1; years <= 5; years += 1)
          _VariantIconChip(
            tokens: tokens,
            label: language.strings.variantValue1YearPlan(value1: years),
            iconAsset: fieldPlanYearIconPath(years),
            selected: variants.maxYears == years,
            onPressed: () => onChanged(variants.copyWith(maxYears: years)),
          ),
      ],
    );
  }
}

double _variantInfoScale(double width) {
  return ((width - 520) / 900).clamp(0.0, 1.0).toDouble();
}

class _VariantReadOnlyRow extends StatelessWidget {
  const _VariantReadOnlyRow({
    required this.tokens,
    required this.language,
    required this.variants,
    required this.row,
    required this.scale,
    this.compact = false,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozGameVariants variants;
  final VariantRowData row;
  final double scale;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return VariantRowBackground(
      tokens: tokens,
      active: true,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16 + 12 * scale,
        vertical: compact ? 9 : 13 + 12 * scale,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: compact ? 10 : 12 + 8 * scale,
        children: [
          VariantIcon(
            row.iconAssetFor(variants),
            size: compact ? 40 : _variantIconSize(scale),
          ),
          Expanded(
            child: _VariantText(
              tokens: tokens,
              language: language,
              variants: variants,
              row: row,
              active: true,
              scale: scale,
              compact: compact,
            ),
          ),
        ],
      ),
    );
  }
}

class _VariantIconStrip extends StatelessWidget {
  const _VariantIconStrip({
    required this.tokens,
    required this.language,
    required this.variants,
    required this.rows,
    required this.selectedIndex,
    required this.onSelected,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozGameVariants variants;
  final List<VariantRowData> rows;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (var index = 0; index < rows.length; index += 1)
          _VariantIconChip(
            tokens: tokens,
            label: rows[index].localizedTitle(language, variants),
            iconAsset: rows[index].iconAssetFor(variants),
            selected: index == selectedIndex,
            enabled: rows[index].valueOf(variants),
            onPressed: () => onSelected(index),
          ),
      ],
    );
  }
}

class _VariantIconChip extends StatelessWidget {
  const _VariantIconChip({
    required this.tokens,
    required this.label,
    required this.iconAsset,
    required this.selected,
    this.enabled = false,
    required this.onPressed,
  });

  final DesignTokens tokens;
  final String label;
  final String iconAsset;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: Tooltip(
          message: label,
          child: MechanicalSelectionSurface(
            selected: selected,
            onPressed: onPressed,
            child: SizedBox(
              width: 52,
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: ChromeButtonBackground(
                      asset: switch ((selected, enabled)) {
                        (true, true) => chromeButtonPrimaryCurrentAsset,
                        (true, false) => chromeButtonPrimaryAsset,
                        (false, true) => chromeButtonSecondaryCurrentAsset,
                        (false, false) => chromeButtonSecondaryAsset,
                      },
                    ),
                  ),
                  VariantIcon(
                    iconAsset,
                    size: selected ? 34 : 31,
                    opacity: selected ? 1 : 0.82,
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

class _VariantToggleRow extends StatelessWidget {
  const _VariantToggleRow({
    required this.tokens,
    required this.language,
    required this.variants,
    required this.row,
    required this.value,
    required this.onChanged,
    required this.scale,
    this.compact = false,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozGameVariants variants;
  final VariantRowData row;
  final bool value;
  final ValueChanged<bool> onChanged;
  final double scale;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = row.localizedTitle(language, variants);
    final toggleSize = compact ? 30.0 : 34 + 12 * scale;
    return Semantics(
      button: true,
      toggled: value,
      label: label,
      child: ExcludeSemantics(
        child: MechanicalSelectionSurface(
          selected: value,
          onPressed: () => onChanged(!value),
          child: VariantRowBackground(
            tokens: tokens,
            active: value,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 16 + 12 * scale,
              vertical: compact ? 9 : 13 + 12 * scale,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: compact ? 10 : 12 + 8 * scale,
              children: [
                VariantIcon(
                  row.iconAssetFor(variants),
                  size: compact ? 40 : _variantIconSize(scale),
                  opacity: value ? 1 : 0.82,
                ),
                Expanded(
                  child: _VariantText(
                    tokens: tokens,
                    language: language,
                    variants: variants,
                    row: row,
                    active: value,
                    scale: scale,
                    compact: compact,
                  ),
                ),
                Container(
                  width: toggleSize,
                  height: toggleSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value
                        ? tokens.colors.gold.withValues(alpha: 0.82)
                        : tokens.colors.black.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: value
                          ? tokens.colors.goldBright
                          : tokens.colors.steel.withValues(alpha: 0.45),
                    ),
                  ),
                  child: value
                      ? MainMenuAssetIcon(
                          fieldPlanToolbarConfirmIconPath,
                          size: toggleSize * 0.63,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VariantRowBackground extends StatelessWidget {
  const VariantRowBackground({
    super.key,
    required this.tokens,
    required this.active,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  });

  final DesignTokens tokens;
  final bool active;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ChromeButtonBackground(
              asset: active
                  ? chromeButtonPrimaryAsset
                  : chromeButtonSecondaryAsset,
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class _VariantText extends StatelessWidget {
  const _VariantText({
    required this.tokens,
    required this.language,
    required this.variants,
    required this.row,
    required this.active,
    required this.scale,
    this.compact = false,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final KolkhozGameVariants variants;
  final VariantRowData row;
  final bool active;
  final double scale;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final titleColor = active
        ? tokens.colors.activeSurfaceText
        : tokens.colors.cardInk;
    final bodyColor = active
        ? tokens.colors.activeSurfaceText
        : tokens.colors.cardInk.withValues(alpha: 0.74);
    final titleSize = compact
        ? DisplayTextSize.headline
        : _variantTitleTextSize(scale);
    final bodySize = compact
        ? DisplayTextSize.caption
        : _variantBodyTextSize(scale);
    final description = row.localizedDescription(language, variants);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: description.isEmpty
          ? 0
          : compact
          ? 4
          : 7 + 3 * scale,
      children: [
        VariantPixelLine(
          height: displayTextSlotHeight(titleSize),
          child: DisplayText(
            row.localizedTitle(language, variants).toUpperCase(),
            color: titleColor,
            size: titleSize,
            variant: DisplayTextWeight.bold,
            maxLines: 1,
            overflow: TextOverflow.clip,
          ),
        ),
        if (description.isNotEmpty)
          VariantPixelLine(
            height: displayTextSlotHeight(bodySize),
            child: DisplayText(
              description,
              color: bodyColor,
              size: bodySize,
              variant: DisplayTextWeight.regular,
              maxLines: 1,
              overflow: TextOverflow.clip,
            ),
          ),
      ],
    );
  }
}

class VariantPixelLine extends StatelessWidget {
  const VariantPixelLine({
    super.key,
    required this.height,
    required this.child,
  });

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: child,
        ),
      ),
    );
  }
}

DisplayTextSize _variantTitleTextSize(double scale) {
  return scale > 0.44 ? DisplayTextSize.cardRank : DisplayTextSize.title;
}

DisplayTextSize _variantBodyTextSize(double scale) {
  return scale > 0.44 ? DisplayTextSize.title : DisplayTextSize.headline;
}

double displayTextSlotHeight(DisplayTextSize size) {
  return switch (size) {
    DisplayTextSize.cardRank => 34,
    DisplayTextSize.title => 29,
    DisplayTextSize.headline => 25,
    DisplayTextSize.caption => 20,
    DisplayTextSize.caption2 => 18,
    DisplayTextSize.small => 16,
    DisplayTextSize.xSmall => 14,
  };
}

double _variantIconSize(double scale) {
  return 55 + 22 * scale;
}
