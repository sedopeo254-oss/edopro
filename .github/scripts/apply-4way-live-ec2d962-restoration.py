from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding='utf-8')


def write(path: str, text: str) -> None:
    (ROOT / path).write_text(text, encoding='utf-8')


def replace_once(path: str, old: str, new: str) -> None:
    text = read(path)
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected exactly one replacement, found {count}: {old[:120]!r}')
    write(path, text.replace(old, new, 1))


def replace_in_range(path: str, start_marker: str, end_marker: str,
                     old: str, new: str) -> None:
    text = read(path)
    start = text.find(start_marker)
    if start < 0:
        raise SystemExit(f'{path}: missing range start {start_marker!r}')
    end = text.find(end_marker, start + len(start_marker))
    if end < 0:
        raise SystemExit(f'{path}: missing range end {end_marker!r}')
    block = text[start:end]
    count = block.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one replacement in range, found {count}: {old[:120]!r}')
    block = block.replace(old, new, 1)
    write(path, text[:start] + block + text[end:])


def insert_before_once(path: str, marker: str, insertion: str) -> None:
    text = read(path)
    count = text.count(marker)
    if count != 1:
        raise SystemExit(f'{path}: expected one insertion marker, found {count}: {marker!r}')
    write(path, text.replace(marker, insertion + marker, 1))


def insert_after_once(path: str, marker: str, insertion: str) -> None:
    text = read(path)
    count = text.count(marker)
    if count != 1:
        raise SystemExit(f'{path}: expected one insertion marker, found {count}: {marker!r}')
    write(path, text.replace(marker, marker + insertion, 1))


# ---------------------------------------------------------------------------
# Pure policy used by both source comments/tests and live Battle Royale code.
# It describes the old ec2d962 two-seat presentation without coupling it to
# the two physical Core sides: the local/attacking field stays below, while
# the selected opponent is projected above even when both share a Core side.
# ---------------------------------------------------------------------------
policy_h = ROOT / 'gframe' / 'battle_royale_live_policy.h'
policy_h.write_text(r'''#ifndef BATTLE_ROYALE_LIVE_POLICY_H
#define BATTLE_ROYALE_LIVE_POLICY_H

#include <cstdint>

namespace ygo::battle_royale_live_policy {

constexpr uint8_t NO_PLAYER = 0xff;

constexpr uint8_t DisplaySide(uint8_t local_logical,
        uint8_t opponent_logical, uint8_t logical_player) {
    if(logical_player == local_logical)
        return 0;
    if(logical_player == opponent_logical)
        return 1;
    return NO_PLAYER;
}

constexpr bool IsValidOpponent(uint8_t local_logical,
        uint8_t candidate, uint8_t player_count, uint8_t active_mask) {
    return candidate < player_count && candidate != local_logical
        && (active_mask & (1u << candidate));
}

constexpr bool RevealPrivateCode(uint8_t local_logical,
        uint8_t owner_logical, uint8_t location, uint8_t position,
        uint8_t location_hand, uint8_t location_extra,
        uint8_t location_removed, uint8_t pos_faceup) {
    if(owner_logical == local_logical)
        return true;
    if(location == location_hand)
        return false;
    if(location == location_extra || location == location_removed)
        return (position & pos_faceup) != 0;
    // Graveyard and all public zones keep their public code.
    return true;
}

constexpr bool PreserveLocalLowerField(bool is_replay,
        bool is_battle_royale) {
    return !is_replay && is_battle_royale;
}

} // namespace ygo::battle_royale_live_policy

#endif
''', encoding='utf-8')

