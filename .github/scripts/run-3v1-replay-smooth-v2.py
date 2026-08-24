from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[2]
PATCH = ROOT / ".github" / "scripts" / "apply-3v1-replay-smooth-v2.py"

text = PATCH.read_text(encoding="utf-8")
needle = "replace_once(duelclient, old_normal_wait, new_normal_wait)"
replacement = '''# Scope this replacement to MSG_SUMMONING only. The same wait tail also exists
# in MSG_FLIPSUMMONING, and changing the first arbitrary occurrence would be
# fragile and could modify the wrong presentation path.
_duel_text = duelclient.read_text(encoding="utf-8")
_case_start = _duel_text.find("\\tcase MSG_SUMMONING: {")
_case_end = _duel_text.find("\\tcase MSG_SUMMONED:", _case_start)
if _case_start < 0 or _case_end < 0:
    raise SystemExit(f"{duelclient}: MSG_SUMMONING case not found")
_case_block = _duel_text[_case_start:_case_end]
if _case_block.count(old_normal_wait) != 1:
    raise SystemExit(f"{duelclient}: expected one normal-summon wait site, found {_case_block.count(old_normal_wait)}")
_case_block = _case_block.replace(old_normal_wait, new_normal_wait, 1)
duelclient.write_text(_duel_text[:_case_start] + _case_block + _duel_text[_case_end:], encoding="utf-8")'''

if text.count(needle) != 1:
    raise SystemExit(f"{PATCH}: expected one normal-wait patch call, found {text.count(needle)}")
PATCH.write_text(text.replace(needle, replacement, 1), encoding="utf-8")
runpy.run_path(str(PATCH), run_name="__main__")
