from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from server.kolkhoz_server.ai import AutomaticAdvancer, ModelCache
from server.kolkhoz_server.engine import KolkhozCEngineFactory
from server.kolkhoz_server.policy import PolicyArtifact
from server.kolkhoz_server.runtime import GameRuntime
from server.kolkhoz_server.store import SQLiteEventStore


class RealCEngineRecoveryTests(unittest.TestCase):
    def test_affected_population_seeds_finish_stepwise(self) -> None:
        repo_root = Path(__file__).resolve().parents[2]
        models = ModelCache(
            {
                "mediumAI": repo_root / "policies/medium_policy.json",
                "neuralAI": repo_root / "policies/hard_policy.json",
            },
            lambda path: PolicyArtifact.load(path).c_buffer(),
        )
        cases = (
            (
                2810686489648982463,
                ["neuralAI", "heuristicAI", "heuristicAI", "mediumAI"],
            ),
            (
                1088494256005499699,
                ["mediumAI", "heuristicAI", "heuristicAI", "mediumAI"],
            ),
        )
        for seed, controllers in cases:
            with self.subTest(seed=seed), tempfile.TemporaryDirectory() as temporary:
                runtime = GameRuntime(
                    SQLiteEventStore(Path(temporary) / "population-seed.sqlite3"),
                    shard_count=1,
                    automatic_advancer=AutomaticAdvancer(models),
                )
                try:
                    runtime.create_game(
                        seed=seed,
                        variants={"variants": {}, "controllers": controllers},
                        session_id=f"population-{seed}",
                    )
                    for _ in range(250):
                        update = runtime.state(f"population-{seed}")
                        if update.state["phase"] == 5:
                            break
                        runtime.advance_automatic(f"population-{seed}", now=0)
                    else:
                        self.fail("population seed did not finish within 1,000 actions")
                finally:
                    runtime.close()

                self.assertEqual(update.state["phase"], 5)
                self.assertLess(update.revision, 1000)

    def test_server_replays_legacy_collapsed_ai_events(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            database = Path(temporary) / "legacy-ai.sqlite3"
            store = SQLiteEventStore(database)
            settings = {
                "variants": {},
                "controllers": [
                    "human",
                    "heuristicAI",
                    "heuristicAI",
                    "heuristicAI",
                ],
            }
            factory = KolkhozCEngineFactory()
            legacy = factory.create_legacy(1, settings)
            try:
                action = legacy.heuristic_action()  # type: ignore[attr-defined]
                legacy.apply_ai_action(action)
                expected = legacy.view()
                store.create_game(
                    "legacy-ai",
                    1,
                    settings,
                    engine_contract_version=1,
                )
                payload = dict(action)
                payload["source"] = "automatic"
                store.append(
                    "legacy-ai",
                    expected_revision=0,
                    kind="action",
                    payload=payload,
                )
            finally:
                legacy.close()
                store.close()

            replacement = GameRuntime(SQLiteEventStore(database), shard_count=1)
            try:
                recovered = replacement.state("legacy-ai").state
            finally:
                replacement.close()

            self.assertEqual(recovered, expected)

    def test_server_keeps_nonhuman_managed_planner_stepwise(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            runtime = GameRuntime(
                SQLiteEventStore(Path(temporary) / "ai-planner.sqlite3"),
                shard_count=1,
                automatic_advancer=AutomaticAdvancer(
                    ModelCache({}, lambda path: object())
                ),
            )
            try:
                created = runtime.create_game(
                    seed=1,
                    variants={
                        "variants": {},
                        "controllers": [
                            "human",
                            "heuristicAI",
                            "heuristicAI",
                            "heuristicAI",
                        ],
                    },
                    session_id="ai-planner",
                )

                self.assertEqual(created.revision, 0)
                self.assertEqual(created.state["phase"], 0)
                self.assertEqual(created.state["legalActions"][0]["kind"], 10)
                self.assertNotEqual(created.state["legalActions"][0]["playerID"], 0)

                applied = runtime.advance_automatic("ai-planner", now=0)
                planning = runtime.state("ai-planner")
                waiting = runtime.advance_automatic("ai-planner", now=0)
                next_applied = runtime.advance_automatic("ai-planner", now=10)
                next_planning = runtime.state("ai-planner")
                events = runtime.events("ai-planner")
            finally:
                runtime.close()

            self.assertEqual(applied, 4)
            self.assertEqual(planning.revision, 4)
            self.assertEqual(planning.state["phase"], 0)
            self.assertEqual(
                [event.payload["kind"] for event in events[:4]],
                [10, 10, 10, 10],
            )
            self.assertTrue(planning.state["managedRewardOffers"])
            self.assertTrue(
                all(
                    action["kind"] in (15, 16)
                    for action in planning.state["legalActions"]
                )
            )
            self.assertEqual(waiting, 0)
            self.assertEqual(next_applied, 1)
            self.assertEqual(next_planning.revision, 5)
            self.assertEqual(next_planning.state["phase"], 0)
            self.assertEqual(len(events), 5)

    def test_server_reveals_default_managed_rewards_before_human_planning(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            database = Path(temporary) / "central-planner.sqlite3"
            runtime = GameRuntime(
                SQLiteEventStore(database),
                shard_count=1,
                automatic_advancer=AutomaticAdvancer(
                    ModelCache({}, lambda path: object())
                ),
            )
            try:
                runtime.create_game(
                    seed=42042,
                    variants={"variants": {}, "controllers": ["human"] * 4},
                    session_id="central-planner",
                )

                applied = runtime.advance_automatic("central-planner", now=0)
                update = runtime.state("central-planner")
                events = runtime.events("central-planner")
            finally:
                runtime.close()

            self.assertEqual(applied, 4)
            self.assertEqual(update.revision, 4)
            self.assertTrue(update.state["legalActions"])
            self.assertTrue(
                all(
                    action["kind"] in (15, 16)
                    for action in update.state["legalActions"]
                )
            )
            self.assertEqual(
                sum(action["kind"] == 16 for action in update.state["legalActions"]),
                1,
            )
            self.assertEqual([event.payload["kind"] for event in events], [10] * 4)
            self.assertTrue(
                all(event.payload["source"] == "automatic" for event in events)
            )

    def test_replacement_worker_replays_identical_authoritative_c_state(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            database = Path(temporary) / "real-engine.sqlite3"
            settings = {
                "variants": {},
                "controllers": ["human"] * 4,
            }
            first = GameRuntime(SQLiteEventStore(database), shard_count=2)
            first.create_game(seed=42042, variants=settings, session_id="real-replay")
            before = first.state("real-replay").state
            legal = before["legalActions"]
            self.assertTrue(legal)
            first.submit_action("real-replay", expected_revision=0, action=legal[0])
            committed = first.state("real-replay").state
            first.close()

            replacement = GameRuntime(SQLiteEventStore(database), shard_count=3)
            try:
                recovered = replacement.state("real-replay").state
            finally:
                replacement.close()

            self.assertEqual(recovered, committed)


if __name__ == "__main__":
    unittest.main()
