import 'package:kolkhoz_app/src/app/views/game/game_controller/models/engine_values.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_constants.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/game_ui_state.dart';

int assignmentTargetRunEnd(List<EngineTransitionEvent> events, int startIndex) {
  final first = events[startIndex];
  if (first.kind != kcTransitionAssignmentTargeted ||
      !first.card.isValid ||
      first.targetSuit < 0) {
    return startIndex;
  }
  var endIndex = startIndex;
  while (endIndex + 1 < events.length) {
    final next = events[endIndex + 1];
    if (next.kind != kcTransitionAssignmentTargeted ||
        !next.card.isValid ||
        next.targetSuit != first.targetSuit) {
      break;
    }
    endIndex++;
  }
  final run = events.sublist(startIndex, endIndex + 1);
  return run.length == 4 &&
          run.every((event) => event.card.suit == first.targetSuit)
      ? endIndex
      : startIndex;
}

bool needsFinalPresentationBoundary(
  TableViewModel presented,
  TableViewModel authoritative,
) =>
    presented.table.phase != authoritative.table.phase ||
    presented.table.year != authoritative.table.year;

/// Builds the visible state at each semantic boundary in one engine dispatch.
///
/// The engine remains authoritative for the final model. Intermediate models
/// only keep later mutations hidden until their event reaches the front of the
/// presentation queue.
List<TableViewModel> projectPresentationBatch({
  required TableViewModel before,
  required TableViewModel after,
  required List<EngineTransitionEvent> events,
}) {
  if (events.isEmpty) {
    return const [];
  }

  final assignmentCardIDs = {
    for (final event in events)
      if (event.kind == kcTransitionAssignmentTargeted && event.card.isValid)
        _eventCardID(event),
  };
  final assignedSoFar = <String>{};
  var assignmentPlayerID = before.table.phase == phaseAssignment
      ? before.table.currentPlayerID
      : null;
  var visible = before;
  final projected = <TableViewModel>[];

  for (final event in events) {
    if (event.kind == kcTransitionAssignmentOpened) {
      assignmentPlayerID = event.playerID;
    }
    final assignmentPanel = assignmentPlayerID == after.viewer.seatID
        ? panelJobs
        : panelBrigade;
    visible = switch (event.kind) {
      kcTransitionCardMoved when event.toZone == kcObjectZoneCurrentTrick =>
        _withPlayedTrickCard(visible, after, event),
      kcTransitionTrickResolved => _withResolvedTrick(
        before: before,
        after: after,
        assignmentCardIDs: assignmentCardIDs,
      ),
      kcTransitionAssignmentOpened => _withVisibleAssignments(
        after,
        assignmentCardIDs: assignmentCardIDs,
        assignedSoFar: assignedSoFar,
        activePanel: assignmentPanel,
      ),
      kcTransitionAssignmentTargeted => _withVisibleAssignments(
        after,
        assignmentCardIDs: assignmentCardIDs,
        assignedSoFar: assignedSoFar..add(_eventCardID(event)),
        activePanel: assignmentPanel,
      ),
      kcTransitionCardMoved when _isRewardClaim(event) => _holdBrigadePhase(
        after,
        previous: visible,
      ),
      kcTransitionCardMoved when _isYearEndCellarMove(event, after) =>
        _holdBrigadePhase(after, previous: visible),
      _ => after,
    };
    final futureEvents = events.skip(projected.length + 1);
    projected.add(
      _withoutFutureCellarMoves(
        _withoutFutureRewardClaims(
          visible,
          before: before,
          futureEvents: futureEvents,
        ),
        before: before,
        finalModel: after,
        futureEvents: futureEvents,
      ),
    );
  }
  return projected;
}

bool _isRewardClaim(EngineTransitionEvent event) =>
    event.fromZone == kcObjectZoneRevealedJob &&
    event.toZone == kcObjectZonePlotRevealed &&
    event.card.isValid;

