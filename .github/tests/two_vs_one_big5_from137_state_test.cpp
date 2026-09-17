#include <cassert>
#include "multiplayer.h"

int main() {
    MultiplayerState big5;
    big5.configure(MultiplayerMode::TWO_V_ONE_BIG5);

    // Exact scenario seats: Joey=0, Yugi=1, Big Five=2. P4 never exists.
    assert(big5.enabled());
    assert(big5.mode() == MultiplayerMode::TWO_V_ONE_BIG5);
    assert(big5.active_mask() == 0x07);
    assert(big5.active_count() == 3);
    assert(big5.is_active(0));
    assert(big5.is_active(1));
    assert(big5.is_active(2));
    assert(!big5.is_active(3));
    assert(big5.team_of(0) == 0);
    assert(big5.team_of(1) == 0);
    assert(big5.team_of(2) == 1);

    // Joey/Yugi own two simultaneous independent fields; Big Five own one.
    assert(big5.field_count(0) == 2);
    assert(big5.field_count(1) == 1);
    assert(big5.field_side_of(0) == 0);
    assert(big5.field_side_of(1) == 0);
    assert(big5.field_side_of(2) == 1);
    assert(big5.field_side_of(3) == MultiplayerState::NO_PLAYER);
    assert(big5.duelist_index_of(0) == 0);
    assert(big5.duelist_index_of(1) == 1);
    assert(big5.duelist_index_of(2) == 0);
    assert(big5.duelist_index_of(3) == MultiplayerState::NO_PLAYER);
    assert(big5.logical_player(0, 0) == 0);
    assert(big5.logical_player(0, 1) == 1);
    assert(big5.logical_player(1, 0) == 2);

    // Exact network prompt routing.
    assert(big5.prompt_player_of(0) == 2);
    assert(big5.prompt_player_of(1) == 3);
    assert(big5.prompt_player_of(2) == 1);

    // Anime order: Big Five -> Joey -> Yugi -> Big Five.
    assert(big5.current_player() == 2);
    assert(big5.advance_turn() == 0);
    assert(big5.advance_turn() == 1);
    assert(big5.advance_turn() == 2);

    // Team victory semantics.
    MultiplayerState heroes_win;
    heroes_win.configure(MultiplayerMode::TWO_V_ONE_BIG5);
    assert(heroes_win.eliminate(2, PlayerEliminationReason::LP));
    assert(heroes_win.has_winner());
    assert(heroes_win.winner_team() == 0);

    MultiplayerState big5_win;
    big5_win.configure(MultiplayerMode::TWO_V_ONE_BIG5);
    assert(big5_win.eliminate(0, PlayerEliminationReason::LP));
    assert(!big5_win.has_winner());
    assert(big5_win.eliminate(1, PlayerEliminationReason::LP));
    assert(big5_win.has_winner());
    assert(big5_win.winner_team() == 1);
    assert(big5_win.winner_player() == 2);

    // HARD regression guards: existing modes must remain exactly as 137c63b.
    MultiplayerState br;
    br.configure(MultiplayerMode::BATTLE_ROYALE);
    assert(br.active_mask() == 0x0f);
    assert(br.field_count(0) == 2 && br.field_count(1) == 2);
    assert(br.current_player() == 0);
    assert(br.advance_turn() == 2);
    assert(br.advance_turn() == 1);
    assert(br.advance_turn() == 3);

    MultiplayerState three;
    three.configure(MultiplayerMode::THREE_V_ONE);
    assert(three.active_mask() == 0x0f);
    assert(three.field_count(0) == 3 && three.field_count(1) == 1);
    assert(three.current_player() == 0);
    assert(three.advance_turn() == 1);
    assert(three.advance_turn() == 2);
    assert(three.advance_turn() == 3);

    MultiplayerState standard;
    assert(!standard.enabled());
    assert(standard.active_mask() == 0);
    return 0;
}