policy_test = ROOT / '.github' / 'tests' / 'battle_royale_live_policy_test.cpp'
policy_test.parent.mkdir(parents=True, exist_ok=True)
policy_test.write_text(r'''#include <cstdlib>
#include <iostream>
#include "gframe/battle_royale_live_policy.h"

using namespace ygo::battle_royale_live_policy;

static void expect(bool value, const char* message) {
    if(!value) {
        std::cerr << message << '\n';
        std::exit(EXIT_FAILURE);
    }
}

int main() {
    // Logical order is P1,P3 on Core side 0 and P2,P4 on Core side 1.
    // The two-seat renderer is independent from those Core sides.
    expect(DisplaySide(0, 1, 0) == 0 && DisplaySide(0, 1, 1) == 1,
        "P1 attacking P3 must keep P1 below and show P3 above");
    expect(DisplaySide(1, 0, 1) == 0 && DisplaySide(1, 0, 0) == 1,
        "P3 attacking P1 must keep P3 below and show P1 above");
    expect(DisplaySide(2, 3, 2) == 0 && DisplaySide(2, 3, 3) == 1,
        "P2 attacking P4 must keep P2 below and show P4 above");
    expect(DisplaySide(3, 2, 3) == 0 && DisplaySide(3, 2, 2) == 1,
        "P4 attacking P2 must keep P4 below and show P2 above");
    expect(DisplaySide(0, 2, 3) == NO_PLAYER,
        "an unrelated third opponent must remain hidden");

    constexpr uint8_t hand = 0x02;
    constexpr uint8_t extra = 0x40;
    constexpr uint8_t removed = 0x20;
    constexpr uint8_t faceup = 0x01;
    expect(RevealPrivateCode(0, 0, hand, 0, hand, extra, removed, faceup),
        "the local player's hand codes must remain visible");
    expect(!RevealPrivateCode(0, 1, hand, 0, hand, extra, removed, faceup),
        "an opponent hand must remain card backs");
    expect(!RevealPrivateCode(0, 1, extra, 0, hand, extra, removed, faceup),
        "a facedown opponent Extra Deck card must remain hidden");
    expect(RevealPrivateCode(0, 1, extra, faceup, hand, extra, removed, faceup),
        "a faceup opponent Extra Deck card is public");
    expect(!RevealPrivateCode(0, 1, removed, 0, hand, extra, removed, faceup),
        "a facedown banished card must remain hidden");
    expect(PreserveLocalLowerField(false, true),
        "live Battle Royale must preserve the lower local/attacker field");
    expect(!PreserveLocalLowerField(true, true),
        "replay keeps its existing attacker-perspective implementation");

    std::cout << "Live Battle Royale ec2d962 projection policy tests passed.\n";
}
''', encoding='utf-8')

# ---------------------------------------------------------------------------
# ClientField live cache/projection API.
# ---------------------------------------------------------------------------
replace_once('gframe/client_field.h',
'''\tvoid CacheMultiplayerPrivatePiles(uint8_t logical_player, const MultiplayerPrivatePileSnapshot& snapshot);
\tvoid CaptureBattleRoyaleReplayPrivatePiles();
''',
'''\tvoid CacheMultiplayerPrivatePiles(uint8_t logical_player, const MultiplayerPrivatePileSnapshot& snapshot);
\tvoid CacheBattleRoyaleLivePrivatePiles(uint8_t logical_player,
\t\tMultiplayerPrivatePileSnapshot snapshot);
\tvoid EnsureBattleRoyaleLivePrivatePile(uint8_t logical_player);
\tvoid CaptureBattleRoyaleLivePrivatePiles();
\tbool ApplyBattleRoyaleLivePrivatePiles(bool clear_transient = false);
\tbool ApplyBattleRoyaleLivePrivateDraw(uint8_t logical_player,
\t\tconst std::vector<MultiplayerPrivatePileCard>& drawn_cards);
\tvoid CaptureBattleRoyaleReplayPrivatePiles();
''')

replace_once('gframe/client_field.cpp',
'#include "battle_royale_replay_smoothing.h"\n',
'#include "battle_royale_replay_smoothing.h"\n#include "battle_royale_live_policy.h"\n')

