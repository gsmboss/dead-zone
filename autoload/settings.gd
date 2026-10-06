extends Node
## Автозагрузка "Settings": настройки игрока в user://settings.cfg.
## Применяет звук, графику и счётчик FPS; игрок и оружие читают свои параметры сами
## и подписываются на changed.

signal changed

const PATH: String = "user://settings.cfg"
const SECTION: String = "settings"
const SENSITIVITY_MIN: float = 60.0
const SENSITIVITY_MAX: float = 400.0
## Стиль экранных кнопок
enum ButtonStyle { VOLUME_3D, FLAT, OUTLINE }
const BUTTON_STYLE_NAMES: PackedStringArray = ["3D", "ПЛОСКИЕ", "КОНТУР"]
## Цвета прицела (crosshair_color — индекс)
const CROSSHAIR_COLORS: Array[Color] = [
	Color(1, 1, 1, 0.85), Color(0.4, 1.0, 0.4, 0.9), Color(1.0, 0.9, 0.2, 0.9),
	Color(0.3, 0.9, 1.0, 0.9), Color(1.0, 0.35, 0.8, 0.9),
]
const CROSSHAIR_COLOR_NAMES: PackedStringArray = ["БЕЛЫЙ", "ЗЕЛЁНЫЙ", "ЖЁЛТЫЙ", "ГОЛУБОЙ", "РОЗОВЫЙ"]
## Гироскоп: когда работает и как часто опрашивается (Гц — «свой FPS» гироскопа)
enum GyroMode { ALWAYS, AIM_ONLY }
const GYRO_MODE_NAMES: PackedStringArray = ["ВСЕГДА", "ТОЛЬКО В ПРИЦЕЛЕ"]
const GYRO_RATES: PackedInt32Array = [30, 60, 90, 120]
## Все сохраняемые настройки и их значения по умолчанию
const DEFAULTS: Dictionary = {
	"look_sensitivity": 180.0, "invert_y": false, "auto_fire": true,
	"master_volume": 1.0, "music_volume": 0.7, "shadows": true, "render_scale": 1.0,
	"show_fps": false, "camera_shake": 1.0, "cutscenes": true,
	"button_style": 0, "button_scale": 1.0, "button_opacity": 0.38, "button_layout": {},
	"joystick_right": false, "crosshair_scale": 1.0, "crosshair_color": 0,
	"gyro_enabled": false, "gyro_mode": 0, "gyro_sensitivity_x": 1.0, "gyro_sensitivity_y": 1.0,
	"camera_mode": 0, "camera_distance": 2.6, "player_name": "",
	"gyro_invert_x": false, "gyro_invert_y": false, "gyro_smoothing": 0.3, "gyro_rate": 60,
	"damage_direction": true, "damage_flash": 1.0, "hit_shake": 1.0, "attacker_marker": true,
	"torch_auto": true,
}

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
## Показывать кат-сцены (вступление, интро миссий, появление босса)
var cutscenes: bool = true

# Кнопки и прицел
var button_style: int = ButtonStyle.VOLUME_3D
## Размер экранных кнопок (множитель)
var button_scale: float = 1.0
var button_opacity: float = 0.38
## Свои позиции кнопок: действие (String) → центр в долях экрана (Vector2 0..1)
var button_layout: Dictionary = {}
## Джойстик справа, кнопки слева (зеркальная раскладка)
var joystick_right: bool = false
var crosshair_scale: float = 1.0
var crosshair_color: int = 0

# Камера: 0 — от первого лица, 1 — от третьего
enum CameraMode { FIRST_PERSON, THIRD_PERSON }
const CAMERA_MODE_NAMES: PackedStringArray = ["1-Е ЛИЦО", "3-Е ЛИЦО"]
var camera_mode: int = CameraMode.FIRST_PERSON
## Расстояние камеры за спиной в виде от 3-го лица, м
var camera_distance: float = 2.6
## Имя в игре по сети
var player_name: String = ""

# Гироскоп
var gyro_enabled: bool = false
var gyro_mode: int = GyroMode.ALWAYS
var gyro_sensitivity_x: float = 1.0
var gyro_sensitivity_y: float = 1.0
var gyro_invert_x: bool = false
var gyro_invert_y: bool = false
## Сглаживание 0..0.9 (больше — плавнее, но с задержкой)
var gyro_smoothing: float = 0.3
## Частота опроса гироскопа, Гц
var gyro_rate: int = 60

