extends Control
## Экран загрузки при запуске: картинка-заставка (ui/splash/splash.png) с медленным наездом
## или, если картинки нет, живая 3D-сцена (зомби в тумане), объёмное название DEAD ZONE,
## 3D-полоса загрузки с процентами и советами. Убежище грузится в фоне (load_threaded_request).

const NEXT_SCENE: String = "res://hub/hub.tscn"
const SPLASH_IMAGE: String = "res://ui/splash/splash.png"
const ZOMBIE_MODEL: String = "res://models/zombies/Zombie_Basic.gltf"
## Заставка видна не меньше этого (чтобы успеть рассмотреть)
const MIN_TIME: float = 2.8
const TIP_TIME: float = 2.6
const ZOOM: float = 0.08
const TIPS: PackedStringArray = [
	"ХЕДШОТ НАНОСИТ ДВОЙНОЙ УРОН",
	"БЕГУНЫ ЗАХОДЯТ СО СПИНЫ — ОГЛЯДЫВАЙСЯ",
	"МАШИНА СБИВАЕТ ЗОМБИ — ЖМИ «СЕСТЬ» РЯДОМ С НЕЙ",
	"ЗАХОДИ В «ЕЖЕДНЕВНО» ЗА НАГРАДОЙ",
	"ИГРАЙ С ДРУЗЬЯМИ: КНОПКА «ПО СЕТИ» В УБЕЖИЩЕ",
	"ВЗРЫВНОЙ ЗОМБИ РАЗДУВАЕТСЯ ПЕРЕД ВЗРЫВОМ — ОТБЕГИ",
	"ВИД ОТ 3-ГО ЛИЦА — КНОПКА «ВИД»",
]

var _bar: LoadingBar3D
var _percent: Label
var _tip: Label
var _background: Control
var _title: Control
var _progress: Array = []
var _shown: float = 0.0
var _time: float = 0.0
var _tip_time: float = 0.0
var _tip_index: int = 0
var _done: bool = false
var _requested: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	_build()
	var err: Error = ResourceLoader.load_threaded_request(NEXT_SCENE)
	_requested = err == OK
	if not _requested:
		push_warning("Boot: фоновая загрузка не началась (%s), загрузим сразу" % error_string(err))
	_tip_index = randi() % TIPS.size()
	_tip.text = TIPS[_tip_index]


func _process(delta: float) -> void:
	if _done:
		return
	_time += delta
	var real: float = 1.0
	var status: int = ResourceLoader.THREAD_LOAD_LOADED
	if _requested:
		status = ResourceLoader.load_threaded_get_status(NEXT_SCENE, _progress)
		real = float(_progress[0]) if not _progress.is_empty() else 0.0
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			real = 1.0
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_requested = false
	# Полоса не обгоняет ни загрузку, ни минимальное время
	var target: float = minf(real, _time / MIN_TIME)
	_shown = move_toward(_shown, target, delta * 1.5)
	_bar.value = _shown
	_percent.text = "ЗАГРУЗКА  %d%%" % roundi(_shown * 100.0)
	_animate(delta)
	if _shown >= 0.999 and status == ResourceLoader.THREAD_LOAD_LOADED:
		_finish()


func _animate(delta: float) -> void:
	# Медленный наезд на картинку
	if _background is TextureRect:
		var k: float = 1.0 + ZOOM * clampf(_time / (MIN_TIME * 2.0), 0.0, 1.0)
		_background.pivot_offset = _background.size * 0.5
		_background.scale = Vector2.ONE * k
	# Название «дышит»
	_title.scale = Vector2.ONE * (1.0 + 0.015 * sin(_time * 2.0))
	_title.pivot_offset = _title.size * 0.5
	_tip_time += delta
	if _tip_time >= TIP_TIME:
		_tip_time = 0.0
		_tip_index = (_tip_index + 1) % TIPS.size()
		_tip.text = TIPS[_tip_index]
		_tip.modulate.a = 0.0
		create_tween().tween_property(_tip, "modulate:a", 1.0, 0.4)


func _finish() -> void:
	_done = true
	var scene: PackedScene = null
	if _requested:
		scene = ResourceLoader.load_threaded_get(NEXT_SCENE) as PackedScene
	# Затемнение и переход
	var fade := ColorRect.new()
	fade.color = Color(0.0, 0.0, 0.0, 0.0)
	fade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(fade)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.35)
	await tween.finished
	if scene != null:
		get_tree().change_scene_to_packed(scene)
	else:
		get_tree().change_scene_to_file(NEXT_SCENE)


# ---------- Интерфейс ----------

func _build() -> void:
	var black := ColorRect.new()
	black.color = Color(0.02, 0.02, 0.03)
	black.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(black)

	var texture: Texture2D = load(SPLASH_IMAGE) as Texture2D if ResourceLoader.exists(SPLASH_IMAGE) else null
	if texture != null:
		var image := TextureRect.new()
		image.texture = texture
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_background = image
	else:
		_background = _build_3d_scene()
	add_child(_background)
	_background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	# Затемнение снизу под полосу и сверху под название
	add_child(_gradient(true))
	add_child(_gradient(false))

	_title = TitleText.new()
	add_child(_title)
	_title.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	_title.offset_left = -420.0
	_title.offset_right = 420.0
	_title.offset_top = 30.0
	_title.offset_bottom = 150.0

	var bottom := VBoxContainer.new()
	bottom.add_theme_constant_override(&"separation", 8)
	add_child(bottom)
	bottom.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	bottom.offset_left = 80.0
	bottom.offset_right = -80.0
	bottom.offset_top = -150.0
	bottom.offset_bottom = -28.0
	_tip = UIKit.label("", 22, bottom)
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.modulate = Color(0.85, 0.85, 0.85)
	_bar = LoadingBar3D.new()
	bottom.add_child(_bar)
	var row := HBoxContainer.new()
	bottom.add_child(row)
	var studio := UIKit.label("SALAMANDERLAB", 20, row)
	studio.modulate = Color(1.0, 1.0, 1.0, 0.6)
	studio.size_flags_horizontal = SIZE_EXPAND_FILL
	_percent = UIKit.label("", 22, row)
	_percent.modulate = UIKit.ACCENT


