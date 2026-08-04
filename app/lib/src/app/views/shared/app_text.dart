import 'package:flutter/widgets.dart';
import 'package:kolkhoz_app/l10n/app_localizations.dart';

export 'package:kolkhoz_app/l10n/app_localizations.dart';

/// Keys that still need runtime selection for descriptor data.
/// Ordinary UI strings use the generated [AppLocalizations] accessors directly.
enum KolkhozText {
  handConsoleContinue,
  handConsoleReviewRequisition,
  handConsoleWaitingForValue1,
  handConsoleWaitingForValue1ToDeclareTrump,
  handConsoleWaitingForValue1ToAssign,
  handConsoleWaitingForValue1ToPlay,
  handConsoleWaitingForValue1ToSwap,
  kolkhozappAccept,
  kolkhozappAddComrade,
  kolkhozappCasual,
  kolkhozappComradeCode,
  kolkhozappComradeRequestAccepted,
  kolkhozappComradeRequestDeclined,
  kolkhozappRanked,
  languageSwitchTitle,
  lobbyCreateGame,
  lobbyPlayDemo,
  lowerbaractionsFinish,
  phaseAssignment,
  phaseGameOver,
  phasePlanning,
  phaseRequisition,
  phaseSwap,
  phaseTrick,
  ruleSummary1Body,
  ruleSummary1Title,
  ruleSummary2Body,
  ruleSummary2Title,
  ruleSummary3Body,
  ruleSummary3Title,
  ruleSummary4Body,
  ruleSummary4Title,
  ruleSummary5Body,
  ruleSummary5Title,
  ruleSummary6Body,
  ruleSummary6Title,
  ruleSummary7Body,
  ruleSummary7Title,
  ruleSummary8Body,
  ruleSummary8Title,
  suitBeets,
  suitPotatoes,
  suitSunflower,
  suitWheat,
  tabledisplayYou,
  variantAccumulationDescription,
  variantAccumulationTitle,
  variantDemoModeDescription,
  variantDemoModeTitle,
  variantFinalYearTrumpDescription,
  variantFinalYearTrumpTitle,
  variantHeroDescription,
  variantHeroTitle,
  variantLottoRewardsDescription,
  variantLottoRewardsTitle,
  variantManagedEconomyDescription,
  variantManagedEconomyTitle,
  variantMedalsDescription,
  variantMedalsTitle,
  variantMiceDescription,
  variantMiceTitle,
  variantNomenklaturaDescription,
  variantNomenklaturaTitle,
  variantNorthernStyleDescription,
  variantNorthernStyleTitle,
  variantOrdenNachalnikuDescription,
  variantOrdenNachalnikuTitle,
  variantPassCardsDescription,
  variantPassCardsTitle,
  variantSwapDescription,
  variantSwapTitle,
  variantWreckerDescription,
  variantWreckerTitle,
}

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get strings => AppLocalizations.of(this);
}

