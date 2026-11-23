#!/usr/bin/env python3
"""Regression guard for EDOPro's one-click, cancellable automatic commit."""
from pathlib import Path

root = Path(__file__).resolve().parents[2]
events = (root / "gframe/event_handler.cpp").read_text(encoding="utf-8")
gui = (root / "gframe/game.cpp").read_text(encoding="utf-8")
field = (root / "gframe/client_field.cpp").read_text(encoding="utf-8")
client = (root / "gframe/duelclient.cpp").read_text(encoding="utf-8")
state = (root / "gframe/pending_action_confirm.h").read_text(encoding="utf-8")

guard = events.split("bool ClientField::OnEvent(const irr::SEvent& event) {", 1)[1]
guard = guard.split("\tbool stopPropagation = false;", 1)[0]
focus = guard.split("if(gui_type == irr::gui::EGET_ELEMENT_FOCUSED", 1)[1]
focus = focus.split("if(gui_type == irr::gui::EGET_BUTTON_CLICKED", 1)[0]
assert "return false;" in focus  # Never veto Irrlicht focus changes
assert "EGET_ELEMENT_FOCUS_LOST" in guard
assert "EGET_ELEMENT_HOVERED" in guard
assert "EGET_ELEMENT_LEFT" in guard
assert "BUTTON_PENDING_ACTION_CANCEL" in guard
assert "irr::KEY_ESCAPE" in guard
assert "BUTTON_LEAVE_GAME || id == BUTTON_RESTART_SINGLE" in guard
assert "BUTTON_PENDING_ACTION_CONFIRM" not in guard
assert "btnPendingActionConfirm" not in gui
assert "btnPendingActionConfirm" not in field
assert "btnPendingActionCancel->setToolTipText" not in gui
assert 'L"Cancel (Esc)"' in gui
assert "pending_action.hovering_cancel = true;" in guard
assert "pending_action.hovering_cancel = false;" in guard

# Main-loop auto-commit runs outside of the rendering mutex; it must
# reuse the existing confirmed response path and never synthesize cancellation.
assert "dField.pending_action.ShouldAutoCommit()" in gui
assert "DuelClient::SendResponse(true);" in gui
assert gui.index("gMutex.unlock();") < gui.index("dField.pending_action.ShouldAutoCommit()")
assert "mainGame->dField.StagePendingAction(msg, response, kind);" in client
assert "SetResponseI(value);" in client
assert "pending_action.message == MSG_SELECT_CHAIN" in guard
assert "DelayFor(PendingActionKind action)" in state
assert "std::chrono::milliseconds{300}" in state
assert "std::chrono::milliseconds{500}" in state
print("Quick Cancel auto-commit UI regression checks: PASS")
