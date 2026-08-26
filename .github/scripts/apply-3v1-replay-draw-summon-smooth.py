from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one replacement site, found {count}')
    path.write_text(text.replace(old, new, 1), encoding='utf-8')


def replace_case(path: Path, start_marker: str, end_marker: str, transform) -> None:
    text = path.read_text(encoding='utf-8')
    start = text.find(start_marker)
    if start < 0:
        raise SystemExit(f'{path}: missing {start_marker}')
    end = text.find(end_marker, start + len(start_marker))
    if end < 0:
        raise SystemExit(f'{path}: missing end marker {end_marker}')
    old = text[start:end]
    new = transform(old)
    if new == old:
        raise SystemExit(f'{path}: transformation for {start_marker} made no change')
    path.write_text(text[:start] + new + text[end:], encoding='utf-8')


# Small pure helper keeps replay timing policy independently testable.
header = ROOT / 'gframe' / 'multiplayer_replay_animation.h'
header.write_text(r'''#ifndef MULTIPLAYER_REPLAY_ANIMATION_H
#define MULTIPLAYER_REPLAY_ANIMATION_H

#include <cstdint>

namespace ygo::multiplayer_replay_animation {

struct SummonTiming {
	uint8_t reveal_frames;
	uint8_t settle_frames;
	uint8_t move_frames;
};

constexpr SummonTiming GetSummonTiming(bool is_replay, bool is_three_vs_one) {
	// Keep live duels and all stock modes unchanged. 3v1 replay animations are
	// shorter because a projected field/private-pile update already surrounds
	// each summon and the stock 30+11 frame pause feels like a freeze.
	return is_replay && is_three_vs_one
		? SummonTiming{ 15, 4, 6 }
		: SummonTiming{ 30, 11, 10 };
}

constexpr uint32_t DrawSoundCount(bool smooth_three_vs_one_replay,
		bool displayed, uint32_t drawn_count) {
	if(!drawn_count)
		return 0;
	// Multi-card effects such as Card of Sanctity must not stack six identical
	// sounds while private snapshots are being reconciled. Play one sound only
	// for the hand that is actually visible.
	return smooth_three_vs_one_replay ? (displayed ? 1u : 0u) : drawn_count;
}

} // namespace ygo::multiplayer_replay_animation

#endif
''', encoding='utf-8')

# Unit test for the behavior that caused the uploaded replay stalls.
test = ROOT / '.github' / 'tests' / 'multiplayer_replay_animation_test.cpp'
test.parent.mkdir(parents=True, exist_ok=True)
test.write_text(r'''#include <cstdlib>
#include <iostream>
#include "gframe/multiplayer_replay_animation.h"

using namespace ygo::multiplayer_replay_animation;

static void expect(bool condition, const char* message) {
	if(!condition) {
		std::cerr << message << '\n';
		std::exit(EXIT_FAILURE);
	}
}

int main() {
	const auto live = GetSummonTiming(false, true);
	expect(live.reveal_frames == 30 && live.settle_frames == 11
		&& live.move_frames == 10,
		"live duel summon timing must remain stock");
	const auto replay = GetSummonTiming(true, true);
	expect(replay.reveal_frames == 15 && replay.settle_frames == 4
		&& replay.move_frames == 6,
		"3v1 replay summons must use the smooth timing");
	expect(DrawSoundCount(true, true, 6) == 1,
		"Card of Sanctity must play one visible batch draw sound");
	expect(DrawSoundCount(true, false, 6) == 0,
		"hidden teammate draws must not stack sounds");
	expect(DrawSoundCount(false, true, 6) == 6,
		"non-3v1 behavior must stay unchanged");
	std::cout << "Replay draw/summon animation policy tests passed.\n";
}
''', encoding='utf-8')

# Declare the incremental visible-hand update.
field_h = ROOT / 'gframe' / 'client_field.h'
replace_once(field_h,
'''\tvoid UpdateMultiplayerPrivateDraw(uint8_t logical_player,\n\t\tconst std::vector<MultiplayerPrivatePileCard>& drawn_cards);\n''',
'''\tvoid UpdateMultiplayerPrivateDraw(uint8_t logical_player,\n\t\tconst std::vector<MultiplayerPrivatePileCard>& drawn_cards);\n\tbool ApplyThreeVsOneReplayPrivateDraw(uint8_t logical_player,\n\t\tconst std::vector<MultiplayerPrivatePileCard>& drawn_cards);\n''')

# Add an in-place/batched draw projection. This preserves ClientCard objects,
# chain pointers and all other piles instead of rebuilding five piles per draw.
field_cpp = ROOT / 'gframe' / 'client_field.cpp'
text = field_cpp.read_text(encoding='utf-8')
marker = '''void ClientField::UpdateMultiplayerPrivateMove(uint8_t previous_logical,\n'''
pos = text.find(marker)
if pos < 0:
    raise SystemExit('client_field.cpp: missing UpdateMultiplayerPrivateMove')
