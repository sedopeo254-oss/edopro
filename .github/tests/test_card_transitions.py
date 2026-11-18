from pathlib import Path

root=Path(__file__).resolve().parents[2]
client=(root/"gframe/duelclient.cpp").read_text(encoding="utf-8")
drawing=(root/"gframe/drawing.cpp").read_text(encoding="utf-8")
field=(root/"gframe/client_field.cpp").read_text(encoding="utf-8")
card=(root/"gframe/client_card.h").read_text(encoding="utf-8")
replay=(root/"gframe/multiplayer_replay_animation.h").read_text(encoding="utf-8")
assert "motion_start_pos" in card and "motion_duration_ms" in card
assert "pcard->motion_start_pos = pcard->curPos;" in field
assert "pcard->motion_delta_pos = trans - pcard->motion_start_pos;" in field
assert "card_motion::MotionProgress(" in drawing
assert "pcard->smooth_move = false;" in drawing
assert "card_motion::OverlayOpacity(" in drawing
assert "return is_replay && is_three_vs_one ? 14 : 12;" in replay
summon=client.split("case MSG_SPSUMMONING: {",1)[1].split("case MSG_SPSUMMONED: {",1)[0]
assert "if(mainGame->dInfo.isCatchingUp)" in summon
assert "else if(!pcard->is_moving)" in summon
assert "mainGame->showcardp = 0;" in summon
draw=client.split("case MSG_DRAW: {",1)[1].split("case MSG_MULTIPLAYER_DRAW: {",1)[0]
assert "mainGame->dField.MoveCard(hand_card" in draw
assert "mainGame->dField.RefreshHandHitboxes();" in draw
private=client.split("case MSG_MULTIPLAYER_DRAW: {",1)[1].split("case MSG_MULTIPLAYER_PRIVATE_PILES: {",1)[0]
assert "mainGame->dField.MoveCard(hand_card" in private
assert "mainGame->dField.RefreshAllCards();" not in private
for name in ("MSG_SET","MSG_SUMMONING","MSG_FLIPSUMMONING","MSG_CHAINING",
             "MSG_DRAW","MSG_MULTIPLAYER_DRAW","MSG_MOVE","MSG_SPSUMMONING"):
    assert f"case {name}:" in client,name
assert client.count("->smooth_move = false;") >= 12
print("Card animation event coverage and multiplayer ownership guards: PASS")