live_methods = r'''namespace {
void SanitizeBattleRoyaleLiveSnapshot(const DuelInfo& info,
        uint8_t logical_player, MultiplayerPrivatePileSnapshot& snapshot) {
    const auto local = info.GetLocalLogicalPlayer();
    snapshot.top_code = logical_player == local ? snapshot.top_code : 0;
    auto sanitize = [&](auto& cards, uint8_t location) {
        for(auto& card : cards) {
            if(!battle_royale_live_policy::RevealPrivateCode(local,
                    logical_player, location, card.position,
                    LOCATION_HAND, LOCATION_EXTRA, LOCATION_REMOVED,
                    POS_FACEUP))
                card.code = 0;
            if(location == LOCATION_HAND && logical_player != local)
                card.position = POS_FACEDOWN_DEFENSE;
        }
    };
    sanitize(snapshot.hand, LOCATION_HAND);
    sanitize(snapshot.extra, LOCATION_EXTRA);
    sanitize(snapshot.grave, LOCATION_GRAVE);
    sanitize(snapshot.removed, LOCATION_REMOVED);
}

template<typename Cards>
void ResizeSnapshotCards(Cards& cards, size_t count, uint8_t position) {
    cards.resize(count, MultiplayerPrivatePileCard{ 0, position });
}
}

void ClientField::CacheBattleRoyaleLivePrivatePiles(uint8_t logical_player,
        MultiplayerPrivatePileSnapshot snapshot) {
    if(mainGame->dInfo.isReplay
            || !mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)
            || logical_player >= multiplayer_private_piles.size())
        return;
    SanitizeBattleRoyaleLiveSnapshot(mainGame->dInfo,
        logical_player, snapshot);
    CacheMultiplayerPrivatePiles(logical_player, snapshot);
}

void ClientField::EnsureBattleRoyaleLivePrivatePile(uint8_t logical_player) {
    if(mainGame->dInfo.isReplay
            || !mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)
            || logical_player >= multiplayer_private_piles.size()
            || multiplayer_private_piles_valid[logical_player])
        return;
    MultiplayerPrivatePileSnapshot snapshot;
    snapshot.deck_count = mainGame->dInfo.logical_deck_count[logical_player];
    ResizeSnapshotCards(snapshot.hand,
        mainGame->dInfo.logical_hand_count[logical_player],
        POS_FACEDOWN_DEFENSE);
    ResizeSnapshotCards(snapshot.extra,
        mainGame->dInfo.logical_extra_count[logical_player],
        POS_FACEDOWN_DEFENSE);
    ResizeSnapshotCards(snapshot.grave,
        mainGame->dInfo.logical_grave_count[logical_player], POS_FACEUP);
    ResizeSnapshotCards(snapshot.removed,
        mainGame->dInfo.logical_banish_count[logical_player], POS_FACEUP);
    CacheBattleRoyaleLivePrivatePiles(logical_player, snapshot);
}

void ClientField::CaptureBattleRoyaleLivePrivatePiles() {
    if(mainGame->dInfo.isReplay
            || !mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))
        return;
    auto capture_cards = [](const auto& source, auto& destination) {
        destination.clear();
        destination.reserve(source.size());
        for(const auto* pcard : source) {
            if(pcard)
                destination.push_back({ pcard->code,
                    static_cast<uint8_t>(pcard->position) });
        }
    };
    for(uint8_t display_side = 0; display_side < 2; ++display_side) {
        const auto logical =
            mainGame->dInfo.GetBattleRoyaleDisplayLogical(display_side);
        if(logical >= multiplayer_private_piles.size())
            continue;
        const auto known_field = multiplayer_displayed_field_logical[display_side];
        const auto known_hand = multiplayer_displayed_hand_logical[display_side];
        if((known_field != 0xff && known_field != logical)
                || (known_hand != 0xff && known_hand != logical))
            continue;
        MultiplayerPrivatePileSnapshot snapshot;
        snapshot.deck_count = static_cast<uint32_t>(deck[display_side].size());
        snapshot.extra_p_count = extra_p_count[display_side] > 0
            ? static_cast<uint32_t>(std::min<size_t>(
                extra_p_count[display_side], extra[display_side].size())) : 0;
        snapshot.top_code = deck[display_side].empty()
            ? 0 : deck[display_side].back()->code;
        capture_cards(hand[display_side], snapshot.hand);
        capture_cards(extra[display_side], snapshot.extra);
        capture_cards(grave[display_side], snapshot.grave);
        capture_cards(remove[display_side], snapshot.removed);
        CacheBattleRoyaleLivePrivatePiles(logical, snapshot);
        multiplayer_displayed_field_logical[display_side] = logical;
        multiplayer_displayed_hand_logical[display_side] = logical;
    }
}

bool ClientField::ApplyBattleRoyaleLivePrivatePiles(bool clear_transient) {
    if(mainGame->dInfo.isReplay
            || !mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))
        return false;
    bool changed = false;
    bool may_clear = clear_transient;
    for(uint8_t display_side = 0; display_side < 2; ++display_side) {
        const auto logical =
            mainGame->dInfo.GetBattleRoyaleDisplayLogical(display_side);
        if(logical >= multiplayer_private_piles.size())
            continue;
        EnsureBattleRoyaleLivePrivatePile(logical);
        auto snapshot = multiplayer_private_piles[logical];
        snapshot.deck_count = mainGame->dInfo.logical_deck_count[logical];
        ResizeSnapshotCards(snapshot.hand,
            mainGame->dInfo.logical_hand_count[logical],
            POS_FACEDOWN_DEFENSE);
        ResizeSnapshotCards(snapshot.extra,
            mainGame->dInfo.logical_extra_count[logical],
            POS_FACEDOWN_DEFENSE);
        ResizeSnapshotCards(snapshot.grave,
            mainGame->dInfo.logical_grave_count[logical], POS_FACEUP);
        ResizeSnapshotCards(snapshot.removed,
            mainGame->dInfo.logical_banish_count[logical], POS_FACEUP);
        SanitizeBattleRoyaleLiveSnapshot(mainGame->dInfo,
            logical, snapshot);
        CacheMultiplayerPrivatePiles(logical, snapshot);
        changed = ReplaceMultiplayerPrivatePiles(display_side,
            snapshot, may_clear) || changed;
        multiplayer_displayed_field_logical[display_side] = logical;
        multiplayer_displayed_hand_logical[display_side] = logical;
        may_clear = false;
    }
    return changed;
}

bool ClientField::ApplyBattleRoyaleLivePrivateDraw(uint8_t logical_player,
        const std::vector<MultiplayerPrivatePileCard>& drawn_cards) {
    if(mainGame->dInfo.isReplay
            || !mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)
            || logical_player >= multiplayer_private_piles.size()
            || !multiplayer_private_piles_valid[logical_player]
            || drawn_cards.empty())
        return false;
    const auto display_side =
        mainGame->dInfo.GetBattleRoyaleDisplaySide(logical_player);
    if(display_side > 1
            || multiplayer_displayed_field_logical[display_side] != logical_player
            || multiplayer_displayed_hand_logical[display_side] != logical_player)
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
        pcard->is_public = logical_player == mainGame->dInfo.GetLocalLogicalPlayer()
            && drawn.code != 0;
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
            MoveCard(pcard, 10);
    mainGame->should_refresh_hands = true;
    RefreshHandHitboxes();
    return true;
}

'''
insert_before_once('gframe/client_field.cpp',
    'void ClientField::CaptureBattleRoyaleReplayPrivatePiles() {\n',
    live_methods)

