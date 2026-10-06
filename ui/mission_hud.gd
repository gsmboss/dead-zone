extends Control
## HUD миссии: цель вверху, полоска босса, объявления по центру, экран результата.
## Все элементы создаются кодом — достаточно добавить пустой Control в HUD.

const ANNOUNCE_HOLD: float = 1.2
const ANNOUNCE_FADE: float = 0.6
## Объявление «впрыгивает»: стартовый масштаб и время
const ANNOUNCE_POP_SCALE: float = 1.8
const ANNOUNCE_POP_TIME: float = 0.35
const COINS_COUNT_TIME: float = 1.2
const RESULT_POP_TIME: float = 0.4
const WIN_COLOR: Color = Color(0.55, 1.0, 0.55)
const LOSE_COLOR: Color = Color(1.0, 0.4, 0.4)
const HUB_SCENE: String = "res://hub/hub.tscn"

## Пусто → поиск по группе mission_manager
@export var mission_manager: MissionManager

var _objective: Label
var _announce: Label
var _announce_tween: Tween
var _result: PanelContainer
var _result_title: Label
var _result_stats: Label
var _result_stars: StarRating
var _result_coins: Label
var _result_tween: Tween
var _boss_box: VBoxContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _boss: Zombie
# Реклама: x2 монеты на экране итогов, воскрешение после смерти
var _double_button: Button
var _earned_coins: int = 0
var _revive_panel: PanelContainer
var _revive_timer: Label


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_ui()
	_connect_manager.call_deferred()


func _build_ui() -> void:
	# Цель миссии вверху по центру
	_objective = _make_label(self, 26)
	_objective.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	_objective.offset_top = 16.0
	_objective.offset_bottom = 56.0

	# Полоска здоровья босса под целью
	_boss_box = VBoxContainer.new()
	_boss_box.visible = false
	_boss_box.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_boss_box)
	_boss_box.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	_boss_box.offset_left = -300.0
	_boss_box.offset_right = 300.0
	_boss_box.offset_top = 62.0
	_boss_box.offset_bottom = 130.0
	_boss_name = _make_label(_boss_box, 24)
	_boss_name.modulate = LOSE_COLOR
	_boss_bar = ProgressBar.new()
	_boss_bar.mouse_filter = MOUSE_FILTER_IGNORE
	_boss_bar.show_percentage = false
	_boss_bar.custom_minimum_size = Vector2(600.0, 22.0)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	bar_bg.set_corner_radius_all(6)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.85, 0.12, 0.1)
	bar_fill.set_corner_radius_all(6)
	_boss_bar.add_theme_stylebox_override(&"background", bar_bg)
	_boss_bar.add_theme_stylebox_override(&"fill", bar_fill)
	_boss_box.add_child(_boss_bar)

	# Крупные объявления чуть выше центра
	_announce = _make_label(self, 56)
	_announce.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_announce.offset_bottom = -120.0
	_announce.modulate.a = 0.0

	# Экран результата
	_result = PanelContainer.new()
	_result.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.78)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(32.0)
	_result.add_theme_stylebox_override(&"panel", style)
	add_child(_result)

	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 18)
	_result.add_child(box)

	_result_title = _make_label(box, 48)
	_result_stars = StarRating.new()
	_result_stars.star_radius = 34.0
	_result_stars.size_flags_horizontal = SIZE_SHRINK_CENTER
	box.add_child(_result_stars)
	_result_stats = _make_label(box, 26)
	_result_coins = _make_label(box, 34)
	_result_coins.modulate = Color(1.0, 0.85, 0.3)

	_double_button = _make_button("x2 МОНЕТЫ  ▶ РЕКЛАМА")
	_double_button.modulate = Color(1.0, 0.9, 0.45)
	_double_button.visible = false
	_double_button.pressed.connect(_on_double_pressed)
	box.add_child(_double_button)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 16)
	box.add_child(buttons)

	var restart := _make_button("ЕЩЁ РАЗ")
	restart.pressed.connect(_on_restart_pressed)
	buttons.add_child(restart)

	if ResourceLoader.exists(HUB_SCENE):
		var hub := _make_button("В УБЕЖИЩЕ")
		hub.pressed.connect(_on_hub_pressed)
		buttons.add_child(hub)

	# По центру экрана, растёт в обе стороны при изменении текста
	_result.set_anchors_and_offsets_preset(PRESET_CENTER, PRESET_MODE_MINSIZE)
	_result.grow_horizontal = GROW_DIRECTION_BOTH
	_result.grow_vertical = GROW_DIRECTION_BOTH
	_result.resized.connect(func() -> void: _result.pivot_offset = _result.size * 0.5)
	_build_revive_panel()


