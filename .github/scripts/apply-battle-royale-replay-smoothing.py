from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected exactly one replacement site, found {count}')
    path.write_text(text.replace(old, new, 1), encoding='utf-8')


def replace_in_range(path: Path, start_marker: str, end_marker: str,
        old: str, new: str) -> None:
    text = path.read_text(encoding='utf-8')
    start = text.find(start_marker)
    if start < 0:
        raise SystemExit(f'{path}: missing range start {start_marker}')
    end = text.find(end_marker, start + len(start_marker))
    if end < 0:
        raise SystemExit(f'{path}: missing range end {end_marker}')
    block = text[start:end]
    count = block.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one replacement in range, found {count}')
    block = block.replace(old, new, 1)
    path.write_text(text[:start] + block + text[end:], encoding='utf-8')


def include_after(path: Path, preferred: str, fallback: str, include: str) -> None:
    text = path.read_text(encoding='utf-8')
    if include in text:
        return
    marker = preferred if preferred in text else fallback
    if marker not in text:
        raise SystemExit(f'{path}: missing include insertion marker')
    path.write_text(text.replace(marker, marker + include, 1), encoding='utf-8')


header = ROOT / 'gframe' / 'battle_royale_replay_smoothing.h'
if header.exists() and 'ShouldSkipLegacyTagSwap' in header.read_text(encoding='utf-8'):
    print('Battle Royale replay smoothing is already applied.')
    raise SystemExit(0)

header.write_text(r'''#ifndef BATTLE_ROYALE_REPLAY_SMOOTHING_H
#define BATTLE_ROYALE_REPLAY_SMOOTHING_H

#include <cstdint>

namespace ygo::battle_royale_replay_smoothing {

constexpr bool ShouldSkipLegacyTagSwap(bool is_replay,
        bool is_battle_royale, bool has_authoritative_snapshot) {
    // Modern Battle Royale replays already carry a complete private-pile
    // snapshot for each logical player. Replaying the legacy tag swap after
    // that snapshot deletes/recreates the same piles and causes the turn hitch.
    return is_replay && is_battle_royale && has_authoritative_snapshot;
}

constexpr bool NeedsSecondTurnRefresh(bool is_replay,
        bool is_battle_royale) {
    // SetBattleRoyaleReplayView already projects both public and private state.
    return !(is_replay && is_battle_royale);
}

constexpr uint8_t DrawMoveFrames(bool is_replay, bool is_battle_royale) {
    // A short non-blocking batch movement is readable without recreating all
    // five private piles or waiting once per card.
    return is_replay && is_battle_royale ? 10 : 8;
}

constexpr uint32_t DrawSoundCount(bool is_replay, bool is_battle_royale,
        bool displayed, uint32_t drawn_count) {
    if(!drawn_count)
        return 0;
    return is_replay && is_battle_royale ? (displayed ? 1u : 0u) : drawn_count;
}

} // namespace ygo::battle_royale_replay_smoothing

#endif
''', encoding='utf-8')

field_h = ROOT / 'gframe' / 'client_field.h'
replace_once(field_h,
'''\tvoid CaptureBattleRoyaleReplayPrivatePiles();
\tvoid ApplyBattleRoyaleReplayPrivatePiles();
\tvoid CaptureThreeVsOneReplayPrivatePiles();
''',
'''\tvoid CaptureBattleRoyaleReplayPrivatePiles();
\tvoid ApplyBattleRoyaleReplayPrivatePiles();
\tbool ApplyBattleRoyaleReplayPrivatePile(uint8_t logical_player);
\tbool ApplyBattleRoyaleReplayPrivateDraw(uint8_t logical_player,
\t\tconst std::vector<MultiplayerPrivatePileCard>& drawn_cards);
\tvoid CaptureThreeVsOneReplayPrivatePiles();
''')

field_cpp = ROOT / 'gframe' / 'client_field.cpp'
include_after(field_cpp,
    '#include "multiplayer_replay_animation.h"\n',
    '#include "duelclient.h"\n',
    '#include "battle_royale_replay_smoothing.h"\n')

