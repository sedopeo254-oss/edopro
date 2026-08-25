from __future__ import annotations

from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
V2_RUNNER = ROOT / ".github" / "scripts" / "run-3v1-replay-smooth-v2.py"
PATCH_DIR = ROOT / ".github" / "patches"
PATCHES = [
    PATCH_DIR / "3v1-replay-state-machine-v5-client.patch",
    PATCH_DIR / "3v1-replay-state-machine-v5-duelclient-1.patch",
    PATCH_DIR / "3v1-replay-state-machine-v5-duelclient-2.patch",
]
MARKER = "three_vs_one_replay_hand_mask"


def run(*args: str) -> None:
    subprocess.run(args, cwd=ROOT, check=True)


def main() -> None:
    game_h = ROOT / "gframe" / "game.h"
    if MARKER in game_h.read_text(encoding="utf-8"):
        print("3v1 replay event-state V5 is already applied")
        return
    if not V2_RUNNER.is_file():
        raise SystemExit(f"missing V2 runner: {V2_RUNNER}")
    missing = [str(path) for path in PATCHES if not path.is_file()]
    if missing:
        raise SystemExit("missing V5 patch files: " + ", ".join(missing))
    run(sys.executable, str(V2_RUNNER))
    for patch in PATCHES:
        run("git", "apply", "--check", str(patch))
        run("git", "apply", str(patch))
    if MARKER not in game_h.read_text(encoding="utf-8"):
        raise SystemExit("V5 marker was not installed")
    print("Applied 3v1 replay event-state V5 after Replay Smooth V2")


if __name__ == "__main__":
    main()
