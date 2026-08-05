#include "KolkhozCEngineInternal.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>

KCCard kc_no_card(void) {
    return (KCCard){ .suit = -1, .value = 0 };
}

bool kc_card_equal(KCCard a, KCCard b) {
    return a.suit == b.suit && a.value == b.value;
}

bool kc_card_is_wrecker(KCCard card) {
    return card.suit == KC_SUIT_WRECKER && card.value == KC_WRECKER_VALUE;
}

bool kc_card_valid(KCCard card) {
    return (card.suit >= 0 && card.suit < KC_SUIT_COUNT && card.value > 0) ||
        kc_card_is_wrecker(card);
}

bool kc_card_matches_suit(KCCard card, int32_t suit) {
    return suit >= 0 &&
        suit < KC_SUIT_COUNT &&
        kc_card_valid(card) &&
        (card.suit == suit || kc_card_is_wrecker(card));
}

int32_t kc_lead_suit(const KCEngine *engine) {
    if (!engine || engine->current_trick_count <= 0) {
        return KC_NO_SUIT;
    }
    KCCard lead = engine->current_trick[0].card;
    return kc_card_is_wrecker(lead) ? KC_NO_SUIT : lead.suit;
}

static void kc_process_automatic_turns(KCEngine *engine);
static int32_t kc_engine_step_automatic_impl(KCEngine *engine);
static int32_t kc_engine_apply_action(KCEngine *engine, KCAction action);
static bool kc_step_requisition(KCEngine *engine);
static void kc_append_exiled(KCEngine *engine, KCCard card, int32_t player_id);
static bool kc_requisition_card_eligible(const KCEngine *engine, int32_t player_id, KCCard card);
static int32_t kc_requisition_highest_value(const KCEngine *engine, int32_t player_id);
static int32_t kc_commit_requisition_choice(KCEngine *engine, int32_t player_id, KCCard card);

void kc_engine_begin_transition_batch(KCEngine *engine) {
    if (!engine) return;
    if (engine->transition_batch_depth == 0) {
        engine->transition_event_count = 0;
    }
    engine->transition_batch_depth++;
}

void kc_engine_end_transition_batch(KCEngine *engine) {
    if (engine && engine->transition_batch_depth > 0) {
        engine->transition_batch_depth--;
    }
}

static void kc_emit_transition(KCEngine *engine, KCTransitionEvent event) {
    if (!engine || engine->transition_event_count >= KC_MAX_TRANSITION_EVENTS) {
        return;
    }
    if (event.kind != KC_TRANSITION_CARD_MOVED ||
        event.to_zone != KC_OBJECT_ZONE_CURRENT_TRICK) {
        event.trick_winner = KC_NO_PLAYER;
    }
    engine->transition_events[engine->transition_event_count++] = event;
}

static int32_t kc_single_assignment_target(const KCEngine *engine) {
    int32_t only_target = KC_NO_SUIT;
    int32_t target_count = 0;
    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        bool legal = false;
        for (int32_t i = 0; i < engine->last_trick_count; i++) {
            if (kc_card_matches_suit(engine->last_trick[i].card, suit)) {
                legal = true;
                break;
            }
        }
        if (legal) {
            only_target = suit;
            target_count++;
            if (target_count > 1) {
                return KC_NO_SUIT;
            }
        }
    }
    return target_count == 1 ? only_target : KC_NO_SUIT;
}

static void kc_prefill_single_assignment_target(KCEngine *engine) {
    int32_t target = kc_single_assignment_target(engine);
    if (target < 0) {
        return;
    }
    for (int32_t i = 0; i < engine->last_trick_count; i++) {
        engine->pending_assignment_targets[i] = target;
        kc_emit_transition(engine, (KCTransitionEvent){
            .kind = KC_TRANSITION_ASSIGNMENT_TARGETED,
            .player_id = engine->last_trick[i].player_id,
            .card = engine->last_trick[i].card,
            .from_zone = KC_OBJECT_ZONE_LAST_TRICK,
            .to_zone = KC_OBJECT_ZONE_PENDING_ASSIGNMENT,
            .from_owner = engine->last_trick[i].player_id,
            .to_owner = target,
            .target_suit = target
        });
    }
}

static uint64_t kc_next(KCEngine *engine) {
    if (engine->rng_state == 0) {
        engine->rng_state = 1;
    }
    engine->rng_state = engine->rng_state * 6364136223846793005ULL + 1442695040888963407ULL;
    return engine->rng_state;
}

static uint64_t kc_multiply_high(uint64_t lhs, uint64_t rhs) {
    uint64_t lhs_low = (uint32_t)lhs;
    uint64_t lhs_high = lhs >> 32;
    uint64_t rhs_low = (uint32_t)rhs;
    uint64_t rhs_high = rhs >> 32;
    uint64_t low_product = lhs_low * rhs_low;
    uint64_t cross_left = lhs_low * rhs_high;
    uint64_t cross_right = lhs_high * rhs_low;
    uint64_t carry = (low_product >> 32) + (uint32_t)cross_left + (uint32_t)cross_right;
    return lhs_high * rhs_high + (cross_left >> 32) + (cross_right >> 32) + (carry >> 32);
}

static uint64_t kc_random_below(KCEngine *engine, uint64_t upper_bound) {
    return kc_multiply_high(kc_next(engine), upper_bound);
}

static double kc_uniform(KCEngine *engine) {
    return (double)(kc_next(engine) >> 11) / (double)(1ULL << 53);
}

static void kc_list_clear(KCCardList *list) {
    list->count = 0;
}

static void kc_list_append(KCCardList *list, KCCard card) {
    if (list->count < KC_MAX_CARDS) {
        list->cards[list->count++] = card;
    }
}

static int32_t kc_list_find(const KCCardList *list, KCCard card) {
    for (int32_t i = 0; i < list->count; i++) {
        if (kc_card_equal(list->cards[i], card)) {
            return i;
        }
    }
    return -1;
}

static bool kc_list_contains(const KCCardList *list, KCCard card) {
    return kc_list_find(list, card) >= 0;
}

static KCCard kc_list_remove_at(KCCardList *list, int32_t index) {
    KCCard card = list->cards[index];
    for (int32_t i = index; i + 1 < list->count; i++) {
        list->cards[i] = list->cards[i + 1];
    }
    list->count--;
    return card;
}

static KCCard kc_list_pop_last(KCCardList *list) {
    if (list->count <= 0) {
        return kc_no_card();
    }
    return list->cards[--list->count];
}

static void kc_list_append_unique(KCCardList *list, KCCard card) {
    if (!kc_list_contains(list, card)) {
        kc_list_append(list, card);
    }
}

static void kc_shuffle(KCEngine *engine, KCCardList *list) {
    if (list->count < 2) {
        return;
    }
    for (int32_t i = 0; i + 1 < list->count; i++) {
        int32_t j = i + (int32_t)kc_random_below(engine, (uint64_t)(list->count - i));
        KCCard tmp = list->cards[i];
        list->cards[i] = list->cards[j];
        list->cards[j] = tmp;
    }
}

static void kc_reset_year_work(KCEngine *engine) {
    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        engine->claimed_jobs[suit] = false;
        engine->work_hours[suit] = 0;
        kc_list_clear(&engine->job_buckets[suit]);
        for (int32_t i = 0; i < KC_MAX_CARDS; i++) {
            engine->job_bucket_tricks[suit][i] = 0;
        }
    }
}

static void kc_clear_last_swap(KCEngine *engine) {
    engine->has_last_swap = false;
    engine->last_swap_player_id = KC_NO_PLAYER;
    engine->last_swap_plot_zone = -1;
    engine->last_swap_plot_index = -1;
    engine->last_swap_hand_index = -1;
    engine->last_swap_new_plot_card = kc_no_card();
}

static int32_t kc_variant_max_years(KCVariants variants) {
    if (variants.max_years < 1) return KC_MAX_YEARS;
    if (variants.max_years > KC_MAX_YEARS) return KC_MAX_YEARS;
    return variants.max_years;
}

void kc_variants_kolkhoz(KCVariants *variants) {
    memset(variants, 0, sizeof(*variants));
    variants->deck_type = 52;
    variants->max_years = KC_MAX_YEARS;
    variants->nomenclature = false;
    variants->allow_swap = true;
    variants->hero_of_soviet_union = true;
    variants->wrecker = true;
    variants->final_year_trump = true;
    variants->pass_cards = false;
    variants->highest_cards_requisition = true;
    variants->lotto_rewards = false;
    variants->managed_economy = true;
}

void kc_controllers_all_external(KCControllers *controllers) {
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        controllers->seats[player_id] = KC_CONTROLLER_EXTERNAL;
    }
}

void kc_controllers_default_single_player(KCControllers *controllers) {
    kc_controllers_all_external(controllers);
    for (int32_t player_id = 1; player_id < KC_PLAYER_COUNT; player_id++) {
        controllers->seats[player_id] = KC_CONTROLLER_HEURISTIC_AI;
    }
}

void kc_controllers_set(KCControllers *controllers, int32_t player_id, int32_t controller) {
    if (player_id < 0 || player_id >= KC_PLAYER_COUNT) {
        return;
    }
    controllers->seats[player_id] = controller;
}

static bool kc_controller_is_external(int32_t controller) {
    return controller == KC_CONTROLLER_EXTERNAL;
}

static bool kc_controller_is_automatic(int32_t controller) {
    return controller == KC_CONTROLLER_HEURISTIC_AI;
}

bool kc_controller_is_policy(int32_t controller) {
    return controller == KC_CONTROLLER_POLICY_AI;
}

static void kc_make_players(KCEngine *engine) {
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        KCPlayer *player = &engine->players[player_id];
        memset(player, 0, sizeof(*player));
        player->id = player_id;
        player->is_human = kc_controller_is_external(engine->controllers.seats[player_id]);
    }
}

static void kc_clear_revealed_jobs(KCEngine *engine) {
    engine->managed_rewards_confirmed = false;
    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        engine->has_revealed_job[suit] = false;
        engine->revealed_jobs[suit] = kc_no_card();
        engine->managed_reward_offers[suit] = kc_no_card();
    }
}

static bool kc_managed_economy_active(const KCEngine *engine) {
    return engine->variants.managed_economy && engine->year < KC_MAX_YEARS;
}

static int32_t kc_next_reward_to_reveal(const KCEngine *engine) {
    if (engine->variants.managed_economy && engine->year >= KC_MAX_YEARS) {
        return KC_NO_SUIT;
    }
    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        if (kc_managed_economy_active(engine)) {
            if (!kc_card_valid(engine->managed_reward_offers[suit])) return suit;
        } else if (!engine->has_revealed_job[suit]) {
            return suit;
        }
    }
    return KC_NO_SUIT;
}

static bool kc_managed_rewards_ready_for_swaps(const KCEngine *engine) {
    return kc_managed_economy_active(engine) &&
        kc_next_reward_to_reveal(engine) == KC_NO_SUIT &&
        !engine->managed_rewards_confirmed;
}

static bool kc_reveal_managed_reward(KCEngine *engine, int32_t suit) {
    if (!kc_valid_suit(suit) ||
        kc_card_valid(engine->managed_reward_offers[suit]) ||
        engine->job_piles[suit].count <= 0) {
        return false;
    }
    KCCard card = kc_list_pop_last(&engine->job_piles[suit]);
    if (!kc_card_valid(card)) return false;
    engine->managed_reward_offers[suit] = card;
    engine->revealed_jobs[suit] = card;
    engine->has_revealed_job[suit] = true;
    kc_emit_transition(engine, (KCTransitionEvent){
        .kind = KC_TRANSITION_CARD_MOVED,
        .player_id = engine->trump_selector,
        .card = card,
        .from_zone = KC_OBJECT_ZONE_JOB_PILE,
        .to_zone = KC_OBJECT_ZONE_REVEALED_JOB,
        .from_owner = suit,
        .to_owner = suit,
        .target_suit = suit
    });
    return true;
}

static bool kc_assign_managed_reward(KCEngine *engine, int32_t target_suit, KCCard card) {
    if (!kc_managed_rewards_ready_for_swaps(engine) ||
        !kc_valid_suit(target_suit) ||
        !kc_card_matches_suit(card, target_suit)) {
        return false;
    }
    KCCard outgoing_reward = engine->revealed_jobs[target_suit];
    if (!kc_card_valid(outgoing_reward)) return false;
    KCCardList *hand = &engine->players[engine->trump_selector].hand;
    int32_t card_index = kc_list_find(hand, card);
    if (card_index < 0) return false;
    kc_list_remove_at(hand, card_index);
    kc_list_append(hand, outgoing_reward);
    engine->revealed_jobs[target_suit] = card;
    kc_emit_transition(engine, (KCTransitionEvent){
        .kind = KC_TRANSITION_CARD_MOVED,
        .player_id = engine->trump_selector,
        .card = outgoing_reward,
        .from_zone = KC_OBJECT_ZONE_REVEALED_JOB,
        .to_zone = KC_OBJECT_ZONE_HAND,
        .from_owner = target_suit,
        .to_owner = engine->trump_selector,
        .target_suit = target_suit
    });
    kc_emit_transition(engine, (KCTransitionEvent){
        .kind = KC_TRANSITION_CARD_MOVED,
        .player_id = engine->trump_selector,
        .card = card,
        .from_zone = KC_OBJECT_ZONE_HAND,
        .to_zone = KC_OBJECT_ZONE_REVEALED_JOB,
        .from_owner = engine->trump_selector,
        .to_owner = target_suit,
        .target_suit = target_suit
    });
    return true;
}

static bool kc_reveal_job(KCEngine *engine, int32_t suit) {
    if (!kc_valid_suit(suit) || engine->has_revealed_job[suit]) return false;
    KCCard card = engine->variants.deck_type == 36
        ? (engine->job_piles[suit].count > 0 ? engine->job_piles[suit].cards[0] : kc_no_card())
        : kc_list_pop_last(&engine->job_piles[suit]);
    if (!kc_card_valid(card)) return false;
    engine->revealed_jobs[suit] = card;
    engine->has_revealed_job[suit] = true;
    kc_emit_transition(engine, (KCTransitionEvent){
        .kind = KC_TRANSITION_CARD_MOVED,
        .player_id = engine->current_player,
        .card = card,
        .from_zone = KC_OBJECT_ZONE_JOB_PILE,
        .to_zone = KC_OBJECT_ZONE_REVEALED_JOB,
        .from_owner = suit,
        .to_owner = suit,
        .target_suit = suit
    });
    return true;
}

static bool kc_card_in_stacks(const KCPlayer *player, KCCard card) {
    for (int32_t stack_index = 0; stack_index < player->stack_count; stack_index++) {
        const KCPlotStack *stack = &player->stacks[stack_index];
        for (int32_t i = 0; i < stack->revealed_count; i++) {
            if (kc_card_equal(stack->revealed[i], card)) {
                return true;
            }
        }
        for (int32_t i = 0; i < stack->hidden_count; i++) {
            if (kc_card_equal(stack->hidden[i], card)) {
                return true;
            }
        }
    }
    return false;
}

static bool kc_is_used_worker_card(const KCEngine *engine, KCCard card) {
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        const KCPlayer *player = &engine->players[player_id];
        if (kc_list_contains(&player->hand, card) ||
            kc_list_contains(&player->plot_revealed, card) ||
            kc_list_contains(&player->plot_hidden, card) ||
            kc_card_in_stacks(player, card)) {
            return true;
        }
    }
    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        if (kc_list_contains(&engine->job_piles[suit], card) ||
            (engine->has_revealed_job[suit] && kc_card_equal(engine->revealed_jobs[suit], card)) ||
            kc_list_contains(&engine->accumulated_job_cards[suit], card) ||
            kc_list_contains(&engine->job_buckets[suit], card)) {
            return true;
        }
    }
    for (int32_t i = 0; i < engine->current_trick_count; i++) {
        if (kc_card_equal(engine->current_trick[i].card, card)) {
            return true;
        }
    }
    for (int32_t i = 0; i < engine->last_trick_count; i++) {
        if (kc_card_equal(engine->last_trick[i].card, card)) {
            return true;
        }
    }
    if (!engine->variants.orden_nachalniku) {
        for (int32_t year = 0; year <= KC_MAX_YEARS; year++) {
            if (kc_list_contains(&engine->exiled[year], card)) {
                return true;
            }
        }
    }
    return false;
}

static void kc_make_worker_deck(KCEngine *engine, KCCardList *deck) {
    kc_list_clear(deck);
    int32_t low_value = engine->variants.deck_type == 36 ? 6 : 1;
    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        for (int32_t value = low_value; value <= 13; value++) {
            KCCard card = { .suit = suit, .value = value };
            if (!kc_is_used_worker_card(engine, card)) {
                kc_list_append(deck, card);
            }
        }
    }
    if (engine->variants.wrecker) {
        KCCard wrecker = { .suit = KC_SUIT_WRECKER, .value = KC_WRECKER_VALUE };
        if (!kc_is_used_worker_card(engine, wrecker)) {
            kc_list_append(deck, wrecker);
        }
    }
    for (int32_t i = 0; i < engine->drunkard_replacements.count; i++) {
        kc_list_append_unique(deck, engine->drunkard_replacements.cards[i]);
    }
    kc_shuffle(engine, deck);
}

static KCCard kc_tutorial_famine_plot_card_for_suit(
    const KCEngine *engine,
    int32_t suit
) {
    KCCard selected = kc_no_card();
    const KCPlayer *learner = &engine->players[0];
    const KCCardList *plots[2] = {
        &learner->plot_revealed,
        &learner->plot_hidden
    };
    for (int32_t plot_index = 0; plot_index < 2; plot_index++) {
        const KCCardList *plot = plots[plot_index];
        for (int32_t index = 0; index < plot->count; index++) {
            KCCard candidate = plot->cards[index];
            if (candidate.suit < 0 ||
                candidate.suit >= KC_SUIT_COUNT ||
                (suit >= 0 && candidate.suit != suit)) {
                continue;
            }
            if (!kc_card_valid(selected) || candidate.value > selected.value) {
                selected = candidate;
            }
        }
    }
    return selected;
}

static KCCard kc_tutorial_famine_saved_card(
    const KCEngine *engine,
    const KCCardList *deck
) {
    KCCard selected = kc_no_card();
    const KCPlayer *learner = &engine->players[0];
    const KCCardList *plots[2] = {
        &learner->plot_revealed,
        &learner->plot_hidden
    };
    for (int32_t plot_index = 0; plot_index < 2; plot_index++) {
        const KCCardList *plot = plots[plot_index];
        for (int32_t index = 0; index < plot->count; index++) {
            KCCard candidate = plot->cards[index];
            if (candidate.suit < 0 || candidate.suit >= KC_SUIT_COUNT) {
                continue;
            }
            int32_t available_cards = 0;
            for (int32_t deck_index = 0; deck_index < deck->count; deck_index++) {
                KCCard available = deck->cards[deck_index];
                if (available.suit == candidate.suit) {
                    available_cards++;
                }
            }
            if (available_cards >= 1 &&
                (!kc_card_valid(selected) ||
                 candidate.value > selected.value)) {
                selected = candidate;
            }
        }
    }
    return selected;
}