replace_once('gframe/client_field.cpp',
'''void ClientField::UpdateMultiplayerPrivateDraw(uint8_t logical_player,
\t\tconst std::vector<MultiplayerPrivatePileCard>& drawn_cards) {
\tif(logical_player >= multiplayer_private_piles.size()
\t\t\t|| !multiplayer_private_piles_valid[logical_player])
\t\treturn;
''',
'''void ClientField::UpdateMultiplayerPrivateDraw(uint8_t logical_player,
\t\tconst std::vector<MultiplayerPrivatePileCard>& drawn_cards) {
\tif(!mainGame->dInfo.isReplay
\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))
\t\tEnsureBattleRoyaleLivePrivatePile(logical_player);
\tif(logical_player >= multiplayer_private_piles.size()
\t\t\t|| !multiplayer_private_piles_valid[logical_player])
\t\treturn;
''')

replace_once('gframe/client_field.cpp',
'''\tif(!mainGame->dInfo.isReplay
\t\t\t|| !(mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)
\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)))
\t\treturn;
''',
'''\tif(!(mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)
\t\t\t|| (mainGame->dInfo.isReplay
\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))))
\t\treturn;
\tif(!mainGame->dInfo.isReplay
\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)) {
\t\tEnsureBattleRoyaleLivePrivatePile(previous_logical);
\t\tEnsureBattleRoyaleLivePrivatePile(current_logical);
\t}
''')