method = r'''bool ClientField::ApplyThreeVsOneReplayPrivateDraw(uint8_t logical_player,
		const std::vector<MultiplayerPrivatePileCard>& drawn_cards) {
	if(!mainGame->dInfo.isReplay
			|| !mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
			|| logical_player >= multiplayer_private_piles.size()
			|| !multiplayer_private_piles_valid[logical_player]
			|| drawn_cards.empty()
			|| !IsThreeVsOneReplayHandDisplayed(logical_player))
		return false;
	const auto core_side = mainGame->dInfo.GetLogicalCoreSide(logical_player);
	const auto display_side = core_side < 2
		? mainGame->LocalPlayer(core_side) : static_cast<uint8_t>(0xff);
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
	// The visible prefix must still describe the pre-draw hand. If an older
	// replay omitted a needed snapshot, fall back to the full atomic reconcile.
	for(size_t i = 0; i < hand[display_side].size(); ++i) {
		const auto* pcard = hand[display_side][i];
		if(!pcard || pcard->code != snapshot.hand[i].code
				|| static_cast<uint8_t>(pcard->position) != snapshot.hand[i].position)
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
	// Animate the complete hand as one non-blocking batch. This replaces the
	// old full private-pile rebuild that caused a visible pause on every draw.
	for(auto* pcard : hand[display_side])
		if(pcard)
			MoveCard(pcard, 8);
	mainGame->should_refresh_hands = true;
	RefreshHandHitboxes();
	return true;
}
'''
text = text[:pos] + method + text[pos:]
field_cpp.write_text(text, encoding='utf-8')

# Duel-client integration.
duel = ROOT / 'gframe' / 'duelclient.cpp'
replace_once(duel,
'#include "multiplayer_attack_arrow.h"\n',
'#include "multiplayer_attack_arrow.h"\n#include "multiplayer_replay_animation.h"\n')

text = duel.read_text(encoding='utf-8')
start = text.find('\tcase MSG_DRAW: {')
end = text.find('\tcase MSG_MULTIPLAYER_PRIVATE_PILES: {', start)
if start < 0 or end < 0:
    raise SystemExit('duelclient.cpp: draw handler range not found')
new_draw_handlers = r'''	case MSG_DRAW: {
		const auto core_player = BufferIO::Read<uint8_t>(pbuf);
		const auto logical_player = mainGame->dInfo.GetLogicalPlayer(core_player);
		const auto private_display = GetActivePrivateDisplaySide(core_player);
		const auto player = private_display < 2
			? private_display : mainGame->LocalPlayer(core_player);
		const auto count = CompatRead<uint8_t, uint32_t>(pbuf);
		std::vector<MultiplayerPrivatePileCard> drawn_cards;
		drawn_cards.reserve(count);
		for(uint32_t i = 0; i < count; ++i) {
			auto code = BufferIO::Read<uint32_t>(pbuf);
			uint8_t position = POS_FACEDOWN_DEFENSE;
			if(!mainGame->dInfo.compat_mode)
				position = static_cast<uint8_t>(BufferIO::Read<uint32_t>(pbuf));
			else {
				position = code & 0x80000000 ? POS_FACEUP : POS_FACEDOWN;
				code &= 0x7fffffff;
			}
			drawn_cards.push_back({ code, position });
		}
		if(logical_player < 4) {
			auto& deck_count = mainGame->dInfo.logical_deck_count[logical_player];
			deck_count = deck_count > count ? deck_count - count : 0;
			mainGame->dInfo.logical_hand_count[logical_player] += count;
		}
		if(mainGame->dInfo.isReplay && mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)) {
			mainGame->dField.UpdateMultiplayerPrivateDraw(logical_player, drawn_cards);
			const bool displayed =
				mainGame->dField.IsThreeVsOneReplayHandDisplayed(logical_player);
			if(displayed
					&& !mainGame->dField.ApplyThreeVsOneReplayPrivateDraw(
						logical_player, drawn_cards))
				mainGame->dField.ApplyThreeVsOneReplayPrivatePiles();
			const auto sounds = multiplayer_replay_animation::DrawSoundCount(
				true, displayed, count);
			for(uint32_t i = 0; i < sounds; ++i)
				Play(SoundManager::SFX::DRAW);
			return true;
		}
		const bool hidden_battle_royale_pile =
			mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE) && private_display > 1;
		if(hidden_battle_royale_pile)
			return true;
		auto lock = LockIf();
		auto& deck = mainGame->dField.deck[player];
		while(deck.size() < count)
			mainGame->dField.AddCard(new ClientCard{}, player, LOCATION_DECK, 0);
		for(const auto& drawn : drawn_cards) {
			if(deck.empty())
				break;
			auto* pcard = deck.back();
			deck.pop_back();
			if(pcard->code != drawn.code)
				pcard->SetCode(drawn.code);
			pcard->position = drawn.position;
			mainGame->dField.AddCard(pcard, player, LOCATION_HAND, 0);
			Play(SoundManager::SFX::DRAW);
		}
		for(auto* hand_card : mainGame->dField.hand[player])
			if(hand_card)
				hand_card->UpdateDrawCoordinates(true);
		mainGame->should_refresh_hands = true;
		event_string = epro::sprintf(gDataManager->GetSysString(1611 + player), count);
		mainGame->dField.CaptureBattleRoyaleReplayPrivatePiles();
		return true;
	}
	case MSG_MULTIPLAYER_DRAW: {
		const auto logical_player = BufferIO::Read<uint8_t>(pbuf);
		const auto count = BufferIO::Read<uint32_t>(pbuf);
		std::vector<MultiplayerPrivatePileCard> drawn_cards;
		drawn_cards.reserve(count);
		for(uint32_t i = 0; i < count; ++i) {
			const auto code = BufferIO::Read<uint32_t>(pbuf);
			const auto position = static_cast<uint8_t>(BufferIO::Read<uint32_t>(pbuf));
			drawn_cards.push_back({ code, position });
		}
		if(logical_player < 4) {
			auto& deck_count = mainGame->dInfo.logical_deck_count[logical_player];
			deck_count = deck_count > count ? deck_count - count : 0;
			mainGame->dInfo.logical_hand_count[logical_player] += count;
		}
		uint32_t sounds = count;
		if(mainGame->dInfo.isReplay) {
			mainGame->dField.UpdateMultiplayerPrivateDraw(logical_player, drawn_cards);
			if(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)) {
				const bool displayed =
					mainGame->dField.IsThreeVsOneReplayHandDisplayed(logical_player);
				if(displayed
						&& !mainGame->dField.ApplyThreeVsOneReplayPrivateDraw(
							logical_player, drawn_cards))
					mainGame->dField.ApplyThreeVsOneReplayPrivatePiles();
				sounds = multiplayer_replay_animation::DrawSoundCount(
					true, displayed, count);
			} else if(mainGame->dInfo.GetBattleRoyaleDisplaySide(logical_player) < 2)
				mainGame->dField.ApplyBattleRoyaleReplayPrivatePiles();
		} else if(logical_player == mainGame->dInfo.GetLocalLogicalPlayer()) {
			auto lock = LockIf();
			const auto side = mainGame->LocalPlayer(mainGame->dInfo.GetLogicalCoreSide(logical_player));
			auto& deck = mainGame->dField.deck[side];
			for(const auto& drawn : drawn_cards) {
				if(deck.empty())
					break;
				auto* pcard = deck.back();
				deck.pop_back();
				if(pcard->code != drawn.code)
					pcard->SetCode(drawn.code);
				pcard->position = drawn.position;
				mainGame->dField.AddCard(pcard, side, LOCATION_HAND, 0);
			}
			mainGame->dField.RefreshAllCards();
		}
		for(uint32_t i = 0; i < sounds; ++i)
			Play(SoundManager::SFX::DRAW);
		return true;
	}
'''
text = text[:start] + new_draw_handlers + text[end:]
duel.write_text(text, encoding='utf-8')