static KCCard kc_take_tutorial_card(
    KCCardList *deck,
    int32_t suit,
    bool highest,
    int32_t below_value
) {
    int32_t selected_index = KC_NO_PLAYER;
    for (int32_t index = 0; index < deck->count; index++) {
        KCCard candidate = deck->cards[index];
        if (candidate.suit != suit ||
            (below_value > 0 && candidate.value >= below_value)) {
            continue;
        }
        if (selected_index < 0 ||
            (highest && candidate.value > deck->cards[selected_index].value) ||
            (!highest && candidate.value < deck->cards[selected_index].value)) {
            selected_index = index;
        }
    }
    return selected_index >= 0
        ? kc_list_remove_at(deck, selected_index)
        : kc_no_card();
}

static KCCard kc_take_tutorial_famine_filler(
    KCCardList *deck,
    int32_t trump_suit,
    int32_t off_suit,
    int32_t closing_value
) {
    int32_t selected_index = KC_NO_PLAYER;
    for (int32_t index = 0; index < deck->count; index++) {
        KCCard candidate = deck->cards[index];
        if (candidate.suit < 0 ||
            candidate.suit >= KC_SUIT_COUNT ||
            candidate.suit == trump_suit ||
            (candidate.suit == off_suit &&
             candidate.value >= closing_value)) {
            continue;
        }
        if (selected_index < 0 ||
            candidate.value > deck->cards[selected_index].value) {
            selected_index = index;
        }
    }
    return selected_index >= 0
        ? kc_list_remove_at(deck, selected_index)
        : kc_no_card();
}

static void kc_deal_tutorial_famine_hands(KCEngine *engine) {
    KCCardList deck;
    kc_make_worker_deck(engine, &deck);
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        kc_list_clear(&engine->players[player_id].hand);
    }

    KCCard saved_off_suit = kc_tutorial_famine_saved_card(engine, &deck);
    int32_t off_suit = kc_card_valid(saved_off_suit)
        ? saved_off_suit.suit
        : KC_SUIT_POTATO;
    int32_t suit_counts[KC_SUIT_COUNT] = {0};
    for (int32_t index = 0; index < deck.count; index++) {
        KCCard candidate = deck.cards[index];
        if (candidate.suit >= 0 && candidate.suit < KC_SUIT_COUNT) {
            suit_counts[candidate.suit]++;
        }
    }
    int32_t trump_suit = off_suit == 0 ? 1 : 0;
    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        if (suit != off_suit &&
            suit_counts[suit] > suit_counts[trump_suit]) {
            trump_suit = suit;
        }
    }
    int32_t void_suit = KC_NO_SUIT;
    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        if (suit == off_suit || suit == trump_suit) {
            continue;
        }
        if (void_suit < 0 || suit_counts[suit] > suit_counts[void_suit]) {
            void_suit = suit;
        }
    }
    int32_t filler_suit = KC_NO_SUIT;
    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        if (suit != off_suit &&
            suit != trump_suit &&
            suit != void_suit) {
            filler_suit = suit;
            break;
        }
    }
    engine->tutorial_famine_trump_suit = trump_suit;
    engine->tutorial_famine_off_suit = off_suit;
    engine->tutorial_famine_void_suit = void_suit;
    engine->pending_final_year_trump_card =
        kc_take_tutorial_card(&deck, trump_suit, false, 0);
    engine->final_year_trump_card = kc_no_card();

    KCCard learner_cards[4] = {
        kc_take_tutorial_card(&deck, trump_suit, true, 0),
        kc_take_tutorial_card(&deck, trump_suit, true, 0),
        kc_take_tutorial_card(
            &deck,
            off_suit,
            true,
            0
        ),
        kc_take_tutorial_card(&deck, void_suit, false, 0)
    };
    for (int32_t index = 0; index < 4; index++) {
        if (kc_card_valid(learner_cards[index])) {
            kc_list_append(&engine->players[0].hand, learner_cards[index]);
        }
    }
    int32_t closing_value = learner_cards[2].value;
    if (kc_card_valid(saved_off_suit) &&
        saved_off_suit.value > closing_value) {
        closing_value = saved_off_suit.value;
    }

    int32_t wrecker_index = kc_list_find(
        &deck,
        (KCCard){ .suit = KC_SUIT_WRECKER, .value = KC_WRECKER_VALUE }
    );
    KCCard wrecker = wrecker_index >= 0
        ? kc_list_remove_at(&deck, wrecker_index)
        : kc_no_card();
    for (int32_t player_id = 1; player_id < KC_PLAYER_COUNT; player_id++) {
        KCCard void_card =
            kc_take_tutorial_card(&deck, void_suit, true, 0);
        KCCard trump_card = player_id == 1 && kc_card_valid(wrecker)
            ? wrecker
            : kc_take_tutorial_card(&deck, trump_suit, true, 0);
        if (kc_card_valid(void_card)) {
            kc_list_append(&engine->players[player_id].hand, void_card);
        }
        if (kc_card_valid(trump_card)) {
            kc_list_append(&engine->players[player_id].hand, trump_card);
        }
    }
    for (int32_t player_id = 1; player_id < KC_PLAYER_COUNT; player_id++) {
        while (engine->players[player_id].hand.count < 4) {
            KCCard card =
                kc_take_tutorial_card(&deck, filler_suit, true, 0);
            if (!kc_card_valid(card)) {
                card = kc_take_tutorial_card(&deck, void_suit, true, 0);
            }
            if (!kc_card_valid(card)) {
                card = kc_take_tutorial_famine_filler(
                    &deck,
                    trump_suit,
                    off_suit,
                    closing_value
                );
            }
            if (kc_card_valid(card)) {
                kc_list_append(&engine->players[player_id].hand, card);
            } else {
                break;
            }
        }
    }
}

static void kc_deal_tutorial_hands(KCEngine *engine) {
    static const KCCard year_one[KC_PLAYER_COUNT][5] = {
        {{KC_SUIT_WHEAT, 6}, {KC_SUIT_SUNFLOWER, 11}, {KC_SUIT_POTATO, 13}, {KC_SUIT_BEET, 11}, {KC_SUIT_WHEAT, 10}},
        {{KC_SUIT_WHEAT, 11}, {KC_SUIT_SUNFLOWER, 10}, {KC_SUIT_POTATO, 12}, {KC_SUIT_BEET, 12}, {KC_SUIT_SUNFLOWER, 6}},
        {{KC_SUIT_WHEAT, 12}, {KC_SUIT_SUNFLOWER, 12}, {KC_SUIT_POTATO, 10}, {KC_SUIT_BEET, 13}, {KC_SUIT_POTATO, 6}},
        {{KC_SUIT_WHEAT, 13}, {KC_SUIT_SUNFLOWER, 13}, {KC_SUIT_POTATO, 11}, {KC_SUIT_BEET, 10}, {KC_SUIT_BEET, 6}}
    };
    static const KCCard year_two[KC_PLAYER_COUNT][5] = {
        {{KC_SUIT_WHEAT, 13}, {KC_SUIT_SUNFLOWER, 13}, {KC_SUIT_POTATO, 10}, {KC_SUIT_SUNFLOWER, 9}, {KC_SUIT_BEET, 13}},
        {{KC_SUIT_BEET, 8}, {KC_SUIT_SUNFLOWER, 10}, {KC_SUIT_POTATO, 11}, {KC_SUIT_POTATO, 9}, {KC_SUIT_BEET, 10}},
        {{KC_SUIT_WHEAT, 11}, {KC_SUIT_SUNFLOWER, 11}, {KC_SUIT_POTATO, 13}, {KC_SUIT_WHEAT, 9}, {KC_SUIT_BEET, 11}},
        {{KC_SUIT_WHEAT, 12}, {KC_SUIT_SUNFLOWER, 12}, {KC_SUIT_POTATO, 12}, {KC_SUIT_BEET, 9}, {KC_SUIT_BEET, 12}}
    };
    static const KCCard year_three[KC_PLAYER_COUNT][5] = {
        {{KC_SUIT_POTATO, 13}, {KC_SUIT_SUNFLOWER, 10}, {KC_SUIT_BEET, 10}, {KC_SUIT_WRECKER, KC_WRECKER_VALUE}, {KC_SUIT_BEET, 8}},
        {{KC_SUIT_POTATO, 12}, {KC_SUIT_SUNFLOWER, 11}, {KC_SUIT_BEET, 11}, {KC_SUIT_POTATO, 7}, {KC_SUIT_SUNFLOWER, 8}},
        {{KC_SUIT_WHEAT, 12}, {KC_SUIT_SUNFLOWER, 12}, {KC_SUIT_BEET, 12}, {KC_SUIT_SUNFLOWER, 7}, {KC_SUIT_POTATO, 11}},
        {{KC_SUIT_WHEAT, 13}, {KC_SUIT_SUNFLOWER, 13}, {KC_SUIT_BEET, 13}, {KC_SUIT_POTATO, 10}, {KC_SUIT_WHEAT, 9}}
    };
    const KCCard (*hands)[5] = engine->year == 1
        ? year_one
        : (engine->year == 2 ? year_two : year_three);
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        kc_list_clear(&engine->players[player_id].hand);
        for (int32_t card_index = 0; card_index < 5; card_index++) {
            kc_list_append(&engine->players[player_id].hand, hands[player_id][card_index]);
        }
    }
    engine->pending_final_year_trump_card = kc_no_card();
    engine->final_year_trump_card = kc_no_card();
}

static void kc_deal_hands(KCEngine *engine) {
    if (engine->tutorial_mode && engine->year <= 3) {
        kc_deal_tutorial_hands(engine);
        return;
    }
    if (engine->tutorial_mode && engine->year == KC_MAX_YEARS) {
        kc_deal_tutorial_famine_hands(engine);
        return;
    }
    KCCardList deck;
    kc_make_worker_deck(engine, &deck);
    int32_t cards_per_player = engine->is_famine ? 4 : 5;
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        kc_list_clear(&engine->players[player_id].hand);
    }
    for (int32_t card_index = 0; card_index < cards_per_player; card_index++) {
        for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
            KCCard card = kc_list_pop_last(&deck);
            if (kc_card_valid(card)) {
                kc_list_append(&engine->players[player_id].hand, card);
            }
        }
    }
    engine->pending_final_year_trump_card = kc_no_card();
    engine->final_year_trump_card = kc_no_card();
    if (engine->year == KC_MAX_YEARS &&
        engine->variants.final_year_trump &&
        engine->variants.wrecker &&
        deck.count > 0) {
        engine->pending_final_year_trump_card = kc_list_pop_last(&deck);
    }
}

static void kc_setup_managed_economy_aces(KCEngine *engine) {
    if (!engine->variants.managed_economy) {
        return;
    }
    KCCardList aces;
    kc_list_clear(&aces);
    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        kc_list_append(&aces, (KCCard){ .suit = suit, .value = 1 });
    }
    kc_shuffle(engine, &aces);
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        KCCard ace = kc_list_pop_last(&aces);
        /* Wheat is the engine's crop identity for the physical clubs suit. */
        if (ace.suit == KC_SUIT_WHEAT) {
            kc_list_append(&engine->players[player_id].plot_revealed, ace);
            engine->trump_selector = player_id;
        } else {
            kc_list_append(&engine->players[player_id].plot_hidden, ace);
        }
    }
}

static void kc_setup_decks(KCEngine *engine) {
    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        kc_list_clear(&engine->job_piles[suit]);
        if (engine->variants.deck_type == 36) {
            kc_list_append(&engine->job_piles[suit], (KCCard){ .suit = suit, .value = 1 });
        } else {
            int32_t first_reward = engine->variants.managed_economy ? 2 : 1;
            int32_t fixed_rewards = engine->variants.lotto_rewards ? 4 : KC_MAX_YEARS;
            for (int32_t value = first_reward; value <= fixed_rewards; value++) {
                kc_list_append(&engine->job_piles[suit], (KCCard){ .suit = suit, .value = value });
            }
            if (engine->variants.lotto_rewards) {
                int32_t lotto_value = 5 + (int32_t)(kc_next(engine) % 9U);
                kc_list_append(&engine->job_piles[suit], (KCCard){ .suit = suit, .value = lotto_value });
            }
            if (engine->tutorial_mode) {
                static const int32_t tutorial_rewards[KC_SUIT_COUNT][KC_MAX_YEARS] = {
                    {2, 3, 4, 5, 1},
                    {5, 1, 2, 3, 4},
                    {1, 2, 3, 4, 5},
                    {4, 5, 1, 2, 3}
                };
                kc_list_clear(&engine->job_piles[suit]);
                for (int32_t year = KC_MAX_YEARS - 1; year >= 0; year--) {
                    kc_list_append(
                        &engine->job_piles[suit],
                        (KCCard){ .suit = suit, .value = tutorial_rewards[suit][year] }
                    );
                }
            } else {
                kc_shuffle(engine, &engine->job_piles[suit]);
            }
        }
    }
    kc_clear_revealed_jobs(engine);
    engine->is_famine = engine->year == KC_MAX_YEARS;
    kc_setup_managed_economy_aces(engine);
    kc_deal_hands(engine);
}

static void kc_engine_init_with_controllers_internal(
    KCEngine *engine,
    uint64_t seed,
    KCVariants variants,
    KCControllers controllers,
    bool process_automatic,
    bool tutorial_mode
) {
    memset(engine, 0, sizeof(*engine));
    engine->rng_state = seed == 0 ? 1 : seed;
    engine->tutorial_mode = tutorial_mode;
    if (tutorial_mode) {
        /* The authored walkthrough teaches the classic fixed reward flow. */
        variants.managed_economy = false;
        variants.lotto_rewards = true;
    }
    variants.final_year_trump = variants.final_year_trump && variants.wrecker;
    variants.managed_economy = variants.managed_economy &&
        variants.deck_type != 36 && !variants.northern_style;
    variants.lotto_rewards = variants.lotto_rewards &&
        variants.deck_type != 36 && !variants.managed_economy;
    engine->variants = variants;
    engine->controllers = controllers;
    engine->year = 1;
    engine->trump = KC_NO_SUIT;
    engine->last_winner = KC_NO_PLAYER;
    engine->winner_id = KC_NO_PLAYER;
    kc_make_players(engine);
    for (int32_t player_id = 1; player_id < KC_PLAYER_COUNT; player_id++) {
        (void)kc_next(engine);
    }
    engine->lead = (int32_t)(kc_next(engine) % KC_PLAYER_COUNT);
    engine->trump_selector = (int32_t)(kc_next(engine) % KC_PLAYER_COUNT);
    if (tutorial_mode) {
        engine->lead = 1;
        engine->trump_selector = 1;
    }
    engine->phase = KC_PHASE_PLANNING;
    kc_reset_year_work(engine);
    kc_setup_decks(engine);
    engine->current_player = engine->trump_selector;
    if (tutorial_mode) {
        engine->current_player = 0;
    }
    if (process_automatic) {
        kc_process_automatic_turns(engine);
    }
}

void kc_engine_init_with_controllers(KCEngine *engine, uint64_t seed, KCVariants variants, KCControllers controllers) {
    kc_engine_init_with_controllers_internal(engine, seed, variants, controllers, true, false);
}

void kc_engine_init_with_controllers_stepwise(KCEngine *engine, uint64_t seed, KCVariants variants, KCControllers controllers) {
    kc_engine_init_with_controllers_internal(engine, seed, variants, controllers, false, false);
}

void kc_engine_init_tutorial_with_controllers_stepwise(
    KCEngine *engine,
    uint64_t seed,
    KCControllers controllers
) {
    KCVariants variants;
    kc_variants_kolkhoz(&variants);
    kc_engine_init_with_controllers_internal(engine, seed, variants, controllers, false, true);
}

void kc_engine_init(KCEngine *engine, uint64_t seed, KCVariants variants) {
    KCControllers controllers;
    kc_controllers_all_external(&controllers);
    kc_engine_init_with_controllers(engine, seed, variants, controllers);
}

bool kc_engine_is_tutorial(const KCEngine *engine) {
    return engine && engine->tutorial_mode;
}

KCEngine *kc_engine_alloc(void) {
    return calloc(1, sizeof(KCEngine));
}

void kc_engine_free(KCEngine *engine) {
    free(engine);
}

void kc_engine_clone(const KCEngine *source, KCEngine *out) {
    if (!source || !out) {
        return;
    }
    *out = *source;
}

static void kc_determinization_collect_list(const KCCardList *list, KCCardList *pool) {
    for (int32_t index = 0; list && index < list->count; index++) {
        kc_list_append(pool, list->cards[index]);
    }
}

static void kc_determinization_collect_stack_hidden(const KCPlotStack *stack, KCCardList *pool) {
    for (int32_t index = 0; stack && index < stack->hidden_count; index++) {
        kc_list_append(pool, stack->hidden[index]);
    }
}

static bool kc_determinization_refill_list(KCCardList *list, KCCardList *pool) {
    for (int32_t index = 0; list && index < list->count; index++) {
        KCCard card = kc_list_pop_last(pool);
        if (!kc_card_valid(card)) {
            return false;
        }
        list->cards[index] = card;
    }
    return true;
}

static bool kc_determinization_refill_stack_hidden(KCPlotStack *stack, KCCardList *pool) {
    for (int32_t index = 0; stack && index < stack->hidden_count; index++) {
        KCCard card = kc_list_pop_last(pool);
        if (!kc_card_valid(card)) {
            return false;
        }
        stack->hidden[index] = card;
    }
    return true;
}

bool kc_engine_sample_determinization(const KCEngine *source, int32_t perspective_player, uint64_t sample_seed, KCEngine *out) {
    if (!source || !out) {
        return false;
    }
    if (!kc_valid_player_id(perspective_player)) {
        perspective_player = kc_valid_player_id(source->current_player) ? source->current_player : 0;
    }

    kc_engine_clone(source, out);
    out->rng_state = sample_seed == 0 ? 1 : sample_seed;

    KCCardList private_pool;
    kc_list_clear(&private_pool);
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        if (player_id == perspective_player) {
            continue;
        }
        const KCPlayer *player = &source->players[player_id];
        kc_determinization_collect_list(&player->hand, &private_pool);
        kc_determinization_collect_list(&player->plot_hidden, &private_pool);
        for (int32_t stack_index = 0; stack_index < player->stack_count; stack_index++) {
            kc_determinization_collect_stack_hidden(&player->stacks[stack_index], &private_pool);
        }
    }
    kc_shuffle(out, &private_pool);

    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        if (player_id == perspective_player) {
            continue;
        }
        KCPlayer *player = &out->players[player_id];
        if (!kc_determinization_refill_list(&player->hand, &private_pool) ||
            !kc_determinization_refill_list(&player->plot_hidden, &private_pool)) {
            return false;
        }
        for (int32_t stack_index = 0; stack_index < player->stack_count; stack_index++) {
            if (!kc_determinization_refill_stack_hidden(&player->stacks[stack_index], &private_pool)) {
                return false;
            }
        }
    }
    if (private_pool.count != 0) {
        return false;
    }

    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        kc_shuffle(out, &out->job_piles[suit]);
    }
    return true;
}

bool kc_valid_player_id(int32_t player_id) {
    return player_id >= 0 && player_id < KC_PLAYER_COUNT;
}

