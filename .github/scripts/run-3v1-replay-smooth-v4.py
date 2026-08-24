from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[2]
V3 = ROOT / ".github" / "scripts" / "run-3v1-replay-smooth-v3.py"
runpy.run_path(str(V3), run_name="__main__")

duelclient = ROOT / "gframe" / "duelclient.cpp"
text = duelclient.read_text(encoding="utf-8")

# Camera changes in 3v1 must never call RefreshAllCards(), because that also
# sets should_refresh_hands=true and visibly re-lays out the hand. Refresh only
# field/skill/overlay/chain objects whose coordinates depend on field_focus.
anchor = "\tauto SetThreeVsOneView = [&](uint8_t perspective,\n"
if text.count(anchor) != 1:
    raise SystemExit(f"{duelclient}: expected one SetThreeVsOneView anchor, found {text.count(anchor)}")
field_only = '''\tauto RefreshThreeVsOneFieldOnly = [&] {
\t\tmainGame->dField.RefreshLogicalDeckMasters();
\t\tauto refresh = [](ClientCard* pcard) {
\t\t\tif(!pcard)
\t\t\t\treturn;
\t\t\tpcard->UpdateDrawCoordinates(true);
\t\t\tpcard->is_moving = false;
\t\t\tpcard->refresh_on_stop = false;
\t\t\tpcard->aniFrame = 0;
\t\t};
\t\tfor(int p = 0; p < 2; ++p) {
\t\t\tfor(auto* pcard : mainGame->dField.mzone[p]) refresh(pcard);
\t\t\tfor(auto* pcard : mainGame->dField.szone[p]) refresh(pcard);
\t\t\trefresh(mainGame->dField.skills[p]);
\t\t}
\t\tfor(auto* pcard : mainGame->dField.overlay_cards) refresh(pcard);
\t\tfor(auto& chain : mainGame->dField.chains)
\t\t\tchain.UpdateDrawCoordinates();
\t};

'''
text = text.replace(anchor, field_only + anchor, 1)

start = text.find("\tauto SetThreeVsOneView = [&](uint8_t perspective,")
end = text.find("\tconst auto* pbuf = msg;", start)
if start < 0 or end < 0:
    raise SystemExit("SetThreeVsOneView scope not found after V3")
block = text[start:end]
needle = "\t\tmainGame->dField.RefreshAllCards();\n\t\treturn true;\n"
if block.count(needle) != 1:
    raise SystemExit(f"expected one full refresh in SetThreeVsOneView, found {block.count(needle)}")
block = block.replace(needle, "\t\tRefreshThreeVsOneFieldOnly();\n\t\treturn true;\n", 1)
text = text[:start] + block + text[end:]

# MSG_ATTACK historically forced a second full refresh to stabilize the arrow.
# Keep the stabilization, but field-only so the allied hand never jitters.
start = text.find("\tcase MSG_ATTACK: {")
end = text.find("\tcase MSG_BATTLE: {", start)
if start < 0 or end < 0:
    raise SystemExit("MSG_ATTACK scope not found")
block = text[start:end]
old_attack_refresh = '''\t\t\tSetThreeVsOneView(attacker_logical, attack_target_logical);
\t\t\t// A replay-view packet may already have selected the same logical pair,
\t\t\t// but the previous card transform can remain for one frame. Refreshing
\t\t\t// here keeps the final arrow attached to the authoritative fields.
\t\t\tmainGame->dField.RefreshAllCards();
'''
new_attack_refresh = '''\t\t\tSetThreeVsOneView(attacker_logical, attack_target_logical);
\t\t\t// Stabilize only the field coordinates for the final arrow. Do not
\t\t\t// refresh/re-layout Hand/Deck/Extra during an opponent attack.
\t\t\tRefreshThreeVsOneFieldOnly();
'''
if block.count(old_attack_refresh) != 1:
    raise SystemExit(f"expected one 3v1 attack refresh site, found {block.count(old_attack_refresh)}")
block = block.replace(old_attack_refresh, new_attack_refresh, 1)
text = text[:start] + block + text[end:]

duelclient.write_text(text, encoding="utf-8")
print("Applied 3v1 replay V4: field-camera refresh cannot re-layout or mutate private hands")
