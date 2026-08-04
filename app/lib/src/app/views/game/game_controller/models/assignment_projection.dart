import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_constants.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';

List<TableCard> assignmentControlCards(TableViewModel model) {
  if (model.table.phase != phaseAssignment) {
    return const [];
  }
  final assignedIDs = assignedAssignmentCardIDs(model);
  return model.table.lastTrick.plays
      .map((play) => play.card)
      .where((card) => !assignedIDs.contains(card.id))
      .toList(growable: false);
}

Trick visibleAssignmentTrick(TableViewModel model) {
  if (model.table.phase != phaseAssignment) {
    return model.table.trick;
  }
  final assignedIDs = assignedAssignmentCardIDs(model);
  return Trick(
    plays: model.table.lastTrick.plays
        .where((play) => !assignedIDs.contains(play.card.id))
        .toList(growable: false),
    winnerSeatID: model.table.lastTrick.winnerSeatID,
  );
}

Set<String> assignedAssignmentCardIDs(TableViewModel model) {
  return {
    for (final job in model.table.jobs)
      for (final card in job.assignedCards) card.id,
  };
}

bool assignmentCardHasLegalTarget(TableViewModel model, String? cardID) =>
    cardID != null &&
    model.legalActions.any(
      (action) =>
          action.kind == actionAssign && action.engineAction.card?.id == cardID,
    );

TableViewModel withAssignmentDraft(
  TableViewModel model,
  Iterable<EngineAction> draft, {
  required int playerID,
  required bool canSubmit,
}) {
  if (model.table.phase != phaseAssignment) {
    return model;
  }
  final draftByCardID = {
    for (final action in draft)
      if (action.card != null && action.targetSuit != null)
        action.card!.id: action,
  };
  if (draftByCardID.isEmpty) {
    return model;
  }
  final cardsByID = {
    for (final play in model.table.lastTrick.plays) play.card.id: play.card,
  };
  final alreadyAssigned = assignedAssignmentCardIDs(model);
  final jobs = [
    for (final job in model.table.jobs)
      Job(
        suit: job.suit,
        hours: job.hours,
        requiredHours: job.requiredHours,
        claimed: job.claimed,
        reward: job.reward,
        assignedCards: [
          ...job.assignedCards,
          for (final entry in draftByCardID.entries)
            if (entry.value.targetSuit == job.suit &&
                !alreadyAssigned.contains(entry.key) &&
                cardsByID[entry.key] != null)
              _pendingAssignmentCard(cardsByID[entry.key]!),
        ],
        validAssignmentTarget: job.validAssignmentTarget,
        highlighted: job.highlighted,
      ),
  ];
  final currentCardIDs = cardsByID.keys.toSet();
  final assignedCardIDs = {
    for (final job in jobs)
      for (final card in job.assignedCards)
        if (currentCardIDs.contains(card.id)) card.id,
  };
  final legalActions = [...model.legalActions];
  if (canSubmit &&
      currentCardIDs.isNotEmpty &&
      assignedCardIDs.containsAll(currentCardIDs) &&
      !legalActions.any((action) => action.kind == actionSubmitAssignments)) {
    legalActions.add(
      LegalAction(
        kind: actionSubmitAssignments,
        label: 'Confirm',
        engineAction: EngineAction(
          kind: actionSubmitAssignments,
          playerID: playerID,
        ),
      ),
    );
  }
  return TableViewModel(
    viewer: model.viewer,
    table: TableState(
      year: model.table.year,
      phase: model.table.phase,
      phasePrompt: model.table.phasePrompt,
      currentPlayerID: model.table.currentPlayerID,
      trump: model.table.trump,
      isFamine: model.table.isFamine,
      maxTricks: model.table.maxTricks,
      seats: model.table.seats,
      jobs: jobs,
      trick: model.table.trick,
      lastTrick: model.table.lastTrick,
      requisitionEvents: model.table.requisitionEvents,
      exiledByYear: model.table.exiledByYear,
      scoreboard: model.table.scoreboard,
      gameResult: model.table.gameResult,
      finalYearTrumpCard: model.table.finalYearTrumpCard,
      managedRewardOffers: model.table.managedRewardOffers,
    ),
    panels: model.panels,
    selection: model.selection,
    legalActions: legalActions,
    seed: model.seed,
  );
}

TableCard _pendingAssignmentCard(TableCard card) => TableCard(
  id: card.id,
  suit: card.suit,
  value: card.value,
  rank: card.rank,
  selected: false,
  highlighted: false,
  pending: true,
  provisional: true,
  assignmentRound: card.assignmentRound,
  nomenclature: card.nomenclature,
  ownerSeatID: card.ownerSeatID,
);

LegalAction? assignmentActionForJob(TableViewModel model, Job job) {
  final selectedCardID = model.selection.assignmentCardID;
  if (selectedCardID == null) {
    return null;
  }
  return assignmentActionForCardAndJob(model, selectedCardID, job);
}

LegalAction? assignmentActionForCardAndJob(
  TableViewModel model,
  String cardID,
  Job job,
) {
  for (final action in model.legalActions) {
    final engineAction = action.engineAction;
    if (action.kind == actionAssign &&
        engineAction.card?.id == cardID &&
        engineAction.targetSuit == job.suit) {
      return action;
    }
  }
  return null;
}