bool kc_valid_suit(int32_t suit) {
    return suit >= 0 && suit < KC_SUIT_COUNT;
}

static KCCard kc_card_at(const KCCardList *list, int32_t index) {
    if (!list || index < 0 || index >= list->count) {
        return kc_no_card();
    }
    return list->cards[index];
}

int32_t kc_engine_current_player(const KCEngine *engine) {
    return engine ? engine->current_player : KC_NO_PLAYER;
}

int32_t kc_engine_lead_player(const KCEngine *engine) {
    return engine ? engine->lead : KC_NO_PLAYER;
}

int32_t kc_engine_trump(const KCEngine *engine) {
    return engine ? engine->trump : KC_NO_SUIT;
}

int32_t kc_engine_trick_count(const KCEngine *engine) {
    return engine ? engine->trick_count : 0;
}

int32_t kc_engine_last_winner(const KCEngine *engine) {
    return engine ? engine->last_winner : KC_NO_PLAYER;
}

int32_t kc_engine_winner_id(const KCEngine *engine) {
    return engine ? engine->winner_id : KC_NO_PLAYER;
}

bool kc_engine_is_famine(const KCEngine *engine) {
    return engine ? engine->is_famine : false;
}

int32_t kc_player_hand_count(const KCEngine *engine, int32_t player_id) {
    if (!engine || !kc_valid_player_id(player_id)) return 0;
    return engine->players[player_id].hand.count;
}

KCCard kc_player_hand_card(const KCEngine *engine, int32_t player_id, int32_t index) {
    if (!engine || !kc_valid_player_id(player_id)) return kc_no_card();
    return kc_card_at(&engine->players[player_id].hand, index);
}

int32_t kc_player_plot_revealed_count(const KCEngine *engine, int32_t player_id) {
    if (!engine || !kc_valid_player_id(player_id)) return 0;
    return engine->players[player_id].plot_revealed.count;
}

KCCard kc_player_plot_revealed_card(const KCEngine *engine, int32_t player_id, int32_t index) {
    if (!engine || !kc_valid_player_id(player_id)) return kc_no_card();
    return kc_card_at(&engine->players[player_id].plot_revealed, index);
}

int32_t kc_player_plot_hidden_count(const KCEngine *engine, int32_t player_id) {
    if (!engine || !kc_valid_player_id(player_id)) return 0;
    return engine->players[player_id].plot_hidden.count;
}

KCCard kc_player_plot_hidden_card(const KCEngine *engine, int32_t player_id, int32_t index) {
    if (!engine || !kc_valid_player_id(player_id)) return kc_no_card();
    return kc_card_at(&engine->players[player_id].plot_hidden, index);
}

int32_t kc_player_plot_stack_count(const KCEngine *engine, int32_t player_id) {
    if (!engine || !kc_valid_player_id(player_id)) return 0;
    return engine->players[player_id].stack_count;
}

int32_t kc_player_plot_stack_revealed_count(const KCEngine *engine, int32_t player_id, int32_t stack_index) {
    if (!engine || !kc_valid_player_id(player_id)) return 0;
    const KCPlayer *player = &engine->players[player_id];
    if (stack_index < 0 || stack_index >= player->stack_count) return 0;
    return player->stacks[stack_index].revealed_count;
}

KCCard kc_player_plot_stack_revealed_card(const KCEngine *engine, int32_t player_id, int32_t stack_index, int32_t card_index) {
    if (!engine || !kc_valid_player_id(player_id)) return kc_no_card();
    const KCPlayer *player = &engine->players[player_id];
    if (stack_index < 0 || stack_index >= player->stack_count) return kc_no_card();
    const KCPlotStack *stack = &player->stacks[stack_index];
    if (card_index < 0 || card_index >= stack->revealed_count) return kc_no_card();
    return stack->revealed[card_index];
}

int32_t kc_player_plot_stack_hidden_count(const KCEngine *engine, int32_t player_id, int32_t stack_index) {
    if (!engine || !kc_valid_player_id(player_id)) return 0;
    const KCPlayer *player = &engine->players[player_id];
    if (stack_index < 0 || stack_index >= player->stack_count) return 0;
    return player->stacks[stack_index].hidden_count;
}

KCCard kc_player_plot_stack_hidden_card(const KCEngine *engine, int32_t player_id, int32_t stack_index, int32_t card_index) {
    if (!engine || !kc_valid_player_id(player_id)) return kc_no_card();
    const KCPlayer *player = &engine->players[player_id];
    if (stack_index < 0 || stack_index >= player->stack_count) return kc_no_card();
    const KCPlotStack *stack = &player->stacks[stack_index];
    if (card_index < 0 || card_index >= stack->hidden_count) return kc_no_card();
    return stack->hidden[card_index];
}

int32_t kc_player_medals(const KCEngine *engine, int32_t player_id) {
    if (!engine || !kc_valid_player_id(player_id)) return 0;
    return engine->players[player_id].medals;
}

int32_t kc_player_banked_medals(const KCEngine *engine, int32_t player_id) {
    if (!engine || !kc_valid_player_id(player_id)) return 0;
    return engine->players[player_id].plot_medals;
}

bool kc_player_brigade_leader(const KCEngine *engine, int32_t player_id) {
    if (!engine || !kc_valid_player_id(player_id)) return false;
    return engine->players[player_id].brigade_leader;
}

bool kc_player_won_trick_this_year(const KCEngine *engine, int32_t player_id) {
    if (!engine || !kc_valid_player_id(player_id)) return false;
    return engine->players[player_id].has_won_trick_this_year;
}

bool kc_has_revealed_job(const KCEngine *engine, int32_t suit) {
    if (!engine || !kc_valid_suit(suit)) return false;
    return engine->has_revealed_job[suit];
}

KCCard kc_revealed_job_card(const KCEngine *engine, int32_t suit) {
    if (!engine || !kc_valid_suit(suit) || !engine->has_revealed_job[suit]) return kc_no_card();
    return engine->revealed_jobs[suit];
}

KCCard kc_managed_reward_offer_card(const KCEngine *engine, int32_t suit) {
    if (!engine || !kc_valid_suit(suit)) return kc_no_card();
    return engine->managed_reward_offers[suit];
}

bool kc_claimed_job(const KCEngine *engine, int32_t suit) {
    if (!engine || !kc_valid_suit(suit)) return false;
    return engine->claimed_jobs[suit];
}

int32_t kc_work_hours(const KCEngine *engine, int32_t suit) {
    if (!engine || !kc_valid_suit(suit)) return 0;
    return engine->work_hours[suit];
}

int32_t kc_job_bucket_count(const KCEngine *engine, int32_t suit) {
    if (!engine || !kc_valid_suit(suit)) return 0;
    return engine->job_buckets[suit].count;
}

KCCard kc_job_bucket_card(const KCEngine *engine, int32_t suit, int32_t index) {
    if (!engine || !kc_valid_suit(suit)) return kc_no_card();
    return kc_card_at(&engine->job_buckets[suit], index);
}

int32_t kc_job_bucket_trick(const KCEngine *engine, int32_t suit, int32_t index) {
    if (!engine || !kc_valid_suit(suit) || index < 0 || index >= engine->job_buckets[suit].count) {
        return 0;
    }
    return engine->job_bucket_tricks[suit][index];
}

int32_t kc_current_trick_count(const KCEngine *engine) {
    return engine ? engine->current_trick_count : 0;
}

int32_t kc_current_trick_player(const KCEngine *engine, int32_t index) {
    if (!engine || index < 0 || index >= engine->current_trick_count) return KC_NO_PLAYER;
    return engine->current_trick[index].player_id;
}

KCCard kc_current_trick_card(const KCEngine *engine, int32_t index) {
    if (!engine || index < 0 || index >= engine->current_trick_count) return kc_no_card();
    return engine->current_trick[index].card;
}

int32_t kc_last_trick_count(const KCEngine *engine) {
    return engine ? engine->last_trick_count : 0;
}

int32_t kc_last_trick_player(const KCEngine *engine, int32_t index) {
    if (!engine || index < 0 || index >= engine->last_trick_count) return KC_NO_PLAYER;
    return engine->last_trick[index].player_id;
}

KCCard kc_last_trick_card(const KCEngine *engine, int32_t index) {
    if (!engine || index < 0 || index >= engine->last_trick_count) return kc_no_card();
    return engine->last_trick[index].card;
}

int32_t kc_pending_assignment_target(const KCEngine *engine, int32_t index) {
    if (!engine || index < 0 || index >= KC_PLAYER_COUNT) return KC_NO_SUIT;
    return engine->pending_assignment_targets[index];
}

int32_t kc_exiled_count(const KCEngine *engine, int32_t year) {
    if (!engine || year < 0 || year > KC_MAX_YEARS) return 0;
    return engine->exiled[year].count;
}

KCCard kc_exiled_card(const KCEngine *engine, int32_t year, int32_t index) {
    if (!engine || year < 0 || year > KC_MAX_YEARS) return kc_no_card();
    return kc_card_at(&engine->exiled[year], index);
}

int32_t kc_exiled_player(const KCEngine *engine, int32_t year, int32_t index) {
    if (engine == NULL || year < 0 || year > KC_MAX_YEARS ||
        index < 0 || index >= engine->exiled[year].count) return KC_NO_PLAYER;
    return engine->exiled_player_ids[year][index];
}

int32_t kc_requisition_event_count(const KCEngine *engine) {
    return engine ? engine->requisition_event_count : 0;
}

int32_t kc_requisition_event_player(const KCEngine *engine, int32_t index) {
    if (!engine || index < 0 || index >= engine->requisition_event_count) return KC_NO_PLAYER;
    return engine->requisition_events[index].player_id;
}

int32_t kc_requisition_event_suit(const KCEngine *engine, int32_t index) {
    if (!engine || index < 0 || index >= engine->requisition_event_count) return KC_NO_SUIT;
    return engine->requisition_events[index].suit;
}

KCCard kc_requisition_event_card(const KCEngine *engine, int32_t index) {
    if (!engine || index < 0 || index >= engine->requisition_event_count) return kc_no_card();
    return engine->requisition_events[index].card;
}

int32_t kc_requisition_event_message_kind(const KCEngine *engine, int32_t index) {
    if (!engine || index < 0 || index >= engine->requisition_event_count) return 0;
    return engine->requisition_events[index].message_kind;
}

static const KCTransitionEvent *kc_transition_event_at(const KCEngine *engine, int32_t index) {
    if (!engine || index < 0 || index >= engine->transition_event_count) return NULL;
    return &engine->transition_events[index];
}

int32_t kc_transition_event_count(const KCEngine *engine) {
    return engine ? engine->transition_event_count : 0;
}

int32_t kc_transition_event_kind(const KCEngine *engine, int32_t index) {
    const KCTransitionEvent *event = kc_transition_event_at(engine, index);
    return event ? event->kind : 0;
}

int32_t kc_transition_event_player(const KCEngine *engine, int32_t index) {
    const KCTransitionEvent *event = kc_transition_event_at(engine, index);
    return event ? event->player_id : KC_NO_PLAYER;
}

KCCard kc_transition_event_card(const KCEngine *engine, int32_t index) {
    const KCTransitionEvent *event = kc_transition_event_at(engine, index);
    return event ? event->card : kc_no_card();
}

int32_t kc_transition_event_from_zone(const KCEngine *engine, int32_t index) {
    const KCTransitionEvent *event = kc_transition_event_at(engine, index);
    return event ? event->from_zone : KC_OBJECT_ZONE_NONE;
}

int32_t kc_transition_event_to_zone(const KCEngine *engine, int32_t index) {
    const KCTransitionEvent *event = kc_transition_event_at(engine, index);
    return event ? event->to_zone : KC_OBJECT_ZONE_NONE;
}

int32_t kc_transition_event_from_owner(const KCEngine *engine, int32_t index) {
    const KCTransitionEvent *event = kc_transition_event_at(engine, index);
    return event ? event->from_owner : KC_NO_PLAYER;
}

int32_t kc_transition_event_to_owner(const KCEngine *engine, int32_t index) {
    const KCTransitionEvent *event = kc_transition_event_at(engine, index);
    return event ? event->to_owner : KC_NO_PLAYER;
}

int32_t kc_transition_event_target_suit(const KCEngine *engine, int32_t index) {
    const KCTransitionEvent *event = kc_transition_event_at(engine, index);
    return event ? event->target_suit : KC_NO_SUIT;
}

int32_t kc_transition_event_trick_winner(const KCEngine *engine, int32_t index) {
    const KCTransitionEvent *event = kc_transition_event_at(engine, index);
    return event ? event->trick_winner : KC_NO_PLAYER;
}

bool kc_swap_count(const KCEngine *engine, int32_t player_id) {
    if (!engine || !kc_valid_player_id(player_id)) return false;
    return engine->swap_count[player_id];
}

bool kc_swap_confirmed(const KCEngine *engine, int32_t player_id) {
    if (!engine || !kc_valid_player_id(player_id)) return false;
    return engine->swap_confirmed[player_id];
}

bool kc_pass_confirmed(const KCEngine *engine, int32_t player_id) {
    if (!engine || !kc_valid_player_id(player_id)) return false;
    return engine->pass_confirmed[player_id];
}

KCCard kc_final_year_trump_card(const KCEngine *engine) {
    return engine ? engine->final_year_trump_card : kc_no_card();
}

static KCAction kc_legal_action_at(const KCEngine *engine, int32_t index) {
    if (!engine || index < 0) return (KCAction){0};
    KCAction actions[256];
    int32_t count = kc_engine_legal_actions(engine, actions, 256);
    if (index >= count) return (KCAction){0};
    return actions[index];
}

int32_t kc_legal_action_count(const KCEngine *engine) {
    if (!engine) return 0;
    KCAction actions[256];
    return kc_engine_legal_actions(engine, actions, 256);
}

int32_t kc_legal_action_kind_at(const KCEngine *engine, int32_t index) {
    return kc_legal_action_at(engine, index).kind;
}

int32_t kc_legal_action_player_at(const KCEngine *engine, int32_t index) {
    return kc_legal_action_at(engine, index).player_id;
}

int32_t kc_legal_action_suit_at(const KCEngine *engine, int32_t index) {
    return kc_legal_action_at(engine, index).suit;
}

KCCard kc_legal_action_card_at(const KCEngine *engine, int32_t index) {
    return kc_legal_action_at(engine, index).card;
}

KCCard kc_legal_action_hand_card_at(const KCEngine *engine, int32_t index) {
    return kc_legal_action_at(engine, index).hand_card;
}

KCCard kc_legal_action_plot_card_at(const KCEngine *engine, int32_t index) {
    return kc_legal_action_at(engine, index).plot_card;
}

int32_t kc_legal_action_plot_zone_at(const KCEngine *engine, int32_t index) {
    return kc_legal_action_at(engine, index).plot_zone;
}

int32_t kc_legal_action_target_suit_at(const KCEngine *engine, int32_t index) {
    return kc_legal_action_at(engine, index).target_suit;
}

int32_t kc_engine_apply_set_trump(KCEngine *engine, int32_t player_id, int32_t suit) {
    KCAction action = { .kind = KC_ACTION_SET_TRUMP, .player_id = player_id, .suit = suit, .card = kc_no_card(), .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = -1 };
    return kc_engine_apply(engine, action);
}

int32_t kc_engine_apply_play_card(KCEngine *engine, int32_t player_id, int32_t suit, int32_t value) {
    KCAction action = { .kind = KC_ACTION_PLAY_CARD, .player_id = player_id, .suit = -1, .card = { .suit = suit, .value = value }, .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = -1 };
    return kc_engine_apply(engine, action);
}

int32_t kc_engine_apply_pass_card(KCEngine *engine, int32_t player_id, int32_t suit, int32_t value) {
    KCAction action = { .kind = KC_ACTION_PASS_CARD, .player_id = player_id, .card = { .suit = suit, .value = value } };
    return kc_engine_apply(engine, action);
}

int32_t kc_engine_apply_swap(KCEngine *engine, int32_t player_id, int32_t hand_suit, int32_t hand_value, int32_t plot_suit, int32_t plot_value, int32_t plot_zone) {
    KCAction action = { .kind = KC_ACTION_SWAP, .player_id = player_id, .suit = -1, .card = kc_no_card(), .hand_card = { .suit = hand_suit, .value = hand_value }, .plot_card = { .suit = plot_suit, .value = plot_value }, .plot_zone = plot_zone, .target_suit = -1 };
    return kc_engine_apply(engine, action);
}

int32_t kc_engine_apply_assign(KCEngine *engine, int32_t player_id, int32_t suit, int32_t value, int32_t target_suit) {
    KCAction action = { .kind = KC_ACTION_ASSIGN, .player_id = player_id, .suit = -1, .card = { .suit = suit, .value = value }, .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = target_suit };
    return kc_engine_apply(engine, action);
}

int32_t kc_engine_apply_simple(KCEngine *engine, int32_t kind, int32_t player_id) {
    KCAction action = { .kind = kind, .player_id = player_id, .suit = -1, .card = kc_no_card(), .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = -1 };
    return kc_engine_apply(engine, action);
}

int32_t kc_engine_apply_suit_action(KCEngine *engine, int32_t kind, int32_t player_id, int32_t suit) {
    KCAction action = { .kind = kind, .player_id = player_id, .suit = suit, .card = kc_no_card(), .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = -1 };
    return kc_engine_apply(engine, action);
}

int32_t kc_engine_apply_card_action(KCEngine *engine, int32_t kind, int32_t player_id, int32_t suit, int32_t card_suit, int32_t card_value) {
    KCAction action = { .kind = kind, .player_id = player_id, .suit = suit, .card = { .suit = card_suit, .value = card_value }, .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = suit };
    return kc_engine_apply(engine, action);
}

int32_t kc_engine_apply_set_trump_manual(KCEngine *engine, int32_t player_id, int32_t suit) {
    KCAction action = { .kind = KC_ACTION_SET_TRUMP, .player_id = player_id, .suit = suit, .card = kc_no_card(), .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = -1 };
    return kc_engine_apply_manual(engine, action);
}

int32_t kc_engine_apply_play_card_manual(KCEngine *engine, int32_t player_id, int32_t suit, int32_t value) {
    KCAction action = { .kind = KC_ACTION_PLAY_CARD, .player_id = player_id, .suit = -1, .card = { .suit = suit, .value = value }, .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = -1 };
    return kc_engine_apply_manual(engine, action);
}

int32_t kc_engine_apply_pass_card_manual(KCEngine *engine, int32_t player_id, int32_t suit, int32_t value) {
    KCAction action = { .kind = KC_ACTION_PASS_CARD, .player_id = player_id, .card = { .suit = suit, .value = value } };
    return kc_engine_apply_manual(engine, action);
}

int32_t kc_engine_apply_swap_manual(KCEngine *engine, int32_t player_id, int32_t hand_suit, int32_t hand_value, int32_t plot_suit, int32_t plot_value, int32_t plot_zone) {
    KCAction action = { .kind = KC_ACTION_SWAP, .player_id = player_id, .suit = -1, .card = kc_no_card(), .hand_card = { .suit = hand_suit, .value = hand_value }, .plot_card = { .suit = plot_suit, .value = plot_value }, .plot_zone = plot_zone, .target_suit = -1 };
    return kc_engine_apply_manual(engine, action);
}

