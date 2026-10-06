extends Node
## Регистрирует действия ввода с клавишами по умолчанию (для теста на ПК).
## Если действие уже задано в Input Map, оно не перезаписывается.

const ACTIONS: Dictionary = {
	&"move_forward": [KEY_W],
	&"move_back": [KEY_S],
	&"move_left": [KEY_A],
	&"move_right": [KEY_D],
	&"jump": [KEY_SPACE],
	&"fire": [KEY_F, KEY_CTRL],
	&"reload": [KEY_R],
	&"switch_weapon": [KEY_Q],
	&"interact": [KEY_E],
	&"aim": [KEY_Z],
	&"inventory": [KEY_I],
	&"throw": [KEY_G],
	&"sprint": [KEY_SHIFT],
	&"slide": [KEY_C],
	&"pause": [KEY_ESCAPE, KEY_P],
	&"camera_view": [KEY_V],
}
## Дополнительно: прицеливание правой кнопкой мыши
const MOUSE_ACTIONS: Dictionary = {
	&"aim": MOUSE_BUTTON_RIGHT,
}


func _enter_tree() -> void:
	for action: StringName in ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for keycode: Key in ACTIONS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action, event)
		if MOUSE_ACTIONS.has(action):
			var mouse_event := InputEventMouseButton.new()
			mouse_event.button_index = MOUSE_ACTIONS[action]
			InputMap.action_add_event(action, mouse_event)


## Кнопка «Назад» на Android (quit_on_go_back выключен): вместо выхода — действие «пауза».
## Его обрабатывают меню уровня (пауза/закрыть окно), убежище (закрыть окно / «ВЫЙТИ?»)
## и кат-сцены (пропуск)
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_tap_action(&"pause")


func _tap_action(action: StringName) -> void:
	if not InputMap.has_action(action):
		return
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	_release_action.call_deferred(action)


func _release_action(action: StringName) -> void:
	# Через кадр: иначе is_action_just_pressed не успеет сработать
	await get_tree().process_frame
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
