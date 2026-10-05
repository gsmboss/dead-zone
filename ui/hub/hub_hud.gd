extends Control
## HUD убежища: монеты, кнопка взаимодействия, окна миссий и оружейной.
## Все элементы создаются кодом.

## Миссии для доски
@export var missions: Array[MissionData] = []

var _coins_label: Label
var _daily_button: Button
var _settings_button: Button
var _interact_button: Button
var _current: Interactable
var _window: HubWindow
var _player: Player


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_ui()
	_connect_world.call_deferred()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"interact"):
		_interact()


func _build_ui() -> void:
	_coins_label = UIKit.label("", 28, self)
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_coins_label.modulate = UIKit.ACCENT
	_coins_label.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
	_coins_label.offset_left = -420.0
	_coins_label.offset_right = -30.0
	_coins_label.offset_top = 20.0
	_coins_label.offset_bottom = 64.0

	_daily_button = UIKit.button("ЕЖЕДНЕВНО", 26, 260.0)
	_daily_button.pressed.connect(func() -> void: _open_window(DailyPanel.new()))
	add_child(_daily_button)
	_daily_button.set_anchors_and_offsets_preset(PRESET_TOP_LEFT)
	_daily_button.offset_left = 30.0
	_daily_button.offset_top = 20.0
	_daily_button.offset_right = 290.0
	_daily_button.offset_bottom = 20.0 + UIKit.BUTTON_HEIGHT

	_settings_button = UIKit.button("НАСТРОЙКИ", 26, 260.0)
	_settings_button.pressed.connect(func() -> void: _open_window(SettingsPanel.new()))
	add_child(_settings_button)
	_settings_button.set_anchors_and_offsets_preset(PRESET_TOP_LEFT)
	_settings_button.offset_left = 30.0
	_settings_button.offset_top = 36.0 + UIKit.BUTTON_HEIGHT
	_settings_button.offset_right = 290.0
	_settings_button.offset_bottom = 36.0 + UIKit.BUTTON_HEIGHT * 2.0

	_interact_button = UIKit.button("", 30, 380.0)
	_interact_button.visible = false
	_interact_button.pressed.connect(_interact)
	add_child(_interact_button)
	_interact_button.set_anchors_and_offsets_preset(PRESET_CENTER_BOTTOM)
	_interact_button.offset_left = -190.0
	_interact_button.offset_right = 190.0
	_interact_button.offset_top = -140.0
	_interact_button.offset_bottom = -50.0


func _connect_world() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as Player
	GameState.coins_changed.connect(_update_coins)
	GameState.progress_changed.connect(_update_daily_badge)
	_update_coins(GameState.coins)
	_update_daily_badge()
	for node: Node in get_tree().get_nodes_in_group(&"interactables"):
		var interactable := node as Interactable
		if interactable != null:
			interactable.player_entered.connect(_on_player_entered)
			interactable.player_exited.connect(_on_player_exited)


func _update_coins(coins: int) -> void:
	_coins_label.text = "МОНЕТЫ: %d" % coins
	# Счётчик «подпрыгивает» при изменении
	_coins_label.pivot_offset = Vector2(_coins_label.size.x, _coins_label.size.y * 0.5)
	_coins_label.scale = Vector2.ONE * 1.25
	create_tween().tween_property(_coins_label, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## «!» на кнопке, если есть что забрать
func _update_daily_badge() -> void:
	var has_rewards: bool = GameState.has_unclaimed_rewards()
	_daily_button.text = "ЕЖЕДНЕВНО  !" if has_rewards else "ЕЖЕДНЕВНО"
	_daily_button.modulate = UIKit.ACCENT if has_rewards else Color.WHITE


func _on_player_entered(interactable: Interactable) -> void:
	_current = interactable
	_interact_button.text = interactable.prompt
	_interact_button.visible = _window == null


func _on_player_exited(interactable: Interactable) -> void:
	if _current == interactable:
		_current = null
		_interact_button.visible = false


func _interact() -> void:
	if _current == null or _window != null:
		return
	match _current.action_id:
		&"missions":
			var board := MissionBoardPanel.new()
			board.missions = missions
			_open_window(board)
		&"shop":
			_open_window(ShopPanel.new())
		_:
			_current.interact()


func _open_window(window: HubWindow) -> void:
	if _window != null:
		window.free()
		return
	_window = window
	window.closed.connect(_on_window_closed)
	add_child(window)
	_interact_button.visible = false
	_daily_button.visible = false
	_settings_button.visible = false
	_set_player_controls(false)


func _on_window_closed() -> void:
	_window = null
	_interact_button.visible = _current != null
	_daily_button.visible = true
	_settings_button.visible = true
	_set_player_controls(true)


func _set_player_controls(enabled: bool) -> void:
	if _player == null:
		return
	_player.input_enabled = enabled
	if _player.touch_controls != null:
		_player.touch_controls.visible = enabled