old_apply = '''void ClientField::ApplyBattleRoyaleReplayPrivatePiles() {
\tif(!mainGame->dInfo.isReplay
\t\t\t|| !mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))
\t\treturn;
\tbool clear_transient = true;
\tfor(uint8_t display_side = 0; display_side < 2; ++display_side) {
\t\tconst auto logical =
\t\t\tmainGame->dInfo.GetBattleRoyaleDisplayLogical(display_side);
\t\tif(logical < multiplayer_private_piles.size()
\t\t\t\t&& multiplayer_private_piles_valid[logical]) {
\t\t\tReplaceMultiplayerPrivatePiles(display_side,
\t\t\t\tmultiplayer_private_piles[logical], clear_transient);
\t\t} else {
\t\t\tReplaceMultiplayerPrivatePiles(display_side,
\t\t\t\tMultiplayerPrivatePileSnapshot{}, clear_transient);
\t\t}
\t\tclear_transient = false;
\t}
}
'''
new_apply = '''bool ClientField::ApplyBattleRoyaleReplayPrivatePile(uint8_t logical_player) {
\tif(!mainGame->dInfo.isReplay
\t\t\t|| !mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)
\t\t\t|| logical_player >= multiplayer_private_piles.size()
\t\t\t|| !multiplayer_private_piles_valid[logical_player])
\t\treturn false;
\tconst auto display_side =
\t\tmainGame->dInfo.GetBattleRoyaleDisplaySide(logical_player);
\tif(display_side > 1)
\t\treturn false;
\treturn ReplaceMultiplayerPrivatePiles(display_side,
\t\tmultiplayer_private_piles[logical_player], false);
}
void ClientField::ApplyBattleRoyaleReplayPrivatePiles() {
\tif(!mainGame->dInfo.isReplay
\t\t\t|| !mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))
\t\treturn;
\tbool clear_transient = true;
\tfor(uint8_t display_side = 0; display_side < 2; ++display_side) {
\t\tconst auto logical =
\t\t\tmainGame->dInfo.GetBattleRoyaleDisplayLogical(display_side);
\t\tif(logical < multiplayer_private_piles.size()
\t\t\t\t&& multiplayer_private_piles_valid[logical])
\t\t\tReplaceMultiplayerPrivatePiles(display_side,
\t\t\t\tmultiplayer_private_piles[logical], clear_transient);
\t\telse
\t\t\tReplaceMultiplayerPrivatePiles(display_side,
\t\t\t\tMultiplayerPrivatePileSnapshot{}, clear_transient);
\t\tclear_transient = false;
\t}
}
'''
replace_once(field_cpp, old_apply, new_apply)

insert_marker = '''bool ClientField::ApplyThreeVsOneReplayPrivateDraw(uint8_t logical_player,
'''
text = field_cpp.read_text(encoding='utf-8')
pos = text.find(insert_marker)
if pos < 0:
    raise SystemExit('client_field.cpp: missing ApplyThreeVsOneReplayPrivateDraw marker')
