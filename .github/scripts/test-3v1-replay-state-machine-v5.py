from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


@dataclass
class ReplayState:
    turn: int = 2
    focus: int = 2
    active_mask: int = 0x0F
    hand_mask: int = 1 << 2
    loaded: int | None = 2
    pending: int | None = None
    cache: set[int] = field(default_factory=lambda: {0, 1, 2, 3})
    private_apply_count: int = 0
    view_hint_count: int = 0
    deck_master_code: dict[int, int] = field(default_factory=dict)
    deck_master_visible: dict[int, bool] = field(default_factory=dict)

    def set_focus(self, logical: int) -> None:
        # 3v1 keeps the currently projected ally during P4's turn unless an
        # authoritative event explicitly names P1/P2/P3.
        ally = logical if 0 <= logical < 3 else self.focus
        if not 0 <= ally < 3:
            ally = 0
        if ally == self.focus and self.loaded == ally:
            return
        self.focus = ally
        self.pending = ally
        if ally in self.cache:
            self.loaded = ally
            self.pending = None
            self.private_apply_count += 1
        else:
            self.loaded = None

    def new_turn(self, logical: int) -> None:
        self.turn = logical
        self.hand_mask = (1 << logical) & self.active_mask
        self.set_focus(logical)

    def replay_view_hint(self, perspective: int, opponent: int) -> None:
        # V5 intentionally treats these duplicated hints as cache prefetch only.
        self.view_hint_count += 1

    def attack(self, attacker: int, target: int) -> None:
        self.hand_mask = ((1 << attacker) | (1 << target)) & self.active_mask
        self.set_focus(target if target < 3 else attacker)

    def target(self, logical: int) -> None:
        self.hand_mask = ((1 << self.turn) | (1 << logical)) & self.active_mask
        self.set_focus(logical)

    def chain_from(self, logical: int) -> None:
        # Field follows the real activating card; the full hand remains hidden.
        self.set_focus(logical)

    def restore_turn_presentation(self) -> None:
        self.hand_mask = (1 << self.turn) & self.active_mask
        self.set_focus(self.turn)

    def private_snapshot(self, logical: int) -> None:
        self.cache.add(logical)
        if self.pending == logical and self.focus == logical:
            self.loaded = logical
            self.pending = None
            self.private_apply_count += 1

    def deck_master(self, logical: int, visible: bool, code: int) -> None:
        if code:
            self.deck_master_code[logical] = code
        self.deck_master_visible[logical] = visible
        if not visible:
            self.set_focus(logical)


def require(path: str, needle: str) -> None:
    text = (ROOT / path).read_text(encoding="utf-8")
    if needle not in text:
        raise AssertionError(f"{path}: missing {needle!r}")


def forbid(path: str, needle: str) -> None:
    text = (ROOT / path).read_text(encoding="utf-8")
    if needle in text:
        raise AssertionError(f"{path}: forbidden {needle!r}")


def test_state_machine() -> None:
    s = ReplayState()
    s.new_turn(3)
    assert s.hand_mask == 1 << 3
    assert s.focus == 2  # P3 field remains projected, but P3 hand is hidden.

    before = s.private_apply_count
    for _ in range(3):
        s.replay_view_hint(3, 2)
        s.private_snapshot(2)
    assert s.focus == 2
    assert s.hand_mask == 1 << 3
    assert s.private_apply_count == before

    s.attack(3, 1)
    assert s.focus == 1
    assert s.hand_mask == (1 << 3) | (1 << 1)
    attack_apply_count = s.private_apply_count
    for _ in range(3):
        s.replay_view_hint(3, 1)
        s.private_snapshot(1)
    assert s.private_apply_count == attack_apply_count

    s.restore_turn_presentation()
    assert s.focus == 1
    assert s.hand_mask == 1 << 3

    s.target(0)
    assert s.focus == 0
    assert s.hand_mask == (1 << 3) | 1
    s.chain_from(2)
    assert s.focus == 2
    assert s.hand_mask == (1 << 3) | 1  # chain focus does not reveal P3's hand
    s.restore_turn_presentation()
    assert s.hand_mask == 1 << 3

    s.deck_master(1, True, 153000012)
    s.deck_master(1, False, 153000012)
    assert s.deck_master_code[1] == 153000012
    assert not s.deck_master_visible[1]
    assert s.focus == 1


def test_source_contract() -> None:
    require("gframe/game.h", "three_vs_one_replay_hand_mask")
    require("gframe/game.h", "logical_deck_master_visible")
    require("gframe/client_field.cpp", "RefreshThreeVsOneReplayField")
    require("gframe/client_field.cpp", "RefreshMultiplayerPrivatePile")
    require("gframe/client_field.cpp", "pile[i]->location == LOCATION_GRAVE")
    require("gframe/client_field.cpp", "pcard->draw_scale = 0.0f")
    require("gframe/duelclient.cpp", "3v1 replay view packets are advisory")
    require("gframe/duelclient.cpp", "ApplyThreeVsOneReplayPrivatePile(logical_player)")
    require("gframe/duelclient.cpp", "Damage alone must not change the 3v1 replay hand/camera")
    require("gframe/duelclient.cpp", "Consume TAG_SWAP as authoritative logical/private state")
    require("gframe/duelclient.cpp", "pcard->SetCode(code)")
    require("gframe/duelclient.cpp", "pcard->is_public = true")
    forbid("multiplayer-deck-master/c153000012.lua", "Duel.FocusLogicalPlayer")
    forbid("multiplayer-deck-master/c153000012.lua", "Duel.TagSwap(")


if __name__ == "__main__":
    test_state_machine()
    test_source_contract()
    print("3v1 replay event-state V5 regressions passed")
