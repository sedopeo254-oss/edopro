#include "utils.h"
#include "game_config.h"
#include <IGUIWindow.h>
#include <IGUIStaticText.h>
#include <IGUIScrollBar.h>
#include <IGUIListBox.h>
#include <IGUIEditBox.h>
#include <IGUICheckBox.h>
#include <IVideoDriver.h>
#include <ICameraSceneNode.h>
#include "game.h"
#include "client_field.h"
#include "client_card.h"
#include "duelclient.h"
#include "multiplayer_replay_animation.h"
#include "data_manager.h"
#include "image_manager.h"
#include "game.h"
#include "materials.h"
#include "core_utils.h"
#include "CGUIImageButton/CGUIImageButton.h"
#include "CGUITTFont/CGUITTFont.h"
#include "custom_skin_enum.h"
#include "fmt.h"

namespace ygo {

ClientField::ClientField() {
	panel = nullptr;
	hovered_card = nullptr;
	clicked_card = nullptr;
	highlighting_card = nullptr;
	hovered_controler = 0;
	hovered_location = 0;
	hovered_sequence = 0;
	selectable_field = 0;
	selected_field = 0;
	deck_act[0] = deck_act[1] = false;
	grave_act[0] = grave_act[1] = false;
	remove_act[0] = remove_act[1] = false;
	extra_act[0] = extra_act[1] = false;
	pzone_act[0] = pzone_act[1] = false;
	conti_act = false;
	deck_reversed = false;
	conti_selecting = false;
	for(int p = 0; p < 2; ++p) {
		skills[p] = nullptr;
		mzone[p].resize(7, nullptr);
		szone[p].resize(8, nullptr);
	}
}
void ClientField::Clear() {
	auto ClearVector = [](auto& vec) {
		for(auto& pcard : vec)
			delete pcard;
		vec = {};
	};
	for(int i = 0; i < 2; ++i) {
		ClearVector(mzone[i]);
		ClearVector(szone[i]);
		mzone[i].resize(7, nullptr);
		szone[i].resize(8, nullptr);
		ClearVector(deck[i]);
		ClearVector(hand[i]);
		ClearVector(grave[i]);
		ClearVector(remove[i]);
		ClearVector(extra[i]);
	}
	ClearVector(limbo_temp);
	ClearVector(overlay_cards);
	if(skills[0]) {
		delete skills[0];
		skills[0] = nullptr;
	}
	if(skills[1]) {
		delete skills[1];
		skills[1] = nullptr;
	}
	overlay_cards.clear();
	extra_p_count[0] = 0;
	extra_p_count[1] = 0;
	player_desc_hints[0].clear();
	player_desc_hints[1].clear();
	chains.clear();
	activatable_cards.clear();
	queued_panel_confirm_cards.clear();
	summonable_cards.clear();
	spsummonable_cards.clear();
	msetable_cards.clear();
	ssetable_cards.clear();
	reposable_cards.clear();
	attackable_cards.clear();
	sort_list.clear();
	disabled_field = 0;
	panel = 0;
	hovered_card = 0;
	clicked_card = 0;
	highlighting_card = 0;
	hovered_controler = 0;
	hovered_location = 0;
	hovered_sequence = 0;
	selectable_field = 0;
	selected_field = 0;
	deck_act[0] = deck_act[1] = false;
	grave_act[0] = grave_act[1] = false;
	remove_act[0] = remove_act[1] = false;
	extra_act[0] = extra_act[1] = false;
	pzone_act[0] = pzone_act[1] = false;
	conti_act = false;
	conti_selecting = false;
	deck_reversed = false;
	for(size_t logical = 0; logical < multiplayer_private_piles.size(); ++logical) {
		multiplayer_private_piles[logical] = {};
		multiplayer_private_piles_valid[logical] = false;
	}
	multiplayer_displayed_field_logical = { 0xff, 0xff };
	multiplayer_displayed_hand_logical = { 0xff, 0xff };
}
void ClientField::Initial(uint8_t player, uint32_t deckc, uint32_t extrac) {
	ClientCard* pcard;
	for(uint32_t i = 0; i < deckc; ++i) {
		pcard = new ClientCard{};
		deck[player].push_back(pcard);
		pcard->owner = player;
		pcard->controler = player;
		pcard->location = LOCATION_DECK;
		pcard->sequence = i;
		pcard->position = POS_FACEDOWN_DEFENSE;
		pcard->UpdateDrawCoordinates(true);
	}
	for(uint32_t i = 0; i < extrac; ++i) {
		pcard = new ClientCard{};
		extra[player].push_back(pcard);
		pcard->owner = player;
		pcard->controler = player;
		pcard->location = LOCATION_EXTRA;
		pcard->sequence = i;
		pcard->position = POS_FACEDOWN_DEFENSE;
		pcard->UpdateDrawCoordinates(true);
	}
}
std::vector<ClientCard*>* ClientField::GetList(uint8_t location, uint8_t controler) {
	switch(location) {
	case LOCATION_DECK:
		return &deck[controler];
		break;
	case LOCATION_HAND:
		return &hand[controler];
		break;
	case LOCATION_MZONE:
		return &mzone[controler];
		break;
	case LOCATION_SZONE:
		return &szone[controler];
		break;
	case LOCATION_GRAVE:
		return &grave[controler];
		break;
	case LOCATION_REMOVED:
		return &remove[controler];
		break;
	case LOCATION_EXTRA:
		return &extra[controler];
		break;
	}
	return nullptr;
}
ClientCard* ClientField::GetCard(uint8_t controler, uint8_t location, size_t sequence, size_t sub_seq) {
	bool is_xyz = (location & LOCATION_OVERLAY) != 0;
	auto lst = GetList(location & (~LOCATION_OVERLAY), controler);
	if(!lst)
		return 0;
	if(is_xyz) {
		if(sequence >= lst->size())
			return 0;
		ClientCard* scard = (*lst)[sequence];
		if(scard && scard->overlayed.size() > sub_seq)
			return scard->overlayed[sub_seq];
		else
			return 0;
	} else {
		if(sequence >= lst->size())
			return 0;
		return (*lst)[sequence];
	}
}
void ClientField::AddCard(ClientCard* pcard, uint8_t controler, uint8_t location, uint32_t sequence) {
	if(!pcard || controler > 1)
		return;
	pcard->controler = controler;
	pcard->location = location;
	pcard->sequence = sequence;
	float z_increase = gGameConfig->topdown_view ? 0.0f : 0.01f;
	switch(location) {
	case LOCATION_DECK: {
		if (sequence != 0 || deck[controler].empty()) {
			deck[controler].push_back(pcard);
			pcard->sequence = static_cast<uint32_t>(deck[controler].size() - 1);
		} else {
			deck[controler].push_back(0);
			for(auto i = deck[controler].size() - 1; i > 0; --i) {
				deck[controler][i] = deck[controler][i - 1];
				deck[controler][i]->sequence++;
				deck[controler][i]->curPos.Z += z_increase;
				deck[controler][i]->mTransform.setTranslation(deck[controler][i]->curPos);
			}
			deck[controler][0] = pcard;
			pcard->sequence = 0;
		}
		pcard->is_reversed = false;
		break;
	}
	case LOCATION_HAND: {
		hand[controler].push_back(pcard);
		pcard->sequence = static_cast<uint32_t>(hand[controler].size() - 1);
		break;
	}
	case LOCATION_MZONE: {
		if(sequence >= mzone[controler].size())
			mzone[controler].resize(sequence + 1, nullptr);
		mzone[controler][sequence] = pcard;
		break;
	}
	case LOCATION_SZONE: {
		if(sequence >= szone[controler].size())
			szone[controler].resize(sequence + 1, nullptr);
		szone[controler][sequence] = pcard;
		break;
	}
	case LOCATION_GRAVE: {
		grave[controler].push_back(pcard);
		pcard->sequence = static_cast<uint32_t>(grave[controler].size() - 1);
		break;
	}
	case LOCATION_REMOVED: {
		remove[controler].push_back(pcard);
		pcard->sequence = static_cast<uint32_t>(remove[controler].size() - 1);
		break;
	}
	case LOCATION_EXTRA: {
		if(extra_p_count[controler] == 0 || (pcard->position & POS_FACEUP)) {
			extra[controler].push_back(pcard);
			pcard->sequence = static_cast<uint32_t>(extra[controler].size() - 1);
		} else {
			extra[controler].push_back(0);
			auto p = extra[controler].size() - extra_p_count[controler] - 1;
			for(auto i = extra[controler].size() - 1; i > p; --i) {
				extra[controler][i] = extra[controler][i - 1];
				extra[controler][i]->sequence++;
				extra[controler][i]->curPos.Z += z_increase;
				extra[controler][i]->mTransform.setTranslation(extra[controler][i]->curPos);
			}
			extra[controler][p] = pcard;
			pcard->sequence = static_cast<uint32_t>(p);
		}
		if (pcard->position & POS_FACEUP)
			extra_p_count[controler]++;
		break;
	}
	}
}
ClientCard* ClientField::RemoveCard(uint8_t controler, uint8_t location, uint32_t sequence) {
	if(controler > 1)
		return nullptr;
	const auto* source = GetList(location, controler);
	if(!source || sequence >= source->size())
		return nullptr;
	auto RemoveFromPile = [&](auto& pile) {
		float z_decrease = gGameConfig->topdown_view ? 0.0f : 0.01f;
		auto pcard = pile[controler][sequence];
		for(size_t i = sequence; i < pile[controler].size() - 1; ++i) {
			pile[controler][i] = pile[controler][i + 1];
			pile[controler][i]->sequence--;
			pile[controler][i]->curPos.Z -= z_decrease;
			pile[controler][i]->mTransform.setTranslation(pile[controler][i]->curPos);
		}
		pile[controler].pop_back();
		return pcard;
	};
	ClientCard* pcard = nullptr;
	switch (location) {
	case LOCATION_DECK: {
		pcard = RemoveFromPile(deck);
		break;
	}
	case LOCATION_HAND: {
		pcard = hand[controler][sequence];
		for (size_t i = sequence; i < hand[controler].size() - 1; ++i) {
			hand[controler][i] = hand[controler][i + 1];
			hand[controler][i]->sequence--;
		}
		hand[controler].pop_back();
		break;
	}
	case LOCATION_MZONE: {
		std::swap(pcard, mzone[controler][sequence]);
		break;
	}
	case LOCATION_SZONE: {
		std::swap(pcard, szone[controler][sequence]);
		break;
	}
	case LOCATION_GRAVE: {
		pcard = RemoveFromPile(grave);
		break;
	}
	case LOCATION_REMOVED: {
		pcard = RemoveFromPile(remove);
		break;
	}
	case LOCATION_EXTRA: {
		pcard = RemoveFromPile(extra);
		if (pcard && pcard->position & POS_FACEUP)
			extra_p_count[controler]--;
		break;
	}
	}
	if(!pcard)
		return nullptr;
	pcard->location = 0;
	return pcard;
}
void ClientField::UpdateCard(uint8_t controler, uint8_t location, uint32_t sequence, const uint8_t* data, uint32_t len) {
	ClientCard* pcard = GetCard(controler, location, sequence);
	if(pcard) {
		if(mainGame->dInfo.compat_mode)
			len = BufferIO::Read<uint32_t>(data);
		pcard->UpdateInfo(CoreUtils::Query{ data, mainGame->dInfo.compat_mode, len, mainGame->dInfo.legacy_race_size });
	}
}
void ClientField::UpdateFieldCard(uint8_t controler, uint8_t location, const uint8_t* data, uint32_t len) {
	auto lst = GetList(location, controler);
	if(!lst)
		return;
	CoreUtils::QueryStream stream{ data, mainGame->dInfo.compat_mode, len, mainGame->dInfo.legacy_race_size };
	auto cit = lst->begin();
	for(const auto& query : stream.GetQueries()) {
		if(cit == lst->end())
			break;
		auto pcard = *cit++;
		if(pcard)
			pcard->UpdateInfo(query);
	}
}
void ClientField::ClearCommandFlag() {
	auto ClearFlag = [](const std::vector<ClientCard*>& map) {
		for(auto& pcard : map)
			if(pcard)
				pcard->cmdFlag = 0;
	};
	ClearFlag(activatable_cards);
	ClearFlag(summonable_cards);
	ClearFlag(spsummonable_cards);
	ClearFlag(msetable_cards);
	ClearFlag(ssetable_cards);
	ClearFlag(reposable_cards);
	ClearFlag(attackable_cards);
	conti_cards.clear();
	deck_act[0] = deck_act[1] = false;
	grave_act[0] = grave_act[1] = false;
	remove_act[0] = remove_act[1] = false;
	extra_act[0] = extra_act[1] = false;
	pzone_act[0] = pzone_act[1] = false;
	conti_act = false;
}
void ClientField::ClearSelect() {
	for(auto& pcard : selectable_cards) {
		pcard->is_selectable = false;
		pcard->is_selected = false;
	}
}
void ClientField::ClearChainSelect() {
	for(auto& pcard : activatable_cards) {
		pcard->cmdFlag = 0;
		pcard->chain_code = 0;
		pcard->is_selectable = false;
		pcard->is_selected = false;
	}
	conti_cards.clear();
	deck_act[0] = deck_act[1] = false;
	grave_act[0] = grave_act[1] = false;
	remove_act[0] = remove_act[1] = false;
	extra_act[0] = extra_act[1] = false;
	pzone_act[0] = pzone_act[1] = false;
	conti_act = false;
}
// needs to be synchronized with EGET_SCROLL_BAR_CHANGED
void ClientField::ShowSelectCard(bool buttonok, bool chain) {
	size_t startpos;
	size_t ct;
	if(selectable_cards.size() <= 5) {
		startpos = 30 + 125 * (5 - selectable_cards.size()) / 2;
		ct = selectable_cards.size();
	} else {
		startpos = 30;
		ct = 5;
	}
	for(size_t i = 0; i < ct; ++i) {
		auto& curstring = mainGame->stCardPos[i];
		auto& curcard = selectable_cards[i];
		curstring->enableOverrideColor(false);
		// image
		if(curcard->code)
			mainGame->imageLoading[mainGame->btnCardSelect[i]] = curcard->code;
		else if(conti_selecting)
			mainGame->imageLoading[mainGame->btnCardSelect[i]] = curcard->chain_code;
		else
			mainGame->btnCardSelect[i]->setImage(mainGame->imageManager.tCover[curcard->controler]);
		mainGame->btnCardSelect[i]->setRelativePosition(mainGame->Scale<irr::s32>(static_cast<irr::s32>(startpos + i * 125), 55, static_cast<irr::s32>(startpos + 120 + i * 125), 225));
		mainGame->btnCardSelect[i]->setPressed(false);
		mainGame->btnCardSelect[i]->setVisible(true);
		if(mainGame->dInfo.curMsg != MSG_SORT_CHAIN && mainGame->dInfo.curMsg != MSG_SORT_CARD) {
			sort_list.clear();
			// text
			std::wstring text = L"";
			if(conti_selecting)
				text = std::wstring{ DataManager::unknown_string };
			else if(curcard->location == LOCATION_OVERLAY) {
				text = epro::format(L"{}[{}]({})", gDataManager->FormatLocation(curcard->overlayTarget->location, curcard->overlayTarget->sequence),
					curcard->overlayTarget->sequence + 1, curcard->sequence + 1);
			} else if(curcard->location) {
				text = epro::format(L"{}[{}]", gDataManager->FormatLocation(curcard->location, curcard->sequence),
					curcard->sequence + 1);
			}
			curstring->setText(text.data());
			// color
			if (curcard->is_selected)
				curstring->setBackgroundColor(skin::DUELFIELD_CARD_SELECTED_WINDOW_BACKGROUND_VAL);
			else {
				if(conti_selecting)
					curstring->setBackgroundColor(skin::DUELFIELD_CARD_SELF_WINDOW_BACKGROUND_VAL);
				else if(curcard->location == LOCATION_OVERLAY) {
					if(curcard->owner != curcard->overlayTarget->controler)
						curstring->setOverrideColor(skin::DUELFIELD_CARD_SELECT_WINDOW_OVERLAY_TEXT_VAL);
					if(curcard->overlayTarget->controler)
						curstring->setBackgroundColor(skin::DUELFIELD_CARD_OPPONENT_WINDOW_BACKGROUND_VAL);
					else
						curstring->setBackgroundColor(skin::DUELFIELD_CARD_SELF_WINDOW_BACKGROUND_VAL);
				} else if(curcard->location == LOCATION_DECK || curcard->location == LOCATION_EXTRA || curcard->location == LOCATION_REMOVED) {
					if(curcard->position & POS_FACEDOWN)
						curstring->setOverrideColor(skin::DUELFIELD_CARD_SELECT_WINDOW_SET_TEXT_VAL);
					if(curcard->controler)
						curstring->setBackgroundColor(skin::DUELFIELD_CARD_OPPONENT_WINDOW_BACKGROUND_VAL);
					else
						curstring->setBackgroundColor(skin::DUELFIELD_CARD_SELF_WINDOW_BACKGROUND_VAL);
				} else {
					if(curcard->controler)
						curstring->setBackgroundColor(skin::DUELFIELD_CARD_OPPONENT_WINDOW_BACKGROUND_VAL);
					else
						curstring->setBackgroundColor(skin::DUELFIELD_CARD_SELF_WINDOW_BACKGROUND_VAL);
				}
			}
		} else {
			if(sort_list[i]) {
				curstring->setText(epro::to_wstring(sort_list[i]).data());
			} else
				curstring->setText(L"");
			curstring->setBackgroundColor(skin::DUELFIELD_CARD_SELF_WINDOW_BACKGROUND_VAL);
		}
		curstring->setVisible(true);
		curstring->setRelativePosition(mainGame->Scale<irr::s32>(static_cast<irr::s32>(startpos + i * 125), 30, static_cast<irr::s32>(startpos + 120 + i * 125), 50));
	}
	if(selectable_cards.size() <= 5) {
		for(auto i = selectable_cards.size(); i < 5; ++i) {
			mainGame->btnCardSelect[i]->setVisible(false);
			mainGame->stCardPos[i]->setVisible(false);
		}
		mainGame->scrCardList->setPos(0);
		mainGame->scrCardList->setVisible(false);
	} else {
		mainGame->scrCardList->setVisible(true);
		mainGame->scrCardList->setMin(0);
		mainGame->scrCardList->setMax(static_cast<irr::s32>(selectable_cards.size() - 5) * 10 + 9);
		mainGame->scrCardList->setPos(0);
	}
	mainGame->btnSelectOK->setVisible(buttonok);
	mainGame->PopupElement(mainGame->wCardSelect);
}
void ClientField::ShowChainCard() {
	sort_list.clear();
	size_t startpos;
	size_t ct;
	if(selectable_cards.size() <= 5) {
		startpos = 30 + 125 * (5 - selectable_cards.size()) / 2;
		ct = selectable_cards.size();
	} else {
		startpos = 30;
		ct = 5;
	}
	for(size_t i = 0; i < ct; ++i) {
		auto& curstring = mainGame->stCardPos[i];
		auto& curcard = selectable_cards[i];
		if(curcard->code)
			mainGame->imageLoading[mainGame->btnCardSelect[i]] = curcard->code;
		else
			mainGame->btnCardSelect[i]->setImage(mainGame->imageManager.tCover[curcard->controler]);
		mainGame->btnCardSelect[i]->setRelativePosition(mainGame->Scale<irr::s32>(static_cast<irr::s32>(startpos + i * 125), 55, static_cast<irr::s32>(startpos + 120 + i * 125), 225));
		mainGame->btnCardSelect[i]->setPressed(false);
		mainGame->btnCardSelect[i]->setVisible(true);
		curstring->setText(epro::format(L"{}[{}]", gDataManager->FormatLocation(curcard->location, curcard->sequence),
			curcard->sequence + 1).data());
		if(curcard->location == LOCATION_OVERLAY) {
			if(curcard->owner != curcard->overlayTarget->controler)
				curstring->setOverrideColor(skin::DUELFIELD_CARD_SELECT_WINDOW_OVERLAY_TEXT_VAL);
			if(curcard->overlayTarget->controler)
				curstring->setBackgroundColor(skin::DUELFIELD_CARD_OPPONENT_WINDOW_BACKGROUND_VAL);
			else
				curstring->setBackgroundColor(skin::DUELFIELD_CARD_SELF_WINDOW_BACKGROUND_VAL);
		} else {
			if(curcard->controler)
				curstring->setBackgroundColor(skin::DUELFIELD_CARD_OPPONENT_WINDOW_BACKGROUND_VAL);
			else
				curstring->setBackgroundColor(skin::DUELFIELD_CARD_SELF_WINDOW_BACKGROUND_VAL);
		}
		curstring->setVisible(true);
		curstring->setRelativePosition(mainGame->Scale<irr::s32>(static_cast<irr::s32>(startpos + i * 125), 30, static_cast<irr::s32>(startpos + 120 + i * 125), 50));
	}
	if(selectable_cards.size() <= 5) {
		for(auto i = selectable_cards.size(); i < 5; ++i) {
			mainGame->btnCardSelect[i]->setVisible(false);
			mainGame->stCardPos[i]->setVisible(false);
		}
		mainGame->scrCardList->setPos(0);
		mainGame->scrCardList->setVisible(false);
	} else {
		mainGame->scrCardList->setVisible(true);
		mainGame->scrCardList->setMin(0);
		mainGame->scrCardList->setMax(static_cast<irr::s32>(selectable_cards.size() - 5) * 10 + 9);
		mainGame->scrCardList->setPos(0);
	}
	if(!chain_forced)
		mainGame->btnSelectOK->setVisible(true);
	else mainGame->btnSelectOK->setVisible(false);
	mainGame->PopupElement(mainGame->wCardSelect);
}
void ClientField::ShowLocationCard() {
	size_t startpos;
	size_t ct;
	if(display_cards.size() <= 5) {
		startpos = 30 + 125 * (5 - display_cards.size()) / 2;
		ct = display_cards.size();
	} else {
		startpos = 30;
		ct = 5;
	}
	for(size_t i = 0; i < ct; ++i) {
		auto& curstring = mainGame->stDisplayPos[i];
		auto& curcard = display_cards[i];
		curstring->enableOverrideColor(false);
		if(curcard->code)
			mainGame->imageLoading[mainGame->btnCardDisplay[i]] = curcard->code;
		else
			mainGame->btnCardDisplay[i]->setImage(mainGame->imageManager.tCover[curcard->controler]);
		mainGame->btnCardDisplay[i]->setRelativePosition(mainGame->Scale<irr::s32>(static_cast<irr::s32>(startpos + i * 125), 55, static_cast<irr::s32>(startpos + 120 + i * 125), 225));
		mainGame->btnCardDisplay[i]->setPressed(false);
		mainGame->btnCardDisplay[i]->setVisible(true);
		std::wstring text;
		if(curcard->location == LOCATION_OVERLAY) {
			text = epro::format(L"{}[{}]({})", gDataManager->FormatLocation(curcard->overlayTarget->location, curcard->overlayTarget->sequence),
				curcard->overlayTarget->sequence + 1, curcard->sequence + 1);
		} else if(curcard->location) {
			text = epro::format(L"{}[{}]", gDataManager->FormatLocation(curcard->location, curcard->sequence),
				curcard->sequence + 1);
		}
		curstring->setText(text.data());
		if(curcard->location == LOCATION_OVERLAY) {
			if(curcard->owner != curcard->overlayTarget->controler)
				curstring->setOverrideColor(skin::DUELFIELD_CARD_SELECT_WINDOW_OVERLAY_TEXT_VAL);
			if(curcard->overlayTarget->controler)
				curstring->setBackgroundColor(skin::DUELFIELD_CARD_OPPONENT_WINDOW_BACKGROUND_VAL);
			else
				curstring->setBackgroundColor(skin::DUELFIELD_CARD_SELF_WINDOW_BACKGROUND_VAL);
		} else if(curcard->location == LOCATION_EXTRA || curcard->location == LOCATION_REMOVED) {
			if(curcard->position & POS_FACEDOWN)
				curstring->setOverrideColor(skin::DUELFIELD_CARD_SELECT_WINDOW_SET_TEXT_VAL);
			if(curcard->controler)
				curstring->setBackgroundColor(skin::DUELFIELD_CARD_OPPONENT_WINDOW_BACKGROUND_VAL);
			else
				curstring->setBackgroundColor(skin::DUELFIELD_CARD_SELF_WINDOW_BACKGROUND_VAL);
		} else {
			if(curcard->controler)
				curstring->setBackgroundColor(skin::DUELFIELD_CARD_OPPONENT_WINDOW_BACKGROUND_VAL);
			else
				curstring->setBackgroundColor(skin::DUELFIELD_CARD_SELF_WINDOW_BACKGROUND_VAL);
		}
		curstring->setVisible(true);
		curstring->setRelativePosition(mainGame->Scale<irr::s32>(static_cast<irr::s32>(startpos + i * 125), 30, static_cast<irr::s32>(startpos + 120 + i * 125), 50));
	}
	if(display_cards.size() <= 5) {
		for(auto i = display_cards.size(); i < 5; ++i) {
			mainGame->btnCardDisplay[i]->setVisible(false);
			mainGame->stDisplayPos[i]->setVisible(false);
		}
		mainGame->scrDisplayList->setPos(0);
		mainGame->scrDisplayList->setVisible(false);
	} else {
		mainGame->scrDisplayList->setVisible(true);
		mainGame->scrDisplayList->setMin(0);
		mainGame->scrDisplayList->setMax(static_cast<irr::s32>(display_cards.size() - 5) * 10 + 9);
		mainGame->scrDisplayList->setPos(0);
	}
	mainGame->btnDisplayOK->setVisible(true);
	mainGame->PopupElement(mainGame->wCardDisplay);
}
std::wstring ClientField::GetOptionText(uint64_t option) const {
	if((option & MULTIPLAYER_OPTION_PLAYER_MASK) != MULTIPLAYER_OPTION_PLAYER_BASE)
		return std::wstring(gDataManager->GetDesc(option, mainGame->dInfo.compat_mode));
	const auto logical = static_cast<uint8_t>(option & 0xffu);
	const auto& team1_names = mainGame->dInfo.isTeam1 ? mainGame->dInfo.selfnames : mainGame->dInfo.opponames;
	const auto& team2_names = mainGame->dInfo.isTeam1 ? mainGame->dInfo.opponames : mainGame->dInfo.selfnames;
	std::wstring name = L"Player";
	if(logical < mainGame->dInfo.team1) {
		if(logical < team1_names.size() && !team1_names[logical].empty())
			name = team1_names[logical];
	} else {
		const auto index = static_cast<size_t>(logical - mainGame->dInfo.team1);
		if(index < team2_names.size() && !team2_names[index].empty())
			name = team2_names[index];
	}
	return epro::format(L"P{} {}", static_cast<unsigned>(logical) + 1u, name);
}
void ClientField::ShowSelectOption(uint64_t select_hint, bool should_lock) {
	std::unique_lock<epro::mutex> lock = (should_lock ? std::unique_lock<epro::mutex>(mainGame->gMutex) : std::unique_lock<epro::mutex>());
	selected_option = 0;
	auto count = select_options.size();
	bool quickmode = true;// (count <= 5);
	for(auto option : select_options) {
		if(mainGame->guiFont->getDimensionustring(GetOptionText(option)).Width > 310) {
			quickmode = false;
			break;
		}
	}
	for(size_t i = 0; (i < count) && (i < 5) && quickmode; i++)
		mainGame->btnOption[i]->setText(GetOptionText(select_options[i]).data());
	irr::core::recti pos = mainGame->wOptions->getRelativePosition();
	if(count > 5 && quickmode)
		pos.LowerRightCorner.X = pos.UpperLeftCorner.X + mainGame->Scale(375);
	else
		pos.LowerRightCorner.X = pos.UpperLeftCorner.X + mainGame->Scale(350);
	if(quickmode) {
		mainGame->scrOption->setVisible(count > 5);
		mainGame->scrOption->setMax(static_cast<irr::s32>(count - 5));
		mainGame->scrOption->setMin(0);
		mainGame->scrOption->setPos(0);
		mainGame->stOptions->setVisible(false);
		mainGame->btnOptionp->setVisible(false);
		mainGame->btnOptionn->setVisible(false);
		mainGame->btnOptionOK->setVisible(false);
		for(size_t i = 0; i < 5; i++)
			mainGame->btnOption[i]->setVisible(i < count);
		int newheight = mainGame->Scale(30 + 40 * static_cast<uint8_t>((count > 5) ? 5 : count));
		int oldheight = pos.LowerRightCorner.Y - pos.UpperLeftCorner.Y;
		pos.UpperLeftCorner.Y = pos.UpperLeftCorner.Y + (oldheight - newheight) / 2;
		pos.LowerRightCorner.Y = pos.UpperLeftCorner.Y + newheight;
		mainGame->wOptions->setRelativePosition(pos);
	} else {
		mainGame->stOptions->setText(GetOptionText(select_options[0]).data());
		mainGame->stOptions->setVisible(true);
		mainGame->btnOptionp->setVisible(false);
		mainGame->btnOptionn->setVisible(count > 1);
		mainGame->btnOptionOK->setVisible(true);
		for(int i = 0; i < 5; i++)
			mainGame->btnOption[i]->setVisible(false);
		pos.LowerRightCorner.Y = pos.UpperLeftCorner.Y + mainGame->Scale(140);
		mainGame->wOptions->setRelativePosition(pos);
	}
	mainGame->wOptions->setText(gDataManager->GetDesc(select_hint ? select_hint : 555, mainGame->dInfo.compat_mode).data());
	mainGame->PopupElement(mainGame->wOptions);
}
void ClientField::ReplaySwap() {
	if(mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))
		return;
	auto reset = [](ClientCard* const& pcard)->void {
		if(pcard) {
			pcard->controler = 1 - pcard->controler;
			pcard->UpdateDrawCoordinates(true);
			pcard->is_moving = false;
		}
	};
	auto resetloc = [&reset](const auto& zone)->void {
		for(const auto& pcard : zone)
			reset(pcard);
	};
	std::swap(deck[0], deck[1]);
	std::swap(hand[0], hand[1]);
	std::swap(mzone[0], mzone[1]);
	std::swap(szone[0], szone[1]);
	std::swap(grave[0], grave[1]);
	std::swap(remove[0], remove[1]);
	std::swap(extra[0], extra[1]);
	std::swap(extra_p_count[0], extra_p_count[1]);
	std::swap(skills[0], skills[1]);
	for(int p = 0; p < 2; ++p) {
		resetloc(deck[p]);
		resetloc(hand[p]);
		resetloc(mzone[p]);
		resetloc(szone[p]);
		resetloc(grave[p]);
		resetloc(remove[p]);
		resetloc(extra[p]);
		reset(skills[p]);
	}
	resetloc(overlay_cards);
	mainGame->dInfo.isFirst = !mainGame->dInfo.isFirst;
	mainGame->dInfo.isTeam1 = !mainGame->dInfo.isTeam1;
	mainGame->dInfo.isReplaySwapped = !mainGame->dInfo.isReplaySwapped;
	std::swap(mainGame->dInfo.lp[0], mainGame->dInfo.lp[1]);
	std::swap(mainGame->dInfo.strLP[0], mainGame->dInfo.strLP[1]);
	std::swap(mainGame->dInfo.current_player[0], mainGame->dInfo.current_player[1]);
	std::swap(player_desc_hints[0], player_desc_hints[1]);
	for(auto& chit : chains) {
		chit.controler = 1 - chit.controler;
		chit.UpdateDrawCoordinates();
	}
	disabled_field = (disabled_field >> 16) | (disabled_field << 16);
}
void ClientField::RefreshAllCards() {
	RefreshLogicalDeckMasters();
	auto refresh = [](ClientCard* const& pcard) {
		if(pcard) {
			pcard->UpdateDrawCoordinates(true);
			pcard->is_moving = false;
			pcard->refresh_on_stop = false;
			pcard->aniFrame = 0;
		}
	};
	auto refreshloc = [&refresh](const auto& zone) {
		for(const auto& pcard : zone)
			refresh(pcard);
	};
	for(int p = 0; p < 2; ++p) {
		refreshloc(deck[p]);
		refreshloc(hand[p]);
		refreshloc(mzone[p]);
		refreshloc(szone[p]);
		refreshloc(grave[p]);
		refreshloc(remove[p]);
		refreshloc(extra[p]);
		refresh(skills[p]);
	}
	refreshloc(overlay_cards);
	for(auto& chit : chains)
		chit.UpdateDrawCoordinates();
	mainGame->should_refresh_hands = true;
}
void ClientField::RefreshPublicFieldCards() {
	RefreshLogicalDeckMasters();
	auto refresh = [](ClientCard* const& pcard) {
		if(!pcard)
			return;
		pcard->UpdateDrawCoordinates(true);
		pcard->is_moving = false;
		pcard->refresh_on_stop = false;
		pcard->aniFrame = 0;
	};
	for(uint8_t player = 0; player < 2; ++player) {
		for(auto* pcard : mzone[player])
			refresh(pcard);
		for(auto* pcard : szone[player])
			refresh(pcard);
		refresh(skills[player]);
	}
	for(auto* pcard : overlay_cards)
		refresh(pcard);
	for(auto& chain : chains)
		chain.UpdateDrawCoordinates();
}
bool ClientField::ReplaceMultiplayerPrivatePiles(uint8_t player,
		const MultiplayerPrivatePileSnapshot& snapshot, bool clear_transient) {
	if(player > 1)
		return false;
	auto public_for = [](uint8_t location, const MultiplayerPrivatePileCard& card) {
		switch(location) {
		case LOCATION_HAND:
			return card.code != 0;
		case LOCATION_EXTRA:
			return card.code != 0 && (card.position & POS_FACEUP);
		case LOCATION_GRAVE:
			return card.code != 0;
		case LOCATION_REMOVED:
			return card.code != 0 && (card.position & POS_FACEUP);
		default:
			return false;
		}
	};
	auto same_cards = [&](const auto& pile, const auto& cards, uint8_t location) {
		if(pile.size() != cards.size())
			return false;
		for(size_t i = 0; i < pile.size(); ++i) {
			const auto* pcard = pile[i];
			if(!pcard || pcard->code != cards[i].code
					|| static_cast<uint8_t>(pcard->position) != cards[i].position
					|| pcard->is_public != public_for(location, cards[i]))
				return false;
		}
		return true;
	};
	const auto visible_top = deck[player].empty() || !deck[player].back()
		? 0u : deck[player].back()->code;
	const auto wanted_extra_p = static_cast<int>(std::min<size_t>(
		snapshot.extra_p_count, snapshot.extra.size()));
	const bool deck_changed = deck[player].size() != snapshot.deck_count
		|| visible_top != snapshot.top_code;
	const bool hand_changed = !same_cards(hand[player], snapshot.hand, LOCATION_HAND);
	const bool extra_changed = extra_p_count[player] != wanted_extra_p
		|| !same_cards(extra[player], snapshot.extra, LOCATION_EXTRA);
	const bool grave_changed = !same_cards(grave[player], snapshot.grave, LOCATION_GRAVE);
	const bool removed_changed = !same_cards(remove[player], snapshot.removed, LOCATION_REMOVED);
	if(!deck_changed && !hand_changed && !extra_changed
			&& !grave_changed && !removed_changed)
		return false;

	if(clear_transient) {
		ClearSelect();
		ClearChainSelect();
		ClearCommandFlag();
		selectable_cards.clear();
		selected_cards.clear();
		must_select_cards.clear();
		selectsum_cards.clear();
		selectsum_all.clear();
		queued_panel_confirm_cards.clear();
		display_cards.clear();
		summonable_cards.clear();
		spsummonable_cards.clear();
		msetable_cards.clear();
		ssetable_cards.clear();
		reposable_cards.clear();
		activatable_cards.clear();
		attackable_cards.clear();
		conti_cards.clear();
		command_card = nullptr;
		clicked_card = nullptr;
		highlighting_card = nullptr;
		attacker = nullptr;
		attack_target = nullptr;
	}

	auto detach_card = [this](ClientCard* pcard) {
		if(!pcard)
			return;
		pcard->ClearTarget();
		if(pcard->equipTarget) {
			pcard->equipTarget->equipped.erase(pcard);
			pcard->equipTarget = nullptr;
		}
		for(auto* equipped : pcard->equipped)
			equipped->equipTarget = nullptr;
		pcard->equipped.clear();
		if(hovered_card == pcard)
			hovered_card = nullptr;
		for(auto& chain : chains) {
			chain.target.erase(pcard);
			if(chain.chain_card == pcard)
				chain.chain_card = nullptr;
		}
		current_chain.target.erase(pcard);
		if(current_chain.chain_card == pcard)
			current_chain.chain_card = nullptr;
	};
	auto reset_identity = [&](ClientCard* pcard) {
		detach_card(pcard);
		pcard->cover = 0;
		pcard->status = 0;
		pcard->cmdFlag = 0;
		pcard->chain_code = 0;
		pcard->is_reversed = false;
		pcard->is_hovered = false;
		pcard->is_selectable = false;
		pcard->is_selected = false;
		pcard->is_showequip = false;
		pcard->is_showtarget = false;
		pcard->is_showchaintarget = false;
		pcard->is_highlighting = false;
		pcard->counters.clear();
		pcard->desc_hints.clear();
	};
	auto set_common = [player](ClientCard* pcard, uint8_t location,
			uint32_t sequence, uint32_t code, uint8_t position, bool is_public) {
		pcard->owner = player;
		pcard->controler = player;
		pcard->location = location;
		pcard->sequence = sequence;
		// A card can already carry the correct numeric code while still rendering
		// the old private card back. Re-run SetCode whenever it becomes public.
		if(pcard->code != code || (is_public && !pcard->is_public))
			pcard->SetCode(code);
		pcard->position = position;
		pcard->is_public = is_public;
		pcard->is_moving = false;
		pcard->is_fading = false;
		pcard->refresh_on_stop = false;
		pcard->aniFrame = 0;
		pcard->curAlpha = 255;
		pcard->draw_scale = 1.0f;
		pcard->UpdateDrawCoordinates(true);
	};
	auto resize_pile = [&](auto& pile, size_t count) {
		while(pile.size() > count) {
			auto* pcard = pile.back();
			detach_card(pcard);
			delete pcard;
			pile.pop_back();
		}
		while(pile.size() < count)
			pile.push_back(new ClientCard{});
	};
	auto reconcile_cards = [&](auto& pile, const auto& cards,
			uint8_t location) {
		resize_pile(pile, cards.size());
		for(size_t sequence = 0; sequence < cards.size(); ++sequence) {
			auto* pcard = pile[sequence];
			const bool wanted_public = public_for(location, cards[sequence]);
			const bool identity_changed = pcard->location != location
				|| pcard->code != cards[sequence].code;
			if(identity_changed)
				reset_identity(pcard);
			set_common(pcard, location, static_cast<uint32_t>(sequence),
				cards[sequence].code, cards[sequence].position, wanted_public);
		}
	};

	if(deck_changed) {
		resize_pile(deck[player], snapshot.deck_count);
		for(size_t sequence = 0; sequence < deck[player].size(); ++sequence) {
			auto* pcard = deck[player][sequence];
			const auto code = sequence + 1 == deck[player].size()
				? snapshot.top_code : 0u;
			if(pcard->location != LOCATION_DECK || pcard->code != code)
				reset_identity(pcard);
			set_common(pcard, LOCATION_DECK, static_cast<uint32_t>(sequence),
				code, POS_FACEDOWN_DEFENSE, false);
		}
	}
	if(hand_changed)
		reconcile_cards(hand[player], snapshot.hand, LOCATION_HAND);
	if(extra_changed) {
		reconcile_cards(extra[player], snapshot.extra, LOCATION_EXTRA);
		extra_p_count[player] = wanted_extra_p;
	}
	if(grave_changed)
		reconcile_cards(grave[player], snapshot.grave, LOCATION_GRAVE);
	if(removed_changed)
		reconcile_cards(remove[player], snapshot.removed, LOCATION_REMOVED);
	if(hand_changed) {
		mainGame->should_refresh_hands = true;
		RefreshHandHitboxes();
	}
	return true;
}
void ClientField::CacheMultiplayerPrivatePiles(uint8_t logical_player,
		const MultiplayerPrivatePileSnapshot& snapshot) {
	if(logical_player >= multiplayer_private_piles.size())
		return;
	multiplayer_private_piles[logical_player] = snapshot;
	multiplayer_private_piles_valid[logical_player] = true;
}
void ClientField::CaptureBattleRoyaleReplayPrivatePiles() {
	if(!mainGame->dInfo.isReplay
			|| !mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)
			|| mainGame->dInfo.replay_battle_royale_perspective
				>= mainGame->dInfo.team1 + mainGame->dInfo.team2)
		return;
	auto capture_cards = [](const auto& source, auto& destination) {
		destination.clear();
		destination.reserve(source.size());
		for(const auto* pcard : source) {
			if(pcard)
				destination.push_back({
					pcard->code, static_cast<uint8_t>(pcard->position)
				});
		}
	};
	for(uint8_t display_side = 0; display_side < 2; ++display_side) {
		const auto logical =
			mainGame->dInfo.GetBattleRoyaleDisplayLogical(display_side);
		if(logical >= multiplayer_private_piles.size())
			continue;
		MultiplayerPrivatePileSnapshot snapshot;
		snapshot.deck_count = static_cast<uint32_t>(deck[display_side].size());
		snapshot.extra_p_count = extra_p_count[display_side] > 0
			? static_cast<uint32_t>(std::min<size_t>(
				extra_p_count[display_side], extra[display_side].size()))
			: 0;
		snapshot.top_code = deck[display_side].empty()
			? 0 : deck[display_side].back()->code;
		capture_cards(hand[display_side], snapshot.hand);
		capture_cards(extra[display_side], snapshot.extra);
		capture_cards(grave[display_side], snapshot.grave);
		capture_cards(remove[display_side], snapshot.removed);
		CacheMultiplayerPrivatePiles(logical, snapshot);
	}
}
void ClientField::ApplyBattleRoyaleReplayPrivatePiles() {
	if(!mainGame->dInfo.isReplay
			|| !mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))
		return;
	bool clear_transient = true;
	for(uint8_t display_side = 0; display_side < 2; ++display_side) {
		const auto logical =
			mainGame->dInfo.GetBattleRoyaleDisplayLogical(display_side);
		if(logical < multiplayer_private_piles.size()
				&& multiplayer_private_piles_valid[logical]) {
			ReplaceMultiplayerPrivatePiles(display_side,
				multiplayer_private_piles[logical], clear_transient);
		} else {
			ReplaceMultiplayerPrivatePiles(display_side,
				MultiplayerPrivatePileSnapshot{}, clear_transient);
		}
		clear_transient = false;
	}
}
void ClientField::CaptureThreeVsOneReplayPrivatePiles() {
	if(!mainGame->dInfo.isReplay
			|| !mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))
		return;
	auto capture_cards = [](const auto& source, auto& destination) {
		destination.clear();
		destination.reserve(source.size());
		for(const auto* pcard : source)
			if(pcard)
				destination.push_back({ pcard->code,
					static_cast<uint8_t>(pcard->position) });
	};
	for(uint8_t display_side = 0; display_side < 2; ++display_side) {
		const auto core_side = mainGame->LocalPlayer(display_side);
		const auto logical = mainGame->dInfo.GetFocusedLogicalPlayer(core_side);
		if(logical >= multiplayer_private_piles.size()
				|| multiplayer_private_piles_valid[logical]
				|| multiplayer_displayed_field_logical[display_side] != logical
				|| multiplayer_displayed_hand_logical[display_side] != logical)
			continue;
		MultiplayerPrivatePileSnapshot snapshot;
		snapshot.deck_count = static_cast<uint32_t>(deck[display_side].size());
		snapshot.extra_p_count = extra_p_count[display_side] > 0
			? static_cast<uint32_t>(std::min<size_t>(
				extra_p_count[display_side], extra[display_side].size())) : 0;
		snapshot.top_code = deck[display_side].empty()
			? 0 : deck[display_side].back()->code;
		// The complete private projection belongs to the same logical player.
		capture_cards(hand[display_side], snapshot.hand);
		capture_cards(extra[display_side], snapshot.extra);
		capture_cards(grave[display_side], snapshot.grave);
		capture_cards(remove[display_side], snapshot.removed);
		CacheMultiplayerPrivatePiles(logical, snapshot);
	}
}
bool ClientField::IsThreeVsOneReplayPrivatePileDisplayed(
		uint8_t logical_player) const {
	if(!mainGame->dInfo.isReplay
			|| !mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
			|| logical_player >= mainGame->dInfo.team1 + mainGame->dInfo.team2)
		return false;
	for(uint8_t core_side = 0; core_side < 2; ++core_side)
		if(mainGame->dInfo.GetFocusedLogicalPlayer(core_side) == logical_player)
			return true;
	return false;
}
bool ClientField::IsThreeVsOneReplayHandDisplayed(uint8_t logical_player) const {
	if(!mainGame->dInfo.isReplay
			|| !mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))
		return false;
	const auto core_side = mainGame->dInfo.GetLogicalCoreSide(logical_player);
	return core_side < 2
		&& mainGame->dInfo.GetFocusedLogicalPlayer(core_side) == logical_player;
}
void ClientField::ApplyThreeVsOneReplayPrivatePiles() {
	if(!mainGame->dInfo.isReplay
			|| !mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))
		return;
	auto capture_cards = [](const auto& source, auto& destination) {
		destination.clear();
		destination.reserve(source.size());
		for(const auto* pcard : source)
			if(pcard)
				destination.push_back({ pcard->code,
					static_cast<uint8_t>(pcard->position) });
	};
	for(uint8_t core_side = 0; core_side < 2; ++core_side) {
		const auto display_side = mainGame->LocalPlayer(core_side);
		if(display_side > 1)
			continue;
		const auto logical = mainGame->dInfo.GetFocusedLogicalPlayer(core_side);
		MultiplayerPrivatePileSnapshot complete;
		if(logical < multiplayer_private_piles.size()
				&& multiplayer_private_piles_valid[logical]) {
			complete = multiplayer_private_piles[logical];
		} else if(multiplayer_displayed_field_logical[display_side] == logical
				&& multiplayer_displayed_hand_logical[display_side] == logical) {
			// The first authoritative snapshot may trail the initial field. Preserve
			// the current projection only when it is already known to be this player.
			complete.deck_count = static_cast<uint32_t>(deck[display_side].size());
			complete.extra_p_count = extra_p_count[display_side] > 0
				? static_cast<uint32_t>(std::min<size_t>(
					extra_p_count[display_side], extra[display_side].size())) : 0;
			complete.top_code = deck[display_side].empty()
				? 0 : deck[display_side].back()->code;
			capture_cards(hand[display_side], complete.hand);
			capture_cards(extra[display_side], complete.extra);
			capture_cards(grave[display_side], complete.grave);
			capture_cards(remove[display_side], complete.removed);
		} else if(logical < 4) {
			// Never leave another teammate's cards on screen under the new name.
			// Use anonymous placeholders until this player's authoritative snapshot
			// arrives, then ReplaceMultiplayerPrivatePiles reconciles them in place.
			complete.deck_count = mainGame->dInfo.logical_deck_count[logical];
			complete.hand.resize(mainGame->dInfo.logical_hand_count[logical],
				{ 0, POS_FACEDOWN_DEFENSE });
			complete.extra.resize(mainGame->dInfo.logical_extra_count[logical],
				{ 0, POS_FACEDOWN_DEFENSE });
			complete.grave.resize(mainGame->dInfo.logical_grave_count[logical],
				{ 0, POS_FACEUP });
			complete.removed.resize(mainGame->dInfo.logical_banish_count[logical],
				{ 0, POS_FACEUP });
		}
		// One atomic snapshot supplies Hand, Deck, Extra, GY and Banish. Never
		// combine the hand of P3 with the graveyard or deck of P1/P2.
		ReplaceMultiplayerPrivatePiles(display_side, complete, false);
		multiplayer_displayed_field_logical[display_side] = logical;
		multiplayer_displayed_hand_logical[display_side] = logical;
	}
}
void ClientField::UpdateMultiplayerPrivateDraw(uint8_t logical_player,
		const std::vector<MultiplayerPrivatePileCard>& drawn_cards) {
	if(logical_player >= multiplayer_private_piles.size()
			|| !multiplayer_private_piles_valid[logical_player])
		return;
	auto& snapshot = multiplayer_private_piles[logical_player];
	const auto count = static_cast<uint32_t>(drawn_cards.size());
	snapshot.deck_count =
		snapshot.deck_count > count ? snapshot.deck_count - count : 0;
	snapshot.top_code = 0;
	snapshot.hand.insert(snapshot.hand.end(),
		drawn_cards.begin(), drawn_cards.end());
}
bool ClientField::ApplyThreeVsOneReplayPrivateDraw(uint8_t logical_player,
		const std::vector<MultiplayerPrivatePileCard>& drawn_cards) {
	if(!mainGame->dInfo.isReplay
			|| !mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
			|| logical_player >= multiplayer_private_piles.size()
			|| !multiplayer_private_piles_valid[logical_player]
			|| drawn_cards.empty()
			|| !IsThreeVsOneReplayHandDisplayed(logical_player))
		return false;
	const auto core_side = mainGame->dInfo.GetLogicalCoreSide(logical_player);
	const auto display_side = core_side < 2
		? mainGame->LocalPlayer(core_side) : static_cast<uint8_t>(0xff);
	if(display_side > 1
			|| multiplayer_displayed_field_logical[display_side] != logical_player
			|| multiplayer_displayed_hand_logical[display_side] != logical_player)
		return false;
	const auto& snapshot = multiplayer_private_piles[logical_player];
	const auto count = drawn_cards.size();
	if(snapshot.hand.size() < count
			|| hand[display_side].size() + count != snapshot.hand.size()
			|| deck[display_side].size() < count)
		return false;
	// The visible prefix must still describe the pre-draw hand. If an older
	// replay omitted a needed snapshot, fall back to the full atomic reconcile.
	for(size_t i = 0; i < hand[display_side].size(); ++i) {
		const auto* pcard = hand[display_side][i];
		if(!pcard || pcard->code != snapshot.hand[i].code
				|| static_cast<uint8_t>(pcard->position) != snapshot.hand[i].position)
			return false;
	}
	for(const auto& drawn : drawn_cards) {
		auto* pcard = deck[display_side].back();
		deck[display_side].pop_back();
		if(!pcard)
			pcard = new ClientCard{};
		pcard->owner = display_side;
		pcard->controler = display_side;
		pcard->location = LOCATION_DECK;
		if(pcard->code != drawn.code)
			pcard->SetCode(drawn.code);
		pcard->position = drawn.position;
		pcard->is_public = drawn.code != 0;
		pcard->is_fading = false;
		pcard->is_moving = false;
		pcard->refresh_on_stop = false;
		pcard->aniFrame = 0;
		pcard->curAlpha = 255;
		pcard->draw_scale = 1.0f;
		AddCard(pcard, display_side, LOCATION_HAND, 0);
	}
	// Animate the complete hand as one non-blocking batch. This replaces the
	// old full private-pile rebuild that caused a visible pause on every draw.
	for(auto* pcard : hand[display_side])
		if(pcard)
			MoveCard(pcard,
				multiplayer_replay_animation::GetDrawMoveFrames(
					mainGame->dInfo.isReplay,
					mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)));
	mainGame->should_refresh_hands = true;
	RefreshHandHitboxes();
	return true;
}
void ClientField::UpdateMultiplayerPrivateMove(uint8_t previous_logical,
		uint8_t previous_location, uint32_t previous_sequence,
		uint8_t current_logical, uint8_t current_location,
		uint32_t current_sequence, uint32_t code, uint8_t position) {
	if(!mainGame->dInfo.isReplay
			|| !(mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)
				|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)))
		return;
	auto get_cards = [](MultiplayerPrivatePileSnapshot& snapshot,
			uint8_t location) -> std::vector<MultiplayerPrivatePileCard>* {
		switch(location) {
		case LOCATION_HAND: return &snapshot.hand;
		case LOCATION_EXTRA: return &snapshot.extra;
		case LOCATION_GRAVE: return &snapshot.grave;
		case LOCATION_REMOVED: return &snapshot.removed;
		default: return nullptr;
		}
	};
	const bool same_pile = previous_logical == current_logical
		&& previous_location == current_location
		&& previous_logical < multiplayer_private_piles.size()
		&& multiplayer_private_piles_valid[previous_logical];
	MultiplayerPrivatePileCard moved{ code, position };
	if(same_pile) {
		auto& snapshot = multiplayer_private_piles[previous_logical];
		if(auto* cards = get_cards(snapshot, previous_location)) {
			if(previous_sequence < cards->size()) {
				moved = (*cards)[previous_sequence];
				cards->erase(cards->begin() + previous_sequence);
			}
			const auto destination =
				std::min<size_t>(current_sequence, cards->size());
			cards->insert(cards->begin() + destination, moved);
		} else if(previous_location == LOCATION_DECK
				&& current_sequence + 1 >= snapshot.deck_count)
			snapshot.top_code = code;
		return;
	}
	if(previous_logical < multiplayer_private_piles.size()
			&& multiplayer_private_piles_valid[previous_logical]) {
		auto& snapshot = multiplayer_private_piles[previous_logical];
		if(previous_location == LOCATION_DECK) {
			if(snapshot.deck_count)
				--snapshot.deck_count;
			snapshot.top_code = 0;
		} else if(auto* cards = get_cards(snapshot, previous_location)) {
			if(previous_sequence < cards->size()) {
				moved = (*cards)[previous_sequence];
				cards->erase(cards->begin() + previous_sequence);
			}
		}
	}
	if(current_logical < multiplayer_private_piles.size()
			&& multiplayer_private_piles_valid[current_logical]) {
		auto& snapshot = multiplayer_private_piles[current_logical];
		moved.code = code ? code : moved.code;
		moved.position = position;
		if(current_location == LOCATION_DECK) {
			++snapshot.deck_count;
			if(current_sequence + 1 >= snapshot.deck_count)
				snapshot.top_code = moved.code;
		} else if(auto* cards = get_cards(snapshot, current_location)) {
			const auto destination =
				std::min<size_t>(current_sequence, cards->size());
			cards->insert(cards->begin() + destination, moved);
		}
	}
}
void ClientField::RefreshLogicalDeckMasters() {
	if(!mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
			|| !mainGame->dInfo.logical_deck_master_enabled)
		return;
	for(uint8_t field_side = 0; field_side < 2; ++field_side) {
		const auto logical_player = mainGame->dInfo.GetFocusedLogicalPlayer(field_side);
		if(logical_player >= 4)
			continue;
		const auto local_side = mainGame->LocalPlayer(field_side);
		const auto code = mainGame->dInfo.logical_deck_master_code[logical_player];
		auto& pcard = skills[local_side];
		if(!code) {
			if(pcard == hovered_card)
				hovered_card = nullptr;
			delete pcard;
			pcard = nullptr;
			continue;
		}
		if(!pcard) {
			pcard = new ClientCard{};
			pcard->controler = local_side;
			pcard->sequence = 0;
			pcard->position = POS_FACEUP;
			pcard->location = LOCATION_SKILL;
		}
		pcard->SetCode(code);
	}
}
void ClientField::CycleTeamField() {
	if(!mainGame->dInfo.HasFieldFlag(DUEL_3_V_1) || mainGame->dInfo.team1 < 2)
		return;
	mainGame->dInfo.field_focus[0] = static_cast<uint8_t>(
		(mainGame->dInfo.field_focus[0] + 1) % mainGame->dInfo.team1);
	hovered_card = nullptr;
	hovered_location = 0;
	hovered_sequence = 0;
	RefreshAllCards();
}
void ClientField::GetChainDrawCoordinates(uint8_t controler, uint8_t location, uint32_t sequence, irr::core::vector3df* t) {
	if ((location & (~LOCATION_OVERLAY)) == LOCATION_HAND) {
		t->X = 2.95f;
		t->Y = (controler == 0) ? 3.15f : (-3.15f);
		t->Z = 0.03f;
		return;
	}
	if(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
			|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)) {
		const auto base_location = location & (~LOCATION_OVERLAY);
		const uint32_t stride = base_location == LOCATION_MZONE ? 7u
			: base_location == LOCATION_SZONE ? 8u : 0u;
		if(stride) {
			const auto core_side = mainGame->LocalPlayer(controler);
			const auto field_duelist = static_cast<uint8_t>(sequence / stride);
			if(mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)) {
				const auto logical = mainGame->dInfo.GetLogicalPlayer(core_side, field_duelist);
				const auto display_side = mainGame->dInfo.GetBattleRoyaleDisplaySide(logical);
				if(display_side > 1) {
					t->X = 3.95f;
					t->Y = -2.5f;
					t->Z = 0.03f;
					return;
				}
				controler = display_side;
			} else if(field_duelist != mainGame->dInfo.field_focus[core_side]) {
				t->X = 3.95f;
				t->Y = controler == 0 ? -2.5f : 2.5f;
				t->Z = 0.03f;
				return;
			}
		}
		if(base_location == LOCATION_MZONE)
			sequence %= 7u;
		else if(base_location == LOCATION_SZONE)
			sequence %= 8u;
	}
	auto PileZ = [&](auto& pile) {
		auto multiplier = gGameConfig->topdown_view ? 1 : pile.size();
		t->Z = multiplier * 0.01f + 0.03f;
	};
	const irr::video::S3DVertex* loc = nullptr;
	switch((location & (~LOCATION_OVERLAY))) {
	case LOCATION_DECK: {
		loc = matManager.getDeck()[controler];
		PileZ(deck[controler]);
		break;
	}
	case LOCATION_MZONE: {
		loc = matManager.vFieldMzone[controler][sequence];
		t->Z = 0.03f;
		break;
	}
	case LOCATION_SZONE: {
		loc = matManager.getSzone()[controler][sequence];
		t->Z = 0.03f;
		break;
	}
	case LOCATION_GRAVE: {
		loc = matManager.getGrave()[controler];
		PileZ(grave[controler]);
		break;
	}
	case LOCATION_REMOVED: {
		loc = matManager.getRemove()[controler];
		PileZ(remove[controler]);
		break;
	}
	case LOCATION_EXTRA: {
		loc = matManager.getExtra()[controler];
		PileZ(extra[controler]);
		break;
	}
	default:
		t->X = 0;
		t->Y = 0;
		t->Z = 0;
		return;
	}
	t->X = (loc[0].Pos.X + loc[1].Pos.X) / 2;
	t->Y = (loc[0].Pos.Y + loc[2].Pos.Y) / 2;
}
static void getCardScreenCoordinates(ClientCard* pcard) {
	irr::core::matrix4 trans = mainGame->camera->getProjectionMatrix();
	trans *= mainGame->camera->getViewMatrix();
	trans *= pcard->mTransform;
	auto transform = [&trans, dim = (mainGame->driver->getCurrentRenderTargetSize() / 2)](irr::core::vector3df vec) {
		irr::f32 transformedPos[4] = { vec.X, vec.Y, vec.Z, 1.0f };

		trans.multiplyWith1x4Matrix(transformedPos);

		if(transformedPos[3] < 0)
			return irr::core::vector2d<irr::s32>(-10000, -10000);

		const irr::f32 zDiv = transformedPos[3] == 0.0f ? 1.0f :
			irr::core::reciprocal(transformedPos[3]);

		return irr::core::vector2d<irr::s32>(
			dim.Width + irr::core::round32(dim.Width * (transformedPos[0] * zDiv)),
			dim.Height - irr::core::round32(dim.Height * (transformedPos[1] * zDiv)));
	};

	const bool reveal_battle_royale_replay_hand =
		mainGame->dInfo.isReplay
		&& mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE);
	const auto& frontmat = (pcard->code
		&& (!mainGame->dInfo.isReplay
			|| reveal_battle_royale_replay_hand
			|| !gGameConfig->hideHandsInReplays
			|| pcard->is_public || pcard->is_hovered))
		? matManager.vCardFront : matManager.vCardBack;
	const auto upperleft = transform(frontmat[0].Pos);
	const auto lowerright = transform(frontmat[3].Pos);
	auto& collision = pcard->hand_collision;
	collision = { upperleft, lowerright };
	if(!collision.isValid())
		collision.repair();
}
void ClientField::RefreshHandHitboxes() {
	for(const auto& _hand : hand)
		for(const auto& pcard : _hand)
			getCardScreenCoordinates(pcard);
}
void ClientField::GetCardDrawCoordinates(ClientCard* pcard, irr::core::vector3df* t, irr::core::vector3df* r, bool setTrans) {
	const int three_columns = mainGame->dInfo.HasFieldFlag(DUEL_3_COLUMNS_FIELD);
	static const irr::core::vector3df selfATK{ 0.0f, 0.0f, 0.0f };
	static const irr::core::vector3df selfDEF{ 0.0f, 0.0f, -irr::core::HALF_PI };
	static const irr::core::vector3df oppoATK{ 0.0f, 0.0f, irr::core::PI };
	static const irr::core::vector3df oppoDEF{ 0.0f, 0.0f, irr::core::HALF_PI };
	static const irr::core::vector3df facedown{ 0.0f, irr::core::PI, 0.0f };
	static const irr::core::vector3df handfaceup{ -FIELD_ANGLE, 0.0f, 0.0f };
	static const irr::core::vector3df handfacedown{ FIELD_ANGLE, irr::core::PI, 0.0f };
	auto GetMiddleX = [](const Materials::QuadVertex pos)->float {
		return (pos[0].Pos.X + pos[1].Pos.X) / 2.0f;
	};
	auto GetMiddleY = [](const Materials::QuadVertex pos)->float {
		return (pos[0].Pos.Y + pos[2].Pos.Y) / 2.0f;
	};
	if(!pcard->location) return;
	const int& controler = pcard->overlayTarget ? pcard->overlayTarget->controler : pcard->controler;
	int draw_controler = controler;
	int sequence = pcard->sequence;
	const int& location = pcard->location;
	pcard->draw_scale = 1.0f;
	if(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
			|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)) {
		const auto base_location = location == LOCATION_OVERLAY && pcard->overlayTarget
			? pcard->overlayTarget->location : location;
		const auto base_sequence = location == LOCATION_OVERLAY && pcard->overlayTarget
			? pcard->overlayTarget->sequence : pcard->sequence;
		const uint32_t stride = base_location == LOCATION_MZONE ? 7u
			: base_location == LOCATION_SZONE ? 8u : 0u;
		const auto core_side = mainGame->LocalPlayer(static_cast<uint8_t>(controler));
		if(mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE) && stride) {
			const auto field_duelist = static_cast<uint8_t>(base_sequence / stride);
			const auto logical = mainGame->dInfo.GetLogicalPlayer(core_side, field_duelist);
			const auto display_side = mainGame->dInfo.GetBattleRoyaleDisplaySide(logical);
			if(display_side > 1) {
				pcard->draw_scale = 0.0f;
				*t = { -100.0f, -100.0f, -10.0f };
				*r = { 0.0f, 0.0f, 0.0f };
				if(setTrans) {
					pcard->mTransform.setTranslation(*t);
					pcard->mTransform.setRotationRadians(*r);
				}
				return;
			}
			draw_controler = display_side;
			sequence = static_cast<int>(base_sequence % stride);
		} else {
			const auto field_count = mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)
				? 2u : (core_side == 0 ? static_cast<uint32_t>(mainGame->dInfo.team1) : 1u);
			if(stride && field_count > 1) {
				const auto field_duelist = static_cast<uint8_t>(base_sequence / stride);
				const auto focused_duelist = mainGame->dInfo.field_focus[core_side];
				if(field_duelist != focused_duelist) {
					pcard->draw_scale = 0.0f;
					*t = { -100.0f, -100.0f, -10.0f };
					*r = { 0.0f, 0.0f, 0.0f };
					if(setTrans) {
						pcard->mTransform.setTranslation(*t);
						pcard->mTransform.setRotationRadians(*r);
					}
					return;
				}
				sequence = static_cast<int>(base_sequence % stride);
			}
		}
	}
	auto GetPos = [&]()->const irr::video::S3DVertex* {
		switch(location) {
		case LOCATION_DECK:		return matManager.getDeck()[draw_controler];
		case LOCATION_MZONE:	return matManager.vFieldMzone[draw_controler][sequence];
		case LOCATION_SZONE:	return matManager.getSzone()[draw_controler][sequence];
		case LOCATION_GRAVE:	return matManager.getGrave()[draw_controler];
		case LOCATION_REMOVED:	return matManager.getRemove()[draw_controler];
		case LOCATION_EXTRA:	return matManager.getExtra()[draw_controler];
		case LOCATION_SKILL:	return matManager.getSkill()[draw_controler];
		case LOCATION_OVERLAY:
			if(!pcard->overlayTarget || draw_controler > 1)
				return nullptr;
			if(pcard->overlayTarget->location == LOCATION_MZONE)
				return matManager.vFieldMzone[draw_controler][sequence];
			if(pcard->overlayTarget->location == LOCATION_SZONE)
				return matManager.getSzone()[draw_controler][sequence];
			[[fallthrough]];
		default: return nullptr;
		}
	};

	if(location != LOCATION_HAND) {
		const auto pos = GetPos();
		if(!pos)
			return;
		t->X = GetMiddleX(pos);
		t->Y = GetMiddleY(pos);
		t->Z = 0.01f;
		if(location == LOCATION_MZONE) {
			if(draw_controler == 0)
				*r = (pcard->position & POS_DEFENSE) ? selfDEF : selfATK;
			else
				*r = (pcard->position & POS_DEFENSE) ? oppoDEF : oppoATK;
		} else if (location == LOCATION_OVERLAY)
			*r = (draw_controler == 0) ? selfATK : oppoATK;
		else
			*r = (draw_controler == 0) ? selfATK : oppoATK;
		if(((location & (LOCATION_GRAVE | LOCATION_OVERLAY)) == 0) && ((location == LOCATION_DECK && deck_reversed == pcard->is_reversed) ||
			(location != LOCATION_DECK && pcard->position & POS_FACEDOWN))) {
			*r += facedown;
			if(location == LOCATION_MZONE && pcard->position & POS_DEFENSE)
				r->Y = irr::core::PI + 0.001f;
		}
		switch(location) {
			case LOCATION_DECK:
			case LOCATION_GRAVE:
			case LOCATION_REMOVED:
			case LOCATION_EXTRA:
			case LOCATION_SKILL: {
				if(!gGameConfig->topdown_view)
					t->Z += 0.01f * sequence;
				break;
			}
			case LOCATION_OVERLAY: {
				if(draw_controler == 0)
					*t = { t->X - 0.12f + 0.06f * pcard->sequence, t->Y + 0.06f, 0.005f + pcard->sequence * 0.0001f };
				else
					*t = { t->X + 0.12f - 0.06f * pcard->sequence, t->Y - 0.06f, 0.005f + pcard->sequence * 0.0001f };
				break;
			}
		}
	} else {
		auto ShouldCardShow = [pcard] {
			return pcard->code
				&& (!mainGame->dInfo.isReplay
					|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)
					|| !gGameConfig->hideHandsInReplays
					|| pcard->is_public || pcard->is_hovered);
		};
		auto SetHoverState = [&] {
			if(!pcard->is_hovered)
				return;
			if(gGameConfig->topdown_view) {
				if(controler == 0)
					t->Y -= 0.2f;
				else
					t->Y += 0.2f;
				return;
			}
			t->Y -= 0.16f;
			t->Z += 0.656f - 0.5f;
		};
		const auto count = hand[controler].size();
		const size_t max = (6 - gGameConfig->topdown_view - three_columns * 2);
		const float xoff1 = (5.5f - 0.8f * count) / 2.0f + sequence * (gGameConfig->topdown_view ? 0.73f : 0.8f);
		float val = three_columns ? 2.4f : 4.0f;
		if(gGameConfig->topdown_view)
			val -= 0.35f;
		float xoff2 = (sequence * val) / (count - 1);
		if(three_columns) xoff2 += 0.8f;
		auto SetXCoord = [&] {
			if(controler == 0) {
				if(count <= max)
					t->X = 1.55f + xoff1;
				else
					t->X = 1.9f + xoff2;
			} else {
				if(count <= max)
					t->X = 6.25f - xoff1;
				else
					t->X = 5.9f - xoff2;
				if(gGameConfig->topdown_view)
					t->X -= 0.378f;
			}
			if(gGameConfig->topdown_view)
				t->X += 0.3f;
		};
		auto SetYCoord = [&] {
			if(gGameConfig->topdown_view) {
				static constexpr auto base_y = 2.5f;
				if(controler == 0)
					t->Y = base_y;
				else
					t->Y = base_y * -1.0f;
				return;
			}
			if(controler == 0)
				t->Y = 4.0f;
			else
				t->Y = -3.4f;

		};
		const float zoff1 = gGameConfig->topdown_view ? 3.0f : 0.5f;
		const float zoff2 = (controler == 0) ? (0.001f * sequence) : (-0.001f * sequence);
		SetXCoord();
		SetYCoord();
		t->Z = zoff1 + zoff2;
		SetHoverState();
		if(gGameConfig->topdown_view) {
			if(controler == 0)
				*r = selfATK;
			else
				*r = oppoATK;
		}
		if(!ShouldCardShow()) {
			if(gGameConfig->topdown_view)
				*r += facedown;
			else
				*r = handfacedown;
		} else if(!gGameConfig->topdown_view)
			*r = handfaceup;
	}
	if(setTrans) {
		pcard->mTransform.setTranslation(*t);
		pcard->mTransform.setRotationRadians(*r);
		if(pcard->location == LOCATION_HAND && !pcard->is_hovered)
			getCardScreenCoordinates(pcard);
	}
}
void ClientField::MoveCard(ClientCard* pcard, float frame) {
	float milliseconds = frame * 1000.0f / 60.0f;
	irr::core::vector3df trans = pcard->curPos;
	irr::core::vector3df rot = pcard->curRot;
	GetCardDrawCoordinates(pcard, &trans, &rot);
	pcard->dPos = (trans - pcard->curPos) / milliseconds;
	float diff = rot.X - pcard->curRot.X;
	while (diff < 0) diff += irr::core::PI * 2;
	while (diff > irr::core::PI * 2)
		diff -= irr::core::PI * 2;
	if (diff < irr::core::PI)
		pcard->dRot.X = diff / milliseconds;
	else
		pcard->dRot.X = -(irr::core::PI * 2 - diff) / milliseconds;
	diff = rot.Y - pcard->curRot.Y;
	while (diff < 0) diff += irr::core::PI * 2;
	while (diff > irr::core::PI * 2) diff -= irr::core::PI * 2;
	if (diff < irr::core::PI)
		pcard->dRot.Y = diff / milliseconds;
	else
		pcard->dRot.Y = -(irr::core::PI * 2 - diff) / milliseconds;
	diff = rot.Z - pcard->curRot.Z;
	while (diff < 0) diff += irr::core::PI * 2;
	while (diff > irr::core::PI * 2) diff -= irr::core::PI * 2;
	if (diff < irr::core::PI)
		pcard->dRot.Z = diff / milliseconds;
	else
		pcard->dRot.Z = -(irr::core::PI * 2 - diff) / milliseconds;
	pcard->is_moving = true;
	pcard->refresh_on_stop = true;
	pcard->aniFrame = milliseconds;
}
void ClientField::FadeCard(ClientCard* pcard, float alpha, float frame) {
	float milliseconds = frame * 1000.0f / 60.0f;
	pcard->dAlpha = (alpha - pcard->curAlpha) / milliseconds;
	pcard->is_fading = true;
	pcard->aniFrame = milliseconds;
}
bool ClientField::ShowSelectSum() {
	if(CheckSelectSum()) {
		if(selectsum_cards.size() == 0 || selectable_cards.size() == 0) {
			SetResponseSelectedCards();
			ShowCancelOrFinishButton(0);
			DuelClient::SendResponse();
			return true;
		} else {
			select_ready = true;
		}
	} else
		select_ready = false;
	bool panelmode = false;
	for (auto& card : selectable_cards) {
		if (card->location & (LOCATION_DECK+LOCATION_EXTRA+LOCATION_GRAVE+LOCATION_REMOVED+LOCATION_OVERLAY)) {
			panelmode = true;
			break;
		}
	}
	mainGame->wCardSelect->setVisible(false);
	mainGame->stCardListTip->setVisible(false);
	if(panelmode) {
		mainGame->dField.ShowSelectCard(select_ready);
	}
	mainGame->stHintMsg->setVisible(!panelmode);
	if (select_ready) {
		ShowCancelOrFinishButton(2);
	} else {
		ShowCancelOrFinishButton(0);
	}
	return false;
}
bool ClientField::CheckSelectSum() {
	std::set<ClientCard*> selable;
	for(auto& card : selectsum_all) {
		card->is_selectable = false;
		card->is_selected = false;
		selable.insert(card);
	}
	for(auto& card : must_select_cards) {
		card->is_selectable = true;
		card->is_selected = true;
		selable.erase(card);
	}
	for(auto& card : selected_cards) {
		card->is_selectable = true;
		card->is_selected = true;
		selable.erase(card);
	}
	selected_cards.insert(selected_cards.end(), must_select_cards.begin(), must_select_cards.end());
	selectsum_cards.clear();
	for(auto& card : selectable_cards) {
		SetShowMark(card, false);
	}
	mainGame->stCardListTip->setVisible(false);
	if (select_mode == 0) {
		bool ret = check_sel_sum_s(selable, 0, select_sumval);
		selectable_cards.clear();
		std::sort(mainGame->dField.must_select_cards.begin(), mainGame->dField.must_select_cards.end(), ClientCard::client_card_sort);
		for(auto& card : must_select_cards) {
			card->is_selectable = true;
			selectable_cards.push_back(card);
			auto it = std::find(selected_cards.begin(), selected_cards.end(), card);
			if (it != selected_cards.end())
				selected_cards.erase(it);
		}
		std::sort(mainGame->dField.selected_cards.begin(), mainGame->dField.selected_cards.end(), ClientCard::client_card_sort);
		for(auto& card : selected_cards) {
			card->is_selectable = true;
			selectable_cards.push_back(card);
		}
		std::vector<ClientCard*> tmp(selectsum_cards.begin(), selectsum_cards.end());
		std::sort(tmp.begin(), tmp.end(), ClientCard::client_card_sort);
		for(auto& card : tmp) {
			card->is_selectable = true;
			selectable_cards.push_back(card);
		}
		return ret;
	} else {
		int mm = -1, mx = -1;
		uint32_t max = 0, sumc = 0;
		bool ret = false;
		for (auto sit = selected_cards.begin(); sit != selected_cards.end(); ++sit) {
			int op1 = (*sit)->opParam & 0xffff;
			int op2 = (*sit)->opParam >> 16;
			int opmin = (op2 > 0 && op1 > op2) ? op2 : op1;
			int opmax = op2 > op1 ? op2 : op1;
			if (mm == -1 || opmin < mm)
				mm = opmin;
			if (mx == -1 || opmax < mx)
				mx = opmax;
			sumc += opmin;
			max += opmax;
		}
		if (select_sumval <= sumc) {
			for (auto& card : must_select_cards) {
				auto it = std::find(selected_cards.begin(), selected_cards.end(), card);
				if (it != selected_cards.end())
					selected_cards.erase(it);
			}
			return true;
		}
		if (select_sumval <= max && select_sumval > max - mx)
			ret = true;
		for(auto sit = selable.begin(); sit != selable.end(); ++sit) {
			uint16_t op1 = (*sit)->opParam & 0xffff;
			uint16_t op2 = ((*sit)->opParam >> 16) & 0xffff;
			uint16_t m = op1;
			uint32_t sums = sumc;
			sums += m;
			int ms = mm;
			if (ms == -1 || m < ms)
				ms = m;
			if (sums >= select_sumval) {
				if (sums - ms < select_sumval)
					selectsum_cards.insert(*sit);
			} else {
				std::set<ClientCard*> left(selable);
				left.erase(*sit);
				if (check_min(left, left.begin(), select_sumval - sums, select_sumval - sums + ms - 1))
					selectsum_cards.insert(*sit);
			}
			if (op2 == 0)
				continue;
			m = op2;
			sums = sumc;
			sums += m;
			ms = mm;
			if (ms == -1 || m < ms)
				ms = m;
			if (sums >= select_sumval) {
				if (sums - ms < select_sumval)
					selectsum_cards.insert(*sit);
			} else {
				std::set<ClientCard*> left(selable);
				left.erase(*sit);
				if (check_min(left, left.begin(), select_sumval - sums, select_sumval - sums + ms - 1))
					selectsum_cards.insert(*sit);
			}
		}
		selectable_cards.clear();
		std::sort(must_select_cards.begin(), must_select_cards.end(), ClientCard::client_card_sort);
		for(auto& card : must_select_cards) {
			card->is_selectable = true;
			selectable_cards.push_back(card);
			auto it = std::find(selected_cards.begin(), selected_cards.end(), card);
			if (it != selected_cards.end())
				selected_cards.erase(it);
		}
		std::sort(selected_cards.begin(), selected_cards.end(), ClientCard::client_card_sort);
		for(auto& card : selected_cards) {
			card->is_selectable = true;
			selectable_cards.push_back(card);
		}
		std::vector<ClientCard*> tmp(selectsum_cards.begin(), selectsum_cards.end());
		std::sort(tmp.begin(), tmp.end(), ClientCard::client_card_sort);
		for(auto& card : tmp) {
			card->is_selectable = true;
			selectable_cards.push_back(card);
		}
		return ret;
	}
}
void ClientField::ShowSelectRace(uint64_t race) {
	uint64_t filter = 0x1;
	auto selected = 0;
	for(auto i = 0u; i < sizeofarr(mainGame->chkRace); ++i, filter <<= 1) {
		auto* checkBox = mainGame->chkRace[i];
		checkBox->setChecked(false);
		auto checked = (filter & race) != 0;
		checkBox->setVisible(checked);
		if(checked) {
			checkBox->setRelativePosition(mainGame->Scale<irr::s32>(10 + (selected % 3) * 120, (selected / 3) * 25, 150 + (selected % 3) * 120, 25 + (selected / 3) * 25));
			++selected;
		}
	}
}
bool ClientField::check_min(const std::set<ClientCard*>& left, std::set<ClientCard*>::const_iterator index, int min, int max) {
	if (index == left.end())
		return false;
	int op1 = (*index)->opParam & 0xffff;
	int op2 = (*index)->opParam >> 16;
	int m = (op2 > 0 && op1 > op2) ? op2 : op1;
	if (m >= min && m <= max)
		return true;
	++index;
	return (min > m && check_min(left, index, min - m, max - m))
	        || check_min(left, index, min, max);
}
bool ClientField::check_sel_sum_s(const std::set<ClientCard*>& left, size_t index, int acc) {
	if (acc < 0)
		return false;
	if (index == selected_cards.size()) {
		if (acc == 0) {
			uint32_t count = static_cast<uint32_t>(selected_cards.size()) - must_select_count;
			return count >= select_min && count <= select_max;
		}
		check_sel_sum_t(left, acc);
		return false;
	}
	auto l = selected_cards[index]->opParam;
	int l1 = l & 0xffff;
	int l2 = l >> 16;
	bool res1 = false, res2 = false;
	res1 = check_sel_sum_s(left, index + 1, acc - l1);
	if (l2 > 0)
		res2 = check_sel_sum_s(left, index + 1, acc - l2);
	return res1 || res2;
}
void ClientField::check_sel_sum_t(const std::set<ClientCard*>& left, int acc) {
	uint32_t count = static_cast<uint32_t>(selected_cards.size()) + 1 - must_select_count;
	for (auto sit = left.begin(); sit != left.end(); ++sit) {
		if (selectsum_cards.find(*sit) != selectsum_cards.end())
			continue;
		std::set<ClientCard*> testlist(left);
		testlist.erase(*sit);
		auto l = (*sit)->opParam;
		int l1 = l & 0xffff;
		int l2 = l >> 16;
		if (check_sum(testlist.begin(), testlist.end(), acc - l1, count)
		        || (l2 > 0 && check_sum(testlist.begin(), testlist.end(), acc - l2, count))) {
			selectsum_cards.insert(*sit);
		}
	}
}
bool ClientField::check_sum(std::set<ClientCard*>::const_iterator index, std::set<ClientCard*>::const_iterator end, int acc, uint32_t count) {
	if (acc == 0)
		return count >= select_min && count <= select_max;
	if (acc < 0 || index == end)
		return false;
	int l = (*index)->opParam;
	int l1 = l & 0xffff;
	int l2 = l >> 16;
	if ((l1 == acc || (l2 > 0 && l2 == acc)) && (count + 1 >= select_min) && (count + 1 <= select_max))
		return true;
	++index;
	return (acc > l1 && check_sum(index, end, acc - l1, count + 1))
	       || (l2 > 0 && acc > l2 && check_sum(index, end, acc - l2, count + 1))
	       || check_sum(index, end, acc, count);
}
size_t ClientField::UpdateDeclarableList(bool refresh) {
	CardDataM* cd = nullptr;
	auto check_code = [&, cards_end = gDataManager->cards.end()](uint32_t trycode) -> bool {
		const auto it = gDataManager->cards.find(trycode);
		cd = nullptr;
		if(it != cards_end && DataManager::IsCardDeclarable(&it->second._data, declare_opcodes, mainGame->dInfo.compat_mode))
			cd = &it->second;
		return cd;
	};
	auto ptext = mainGame->ebANCard->getText();
	if(ptext[0] == 0 && !refresh) {
		std::vector<uint32_t> cache;
		cache.swap(ancard);
		int sel = mainGame->lstANCard->getSelected();
		uint32_t selcode = (sel == -1) ? 0 : cache[sel];
		mainGame->lstANCard->clear();
		for(const auto& trycode : cache) {
			if(check_code(trycode)) {
				ancard.push_back(trycode);
				auto idx = mainGame->lstANCard->addItem(cd->GetStrings().name.data());
				if(trycode == selcode)
					mainGame->lstANCard->setSelected(idx);
			}
		}
		if(ancard.size() > 0)
			return ancard.size();
	}
	if(check_code(BufferIO::GetVal(ptext))) {
		mainGame->lstANCard->clear();
		mainGame->lstANCard->addItem(cd->GetStrings().name.data());
		ancard = { cd->_data.code };
		return ancard.size();
	}
	const auto pname = Utils::ToUpperNoAccents(ptext);
	mainGame->lstANCard->clear();
	ancard.clear();
	for(const auto& card : gDataManager->cards) {
		const auto& strings = card.second.GetStrings();
		const auto& name = strings.uppercase_name;
		if(name.find(pname) != std::wstring::npos) {
			if(DataManager::IsCardDeclarable(&card.second._data, declare_opcodes, mainGame->dInfo.compat_mode)) {
				if(pname == name) { //exact match
					mainGame->lstANCard->insertItem(0, strings.name.data(), -1);
					ancard.insert(ancard.begin(), card.first);
				} else {
					mainGame->lstANCard->addItem(strings.name.data());
					ancard.push_back(card.first);
				}
			}
		}
	}
	return ancard.size();
}
void ChainInfo::UpdateDrawCoordinates() {
	mainGame->dField.GetChainDrawCoordinates(controler, location, sequence, &chain_pos);
}
}