## «ВОСКРЕСНУТЬ?» после смерти: реклама за второй шанс или поражение
func _build_revive_panel() -> void:
	_revive_panel = PanelContainer.new()
	_revive_panel.visible = false
	_revive_panel.add_theme_stylebox_override(&"panel", UIKit.panel_style(Color(0.05, 0.0, 0.0, 0.85)))
	add_child(_revive_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 16)
	_revive_panel.add_child(box)
	var title := _make_label(box, 48)
	title.text = "ВЫ ПОГИБЛИ"
	title.modulate = LOSE_COLOR
	_revive_timer = _make_label(box, 30)
	var revive := _make_button("ВОСКРЕСНУТЬ  ▶ РЕКЛАМА")
	revive.modulate = Color(0.6, 1.0, 0.6)
	revive.pressed.connect(_on_revive_pressed)
	box.add_child(revive)
	var give_up := _make_button("СДАТЬСЯ")
	give_up.pressed.connect(func() -> void:
		_revive_panel.visible = false
		if mission_manager != null:
			mission_manager.decline_revive())
	box.add_child(give_up)
	_revive_panel.set_anchors_and_offsets_preset(PRESET_CENTER, PRESET_MODE_MINSIZE)
	_revive_panel.grow_horizontal = GROW_DIRECTION_BOTH
	_revive_panel.grow_vertical = GROW_DIRECTION_BOTH


func _process(_delta: float) -> void:
	if _revive_panel == null or not _revive_panel.visible or mission_manager == null:
		return
	var left: float = mission_manager.get_revive_left()
	if left <= 0.0:
		_revive_panel.visible = false
		return
	_revive_timer.text = "ВТОРОЙ ШАНС: %d" % ceili(left)


func _on_revive_offered(_seconds: float) -> void:
	_revive_panel.visible = true


func _on_revive_pressed() -> void:
	_revive_panel.visible = false
	var shown: bool = Ads.show_rewarded(
		func() -> void: mission_manager.revive(),
		func() -> void: mission_manager.decline_revive())
	if not shown:
		mission_manager.decline_revive()


func _on_double_pressed() -> void:
	_double_button.disabled = true
	var shown: bool = Ads.show_rewarded(func() -> void:
		GameState.add_coins(_earned_coins)
		GameState.save_game()
		_double_button.visible = false
		_set_coins_text(float(_earned_coins * 2), GameState.coins)
		Sfx.play_2d(Sfx.sounds.ui_confirm, -4.0, 1.0, 0.0),
		func() -> void: _double_button.disabled = false)
	if not shown:
		_double_button.visible = false


func _make_label(parent: Control, font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_constant_override(&"outline_size", 8)
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	parent.add_child(label)
	return label


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260.0, 80.0)
	button.focus_mode = FOCUS_NONE
	button.add_theme_font_size_override(&"font_size", 28)
	UIKit.apply_3d_style(button)
	button.pressed.connect(func() -> void: Sfx.click())
	return button


func _connect_manager() -> void:
	if mission_manager == null:
		mission_manager = get_tree().get_first_node_in_group(&"mission_manager") as MissionManager
	if mission_manager == null or Net.in_match:
		hide()  # в уровне нет миссии или идёт матч по сети (свой интерфейс MatchHUD)
		return
	mission_manager.objective_changed.connect(_on_objective_changed)
	mission_manager.announcement.connect(_show_announcement)
	mission_manager.mission_finished.connect(_show_result)
	mission_manager.boss_spawned.connect(_on_boss_spawned)
	mission_manager.revive_offered.connect(_on_revive_offered)
	_objective.text = mission_manager.get_objective_text()


func _on_objective_changed(text: String) -> void:
	_objective.text = text