br_draw = r'''bool ClientField::ApplyBattleRoyaleReplayPrivateDraw(uint8_t logical_player,
        const std::vector<MultiplayerPrivatePileCard>& drawn_cards) {
    if(!mainGame->dInfo.isReplay
            || !mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)
            || logical_player >= multiplayer_private_piles.size()
            || !multiplayer_private_piles_valid[logical_player]
            || drawn_cards.empty())
        return false;
    const auto display_side =
        mainGame->dInfo.GetBattleRoyaleDisplaySide(logical_player);
    if(display_side > 1
            || mainGame->dInfo.GetBattleRoyaleDisplayLogical(display_side)
                != logical_player)
        return false;
    const auto& snapshot = multiplayer_private_piles[logical_player];
    const auto count = drawn_cards.size();
    if(snapshot.hand.size() < count
            || hand[display_side].size() + count != snapshot.hand.size()
            || deck[display_side].size() < count)
        return false;
    for(size_t i = 0; i < hand[display_side].size(); ++i) {
        const auto* pcard = hand[display_side][i];
        if(!pcard || pcard->code != snapshot.hand[i].code
                || static_cast<uint8_t>(pcard->position)
                    != snapshot.hand[i].position)
            return false;
    }
    for(const auto& drawn : drawn_cards) {
        auto* pcard = deck[display_side].back();
        deck[display_side].pop_back();
        if(!pcard)
            pcard = new ClientCard{};
        pcard->owner = display_side;
        pcard->controler = display_side;
        pcard->location = LOCATION_DECK;
        if(pcard->code != drawn.code)
            pcard->SetCode(drawn.code);
        pcard->position = drawn.position;
        pcard->is_public = drawn.code != 0;
        pcard->is_fading = false;
        pcard->is_moving = false;
        pcard->refresh_on_stop = false;
        pcard->aniFrame = 0;
        pcard->curAlpha = 255;
        pcard->draw_scale = 1.0f;
        AddCard(pcard, display_side, LOCATION_HAND, 0);
    }
    for(auto* pcard : hand[display_side])
        if(pcard)
            MoveCard(pcard,
                battle_royale_replay_smoothing::DrawMoveFrames(
                    mainGame->dInfo.isReplay,
                    mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)));
    mainGame->should_refresh_hands = true;
    RefreshHandHitboxes();
    return true;
}
'''
field_cpp.write_text(text[:pos] + br_draw + text[pos:], encoding='utf-8')

duel = ROOT / 'gframe' / 'duelclient.cpp'
include_after(duel,
    '#include "multiplayer_replay_animation.h"\n',
    '#include "multiplayer_attack_arrow.h"\n',
    '#include "battle_royale_replay_smoothing.h"\n')

replace_once(duel,
'''\t\tmainGame->dField.ApplyBattleRoyaleReplayPrivatePiles();
\t\tif(perspective_changed || opponent_changed)
\t\t\tmainGame->dField.RefreshAllCards();
''',
'''\t\tmainGame->dField.ApplyBattleRoyaleReplayPrivatePiles();
\t\tif(perspective_changed || opponent_changed)
\t\t\tmainGame->dField.RefreshPublicFieldCards();
''')

replace_once(duel,
'''\t\t\tif(outgoing < 4
\t\t\t\t\t&& !(mainGame->dInfo.isReplay
\t\t\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))) {
''',
'''\t\t\tif(outgoing < 4
\t\t\t\t\t&& !(mainGame->dInfo.isReplay
\t\t\t\t\t\t&& (mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
\t\t\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)))) {
''')

replace_once(duel,
'''\t\tif((mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))
\t\t\t\t&& active_seat_changed
\t\t\t\t&& !(mainGame->dInfo.isReplay
\t\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)))
\t\t\tmainGame->dField.RefreshAllCards();
''',
'''\t\tif((mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))
\t\t\t\t&& active_seat_changed
\t\t\t\t&& battle_royale_replay_smoothing::NeedsSecondTurnRefresh(
\t\t\t\t\tmainGame->dInfo.isReplay,
\t\t\t\t\tmainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))
\t\t\t\t&& !(mainGame->dInfo.isReplay
\t\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)))
\t\t\tmainGame->dField.RefreshAllCards();
''')

