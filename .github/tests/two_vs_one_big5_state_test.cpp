#include <cassert>
#include "multiplayer.h"

int main() {
    MultiplayerState big5;
    big5.configure_two_vs_one_big5();

    // Scenario 1 logical seats: Joey=0, Yugi=1, Big Five=2.
    assert(big5.enabled());
    assert(big5.mode() == MultiplayerMode::THREE_V_ONE);
    assert(big5.is_two_vs_one_big5());
    assert(big5.active_mask() == 0x07);
    assert(big5.active_count() == 3);
    assert(big5.team_of(0) == 0);
    assert(big5.team_of(1) == 0);
    assert(big5.team_of(2) == 1);

    // Two independent allied fields on side 0, one Big Five field on side 1.
    assert(big5.field_count(0) == 2);
    assert(big5.field_count(1) == 1);
    assert(big5.field_side_of(0) == 0);
    assert(big5.field_side_of(1) == 0);
    assert(big5.field_side_of(2) == 1);
    assert(big5.duelist_index_of(0) == 0);
    assert(big5.duelist_index_of(1) == 1);
    assert(big5.duelist_index_of(2) == 0);
    assert(big5.logical_player(0, 0) == 0);
    assert(big5.logical_player(0, 1) == 1);
    assert(big5.logical_player(1, 0) == 2);

    // Prompts route to the exact network duelist that owns the logical field.
    assert(big5.prompt_player_of(0) == 2);
    assert(big5.prompt_player_of(1) == 3);
    assert(big5.prompt_player_of(2) == 1);

    // Anime order: Big Five -> Joey -> Yugi -> Big Five.
    assert(big5.current_player() == 2);
    assert(big5.advance_turn() == 0);
    assert(big5.advance_turn() == 1);
    assert(big5.advance_turn() == 2);

    // Team victory remains team-based while Big Five are one solo player.
    MultiplayerState heroes_win;
    heroes_win.configure_two_vs_one_big5();
    assert(heroes_win.eliminate(2, PlayerEliminationReason::LP));
    assert(heroes_win.has_winner());
    assert(heroes_win.winner_team() == 0);

    MultiplayerState big5_win;
    big5_win.configure_two_vs_one_big5();
    assert(big5_win.eliminate(0, PlayerEliminationReason::LP));
    assert(!big5_win.has_winner());
    assert(big5_win.eliminate(1, PlayerEliminationReason::LP));
    assert(big5_win.has_winner());
    assert(big5_win.winner_team() == 1);
    assert(big5_win.winner_player() == 2);

    // Hard regression guards: existing modes keep their original topology/order.
    MultiplayerState br;
    br.configure(MultiplayerMode::BATTLE_ROYALE);
    assert(!br.is_two_vs_one_big5());
    assert(br.active_mask() == 0x0f);
    assert(br.field_count(0) == 2 && br.field_count(1) == 2);
    assert(br.current_player() == 0);
    assert(br.advance_turn() == 2);

    MultiplayerState three;
    three.configure(MultiplayerMode::THREE_V_ONE);
    assert(!three.is_two_vs_one_big5());
    assert(three.active_mask() == 0x0f);
    assert(three.field_count(0) == 3 && three.field_count(1) == 1);
    assert(three.current_player() == 0);
    assert(three.advance_turn() == 1);

    MultiplayerState standard;
    assert(!standard.enabled());
    assert(!standard.is_two_vs_one_big5());
    assert(standard.active_mask() == 0);

    return 0;
}