replace_once('gframe/duelclient.cpp',
'#include "battle_royale_replay_smoothing.h"\n',
'#include "battle_royale_replay_smoothing.h"\n#include "battle_royale_live_policy.h"\n')

replace_once('gframe/duelclient.cpp',
'''\t\tif(!mainGame->dInfo.SetBattleRoyaleOpponent(logical))
\t\t\treturn false;
\t\tmainGame->dField.RefreshAllCards();
\t\treturn true;
''',
'''\t\tmainGame->dField.CaptureBattleRoyaleLivePrivatePiles();
\t\tif(!mainGame->dInfo.SetBattleRoyaleOpponent(logical))
\t\t\treturn false;
\t\tmainGame->dField.ApplyBattleRoyaleLivePrivatePiles(false);
\t\tmainGame->dField.RefreshPublicFieldCards();
\t\treturn true;
''')

replace_once('gframe/duelclient.cpp',
'''\t\tmainGame->dField.Initial(mainGame->LocalPlayer(1), deckc, extrac);
\t\tmainGame->dInfo.turn = 0;
''',
'''\t\tmainGame->dField.Initial(mainGame->LocalPlayer(1), deckc, extrac);
\t\tif(!mainGame->dInfo.isReplay
\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)) {
\t\t\tfor(uint8_t display_side = 0; display_side < 2; ++display_side) {
\t\t\t\tconst auto logical =
\t\t\t\t\tmainGame->dInfo.GetBattleRoyaleDisplayLogical(display_side);
\t\t\t\tmainGame->dField.multiplayer_displayed_field_logical[display_side] = logical;
\t\t\t\tmainGame->dField.multiplayer_displayed_hand_logical[display_side] = logical;
\t\t\t}
\t\t\tmainGame->dField.CaptureBattleRoyaleLivePrivatePiles();
\t\t}
\t\tmainGame->dInfo.turn = 0;
''')

replace_in_range('gframe/duelclient.cpp',
    '\tcase MSG_MULTIPLAYER_PRIVATE_PILES: {\n',
    '\tcase MSG_DAMAGE: {\n',
'''\t\tif(mainGame->dInfo.isReplay
\t\t\t\t&& (mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)
\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))) {
''',
'''\t\tif(!mainGame->dInfo.isReplay
\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)) {
\t\t\tmainGame->dField.CacheBattleRoyaleLivePrivatePiles(
\t\t\t\tlogical_player, snapshot);
\t\t\tif(mainGame->dInfo.GetBattleRoyaleDisplaySide(logical_player) < 2)
\t\t\t\tmainGame->dField.ApplyBattleRoyaleLivePrivatePiles(false);
\t\t} else if(mainGame->dInfo.isReplay
\t\t\t\t&& (mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)
\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))) {
''')

