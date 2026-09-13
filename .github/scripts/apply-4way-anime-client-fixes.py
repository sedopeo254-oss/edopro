from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def replace_once(path, old, new):
    p = ROOT / path
    text = p.read_text(encoding="utf-8")
    if new in text:
        return
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected one replacement site, found {count}")
    p.write_text(text.replace(old, new, 1), encoding="utf-8")


def replace_all(path, old, new, minimum=1):
    p = ROOT / path
    text = p.read_text(encoding="utf-8")
    if old not in text and new in text:
        return
    count = text.count(old)
    if count < minimum:
        raise SystemExit(f"{path}: expected at least {minimum} replacement sites, found {count}")
    p.write_text(text.replace(old, new), encoding="utf-8")


# Public API used by the duel button.
replace_once(
    "gframe/client_field.h",
    "\tvoid RefreshHandHitboxes();\n\tvoid CycleTeamField();\n",
    "\tvoid RefreshHandHitboxes();\n\tvoid CycleBattleRoyaleOpponent();\n\tvoid CycleTeamField();\n",
)

# Cycle only the opponent projected on the upper side. The local logical player
# remains pinned to display side 0 by DuelInfo::SetBattleRoyaleOpponent().
client_field = ROOT / "gframe/client_field.cpp"
text = client_field.read_text(encoding="utf-8")
method_name = "void ClientField::CycleBattleRoyaleOpponent() {"
if method_name not in text:
    marker = "bool ClientField::ReplaceMultiplayerPrivatePiles(uint8_t player,\n"
    if text.count(marker) != 1:
        raise SystemExit("client_field.cpp: ReplaceMultiplayerPrivatePiles marker mismatch")
    method = r'''void ClientField::CycleBattleRoyaleOpponent() {
	if(mainGame->dInfo.isReplay
			|| !mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))
		return;
	const auto player_count = static_cast<uint8_t>(
		mainGame->dInfo.team1 + mainGame->dInfo.team2);
	const auto local = mainGame->dInfo.GetLocalLogicalPlayer();
	if(player_count < 2 || local >= player_count)
		return;
	uint8_t current = mainGame->dInfo.battle_royale_opponent_logical;
	if(current >= player_count || current == local)
		current = local;
	uint8_t next = 0xff;
	for(uint8_t step = 1; step <= player_count; ++step) {
		const auto logical = static_cast<uint8_t>((current + step) % player_count);
		if(logical != local
				&& (mainGame->dInfo.active_player_mask & (1u << logical))) {
			next = logical;
			break;
		}
	}
	if(next >= player_count || !mainGame->dInfo.SetBattleRoyaleOpponent(next))
		return;
	// Never leave the previous opponent's private cards under the new name.
	// Normally the authoritative live snapshot already exists; placeholders are
	// only a safe fallback until that snapshot arrives.
	if(next < multiplayer_private_piles.size()
			&& !multiplayer_private_piles_valid[next]) {
		MultiplayerPrivatePileSnapshot snapshot;
		snapshot.deck_count = mainGame->dInfo.logical_deck_count[next];
		snapshot.hand.resize(mainGame->dInfo.logical_hand_count[next],
			{ 0, POS_FACEDOWN_DEFENSE });
		snapshot.extra.resize(mainGame->dInfo.logical_extra_count[next],
			{ 0, POS_FACEDOWN_DEFENSE });
		snapshot.grave.resize(mainGame->dInfo.logical_grave_count[next],
			{ 0, POS_FACEUP });
		snapshot.removed.resize(mainGame->dInfo.logical_banish_count[next],
			{ 0, POS_FACEUP });
		CacheMultiplayerPrivatePiles(next, snapshot);
	}
	hovered_card = nullptr;
	hovered_location = 0;
	hovered_sequence = 0;
	ApplyBattleRoyaleLivePrivatePile(next, false);
	RefreshAllCards();
}
'''
    client_field.write_text(text.replace(marker, method + marker, 1), encoding="utf-8")

# BUTTON_REPLAY_SWAP is already the small duel-side swap button. In live Battle
# Royale it becomes "Swap the player" and cycles only active opponents.
replace_once(
    "gframe/event_handler.cpp",
    "\t\t\t\telse if(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))\n\t\t\t\t\tmainGame->dField.CycleTeamField();\n",
    "\t\t\t\telse if(mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))\n\t\t\t\t\tmainGame->dField.CycleBattleRoyaleOpponent();\n\t\t\t\telse if(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))\n\t\t\t\t\tmainGame->dField.CycleTeamField();\n",
)

# Show the button to actual Battle Royale players without changing spectators,
# replays or 3v1 behavior.
replace_all(
    "gframe/duelclient.cpp",
    "mainGame->btnSpectatorSwap->setVisible(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1));",
    "mainGame->btnSpectatorSwap->setVisible(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE));",
    minimum=2,
)
replace_once(
    "gframe/duelclient.cpp",
    "\t\t\tif(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))\n\t\t\t\tmainGame->btnSpectatorSwap->setText(L\"Swap the Team\");\n",
    "\t\t\tif(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))\n\t\t\t\tmainGame->btnSpectatorSwap->setText(L\"Swap the Team\");\n\t\t\telse if(mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))\n\t\t\t\tmainGame->btnSpectatorSwap->setText(L\"Swap the player\");\n",
)

print("Applied live Battle Royale Swap the player client UI")
