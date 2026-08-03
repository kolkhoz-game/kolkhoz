#include "KolkhozCEngineInternal.h"

#include <stddef.h>

enum {
    KC_MANAGED_MAX_SACRIFICE_VALUE = 9,
    KC_MANAGED_REWARD_SWAP_COST = 150
};

static int32_t kc_managed_matching_plot_count(
    const KCEngine *engine,
    int32_t player_id,
    int32_t suit
) {
    if (!engine || !kc_valid_player_id(player_id) || !kc_valid_suit(suit)) {
        return 0;
    }
    const KCPlayer *player = &engine->players[player_id];
    int32_t count = 0;
    for (int32_t i = 0; i < player->plot_revealed.count; i++) {
        if (kc_card_matches_suit(player->plot_revealed.cards[i], suit)) {
            count++;
        }
    }
    for (int32_t i = 0; i < player->plot_hidden.count; i++) {
        if (kc_card_matches_suit(player->plot_hidden.cards[i], suit)) {
            count++;
        }
    }
    return count;
}

static int32_t kc_managed_matching_worker_count(
    const KCEngine *engine,
    int32_t player_id,
    int32_t suit
) {
    if (!engine || !kc_valid_player_id(player_id) || !kc_valid_suit(suit)) {
        return 0;
    }
    const KCCardList *hand = &engine->players[player_id].hand;
    int32_t count = 0;
    for (int32_t i = 0; i < hand->count; i++) {
        KCCard card = hand->cards[i];
        if (!kc_card_is_wrecker(card) && card.value >= 6 &&
            kc_card_matches_suit(card, suit)) {
            count++;
        }
    }
    return count;
}

static int32_t kc_managed_reward_swap_score(
    const KCEngine *engine,
    KCAction action
) {
    if (!engine || action.kind != KC_ACTION_ASSIGN_REWARD ||
        !kc_valid_suit(action.suit) || !kc_card_valid(action.card) ||
        kc_card_is_wrecker(action.card) || action.card.value < 6 ||
        action.card.value > KC_MANAGED_MAX_SACRIFICE_VALUE) {
        return 0;
    }
    KCCard current = engine->revealed_jobs[action.suit];
    if (!kc_card_valid(current)) {
        return 0;
    }
    int32_t upgrade = action.card.value - current.value;
    if (upgrade <= 0) {
        return 0;
    }

    int32_t score = upgrade * 100 - KC_MANAGED_REWARD_SWAP_COST;
    score += kc_managed_matching_plot_count(
        engine,
        action.player_id,
        action.suit
    ) * 30;
    int32_t matching_workers = kc_managed_matching_worker_count(
        engine,
        action.player_id,
        action.suit
    );
    if (matching_workers > 1) {
        score += (matching_workers - 1) * 20;
    }
    score -= action.card.value;
    return score;
}

bool kc_choose_managed_economy_action(
    const KCEngine *engine,
    const KCAction *actions,
    int32_t count,
    KCAction *selected
) {
    if (!engine || !actions || count <= 0 || !selected ||
        !engine->variants.managed_economy ||
        engine->phase != KC_PHASE_PLANNING ||
        engine->managed_rewards_confirmed) {
        return false;
    }

    bool has_swap = false;
    KCAction best_swap = {0};
    int32_t best_score = 0;
    const KCAction *confirm = NULL;
    for (int32_t i = 0; i < count; i++) {
        KCAction action = actions[i];
        if (action.kind == KC_ACTION_CONFIRM_REWARD_SWAPS) {
            confirm = &actions[i];
            continue;
        }
        int32_t score = kc_managed_reward_swap_score(
            engine,
            action
        );
        if (score > 0 && (!has_swap || score > best_score ||
            (score == best_score && kc_action_less(action, best_swap)))) {
            has_swap = true;
            best_swap = action;
            best_score = score;
        }
    }
    if (has_swap) {
        *selected = best_swap;
        return true;
    }
    if (confirm) {
        *selected = *confirm;
        return true;
    }
    return false;
}