# live draw insertion
insert_before_once('gframe/duelclient.cpp',
'''\t\tif(mainGame->dInfo.isReplay
\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)
\t\t\t\t&& logical_player < mainGame->dField.multiplayer_private_piles_valid.size()
\t\t\t\t&& mainGame->dField.multiplayer_private_piles_valid[logical_player]) {
''',
'''\t\tif(!mainGame->dInfo.isReplay
\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)) {
\t\t\tmainGame->dField.UpdateMultiplayerPrivateDraw(logical_player, drawn_cards);
\t\t\tconst bool displayed =
\t\t\t\tmainGame->dInfo.GetBattleRoyaleDisplaySide(logical_player) < 2;
\t\t\tif(displayed
\t\t\t\t\t&& !mainGame->dField.ApplyBattleRoyaleLivePrivateDraw(
\t\t\t\t\t\tlogical_player, drawn_cards))
\t\t\t\tmainGame->dField.ApplyBattleRoyaleLivePrivatePiles(false);
\t\t\tif(displayed)
\t\t\t\tPlay(SoundManager::SFX::DRAW);
\t\t\treturn true;
\t\t}
''')

replace_in_range('gframe/duelclient.cpp',
    '\tcase MSG_MULTIPLAYER_DRAW: {\n',
    '\tcase MSG_MULTIPLAYER_PRIVATE_PILES: {\n',
'''\t\t} else if(logical_player == mainGame->dInfo.GetLocalLogicalPlayer()) {
''',
'''\t\t} else if(mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)) {
\t\t\tmainGame->dField.UpdateMultiplayerPrivateDraw(logical_player, drawn_cards);
\t\t\tconst bool displayed =
\t\t\t\tmainGame->dInfo.GetBattleRoyaleDisplaySide(logical_player) < 2;
\t\t\tif(displayed
\t\t\t\t\t&& !mainGame->dField.ApplyBattleRoyaleLivePrivateDraw(
\t\t\t\t\t\tlogical_player, drawn_cards))
\t\t\t\tmainGame->dField.ApplyBattleRoyaleLivePrivatePiles(false);
\t\t\tsounds = displayed ? 1u : 0u;
\t\t} else if(logical_player == mainGame->dInfo.GetLocalLogicalPlayer()) {
''')

replace_in_range('gframe/duelclient.cpp',
    '\tcase MSG_MULTIPLAYER_NEW_TURN: {\n',
    '\tcase MSG_MULTIPLAYER_REPLAY_VIEW: {\n',
'''\t\tmainGame->dInfo.logical_turn_player = logical_player;
''',
'''\t\tif(!mainGame->dInfo.isReplay
\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))
\t\t\tmainGame->dField.CaptureBattleRoyaleLivePrivatePiles();
\t\tmainGame->dInfo.logical_turn_player = logical_player;
''')

replace_in_range('gframe/duelclient.cpp',
    '\tcase MSG_MULTIPLAYER_NEW_TURN: {\n',
    '\tcase MSG_MULTIPLAYER_REPLAY_VIEW: {\n',
'''\t\t\tif(outgoing < 4
\t\t\t\t\t&& !(mainGame->dInfo.isReplay
\t\t\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))) {
''',
'''\t\t\tconst bool displayed_owner_matches =
\t\t\t\t!mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)
\t\t\t\t|| local_side > 1
\t\t\t\t|| mainGame->dField.multiplayer_displayed_field_logical[local_side]
\t\t\t\t\t== outgoing;
\t\t\tif(outgoing < 4 && displayed_owner_matches
\t\t\t\t\t&& !(mainGame->dInfo.isReplay
\t\t\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))) {
''')