func _on_boss_spawned(boss: Zombie) -> void:
	if boss == null or boss.health == null:
		return
	_boss = boss
	_boss_name.text = boss.data.display_name if boss.data != null else "БОСС"
	_boss_bar.max_value = boss.health.max_health
	_boss_bar.value = boss.health.current
	_boss_box.visible = true
	boss.health.health_changed.connect(_on_boss_health_changed)
	boss.health.died.connect(_on_boss_died)


func _on_boss_health_changed(current: float, max_value: float) -> void:
	_boss_bar.max_value = max_value
	_boss_bar.value = current


func _on_boss_died() -> void:
	_boss_box.visible = false
	_boss = null


func _show_announcement(text: String) -> void:
	if _announce_tween != null and _announce_tween.is_valid():
		_announce_tween.kill()
	_announce.text = text
	_announce.modulate.a = 0.0
	_announce.pivot_offset = _announce.size * 0.5
	_announce.scale = Vector2.ONE * ANNOUNCE_POP_SCALE
	_announce_tween = create_tween()
	_announce_tween.set_parallel(true)
	_announce_tween.tween_property(_announce, "scale", Vector2.ONE, ANNOUNCE_POP_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_announce_tween.tween_property(_announce, "modulate:a", 1.0, ANNOUNCE_POP_TIME * 0.6)
	_announce_tween.set_parallel(false)
	_announce_tween.tween_interval(ANNOUNCE_HOLD)
	_announce_tween.tween_property(_announce, "modulate:a", 0.0, ANNOUNCE_FADE)


func _show_result(won: bool, stats: Dictionary) -> void:
	if _announce_tween != null and _announce_tween.is_valid():
		_announce_tween.kill()
	_announce.modulate.a = 0.0

	_result_title.text = "ПОБЕДА!" if won else "ВЫ ПОГИБЛИ"
	_result_title.modulate = WIN_COLOR if won else LOSE_COLOR
	_boss_box.visible = false

	var stars: int = int(stats.get("stars", 0))
	_result_stars.visible = won
	if won:
		_result_stars.play(stars)

	var lines := PackedStringArray()
	var level: int = int(stats.get("level", 1))
	lines.append(str(stats.get("title", "")) + ("" if level <= 1 else "  •  уровень %d" % level))
	lines.append("Убито зомби: %d" % int(stats.get("kills", 0)))
	if bool(stats.get("endless", false)):
		lines.append("Волн пройдено: %d" % int(stats.get("waves", 0)))
	lines.append("Очки: %d" % int(stats.get("score", 0)))
	lines.append("Время: %s" % MissionManager.format_time(float(stats.get("time", 0.0))))
	lines.append("Точность: %d%%  •  Здоровье: %d%%" % [
		roundi(float(stats.get("accuracy", 0.0)) * 100.0), roundi(float(stats.get("health_share", 0.0)) * 100.0)])
	_result_stats.text = "\n".join(lines)
	_result.visible = true
	_revive_panel.visible = false
	_earned_coins = int(stats.get("coins", 0))
	_double_button.disabled = false
	_double_button.visible = _earned_coins > 0 and Ads.is_rewarded_ready()

	# Окно результата «впрыгивает», монеты считаются от нуля
	_result.scale = Vector2.ONE * 0.6
	_result.modulate.a = 0.0
	if _result_tween != null and _result_tween.is_valid():
		_result_tween.kill()
	_result_tween = create_tween()
	_result_tween.set_parallel(true)
	_result_tween.tween_property(_result, "scale", Vector2.ONE, RESULT_POP_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_result_tween.tween_property(_result, "modulate:a", 1.0, RESULT_POP_TIME * 0.5)
	_result_tween.set_parallel(false)
	_result_tween.tween_method(_set_coins_text.bind(int(stats.get("total_coins", 0))),
		0.0, float(stats.get("coins", 0)), COINS_COUNT_TIME)


func _set_coins_text(value: float, total: int) -> void:
	_result_coins.text = "МОНЕТЫ +%d  (ВСЕГО %d)" % [roundi(value), total]


## После миссии — межстраничная реклама (если пора), затем переход
func _on_restart_pressed() -> void:
	Ads.after_mission(func() -> void: get_tree().reload_current_scene())


func _on_hub_pressed() -> void:
	Ads.after_mission(func() -> void: get_tree().change_scene_to_file(HUB_SCENE))
