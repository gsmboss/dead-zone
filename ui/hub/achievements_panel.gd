class_name AchievementsPanel
extends HubWindow
## Окно «ДОСТИЖЕНИЯ»: вкладки ДОСТИЖЕНИЯ (медали, прогресс, награды — начисляются сами при открытии)
## и СТАТИСТИКА (счётчики за всю игру из GameState.get_stat).

const TABS: PackedStringArray = ["ДОСТИЖЕНИЯ", "СТАТИСТИКА"]
## Статистика: [событие, подпись]
const STATS: Array = [
	[&"kill", "УБИТО ЗОМБИ"],
	[&"headshot_kill", "В ГОЛОВУ"],
	[&"melee_kill", "БЛИЖНИМ БОЕМ"],
	[&"car_kill", "СБИТО МАШИНОЙ"],
	[&"boss_kill", "БОССОВ ПОБЕЖДЕНО"],
	[&"brute_kill", "БУГАЁВ"],
	[&"screamer_kill", "КРИКУНОВ"],
	[&"helmet_off", "СБИТО КАСОК"],
	[&"mission_win", "ПОБЕД В МИССИЯХ"],
	[&"stars3", "МИССИЙ НА 3 ЗВЕЗДЫ"],
	[&"chapter", "ГЛАВ СЮЖЕТА"],
	[&"rescue", "СПАСЕНО ВЫЖИВШИХ"],
	[&"endless_wave", "ЛУЧШАЯ ВОЛНА"],
	[&"raid_win", "ОТБИТО НАБЕГОВ"],
	[&"race_finish", "ЗАЕЗДОВ"],
	[&"race_gold", "ЗОЛОТЫХ МЕДАЛЕЙ"],
	[&"drift_points", "ОЧКОВ ДРИФТА"],
	[&"deploy", "ПОСТАВЛЕНО ЛОВУШЕК"],
	[&"craft", "СОБРАНО В МАСТЕРСКОЙ"],
	[&"coins_earned", "ЗАРАБОТАНО МОНЕТ"],
	[&"daily_streak", "ЛУЧШАЯ СЕРИЯ ДНЕЙ"],
]

static var _tab: int = 0


func _ready() -> void:
	window_title = "ДОСТИЖЕНИЯ"
	GameState.achievement_unlocked.connect(_on_achievement_unlocked)
	super._ready()


func _on_achievement_unlocked(_achievement: AchievementData) -> void:
	refresh()


func _build_content() -> void:
	content.add_child(UIKit.tab_bar(TABS, _tab, func(index: int) -> void:
		_tab = index
		refresh()))
	if _tab == 0:
		_build_achievements()
	else:
		_build_stats()


func _build_achievements() -> void:
	var list: Array[AchievementData] = GameState.achievement_list.achievements
	var header := UIKit.label(UIKit.t("ПОЛУЧЕНО %d ИЗ %d") % [GameState.get_achievement_count(), list.size()], 26, content)
	header.modulate = UIKit.ACCENT
	# Сначала незавершённые, ближе к цели — выше; полученные — в конце
	var open: Array[AchievementData] = []
	var done: Array[AchievementData] = []
	for achievement: AchievementData in list:
		if achievement == null:
			continue
		if GameState.is_achievement_done(achievement.id):
			done.append(achievement)
		else:
			open.append(achievement)
	open.sort_custom(func(a: AchievementData, b: AchievementData) -> bool:
		return _share(a) > _share(b))
	for achievement: AchievementData in open + done:
		content.add_child(_make_card(achievement))


func _share(achievement: AchievementData) -> float:
	return clampf(float(GameState.get_stat(achievement.event)) / float(maxi(achievement.target, 1)), 0.0, 1.0)


func _make_card(achievement: AchievementData) -> Control:
	var done: bool = GameState.is_achievement_done(achievement.id)
	var card := UIKit.card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	card.add_child(row)
	var badge := AchievementBadge.new()
	badge.color = achievement.icon_color
	badge.locked = not done
	badge.custom_minimum_size = Vector2(72.0, 72.0)
	row.add_child(badge)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = SIZE_EXPAND_FILL
	texts.add_theme_constant_override(&"separation", 4)
	row.add_child(texts)
	var title := UIKit.label(achievement.title, 26, texts)
	title.modulate = UIKit.GOOD if done else Color.WHITE
	UIKit.label(achievement.description, 20, texts).modulate = UIKit.DIM
	if not done:
		var value: int = mini(GameState.get_stat(achievement.event), achievement.target)
		var bar := ProgressBar.new()
		bar.max_value = achievement.target
		bar.value = value
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0.0, 14.0)
		texts.add_child(bar)
		UIKit.label("%d / %d" % [value, achievement.target], 18, texts).modulate = UIKit.DIM
	var reward := UIKit.label(UIKit.t("ПОЛУЧЕНО") if done else "+" + UIKit.coins_text(achievement.reward), 22, row)
	reward.modulate = UIKit.GOOD if done else UIKit.ACCENT
	reward.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reward.custom_minimum_size.x = 170.0
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return card


func _build_stats() -> void:
	var card := UIKit.card()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 40)
	grid.add_theme_constant_override(&"v_separation", 10)
	card.add_child(grid)
	content.add_child(card)
	for entry: Array in STATS:
		var name_label := UIKit.label(str(entry[1]), 22, grid)
		name_label.size_flags_horizontal = SIZE_EXPAND_FILL
		name_label.modulate = UIKit.DIM
		var value := UIKit.label(str(GameState.get_stat(entry[0])), 24, grid)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.modulate = UIKit.ACCENT
