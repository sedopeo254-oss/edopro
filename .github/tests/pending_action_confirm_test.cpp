#include "gframe/pending_action_confirm.h"
#include <cstdlib>
#include <iostream>
#include <initializer_list>
#include <chrono>

using namespace ygo;
static void check(bool b,const char* what) {
	if(!b) { std::cerr<<"FAIL: "<<what<<'\n'; std::exit(1); }
}
int main(){
	PendingActionConfirmation action;
	for(int c: {0,1,3,4,5})
		check(ClassifyPendingAction(MSG_SELECT_IDLECMD,(7<<16)|c)!=PendingActionKind::None,
			"summon, special summon, set and activate staged");
	for(int c: {2,6,7,8})
		check(ClassifyPendingAction(MSG_SELECT_IDLECMD,c)==PendingActionKind::None,
			"reposition, phase change and shuffle untouched");
	check(ClassifyPendingAction(MSG_SELECT_BATTLECMD,2<<16)==PendingActionKind::Activate,
		"battle activation staged");
	check(ClassifyPendingAction(MSG_SELECT_BATTLECMD,(2<<16)|1)==PendingActionKind::None,
		"attacks are not staged");
	check(ClassifyPendingAction(MSG_SELECT_BATTLECMD,2)==PendingActionKind::None,
		"battle phase transition untouched");
	check(ClassifyPendingAction(MSG_SELECT_CHAIN,0)==PendingActionKind::Activate,
		"optional chain activation staged");
	check(ClassifyPendingAction(MSG_SELECT_CHAIN,-1)==PendingActionKind::None,
		"declining chain not staged");
	check(ClassifyPendingAction(MSG_SELECT_CHAIN,0,true)==PendingActionKind::None,
		"forced chain not staged");
	check(ClassifyPendingAction(MSG_SELECT_PLACE,0)==PendingActionKind::None,
		"no fake cancellation for zone prompts");
	check(ClassifyPendingAction(MSG_SELECT_POSITION,0)==PendingActionKind::None,
		"no fake cancellation for position prompts");
	const auto start = PendingActionConfirmation::Clock::now();
	check(action.Stage(MSG_SELECT_IDLECMD,(2<<16)|3,start),"can stage Monster Set");
	check(!action.ShouldAutoCommit(start + std::chrono::milliseconds{499}),
		"set stays cancellable for the entire 500ms window");
	check(action.ShouldAutoCommit(start + std::chrono::milliseconds{500}),
		"set autocommits without an extra click after 500ms");
	action.hovering_cancel = true;
	check(!action.ShouldAutoCommit(start + std::chrono::seconds{5}),
		"hovering Cancel pauses autocommit");
	action.hovering_cancel = false;
	check(action.ShouldAutoCommit(start + std::chrono::seconds{5}),
		"leaving Cancel permits autocommit");
	check(action.active&&action.message==MSG_SELECT_IDLECMD&&
		action.response==((2<<16)|3)&&action.kind==PendingActionKind::MonsterSet,
		"exact original response retained");
	check(!action.Stage(MSG_SELECT_IDLECMD,5),"pending action cannot be overwritten");
	action.Reset();
	check(!action.active&&action.kind==PendingActionKind::None,
		"cancel does not commit a response");
	check(action.Stage(MSG_SELECT_CHAIN,0,start),"new action after cancel");
	check(!action.ShouldAutoCommit(start + std::chrono::milliseconds{299}),
		"activation gets a short 300ms window");
	check(action.ShouldAutoCommit(start + std::chrono::milliseconds{300}),
		"activation autocommits after 300ms");
	action.Reset();
	check(!action.ShouldAutoCommit(start + std::chrono::seconds{10}),
		"no timer fires after a canceled action");
	std::cout<<"Pending Action Confirmation: PASS\n";
}
