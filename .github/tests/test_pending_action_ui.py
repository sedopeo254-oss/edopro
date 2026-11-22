#!/usr/bin/env python3
"""Prevent the Irrlicht focus-veto regression in the pre-commit action UI."""
from pathlib import Path

root = Path(__file__).resolve().parents[2]
events = (root / "gframe/event_handler.cpp").read_text(encoding="utf-8")
gui = (root / "gframe/game.cpp").read_text(encoding="utf-8")
client = (root / "gframe/duelclient.cpp").read_text(encoding="utf-8")
guard = events.split("bool ClientField::OnEvent(const irr::SEvent& event) {", 1)[1]
guard = guard.split("\tbool stopPropagation = false;", 1)[0]

# Irrlicht cancels a focus change when the receiver consumes these events.
assert "EGET_ELEMENT_FOCUSED" in guard
assert "EGET_ELEMENT_FOCUS_LOST" in guard
focus = guard.split("if(gui_type == irr::gui::EGET_ELEMENT_FOCUSED", 1)[1]
focus = focus.split("if(gui_type == irr::gui::EGET_BUTTON_CLICKED", 1)[0]
assert "return false;" in focus
assert "DuelClient::SendResponse(true);" in guard
assert "BUTTON_PENDING_ACTION_CANCEL" in guard
assert "BUTTON_LEAVE_GAME || id == BUTTON_RESTART_SINGLE" in guard
assert "irr::KEY_ESCAPE" in guard

# The previous tooltip covered the button captions in the duel scene.
assert "btnPendingActionConfirm->setToolTipText" not in gui
assert "btnPendingActionCancel->setToolTipText" not in gui

# No fake -1 for mandatory placement or position prompts.
assert "mainGame->dField.StagePendingAction(msg, response, kind);" in client
assert "SetResponseI(value);" in client
assert "pending_action.message == MSG_SELECT_CHAIN" in guard
print("Pending action focus, mouse and click routing: PASS")
