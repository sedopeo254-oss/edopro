from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GAME_CPP = ROOT / "gframe" / "game.cpp"

text = GAME_CPP.read_text(encoding="utf-8")
old = (
    '\t} else if(mode == 3) {\n'
    '\t\tduel_param |= DUEL_2_V_1_BIG5;\n'
    '\t\tebTeam1->setText(L"2");\n'
    '\t\tebTeam2->setText(L"1");\n'
    '\t\tebStartLP->setText(L"4000");\n'
    '\t}\n'
)
new = (
    '\t} else if(mode == 3) {\n'
    '\t\tduel_param |= DUEL_2_V_1_BIG5;\n'
    '\t\tebTeam1->setText(L"2");\n'
    '\t\tebTeam2->setText(L"1");\n'
    '\t}\n'
)

# The crash dump EIP maps to the virtual call through ebStartLP while
# UpdateMultiplayerMode() is being invoked during host-UI construction.
# At that time ebStartLP can still be nullptr. Starting LP is already set
# safely in GenericDuel::TPResult(): 4000 for Joey/Yugi, 8000 for Big Five.
if old in text:
    text = text.replace(old, new, 1)
elif new not in text:
    raise SystemExit("gframe/game.cpp: could not locate the 2v1 mode-3 block")

# Regression guard: UpdateMultiplayerMode must never touch Start LP widgets.
start = text.find("void Game::UpdateMultiplayerMode()")
end = text.find("\n}", start)
if start < 0 or end < 0:
    raise SystemExit("gframe/game.cpp: could not isolate UpdateMultiplayerMode")
block = text[start:end + 2]
if "ebStartLP" in block:
    raise SystemExit("gframe/game.cpp: unsafe ebStartLP access remains in UpdateMultiplayerMode")
if 'duel_param |= DUEL_2_V_1_BIG5;' not in block:
    raise SystemExit("gframe/game.cpp: 2v1 mode flag missing after crash fix")
if 'ebTeam1->setText(L"2");' not in block or 'ebTeam2->setText(L"1");' not in block:
    raise SystemExit("gframe/game.cpp: 2v1 seat topology changed unexpectedly")

GAME_CPP.write_text(text, encoding="utf-8")
print("Removed crash-causing Start LP GUI dereference from 2v1 mode selection")