TableViewModel _holdBrigadePhase(
  TableViewModel after, {
  required TableViewModel previous,
}) => _withTable(
  after,
  table: _copyTable(
    after.table,
    phase: previous.table.phase,
    phasePrompt: previous.table.phasePrompt,
  ),
  panels: Panels(active: panelBrigade, available: after.panels.available),
);

bool _isYearEndCellarMove(
  EngineTransitionEvent event,
  TableViewModel finalModel,
) =>
    finalModel.table.phase == phaseRequisition &&
    event.kind == kcTransitionCardMoved &&
    event.fromZone == kcObjectZoneHand &&
    event.toZone == kcObjectZonePlotHidden &&
    event.toOwner >= 0 &&
    event.card.isValid;

TableViewModel _withoutFutureCellarMoves(
  TableViewModel model, {
  required TableViewModel before,
  required TableViewModel finalModel,
  required Iterable<EngineTransitionEvent> futureEvents,
}) {
  final moves = [
    for (final event in futureEvents)
      if (_isYearEndCellarMove(event, finalModel)) event,
  ];
  if (moves.isEmpty) {
    return model;
  }
  final seats = [
    for (final seat in model.table.seats)
      _seatBeforeFutureCellarMoves(
        seat,
        beforeSeat: before.table.seats
            .where((candidate) => candidate.id == seat.id)
            .firstOrNull,
        moves: moves.where((event) => event.toOwner == seat.id).toList(),
      ),
  ];
  return _withTable(model, table: _copyTable(model.table, seats: seats));
}

Seat _seatBeforeFutureCellarMoves(
  Seat seat, {
  required Seat? beforeSeat,
  required List<EngineTransitionEvent> moves,
}) {
  if (moves.isEmpty) {
    return seat;
  }
  final cardIDs = {for (final event in moves) _eventCardID(event)};
  final restoredCards = [
    for (final card in beforeSeat?.hand ?? const <TableCard>[])
      if (cardIDs.contains(card.id) &&
          !seat.hand.any((candidate) => candidate.id == card.id))
        card,
  ];
  final redactedCardCount = moves.length - restoredCards.length;
  final hiddenCardCount = seat.plot.hiddenCardCount;
  final priorHiddenCardCount = hiddenCardCount == null
      ? null
      : hiddenCardCount > moves.length
      ? hiddenCardCount - moves.length
      : 0;
  return Seat(
    id: seat.id,
    name: seat.name,
    controller: seat.controller,
    portraitAsset: seat.portraitAsset,
    isViewer: seat.isViewer,
    isCurrentTurn: seat.isCurrentTurn,
    isBrigadeLeader: seat.isBrigadeLeader,
    hand: [...seat.hand, ...restoredCards],
    hiddenHandCount: seat.hiddenHandCount + redactedCardCount,
    plot: PlotState(
      revealed: seat.plot.revealed,
      hidden: [
        for (final card in seat.plot.hidden)
          if (!cardIDs.contains(card.id)) card,
      ],
      stacks: seat.plot.stacks,
      hiddenCardCount: priorHiddenCardCount,
    ),
    medals: seat.medals,
    bankedMedals: seat.bankedMedals,
    visibleScore: seat.visibleScore,
    profileStats: seat.profileStats,
    profileUserID: seat.profileUserID,
    statusText: seat.statusText,
  );
}

TableViewModel _withoutFutureRewardClaims(
  TableViewModel model, {
  required TableViewModel before,
  required Iterable<EngineTransitionEvent> futureEvents,
}) {
  final claims = {
    for (final event in futureEvents)
      if (event.kind == kcTransitionCardMoved && _isRewardClaim(event))
        _eventCardID(event): event,
  };
  if (claims.isEmpty) {
    return model;
  }

  final rewardCards = {
    for (final seat in model.table.seats)
      for (final card in seat.plot.revealed)
        if (claims.containsKey(card.id)) card.id: card,
  };
  final seats = [
    for (final seat in model.table.seats)
      _seatWithoutRevealedCards(seat, claims.keys.toSet()),
  ];
  final jobs = [
    for (final job in model.table.jobs)
      if (claims.values.any(
        (event) => engineSuitName(event.targetSuit) == job.suit,
      ))
        Job(
          suit: job.suit,
          hours: job.hours,
          requiredHours: job.requiredHours,
          claimed:
              before.table.jobs
                  .where((candidate) => candidate.suit == job.suit)
                  .firstOrNull
                  ?.claimed ??
              job.claimed,
          reward:
              before.table.jobs
                  .where((candidate) => candidate.suit == job.suit)
                  .map((candidate) => candidate.reward)
                  .firstOrNull ??
              rewardCards.values
                  .where((card) => card.suit == job.suit)
                  .firstOrNull,
          assignedCards: job.assignedCards,
          validAssignmentTarget: job.validAssignmentTarget,
          highlighted: job.highlighted,
        )
      else
        job,
  ];
  return _withTable(
    model,
    table: _copyTable(model.table, seats: seats, jobs: jobs),
  );
}

