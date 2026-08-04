from __future__ import annotations

import ctypes
import unittest
from http import HTTPStatus
from pathlib import Path
from unittest import mock

from engine.python.kolkhoz_c_engine import (
    CEngine,
    KCAction,
    KCCard,
    KCEngineSnapshot,
    build_shared_library,
)
from server.kolkhoz_server.contracts import (
    DEFAULT_VARIANTS,
    action_from_json,
    action_in,
    action_to_json,
    card_from_json,
    card_to_json,
    controllers_native,
    listing_json,
    normalize_controllers,
    normalize_variants,
    optional_bool,
    optional_int,
    privacy_safe_action_log,
    snapshot_json,
    variants_native,
)
from server.kolkhoz_server.errors import ServerError
from server.kolkhoz_server.policy import PolicyArtifact


class ContractNormalizationTests(unittest.TestCase):
    def test_normalizes_variants_without_accepting_unknown_fields(self) -> None:
        self.assertEqual(normalize_variants(None), DEFAULT_VARIANTS)
        normalized = normalize_variants({"allowSwap": False, "futureRule": True})
        self.assertFalse(normalized["allowSwap"])
        self.assertNotIn("futureRule", normalized)
        native = variants_native(normalized)
        self.assertFalse(native.allow_swap)
        self.assertFalse(native.pass_cards)
        self.assertTrue(native.wrecker)
        self.assertTrue(native.managed_economy)
        self.assertFalse(native.lotto_rewards)

    def test_passing_remains_available_as_an_explicit_custom_variant(self) -> None:
        normalized = normalize_variants({"passCards": True})

        self.assertTrue(normalized["passCards"])
        self.assertTrue(variants_native(normalized).pass_cards)

    def test_managed_economy_is_mutually_exclusive_with_other_reward_rules(self) -> None:
        managed = normalize_variants(
            {"managedEconomy": True, "lottoRewards": True}
        )
        self.assertTrue(managed["managedEconomy"])
        self.assertFalse(managed["lottoRewards"])
        self.assertTrue(variants_native(managed).managed_economy)

        northern = normalize_variants(
            {"managedEconomy": True, "northernStyle": True}
        )
        self.assertFalse(northern["managedEconomy"])

    def test_normalizes_four_supported_controllers_and_keeps_a_human(self) -> None:
        self.assertEqual(
            normalize_controllers(["neuralAI", "mediumAI"]),
            ["neuralAI", "mediumAI", "human", "human"],
        )
        all_ai = normalize_controllers(["heuristicAI"] * 4)
        self.assertEqual(all_ai[0], "human")
        native = controllers_native(all_ai)
        self.assertEqual(list(native.seats), [0, 1, 1, 1])

    def test_rejects_invalid_contract_scalars(self) -> None:
        for value in (True, "not-an-int"):
            with self.subTest(value=value), self.assertRaises(ServerError) as raised:
                optional_int(value)
            self.assertEqual(raised.exception.status, HTTPStatus.BAD_REQUEST)
        self.assertTrue(optional_bool("yes"))
        self.assertFalse(optional_bool("0"))
        with self.assertRaises(ServerError):
            normalize_controllers(["impossibleAI"])


