from pathlib import Path

path = Path('.github/scripts/apply-4way-live-ec2d962-restoration.py')
text = path.read_text(encoding='utf-8')

old_outgoing = '''\t\t\tif(outgoing < 4
\t\t\t\t\t&& !(mainGame->dInfo.isReplay
\t\t\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))) {
'''
current_outgoing = '''\t\t\tif(outgoing < 4
\t\t\t\t\t&& !(mainGame->dInfo.isReplay
\t\t\t\t\t\t&& (mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
\t\t\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)))) {
'''
if text.count(old_outgoing) != 1:
    raise SystemExit(f'outgoing anchor count: {text.count(old_outgoing)}')
text = text.replace(old_outgoing, current_outgoing, 1)

old_refresh = '''\t\tif((mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))
\t\t\t\t&& active_seat_changed
\t\t\t\t&& !(mainGame->dInfo.isReplay
\t\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)))
\t\t\tmainGame->dField.RefreshAllCards();
'''
current_refresh = '''\t\tif((mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))
\t\t\t\t&& active_seat_changed
\t\t\t\t&& battle_royale_replay_smoothing::NeedsSecondTurnRefresh(
\t\t\t\t\tmainGame->dInfo.isReplay,
\t\t\t\t\tmainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))
\t\t\t\t&& !(mainGame->dInfo.isReplay
\t\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)))
\t\t\tmainGame->dField.RefreshAllCards();
'''
if text.count(old_refresh) != 1:
    raise SystemExit(f'refresh anchor count: {text.count(old_refresh)}')
text = text.replace(old_refresh, current_refresh, 1)

path.write_text(text, encoding='utf-8')
print('Adjusted patch anchors for the replay-smoothed work branch.')
