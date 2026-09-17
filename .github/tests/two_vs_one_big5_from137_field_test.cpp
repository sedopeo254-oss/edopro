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
    options.flags = DUEL_2_V_1_BIG5;
    options.team1 = { 4000, 5, 1 };
    options.team2 = { 8000, 5, 1 };
    options.cardReader = read_card;
    options.cardReaderDone = read_card_done;
    options.scriptReader = read_script;
    options.logHandler = log_message;

    bool valid_lua = true;
    duel game(options, valid_lua);
    expect(valid_lua, "Lua runtime must initialize");
    auto& field = *game.game_field;

    // Exact topology and field storage. This catches accidental 3v1 allocation.
    expect(field.multiplayer.mode() == MultiplayerMode::TWO_V_ONE_BIG5,
        "Core must configure the dedicated 2v1 mode");
    expect(field.multiplayer.active_mask() == 0x07,
        "only Joey, Yugi and Big Five may be active");
    expect(field.player[0].list_mzone.size() == 14,
        "Joey/Yugi must own exactly two monster fields");
    expect(field.player[0].list_szone.size() == 16,
        "Joey/Yugi must own exactly two spell/trap fields");
    expect(field.player[1].list_mzone.size() == 7,
        "Big Five must own exactly one monster field");

    // Create Yugi's private resources using the same API the LAN server uses.
    initialize_extra_duelist(game, 1, 11001);
    expect(field.player[0].extra_duelist_ids.size() == 1
        && field.player[0].extra_duelist_ids.front() == 1,
        "Yugi must have one independent private resource set");
    expect(field.get_logical_list(0, LOCATION_DECK, 1).size() == 1,
        "Yugi's Deck must be independent from Joey's Deck");

    // Two simultaneous allied fields: Joey's zone 0 and Yugi's encoded zone 7.
    auto* joey = game.new_card(12001);
    joey->owner = 0;
    joey->owner_duelist = 0;
    field.add_card(0, joey, LOCATION_MZONE, 0);
    expect(joey->current.sequence == 0,
        "Joey's first monster zone must map to slot 0");

    expect(field.tag_swap_to(0, 1), "active private resources must switch to Yugi");
    auto* yugi = game.new_card(12002);
    yugi->owner = 0;
    yugi->owner_duelist = 1;
    field.add_card(0, yugi, LOCATION_MZONE, 0);
    expect(yugi->current.sequence == 7,
        "Yugi's first monster zone must map to slot 7");
    expect(field.player[0].list_mzone[0] == joey
        && field.player[0].list_mzone[7] == yugi,
        "Joey and Yugi fields must remain simultaneously present");

    // Fusion material collection on the allied side must see both fields.
    card_set materials;
    field.get_fusion_material(0, &materials);
    expect(materials.find(joey) != materials.end()
        && materials.find(yugi) != materials.end(),
        "Fusion material pool must include monsters from both allied fields");

    // Prompt routing must follow the logical owner rather than the current screen.
    auto* yugi_effect = game.new_effect();
    yugi_effect->owner = yugi;
    yugi_effect->handler = yugi;
    field.core.reason_effect = yugi_effect;
    expect(field.get_effect_duelist(0) == 1,
        "Yugi effect must keep Yugi logical ownership");
    expect(field.get_response_player(0) == 3,
        "Yugi effect prompt must route to logical selector 3");
    field.core.reason_effect = nullptr;
    expect(field.get_response_player(1) == 1,
        "Big Five prompt must route to physical side 1");

    // Independent GY/Banish/LP while another allied field remains present.
    expect(field.move_card(0, yugi, LOCATION_GRAVE, 0),
        "Yugi's monster must move to Yugi's Graveyard");
    expect(field.get_logical_list(0, LOCATION_GRAVE, 1).size() == 1
        && field.get_logical_list(0, LOCATION_GRAVE, 1).front() == yugi,
        "Yugi's Graveyard must remain independent");
    expect(field.get_logical_list(0, LOCATION_GRAVE, 0).empty(),
        "Yugi's card must never enter Joey's Graveyard");

    field.get_logical_lp(0, 0) = 3600;
    field.get_logical_lp(0, 1) = 2500;
    field.get_logical_lp(1, 0) = 8000;
    expect(field.get_logical_lp(0, 0) == 3600
        && field.get_logical_lp(0, 1) == 2500
        && field.get_logical_lp(1, 0) == 8000,
        "all three logical LP values must remain independent");

    // The old crash: logical P4 must map nowhere. Never dereference it.
    expect(!field.multiplayer.is_active(3), "P4 must stay inactive");
    expect(field.multiplayer.field_side_of(3) == MultiplayerState::NO_PLAYER,
        "P4 must not map to a physical field side");
    expect(field.multiplayer.duelist_index_of(3) == MultiplayerState::NO_PLAYER,
        "P4 must not map to a private resource index");
    field.publish_multiplayer_private_piles(3); // must safely no-op, never crash

    // Existing modes are not reconfigured by constructing the new one.
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