replace_in_range('gframe/duelclient.cpp',
    '\tcase MSG_MULTIPLAYER_NEW_TURN: {\n',
    '\tcase MSG_MULTIPLAYER_REPLAY_VIEW: {\n',
'''\t\t// Multiplayer on-field arrays contain encoded per-duelist fields.
\t\t// Rebuild the normal two-side projection when either side changes focus.
\t\tif((mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))
\t\t\t\t&& active_seat_changed
\t\t\t\t&& !(mainGame->dInfo.isReplay
\t\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)))
\t\t\tmainGame->dField.RefreshAllCards();
''',
'''\t\t// Multiplayer on-field arrays contain encoded per-duelist fields.
\t\tif(!mainGame->dInfo.isReplay
\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)) {
\t\t\tmainGame->dField.ApplyBattleRoyaleLivePrivatePiles(true);
\t\t\tmainGame->dField.RefreshPublicFieldCards();
\t\t} else if((mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))
\t\t\t\t&& active_seat_changed
\t\t\t\t&& !(mainGame->dInfo.isReplay
\t\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)))
\t\t\tmainGame->dField.RefreshAllCards();
''')

replace_once('gframe/duelclient.cpp',
'''\t\t\t\tif(mainGame->dInfo.SetBattleRoyaleOpponent(displayed_opponent))
\t\t\t\t\tmainGame->dField.RefreshAllCards();
''',
'''\t\t\t\tmainGame->dField.CaptureBattleRoyaleLivePrivatePiles();
\t\t\t\tif(mainGame->dInfo.SetBattleRoyaleOpponent(displayed_opponent)) {
\t\t\t\t\tmainGame->dField.ApplyBattleRoyaleLivePrivatePiles(false);
\t\t\t\t\tmainGame->dField.RefreshPublicFieldCards();
\t\t\t\t}
''')

replace_in_range('gframe/duelclient.cpp',
    '\tcase MSG_DAMAGE: {\n',
    '\tcase MSG_RECOVER: {\n',
'''\t\tif(mainGame->dInfo.isReplay
\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)
\t\t\t\t&& logical_player < mainGame->dInfo.team1 + mainGame->dInfo.team2
\t\t\t\t&& logical_player != mainGame->dInfo.GetLocalLogicalPlayer())
\t\t\tSetBattleRoyaleReplayView(
\t\t\t\tmainGame->dInfo.GetLocalLogicalPlayer(), logical_player);
\t\telse if(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
''',
'''\t\tif(mainGame->dInfo.isReplay
\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)
\t\t\t\t&& logical_player < mainGame->dInfo.team1 + mainGame->dInfo.team2
\t\t\t\t&& logical_player != mainGame->dInfo.GetLocalLogicalPlayer())
\t\t\tSetBattleRoyaleReplayView(
\t\t\t\tmainGame->dInfo.GetLocalLogicalPlayer(), logical_player);
\t\telse if(!mainGame->dInfo.isReplay
\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)
\t\t\t\t&& logical_player < mainGame->dInfo.team1 + mainGame->dInfo.team2
\t\t\t\t&& logical_player != mainGame->dInfo.GetLocalLogicalPlayer()) {
\t\t\tmainGame->dField.CaptureBattleRoyaleLivePrivatePiles();
\t\t\tif(mainGame->dInfo.SetBattleRoyaleOpponent(logical_player)) {
\t\t\t\tmainGame->dField.ApplyBattleRoyaleLivePrivatePiles(false);
\t\t\t\tmainGame->dField.RefreshPublicFieldCards();
\t\t\t}
\t\t} else if(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
''')

