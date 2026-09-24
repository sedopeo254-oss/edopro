#include "card.h"
#include "duel.h"
#include "effect.h"
#include "field.h"
#include "ocgapi.h"

#include <cstdlib>
#include <iostream>

namespace {
void expect(bool condition, const char* message) {
    if(condition) return;
    std::cerr << "FAILED: " << message << '\n';
    std::exit(1);
}
void read_card(void*, uint32_t code, OCG_CardData* data) {
    *data = {};
    data->code = code;
    data->type = TYPE_MONSTER;
}
void read_card_done(void*, OCG_CardData*) {}
int read_script(void*, OCG_Duel, const char*) { return 0; }
void log_message(void*, const char*, int) {}

void initialize_extra_duelist(duel& game, uint8_t duelist_index, uint32_t code) {
    const OCG_NewCardInfo info{
        0, duelist_index, code, 0, LOCATION_DECK, 0, POS_FACEDOWN_DEFENSE
    };
    OCG_DuelNewCard(&game, &info);
}
}

int main() {
    OCG_DuelOptions options{};
    options.seed[0] = 1;
    options.flags = DUEL_2_V_1;
    options.team1 = { 4000, 5, 1 };
    options.team2 = { 4000, 5, 1 };
    options.cardReader = read_card;
    options.cardReaderDone = read_card_done;
    options.scriptReader = read_script;
    options.logHandler = log_message;

    bool valid_lua = true;
    duel game(options, valid_lua);
    expect(valid_lua, "Lua runtime must initialize");
    auto& field = *game.game_field;

    expect(field.multiplayer.mode() == MultiplayerMode::TWO_V_ONE,
        "dedicated 2v1 mode must be configured");
    expect(field.multiplayer.active_mask() == 0x07,
        "2v1 must have exactly three active logical players");
    expect(field.multiplayer.current_player() == 2,
        "opponent P3 must own the first logical turn");
    expect(field.multiplayer.advance_turn() == 0,
        "turn after P3 must be team P1");
    expect(field.multiplayer.advance_turn() == 1,
        "turn after P1 must be team P2");
    expect(field.multiplayer.advance_turn() == 2,
        "turn after P2 must return to P3");

    expect(field.player[0].list_mzone.size() == 14,
        "team side must contain two independent 7-zone monster fields");
    expect(field.player[0].list_szone.size() == 16,
        "team side must contain two independent 8-zone spell/trap fields");
    expect(field.player[1].list_mzone.size() == 7,
        "opponent must have one normal monster field");

    initialize_extra_duelist(game, 1, 11001);
    expect(field.get_logical_list(0, LOCATION_DECK, 1).size() == 1,
        "P2 Deck must be independent from P1 Deck");

    auto* p1 = game.new_card(12001);
    p1->owner = 0;
    p1->owner_duelist = 0;
    field.add_card(0, p1, LOCATION_MZONE, 0);
    expect(p1->current.sequence == 0 && p1->current.duelist == 0,
        "P1 zone 0 must belong to P1");

    expect(field.tag_swap_to(0, 1), "logical team resources must switch to P2");
    auto* p2 = game.new_card(12002);
    p2->owner = 0;
    p2->owner_duelist = 1;
    field.add_card(0, p2, LOCATION_MZONE, 0);
    expect(p2->current.sequence == 7 && p2->current.duelist == 1,
        "P2 zone 0 must map to encoded slot 7");
    expect(field.player[0].list_mzone[0] == p1
        && field.player[0].list_mzone[7] == p2,
        "P1 and P2 fields must remain simultaneously independent");

    card_set fusion;
    field.get_fusion_material(0, &fusion);
    expect(fusion.find(p1) != fusion.end() && fusion.find(p2) != fusion.end(),
        "team Fusion material pool must see both allied fields");

    auto* p2_effect = game.new_effect();
    p2_effect->owner = p2;
    p2_effect->handler = p2;
    field.core.reason_effect = p2_effect;
    expect(field.get_effect_duelist(0) == 1,
        "P2 effect must retain P2 logical ownership");
    expect(field.get_response_player(0) == 3,
        "P2 effect prompt must route to P2 selector");
    field.core.reason_effect = nullptr;

    // Deck Master-style card: a card from P2's private pile must summon into
    // P2's own encoded field even if another team field is currently projected.
    auto* p2_dm = game.new_card(13002);
    p2_dm->owner = 0;
    p2_dm->owner_duelist = 1;
    field.add_card(0, p2_dm, LOCATION_HAND, 0, false, 1);
    expect(field.tag_swap_to(0, 0), "screen/resources can switch back to P1");
    expect(field.move_card(0, p2_dm, LOCATION_MZONE, 1, false),
        "P2 Deck Master-style card must move to field");
    expect(p2_dm->current.duelist == 1 && p2_dm->current.sequence == 8,
        "P2 Deck Master-style summon must stay in P2 field, not P1 field");

    expect(field.move_card(0, p2, LOCATION_GRAVE, 0),
        "P2 monster must move to P2 Graveyard");
    expect(field.get_logical_list(0, LOCATION_GRAVE, 1).front() == p2,
        "P2 Graveyard must contain P2 card");
    expect(field.get_logical_list(0, LOCATION_GRAVE, 0).empty(),
        "P1 Graveyard must stay independent");

    auto* banish = game.new_card(14002);
    banish->owner = 0;
    banish->owner_duelist = 1;
    field.add_card(0, banish, LOCATION_REMOVED, 0, false, 1);
    expect(field.get_logical_list(0, LOCATION_REMOVED, 1).front() == banish,
        "P2 Banish must stay independent");

    field.get_logical_lp(0, 0) = 3900;
    field.get_logical_lp(0, 1) = 2700;
    field.get_logical_lp(1, 0) = 3500;
    expect(field.get_logical_lp(0, 0) == 3900
        && field.get_logical_lp(0, 1) == 2700
        && field.get_logical_lp(1, 0) == 3500,
        "all three LP pools must be independent");

    expect(!field.multiplayer.is_active(3),
        "logical P4 must remain inactive");
    expect(field.multiplayer.field_side_of(3) == MultiplayerState::NO_PLAYER,
        "inactive P4 must not map to a field");
    field.publish_multiplayer_private_piles(3);

    MultiplayerState br;
    br.configure(MultiplayerMode::BATTLE_ROYALE);
    expect(br.active_mask() == 0x0f && br.field_count(0) == 2 && br.field_count(1) == 2,
        "Battle Royale topology must remain unchanged");
    MultiplayerState three;
    three.configure(MultiplayerMode::THREE_V_ONE);
    expect(three.active_mask() == 0x0f && three.field_count(0) == 3 && three.field_count(1) == 1,
        "3v1 topology must remain unchanged");

    return 0;
}
