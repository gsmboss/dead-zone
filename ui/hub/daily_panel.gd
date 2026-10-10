class_name DailyPanel
extends HubWindow
## Ежедневно: награда за вход (серия дней), событие недели с испытанием и три задания на сегодня.


func _ready() -> void:
	window_title = "ЕЖЕДНЕВНО"
	GameState.progress_changed.connect(refresh)
	super._ready()


func _build_content() -> void:
	var event: DailyEventData = GameState.get_daily_event()
	if event != null:
		var banner := UIKit.label(UIKit.t("СОБЫТИЕ ДНЯ: %s — %s") % [UIKit.t(event.title), UIKit.t(event.description)], 24, content)
		banner.modulate = UIKit.GOOD
	content.add_child(_make_daily_card())
	var weekly: WeeklyEventData = GameState.get_weekly_event()
	if weekly != null:
		content.add_child(_make_weekly_card(weekly))
	UIKit.label("ЗАДАНИЯ НА СЕГОДНЯ", 28, content).modulate = UIKit.ACCENT
	var quests: Array[Dictionary] = GameState.get_quests()
	if quests.is_empty():
		UIKit.label("Заданий нет", 24, content).modulate = UIKit.DIM
	for i in quests.size():
		content.add_child(_make_quest_card(i, quests[i]))


func _make_daily_card() -> Control:
	var card := UIKit.card()
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	card.add_child(box)

	UIKit.label("НАГРАДА ЗА ВХОД", 30, box)
	var streak: int = GameState.get_next_streak()
	var info := UIKit.label(UIKit.t("День серии: %d из %d. Заходи каждый день — награда растёт") % [
		streak, GameState.quest_pool.max_streak], 22, box)
	info.modulate = UIKit.DIM

	var can_claim: bool = GameState.can_claim_daily()
	var claim := UIKit.button(
		UIKit.t("ЗАБРАТЬ %s") % UIKit.coins_text(GameState.get_daily_reward()) if can_claim else "ПРИХОДИ ЗАВТРА", 28)
	claim.disabled = not can_claim
	claim.pressed.connect(_on_claim_daily)
	box.add_child(claim)
	return card


## Событие недели: что изменилось в миссиях и недельное испытание с крупной наградой
func _make_weekly_card(weekly: WeeklyEventData) -> Control:
	var card := UIKit.card()
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	card.add_child(box)
	var header := UIKit.label(UIKit.t("СОБЫТИЕ НЕДЕЛИ: %s") % UIKit.t(weekly.title), 28, box)
	header.modulate = Color(1.0, 0.6, 0.35)
	UIKit.label(UIKit.t("%s  •  ОСТАЛОСЬ ДНЕЙ: %d") % [UIKit.t(weekly.description), GameState.get_week_days_left()],
		20, box).modulate = UIKit.DIM
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	box.add_child(row)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(texts)
	var progress: int = GameState.get_weekly_progress()
	var claimed: bool = GameState.is_weekly_claimed()
	UIKit.label(UIKit.t("ИСПЫТАНИЕ: %s") % UIKit.t(weekly.challenge_text), 24, texts)
	texts.add_child(AchievementsPanel.make_bar(progress, weekly.challenge_target, Color(1.0, 0.6, 0.35)))
	UIKit.label("%d / %d" % [progress, weekly.challenge_target], 20, texts).modulate = UIKit.DIM
	var can_claim: bool = GameState.can_claim_weekly()
	var button := UIKit.button("ПОЛУЧЕНО" if claimed else "+" + UIKit.coins_text(weekly.challenge_reward), 24, 240.0)
	button.disabled = not can_claim
	button.pressed.connect(func() -> void:
		if GameState.claim_weekly() > 0:
			Sfx.play_2d(Sfx.sounds.purchase, -4.0, 1.0, 0.0)
		else:
			Sfx.error())
	row.add_child(button)
	return card


func _make_quest_card(index: int, entry: Dictionary) -> Control:
	var card := UIKit.card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	card.add_child(row)

	var quest: QuestData = GameState.quest_pool.find(str(entry.get("id", "")))
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(texts)
	if quest == null:
		UIKit.label("Неизвестное задание", 24, texts).modulate = UIKit.DIM
		return card

	var claimed: bool = bool(entry.get("claimed", false))
	var complete: bool = GameState.is_quest_complete(entry)
	var title := UIKit.label(quest.title, 26, texts)
	title.modulate = UIKit.GOOD if complete else Color.WHITE
	var progress: int = mini(int(entry.get("progress", 0)), quest.target)
	UIKit.label(UIKit.t("%d / %d  •  награда %d") % [progress, quest.target, quest.reward_coins], 22, texts).modulate = UIKit.DIM

	var button := UIKit.button("ПОЛУЧЕНО" if claimed else "ЗАБРАТЬ", 24, 220.0)
	button.disabled = claimed or not complete
	button.pressed.connect(func() -> void: _on_claim_quest(index))
	row.add_child(button)
	return card


func _on_claim_daily() -> void:
	if GameState.claim_daily() > 0:
		Sfx.play_2d(Sfx.sounds.purchase, -4.0, 1.0, 0.0)
	else:
		Sfx.error()


func _on_claim_quest(index: int) -> void:
	if GameState.claim_quest(index):
		Sfx.play_2d(Sfx.sounds.purchase, -4.0, 1.0, 0.0)
	else:
		Sfx.error()