int32_t kc_engine_apply_assign_manual(KCEngine *engine, int32_t player_id, int32_t suit, int32_t value, int32_t target_suit) {
    KCAction action = { .kind = KC_ACTION_ASSIGN, .player_id = player_id, .suit = -1, .card = { .suit = suit, .value = value }, .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = target_suit };
    return kc_engine_apply_manual(engine, action);
}

int32_t kc_engine_apply_simple_manual(KCEngine *engine, int32_t kind, int32_t player_id) {
    KCAction action = { .kind = kind, .player_id = player_id, .suit = -1, .card = kc_no_card(), .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = -1 };
    return kc_engine_apply_manual(engine, action);
}


int32_t kc_engine_apply_suit_action_manual(KCEngine *engine, int32_t kind, int32_t player_id, int32_t suit) {
    KCAction action = { .kind = kind, .player_id = player_id, .suit = suit, .card = kc_no_card(), .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = -1 };
    return kc_engine_apply_manual(engine, action);
}

int32_t kc_engine_apply_card_action_manual(KCEngine *engine, int32_t kind, int32_t player_id, int32_t suit, int32_t card_suit, int32_t card_value) {
    KCAction action = { .kind = kind, .player_id = player_id, .suit = suit, .card = { .suit = card_suit, .value = card_value }, .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = suit };
    return kc_engine_apply_manual(engine, action);
}

static KCCard kc_draw_from(KCCardList *deck) {
    return kc_list_pop_last(deck);
}

void kc_engine_init_curriculum_rounds(KCEngine *engine, uint64_t seed, KCVariants variants, int32_t plot_cards_per_player, double final_round_famine_rate, int32_t curriculum_rounds) {
    memset(engine, 0, sizeof(*engine));
    engine->rng_state = seed == 0 ? 1 : seed;
    /* Curriculum fixtures begin with synthetic rewards already installed. */
    variants.managed_economy = false;
    engine->variants = variants;
    kc_controllers_all_external(&engine->controllers);
    engine->trump = KC_NO_SUIT;
    engine->last_winner = KC_NO_PLAYER;
    engine->winner_id = KC_NO_PLAYER;
    kc_make_players(engine);

    int32_t safe_rounds = curriculum_rounds < 1 ? 1 : (curriculum_rounds > KC_MAX_YEARS ? KC_MAX_YEARS : curriculum_rounds);
    double safe_famine_rate = final_round_famine_rate < 0 ? 0 : (final_round_famine_rate > 1 ? 1 : final_round_famine_rate);
    bool final_round_famine = safe_rounds < KC_MAX_YEARS && kc_uniform(engine) < safe_famine_rate;
    int32_t latest_non_famine_start = KC_MAX_YEARS - safe_rounds;
    if (latest_non_famine_start < 1) latest_non_famine_start = 1;
    engine->year = final_round_famine
        ? KC_MAX_YEARS - safe_rounds + 1
        : 1 + (int32_t)(kc_next(engine) % (uint64_t)latest_non_famine_start);
    engine->is_famine = false;
    engine->lead = (int32_t)(kc_next(engine) % KC_PLAYER_COUNT);
    engine->trump_selector = (int32_t)(kc_next(engine) % KC_PLAYER_COUNT);
    engine->current_player = engine->trump_selector;
    engine->phase = KC_PHASE_PLANNING;
    engine->trick_count = 0;
    for (int32_t i = 0; i < KC_PLAYER_COUNT; i++) {
        engine->pending_assignment_targets[i] = KC_NO_SUIT;
    }
    memset(engine->swap_confirmed, 0, sizeof(engine->swap_confirmed));
    memset(engine->swap_count, 0, sizeof(engine->swap_count));

    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        engine->claimed_jobs[suit] = false;
        engine->work_hours[suit] = (int32_t)(kc_next(engine) % 28);
        kc_list_clear(&engine->job_buckets[suit]);
        kc_list_clear(&engine->job_piles[suit]);
        for (int32_t value = 1; value <= KC_MAX_YEARS; value++) {
            kc_list_append(&engine->job_piles[suit], (KCCard){ .suit = suit, .value = value });
        }
        kc_shuffle(engine, &engine->job_piles[suit]);
        engine->has_revealed_job[suit] = true;
        engine->revealed_jobs[suit] = (KCCard){ .suit = suit, .value = 1 + (int32_t)(kc_next(engine) % KC_MAX_YEARS) };
    }

    KCCardList deck;
    kc_list_clear(&deck);
    int32_t min_worker_value = variants.deck_type == 36 ? 6 : 1;
    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        for (int32_t value = min_worker_value; value <= 13; value++) {
            kc_list_append(&deck, (KCCard){ .suit = suit, .value = value });
        }
    }
    kc_shuffle(engine, &deck);

    int32_t cards_per_player = 5;
    int32_t plot_limit = plot_cards_per_player < 0 ? 0 : plot_cards_per_player;
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        KCPlayer *player = &engine->players[player_id];
        kc_list_clear(&player->hand);
        kc_list_clear(&player->plot_revealed);
        kc_list_clear(&player->plot_hidden);
        player->stack_count = 0;
        player->brigade_leader = false;
        player->has_won_trick_this_year = kc_uniform(engine) < 0.35;
        player->medals = (int32_t)(kc_next(engine) % 3);
        player->plot_medals = 0;

        for (int32_t card_index = 0; card_index < cards_per_player; card_index++) {
            KCCard card = kc_draw_from(&deck);
            if (kc_card_valid(card)) {
                kc_list_append(&player->hand, card);
            }
        }
        int32_t remaining_players = KC_PLAYER_COUNT - player_id;
        if (remaining_players < 1) remaining_players = 1;
        int32_t plot_count = plot_limit;
        int32_t max_available = deck.count / remaining_players;
        if (plot_count > max_available) plot_count = max_available;
        int32_t revealed_count = plot_count > 0 ? (int32_t)(kc_next(engine) % (uint64_t)(plot_count + 1)) : 0;
        for (int32_t card_index = 0; card_index < revealed_count; card_index++) {
            KCCard card = kc_draw_from(&deck);
            if (kc_card_valid(card)) {
                kc_list_append(&player->plot_revealed, card);
            }
        }
        for (int32_t card_index = revealed_count; card_index < plot_count; card_index++) {
            KCCard card = kc_draw_from(&deck);
            if (kc_card_valid(card)) {
                kc_list_append(&player->plot_hidden, card);
            }
        }
    }
    kc_process_automatic_turns(engine);
}

void kc_engine_init_curriculum(KCEngine *engine, uint64_t seed, KCVariants variants, int32_t plot_cards_per_player, double second_year_famine_rate) {
    kc_engine_init_curriculum_rounds(engine, seed, variants, plot_cards_per_player, second_year_famine_rate, 2);
}

bool kc_curriculum_should_continue(const KCEngine *engine, bool curriculum, int32_t starting_year) {
    return !curriculum || engine->year < starting_year + 2;
}

bool kc_curriculum_incomplete(const KCEngine *engine, bool curriculum, int32_t starting_year) {
    return curriculum && engine->phase != KC_PHASE_GAME_OVER && engine->year < starting_year + 2;
}

static bool kc_is_active_turn(const KCEngine *engine, int32_t player_id) {
    return player_id >= 0 && player_id < KC_PLAYER_COUNT &&
        engine->current_player == player_id;
}

static bool kc_is_active_assignment(const KCEngine *engine, int32_t player_id) {
    return player_id >= 0 && player_id < KC_PLAYER_COUNT &&
        engine->last_winner == player_id;
}

static void kc_clear_pass(KCEngine *engine) {
    memset(engine->pass_confirmed, 0, sizeof(engine->pass_confirmed));
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        engine->pass_cards[player_id] = kc_no_card();
    }
}

static void kc_advance_after_pass(KCEngine *engine) {
    bool swap_available = engine->year > 1 || kc_managed_economy_active(engine);
    if (engine->variants.allow_swap && swap_available) {
        engine->phase = KC_PHASE_SWAP;
        memset(engine->swap_confirmed, 0, sizeof(engine->swap_confirmed));
        memset(engine->swap_count, 0, sizeof(engine->swap_count));
        if (kc_managed_economy_active(engine)) {
            engine->swap_confirmed[engine->trump_selector] = true;
        }
        engine->current_player = 0;
        while (engine->current_player < KC_PLAYER_COUNT &&
               engine->swap_confirmed[engine->current_player]) {
            engine->current_player++;
        }
        if (engine->current_player >= KC_PLAYER_COUNT) {
            engine->phase = KC_PHASE_TRICK;
            engine->current_player = engine->lead;
        }
        kc_clear_last_swap(engine);
    } else {
        engine->phase = KC_PHASE_TRICK;
        engine->current_player = engine->lead;
    }
}

static void kc_resolve_pass(KCEngine *engine) {
    KCCard selected[KC_PLAYER_COUNT];
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        selected[player_id] = engine->pass_cards[player_id];
        int32_t index = kc_list_find(&engine->players[player_id].hand, selected[player_id]);
        if (index >= 0) {
            kc_list_remove_at(&engine->players[player_id].hand, index);
        }
    }
    bool pass_left = engine->year % 2 == 0;
    for (int32_t sender = 0; sender < KC_PLAYER_COUNT; sender++) {
        int32_t recipient = pass_left
            ? (sender + 1) % KC_PLAYER_COUNT
            : (sender + KC_PLAYER_COUNT - 1) % KC_PLAYER_COUNT;
        kc_list_append(&engine->players[recipient].hand, selected[sender]);
        kc_emit_transition(engine, (KCTransitionEvent){
            .kind = KC_TRANSITION_CARD_MOVED,
            .player_id = sender,
            .card = selected[sender],
            .from_zone = KC_OBJECT_ZONE_HAND,
            .to_zone = KC_OBJECT_ZONE_HAND,
            .from_owner = sender,
            .to_owner = recipient,
            .target_suit = KC_NO_SUIT
        });
    }
    kc_clear_pass(engine);
    kc_advance_after_pass(engine);
}

static int32_t kc_commit_pass(KCEngine *engine, int32_t player_id, KCCard card) {
    if (!kc_valid_player_id(player_id) || engine->pass_confirmed[player_id]) {
        return KC_ERR_WRONG_PLAYER;
    }
    if (kc_list_find(&engine->players[player_id].hand, card) < 0) {
        return KC_ERR_INVALID_CARD;
    }
    engine->pass_cards[player_id] = card;
    engine->pass_confirmed[player_id] = true;
    for (int32_t candidate = 0; candidate < KC_PLAYER_COUNT; candidate++) {
        if (!engine->pass_confirmed[candidate]) {
            engine->current_player = candidate;
            return 0;
        }
    }
    kc_resolve_pass(engine);
    return 0;
}

void kc_advance_from_planning(KCEngine *engine) {
    if (engine->is_famine) {
        engine->trump = kc_card_valid(engine->final_year_trump_card) &&
                !kc_card_is_wrecker(engine->final_year_trump_card)
            ? engine->final_year_trump_card.suit
            : KC_NO_SUIT;
    } else if (engine->trump < 0) {
        engine->trump = (int32_t)(kc_next(engine) % KC_SUIT_COUNT);
    }
    if (engine->variants.pass_cards && engine->year > 1) {
        engine->phase = KC_PHASE_PASS;
        engine->current_player = 0;
        kc_clear_pass(engine);
    } else {
        kc_advance_after_pass(engine);
    }
}

static void kc_process_automatic_turns(KCEngine *engine) {
    int32_t guard_count = 0;
    while (guard_count < 200) {
        guard_count++;
        if (kc_engine_step_automatic_impl(engine) <= 0) {
            return;
        }
    }
}

static int32_t kc_engine_step_automatic_impl(KCEngine *engine) {
    if (!engine) {
        return 0;
    }
    if (engine->phase == KC_PHASE_PLANNING && engine->is_famine &&
        kc_next_reward_to_reveal(engine) == KC_NO_SUIT &&
        !kc_card_valid(engine->pending_final_year_trump_card)) {
        kc_advance_from_planning(engine);
        return 1;
    }
    if (engine->phase == KC_PHASE_REQUISITION &&
        engine->requisition_rounds_remaining > 0) {
        for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
            if (engine->requisition_choice_confirmed[player_id] ||
                !engine->requisition_target_players[player_id] ||
                !kc_controller_is_automatic(engine->controllers.seats[player_id])) {
                continue;
            }
            int32_t highest = kc_requisition_highest_value(engine, player_id);
            KCCard selected = kc_no_card();
            const KCPlayer *player = &engine->players[player_id];
            for (int32_t zone = 0; zone < 2 && !kc_card_valid(selected); zone++) {
                const KCCardList *cards = zone == 0
                    ? &player->plot_hidden
                    : &player->plot_revealed;
                for (int32_t i = 0; i < cards->count; i++) {
                    if (cards->cards[i].value == highest &&
                        kc_requisition_card_eligible(engine, player_id, cards->cards[i])) {
                        selected = cards->cards[i];
                        break;
                    }
                }
            }
            return kc_commit_requisition_choice(engine, player_id, selected) == 0 ? 1 : -1;
        }
        return 0;
    }
    if (engine->phase == KC_PHASE_REQUISITION &&
        engine->requisition_plan_index < engine->requisition_plan_count) {
        return kc_step_requisition(engine) ? 1 : 0;
    }
    if (engine->phase == KC_PHASE_PASS) {
        int32_t player_id = engine->current_player;
        if (!kc_valid_player_id(player_id) ||
            !kc_controller_is_automatic(engine->controllers.seats[player_id]) ||
            engine->players[player_id].hand.count <= 0) {
            return 0;
        }
        KCCard selected = engine->players[player_id].hand.cards[0];
        for (int32_t i = 1; i < engine->players[player_id].hand.count; i++) {
            KCCard candidate = engine->players[player_id].hand.cards[i];
            if (candidate.value < selected.value ||
                (candidate.value == selected.value && candidate.suit < selected.suit)) {
                selected = candidate;
            }
        }
        return kc_commit_pass(engine, player_id, selected) == 0 ? 1 : -1;
    }
    int32_t player_id = engine->phase == KC_PHASE_ASSIGNMENT ? engine->last_winner : engine->current_player;
    if (player_id < 0 ||
        player_id >= KC_PLAYER_COUNT ||
        !kc_controller_is_automatic(engine->controllers.seats[player_id])) {
        return 0;
    }
    KCAction actions[256];
    int32_t count = kc_engine_legal_actions(engine, actions, 256);
    KCAction selected;
    if (!kc_choose_benchmark_action(engine, actions, count, &selected)) {
        return 0;
    }
    int32_t error = kc_engine_apply_action(engine, selected);
    return error == 0 ? 1 : -error;
}

int32_t kc_engine_step_automatic(KCEngine *engine) {
    kc_engine_begin_transition_batch(engine);
    int32_t result = kc_engine_step_automatic_impl(engine);
    kc_engine_end_transition_batch(engine);
    return result;
}

bool kc_engine_heuristic_action(const KCEngine *engine, KCAction *selected) {
    if (!engine || !selected) {
        return false;
    }
    if (engine->phase == KC_PHASE_REQUISITION &&
        engine->requisition_rounds_remaining > 0) {
        KCAction actions[256];
        int32_t count = kc_engine_legal_actions(engine, actions, 256);
        for (int32_t i = 0; i < count; i++) {
            int32_t player_id = actions[i].player_id;
            if (actions[i].kind == KC_ACTION_SELECT_REQUISITION_CARD &&
                kc_valid_player_id(player_id) &&
                kc_controller_is_automatic(engine->controllers.seats[player_id])) {
                *selected = actions[i];
                return true;
            }
        }
        return false;
    }
    if (engine->phase == KC_PHASE_PASS &&
        kc_valid_player_id(engine->current_player) &&
        !kc_controller_is_external(
            engine->controllers.seats[engine->current_player]) &&
        engine->players[engine->current_player].hand.count > 0) {
        KCCard card = engine->players[engine->current_player].hand.cards[0];
        for (int32_t i = 1; i < engine->players[engine->current_player].hand.count; i++) {
            KCCard candidate = engine->players[engine->current_player].hand.cards[i];
            if (candidate.value < card.value ||
                (candidate.value == card.value && candidate.suit < card.suit)) {
                card = candidate;
            }
        }
        *selected = (KCAction){ .kind = KC_ACTION_PASS_CARD, .player_id = engine->current_player, .card = card };
        return true;
    }
    int32_t player_id = engine->phase == KC_PHASE_ASSIGNMENT ? engine->last_winner : engine->current_player;
    if (player_id < 0 ||
        player_id >= KC_PLAYER_COUNT ||
        !kc_controller_is_automatic(engine->controllers.seats[player_id])) {
        return false;
    }
    KCAction actions[256];
    int32_t count = kc_engine_legal_actions(engine, actions, 256);
    return kc_choose_benchmark_action(engine, actions, count, selected);
}

bool kc_engine_waiting_for_external_action(const KCEngine *engine) {
    int32_t player_id = kc_engine_waiting_player(engine);
    return player_id >= 0 &&
        player_id < KC_PLAYER_COUNT &&
        kc_controller_is_external(engine->controllers.seats[player_id]);
}

int32_t kc_engine_waiting_player(const KCEngine *engine) {
    switch (engine->phase) {
    case KC_PHASE_PLANNING:
    case KC_PHASE_SWAP:
    case KC_PHASE_TRICK:
        return engine->current_player;
    case KC_PHASE_PASS:
        for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
            if (!engine->pass_confirmed[player_id] &&
                kc_controller_is_external(engine->controllers.seats[player_id])) {
                return player_id;
            }
        }
        return engine->current_player;
    case KC_PHASE_ASSIGNMENT:
        return engine->last_winner;
    case KC_PHASE_REQUISITION:
        if (engine->requisition_rounds_remaining > 0) {
            for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
                if (!engine->requisition_choice_confirmed[player_id] &&
                    engine->requisition_target_players[player_id] &&
                    kc_controller_is_external(engine->controllers.seats[player_id])) {
                    return player_id;
                }
            }
            return engine->current_player;
        }
        return engine->requisition_plan_index < engine->requisition_plan_count
            ? KC_NO_PLAYER
            : 0;
    default:
        return KC_NO_PLAYER;
    }
}

int32_t kc_engine_phase(const KCEngine *engine) {
    return engine ? engine->phase : KC_PHASE_GAME_OVER;
}

int32_t kc_engine_year(const KCEngine *engine) {
    return engine ? engine->year : 0;
}

bool kc_is_valid_play(const KCEngine *engine, int32_t player_id, int32_t card_index) {
    if (player_id < 0 || player_id >= KC_PLAYER_COUNT) {
        return false;
    }
    const KCCardList *hand = &engine->players[player_id].hand;
    if (card_index < 0 || card_index >= hand->count) {
        return false;
    }
    if (engine->current_trick_count == 0) {
        return true;
    }
    int32_t lead_suit = kc_lead_suit(engine);
    bool has_lead_suit = false;
    for (int32_t i = 0; i < hand->count; i++) {
        if (kc_card_matches_suit(hand->cards[i], lead_suit)) {
            has_lead_suit = true;
            break;
        }
    }
    return !has_lead_suit || kc_card_matches_suit(hand->cards[card_index], lead_suit);
}

