class_name GameMenus
extends Control
## Меню уровня (создаётся кодом): кнопки «II» (пауза) и «СУМКА» на экране,
## окно паузы (продолжить, сумка, настройки, заново, в убежище).
## Достаточно пустого Control в HUD уровня с этим скриптом.

const HUB_SCENE: String = "res://hub/hub.tscn"
const BUTTON_SIZE: float = 90.0

var _touch_controls: TouchControls
var _pause_button: TouchActionButton
var _bag_button: TouchActionButton
var _pause_panel: PanelContainer
var _window: HubWindow
## Сумка открыта прямо из HUD (закрытие — сразу в игру, без окна паузы)
var _window_from_hud: bool = false


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_pause_panel()
	_setup_buttons.call_deferred()


func _exit_tree() -> void:
	# Смена сцены во время паузы не должна оставить игру на паузе
	if get_tree() != null and get_tree().paused:
		get_tree().paused = false


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"pause"):
		if _window != null:
			_window.close_window()
		elif get_tree().paused:
			_resume()
		else:
			_pause()
	elif Input.is_action_just_pressed(&"inventory") and _window == null and not _is_player_dead():
		_open_window(InventoryPanel.new(), not get_tree().paused)


func _setup_buttons() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null or player.touch_controls == null:
		push_warning("GameMenus: игрок или TouchControls не найдены — только клавиатура")
		return
	_touch_controls = player.touch_controls
	_pause_button = _make_touch_button(&"pause", "II", Vector2(1.0, 0.0), Vector2(-120.0, 130.0))
	_bag_button = _make_touch_button(&"inventory", "СУМКА", Vector2(0.0, 0.0), Vector2(24.0, 110.0))


func _make_touch_button(action: StringName, text: String, anchor: Vector2, offset: Vector2) -> TouchActionButton:
	var button := TouchActionButton.new()
	button.action = action
	button.label = text
	button.use_action_color = false
	button.name = "%sButton" % String(action).capitalize()
	_touch_controls.add_child(button)
	button.anchor_left = anchor.x
	button.anchor_right = anchor.x
	button.anchor_top = anchor.y
	button.anchor_bottom = anchor.y
	button.offset_left = offset.x
	button.offset_top = offset.y
	button.offset_right = offset.x + BUTTON_SIZE
	button.offset_bottom = offset.y + BUTTON_SIZE
	_touch_controls.register_button(button)
	return button


# ---------- Пауза ----------

func _pause() -> void:
	if _is_player_dead():
		return
	if _touch_controls != null:
		_touch_controls.reset_all()
	get_tree().paused = true
	_pause_panel.visible = true


func _resume() -> void:
	_pause_panel.visible = false
	get_tree().paused = false


func _build_pause_panel() -> void:
	_pause_panel = PanelContainer.new()
	_pause_panel.visible = false
	_pause_panel.add_theme_stylebox_override(&"panel", UIKit.panel_style())
	add_child(_pause_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 14)
	_pause_panel.add_child(box)
	var title := UIKit.label("ПАУЗА", 44, box)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = UIKit.ACCENT

	_add_pause_button(box, "ПРОДОЛЖИТЬ", _resume)
	_add_pause_button(box, "СУМКА", func() -> void: _open_window(InventoryPanel.new(), false))
	_add_pause_button(box, "НАСТРОЙКИ", func() -> void: _open_window(SettingsPanel.new(), false))
	_add_pause_button(box, "ЗАНОВО", _restart)
	if ResourceLoader.exists(HUB_SCENE):
		_add_pause_button(box, "В УБЕЖИЩЕ", _go_to_hub)

	_pause_panel.set_anchors_and_offsets_preset(PRESET_CENTER, PRESET_MODE_MINSIZE)
	_pause_panel.grow_horizontal = GROW_DIRECTION_BOTH
	_pause_panel.grow_vertical = GROW_DIRECTION_BOTH


func _add_pause_button(parent: Control, text: String, callback: Callable) -> void:
	var button := UIKit.button(text, 28, 380.0)
	button.pressed.connect(callback)
	parent.add_child(button)


## from_hud — окно открыто кнопкой в HUD: игра на паузе, закрытие возвращает в игру
func _open_window(window: HubWindow, from_hud: bool) -> void:
	if _window != null:
		window.free()
		return
	if from_hud:
		if _touch_controls != null:
			_touch_controls.reset_all()
		get_tree().paused = true
	_window_from_hud = from_hud
	_window = window
	window.closed.connect(_on_window_closed)
	_pause_panel.visible = false
	add_child(window)


func _on_window_closed() -> void:
	_window = null
	if _window_from_hud:
		_resume()
	else:
		_pause_panel.visible = true


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _go_to_hub() -> void:
	get_tree().paused = false
	var manager := get_tree().get_first_node_in_group(&"mission_manager") as MissionManager
	if manager != null:
		manager.leave_mission()  # монеты за убитых сохраняются
	get_tree().change_scene_to_file(HUB_SCENE)


func _is_player_dead() -> bool:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	return player != null and player.health != null and player.health.is_dead