Seat _seatWithoutRevealedCards(Seat seat, Set<String> cardIDs) {
  final removedValue = seat.plot.revealed
      .where((card) => cardIDs.contains(card.id))
      .fold<int>(0, (total, card) => total + card.value);
  return Seat(
    id: seat.id,
    name: seat.name,
    controller: seat.controller,
    portraitAsset: seat.portraitAsset,
    isViewer: seat.isViewer,
    isCurrentTurn: seat.isCurrentTurn,
    isBrigadeLeader: seat.isBrigadeLeader,
    hand: seat.hand,
    hiddenHandCount: seat.hiddenHandCount,
    plot: PlotState(
      revealed: [
        for (final card in seat.plot.revealed)
          if (!cardIDs.contains(card.id)) card,
      ],
      hidden: seat.plot.hidden,
      stacks: seat.plot.stacks,
      hiddenCardCount: seat.plot.hiddenCardCount,
    ),
    medals: seat.medals,
    bankedMedals: seat.bankedMedals,
    visibleScore: seat.visibleScore - removedValue,
    profileStats: seat.profileStats,
    profileUserID: seat.profileUserID,
    statusText: seat.statusText,
  );
}

TableViewModel _withPlayedTrickCard(
  TableViewModel visible,
  TableViewModel finalModel,
  EngineTransitionEvent event,
) {
  final cardID = _eventCardID(event);
  final card =
      visible.table.seats
          .expand((seat) => seat.hand)
          .where((card) => card.id == cardID)
          .firstOrNull ??
      finalModel.table.lastTrick.plays
          .where((play) => play.card.id == cardID)
          .map((play) => play.card)
          .firstOrNull;
  if (card == null) {
    return visible;
  }
  final playedCard = TableCard(
    id: card.id,
    suit: card.suit,
    value: card.value,
    rank: card.rank,
    selected: false,
    highlighted: false,
    pending: card.pending,
    assignmentRound: card.assignmentRound,
    nomenclature: card.nomenclature,
    ownerSeatID: card.ownerSeatID,
  );

  final finalSeat = finalModel.table.seats
      .where((seat) => seat.id == event.playerID)
      .firstOrNull;
  final seats = [
    for (final seat in visible.table.seats)
      if (seat.id == event.playerID && finalSeat != null)
        _seatWithHand(
          seat,
          hand: finalSeat.hand,
          hiddenHandCount: finalSeat.hiddenHandCount,
        )
      else
        seat,
  ];
  final plays = [
    for (final play in visible.table.trick.plays)
      if (play.card.id != cardID) play,
    TrickPlay(seatID: event.playerID, card: playedCard),
  ];
  final winnerSeatID = event.trickWinnerID >= 0
      ? event.trickWinnerID
      : finalModel.table.trick.plays.any((play) => play.card.id == cardID)
      ? finalModel.table.trick.winnerSeatID
      : finalModel.table.lastTrick.plays.any((play) => play.card.id == cardID)
      ? finalModel.table.lastTrick.winnerSeatID
      : visible.table.trick.winnerSeatID;
  return _withTable(
    visible,
    table: _copyTable(
      visible.table,
      seats: seats,
      trick: Trick(plays: plays, winnerSeatID: winnerSeatID),
    ),
    panels: Panels(
      active: panelBrigade,
      available: finalModel.panels.available,
    ),
    selection: finalModel.selection,
  );
}