draw_anchor = '''\t\tif(mainGame->dInfo.isReplay && mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)) {
\t\t\tmainGame->dField.UpdateMultiplayerPrivateDraw(logical_player, drawn_cards);
\t\t\tconst bool displayed =
\t\t\t\tmainGame->dField.IsThreeVsOneReplayHandDisplayed(logical_player);
\t\t\tif(displayed
\t\t\t\t\t&& !mainGame->dField.ApplyThreeVsOneReplayPrivateDraw(
\t\t\t\t\t\tlogical_player, drawn_cards))
\t\t\t\tmainGame->dField.ApplyThreeVsOneReplayPrivatePiles();
\t\t\tconst auto sounds = multiplayer_replay_animation::DrawSoundCount(
\t\t\t\ttrue, displayed, count);
\t\t\tfor(uint32_t i = 0; i < sounds; ++i)
\t\t\t\tPlay(SoundManager::SFX::DRAW);
\t\t\treturn true;
\t\t}
'''
br_draw_handler = draw_anchor + '''\t\tif(mainGame->dInfo.isReplay
\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)
\t\t\t\t&& logical_player < mainGame->dField.multiplayer_private_piles_valid.size()
\t\t\t\t&& mainGame->dField.multiplayer_private_piles_valid[logical_player]) {
\t\t\tmainGame->dField.UpdateMultiplayerPrivateDraw(logical_player, drawn_cards);
\t\t\tconst bool displayed =
\t\t\t\tmainGame->dInfo.GetBattleRoyaleDisplaySide(logical_player) < 2;
\t\t\tif(displayed
\t\t\t\t\t&& !mainGame->dField.ApplyBattleRoyaleReplayPrivateDraw(
\t\t\t\t\t\tlogical_player, drawn_cards))
\t\t\t\tmainGame->dField.ApplyBattleRoyaleReplayPrivatePile(logical_player);
\t\t\tconst auto sounds = battle_royale_replay_smoothing::DrawSoundCount(
\t\t\t\ttrue, true, displayed, count);
\t\t\tfor(uint32_t i = 0; i < sounds; ++i)
\t\t\t\tPlay(SoundManager::SFX::DRAW);
\t\t\treturn true;
\t\t}
'''
replace_once(duel, draw_anchor, br_draw_handler)

replace_in_range(duel,
    '\tcase MSG_MULTIPLAYER_DRAW: {',
    '\tcase MSG_MULTIPLAYER_PRIVATE_PILES: {',
'''\t\t\t} else if(mainGame->dInfo.GetBattleRoyaleDisplaySide(logical_player) < 2)
\t\t\t\tmainGame->dField.ApplyBattleRoyaleReplayPrivatePiles();
''',
'''\t\t\t} else if(mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)) {
\t\t\t\tconst bool displayed =
\t\t\t\t\tmainGame->dInfo.GetBattleRoyaleDisplaySide(logical_player) < 2;
\t\t\t\tif(displayed
\t\t\t\t\t\t&& !mainGame->dField.ApplyBattleRoyaleReplayPrivateDraw(
\t\t\t\t\t\t\tlogical_player, drawn_cards))
\t\t\t\t\tmainGame->dField.ApplyBattleRoyaleReplayPrivatePile(logical_player);
\t\t\t\tsounds = battle_royale_replay_smoothing::DrawSoundCount(
\t\t\t\t\ttrue, true, displayed, count);
\t\t\t}
''')

replace_in_range(duel,
    '\tcase MSG_MULTIPLAYER_PRIVATE_PILES: {',
    '\tcase MSG_DAMAGE: {',
'''\t\t\t} else if(mainGame->dInfo.GetBattleRoyaleDisplaySide(logical_player) < 2)
\t\t\t\tmainGame->dField.ApplyBattleRoyaleReplayPrivatePiles();
''',
'''\t\t\t} else if(mainGame->dInfo.GetBattleRoyaleDisplaySide(logical_player) < 2)
\t\t\t\tmainGame->dField.ApplyBattleRoyaleReplayPrivatePile(logical_player);
''')

insert = '''\t\tif(mainGame->dInfo.isReplay
\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)) {
\t\t\t// Replay snapshots already carry exact logical Hand/Deck/Extra/GY/Banish.
\t\t\t// Replaying TAG_SWAP here would delete/recreate the visible hand and is
\t\t\t// the main source of flicker, stalls and P3 appearing during P4's turn.
\t\t\treturn true;
\t\t}
'''
replacement = insert + '''\t\tif(battle_royale_replay_smoothing::ShouldSkipLegacyTagSwap(
\t\t\t\tmainGame->dInfo.isReplay,
\t\t\t\tmainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE),
\t\t\t\tlogical_player < mainGame->dField.multiplayer_private_piles_valid.size()
\t\t\t\t\t&& mainGame->dField.multiplayer_private_piles_valid[logical_player]))
\t\t\treturn true;
'''
replace_once(duel, insert, replacement)

print('Applied Battle Royale replay turn/draw smoothing without changing 3v1 policy.')