class ActionContractTests(unittest.TestCase):
    def test_legacy_wrecker_wire_value_maps_to_zero_value_engine_card(self) -> None:
        decoded = card_from_json({"suit": 4, "value": 14})
        self.assertEqual((decoded.suit, decoded.value), (4, 0))
        self.assertEqual(card_to_json(decoded), {"suit": 4, "value": 14})

    def test_portable_action_round_trip_and_membership(self) -> None:
        action = KCAction(8, 2, -1, KCCard(-1, 0), KCCard(1, 7), KCCard(3, 9), 1, -1)
        encoded = action_to_json(action, source="automatic")
        self.assertEqual(encoded["source"], "automatic")
        decoded = action_from_json(encoded)
        self.assertTrue(action_in(decoded, [action]))
        self.assertEqual(
            action_to_json(decoded), {k: v for k, v in encoded.items() if k != "source"}
        )

    def test_missing_optional_cards_use_engine_sentinels(self) -> None:
        action = action_from_json({"kind": 0, "playerID": 1})
        self.assertEqual((action.card.suit, action.card.value), (-1, 0))
        self.assertEqual(action.plot_zone, -1)
        with self.assertRaises(ServerError) as raised:
            action_from_json({"kind": 0})
        self.assertEqual(str(raised.exception), "missing playerID")

    def test_swap_secrets_are_redacted_only_from_other_viewers_before_game_over(
        self,
    ) -> None:
        action = action_to_json(
            KCAction(8, 1, -1, KCCard(-1, 0), KCCard(0, 6), KCCard(2, 9), 0, -1)
        )
        other = privacy_safe_action_log([action], 0, game_over=False)[0]
        owner = privacy_safe_action_log([action], 1, game_over=False)[0]
        finished = privacy_safe_action_log([action], 0, game_over=True)[0]
        self.assertEqual(other["handCard"], {"suit": -1, "value": -1})
        self.assertEqual(owner["handCard"], {"suit": 0, "value": 6})
        self.assertEqual(finished["plotCard"], {"suit": 2, "value": 9})

    def test_pass_card_is_never_exposed_to_other_viewers(self) -> None:
        action = action_to_json(
            KCAction(9, 2, -1, KCCard(3, 12), KCCard(-1, 0), KCCard(-1, 0), -1, -1)
        )
        other = privacy_safe_action_log([action], 0, game_over=False)[0]
        owner = privacy_safe_action_log([action], 2, game_over=False)[0]
        finished = privacy_safe_action_log([action], 0, game_over=True)[0]
        self.assertEqual(other["card"], {"suit": -1, "value": -1})
        self.assertEqual(owner["card"], {"suit": 3, "value": 12})
        self.assertEqual(finished["card"], {"suit": -1, "value": -1})

    def test_requisition_choice_is_private_until_engine_resolution(self) -> None:
        action = action_to_json(
            KCAction(17, 2, -1, KCCard(3, 12), KCCard(-1, 0), KCCard(-1, 0), 0, -1)
        )
        other = privacy_safe_action_log([action], 0, game_over=False)[0]
        owner = privacy_safe_action_log([action], 2, game_over=False)[0]
        self.assertEqual(other["card"], {"suit": -1, "value": -1})
        self.assertEqual(owner["card"], {"suit": 3, "value": 12})


class ProjectionContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.engine = CEngine(build_shared_library())

    def test_requisition_compares_medalists_once_per_failed_field(self) -> None:
        pointer = self.engine.new_engine(
            81001,
            variants=variants_native(
                normalize_variants({"heroOfSovietUnion": False})
            ),
            controllers=controllers_native(["human"] * 4),
        )
        try:
            state = self.engine.snapshot(pointer)
            state.phase = 3
            state.last_winner = 0
            state.current_player = 0
            state.trick_count = 4
            state.last_trick_count = 0
            for suit in range(4):
                state.work_hours[suit] = 40 if suit >= 2 else 0
                state.job_buckets[suit].count = 0
            for player_id in range(4):
                state.players[player_id].hand.count = 0
                state.players[player_id].plot_hidden.count = 0
                state.players[player_id].plot_revealed.count = 0
                state.players[player_id].medals = 1 if player_id < 2 else 0

            player_zero = state.players[0]
            player_zero.plot_hidden.count = 3
            player_zero.plot_hidden.cards[0] = KCCard(0, 10)
            player_zero.plot_hidden.cards[1] = KCCard(1, 10)
            player_zero.plot_hidden.cards[2] = KCCard(1, 8)
            player_one = state.players[1]
            player_one.plot_hidden.count = 2
            player_one.plot_hidden.cards[0] = KCCard(0, 10)
            player_one.plot_hidden.cards[1] = KCCard(1, 7)

            self.engine.apply_action(
                pointer,
                KCAction(6, 0, -1, KCCard(-1, 0), KCCard(-1, 0), KCCard(-1, 0), -1, -1),
            )

            actions = self.engine.legal_actions(pointer)
            self.assertEqual(
                {(action.player_id, action.card.suit, action.card.value) for action in actions},
                {(0, 0, 10), (0, 1, 10), (1, 0, 10)},
            )
            self.engine.apply_action(
                pointer,
                next(action for action in actions if action.player_id == 0 and action.card.suit == 1),
            )
            state = self.engine.snapshot(pointer)
            self.assertEqual(state.players[0].plot_hidden.count, 3)

            self.engine.apply_action(
                pointer,
                next(action for action in self.engine.legal_actions(pointer) if action.player_id == 1),
            )
            state = self.engine.snapshot(pointer)
            self.assertEqual(state.exiled[1].count, 2)
            self.assertEqual(state.requisition_rounds_remaining, 1)

            second_round = self.engine.legal_actions(pointer)
            self.assertEqual(
                {(action.player_id, action.card.value) for action in second_round},
                {(0, 8), (1, 7)},
            )
            for player_id in (0, 1):
                self.engine.apply_action(
                    pointer,
                    next(
                        action
                        for action in self.engine.legal_actions(pointer)
                        if action.player_id == player_id
                    ),
                )

            state = self.engine.snapshot(pointer)
            self.assertEqual(state.requisition_rounds_remaining, 0)
            self.assertEqual(state.exiled[1].count, 3)
            self.assertTrue(
                any(
                    state.players[1].plot_revealed.cards[index].value == 7
                    for index in range(state.players[1].plot_revealed.count)
                )
            )
        finally:
            self.engine.free_engine(pointer)

    def test_hero_is_fully_protected_from_a_saboteur_failure(self) -> None:
        pointer = self.engine.new_engine(
            81002,
            variants=variants_native(normalize_variants({"heroOfSovietUnion": True})),
            controllers=controllers_native(["human"] * 4),
        )
        try:
            state = self.engine.snapshot(pointer)
            state.phase = 3
            state.last_winner = 0
            state.current_player = 0
            state.trick_count = 4
            state.last_trick_count = 0
            state.is_famine = False
            for suit in range(4):
                state.work_hours[suit] = 40
                state.job_buckets[suit].count = 0
            state.job_buckets[0].count = 1
            state.job_buckets[0].cards[0] = KCCard(4, 0)
            for player_id in range(4):
                player = state.players[player_id]
                player.hand.count = 0
                player.plot_hidden.count = 1
                player.plot_revealed.count = 0
                player.plot_hidden.cards[0] = KCCard(0, 13 - player_id)
                player.medals = 4 if player_id == 0 else 0

            self.engine.apply_action(
                pointer,
                KCAction(6, 0, -1, KCCard(-1, 0), KCCard(-1, 0), KCCard(-1, 0), -1, -1),
            )
            self.assertEqual(
                {action.player_id for action in self.engine.legal_actions(pointer)},
                {1, 2, 3},
            )
            for player_id in (1, 2, 3):
                self.engine.apply_action(
                    pointer,
                    next(
                        action
                        for action in self.engine.legal_actions(pointer)
                        if action.player_id == player_id
                    ),
                )

            state = self.engine.snapshot(pointer)
            self.assertEqual(state.exiled[1].count, 3)
            self.assertEqual(state.players[0].plot_hidden.count, 1)
            self.assertFalse(
                any(
                    state.exiled_player_ids[1][index] == 0
                    for index in range(state.exiled[1].count)
                )
            )
        finally:
            self.engine.free_engine(pointer)

    def test_snapshot_exposes_only_the_viewers_private_cards(self) -> None:
        controllers = controllers_native(["human"] * 4)
        pointer = self.engine.new_engine(
            321,
            variants=variants_native(normalize_variants(None)),
            controllers=controllers,
        )
        try:
            viewed = snapshot_json(self.engine, pointer, 0)
            spectator = snapshot_json(self.engine, pointer, None)
        finally:
            self.engine.free_engine(pointer)
        self.assertGreater(len(viewed["players"][0]["hand"]), 0)
        self.assertEqual(viewed["players"][1]["hand"], [])
        self.assertTrue(all(player["hand"] == [] for player in spectator["players"]))
        self.assertTrue(all(pile["cards"] == [] for pile in viewed["jobPiles"]))
        self.assertEqual(
            viewed["exiledPlayers"],
            [{"suit": year, "values": []} for year in range(6)],
        )
        self.assertEqual(
            set(viewed),
            {
                "year",
                "phase",
                "currentPlayer",
                "waitingPlayer",
                "waitingForExternalAction",
                "lead",
                "trumpSelector",
                "trump",
                "trickCount",
                "isFamine",
                "players",
                "jobPiles",
                "revealedJobs",
                "managedRewardOffers",
                "claimedJobs",
                "workHours",
                "jobBuckets",
                "accumulatedJobCards",
                "currentTrick",
                "currentTrickWinner",
                "lastTrick",
                "lastWinner",
                "exiled",
                "exiledPlayers",
                "pendingAssignments",
                "requisitionEvents",
                "transitionEvents",
                "scores",
                "winnerID",
                "swapConfirmed",
                "swapCount",
                "passConfirmed",
                "finalYearTrumpCard",
            },
        )

    def test_managed_economy_reveals_then_swaps_rewards_with_the_planners_hand(
        self,
    ) -> None:
        variants = variants_native(
            normalize_variants({"managedEconomy": True, "lottoRewards": False})
        )
        pointer = self.engine.new_engine(
            42042,
            variants=variants,
            controllers=controllers_native(["human"] * 4),
        )
        try:
            state = self.engine.snapshot(pointer)
            planner = int(state.trump_selector)
            self.assertEqual(state.players[planner].hand.count, 5)
            dealt_aces: list[tuple[int, int]] = []
            for player_id in range(4):
                player = state.players[player_id]
                dealt_aces.extend(
                    (player.plot_hidden.cards[index].suit, 0)
                    for index in range(player.plot_hidden.count)
                    if player.plot_hidden.cards[index].value == 1
                )
                dealt_aces.extend(
                    (player.plot_revealed.cards[index].suit, 1)
                    for index in range(player.plot_revealed.count)
                    if player.plot_revealed.cards[index].value == 1
                )
            self.assertEqual(
                sorted(dealt_aces),
                [(0, 1), (1, 0), (2, 0), (3, 0)],
            )
            self.assertEqual(state.players[planner].plot_revealed.cards[0].suit, 0)
            self.assertTrue(
                all(
                    sorted(
                        state.job_piles[suit].cards[index].value
                        for index in range(state.job_piles[suit].count)
                    )
                    == [2, 3, 4, 5]
                    for suit in range(4)
                )
            )

            for suit in range(4):
                actions = self.engine.legal_actions(pointer)
                self.assertEqual(len(actions), 1)
                self.assertEqual((actions[0].kind, actions[0].suit), (10, suit))
                self.engine.apply_action(pointer, actions[0])

            state = self.engine.snapshot(pointer)
            self.assertEqual(state.players[planner].hand.count, 5)
            self.assertTrue(
                all(state.managed_reward_offers[suit].suit == suit for suit in range(4))
            )
            public = snapshot_json(self.engine, pointer, (planner + 1) % 4)
            self.assertEqual(
                [card["suit"] for card in public["managedRewardOffers"]],
                [0, 1, 2, 3],
            )
            self.assertEqual(public["players"][planner]["hand"], [])
            self.assertEqual(
                public["players"][planner]["revealedPlot"],
                [{"suit": 0, "value": 1}],
            )
            viewer = (planner + 1) % 4
            self.assertTrue(
                all(
                    public["players"][player_id]["hiddenPlotCount"] == 1
                    and (
                        len(public["players"][player_id]["hiddenPlot"]) == 1
                        if player_id == viewer
                        else public["players"][player_id]["hiddenPlot"] == []
                    )
                    for player_id in range(4)
                    if player_id != planner
                )
            )

            # All four reward slots are live at once, while keeping every
            # revealed offer unchanged remains the default provisional layout.
            state.players[planner].hand.cards[0] = KCCard(4, 0)
            actions = self.engine.legal_actions(pointer)
            self.assertEqual(sum(action.kind == 16 for action in actions), 1)
            self.assertTrue(all(action.kind in (15, 16) for action in actions))
            self.assertEqual(
                {action.suit for action in actions if action.kind == 15},
                {0, 1, 2, 3},
            )

            saboteur_swap = next(
                action
                for action in actions
                if action.kind == 15 and action.suit == 0 and action.card.suit == 4
            )
            original_wheat_reward = (
                state.managed_reward_offers[0].suit,
                state.managed_reward_offers[0].value,
            )
            self.engine.apply_action(pointer, saboteur_swap)
            state = self.engine.snapshot(pointer)
            self.assertEqual(state.players[planner].hand.count, 5)
            self.assertEqual(
                (state.revealed_jobs[0].suit, state.revealed_jobs[0].value),
                (4, 0),
            )

            # Before confirmation, swapping the outgoing offer back into the
            # same slot reverses the provisional choice.
            reverse_swap = next(
                action
                for action in self.engine.legal_actions(pointer)
                if action.kind == 15
                and action.suit == 0
                and (action.card.suit, action.card.value) == original_wheat_reward
            )
            self.engine.apply_action(pointer, reverse_swap)
            state = self.engine.snapshot(pointer)
            self.assertEqual(
                (state.revealed_jobs[0].suit, state.revealed_jobs[0].value),
                original_wheat_reward,
            )
            self.assertEqual(state.players[planner].hand.count, 5)

            state = self.engine.snapshot(pointer)
            self.assertEqual(state.players[planner].hand.count, 5)
            self.assertTrue(all(state.has_revealed_job))
            confirm_rewards = next(
                action
                for action in self.engine.legal_actions(pointer)
                if action.kind == 16
            )
            self.engine.apply_action(pointer, confirm_rewards)
            self.assertTrue(
                all(action.kind == 1 for action in self.engine.legal_actions(pointer))
            )

            self.engine.apply_action(pointer, self.engine.legal_actions(pointer)[0])
            state = self.engine.snapshot(pointer)
            self.assertEqual(state.phase, 1)
            self.assertEqual(state.year, 1)
            self.assertTrue(state.swap_confirmed[planner])
            self.assertNotEqual(state.current_player, planner)
            swapping_players: list[int] = []
            while state.phase == 1:
                swapping_players.append(int(state.current_player))
                confirm = next(
                    action
                    for action in self.engine.legal_actions(pointer)
                    if action.kind == 3
                )
                self.engine.apply_action(pointer, confirm)
                state = self.engine.snapshot(pointer)
            self.assertEqual(
                set(swapping_players),
                set(range(4)) - {planner},
            )
            self.assertEqual(state.phase, 2)
        finally:
            self.engine.free_engine(pointer)

    def test_managed_economy_has_no_reward_cards_in_year_five(self) -> None:
        variants = variants_native(
            normalize_variants({"managedEconomy": True, "lottoRewards": False})
        )
        pointer = self.engine.new_engine(
            42043,
            variants=variants,
            controllers=controllers_native(["human"] * 4),
        )
        try:
            state = self.engine.snapshot(pointer)
            state.year = 5
            state.is_famine = True
            self.assertEqual(self.engine.legal_actions(pointer), [])
            self.assertEqual(self.engine.step_automatic(pointer), 1)
            state = self.engine.snapshot(pointer)
            self.assertEqual(state.phase, 1)
            self.assertFalse(any(state.has_revealed_job))
            self.assertTrue(
                all(
                    state.managed_reward_offers[suit].suit == -1
                    for suit in range(4)
                )
            )
        finally:
            self.engine.free_engine(pointer)

    def test_stepwise_final_year_trump_advances_from_planning(self) -> None:
        pointer = self.engine.new_engine(
            42049,
            variants=variants_native(normalize_variants({})),
            controllers=controllers_native(["human"] * 4),
            stepwise_controllers=True,
        )
        try:
            state = self.engine.snapshot(pointer)
            state.phase = 0
            state.year = 5
            state.is_famine = True
            state.current_player = 0
            state.trump_selector = 0
            state.managed_rewards_confirmed = False
            state.pending_final_year_trump_card = KCCard(2, 7)
            state.final_year_trump_card = KCCard(-1, 0)
            for suit in range(4):
                state.managed_reward_offers[suit] = KCCard(-1, 0)
                state.revealed_jobs[suit] = KCCard(-1, 0)
                state.has_revealed_job[suit] = False

            actions = self.engine.legal_actions(pointer)
            self.assertEqual(len(actions), 1)
            self.assertEqual(actions[0].kind, 11)

            self.engine.apply_ai_action_stepwise(pointer, actions[0])

            self.assertNotEqual(self.engine.phase(pointer), 0)
            self.assertTrue(self.engine.legal_actions(pointer))
        finally:
            self.engine.free_engine(pointer)

    def test_managed_economy_returns_unclaimed_rewards_to_worker_deck(self) -> None:
        variants = variants_native(
            normalize_variants({"managedEconomy": True, "lottoRewards": False})
        )
        pointer = self.engine.new_engine(
            42046,
            variants=variants,
            controllers=controllers_native(["human"] * 4),
        )
        try:
            for suit in range(4):
                self.engine.apply_action(pointer, self.engine.legal_actions(pointer)[0])

            state = self.engine.snapshot(pointer)
            unclaimed_rewards = {
                (state.revealed_jobs[suit].suit, state.revealed_jobs[suit].value)
                for suit in range(4)
            }
            state.phase = 4
            state.requisition_plan_count = 0
            state.requisition_plan_index = 0

            self.engine.apply_action(
                pointer,
                KCAction(
                    7,
                    0,
                    -1,
                    KCCard(-1, 0),
                    KCCard(-1, 0),
                    KCCard(-1, 0),
                    -1,
                    -1,
                ),
            )

            state = self.engine.snapshot(pointer)
            dealt_cards = {
                (player.hand.cards[index].suit, player.hand.cards[index].value)
                for player in state.players
                for index in range(player.hand.count)
            }
            north_cards = {
                (state.exiled[1].cards[index].suit, state.exiled[1].cards[index].value)
                for index in range(state.exiled[1].count)
            }
            self.assertEqual(state.year, 2)
            self.assertTrue(unclaimed_rewards <= dealt_cards)
            self.assertTrue(unclaimed_rewards.isdisjoint(north_cards))
        finally:
            self.engine.free_engine(pointer)

    def test_managed_economy_completes_a_full_benchmark_game(self) -> None:
        variants = variants_native(
            normalize_variants({"managedEconomy": True, "lottoRewards": False})
        )
        result = self.engine.lib.kc_run_benchmark_game(ctypes.c_uint64(42044), variants)

        self.assertGreater(result.actions, 0)
        self.assertLess(result.actions, 1000)
        self.assertNotEqual(result.checksum, -999999)

    def test_managed_economy_heuristic_upgrades_every_worthwhile_reward(self) -> None:
        pointer = self.engine.new_engine(
            42045,
            variants=variants_native(
                normalize_variants({"managedEconomy": True, "lottoRewards": False})
            ),
            controllers=controllers_native(["human"] * 4),
        )
        try:
            state = self.engine.snapshot(pointer)
            state.phase = 0
            state.year = 1
            state.current_player = 0
            state.trump_selector = 0
            state.controllers.seats[0] = 1
            state.managed_rewards_confirmed = False
            state.players[0].hand.count = 5
            for suit, value in enumerate((6, 7, 8, 9)):
                state.players[0].hand.cards[suit] = KCCard(suit, value)
                state.managed_reward_offers[suit] = KCCard(suit, value - 4)
                state.revealed_jobs[suit] = KCCard(suit, value - 4)
                state.has_revealed_job[suit] = True
            state.players[0].hand.cards[4] = KCCard(4, 0)

            self.assertEqual(self.engine.phase(pointer), 0)
            self.assertTrue(
                any(action.kind == 15 for action in self.engine.legal_actions(pointer))
            )

            changed_suits: set[int] = set()
            for _ in range(4):
                action = self.engine.heuristic_action(pointer)
                self.assertEqual(action.kind, 15)
                self.assertNotEqual(action.card.suit, 4)
                changed_suits.add(int(action.suit))
                state.controllers.seats[0] = 0
                self.engine.apply_action(pointer, action)
                state.controllers.seats[0] = 1

            self.assertEqual(changed_suits, {0, 1, 2, 3})
            confirm = self.engine.heuristic_action(pointer)
            self.assertEqual(confirm.kind, 16)
            state.controllers.seats[0] = 0
            self.engine.apply_action(pointer, confirm)
            self.assertTrue(self.engine.snapshot(pointer).managed_rewards_confirmed)
        finally:
            self.engine.free_engine(pointer)

    def test_managed_economy_policy_uses_heuristic_reward_choice(self) -> None:
        pointer = self.engine.new_engine(
            42048,
            variants=variants_native(
                normalize_variants({"managedEconomy": True, "lottoRewards": False})
            ),
            controllers=controllers_native(["mediumAI", "human", "human", "human"]),
            stepwise_controllers=True,
        )
        try:
            state = self.engine.snapshot(pointer)
            state.phase = 0
            state.year = 1
            state.current_player = 0
            state.trump_selector = 0
            state.managed_rewards_confirmed = False
            state.players[0].hand.count = 5
            cards = (
                KCCard(4, 0),
                KCCard(1, 8),
                KCCard(2, 9),
                KCCard(2, 6),
                KCCard(3, 1),
            )
            for index, card in enumerate(cards):
                state.players[0].hand.cards[index] = card
            for suit, value in enumerate((5, 4, 5, 5)):
                state.managed_reward_offers[suit] = KCCard(suit, value)
                state.revealed_jobs[suit] = KCCard(suit, value)
                state.has_revealed_job[suit] = True

            model = PolicyArtifact.load(
                Path(__file__).resolve().parents[2] / "policies/medium_policy.json"
            ).c_buffer()
            action = self.engine.policy_action(pointer, model)

            self.assertIsNotNone(action)
            assert action is not None
            self.assertEqual(
                (action.kind, action.suit, action.card.suit, action.card.value),
                (15, 2, 2, 9),
            )
        finally:
            self.engine.free_engine(pointer)

    def test_heuristic_redirects_after_pending_work_completes_a_job(self) -> None:
        pointer = self.engine.new_engine(
            42047,
            variants=variants_native(normalize_variants(None)),
            controllers=controllers_native(["human"] * 4),
        )
        try:
            state = self.engine.snapshot(pointer)
            state.phase = 3
            state.last_winner = 0
            state.current_player = 0
            state.controllers.seats[0] = 1
            state.last_trick_count = 4
            state.players[0].plot_revealed.count = 0
            state.players[0].plot_hidden.count = 0
            cards = ((0, 6), (1, 7), (1, 8), (1, 9))
            for index, (suit, value) in enumerate(cards):
                state.last_trick[index].player_id = index
                state.last_trick[index].card = KCCard(suit, value)
                state.pending_assignment_targets[index] = -1
            for suit in range(4):
                state.claimed_jobs[suit] = False
                state.work_hours[suit] = 0
            state.work_hours[0] = 35
            state.has_revealed_job[0] = True
            state.revealed_jobs[0] = KCCard(0, 2)
            state.has_revealed_job[1] = True
            state.revealed_jobs[1] = KCCard(1, 5)

            finishing_action = self.engine.heuristic_action(pointer)
            self.assertEqual((finishing_action.kind, finishing_action.target_suit), (5, 0))
            state.controllers.seats[0] = 0
            self.engine.apply_action(pointer, finishing_action)
            state.controllers.seats[0] = 1

            redirected_action = self.engine.heuristic_action(pointer)
            self.assertEqual((redirected_action.kind, redirected_action.target_suit), (5, 1))
        finally:
            self.engine.free_engine(pointer)

    def test_heuristic_uses_exact_subset_to_complete_a_job(self) -> None:
        pointer = self.engine.new_engine(
            42048,
            variants=variants_native(normalize_variants(None)),
            controllers=controllers_native(["human"] * 4),
        )
        try:
            state = self.engine.snapshot(pointer)
            state.phase = 3
            state.last_winner = 0
            state.current_player = 0
            state.controllers.seats[0] = 1
            state.last_trick_count = 4
            state.players[0].plot_revealed.count = 0
            state.players[0].plot_hidden.count = 0
            cards = ((0, 8), (1, 7), (1, 6), (0, 1))
            for index, (suit, value) in enumerate(cards):
                state.last_trick[index].player_id = index
                state.last_trick[index].card = KCCard(suit, value)
                state.pending_assignment_targets[index] = -1
            for suit in range(4):
                state.claimed_jobs[suit] = False
                state.work_hours[suit] = 0
                state.has_revealed_job[suit] = False
            state.work_hours[0] = 27

            first_action = self.engine.heuristic_action(pointer)
            self.assertEqual(
                (first_action.card.value, first_action.target_suit),
                (7, 0),
            )
            state.controllers.seats[0] = 0
            self.engine.apply_action(pointer, first_action)
            state.controllers.seats[0] = 1

            second_action = self.engine.heuristic_action(pointer)
            self.assertEqual(
                (second_action.card.value, second_action.target_suit),
                (6, 0),
            )
            state.controllers.seats[0] = 0
            self.engine.apply_action(pointer, second_action)
            state.controllers.seats[0] = 1

            redirected_action = self.engine.heuristic_action(pointer)
            self.assertEqual(redirected_action.target_suit, 1)
        finally:
            self.engine.free_engine(pointer)

    def test_heuristic_values_one_high_plot_card_over_two_low_cards(self) -> None:
        pointer = self.engine.new_engine(
            42049,
            variants=variants_native(normalize_variants(None)),
            controllers=controllers_native(["human"] * 4),
        )
        try:
            state = self.engine.snapshot(pointer)
            state.phase = 3
            state.last_winner = 0
            state.current_player = 0
            state.controllers.seats[0] = 1
            state.last_trick_count = 4
            cards = ((0, 8), (1, 7), (1, 6), (0, 5))
            for index, (suit, value) in enumerate(cards):
                state.last_trick[index].player_id = index
                state.last_trick[index].card = KCCard(suit, value)
                state.pending_assignment_targets[index] = -1
            for suit in range(4):
                state.claimed_jobs[suit] = False
                state.work_hours[suit] = 0
                state.has_revealed_job[suit] = False

            player = state.players[0]
            player.plot_hidden.count = 0
            player.plot_revealed.count = 3
            player.has_won_trick_this_year = True
            player.plot_revealed.cards[0] = KCCard(0, 13)
            player.plot_revealed.cards[1] = KCCard(1, 1)
            player.plot_revealed.cards[2] = KCCard(1, 2)

            action = self.engine.heuristic_action(pointer)
            self.assertEqual(action.target_suit, 0)
        finally:
            self.engine.free_engine(pointer)

    def test_heuristic_starves_job_with_vulnerable_opponent_value(self) -> None:
        pointer = self.engine.new_engine(
            42050,
            variants=variants_native(normalize_variants(None)),
            controllers=controllers_native(["human"] * 4),
        )
        try:
            state = self.engine.snapshot(pointer)
            state.phase = 3
            state.last_winner = 0
            state.current_player = 0
            state.controllers.seats[0] = 1
            state.last_trick_count = 4
            cards = ((0, 8), (1, 7), (1, 6), (0, 5))
            for index, (suit, value) in enumerate(cards):
                state.last_trick[index].player_id = index
                state.last_trick[index].card = KCCard(suit, value)
                state.pending_assignment_targets[index] = -1
            for suit in range(4):
                state.claimed_jobs[suit] = False
                state.work_hours[suit] = 0
                state.has_revealed_job[suit] = False
            state.players[0].plot_revealed.count = 0
            state.players[0].plot_hidden.count = 0

            opponent = state.players[1]
            opponent.plot_hidden.count = 0
            opponent.plot_revealed.count = 1
            opponent.plot_revealed.cards[0] = KCCard(0, 13)
            opponent.medals = 0
            ineligible_action = self.engine.heuristic_action(pointer)
            self.assertEqual(ineligible_action.target_suit, 0)

            opponent.medals = 1
            vulnerable_action = self.engine.heuristic_action(pointer)
            self.assertEqual(vulnerable_action.target_suit, 1)

            state.work_hours[0] = 27
            state.has_revealed_job[0] = True
            state.revealed_jobs[0] = KCCard(0, 2)
            added_to_vulnerable_job = 0
            for _ in range(4):
                action = self.engine.heuristic_action(pointer)
                if action.target_suit == 0:
                    added_to_vulnerable_job += action.card.value
                state.controllers.seats[0] = 0
                self.engine.apply_action(pointer, action)
                state.controllers.seats[0] = 1
            self.assertLess(added_to_vulnerable_job, 13)
        finally:
            self.engine.free_engine(pointer)

    def test_snapshot_reads_work_hours_through_the_c_api(self) -> None:
        pointer = self.engine.new_engine(
            322,
            variants=variants_native(normalize_variants(None)),
            controllers=controllers_native(["human"] * 4),
        )
        try:
            state = ctypes.cast(pointer, ctypes.POINTER(KCEngineSnapshot)).contents
            state.work_hours[0] = -20
            with mock.patch.object(
                self.engine,
                "work_hours",
                side_effect=[0, 9, 18, 27],
            ) as work_hours:
                viewed = snapshot_json(self.engine, pointer, 0)
        finally:
            self.engine.free_engine(pointer)

        self.assertEqual(
            viewed["workHours"],
            [
                {"suit": 0, "value": 0},
                {"suit": 1, "value": 9},
                {"suit": 2, "value": 18},
                {"suit": 3, "value": 27},
            ],
        )
        self.assertEqual(work_hours.call_count, 4)

    def test_snapshot_pairs_each_exiled_card_with_its_player(self) -> None:
        pointer = self.engine.new_engine(
            654,
            variants=variants_native(normalize_variants(None)),
            controllers=controllers_native(["human"] * 4),
        )
        try:
            state = ctypes.cast(pointer, ctypes.POINTER(KCEngineSnapshot)).contents
            state.exiled[2].cards[0] = KCCard(1, 10)
            state.exiled[2].cards[1] = KCCard(3, 7)
            state.exiled[2].count = 2
            state.exiled_player_ids[2][0] = 1
            state.exiled_player_ids[2][1] = 3
            viewed = snapshot_json(self.engine, pointer, 0)
        finally:
            self.engine.free_engine(pointer)
        self.assertEqual(viewed["exiledPlayers"][2], {"suit": 2, "values": [1, 3]})

    def test_snapshot_reveals_every_cellar_only_after_game_over(self) -> None:
        pointer = self.engine.new_engine(
            655,
            variants=variants_native(normalize_variants(None)),
            controllers=controllers_native(["human"] * 4),
        )
        try:
            state = ctypes.cast(pointer, ctypes.POINTER(KCEngineSnapshot)).contents
            opponent = state.players[1]
            opponent.plot_hidden.cards[0] = KCCard(1, 10)
            opponent.plot_hidden.count = 1
            opponent.stacks[0].hidden[0] = KCCard(3, 7)
            opponent.stacks[0].hidden_count = 1
            opponent.stack_count = 1

            active = snapshot_json(self.engine, pointer, 0)
            state.phase = 5
            finished = snapshot_json(self.engine, pointer, 0)
        finally:
            self.engine.free_engine(pointer)

        self.assertEqual(active["players"][1]["hiddenPlot"], [])
        self.assertEqual(active["players"][1]["hiddenPlotCount"], 1)
        self.assertEqual(active["players"][1]["stacks"][0]["hidden"], [])
        self.assertEqual(active["players"][1]["stacks"][0]["hiddenCount"], 1)
        self.assertEqual(
            finished["players"][1]["hiddenPlot"],
            [{"suit": 1, "value": 10}],
        )
        self.assertEqual(
            finished["players"][1]["stacks"][0]["hidden"],
            [{"suit": 3, "value": 7}],
        )

    def test_listing_keeps_flutter_envelope_names(self) -> None:
        listing = listing_json(
            session_id="s",
            invite_code="invite",
            open_seats=[3, 1],
            occupied_seats={2, 0},
            controllers=["human"] * 4,
            ranked=False,
            browser_joinable=True,
            player_profiles=[],
            seat_presence=[],
            turn_player_id=None,
            turn_deadline_at=None,
            action_log_count=0,
            started=False,
            lobby_countdown_ends_at=None,
            created_at=1.0,
            expires_at=2.0,
        )
        self.assertEqual(listing["occupiedSeats"], [0, 2])
        self.assertEqual(listing["openSeats"], [3, 1])
        self.assertEqual(
            set(listing),
            {
                "sessionID",
                "inviteCode",
                "openSeats",
                "occupiedSeats",
                "controllers",
                "ranked",
                "browserJoinable",
                "playerProfiles",
                "seatPresence",
                "turnPlayerID",
                "turnDeadlineAt",
                "actionLogCount",
                "started",
                "lobbyCountdownEndsAt",
                "createdAt",
                "expiresAt",
            },
        )


if __name__ == "__main__":
    unittest.main()