# Эффекты урона
## Дуги и подсветка края экрана со стороны, откуда атакуют
var damage_direction: bool = true
## Яркость красной вспышки при уроне 0..1
var damage_flash: float = 1.0
## Толчок камеры при уроне 0..1
var hit_shake: float = 1.0
## По сети: метка над игроком, который в вас стреляет
var attacker_marker: bool = true
## Факел сам зажигается ночью и гаснет на рассвете
var torch_auto: bool = true

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
	for key: String in DEFAULTS:
		var value: Variant = config.get_value(SECTION, key, get(key))
		# Тип из файла может не совпасть (ручная правка, старая версия) — приводим
		match typeof(DEFAULTS[key]):
			TYPE_FLOAT:
				value = float(value) if value is float or value is int else get(key)
			TYPE_INT:
				value = int(value) if value is float or value is int else get(key)
			TYPE_BOOL:
				value = bool(value) if value is bool or value is int else get(key)
			TYPE_DICTIONARY:
				value = value if value is Dictionary else {}
			TYPE_STRING:
				value = str(value)
		set(key, value)
	_clamp_values()


func save_settings() -> void:
	var config := ConfigFile.new()
	for key: String in DEFAULTS:
		config.set_value(SECTION, key, get(key))
	var err: Error = config.save(PATH)
	if err != OK:
		push_error("Settings: не удалось сохранить настройки: %s" % error_string(err))


func reset_to_defaults() -> void:
	for key: String in DEFAULTS:
		var value: Variant = DEFAULTS[key]
		set(key, value.duplicate() if value is Dictionary else value)
	apply()
	save_settings()
	changed.emit()


func _clamp_values() -> void:
	look_sensitivity = clampf(look_sensitivity, SENSITIVITY_MIN, SENSITIVITY_MAX)
	master_volume = clampf(master_volume, 0.0, 1.0)
	music_volume = clampf(music_volume, 0.0, 1.0)
	render_scale = clampf(render_scale, 0.5, 1.0)
	camera_shake = clampf(camera_shake, 0.0, 1.0)
	button_style = clampi(button_style, 0, BUTTON_STYLE_NAMES.size() - 1)
	button_scale = clampf(button_scale, 0.7, 1.4)
	button_opacity = clampf(button_opacity, 0.15, 0.9)
	crosshair_scale = clampf(crosshair_scale, 0.5, 2.0)
	crosshair_color = clampi(crosshair_color, 0, CROSSHAIR_COLORS.size() - 1)
	gyro_mode = clampi(gyro_mode, 0, GYRO_MODE_NAMES.size() - 1)
	camera_mode = clampi(camera_mode, 0, CAMERA_MODE_NAMES.size() - 1)
	camera_distance = clampf(camera_distance, 1.5, 4.5)
	gyro_sensitivity_x = clampf(gyro_sensitivity_x, 0.1, 4.0)
	gyro_sensitivity_y = clampf(gyro_sensitivity_y, 0.1, 4.0)
	gyro_smoothing = clampf(gyro_smoothing, 0.0, 0.9)
	damage_flash = clampf(damage_flash, 0.0, 1.0)
	hit_shake = clampf(hit_shake, 0.0, 1.0)
	if not gyro_rate in GYRO_RATES:
		gyro_rate = 60


## Позиция кнопки (центр в долях экрана) из своей раскладки; Vector2.INF — нет своей
func get_button_position(action: StringName) -> Vector2:
	var value: Variant = button_layout.get(String(action), null)
	return value if value is Vector2 and (value as Vector2).is_finite() else Vector2.INF


## Сохранить раскладку из редактора
func set_layout(layout: Dictionary, right_joystick: bool) -> void:
	button_layout = layout.duplicate()
	joystick_right = right_joystick
	save_settings()
	changed.emit()


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
	# Нижний левый угол, мелко: не перекрывает меню, здоровье и кнопки
	_fps_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_fps_label.offset_left = 8.0
	_fps_label.offset_top = -30.0
	_fps_label.offset_right = 140.0
	_fps_label.offset_bottom = -4.0
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps_label.add_theme_font_size_override(&"font_size", 18)
	_fps_label.add_theme_constant_override(&"outline_size", 6)
	_fps_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_fps_label.modulate = Color(0.6, 1.0, 0.6)
	_fps_layer.add_child(_fps_label)