static int32_t kc_trick_winner(const KCEngine *engine) {
    int32_t lead_suit = kc_lead_suit(engine);
    bool has_trump = false;
    if (engine->trump >= 0) {
        for (int32_t i = 0; i < engine->current_trick_count; i++) {
            if (kc_card_matches_suit(engine->current_trick[i].card, engine->trump)) {
                has_trump = true;
                break;
            }
        }
    }
    int32_t best_player = engine->lead;
    int32_t best_value = -1;
    int32_t winning_suit = has_trump ? engine->trump : lead_suit;
    for (int32_t i = 0; i < engine->current_trick_count; i++) {
        KCCard card = engine->current_trick[i].card;
        if ((winning_suit == KC_NO_SUIT || kc_card_matches_suit(card, winning_suit)) &&
            card.value > best_value) {
            best_value = card.value;
            best_player = engine->current_trick[i].player_id;
        }
    }
    return best_player;
}

int32_t kc_current_trick_winner(const KCEngine *engine) {
    if (!engine || engine->current_trick_count <= 0) {
        return KC_NO_PLAYER;
    }
    return kc_trick_winner(engine);
}

static void kc_resolve_current_trick(KCEngine *engine) {
    int32_t winner = kc_trick_winner(engine);
    engine->last_winner = winner;
    engine->last_trick_count = engine->current_trick_count;
    for (int32_t i = 0; i < engine->current_trick_count; i++) {
        engine->last_trick[i] = engine->current_trick[i];
    }
    engine->current_trick_count = 0;
    engine->trick_count += 1;
    engine->lead = winner;
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        engine->players[player_id].brigade_leader = player_id == winner;
    }
    engine->players[winner].has_won_trick_this_year = true;
    engine->players[winner].medals += 1;
    kc_emit_transition(engine, (KCTransitionEvent){
        .kind = KC_TRANSITION_TRICK_RESOLVED,
        .player_id = winner,
        .card = kc_no_card(),
        .from_zone = KC_OBJECT_ZONE_CURRENT_TRICK,
        .to_zone = KC_OBJECT_ZONE_LAST_TRICK,
        .from_owner = KC_NO_PLAYER,
        .to_owner = winner,
        .target_suit = KC_NO_SUIT
    });
    engine->phase = KC_PHASE_ASSIGNMENT;
    engine->current_player = winner;
    for (int32_t i = 0; i < KC_PLAYER_COUNT; i++) {
        engine->pending_assignment_targets[i] = KC_NO_SUIT;
    }
    kc_emit_transition(engine, (KCTransitionEvent){
        .kind = KC_TRANSITION_ASSIGNMENT_OPENED,
        .player_id = winner,
        .card = kc_no_card(),
        .from_zone = KC_OBJECT_ZONE_LAST_TRICK,
        .to_zone = KC_OBJECT_ZONE_PENDING_ASSIGNMENT,
        .from_owner = winner,
        .to_owner = winner,
        .target_suit = KC_NO_SUIT
    });
    bool tutorial_manual_assignment =
        engine->tutorial_mode &&
        winner == 0 &&
        ((engine->year == 1 && engine->trick_count == 3) ||
         (engine->year == 2 &&
          (engine->trick_count == 2 || engine->trick_count == 4)));
    if (!tutorial_manual_assignment) {
        kc_prefill_single_assignment_target(engine);
    }
}

static int32_t kc_play_card_index(KCEngine *engine, int32_t player_id, int32_t card_index) {
    KCCard card = kc_list_remove_at(&engine->players[player_id].hand, card_index);
    engine->current_trick[engine->current_trick_count++] = (KCTrickPlay){
        .player_id = player_id,
        .card = card
    };
    kc_emit_transition(engine, (KCTransitionEvent){
        .kind = KC_TRANSITION_CARD_MOVED,
        .player_id = player_id,
        .card = card,
        .from_zone = KC_OBJECT_ZONE_HAND,
        .to_zone = KC_OBJECT_ZONE_CURRENT_TRICK,
        .from_owner = player_id,
        .to_owner = player_id,
        .target_suit = KC_NO_SUIT,
        .trick_winner = kc_trick_winner(engine)
    });
    if (engine->current_trick_count == KC_PLAYER_COUNT) {
        kc_resolve_current_trick(engine);
    } else {
        engine->current_player = (player_id + 1) % KC_PLAYER_COUNT;
    }
    return 0;
}

int32_t kc_work_value(const KCEngine *engine, KCCard card) {
    if (engine->variants.nomenclature && card.value == 11 && card.suit == engine->trump) {
        return 0;
    }
    return card.value;
}

bool kc_job_contains_wrecker(const KCEngine *engine, int32_t suit) {
    if (!engine || !kc_valid_suit(suit)) {
        return false;
    }
    const KCCardList *bucket = &engine->job_buckets[suit];
    for (int32_t i = 0; i < bucket->count; i++) {
        if (kc_card_is_wrecker(bucket->cards[i])) {
            return true;
        }
    }
    return false;
}

static bool kc_card_already_exiled_this_year(const KCEngine *engine, KCCard card) {
    if (!engine || engine->year < 0 || engine->year > KC_MAX_YEARS) {
        return false;
    }
    return kc_list_contains(&engine->exiled[engine->year], card);
}

bool kc_assignment_target_legal(const KCEngine *engine, int32_t target_suit) {
    for (int32_t i = 0; i < engine->last_trick_count; i++) {
        if (kc_card_matches_suit(engine->last_trick[i].card, target_suit)) {
            return true;
        }
    }
    return false;
}

int32_t kc_pending_assignment_count(const KCEngine *engine) {
    int32_t count = 0;
    for (int32_t i = 0; i < engine->last_trick_count; i++) {
        if (engine->pending_assignment_targets[i] >= 0) {
            count++;
        }
    }
    return count;
}

static void kc_sort_cards_ascending(KCCard *cards, int32_t count) {
    for (int32_t i = 1; i < count; i++) {
        KCCard value = cards[i];
        int32_t j = i - 1;
        while (j >= 0 && cards[j].value > value.value) {
            cards[j + 1] = cards[j];
            j--;
        }
        cards[j + 1] = value;
    }
}

static void kc_claim_job_if_needed(KCEngine *engine, int32_t suit) {
    if (engine->work_hours[suit] < KC_WORK_THRESHOLD || engine->claimed_jobs[suit]) {
        return;
    }
    engine->claimed_jobs[suit] = true;
    int32_t winner = engine->last_winner;
    if (winner < 0) {
        return;
    }
    if (engine->variants.deck_type == 36 && engine->variants.orden_nachalniku) {
        KCCardList *bucket = &engine->job_buckets[suit];
        if (bucket->count <= 0 || engine->players[winner].stack_count >= KC_MAX_STACKS) {
            return;
        }
        int32_t lowest_index = 0;
        for (int32_t i = 1; i < bucket->count; i++) {
            if (bucket->cards[i].value < bucket->cards[lowest_index].value) {
                lowest_index = i;
            }
        }
        KCPlotStack *stack = &engine->players[winner].stacks[engine->players[winner].stack_count++];
        memset(stack, 0, sizeof(*stack));
        KCCard lowest = bucket->cards[lowest_index];
        stack->revealed[stack->revealed_count++] = lowest;
        KCCard hidden[KC_MAX_CARDS];
        int32_t hidden_count = 0;
        for (int32_t i = 0; i < bucket->count; i++) {
            if (i != lowest_index) {
                hidden[hidden_count++] = bucket->cards[i];
            }
        }
        kc_sort_cards_ascending(hidden, hidden_count);
        for (int32_t i = 0; i < hidden_count; i++) {
            stack->hidden[stack->hidden_count++] = hidden[i];
        }
        kc_list_clear(bucket);
    } else if (engine->variants.deck_type != 36 && !engine->variants.northern_style && engine->has_revealed_job[suit]) {
        KCCard reward = engine->revealed_jobs[suit];
        if (engine->variants.accumulate_jobs) {
            for (int32_t i = 0; i < engine->accumulated_job_cards[suit].count; i++) {
                kc_list_append(&engine->players[winner].plot_revealed, engine->accumulated_job_cards[suit].cards[i]);
            }
            kc_list_clear(&engine->accumulated_job_cards[suit]);
        }
        kc_list_append(&engine->players[winner].plot_revealed, reward);
        kc_emit_transition(engine, (KCTransitionEvent){
            .kind = KC_TRANSITION_CARD_MOVED,
            .player_id = winner,
            .card = reward,
            .from_zone = KC_OBJECT_ZONE_REVEALED_JOB,
            .to_zone = KC_OBJECT_ZONE_PLOT_REVEALED,
            .from_owner = suit,
            .to_owner = winner,
            .target_suit = suit
        });
        engine->has_revealed_job[suit] = false;
        engine->revealed_jobs[suit] = kc_no_card();
    }
}

static void kc_apply_assignments(KCEngine *engine) {
    for (int32_t i = 0; i < engine->last_trick_count; i++) {
        int32_t target_suit = engine->pending_assignment_targets[i];
        if (target_suit < 0) {
            continue;
        }
        KCCard card = engine->last_trick[i].card;
        int32_t bucket_index = engine->job_buckets[target_suit].count;
        kc_list_append(&engine->job_buckets[target_suit], card);
        if (bucket_index < KC_MAX_CARDS) {
            engine->job_bucket_tricks[target_suit][bucket_index] = engine->trick_count;
        }
        engine->work_hours[target_suit] += kc_work_value(engine, card);
    }
    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        kc_claim_job_if_needed(engine, suit);
    }
}

static bool kc_is_year_complete(const KCEngine *engine) {
    int32_t expected_tricks = engine->is_famine ? 3 : 4;
    if (engine->trick_count >= expected_tricks) {
        return true;
    }
    bool all_one = true;
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        int32_t count = engine->players[player_id].hand.count;
        if (count == 0) {
            return true;
        }
        if (count != 1) {
            all_one = false;
        }
    }
    return all_one;
}

static void kc_move_remaining_hands_to_plots(KCEngine *engine) {
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        KCPlayer *player = &engine->players[player_id];
        for (int32_t i = 0; i < player->hand.count; i++) {
            KCCard card = player->hand.cards[i];
            kc_list_append(&player->plot_hidden, card);
            kc_emit_transition(engine, (KCTransitionEvent){
                .kind = KC_TRANSITION_CARD_MOVED,
                .player_id = player_id,
                .card = card,
                .from_zone = KC_OBJECT_ZONE_HAND,
                .to_zone = KC_OBJECT_ZONE_PLOT_HIDDEN,
                .from_owner = player_id,
                .to_owner = player_id,
                .target_suit = KC_NO_SUIT
            });
        }
        kc_list_clear(&player->hand);
    }
}

static int32_t kc_hero_player_id(const KCEngine *engine) {
    int32_t required = engine->is_famine ? 3 : 4;
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        if (engine->players[player_id].medals == required) {
            return player_id;
        }
    }
    return KC_NO_PLAYER;
}

static void kc_append_exiled(KCEngine *engine, KCCard card, int32_t player_id);

static void kc_append_exiled(KCEngine *engine, KCCard card, int32_t player_id) {
    KCCardList *cards = &engine->exiled[engine->year];
    if (cards->count >= KC_MAX_CARDS) return;
    engine->exiled_player_ids[engine->year][cards->count] = player_id;
    kc_list_append(cards, card);
}

static bool kc_handle_drunkard(KCEngine *engine, int32_t suit) {
    if (!engine->variants.nomenclature || engine->trump < 0) {
        return false;
    }
    KCCardList *bucket = &engine->job_buckets[suit];
    for (int32_t i = 0; i < bucket->count; i++) {
        KCCard card = bucket->cards[i];
        if (card.value == 11 && card.suit == engine->trump) {
            kc_append_exiled(engine, card, KC_NO_PLAYER);
            if (engine->has_revealed_job[suit]) {
                kc_list_append(&engine->drunkard_replacements, engine->revealed_jobs[suit]);
            }
            if (engine->requisition_event_count < KC_MAX_CARDS) {
                engine->requisition_events[engine->requisition_event_count++] = (KCRequisitionEvent){
                    .player_id = KC_NO_PLAYER,
                    .suit = suit,
                    .card = card,
                    .message_kind = 3
                };
            }
            kc_emit_transition(engine, (KCTransitionEvent){
                .kind = KC_TRANSITION_CARD_MOVED,
                .player_id = KC_NO_PLAYER,
                .card = card,
                .from_zone = KC_OBJECT_ZONE_JOB_BUCKET,
                .to_zone = KC_OBJECT_ZONE_EXILED,
                .from_owner = KC_NO_PLAYER,
                .to_owner = KC_NO_PLAYER,
                .target_suit = suit
            });
            return true;
        }
    }
    return false;
}

static void kc_reveal_hidden_cards(KCEngine *engine, int32_t player_id, int32_t suit, bool reveal_all) {
    KCPlayer *player = &engine->players[player_id];
    if (reveal_all) {
        int32_t index = 0;
        while (index < player->plot_hidden.count) {
            KCCard card = player->plot_hidden.cards[index];
            if (kc_card_matches_suit(card, suit)) {
                kc_list_remove_at(&player->plot_hidden, index);
                kc_list_append(&player->plot_revealed, card);
            } else {
                index++;
            }
        }
    } else {
        int32_t best_index = -1;
        for (int32_t i = 0; i < player->plot_hidden.count; i++) {
            KCCard card = player->plot_hidden.cards[i];
            if (kc_card_matches_suit(card, suit) &&
                (best_index < 0 || card.value > player->plot_hidden.cards[best_index].value)) {
                best_index = i;
            }
        }
        if (best_index >= 0) {
            KCCard card = kc_list_remove_at(&player->plot_hidden, best_index);
            kc_list_append(&player->plot_revealed, card);
        }
    }
}

static int32_t kc_requisition_event_suit_for_card(
    KCCard card,
    const bool active_suits[KC_SUIT_COUNT],
    const bool vulnerable_suits[KC_SUIT_COUNT]
);

static bool kc_requisition_card_eligible(
    const KCEngine *engine,
    int32_t player_id,
    KCCard card
) {
    if (!kc_valid_player_id(player_id) ||
        kc_card_already_exiled_this_year(engine, card)) {
        return false;
    }
    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        if (engine->requisition_player_suits[player_id][suit] &&
            kc_card_matches_suit(card, suit)) {
            return true;
        }
    }
    return false;
}

static int32_t kc_requisition_highest_value(const KCEngine *engine, int32_t player_id) {
    if (!kc_valid_player_id(player_id) || !engine->requisition_target_players[player_id]) {
        return -1;
    }
    int32_t highest = -1;
    const KCPlayer *player = &engine->players[player_id];
    for (int32_t i = 0; i < player->plot_revealed.count; i++) {
        KCCard card = player->plot_revealed.cards[i];
        if (kc_requisition_card_eligible(engine, player_id, card) && card.value > highest) {
            highest = card.value;
        }
    }
    for (int32_t i = 0; i < player->plot_hidden.count; i++) {
        KCCard card = player->plot_hidden.cards[i];
        if (kc_requisition_card_eligible(engine, player_id, card) && card.value > highest) {
            highest = card.value;
        }
    }
    return highest;
}

static bool kc_requisition_choices_complete(const KCEngine *engine) {
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        if (engine->requisition_target_players[player_id] &&
            !engine->requisition_choice_confirmed[player_id]) {
            return false;
        }
    }
    return true;
}

static int32_t kc_first_requisition_suit(const KCEngine *engine) {
    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        if (engine->requisition_active_suits[suit]) return suit;
    }
    return KC_NO_SUIT;
}

static void kc_prepare_requisition_round(KCEngine *engine) {
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        engine->requisition_choices[player_id] = kc_no_card();
        engine->requisition_choice_confirmed[player_id] =
            !engine->requisition_target_players[player_id] ||
            kc_requisition_highest_value(engine, player_id) < 0;
    }
    engine->current_player = KC_NO_PLAYER;
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        if (!engine->requisition_choice_confirmed[player_id]) {
            engine->current_player = player_id;
            break;
        }
    }
}

static void kc_reveal_requisition_choice(KCEngine *engine, int32_t player_id) {
    KCCard card = engine->requisition_choices[player_id];
    if (!kc_card_valid(card)) return;
    KCPlayer *player = &engine->players[player_id];
    int32_t hidden_index = kc_list_find(&player->plot_hidden, card);
    if (hidden_index >= 0) {
        kc_list_remove_at(&player->plot_hidden, hidden_index);
        kc_list_append(&player->plot_revealed, card);
    }
}

static void kc_hold_requisition_nomination(
    KCEngine *engine,
    int32_t player_id,
    KCCard card
) {
    for (int32_t i = 0; i < engine->requisition_held_nomination_count; i++) {
        if (engine->requisition_held_nominations[i].player_id == player_id &&
            kc_card_equal(engine->requisition_held_nominations[i].card, card)) {
            return;
        }
    }
    if (engine->requisition_held_nomination_count >= KC_MAX_CARDS) return;
    engine->requisition_held_nominations[
        engine->requisition_held_nomination_count++
    ] = (KCTrickPlay){.player_id = player_id, .card = card};
}

static void kc_release_requisition_nomination(
    KCEngine *engine,
    int32_t player_id,
    KCCard card
) {
    for (int32_t i = 0; i < engine->requisition_held_nomination_count; i++) {
        KCTrickPlay held = engine->requisition_held_nominations[i];
        if (held.player_id != player_id || !kc_card_equal(held.card, card)) continue;
        for (int32_t j = i; j + 1 < engine->requisition_held_nomination_count; j++) {
            engine->requisition_held_nominations[j] =
                engine->requisition_held_nominations[j + 1];
        }
        engine->requisition_held_nomination_count--;
        return;
    }
}

static void kc_configure_requisition_round_targets(KCEngine *engine) {
    memset(engine->requisition_target_players, 0, sizeof(engine->requisition_target_players));
    memset(engine->requisition_player_suits, 0, sizeof(engine->requisition_player_suits));
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        bool targeted = engine->requisition_individual_losses
            ? engine->requisition_individual_losses_remaining[player_id] > 0
            : engine->requisition_expanded_rounds_remaining > 0 ||
                engine->players[player_id].medals > 0;
        engine->requisition_target_players[player_id] = targeted;
        if (!targeted) continue;
        for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
            engine->requisition_player_suits[player_id][suit] =
                engine->requisition_active_suits[suit];
        }
    }
}

