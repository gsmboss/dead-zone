extends Control
## HUD убежища: монеты, кнопка взаимодействия, окна миссий и оружейной.
## Все элементы создаются кодом.

## Миссии для доски
@export var missions: Array[MissionData] = []

var _coins_label: Label
var _menu_bar: HBoxContainer
var _exit_panel: PanelContainer
var _daily_button: Button
var _settings_button: Button
var _base_button: Button
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
	if Input.is_action_just_pressed(&"pause") and not CutscenePlayer.is_blocking_input() \
			and not ControlLayoutEditor.is_open:
		_on_back()


## «Назад» в убежище: закрыть окно, иначе спросить про выход
func _on_back() -> void:
	if _exit_panel != null:
		_exit_panel.queue_free()
		_exit_panel = null
		return
	if _window != null:
		_window.close_window()
		return
	_show_exit_confirm()


func _show_exit_confirm() -> void:
	_exit_panel = PanelContainer.new()
	_exit_panel.add_theme_stylebox_override(&"panel", UIKit.panel_style())
	add_child(_exit_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 16)
	_exit_panel.add_child(box)
	var title := UIKit.label("ВЫЙТИ ИЗ ИГРЫ?", 40, box)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = UIKit.ACCENT
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	box.add_child(row)
	var stay := UIKit.button("ОСТАТЬСЯ", 28, 240.0)
	stay.pressed.connect(_on_back)
	row.add_child(stay)
	var quit := UIKit.button("ВЫЙТИ", 28, 240.0)
	quit.pressed.connect(func() -> void:
		GameState.save_game()
		get_tree().quit())
	row.add_child(quit)
	_exit_panel.set_anchors_and_offsets_preset(PRESET_CENTER, PRESET_MODE_MINSIZE)
	_exit_panel.grow_horizontal = GROW_DIRECTION_BOTH
	_exit_panel.grow_vertical = GROW_DIRECTION_BOTH
	_exit_panel.scale = Vector2.ONE * 0.8
	_exit_panel.pivot_offset = _exit_panel.get_combined_minimum_size() * 0.5
	create_tween().tween_property(_exit_panel, "scale", Vector2.ONE, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_ui() -> void:
	# Меню — одной строкой сверху: не закрывает джойстик и кнопки слева, монеты справа
	_menu_bar = HBoxContainer.new()
	_menu_bar.add_theme_constant_override(&"separation", 10)
	add_child(_menu_bar)
	_menu_bar.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	_menu_bar.offset_left = 16.0
	_menu_bar.offset_right = -16.0
	_menu_bar.offset_top = 12.0
	_menu_bar.offset_bottom = 12.0 + UIKit.BUTTON_HEIGHT

	_daily_button = _add_menu_button("ЕЖЕДНЕВНО", func() -> void: _open_window(DailyPanel.new()))
	_settings_button = _add_menu_button("НАСТРОЙКИ", func() -> void: _open_window(SettingsPanel.new()))
	_base_button = _add_menu_button("БАЗА", func() -> void: _open_window(BasePanel.new()))
	_add_menu_button("ПЕРСОНАЖ", func() -> void: _open_window(SkinPanel.new()))
	var online := _add_menu_button("ПО СЕТИ", func() -> void: _open_window(LobbyPanel.new()))
	online.modulate = Color(0.75, 0.95, 1.0)

	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	spacer.mouse_filter = MOUSE_FILTER_IGNORE
	_menu_bar.add_child(spacer)
	_coins_label = UIKit.label("", 26, _menu_bar)
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_coins_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_coins_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_coins_label.modulate = UIKit.ACCENT

	_interact_button = UIKit.button("", 30, 380.0)
	_interact_button.visible = false
	_interact_button.pressed.connect(_interact)
	add_child(_interact_button)
	_interact_button.set_anchors_and_offsets_preset(PRESET_CENTER_BOTTOM)
	_interact_button.offset_left = -190.0
	_interact_button.offset_right = 190.0
	_interact_button.offset_top = -140.0
	_interact_button.offset_bottom = -50.0


## Кнопка в верхней строке меню убежища
func _add_menu_button(text: String, callback: Callable) -> Button:
	var button := UIKit.button(text, 21)
	button.pressed.connect(callback)
	_menu_bar.add_child(button)
	return button


func _connect_world() -> void:
	# Вернулись из матча по сети — сразу в лобби
	if Net.is_online():
		_open_window.call_deferred(LobbyPanel.new())
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
			# Карта заражения в 3D вместо списка
			var select := MissionSelect.new()
			select.missions = missions
			_open_window(select)
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
	_menu_bar.visible = false
	_set_player_controls(false)


func _on_window_closed() -> void:
	_window = null
	_interact_button.visible = _current != null
	_menu_bar.visible = true
	# Меню «выезжает» сверху
	_menu_bar.modulate.a = 0.0
	_menu_bar.position.y = -40.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_menu_bar, "modulate:a", 1.0, 0.25)
	tween.tween_property(_menu_bar, "position:y", 12.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_set_player_controls(true)


func _set_player_controls(enabled: bool) -> void:
	if _player == null:
		return
	_player.input_enabled = enabled
	if _player.touch_controls != null:
		_player.touch_controls.visible = enabled
