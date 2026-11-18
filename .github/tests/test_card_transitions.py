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
# Hidden allied fields must continue updating their animation clocks.
card_render = drawing.split("void Game::DrawCard(ClientCard* pcard) {",1)[1]
assert card_render.index("if(pcard->aniFrame > 0)") < card_render.index("if(pcard->draw_scale <= 0.0f)")
# The activation mask uses the same opacity as the card, avoiding a mask flash.
assert drawing.count("driver->draw2DImage(imageManager.tMask,") == 2
assert drawing.count("0, matManager.c2d, true);") >= 4
assert "820.0f : 540.0f" in drawing
# The activation effect now finishes inside the 12-frame Quick animation
# wait instead of flashing immediately and lingering under the next packet.
assert drawing.count("2200.0f : 900.0f") == 2
assert "opening*255.f" in drawing and "closing*255.f" in drawing
assert "y *= card_motion::OverlayOpacity(showcardp,12.f);" in drawing
assert "return is_replay && is_three_vs_one ? 14 : 12;" in replay
assert "SummonTiming{ 12, 4, 8 }" in replay
assert client.count("gGameConfig->quick_animation);") >= 3
chain=client.split("case MSG_CHAINING: {",1)[1].split("case MSG_CHAINED:",1)[0]
assert "const auto activation_frames = gGameConfig->quick_animation ? 12 : 30;" in chain
assert chain.count("WaitFrameSignal(activation_frames, lock);") == 2
flip=client.split("case MSG_FLIPSUMMONING: {",1)[1].split("case MSG_FLIPSUMMONED:",1)[0]
assert flip.index("auto lock = LockIf();") < flip.index("pcard->SetCode(code);")
assert client.count("WaitFrameSignal(gGameConfig->quick_animation ? 12 : 30, lock);") >= 2
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
