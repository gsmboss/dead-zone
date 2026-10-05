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