String lookupKolkhozText(
  KolkhozText key, {
  required bool russian,
  Map<String, Object?> args = const {},
}) {
  final strings = lookupAppLocalizations(Locale(russian ? 'ru' : 'en'));
  return switch (key) {
    KolkhozText.handConsoleContinue => strings.handConsoleContinue,
    KolkhozText.handConsoleReviewRequisition =>
      strings.handConsoleReviewRequisition,
    KolkhozText.handConsoleWaitingForValue1 =>
      strings.handConsoleWaitingForValue1(value1: args['value1']!),
    KolkhozText.handConsoleWaitingForValue1ToDeclareTrump =>
      strings.handConsoleWaitingForValue1ToDeclareTrump(
        value1: args['value1']!,
      ),
    KolkhozText.handConsoleWaitingForValue1ToAssign =>
      strings.handConsoleWaitingForValue1ToAssign(value1: args['value1']!),
    KolkhozText.handConsoleWaitingForValue1ToPlay =>
      strings.handConsoleWaitingForValue1ToPlay(value1: args['value1']!),
    KolkhozText.handConsoleWaitingForValue1ToSwap =>
      strings.handConsoleWaitingForValue1ToSwap(value1: args['value1']!),
    KolkhozText.kolkhozappAccept => strings.kolkhozappAccept,
    KolkhozText.kolkhozappAddComrade => strings.kolkhozappAddComrade,
    KolkhozText.kolkhozappCasual => strings.kolkhozappCasual,
    KolkhozText.kolkhozappComradeCode => strings.kolkhozappComradeCode,
    KolkhozText.kolkhozappComradeRequestAccepted =>
      strings.kolkhozappComradeRequestAccepted,
    KolkhozText.kolkhozappComradeRequestDeclined =>
      strings.kolkhozappComradeRequestDeclined,
    KolkhozText.kolkhozappRanked => strings.kolkhozappRanked,
    KolkhozText.languageSwitchTitle => strings.languageSwitchTitle,
    KolkhozText.lobbyCreateGame => strings.lobbyCreateGame,
    KolkhozText.lobbyPlayDemo => strings.lobbyPlayDemo,
    KolkhozText.lowerbaractionsFinish => strings.lowerbaractionsFinish,
    KolkhozText.phaseAssignment => strings.phaseAssignment,
    KolkhozText.phaseGameOver => strings.phaseGameOver,
    KolkhozText.phasePlanning => strings.phasePlanning,
    KolkhozText.phaseRequisition => strings.phaseRequisition,
    KolkhozText.phaseSwap => strings.phaseSwap,
    KolkhozText.phaseTrick => strings.phaseTrick,
    KolkhozText.ruleSummary1Body => strings.ruleSummary1Body,
    KolkhozText.ruleSummary1Title => strings.ruleSummary1Title,
    KolkhozText.ruleSummary2Body => strings.ruleSummary2Body,
    KolkhozText.ruleSummary2Title => strings.ruleSummary2Title,
    KolkhozText.ruleSummary3Body => strings.ruleSummary3Body,
    KolkhozText.ruleSummary3Title => strings.ruleSummary3Title,
    KolkhozText.ruleSummary4Body => strings.ruleSummary4Body,
    KolkhozText.ruleSummary4Title => strings.ruleSummary4Title,
    KolkhozText.ruleSummary5Body => strings.ruleSummary5Body,
    KolkhozText.ruleSummary5Title => strings.ruleSummary5Title,
    KolkhozText.ruleSummary6Body => strings.ruleSummary6Body,
    KolkhozText.ruleSummary6Title => strings.ruleSummary6Title,
    KolkhozText.ruleSummary7Body => strings.ruleSummary7Body,
    KolkhozText.ruleSummary7Title => strings.ruleSummary7Title,
    KolkhozText.ruleSummary8Body => strings.ruleSummary8Body,
    KolkhozText.ruleSummary8Title => strings.ruleSummary8Title,
    KolkhozText.suitBeets => strings.suitBeets,
    KolkhozText.suitPotatoes => strings.suitPotatoes,
    KolkhozText.suitSunflower => strings.suitSunflower,
    KolkhozText.suitWheat => strings.suitWheat,
    KolkhozText.tabledisplayYou => strings.tabledisplayYou,
    KolkhozText.variantAccumulationDescription =>
      strings.variantAccumulationDescription,
    KolkhozText.variantAccumulationTitle => strings.variantAccumulationTitle,
    KolkhozText.variantDemoModeDescription =>
      strings.variantDemoModeDescription,
    KolkhozText.variantDemoModeTitle => strings.variantDemoModeTitle,
    KolkhozText.variantFinalYearTrumpDescription =>
      strings.variantFinalYearTrumpDescription,
    KolkhozText.variantFinalYearTrumpTitle =>
      strings.variantFinalYearTrumpTitle,
    KolkhozText.variantHeroDescription => strings.variantHeroDescription,
    KolkhozText.variantHeroTitle => strings.variantHeroTitle,
    KolkhozText.variantLottoRewardsDescription =>
      strings.variantLottoRewardsDescription,
    KolkhozText.variantLottoRewardsTitle => strings.variantLottoRewardsTitle,
    KolkhozText.variantManagedEconomyDescription =>
      strings.variantManagedEconomyDescription,
    KolkhozText.variantManagedEconomyTitle =>
      strings.variantManagedEconomyTitle,
    KolkhozText.variantMedalsDescription => strings.variantMedalsDescription,
    KolkhozText.variantMedalsTitle => strings.variantMedalsTitle,
    KolkhozText.variantMiceDescription => strings.variantMiceDescription,
    KolkhozText.variantMiceTitle => strings.variantMiceTitle,
    KolkhozText.variantNomenklaturaDescription =>
      strings.variantNomenklaturaDescription,
    KolkhozText.variantNomenklaturaTitle => strings.variantNomenklaturaTitle,
    KolkhozText.variantNorthernStyleDescription =>
      strings.variantNorthernStyleDescription,
    KolkhozText.variantNorthernStyleTitle => strings.variantNorthernStyleTitle,
    KolkhozText.variantOrdenNachalnikuDescription =>
      strings.variantOrdenNachalnikuDescription,
    KolkhozText.variantOrdenNachalnikuTitle =>
      strings.variantOrdenNachalnikuTitle,
    KolkhozText.variantPassCardsDescription =>
      strings.variantPassCardsDescription,
    KolkhozText.variantPassCardsTitle => strings.variantPassCardsTitle,
    KolkhozText.variantSwapDescription => strings.variantSwapDescription,
    KolkhozText.variantSwapTitle => strings.variantSwapTitle,
    KolkhozText.variantWreckerDescription => strings.variantWreckerDescription,
    KolkhozText.variantWreckerTitle => strings.variantWreckerTitle,
  };
}
