extends Node
## Автозагрузка "Settings": настройки игрока в user://settings.cfg.
## Применяет звук, графику и счётчик FPS; игрок и оружие читают свои параметры сами
## и подписываются на changed.

signal changed

const PATH: String = "user://settings.cfg"
const SECTION: String = "settings"
const SENSITIVITY_MIN: float = 60.0
const SENSITIVITY_MAX: float = 400.0

## Поворот в градусах за свайп на всю высоту экрана
var look_sensitivity: float = 180.0
var invert_y: bool = false
var auto_fire: bool = true
## Громкость 0..1
var master_volume: float = 1.0
var music_volume: float = 0.7
var shadows: bool = true
## Разрешение 3D (0.5..1): ниже — быстрее на слабых телефонах
var render_scale: float = 1.0
var show_fps: bool = false
## Сила тряски камеры 0..1
var camera_shake: float = 1.0

var _fps_layer: CanvasLayer
var _fps_label: Label
var _fps_timer: float = 0.0


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	load_settings()
	_build_fps_label()
	get_tree().node_added.connect(_on_node_added)
	apply()


func _process(delta: float) -> void:
	if not show_fps:
		return
	_fps_timer -= delta
	if _fps_timer <= 0.0:
		_fps_timer = 0.5
		_fps_label.text = "FPS %d" % Engine.get_frames_per_second()


## Изменить значение и применить. key — имя переменной.
## save = false — для слайдера во время перетаскивания (сохранение по отпусканию)
func set_value(key: StringName, value: Variant, save: bool = true) -> void:
	if not key in self:
		push_warning("Settings: неизвестная настройка %s" % key)
		return
	set(key, value)
	_clamp_values()
	apply()
	if save:
		save_settings()
	changed.emit()


func apply() -> void:
	var bus: int = AudioServer.get_bus_index(&"Master")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))
		AudioServer.set_bus_mute(bus, master_volume <= 0.001)
	get_viewport().scaling_3d_scale = render_scale
	_fps_layer.visible = show_fps
	var scene: Node = get_tree().current_scene
	if scene != null:
		for node: Node in scene.find_children("*", "DirectionalLight3D", true, false):
			_apply_light(node as DirectionalLight3D)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return  # первый запуск — значения по умолчанию
	look_sensitivity = float(config.get_value(SECTION, "look_sensitivity", look_sensitivity))
	invert_y = bool(config.get_value(SECTION, "invert_y", invert_y))
	auto_fire = bool(config.get_value(SECTION, "auto_fire", auto_fire))
	master_volume = float(config.get_value(SECTION, "master_volume", master_volume))
	music_volume = float(config.get_value(SECTION, "music_volume", music_volume))
	shadows = bool(config.get_value(SECTION, "shadows", shadows))
	render_scale = float(config.get_value(SECTION, "render_scale", render_scale))
	show_fps = bool(config.get_value(SECTION, "show_fps", show_fps))
	camera_shake = float(config.get_value(SECTION, "camera_shake", camera_shake))
	_clamp_values()


func save_settings() -> void:
	var config := ConfigFile.new()
	for key: String in ["look_sensitivity", "invert_y", "auto_fire", "master_volume", "music_volume",
			"shadows", "render_scale", "show_fps", "camera_shake"]:
		config.set_value(SECTION, key, get(key))
	var err: Error = config.save(PATH)
	if err != OK:
		push_error("Settings: не удалось сохранить настройки: %s" % error_string(err))


func reset_to_defaults() -> void:
	look_sensitivity = 180.0
	invert_y = false
	auto_fire = true
	master_volume = 1.0
	music_volume = 0.7
	shadows = true
	render_scale = 1.0
	show_fps = false
	camera_shake = 1.0
	apply()
	save_settings()
	changed.emit()


func _clamp_values() -> void:
	look_sensitivity = clampf(look_sensitivity, SENSITIVITY_MIN, SENSITIVITY_MAX)
	master_volume = clampf(master_volume, 0.0, 1.0)
	music_volume = clampf(music_volume, 0.0, 1.0)
	render_scale = clampf(render_scale, 0.5, 1.0)
	camera_shake = clampf(camera_shake, 0.0, 1.0)


## Новые солнца в загружаемых сценах получают настройку теней
func _on_node_added(node: Node) -> void:
	if node is DirectionalLight3D:
		_apply_light(node as DirectionalLight3D)


func _apply_light(light: DirectionalLight3D) -> void:
	if light == null:
		return
	# Помним исходное значение, чтобы включение вернуло тени только тем, у кого они были
	if not light.has_meta(&"default_shadow"):
		light.set_meta(&"default_shadow", light.shadow_enabled)
	light.shadow_enabled = shadows and bool(light.get_meta(&"default_shadow"))


func _build_fps_label() -> void:
	_fps_layer = CanvasLayer.new()
	_fps_layer.layer = 100
	add_child(_fps_layer)
	_fps_label = Label.new()
	_fps_label.position = Vector2(12.0, 210.0)
	_fps_label.add_theme_font_size_override(&"font_size", 22)
	_fps_label.add_theme_constant_override(&"outline_size", 6)
	_fps_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_fps_label.modulate = Color(0.6, 1.0, 0.6)
	_fps_layer.add_child(_fps_label)