# TAG_SWAP cache
insert_before_once('gframe/duelclient.cpp',
'''\t\tif(mainGame->dInfo.isReplay
\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)) {
''',
r'''\t\tif(!mainGame->dInfo.isReplay
\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)
\t\t\t\t&& logical_player < player_count) {
\t\t\tconst auto* cachebuf = pbuf;
\t\t\tMultiplayerPrivatePileSnapshot snapshot;
\t\t\tsnapshot.deck_count = mcount;
\t\t\tsnapshot.extra_p_count = pcount;
\t\t\tsnapshot.top_code = topcode;
\t\t\tauto read_private_cards = [&](auto& cards, uint32_t count,
\t\t\t\t\tuint8_t default_position) {
\t\t\t\tcards.reserve(count);
\t\t\t\tfor(uint32_t i = 0; i < count; ++i) {
\t\t\t\t\tif(cachebuf + sizeof(uint32_t) > payload_end)
\t\t\t\t\t\treturn false;
\t\t\t\t\tauto card_code = BufferIO::Read<uint32_t>(cachebuf);
\t\t\t\t\tauto card_position = default_position;
\t\t\t\t\tif(!mainGame->dInfo.compat_mode) {
\t\t\t\t\t\tif(cachebuf + sizeof(uint32_t) > payload_end)
\t\t\t\t\t\t\treturn false;
\t\t\t\t\t\tcard_position = static_cast<uint8_t>(
\t\t\t\t\t\t\tBufferIO::Read<uint32_t>(cachebuf));
\t\t\t\t\t} else {
\t\t\t\t\t\tcard_position = card_code & 0x80000000
\t\t\t\t\t\t\t? POS_FACEUP : default_position;
\t\t\t\t\t\tcard_code &= 0x7fffffff;
\t\t\t\t\t}
\t\t\t\t\tcards.push_back({ card_code, card_position });
\t\t\t\t}
\t\t\t\treturn true;
\t\t\t};
\t\t\tbool valid_snapshot = read_private_cards(snapshot.hand,
\t\t\t\thcount, POS_FACEDOWN_DEFENSE)
\t\t\t\t&& read_private_cards(snapshot.extra,
\t\t\t\t\tecount, POS_FACEDOWN_DEFENSE);
\t\t\tif(valid_snapshot && is_multiplayer
\t\t\t\t\t&& cachebuf + 2 * sizeof(uint32_t) <= payload_end) {
\t\t\t\tconst auto gcount = BufferIO::Read<uint32_t>(cachebuf);
\t\t\t\tconst auto rcount = BufferIO::Read<uint32_t>(cachebuf);
\t\t\t\tauto read_public_cards = [&](auto& cards, uint32_t count) {
\t\t\t\t\tcards.reserve(count);
\t\t\t\t\tfor(uint32_t i = 0; i < count; ++i) {
\t\t\t\t\t\tif(cachebuf + 2 * sizeof(uint32_t) > payload_end)
\t\t\t\t\t\t\treturn false;
\t\t\t\t\t\tconst auto card_code = BufferIO::Read<uint32_t>(cachebuf);
\t\t\t\t\t\tconst auto card_position = static_cast<uint8_t>(
\t\t\t\t\t\t\tBufferIO::Read<uint32_t>(cachebuf));
\t\t\t\t\t\tcards.push_back({ card_code, card_position });
\t\t\t\t\t}
\t\t\t\t\treturn true;
\t\t\t\t};
\t\t\t\tvalid_snapshot = read_public_cards(snapshot.grave, gcount)
\t\t\t\t\t&& read_public_cards(snapshot.removed, rcount);
\t\t\t}
\t\t\tif(valid_snapshot)
\t\t\t\tmainGame->dField.CacheBattleRoyaleLivePrivatePiles(
\t\t\t\t\tlogical_player, snapshot);
\t\t}
''')

replace_in_range('gframe/duelclient.cpp',
    '\tcase MSG_TAG_SWAP: {\n',
    '\tcase MSG_RELOAD_FIELD: {\n',
'''\t\tif(!(mainGame->dInfo.duel_params & (DUEL_BATTLE_ROYALE | DUEL_3_V_1))) {
''',
'''\t\tif(!mainGame->dInfo.isReplay
\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)
\t\t\t\t&& private_display < 2 && logical_player < player_count) {
\t\t\tmainGame->dField.multiplayer_displayed_field_logical[private_display]
\t\t\t\t= logical_player;
\t\t\tmainGame->dField.multiplayer_displayed_hand_logical[private_display]
\t\t\t\t= logical_player;
\t\t}
\t\tif(!(mainGame->dInfo.duel_params & (DUEL_BATTLE_ROYALE | DUEL_3_V_1))) {
''')

print('Applied live 4-way Battle Royale ec2d962 restoration without changing 3v1/replay policy.')
