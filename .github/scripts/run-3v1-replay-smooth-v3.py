from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[2]
V2 = ROOT / ".github" / "scripts" / "run-3v1-replay-smooth-v2.py"

# First apply every proven V2 correction (logical draws, Deck Master owner lock,
# public summon images, shorter replay summon waits, target visibility).
runpy.run_path(str(V2), run_name="__main__")


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected exactly one V3 patch site, found {count}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


def replace_in_function(path: Path, signature: str, next_signature: str, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    start = text.find(signature)
    end = text.find(next_signature, start + len(signature))
    if start < 0 or end < 0:
        raise SystemExit(f"{path}: function scope not found for {signature}")
    block = text[start:end]
    count = block.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected one scoped V3 site in {signature}, found {count}")
    block = block.replace(old, new, 1)
    path.write_text(text[:start] + block + text[end:], encoding="utf-8")


# ---------------------------------------------------------------------------
# V3 architecture: field camera and private-pile projection are independent.
# field_focus = which MZONE/SZONE field replay wants to show for attacks/targets.
# logical_active = whose Deck/Hand/Extra/GY/Banish is actually mounted on that
# physical side. The hand must NEVER follow a transient attack/target camera.
# ---------------------------------------------------------------------------
field = ROOT / "gframe" / "client_field.cpp"

replace_in_function(
    field,
    "void ClientField::CaptureThreeVsOneReplayPrivatePiles() {",
    "bool ClientField::IsThreeVsOneReplayPrivatePileDisplayed(",
    "const auto logical = mainGame->dInfo.GetFocusedLogicalPlayer(core_side);",
    "const auto logical = mainGame->dInfo.GetLogicalPlayer(core_side);"
)

old_displayed = '''\tfor(uint8_t core_side = 0; core_side < 2; ++core_side) {
\t\tif(mainGame->dInfo.GetFocusedLogicalPlayer(core_side) == logical_player)
\t\t\treturn true;
\t}
'''
new_displayed = '''\tfor(uint8_t core_side = 0; core_side < 2; ++core_side) {
\t\t// Private piles follow the side's active logical duelist, not the field
\t\t// camera. This keeps the allied hand pinned during Nezbitt's turn even
\t\t// while replay temporarily shows P1/P2/P3 attack/target fields.
\t\tif(mainGame->dInfo.GetLogicalPlayer(core_side) == logical_player)
\t\t\treturn true;
\t}
'''
replace_in_function(
    field,
    "bool ClientField::IsThreeVsOneReplayPrivatePileDisplayed(",
    "void ClientField::ApplyThreeVsOneReplayPrivatePiles() {",
    old_displayed,
    new_displayed
)

replace_in_function(
    field,
    "void ClientField::ApplyThreeVsOneReplayPrivatePiles() {",
    "void ClientField::UpdateMultiplayerPrivateDraw(",
    "const auto logical = mainGame->dInfo.GetFocusedLogicalPlayer(core_side);",
    "const auto logical = mainGame->dInfo.GetLogicalPlayer(core_side);"
)


duelclient = ROOT / "gframe" / "duelclient.cpp"

# Private-pile MOVE visibility must use the mounted private duelist, not the
# current field camera. Otherwise P2's grave/hand disappears as soon as camera
# moves to P1/P3 and Super Roboyarou can become a hidden placeholder again.
old_inactive = '''\t\t\tif(mainGame->dInfo.isReplay
\t\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))
\t\t\t\treturn info.duelist != mainGame->dInfo.field_focus[core_player];
'''
new_inactive = '''\t\t\tif(mainGame->dInfo.isReplay
\t\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))
\t\t\t\treturn info.duelist
\t\t\t\t\t!= mainGame->dInfo.GetDisplayedPrivateDuelist(core_player);
'''
replace_once(duelclient, old_inactive, new_inactive)

# V2 still re-applied/captured private piles whenever SetThreeVsOneView moved
# the battlefield camera. V3 makes this function field-only.
old_view = '''\t\tconst auto allied_duelist = mainGame->dInfo.GetLogicalDuelist(allied_logical);
\t\tconst bool changed = mainGame->dInfo.field_focus[0] != allied_duelist
\t\t\t|| mainGame->dInfo.field_focus[1] != 0;
\t\tif(!changed)
\t\t\treturn false;
\t\tif(mainGame->dInfo.isReplay)
\t\t\tmainGame->dField.CaptureThreeVsOneReplayPrivatePiles();
\t\tmainGame->dInfo.SetFieldFocus(0, allied_duelist);
\t\tmainGame->dInfo.SetFieldFocus(1, 0);
\t\tif(mainGame->dInfo.isReplay)
\t\t\tmainGame->dField.ApplyThreeVsOneReplayPrivatePiles();
\t\tmainGame->dField.RefreshAllCards();
\t\treturn true;
'''
new_view = '''\t\tconst auto allied_duelist = mainGame->dInfo.GetLogicalDuelist(allied_logical);
\t\tconst bool changed = mainGame->dInfo.field_focus[0] != allied_duelist
\t\t\t|| mainGame->dInfo.field_focus[1] != 0;
\t\tif(!changed)
\t\t\treturn false;
\t\t// FIELD CAMERA ONLY. Never rebuild/capture Hand/Deck/Extra/GY/Banish
\t\t// here. Those are projected from logical_active and change only when the
\t\t// actual private-seat owner changes (turn/tag transition).
\t\tmainGame->dInfo.SetFieldFocus(0, allied_duelist);
\t\tmainGame->dInfo.SetFieldFocus(1, 0);
\t\tmainGame->dField.RefreshAllCards();
\t\treturn true;
'''
replace_once(duelclient, old_view, new_view)

# When the actual logical seat changes at MSG_MULTIPLAYER_NEW_TURN, that is the
# correct moment to project a different hand. Do it once, after logical_active
# is updated, rather than on every replay camera hint.
old_active = '''\t\t\tmainGame->dInfo.logical_active[field_side] = logical_player;
\t\t}
\t\tif(logical_player < mainGame->dInfo.team1) {
'''
new_active = '''\t\t\tmainGame->dInfo.logical_active[field_side] = logical_player;
\t\t\tif(mainGame->dInfo.isReplay
\t\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
\t\t\t\t\t&& active_seat_changed) {
\t\t\t\t// One deterministic private-pile transition per real logical seat
\t\t\t\t// change. Camera-only P1/P2/P3 view changes never reach this path.
\t\t\t\tmainGame->dField.ApplyThreeVsOneReplayPrivatePiles();
\t\t\t}
\t\t}
\t\tif(logical_player < mainGame->dInfo.team1) {
'''
replace_once(duelclient, old_active, new_active)

# Normal MSG_DRAW in V2 correctly updates the logical cache, but the displayed
# test/helper must now be based on logical_active (the ClientField method above
# was changed accordingly). No field-camera hand mutation remains.

# Special Summon: focus the FIELD camera to the Summoned card's logical field
# before binding its public code. This makes an off-camera Deck Master visible
# immediately while keeping private piles pinned to logical_active.
old_sp_bind = '''\t\tCoreUtils::loc_info info = CoreUtils::ReadLocInfo(pbuf, mainGame->dInfo.compat_mode);
\t\tif(MapLocationDisplay(info)) {
'''
new_sp_bind = '''\t\tCoreUtils::loc_info info = CoreUtils::ReadLocInfo(pbuf, mainGame->dInfo.compat_mode);
\t\tif(mainGame->dInfo.isReplay
\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
\t\t\t\t&& info.controler < 2
\t\t\t\t&& (info.location & LOCATION_ONFIELD)) {
\t\t\tconst auto summon_logical = mainGame->dInfo.GetLogicalPlayer(
\t\t\t\tinfo.controler, info.duelist);
\t\t\tif(summon_logical < mainGame->dInfo.team1 + mainGame->dInfo.team2)
\t\t\t\tSetThreeVsOneView(summon_logical);
\t\t}
\t\tif(MapLocationDisplay(info)) {
'''
# Scope to MSG_SPSUMMONING because similar loc-info patterns exist elsewhere.
text = duelclient.read_text(encoding="utf-8")
start = text.find("\tcase MSG_SPSUMMONING: {")
end = text.find("\tcase MSG_SPSUMMONED:", start)
if start < 0 or end < 0:
    raise SystemExit("MSG_SPSUMMONING scope not found")
block = text[start:end]
if block.count(old_sp_bind) != 1:
    raise SystemExit(f"expected one V3 special-summon bind site, found {block.count(old_sp_bind)}")
block = block.replace(old_sp_bind, new_sp_bind, 1)
duelclient.write_text(text[:start] + block + text[end:], encoding="utf-8")

print("Applied 3v1 replay V3: field camera decoupled from logical private piles; Card of Sanctity routed per player")
