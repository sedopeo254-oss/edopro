#!/usr/bin/env python3
"""Merge the preserved real 2v1 mode with current Inherited/3v1/Battle Royale.
Only three obsolete gframe/game.cpp anchors are translated (mode index 4).
Any other missing legacy patch anchor is an error, never silently ignored.
"""
from pathlib import Path
import runpy

ROOT=Path(__file__).resolve().parents[2]
CORE_PATCH=ROOT/".github/scripts/apply-2v1-clean-core.py"
CLIENT_PATCH=ROOT/".github/scripts/apply-2v1-clean-client-server.py"
GAME=ROOT/"gframe/game.cpp"

def replace_one(content,old,new):
    n=content.count(old)
    if n!=1:
        raise RuntimeError(f"Expected exactly one host anchor ({n}): {old[:90]!r}")
    return content.replace(old,new,1)

for file in (CORE_PATCH,CLIENT_PATCH):
    src=file.read_text(encoding="utf-8")
    old="DUEL_2_V_1             0x8000000000ULL"
    assert src.count(old)==1,(file,"legacy 2v1 flag missing")
    file.write_text(src.replace(old,"DUEL_2_V_1             0x10000000000ULL"),
        encoding="utf-8")

runpy.run_path(str(CORE_PATCH),run_name="__main__")

src=GAME.read_text(encoding="utf-8")
src=replace_one(src,
    'cbMultiplayerMode->addItem(L"Inherited Duel Mode");',
    'cbMultiplayerMode->addItem(L"Inherited Duel Mode");\n'
    '\t\tcbMultiplayerMode->addItem(L"2 vs 1");')
src=replace_one(src,
    'cbMultiplayerMode->setSelected((duel_param & DUEL_INHERITED_DUEL) ? 3',
    'cbMultiplayerMode->setSelected((duel_param & DUEL_2_V_1) ? 4\n'
    '\t\t\t: (duel_param & DUEL_INHERITED_DUEL) ? 3')
src=replace_one(src,
    'duel_param & (DUEL_BATTLE_ROYALE | DUEL_3_V_1 | DUEL_INHERITED_DUEL);',
    'duel_param & (DUEL_BATTLE_ROYALE | DUEL_3_V_1 | DUEL_INHERITED_DUEL | DUEL_2_V_1);')
src=replace_one(src,
    'duel_param &= ~(DUEL_BATTLE_ROYALE | DUEL_3_V_1 | DUEL_INHERITED_DUEL);',
    'duel_param &= ~(DUEL_BATTLE_ROYALE | DUEL_3_V_1 | DUEL_INHERITED_DUEL | DUEL_2_V_1);')
src=replace_one(src,
    'if(mode == 1) {\n\t\tduel_param |= DUEL_BATTLE_ROYALE;',
    'if(mode == 4) {\n'
    '\t\tduel_param |= DUEL_2_V_1;\n'
    '\t\tebTeam1->setText(L"2");\n'
    '\t\tebTeam2->setText(L"1");\n'
    '\t} else if(mode == 1) {\n'
    '\t\tduel_param |= DUEL_BATTLE_ROYALE;')
GAME.write_text(src,encoding="utf-8")

src=CLIENT_PATCH.read_text(encoding="utf-8")
needle="def replace_once(path, old, new):"
assert src.count(needle)==1
src=src.replace(needle,"__unified_misses=[]\n"+needle,1)
old='raise SystemExit(f"{path}: expected one replacement site, found {count}")'
new='__unified_misses.append((path,old[:96],count)); return'
assert src.count(old)==1
src=src.replace(old,new,1)
CLIENT_PATCH.write_text(src,encoding="utf-8")
result=runpy.run_path(str(CLIENT_PATCH),run_name="__main__")
misses=result["__unified_misses"]
if len(misses)!=3 or any(path!="gframe/game.cpp" for path,_,_ in misses):
    raise RuntimeError(f"Unexpected 2v1 integration conflicts: {misses!r}")

for file in (ROOT/"gframe/ocgapi_constants.h",
             ROOT/"ocgcore/ocgapi_constants.h"):
    flags=file.read_text(encoding="utf-8")
    for marker in ("DUEL_BATTLE_ROYALE","DUEL_3_V_1","DUEL_INHERITED_DUEL",
                   "DUEL_2_V_1"):
        assert f"#define {marker}" in flags,(file,marker)
    assert "#define DUEL_2_V_1             0x10000000000ULL" in flags
host=GAME.read_text(encoding="utf-8")
for marker in ('addItem(L"2 vs 1")','addItem(L"Inherited Duel Mode")',
               'if(mode == 4) {','DUEL_2_V_1','DUEL_INHERITED_DUEL'):
    assert marker in host,marker
print("Real unified 2v1 / 3v1 / Battle Royale / Inherited Duel sources: PASS")
