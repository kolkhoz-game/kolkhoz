#include "include/KolkhozCEngine.h"

#include <stddef.h>
#include <stdint.h>

static KCAction kc_web_selected_action;

static int32_t kc_web_pack_card(KCCard card) {
    return (((card.suit + 2) & 0xff) << 8) | (card.value & 0xff);
}

KCEngine *kc_web_engine_new(
    uint32_t seed,
    int32_t tutorial,
    int32_t controller_0,
    int32_t controller_1,
    int32_t controller_2,
    int32_t controller_3
) {
    KCEngine *engine = kc_engine_alloc();
    if (engine == NULL) {
        return NULL;
    }
    KCControllers controllers;
    kc_controllers_all_external(&controllers);
    kc_controllers_set(&controllers, 0, controller_0);
    kc_controllers_set(&controllers, 1, controller_1);
    kc_controllers_set(&controllers, 2, controller_2);
    kc_controllers_set(&controllers, 3, controller_3);
    if (tutorial) {
        kc_engine_init_tutorial_with_controllers_stepwise(engine, seed, controllers);
    } else {
        KCVariants variants;
        kc_variants_kolkhoz(&variants);
        kc_engine_init_with_controllers_stepwise(engine, seed, variants, controllers);
    }
    return engine;
}

KCEngine *kc_web_engine_clone(const KCEngine *source) {
    KCEngine *clone = kc_engine_alloc();
    if (clone != NULL) {
        kc_engine_clone(source, clone);
    }
    return clone;
}

void kc_web_engine_free(KCEngine *engine) {
    kc_engine_free(engine);
}

int32_t kc_web_engine_step_automatic(KCEngine *engine) {
    return kc_engine_step_automatic(engine);
}

int32_t kc_web_engine_apply(
    KCEngine *engine,
    int32_t mode,
    int32_t kind,
    int32_t player_id,
    int32_t suit,
    int32_t card_suit,
    int32_t card_value,
    int32_t hand_suit,
    int32_t hand_value,
    int32_t plot_suit,
    int32_t plot_value,
    int32_t plot_zone,
    int32_t target_suit
) {
    KCAction action = {
        .kind = kind,
        .player_id = player_id,
        .suit = suit,
        .card = {.suit = card_suit, .value = card_value},
        .hand_card = {.suit = hand_suit, .value = hand_value},
        .plot_card = {.suit = plot_suit, .value = plot_value},
        .plot_zone = plot_zone,
        .target_suit = target_suit,
    };
    if (mode == 1) {
        return kc_engine_apply_manual(engine, action);
    }
    if (mode == 2) {
        return kc_engine_apply_ai_action(engine, action);
    }
    return kc_engine_apply(engine, action);
}

int32_t kc_web_engine_heuristic_action(const KCEngine *engine) {
    return kc_engine_heuristic_action(engine, &kc_web_selected_action) ? 1 : 0;
}

int32_t kc_web_selected_action_get(int32_t field) {
    switch (field) {
        case 0: return kc_web_selected_action.kind;
        case 1: return kc_web_selected_action.player_id;
        case 2: return kc_web_selected_action.suit;
        case 3: return kc_web_pack_card(kc_web_selected_action.card);
        case 4: return kc_web_pack_card(kc_web_selected_action.hand_card);
        case 5: return kc_web_pack_card(kc_web_selected_action.plot_card);
        case 6: return kc_web_selected_action.plot_zone;
        case 7: return kc_web_selected_action.target_suit;
        default: return -1;
    }
}