static void kc_resolve_requisition_round(KCEngine *engine) {
    bool individual_loss_round = engine->requisition_individual_losses;
    int32_t highest = -1;
    bool was_hidden[KC_PLAYER_COUNT] = {0};
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        was_hidden[player_id] = kc_list_find(
            &engine->players[player_id].plot_hidden,
            engine->requisition_choices[player_id]
        ) >= 0;
        kc_reveal_requisition_choice(engine, player_id);
        KCCard card = engine->requisition_choices[player_id];
        if (!kc_card_valid(card)) continue;
        if (card.value > highest) highest = card.value;
        kc_emit_transition(engine, (KCTransitionEvent){
            .kind = KC_TRANSITION_CARD_MOVED,
            .player_id = player_id,
            .card = card,
            .from_zone = was_hidden[player_id]
                ? KC_OBJECT_ZONE_PLOT_HIDDEN
                : KC_OBJECT_ZONE_PLOT_REVEALED,
            .to_zone = KC_OBJECT_ZONE_CURRENT_TRICK,
            .from_owner = player_id,
            .to_owner = player_id,
            .target_suit = kc_requisition_event_suit_for_card(
                card,
                engine->requisition_active_suits,
                engine->requisition_player_suits[player_id]
            )
        });
    }

    bool exiled_any = false;
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        KCCard card = engine->requisition_choices[player_id];
        if (!kc_card_valid(card)) continue;
        bool requisitioned = engine->requisition_individual_losses || card.value == highest;
        int32_t event_suit = kc_requisition_event_suit_for_card(
            card,
            engine->requisition_active_suits,
            engine->requisition_player_suits[player_id]
        );
        if (!requisitioned) {
            kc_hold_requisition_nomination(engine, player_id, card);
            kc_emit_transition(engine, (KCTransitionEvent){
                .kind = KC_TRANSITION_CARD_MOVED,
                .player_id = player_id,
                .card = card,
                .from_zone = KC_OBJECT_ZONE_CURRENT_TRICK,
                .to_zone = KC_OBJECT_ZONE_PLOT_REVEALED,
                .from_owner = player_id,
                .to_owner = player_id,
                .target_suit = event_suit
            });
            continue;
        }
        kc_release_requisition_nomination(engine, player_id, card);
        kc_append_exiled(engine, card, player_id);
        kc_emit_transition(engine, (KCTransitionEvent){
            .kind = KC_TRANSITION_CARD_MOVED,
            .player_id = player_id,
            .card = card,
            .from_zone = KC_OBJECT_ZONE_CURRENT_TRICK,
            .to_zone = KC_OBJECT_ZONE_EXILED,
            .from_owner = player_id,
            .to_owner = KC_NO_PLAYER,
            .target_suit = event_suit
        });
        if (engine->requisition_event_count < KC_MAX_CARDS) {
            engine->requisition_events[engine->requisition_event_count++] = (KCRequisitionEvent){
                .player_id = player_id,
                .suit = event_suit,
                .card = card,
                .message_kind = 1
            };
        }
        exiled_any = true;
    }
    if (!exiled_any && !individual_loss_round &&
        engine->requisition_event_count < KC_MAX_CARDS) {
        engine->requisition_events[engine->requisition_event_count++] = (KCRequisitionEvent){
            .player_id = KC_NO_PLAYER,
            .suit = kc_first_requisition_suit(engine),
            .card = kc_no_card(),
            .message_kind = 2
        };
    }

    engine->requisition_rounds_remaining--;
    if (individual_loss_round) {
        bool individual_losses_remain = false;
        for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
            if (engine->requisition_individual_losses_remaining[player_id] > 0) {
                engine->requisition_individual_losses_remaining[player_id]--;
            }
            individual_losses_remain = individual_losses_remain ||
                engine->requisition_individual_losses_remaining[player_id] > 0;
        }
        engine->requisition_individual_losses = individual_losses_remain;
    } else {
        if (engine->requisition_competitive_rounds_remaining > 0) {
            engine->requisition_competitive_rounds_remaining--;
        }
        if (engine->requisition_expanded_rounds_remaining > 0) {
            engine->requisition_expanded_rounds_remaining--;
        }
    }
    if (engine->requisition_rounds_remaining > 0) {
        kc_configure_requisition_round_targets(engine);
        kc_prepare_requisition_round(engine);
    } else {
        engine->current_player = 0;
    }
}

static void kc_resolve_empty_requisition_rounds(KCEngine *engine) {
    while (engine->requisition_rounds_remaining > 0 &&
        kc_requisition_choices_complete(engine)) {
        kc_resolve_requisition_round(engine);
    }
}

static int32_t kc_commit_requisition_choice(
    KCEngine *engine,
    int32_t player_id,
    KCCard card
) {
    if (engine->phase != KC_PHASE_REQUISITION ||
        engine->requisition_rounds_remaining <= 0) {
        return KC_ERR_WRONG_PHASE;
    }
    if (!kc_valid_player_id(player_id) ||
        !engine->requisition_target_players[player_id] ||
        engine->requisition_choice_confirmed[player_id]) {
        return KC_ERR_WRONG_PLAYER;
    }
    int32_t highest = kc_requisition_highest_value(engine, player_id);
    if (highest < 0 || card.value != highest ||
        !kc_requisition_card_eligible(engine, player_id, card) ||
        (kc_list_find(&engine->players[player_id].plot_revealed, card) < 0 &&
         kc_list_find(&engine->players[player_id].plot_hidden, card) < 0)) {
        return KC_ERR_INVALID_CARD;
    }
    engine->requisition_choices[player_id] = card;
    engine->requisition_choice_confirmed[player_id] = true;
    if (kc_requisition_choices_complete(engine)) {
        kc_resolve_requisition_round(engine);
        kc_resolve_empty_requisition_rounds(engine);
    } else {
        for (int32_t candidate = 0; candidate < KC_PLAYER_COUNT; candidate++) {
            if (!engine->requisition_choice_confirmed[candidate]) {
                engine->current_player = candidate;
                break;
            }
        }
    }
    return 0;
}

static int32_t kc_requisition_event_suit_for_card(
    KCCard card,
    const bool active_suits[KC_SUIT_COUNT],
    const bool vulnerable_suits[KC_SUIT_COUNT]
) {
    if (!kc_card_is_wrecker(card) && card.suit >= 0 && card.suit < KC_SUIT_COUNT) {
        return card.suit;
    }
    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        if (active_suits[suit] && vulnerable_suits[suit]) return suit;
    }
    return KC_NO_SUIT;
}

static void kc_begin_core_requisition(KCEngine *engine) {
    bool informant[KC_SUIT_COUNT] = {0};
    bool party_official[KC_SUIT_COUNT] = {0};
    int32_t active_count = 0;
    int32_t hero_id = engine->variants.hero_of_soviet_union
        ? kc_hero_player_id(engine)
        : KC_NO_PLAYER;

    memset(engine->requisition_active_suits, 0, sizeof(engine->requisition_active_suits));
    memset(engine->requisition_player_suits, 0, sizeof(engine->requisition_player_suits));
    memset(engine->requisition_target_players, 0, sizeof(engine->requisition_target_players));
    memset(engine->requisition_choice_confirmed, 0, sizeof(engine->requisition_choice_confirmed));
    memset(
        engine->requisition_individual_losses_remaining,
        0,
        sizeof(engine->requisition_individual_losses_remaining)
    );
    engine->requisition_rounds_remaining = 0;
    engine->requisition_individual_losses = false;
    engine->requisition_competitive_rounds_remaining = 0;
    engine->requisition_expanded_rounds_remaining = 0;

    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        if (engine->work_hours[suit] >= KC_WORK_THRESHOLD && !kc_job_contains_wrecker(engine, suit)) {
            continue;
        }
        if (kc_handle_drunkard(engine, suit)) {
            continue;
        }
        engine->requisition_active_suits[suit] = true;
        active_count++;
        if (engine->variants.nomenclature && engine->trump >= 0) {
            for (int32_t i = 0; i < engine->job_buckets[suit].count; i++) {
                KCCard card = engine->job_buckets[suit].cards[i];
                informant[suit] = informant[suit] ||
                    (card.suit == engine->trump && card.value == 12);
                party_official[suit] = party_official[suit] ||
                    (card.suit == engine->trump && card.value == 13);
            }
        }
    }

    bool party_bonus = false;
    bool informant_active = false;
    bool informant_party_same_field = false;
    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        if (!engine->requisition_active_suits[suit]) continue;
        party_bonus = party_bonus || party_official[suit];
        informant_active = informant_active || informant[suit];
        informant_party_same_field = informant_party_same_field ||
            (informant[suit] && party_official[suit]);
        for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
            if (engine->variants.mice_variant ||
                (informant[suit] && !(hero_id >= 0 && player_id == hero_id))) {
                kc_reveal_hidden_cards(engine, player_id, suit, true);
            }
        }
    }

    bool universal_override = engine->variants.northern_style || engine->variants.mice_variant;
    int32_t individual_round_count = 0;
    if (active_count > 0 && universal_override) {
        individual_round_count = active_count + (party_bonus ? 1 : 0);
        for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
            engine->requisition_individual_losses_remaining[player_id] =
                individual_round_count;
        }
    } else if (active_count > 0 && hero_id >= 0) {
        individual_round_count = engine->players[hero_id].medals;
        for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
            if (player_id == hero_id) continue;
            engine->requisition_individual_losses_remaining[player_id] =
                individual_round_count;
        }
        if (engine->requisition_event_count < KC_MAX_CARDS) {
            engine->requisition_events[engine->requisition_event_count++] = (KCRequisitionEvent){
                .player_id = hero_id,
                .suit = KC_NO_SUIT,
                .card = kc_no_card(),
                .message_kind = 4
            };
        }
    } else if (active_count > 0) {
        for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
            int32_t losses = engine->players[player_id].medals;
            engine->requisition_individual_losses_remaining[player_id] = losses;
            if (losses > individual_round_count) individual_round_count = losses;
        }
        engine->requisition_competitive_rounds_remaining =
            active_count + (party_bonus ? 1 : 0);
        if (informant_active) {
            engine->requisition_expanded_rounds_remaining =
                1 + (informant_party_same_field ? 1 : 0);
        }
    }

    engine->requisition_individual_losses = individual_round_count > 0;
    engine->requisition_rounds_remaining =
        individual_round_count + engine->requisition_competitive_rounds_remaining;
    if (engine->requisition_rounds_remaining > 0) {
        kc_configure_requisition_round_targets(engine);
        kc_prepare_requisition_round(engine);
        kc_resolve_empty_requisition_rounds(engine);
    }
}

static void kc_perform_requisition_batch(KCEngine *engine) {
    engine->phase = KC_PHASE_REQUISITION;
    engine->current_player = 0;
    engine->requisition_event_count = 0;
    engine->requisition_held_nomination_count = 0;
    kc_begin_core_requisition(engine);
}

static bool kc_requisition_reveal_all(const KCEngine *engine, int32_t suit) {
    if (engine->variants.mice_variant) return true;
    if (!engine->variants.nomenclature || engine->trump < 0) return false;
    for (int32_t i = 0; i < engine->job_buckets[suit].count; i++) {
        KCCard card = engine->job_buckets[suit].cards[i];
        if (card.suit == engine->trump && card.value == 12) return true;
    }
    return false;
}

static bool kc_step_requisition(KCEngine *engine) {
    if (!engine || engine->phase != KC_PHASE_REQUISITION ||
        engine->requisition_plan_index >= engine->requisition_plan_count) {
        return false;
    }
    int32_t event_index = engine->requisition_plan_index++;
    KCRequisitionEvent event = engine->requisition_plan[event_index];
    int32_t source_zone = KC_OBJECT_ZONE_PLOT_REVEALED;
    if (event.player_id >= 0 && event.player_id < KC_PLAYER_COUNT &&
        kc_list_contains(&engine->players[event.player_id].plot_hidden, event.card)) {
        source_zone = KC_OBJECT_ZONE_PLOT_HIDDEN;
    }
    bool exiles_plot_card = event.message_kind == 1 || event.message_kind == 5;
    if (exiles_plot_card && event.player_id >= 0 && event.player_id < KC_PLAYER_COUNT) {
        if (event.message_kind == 1 && kc_requisition_reveal_all(engine, event.suit)) {
            kc_reveal_hidden_cards(engine, event.player_id, event.suit, true);
        }
        kc_append_exiled(engine, event.card, event.player_id);
    } else if (event.message_kind == 3) {
        kc_append_exiled(engine, event.card, KC_NO_PLAYER);
        if (event.suit >= 0 && event.suit < KC_SUIT_COUNT && engine->has_revealed_job[event.suit]) {
            kc_list_append(&engine->drunkard_replacements, engine->revealed_jobs[event.suit]);
        }
    }
    if (engine->requisition_event_count < KC_MAX_CARDS) {
        engine->requisition_events[engine->requisition_event_count++] = event;
    }
    if (kc_card_valid(event.card)) {
        kc_emit_transition(engine, (KCTransitionEvent){
            .kind = KC_TRANSITION_CARD_MOVED,
            .player_id = event.player_id,
            .card = event.card,
            .from_zone = event.message_kind == 3
                ? KC_OBJECT_ZONE_JOB_BUCKET
                : source_zone,
            .to_zone = KC_OBJECT_ZONE_EXILED,
            .from_owner = event.player_id,
            .to_owner = KC_NO_PLAYER,
            .target_suit = event.suit
        });
    }
    return true;
}

static void kc_perform_requisition(KCEngine *engine) {
    engine->requisition_plan_count = 0;
    engine->requisition_plan_index = 0;
    kc_perform_requisition_batch(engine);
}

static void kc_advance_after_assignments(KCEngine *engine) {
    if (kc_is_year_complete(engine)) {
        kc_move_remaining_hands_to_plots(engine);
        kc_perform_requisition(engine);
    } else {
        engine->phase = KC_PHASE_TRICK;
        engine->current_player = engine->lead;
    }
}

static void kc_remove_exiled_cards(KCEngine *engine) {
    KCCardList *cards = &engine->exiled[engine->year];
    for (int32_t exiled_index = 0; exiled_index < cards->count; exiled_index++) {
        KCCard card = cards->cards[exiled_index];
        for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
            int32_t index = kc_list_find(&engine->players[player_id].plot_revealed, card);
            if (index >= 0) {
                kc_list_remove_at(&engine->players[player_id].plot_revealed, index);
                break;
            }
            index = kc_list_find(&engine->players[player_id].plot_hidden, card);
            if (index >= 0) {
                kc_list_remove_at(&engine->players[player_id].plot_hidden, index);
                break;
            }
        }
    }
}

int32_t kc_visible_score(const KCEngine *engine, int32_t player_id) {
    if (player_id < 0 || player_id >= KC_PLAYER_COUNT) {
        return 0;
    }
    const KCPlayer *player = &engine->players[player_id];
    int32_t score = 0;
    for (int32_t i = 0; i < player->plot_revealed.count; i++) {
        score += player->plot_revealed.cards[i].value;
    }
    for (int32_t stack_index = 0; stack_index < player->stack_count; stack_index++) {
        const KCPlotStack *stack = &player->stacks[stack_index];
        for (int32_t i = 0; i < stack->revealed_count; i++) {
            score += stack->revealed[i].value;
        }
    }
    if (engine->variants.medals_count) {
        score += player->plot_medals + player->medals;
    }
    return score;
}

int32_t kc_final_score(const KCEngine *engine, int32_t player_id) {
    if (player_id < 0 || player_id >= KC_PLAYER_COUNT) {
        return 0;
    }
    int32_t score = kc_visible_score(engine, player_id);
    const KCPlayer *player = &engine->players[player_id];
    for (int32_t i = 0; i < player->plot_hidden.count; i++) {
        score += player->plot_hidden.cards[i].value;
    }
    return score;
}

static void kc_finish_game(KCEngine *engine) {
    int32_t winner = 0;
    int32_t best_score = -1;
    int32_t best_medals = -1;
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        int32_t score = kc_final_score(engine, player_id);
        int32_t medals = engine->players[player_id].plot_medals + engine->players[player_id].medals;
        engine->game_scores[player_id] = score;
        if (score > best_score ||
            (score == best_score && medals > best_medals) ||
            (score == best_score && medals == best_medals && player_id > winner)) {
            best_score = score;
            best_medals = medals;
            winner = player_id;
        }
    }
    engine->winner_id = winner;
    engine->phase = KC_PHASE_GAME_OVER;
    engine->current_player = 0;
}

static void kc_transition_to_next_year(KCEngine *engine) {
    engine->requisition_held_nomination_count = 0;
    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        if (engine->variants.deck_type == 36 || engine->variants.northern_style) {
            continue;
        }
        /* Unclaimed managed rewards rejoin the next worker deck. */
        if (engine->has_revealed_job[suit] && !engine->variants.managed_economy) {
            if (engine->variants.accumulate_jobs) {
                kc_list_append(&engine->accumulated_job_cards[suit], engine->revealed_jobs[suit]);
            } else {
                kc_append_exiled(engine, engine->revealed_jobs[suit], KC_NO_PLAYER);
            }
        }
    }
    if (engine->year >= kc_variant_max_years(engine->variants)) {
        kc_finish_game(engine);
        return;
    }
    engine->year += 1;
    engine->trick_count = 0;
    engine->current_trick_count = 0;
    engine->last_trick_count = 0;
    engine->last_winner = KC_NO_PLAYER;
    engine->trump = KC_NO_SUIT;
    if (engine->tutorial_mode &&
        (engine->year == 3 || engine->year == KC_MAX_YEARS)) {
        engine->lead = 3;
    }
    engine->requisition_event_count = 0;
    engine->requisition_plan_count = 0;
    engine->requisition_plan_index = 0;
    memset(engine->swap_confirmed, 0, sizeof(engine->swap_confirmed));
    memset(engine->swap_count, 0, sizeof(engine->swap_count));
    kc_clear_last_swap(engine);
    kc_reset_year_work(engine);
    if (engine->variants.orden_nachalniku && engine->variants.deck_type == 36) {
        for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
            KCPlayer *player = &engine->players[player_id];
            for (int32_t stack_index = 0; stack_index < player->stack_count; stack_index++) {
                KCPlotStack *stack = &player->stacks[stack_index];
                for (int32_t i = 0; i < stack->revealed_count; i++) {
                    kc_list_append(&player->plot_revealed, stack->revealed[i]);
                }
            }
            player->stack_count = 0;
        }
    }
    kc_clear_revealed_jobs(engine);
    engine->is_famine = engine->year == KC_MAX_YEARS;
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        KCPlayer *player = &engine->players[player_id];
        player->plot_medals += player->medals;
        player->medals = 0;
        player->has_won_trick_this_year = false;
        player->brigade_leader = false;
    }
    engine->trump_selector = (engine->trump_selector + 1) % KC_PLAYER_COUNT;
    engine->current_player = engine->trump_selector;
    engine->phase = KC_PHASE_PLANNING;
    kc_deal_hands(engine);
}