func _gradient(top: bool) -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.0, 0.0, 0.0, 0.0))
	gradient.set_color(1, Color(0.0, 0.0, 0.0, 0.8))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 4
	texture.height = 64
	texture.fill_from = Vector2(0.5, 1.0) if top else Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 0.0) if top else Vector2(0.5, 1.0)
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(PRESET_TOP_WIDE if top else PRESET_BOTTOM_WIDE)
	if top:
		rect.offset_bottom = 200.0
	else:
		rect.offset_top = -240.0
	return rect


## Запасной фон без картинки: зомби в красном тумане, камера медленно облетает
func _build_3d_scene() -> Control:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.08, 0.03, 0.03)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.5, 0.35, 0.35)
	environment.ambient_light_energy = 0.4
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.3, 0.08, 0.05)
	environment.fog_density = 0.08
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)

	var rim := OmniLight3D.new()
	rim.light_color = Color(1.0, 0.25, 0.1)
	rim.light_energy = 4.0
	rim.omni_range = 8.0
	rim.position = Vector3(-1.5, 2.5, -2.0)
	viewport.add_child(rim)
	var key := DirectionalLight3D.new()
	key.light_color = Color(0.7, 0.75, 1.0)
	key.light_energy = 0.6
	key.rotation_degrees = Vector3(-30.0, 25.0, 0.0)
	viewport.add_child(key)

	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.12, 0.1, 0.1)
	var plane := PlaneMesh.new()
	plane.size = Vector2(40.0, 40.0)
	plane.material = ground_material
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	viewport.add_child(ground)

	var pivot := OrbitPivot.new()
	viewport.add_child(pivot)
	var camera := Camera3D.new()
	camera.fov = 45.0
	camera.position = Vector3(0.0, 1.6, 4.2)
	# Сцена ещё не в дереве — поворот считаем без look_at
	camera.basis = Basis.looking_at(Vector3(0.0, 1.2, 0.0) - camera.position, Vector3.UP)
	pivot.add_child(camera)

	if ResourceLoader.exists(ZOMBIE_MODEL):
		var offsets: Array[Vector3] = [Vector3(0.0, 0.0, 0.0), Vector3(-1.6, 0.0, -2.5), Vector3(1.8, 0.0, -3.5)]
		for offset: Vector3 in offsets:
			var zombie := (load(ZOMBIE_MODEL) as PackedScene).instantiate() as Node3D
			if zombie == null:
				continue
			zombie.scale = Vector3.ONE * 1.6
			zombie.position = offset
			zombie.rotation.y = randf_range(-0.3, 0.3)
			viewport.add_child(zombie)
			var players: Array[Node] = zombie.find_children("*", "AnimationPlayer", true, false)
			if not players.is_empty():
				var player := players[0] as AnimationPlayer
				var anim: StringName = &"Walk" if player.has_animation(&"Walk") else &"Idle"
				if player.has_animation(anim):
					player.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
					player.play(anim)
					player.seek(randf() * 1.0, true)
	return container


## Медленное покачивание камеры вокруг сцены
class OrbitPivot extends Node3D:
	var _time: float = 0.0

	func _process(delta: float) -> void:
		_time += delta
		rotation.y = sin(_time * 0.25) * 0.5


## Название с объёмом: «выдавленные» слои снизу-справа, контур и красный отсвет
class TitleText extends Control:
	const TEXT: String = "DEAD ZONE"
	const FONT_SIZE: int = 96
	const DEPTH: int = 8

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var font: Font = ThemeDB.fallback_font
		var text_size: Vector2 = font.get_string_size(TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
		var origin := Vector2((size.x - text_size.x) * 0.5, size.y * 0.5 + font.get_ascent(FONT_SIZE) * 0.35)
		# Тень
		draw_string(font, origin + Vector2(DEPTH + 6.0, DEPTH + 10.0), TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1,
			FONT_SIZE, Color(0.0, 0.0, 0.0, 0.5))
		# Боковина: слои от тёмного к светлому
		for i in range(DEPTH, 0, -1):
			var shade: float = 0.25 + 0.35 * (1.0 - float(i) / DEPTH)
			draw_string(font, origin + Vector2(i, i), TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE,
				Color(shade * 1.4, shade * 0.35, shade * 0.2))
		draw_string_outline(font, origin, TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 6,
			Color(0.1, 0.02, 0.0))
		draw_string(font, origin, TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(1.0, 0.82, 0.3))
		# Блик по верхней половине букв
		draw_string(font, origin + Vector2(0.0, -2.0), TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE,
			Color(1.0, 1.0, 0.85, 0.25))
