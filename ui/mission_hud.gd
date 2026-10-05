extends Control
## HUD миссии: цель вверху, объявления по центру, экран результата.
## Все элементы создаются кодом — достаточно добавить пустой Control в HUD.

const ANNOUNCE_HOLD: float = 1.2
const ANNOUNCE_FADE: float = 0.6
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
	_result_stats = _make_label(box, 26)

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
	return button


func _connect_manager() -> void:
	if mission_manager == null:
		mission_manager = get_tree().get_first_node_in_group(&"mission_manager") as MissionManager
	if mission_manager == null:
		hide()  # в уровне нет миссии
		return
	mission_manager.objective_changed.connect(_on_objective_changed)
	mission_manager.announcement.connect(_show_announcement)
	mission_manager.mission_finished.connect(_show_result)
	_objective.text = mission_manager.get_objective_text()


func _on_objective_changed(text: String) -> void:
	_objective.text = text


func _show_announcement(text: String) -> void:
	if _announce_tween != null and _announce_tween.is_valid():
		_announce_tween.kill()
	_announce.text = text
	_announce.modulate.a = 1.0
	_announce_tween = create_tween()
	_announce_tween.tween_interval(ANNOUNCE_HOLD)
	_announce_tween.tween_property(_announce, "modulate:a", 0.0, ANNOUNCE_FADE)


func _show_result(won: bool, stats: Dictionary) -> void:
	if _announce_tween != null and _announce_tween.is_valid():
		_announce_tween.kill()
	_announce.modulate.a = 0.0

	_result_title.text = "ПОБЕДА!" if won else "ВЫ ПОГИБЛИ"
	_result_title.modulate = WIN_COLOR if won else LOSE_COLOR

	var lines := PackedStringArray()
	lines.append(str(stats.get("title", "")))
	lines.append("Убито зомби: %d" % int(stats.get("kills", 0)))
	lines.append("Очки: %d" % int(stats.get("score", 0)))
	lines.append("Время: %s" % MissionManager.format_time(float(stats.get("time", 0.0))))
	lines.append("Монеты: +%d (всего %d)" % [int(stats.get("coins", 0)), int(stats.get("total_coins", 0))])
	_result_stats.text = "\n".join(lines)
	_result.visible = true


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()


func _on_hub_pressed() -> void:
	get_tree().change_scene_to_file(HUB_SCENE)