TableViewModel _withResolvedTrick({
  required TableViewModel before,
  required TableViewModel after,
  required Set<String> assignmentCardIDs,
}) {
  final jobs = _jobsWithVisibleAssignments(
    after.table.jobs,
    assignmentCardIDs: assignmentCardIDs,
    assignedSoFar: const {},
  );
  return _withTable(
    after,
    table: _copyTable(
      after.table,
      phase: before.table.phase,
      phasePrompt: before.table.phasePrompt,
      jobs: jobs,
    ),
    panels: Panels(active: panelBrigade, available: after.panels.available),
  );
}

TableViewModel _withVisibleAssignments(
  TableViewModel after, {
  required Set<String> assignmentCardIDs,
  required Set<String> assignedSoFar,
  required String activePanel,
}) => _withTable(
  after,
  table: _copyTable(
    after.table,
    phase: phaseAssignment,
    jobs: _jobsWithVisibleAssignments(
      after.table.jobs,
      assignmentCardIDs: assignmentCardIDs,
      assignedSoFar: assignedSoFar,
    ),
  ),
  panels: Panels(active: activePanel, available: after.panels.available),
);

List<Job> _jobsWithVisibleAssignments(
  List<Job> jobs, {
  required Set<String> assignmentCardIDs,
  required Set<String> assignedSoFar,
}) => [
  for (final job in jobs)
    Job(
      suit: job.suit,
      hours: job.hours,
      requiredHours: job.requiredHours,
      claimed: job.claimed,
      reward: job.reward,
      assignedCards: [
        for (final card in job.assignedCards)
          if (!assignmentCardIDs.contains(card.id) ||
              assignedSoFar.contains(card.id))
            card,
      ],
      validAssignmentTarget: job.validAssignmentTarget,
      highlighted: job.highlighted,
    ),
];

String _eventCardID(EngineTransitionEvent event) =>
    '${engineSuitName(event.card.suit) ?? 'unknown'}-${event.card.value}';

Seat _seatWithHand(
  Seat seat, {
  required List<TableCard> hand,
  required int hiddenHandCount,
}) => Seat(
  id: seat.id,
  name: seat.name,
  controller: seat.controller,
  portraitAsset: seat.portraitAsset,
  isViewer: seat.isViewer,
  isCurrentTurn: seat.isCurrentTurn,
  isBrigadeLeader: seat.isBrigadeLeader,
  hand: hand,
  hiddenHandCount: hiddenHandCount,
  plot: seat.plot,
  medals: seat.medals,
  bankedMedals: seat.bankedMedals,
  visibleScore: seat.visibleScore,
  profileStats: seat.profileStats,
  profileUserID: seat.profileUserID,
  statusText: seat.statusText,
);

TableViewModel _withTable(
  TableViewModel model, {
  required TableState table,
  Panels? panels,
  SelectionState? selection,
}) => TableViewModel(
  viewer: model.viewer,
  table: table,
  panels: panels ?? model.panels,
  selection: selection ?? model.selection,
  legalActions: const [],
  seed: model.seed,
);

TableState _copyTable(
  TableState table, {
  String? phase,
  Prompt? phasePrompt,
  List<Seat>? seats,
  List<Job>? jobs,
  Trick? trick,
}) => TableState(
  year: table.year,
  phase: phase ?? table.phase,
  phasePrompt: phasePrompt ?? table.phasePrompt,
  currentPlayerID: table.currentPlayerID,
  trump: table.trump,
  isFamine: table.isFamine,
  maxTricks: table.maxTricks,
  seats: seats ?? table.seats,
  jobs: jobs ?? table.jobs,
  trick: trick ?? table.trick,
  lastTrick: table.lastTrick,
  requisitionEvents: table.requisitionEvents,
  exiledByYear: table.exiledByYear,
  scoreboard: table.scoreboard,
  gameResult: table.gameResult,
  finalYearTrumpCard: table.finalYearTrumpCard,
);