static int32_t kc_swap_card(KCEngine *engine, int32_t player_id, KCCard hand_card, KCCard plot_card, int32_t zone) {
    int32_t hand_index = kc_list_find(&engine->players[player_id].hand, hand_card);
    if (hand_index < 0) {
        return KC_ERR_INVALID_CARD;
    }
    KCCardList *plot = zone == KC_ZONE_REVEALED ?
        &engine->players[player_id].plot_revealed :
        &engine->players[player_id].plot_hidden;
    int32_t plot_index = kc_list_find(plot, plot_card);
    if (plot_index < 0) {
        return KC_ERR_INVALID_CARD;
    }
    plot->cards[plot_index] = hand_card;
    engine->players[player_id].hand.cards[hand_index] = plot_card;
    engine->swap_count[player_id] = true;
    engine->has_last_swap = true;
    engine->last_swap_player_id = player_id;
    engine->last_swap_plot_zone = zone;
    engine->last_swap_plot_index = plot_index;
    engine->last_swap_hand_index = hand_index;
    engine->last_swap_new_plot_card = hand_card;
    int32_t plot_object_zone = zone == KC_ZONE_REVEALED
        ? KC_OBJECT_ZONE_PLOT_REVEALED
        : KC_OBJECT_ZONE_PLOT_HIDDEN;
    kc_emit_transition(engine, (KCTransitionEvent){
        .kind = KC_TRANSITION_CARD_MOVED,
        .player_id = player_id,
        .card = hand_card,
        .from_zone = KC_OBJECT_ZONE_HAND,
        .to_zone = plot_object_zone,
        .from_owner = player_id,
        .to_owner = player_id,
        .target_suit = KC_NO_SUIT
    });
    kc_emit_transition(engine, (KCTransitionEvent){
        .kind = KC_TRANSITION_CARD_MOVED,
        .player_id = player_id,
        .card = plot_card,
        .from_zone = plot_object_zone,
        .to_zone = KC_OBJECT_ZONE_HAND,
        .from_owner = player_id,
        .to_owner = player_id,
        .target_suit = KC_NO_SUIT
    });
    return 0;
}

static int32_t kc_undo_swap(KCEngine *engine, int32_t player_id) {
    if (!engine->has_last_swap ||
        engine->last_swap_player_id != player_id ||
        !engine->swap_count[player_id] ||
        engine->last_swap_hand_index < 0 ||
        engine->last_swap_hand_index >= engine->players[player_id].hand.count) {
        return KC_ERR_INVALID_CARD;
    }
    KCCardList *plot = engine->last_swap_plot_zone == KC_ZONE_REVEALED ?
        &engine->players[player_id].plot_revealed :
        &engine->players[player_id].plot_hidden;
    if (engine->last_swap_plot_index < 0 || engine->last_swap_plot_index >= plot->count) {
        return KC_ERR_INVALID_CARD;
    }
    KCCard temporary = plot->cards[engine->last_swap_plot_index];
    KCCard returned_to_plot = engine->players[player_id].hand.cards[engine->last_swap_hand_index];
    plot->cards[engine->last_swap_plot_index] = returned_to_plot;
    engine->players[player_id].hand.cards[engine->last_swap_hand_index] = temporary;
    int32_t plot_object_zone = engine->last_swap_plot_zone == KC_ZONE_REVEALED
        ? KC_OBJECT_ZONE_PLOT_REVEALED
        : KC_OBJECT_ZONE_PLOT_HIDDEN;
    kc_emit_transition(engine, (KCTransitionEvent){
        .kind = KC_TRANSITION_CARD_MOVED,
        .player_id = player_id,
        .card = temporary,
        .from_zone = plot_object_zone,
        .to_zone = KC_OBJECT_ZONE_HAND,
        .from_owner = player_id,
        .to_owner = player_id,
        .target_suit = KC_NO_SUIT
    });
    kc_emit_transition(engine, (KCTransitionEvent){
        .kind = KC_TRANSITION_CARD_MOVED,
        .player_id = player_id,
        .card = returned_to_plot,
        .from_zone = KC_OBJECT_ZONE_HAND,
        .to_zone = plot_object_zone,
        .from_owner = player_id,
        .to_owner = player_id,
        .target_suit = KC_NO_SUIT
    });
    engine->swap_count[player_id] = false;
    kc_clear_last_swap(engine);
    return 0;
}

static void kc_confirm_swap(KCEngine *engine, int32_t player_id) {
    engine->swap_confirmed[player_id] = true;
    int32_t confirmed = 0;
    for (int32_t i = 0; i < KC_PLAYER_COUNT; i++) {
        confirmed += engine->swap_confirmed[i] ? 1 : 0;
    }
    if (confirmed >= KC_PLAYER_COUNT) {
        engine->phase = KC_PHASE_TRICK;
        engine->current_player = engine->lead;
        memset(engine->swap_confirmed, 0, sizeof(engine->swap_confirmed));
        memset(engine->swap_count, 0, sizeof(engine->swap_count));
        kc_clear_last_swap(engine);
        return;
    }
    for (int32_t next = player_id + 1; next < KC_PLAYER_COUNT; next++) {
        if (!engine->swap_confirmed[next]) {
            engine->current_player = next;
            return;
        }
    }
}

static int32_t kc_engine_apply_action(KCEngine *engine, KCAction action) {
    int32_t player_id = action.player_id;
    switch (action.kind) {
    case KC_ACTION_COMPLETE_TUTORIAL_ORIENTATION:
        if (!engine->tutorial_mode ||
            engine->tutorial_orientation_complete ||
            engine->year != 1 ||
            engine->phase != KC_PHASE_PLANNING) {
            return KC_ERR_WRONG_PHASE;
        }
        engine->tutorial_orientation_complete = true;
        engine->current_player = engine->trump_selector;
        return 0;

    case KC_ACTION_COMPLETE_TUTORIAL_REWARD_LESSON:
        if (!engine->tutorial_mode ||
            !engine->tutorial_orientation_complete ||
            engine->tutorial_reward_lesson_complete ||
            engine->year != 1 ||
            engine->phase != KC_PHASE_PLANNING ||
            kc_next_reward_to_reveal(engine) != KC_NO_SUIT) {
            return KC_ERR_WRONG_PHASE;
        }
        engine->tutorial_reward_lesson_complete = true;
        engine->current_player = engine->trump_selector;
        return 0;

    case KC_ACTION_COMPLETE_TUTORIAL_SABOTEUR_FOLLOW_LESSON:
        if (!engine->tutorial_mode ||
            engine->tutorial_saboteur_follow_lesson_complete ||
            engine->year != 3 ||
            engine->phase != KC_PHASE_TRICK ||
            engine->trick_count != 0 ||
            engine->current_trick_count != 2 ||
            engine->current_trick[1].player_id != 0 ||
            !kc_card_is_wrecker(engine->current_trick[1].card)) {
            return KC_ERR_WRONG_PHASE;
        }
        engine->tutorial_saboteur_follow_lesson_complete = true;
        engine->current_player = 1;
        return 0;

    case KC_ACTION_REVEAL_TRUMP:
        if (engine->phase != KC_PHASE_PLANNING) {
            return KC_ERR_WRONG_PHASE;
        }
        if (!kc_is_active_turn(engine, player_id)) {
            return KC_ERR_WRONG_PLAYER;
        }
        if (kc_next_reward_to_reveal(engine) != KC_NO_SUIT ||
            !kc_card_valid(engine->pending_final_year_trump_card) ||
            kc_card_valid(engine->final_year_trump_card)) {
            return KC_ERR_INVALID_CARD;
        }
        engine->final_year_trump_card = engine->pending_final_year_trump_card;
        engine->pending_final_year_trump_card = kc_no_card();
        engine->trump = kc_card_is_wrecker(engine->final_year_trump_card)
            ? KC_NO_SUIT
            : engine->final_year_trump_card.suit;
        kc_append_exiled(engine, engine->final_year_trump_card, KC_NO_PLAYER);
        return 0;

    case KC_ACTION_REVEAL_REWARD:
        if (engine->phase != KC_PHASE_PLANNING) {
            return KC_ERR_WRONG_PHASE;
        }
        if (!kc_is_active_turn(engine, player_id)) {
            return KC_ERR_WRONG_PLAYER;
        }
        if (action.suit != kc_next_reward_to_reveal(engine)) {
            return KC_ERR_INVALID_CARD;
        }
        if (kc_managed_economy_active(engine)
                ? !kc_reveal_managed_reward(engine, action.suit)
                : !kc_reveal_job(engine, action.suit)) {
            return KC_ERR_INVALID_CARD;
        }
        if (engine->tutorial_mode &&
            engine->year == 1 &&
            !engine->tutorial_reward_lesson_complete &&
            kc_next_reward_to_reveal(engine) == KC_NO_SUIT) {
            engine->current_player = 0;
        }
        return 0;

    case KC_ACTION_ASSIGN_REWARD:
        if (engine->phase != KC_PHASE_PLANNING) {
            return KC_ERR_WRONG_PHASE;
        }
        if (!kc_is_active_turn(engine, player_id)) {
            return KC_ERR_WRONG_PLAYER;
        }
        return kc_assign_managed_reward(engine, action.suit, action.card)
            ? 0
            : KC_ERR_INVALID_CARD;

    case KC_ACTION_CONFIRM_REWARD_SWAPS:
        if (engine->phase != KC_PHASE_PLANNING) {
            return KC_ERR_WRONG_PHASE;
        }
        if (!kc_is_active_turn(engine, player_id)) {
            return KC_ERR_WRONG_PLAYER;
        }
        if (!kc_managed_rewards_ready_for_swaps(engine)) {
            return KC_ERR_INVALID_CARD;
        }
        engine->managed_rewards_confirmed = true;
        return 0;

    case KC_ACTION_SET_TRUMP:
        if (engine->phase != KC_PHASE_PLANNING) {
            return KC_ERR_WRONG_PHASE;
        }
        if (!kc_is_active_turn(engine, player_id)) {
            return KC_ERR_WRONG_PLAYER;
        }
        if (action.suit < 0 || action.suit >= KC_SUIT_COUNT) {
            return KC_ERR_INVALID_CARD;
        }
        if (kc_managed_economy_active(engine) &&
            !engine->managed_rewards_confirmed) {
            return KC_ERR_INVALID_CARD;
        }
        engine->trump = action.suit;
        kc_advance_from_planning(engine);
        return 0;

    case KC_ACTION_SWAP:
        if (engine->phase != KC_PHASE_SWAP) {
            return KC_ERR_WRONG_PHASE;
        }
        if (!kc_is_active_turn(engine, player_id)) {
            return KC_ERR_WRONG_PLAYER;
        }
        if (engine->swap_count[player_id]) {
            return KC_ERR_INVALID_CARD;
        }
        return kc_swap_card(engine, player_id, action.hand_card, action.plot_card, action.plot_zone);

    case KC_ACTION_CONFIRM_SWAP:
        if (engine->phase != KC_PHASE_SWAP) {
            return KC_ERR_WRONG_PHASE;
        }
        if (!kc_is_active_turn(engine, player_id)) {
            return KC_ERR_WRONG_PLAYER;
        }
        kc_confirm_swap(engine, player_id);
        return 0;

    case KC_ACTION_UNDO_SWAP:
        if (engine->phase != KC_PHASE_SWAP) {
            return KC_ERR_WRONG_PHASE;
        }
        if (!kc_is_active_turn(engine, player_id)) {
            return KC_ERR_WRONG_PLAYER;
        }
        return kc_undo_swap(engine, player_id);

    case KC_ACTION_PASS_CARD:
        if (engine->phase != KC_PHASE_PASS) {
            return KC_ERR_WRONG_PHASE;
        }
        return kc_commit_pass(engine, player_id, action.card);

    case KC_ACTION_PLAY_CARD: {
        if (engine->phase != KC_PHASE_TRICK) {
            return KC_ERR_WRONG_PHASE;
        }
        if (!kc_is_active_turn(engine, player_id)) {
            return KC_ERR_WRONG_PLAYER;
        }
        int32_t card_index = kc_list_find(&engine->players[player_id].hand, action.card);
        if (!kc_is_valid_play(engine, player_id, card_index)) {
            return KC_ERR_INVALID_CARD;
        }
        int32_t result = kc_play_card_index(engine, player_id, card_index);
        if (result == 0 &&
            engine->tutorial_mode &&
            engine->year == 3 &&
            engine->trick_count == 0 &&
            player_id == 0 &&
            kc_card_is_wrecker(action.card) &&
            !engine->tutorial_saboteur_follow_lesson_complete) {
            engine->current_player = 0;
        }
        return result;
    }

    case KC_ACTION_ASSIGN: {
        if (engine->phase != KC_PHASE_ASSIGNMENT) {
            return KC_ERR_WRONG_PHASE;
        }
        if (!kc_is_active_assignment(engine, player_id)) {
            return KC_ERR_WRONG_PLAYER;
        }
        if (!kc_assignment_target_legal(engine, action.target_suit)) {
            return KC_ERR_INVALID_ASSIGNMENT;
        }
        for (int32_t i = 0; i < engine->last_trick_count; i++) {
            if (engine->pending_assignment_targets[i] < 0 && kc_card_equal(engine->last_trick[i].card, action.card)) {
                engine->pending_assignment_targets[i] = action.target_suit;
                kc_emit_transition(engine, (KCTransitionEvent){
                    .kind = KC_TRANSITION_ASSIGNMENT_TARGETED,
                    .player_id = engine->last_trick[i].player_id,
                    .card = engine->last_trick[i].card,
                    .from_zone = KC_OBJECT_ZONE_LAST_TRICK,
                    .to_zone = KC_OBJECT_ZONE_PENDING_ASSIGNMENT,
                    .from_owner = engine->last_trick[i].player_id,
                    .to_owner = action.target_suit,
                    .target_suit = action.target_suit
                });
                return 0;
            }
        }
        return KC_ERR_INVALID_ASSIGNMENT;
    }

    case KC_ACTION_SUBMIT_ASSIGNMENTS:
        if (engine->phase != KC_PHASE_ASSIGNMENT) {
            return KC_ERR_WRONG_PHASE;
        }
        if (!kc_is_active_assignment(engine, player_id)) {
            return KC_ERR_WRONG_PLAYER;
        }
        if (kc_pending_assignment_count(engine) != engine->last_trick_count) {
            return KC_ERR_INVALID_ASSIGNMENT;
        }
        kc_apply_assignments(engine);
        for (int32_t i = 0; i < KC_PLAYER_COUNT; i++) {
            engine->pending_assignment_targets[i] = KC_NO_SUIT;
        }
        kc_advance_after_assignments(engine);
        return 0;

    case KC_ACTION_SELECT_REQUISITION_CARD:
        return kc_commit_requisition_choice(engine, player_id, action.card);

    case KC_ACTION_CONTINUE_AFTER_REQUISITION:
        if (engine->phase != KC_PHASE_REQUISITION) {
            return 0;
        }
        if (engine->requisition_plan_index < engine->requisition_plan_count ||
            engine->requisition_rounds_remaining > 0) {
            return KC_ERR_WRONG_PHASE;
        }
        kc_remove_exiled_cards(engine);
        kc_transition_to_next_year(engine);
        return 0;

    default:
        return KC_ERR_INVALID_CARD;
    }
}

int32_t kc_engine_apply(KCEngine *engine, KCAction action) {
    kc_engine_begin_transition_batch(engine);
    int32_t error = kc_engine_apply_action(engine, action);
    if (error == 0) {
        kc_process_automatic_turns(engine);
    }
    kc_engine_end_transition_batch(engine);
    return error;
}

int32_t kc_engine_apply_manual(KCEngine *engine, KCAction action) {
    kc_engine_begin_transition_batch(engine);
    int32_t error = kc_engine_apply_action(engine, action);
    kc_engine_end_transition_batch(engine);
    return error;
}

static void kc_add_action(KCAction *actions, int32_t max_actions, int32_t *count, KCAction action) {
    if (*count < max_actions) {
        actions[*count] = action;
    }
    *count += 1;
}

static int32_t kc_tutorial_assignment_target(
    const KCEngine *engine,
    int32_t play_index
) {
    if (!engine->tutorial_mode || engine->year < 1 || engine->year > 3) {
        return KC_NO_SUIT;
    }
    static const int32_t targets[3][4] = {
        {KC_SUIT_WHEAT, KC_SUIT_SUNFLOWER, KC_SUIT_POTATO, KC_SUIT_BEET},
        {KC_SUIT_POTATO, KC_NO_SUIT, KC_SUIT_SUNFLOWER, KC_SUIT_WHEAT},
        {KC_SUIT_BEET, KC_SUIT_BEET, KC_SUIT_SUNFLOWER, KC_SUIT_POTATO}
    };
    if (engine->trick_count < 1 || engine->trick_count > 4) {
        return KC_NO_SUIT;
    }
    if (engine->year == 2 && engine->trick_count == 2) {
        if (play_index < 0 || play_index >= engine->last_trick_count) {
            return KC_NO_SUIT;
        }
        return engine->last_trick[play_index].card.suit == KC_SUIT_WHEAT
            ? KC_SUIT_WHEAT
            : KC_SUIT_BEET;
    }
    return targets[engine->year - 1][engine->trick_count - 1];
}

static int32_t kc_tutorial_famine_off_suit(const KCEngine *engine) {
    int32_t counts[KC_SUIT_COUNT] = {0};
    const KCCardList *hand = &engine->players[0].hand;
    for (int32_t index = 0; index < hand->count; index++) {
        KCCard card = hand->cards[index];
        if (card.suit >= 0 &&
            card.suit < KC_SUIT_COUNT &&
            card.suit != engine->trump) {
            counts[card.suit]++;
        }
    }
    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        if (counts[suit] >= 2) {
            return suit;
        }
    }
    return KC_NO_SUIT;
}

static int32_t kc_tutorial_famine_void_suit(const KCEngine *engine) {
    if (engine->tutorial_famine_void_suit >= 0 &&
        engine->tutorial_famine_void_suit < KC_SUIT_COUNT) {
        return engine->tutorial_famine_void_suit;
    }
    int32_t off_suit = kc_tutorial_famine_off_suit(engine);
    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        if (suit == engine->trump || suit == off_suit) {
            continue;
        }
        bool every_opponent_has_suit = true;
        for (int32_t player_id = 1; player_id < KC_PLAYER_COUNT; player_id++) {
            bool found = false;
            const KCCardList *hand = &engine->players[player_id].hand;
            for (int32_t index = 0; index < hand->count; index++) {
                if (hand->cards[index].suit == suit) {
                    found = true;
                    break;
                }
            }
            every_opponent_has_suit = every_opponent_has_suit && found;
        }
        if (every_opponent_has_suit) {
            return suit;
        }
    }
    return KC_NO_SUIT;
}