int32_t kc_web_engine_get(
    const KCEngine *engine,
    int32_t field,
    int32_t a,
    int32_t b,
    int32_t c
) {
    switch (field) {
        case 0: return kc_engine_phase(engine);
        case 1: return kc_engine_year(engine);
        case 2: return kc_engine_current_player(engine);
        case 3: return kc_engine_lead_player(engine);
        case 4: return kc_engine_trump(engine);
        case 5: return kc_engine_trick_count(engine);
        case 6: return kc_engine_last_winner(engine);
        case 7: return kc_engine_winner_id(engine);
        case 8: return kc_engine_is_famine(engine);
        case 9: return kc_engine_is_tutorial(engine);
        case 10: return kc_visible_score(engine, a);
        case 11: return kc_final_score(engine, a);
        case 12: return kc_player_medals(engine, a);
        case 13: return kc_player_banked_medals(engine, a);
        case 14: return kc_player_brigade_leader(engine, a);
        case 15: return kc_player_hand_count(engine, a);
        case 16: return kc_web_pack_card(kc_player_hand_card(engine, a, b));
        case 17: return kc_player_plot_revealed_count(engine, a);
        case 18: return kc_web_pack_card(kc_player_plot_revealed_card(engine, a, b));
        case 19: return kc_player_plot_hidden_count(engine, a);
        case 20: return kc_web_pack_card(kc_player_plot_hidden_card(engine, a, b));
        case 21: return kc_player_plot_stack_count(engine, a);
        case 22: return kc_player_plot_stack_revealed_count(engine, a, b);
        case 23: return kc_web_pack_card(kc_player_plot_stack_revealed_card(engine, a, b, c));
        case 24: return kc_player_plot_stack_hidden_count(engine, a, b);
        case 25: return kc_web_pack_card(kc_player_plot_stack_hidden_card(engine, a, b, c));
        case 26: return kc_has_revealed_job(engine, a);
        case 27: return kc_web_pack_card(kc_revealed_job_card(engine, a));
        case 28: return kc_claimed_job(engine, a);
        case 29: return kc_work_hours(engine, a);
        case 30: return kc_job_bucket_count(engine, a);
        case 31: return kc_web_pack_card(kc_job_bucket_card(engine, a, b));
        case 32: return kc_job_bucket_trick(engine, a, b);
        case 33: return kc_current_trick_count(engine);
        case 34: return kc_current_trick_winner(engine);
        case 35: return kc_current_trick_player(engine, a);
        case 36: return kc_web_pack_card(kc_current_trick_card(engine, a));
        case 37: return kc_last_trick_count(engine);
        case 38: return kc_last_trick_player(engine, a);
        case 39: return kc_web_pack_card(kc_last_trick_card(engine, a));
        case 40: return kc_pending_assignment_target(engine, a);
        case 41: return kc_exiled_count(engine, a);
        case 42: return kc_web_pack_card(kc_exiled_card(engine, a, b));
        case 43: return kc_exiled_player(engine, a, b);
        case 44: return kc_requisition_event_count(engine);
        case 45: return kc_requisition_event_player(engine, a);
        case 46: return kc_requisition_event_suit(engine, a);
        case 47: return kc_web_pack_card(kc_requisition_event_card(engine, a));
        case 48: return kc_requisition_event_message_kind(engine, a);
        case 49: return kc_transition_event_count(engine);
        case 50: return kc_transition_event_kind(engine, a);
        case 51: return kc_transition_event_player(engine, a);
        case 52: return kc_web_pack_card(kc_transition_event_card(engine, a));
        case 53: return kc_transition_event_from_zone(engine, a);
        case 54: return kc_transition_event_to_zone(engine, a);
        case 55: return kc_transition_event_from_owner(engine, a);
        case 56: return kc_transition_event_to_owner(engine, a);
        case 57: return kc_transition_event_target_suit(engine, a);
        case 58: return kc_transition_event_trick_winner(engine, a);
        case 59: return kc_swap_count(engine, a);
        case 60: return kc_swap_confirmed(engine, a);
        case 61: return kc_pass_confirmed(engine, a);
        case 62: return kc_web_pack_card(kc_final_year_trump_card(engine));
        case 63: return kc_legal_action_count(engine);
        case 64: return kc_legal_action_kind_at(engine, a);
        case 65: return kc_legal_action_player_at(engine, a);
        case 66: return kc_legal_action_suit_at(engine, a);
        case 67: return kc_web_pack_card(kc_legal_action_card_at(engine, a));
        case 68: return kc_web_pack_card(kc_legal_action_hand_card_at(engine, a));
        case 69: return kc_web_pack_card(kc_legal_action_plot_card_at(engine, a));
        case 70: return kc_legal_action_plot_zone_at(engine, a);
        case 71: return kc_legal_action_target_suit_at(engine, a);
        default: return -1;
    }
}