# Shorten only the blocking 3v1 replay reveal waits; live duels remain stock.
def add_timing_and_replace(block: str, flip: bool = False) -> str:
    code_line = '\t\tconst auto code = BufferIO::Read<uint32_t>(pbuf);\n'
    if block.count(code_line) != 1:
        raise SystemExit('unexpected summon code line count')
    timing = (code_line
        + '\t\tconst auto summon_timing = multiplayer_replay_animation::GetSummonTiming(\n'
        + '\t\t\tmainGame->dInfo.isReplay, mainGame->dInfo.HasFieldFlag(DUEL_3_V_1));\n')
    block = block.replace(code_line, timing, 1)
    if 'mainGame->WaitFrameSignal(30, lock);' not in block:
        raise SystemExit('summon block lacks reveal wait')
    block = block.replace('mainGame->WaitFrameSignal(30, lock);',
        'mainGame->WaitFrameSignal(summon_timing.reveal_frames, lock);')
    if 'mainGame->WaitFrameSignal(11, lock);' not in block:
        raise SystemExit('summon block lacks settle wait')
    block = block.replace('mainGame->WaitFrameSignal(11, lock);',
        'mainGame->WaitFrameSignal(summon_timing.settle_frames, lock);')
    if flip:
        if 'mainGame->dField.MoveCard(pcard, 10);' not in block:
            raise SystemExit('flip summon block lacks move timing')
        block = block.replace('mainGame->dField.MoveCard(pcard, 10);',
            'mainGame->dField.MoveCard(pcard, summon_timing.move_frames);', 1)
    return block

replace_case(duel, '\tcase MSG_SUMMONING: {', '\tcase MSG_SUMMONED: {', add_timing_and_replace)
replace_case(duel, '\tcase MSG_SPSUMMONING: {', '\tcase MSG_SPSUMMONED: {', add_timing_and_replace)
replace_case(duel, '\tcase MSG_FLIPSUMMONING: {', '\tcase MSG_FLIPSUMMONED: {',
    lambda block: add_timing_and_replace(block, True))

print('Applied non-blocking 3v1 replay draw batching and smooth summon timing.')