static bool kc_tutorial_play_allowed(
    const KCEngine *engine,
    int32_t player_id,
    KCCard card
) {
    if (!engine->tutorial_mode || engine->year < 1) {
        return true;
    }
    if (engine->year == 4) {
        const KCCardList *hand = &engine->players[player_id].hand;
        for (int32_t index = 0; index < hand->count; index++) {
            if (kc_card_is_wrecker(hand->cards[index])) {
                return kc_card_is_wrecker(card);
            }
        }
        return true;
    }
    if (engine->year == KC_MAX_YEARS) {
        int32_t trick = engine->trick_count;
        int32_t off_suit = kc_tutorial_famine_off_suit(engine);
        int32_t void_suit = engine->current_trick_count > 0
            ? kc_lead_suit(engine)
            : kc_tutorial_famine_void_suit(engine);
        if (trick == 0) {
            if (player_id != 0) {
                return card.suit == void_suit;
            }
            int32_t lower_trump = 100;
            const KCCardList *hand = &engine->players[0].hand;
            for (int32_t index = 0; index < hand->count; index++) {
                KCCard candidate = hand->cards[index];
                if (candidate.suit == engine->trump &&
                    candidate.value < lower_trump) {
                    lower_trump = candidate.value;
                }
            }
            return card.suit == engine->trump && card.value == lower_trump;
        }
        if (trick == 1) {
            if (player_id == 1) {
                return kc_card_is_wrecker(card);
            }
            return card.suit == engine->trump;
        }
        if (trick == 2) {
            int32_t closing_suit = engine->current_trick_count > 0
                ? kc_lead_suit(engine)
                : off_suit;
            if (player_id != 0) {
                return true;
            }
            int32_t highest_closer = -1;
            const KCCardList *hand = &engine->players[0].hand;
            for (int32_t index = 0; index < hand->count; index++) {
                KCCard candidate = hand->cards[index];
                if (candidate.suit == closing_suit &&
                    candidate.value > highest_closer) {
                    highest_closer = candidate.value;
                }
            }
            return card.suit == closing_suit &&
                card.value == highest_closer;
        }
        return true;
    }
    if (engine->year > 3) {
        return true;
    }
    int32_t trick = engine->trick_count;
    if (trick < 0 || trick >= 4) {
        return true;
    }
    if (engine->year == 2) {
        static const int32_t suits[4][KC_PLAYER_COUNT] = {
            {KC_SUIT_POTATO, KC_SUIT_POTATO, KC_SUIT_POTATO, KC_SUIT_POTATO},
            {KC_SUIT_WHEAT, KC_SUIT_BEET, KC_SUIT_BEET, KC_SUIT_BEET},
            {KC_SUIT_SUNFLOWER, KC_SUIT_SUNFLOWER, KC_SUIT_SUNFLOWER, KC_SUIT_SUNFLOWER},
            {KC_SUIT_WHEAT, KC_SUIT_BEET, KC_SUIT_WHEAT, KC_SUIT_BEET}
        };
        if (card.suit != suits[trick][player_id]) {
            return false;
        }
        if (trick == 2 && player_id == 0) {
            return card.value == 9;
        }
        if (trick == 3 && player_id == 2) {
            return card.value == 9;
        }
        return true;
    }
    if (engine->year == 3) {
        static const int32_t suits[4][KC_PLAYER_COUNT] = {
            {KC_SUIT_WRECKER, KC_SUIT_SUNFLOWER, KC_SUIT_WHEAT, KC_SUIT_WHEAT},
            {KC_SUIT_BEET, KC_SUIT_BEET, KC_SUIT_BEET, KC_SUIT_BEET},
            {KC_SUIT_SUNFLOWER, KC_SUIT_SUNFLOWER, KC_SUIT_SUNFLOWER, KC_SUIT_SUNFLOWER},
            {KC_SUIT_POTATO, KC_SUIT_POTATO, KC_SUIT_POTATO, KC_SUIT_POTATO}
        };
        return card.suit == suits[trick][player_id];
    }
    static const int32_t suits[4] = {
        KC_SUIT_WHEAT, KC_SUIT_SUNFLOWER, KC_SUIT_POTATO, KC_SUIT_BEET
    };
    if (card.suit != suits[trick]) {
        return false;
    }
    if (engine->year == 1 && trick == 0 && player_id == 0) {
        return card.value == 6;
    }
    return true;
}

static bool kc_tutorial_swap_allowed(
    const KCEngine *engine,
    int32_t player_id,
    KCCard hand_card,
    KCCard plot_card,
    int32_t plot_zone
) {
    if (!engine->tutorial_mode) {
        return true;
    }
    if (engine->year == KC_MAX_YEARS) {
        int32_t intended_suit = engine->tutorial_famine_off_suit;
        KCCard saved_card =
            kc_tutorial_famine_plot_card_for_suit(engine, intended_suit);
        return player_id == 0 &&
            kc_card_valid(saved_card) &&
            kc_card_equal(plot_card, saved_card) &&
            hand_card.suit != engine->trump &&
            hand_card.suit != saved_card.suit;
    }
    if (engine->year > 3) {
        return true;
    }
    return engine->year == 2 &&
        player_id == 0 &&
        plot_zone == KC_ZONE_HIDDEN &&
        hand_card.suit == KC_SUIT_BEET &&
        hand_card.value == 13 &&
        plot_card.suit == KC_SUIT_WHEAT &&
        plot_card.value == 10;
}

int32_t kc_engine_legal_actions(const KCEngine *engine, KCAction *actions, int32_t max_actions) {
    int32_t count = 0;
    if (engine->tutorial_mode && !engine->tutorial_orientation_complete) {
        KCAction action = {0};
        action.kind = KC_ACTION_COMPLETE_TUTORIAL_ORIENTATION;
        action.player_id = 0;
        action.suit = -1;
        action.card = kc_no_card();
        action.hand_card = kc_no_card();
        action.plot_card = kc_no_card();
        action.plot_zone = -1;
        action.target_suit = -1;
        kc_add_action(actions, max_actions, &count, action);
        return count;
    }
    if (engine->tutorial_mode &&
        engine->year == 1 &&
        engine->phase == KC_PHASE_PLANNING &&
        !engine->tutorial_reward_lesson_complete &&
        kc_next_reward_to_reveal(engine) == KC_NO_SUIT) {
        KCAction action = {0};
        action.kind = KC_ACTION_COMPLETE_TUTORIAL_REWARD_LESSON;
        action.player_id = 0;
        action.suit = -1;
        action.card = kc_no_card();
        action.hand_card = kc_no_card();
        action.plot_card = kc_no_card();
        action.plot_zone = -1;
        action.target_suit = -1;
        kc_add_action(actions, max_actions, &count, action);
        return count;
    }
    if (engine->tutorial_mode &&
        engine->year == 3 &&
        engine->phase == KC_PHASE_TRICK &&
        engine->trick_count == 0 &&
        !engine->tutorial_saboteur_follow_lesson_complete &&
        engine->current_trick_count == 2 &&
        engine->current_trick[1].player_id == 0 &&
        kc_card_is_wrecker(engine->current_trick[1].card)) {
        KCAction action = {0};
        action.kind = KC_ACTION_COMPLETE_TUTORIAL_SABOTEUR_FOLLOW_LESSON;
        action.player_id = 0;
        action.suit = -1;
        action.card = kc_no_card();
        action.hand_card = kc_no_card();
        action.plot_card = kc_no_card();
        action.plot_zone = -1;
        action.target_suit = -1;
        kc_add_action(actions, max_actions, &count, action);
        return count;
    }
    switch (engine->phase) {
    case KC_PHASE_PLANNING:
        if (kc_next_reward_to_reveal(engine) != KC_NO_SUIT) {
            KCAction action = {0};
            action.kind = KC_ACTION_REVEAL_REWARD;
            action.player_id = engine->current_player;
            action.suit = kc_next_reward_to_reveal(engine);
            action.card = kc_no_card();
            action.hand_card = kc_no_card();
            action.plot_card = kc_no_card();
            action.plot_zone = -1;
            action.target_suit = -1;
            kc_add_action(actions, max_actions, &count, action);
        } else if (kc_managed_rewards_ready_for_swaps(engine)) {
            const KCCardList *hand = &engine->players[engine->trump_selector].hand;
            for (int32_t target_suit = 0; target_suit < KC_SUIT_COUNT; target_suit++) {
                for (int32_t card_index = 0; card_index < hand->count; card_index++) {
                    KCCard card = hand->cards[card_index];
                    if (!kc_card_matches_suit(card, target_suit)) continue;
                    KCAction action = {0};
                    action.kind = KC_ACTION_ASSIGN_REWARD;
                    action.player_id = engine->trump_selector;
                    action.suit = target_suit;
                    action.card = card;
                    action.hand_card = kc_no_card();
                    action.plot_card = kc_no_card();
                    action.plot_zone = -1;
                    action.target_suit = target_suit;
                    kc_add_action(actions, max_actions, &count, action);
                }
            }
            KCAction confirm_action = {0};
            confirm_action.kind = KC_ACTION_CONFIRM_REWARD_SWAPS;
            confirm_action.player_id = engine->trump_selector;
            confirm_action.suit = KC_NO_SUIT;
            confirm_action.card = kc_no_card();
            confirm_action.hand_card = kc_no_card();
            confirm_action.plot_card = kc_no_card();
            confirm_action.plot_zone = -1;
            confirm_action.target_suit = KC_NO_SUIT;
            kc_add_action(actions, max_actions, &count, confirm_action);
        } else if (kc_card_valid(engine->pending_final_year_trump_card)) {
            KCAction action = {0};
            action.kind = KC_ACTION_REVEAL_TRUMP;
            action.player_id = engine->current_player;
            action.suit = -1;
            action.card = kc_no_card();
            action.hand_card = kc_no_card();
            action.plot_card = kc_no_card();
            action.plot_zone = -1;
            action.target_suit = -1;
            kc_add_action(actions, max_actions, &count, action);
        } else if (!engine->is_famine) {
            for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
                if (engine->tutorial_mode && engine->year <= 3) {
                    int32_t tutorial_trump =
                        engine->year == 3 ? KC_SUIT_SUNFLOWER : KC_SUIT_WHEAT;
                    if (suit != tutorial_trump) {
                        continue;
                    }
                }
                KCAction action = {0};
                action.kind = KC_ACTION_SET_TRUMP;
                action.player_id = engine->current_player;
                action.suit = suit;
                action.card = kc_no_card();
                action.hand_card = kc_no_card();
                action.plot_card = kc_no_card();
                action.plot_zone = -1;
                action.target_suit = -1;
                kc_add_action(actions, max_actions, &count, action);
            }
        }
        break;

    case KC_PHASE_SWAP: {
        int32_t player_id = engine->current_player;
        if (!engine->swap_count[player_id]) {
            const KCPlayer *player = &engine->players[player_id];
            for (int32_t hand_index = 0; hand_index < player->hand.count; hand_index++) {
                for (int32_t plot_index = 0; plot_index < player->plot_hidden.count; plot_index++) {
                    if (!kc_tutorial_swap_allowed(
                            engine,
                            player_id,
                            player->hand.cards[hand_index],
                            player->plot_hidden.cards[plot_index],
                            KC_ZONE_HIDDEN)) {
                        continue;
                    }
                    KCAction action = {0};
                    action.kind = KC_ACTION_SWAP;
                    action.player_id = player_id;
                    action.card = kc_no_card();
                    action.hand_card = player->hand.cards[hand_index];
                    action.plot_card = player->plot_hidden.cards[plot_index];
                    action.plot_zone = KC_ZONE_HIDDEN;
                    action.suit = -1;
                    action.target_suit = -1;
                    kc_add_action(actions, max_actions, &count, action);
                }
                for (int32_t plot_index = 0; plot_index < player->plot_revealed.count; plot_index++) {
                    if (!kc_tutorial_swap_allowed(
                            engine,
                            player_id,
                            player->hand.cards[hand_index],
                            player->plot_revealed.cards[plot_index],
                            KC_ZONE_REVEALED)) {
                        continue;
                    }
                    KCAction action = {0};
                    action.kind = KC_ACTION_SWAP;
                    action.player_id = player_id;
                    action.card = kc_no_card();
                    action.hand_card = player->hand.cards[hand_index];
                    action.plot_card = player->plot_revealed.cards[plot_index];
                    action.plot_zone = KC_ZONE_REVEALED;
                    action.suit = -1;
                    action.target_suit = -1;
                    kc_add_action(actions, max_actions, &count, action);
                }
            }
        } else if (engine->has_last_swap &&
                   engine->last_swap_player_id == player_id &&
                   !(engine->tutorial_mode && engine->year <= 3)) {
            KCAction action = {0};
            action.kind = KC_ACTION_UNDO_SWAP;
            action.player_id = player_id;
            action.suit = -1;
            action.card = kc_no_card();
            action.hand_card = kc_no_card();
            action.plot_card = kc_no_card();
            action.plot_zone = -1;
            action.target_suit = -1;
            kc_add_action(actions, max_actions, &count, action);
        }
        bool tutorial_swap_required =
            engine->tutorial_mode &&
            player_id == 0 &&
            (engine->year == 2 || engine->year == KC_MAX_YEARS) &&
            !engine->swap_count[player_id];
        if (!tutorial_swap_required) {
            KCAction action = {0};
            action.kind = KC_ACTION_CONFIRM_SWAP;
            action.player_id = player_id;
            action.suit = -1;
            action.card = kc_no_card();
            action.hand_card = kc_no_card();
            action.plot_card = kc_no_card();
            action.plot_zone = -1;
            action.target_suit = -1;
            kc_add_action(actions, max_actions, &count, action);
        }
        break;
    }

    case KC_PHASE_PASS:
        for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
            if (engine->pass_confirmed[player_id]) {
                continue;
            }
            const KCCardList *hand = &engine->players[player_id].hand;
            for (int32_t card_index = 0; card_index < hand->count; card_index++) {
                KCAction action = {0};
                action.kind = KC_ACTION_PASS_CARD;
                action.player_id = player_id;
                action.card = hand->cards[card_index];
                action.suit = -1;
                action.hand_card = kc_no_card();
                action.plot_card = kc_no_card();
                action.plot_zone = -1;
                action.target_suit = -1;
                kc_add_action(actions, max_actions, &count, action);
            }
        }
        break;

    case KC_PHASE_TRICK: {
        int32_t player_id = engine->current_player;
        const KCCardList *hand = &engine->players[player_id].hand;
        for (int32_t card_index = 0; card_index < hand->count; card_index++) {
            if (kc_is_valid_play(engine, player_id, card_index) &&
                kc_tutorial_play_allowed(engine, player_id, hand->cards[card_index])) {
                KCAction action = {0};
                action.kind = KC_ACTION_PLAY_CARD;
                action.player_id = player_id;
                action.card = hand->cards[card_index];
                action.suit = -1;
                action.hand_card = kc_no_card();
                action.plot_card = kc_no_card();
                action.plot_zone = -1;
                action.target_suit = -1;
                kc_add_action(actions, max_actions, &count, action);
            }
        }
        break;
    }

    case KC_PHASE_ASSIGNMENT: {
        int32_t winner = engine->last_winner;
        if (kc_pending_assignment_count(engine) >= engine->last_trick_count) {
            KCAction action = {0};
            action.kind = KC_ACTION_SUBMIT_ASSIGNMENTS;
            action.player_id = winner;
            action.suit = -1;
            action.card = kc_no_card();
            action.hand_card = kc_no_card();
            action.plot_card = kc_no_card();
            action.plot_zone = -1;
            action.target_suit = -1;
            kc_add_action(actions, max_actions, &count, action);
        } else {
            for (int32_t play_index = 0; play_index < engine->last_trick_count; play_index++) {
                if (engine->pending_assignment_targets[play_index] >= 0) {
                    continue;
                }
                for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
                    int32_t tutorial_target = kc_tutorial_assignment_target(
                        engine,
                        play_index
                    );
                    if (kc_assignment_target_legal(engine, suit) &&
                        (tutorial_target == KC_NO_SUIT || suit == tutorial_target)) {
                        KCAction action = {0};
                        action.kind = KC_ACTION_ASSIGN;
                        action.player_id = winner;
                        action.card = engine->last_trick[play_index].card;
                        action.target_suit = suit;
                        action.suit = -1;
                        action.hand_card = kc_no_card();
                        action.plot_card = kc_no_card();
                        action.plot_zone = -1;
                        kc_add_action(actions, max_actions, &count, action);
                    }
                }
            }
        }
        break;
    }

    case KC_PHASE_REQUISITION: {
        if (engine->requisition_plan_index < engine->requisition_plan_count) {
            break;
        }
        if (engine->requisition_rounds_remaining > 0) {
            for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
                if (!engine->requisition_target_players[player_id] ||
                    engine->requisition_choice_confirmed[player_id]) {
                    continue;
                }
                int32_t highest = kc_requisition_highest_value(engine, player_id);
                const KCPlayer *player = &engine->players[player_id];
                for (int32_t zone = 0; zone < 2; zone++) {
                    const KCCardList *cards = zone == 0
                        ? &player->plot_hidden
                        : &player->plot_revealed;
                    for (int32_t i = 0; i < cards->count; i++) {
                        KCCard card = cards->cards[i];
                        if (card.value != highest ||
                            !kc_requisition_card_eligible(engine, player_id, card)) {
                            continue;
                        }
                        KCAction action = {0};
                        action.kind = KC_ACTION_SELECT_REQUISITION_CARD;
                        action.player_id = player_id;
                        action.card = card;
                        action.suit = -1;
                        action.hand_card = kc_no_card();
                        action.plot_card = kc_no_card();
                        action.plot_zone = zone;
                        action.target_suit = -1;
                        kc_add_action(actions, max_actions, &count, action);
                    }
                }
            }
            break;
        }
        KCAction action = {0};
        action.kind = KC_ACTION_CONTINUE_AFTER_REQUISITION;
        action.player_id = 0;
        action.suit = -1;
        action.card = kc_no_card();
        action.hand_card = kc_no_card();
        action.plot_card = kc_no_card();
        action.plot_zone = -1;
        action.target_suit = -1;
        kc_add_action(actions, max_actions, &count, action);
        break;
    }

    default:
        break;
    }
    return count;
}

static int32_t kc_action_kind_order(KCAction action) {
    return action.kind;
}

bool kc_action_less(KCAction lhs, KCAction rhs) {
    int32_t left_key[] = {
        kc_action_kind_order(lhs),
        lhs.player_id,
        lhs.suit,
        lhs.card.suit,
        lhs.card.value,
        lhs.hand_card.suit,
        lhs.hand_card.value,
        lhs.plot_card.suit,
        lhs.plot_card.value,
        lhs.plot_zone,
        lhs.target_suit
    };
    int32_t right_key[] = {
        kc_action_kind_order(rhs),
        rhs.player_id,
        rhs.suit,
        rhs.card.suit,
        rhs.card.value,
        rhs.hand_card.suit,
        rhs.hand_card.value,
        rhs.plot_card.suit,
        rhs.plot_card.value,
        rhs.plot_zone,
        rhs.target_suit
    };
    for (int32_t i = 0; i < 11; i++) {
        if (left_key[i] != right_key[i]) {
            return left_key[i] < right_key[i];
        }
    }
    return false;
}

KCGameRunResult kc_run_benchmark_game(uint64_t seed, KCVariants variants) {
    KCEngine engine;
    kc_engine_init(&engine, seed, variants);
    KCGameRunResult result = {0};
    while (engine.phase != KC_PHASE_GAME_OVER && result.actions < 1000) {
        KCAction actions[256];
        int32_t count = kc_engine_legal_actions(&engine, actions, 256);
        KCAction selected;
        if (!kc_choose_benchmark_action(&engine, actions, count, &selected)) {
            result.checksum = -999999;
            return result;
        }
        int32_t error = kc_engine_apply(&engine, selected);
        if (error != 0) {
            result.checksum = -error;
            return result;
        }
        result.actions += 1;
    }
    int32_t score_sum = 0;
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        score_sum += kc_final_score(&engine, player_id);
    }
    result.checksum = engine.winner_id * 31 + score_sum;
    return result;
}
