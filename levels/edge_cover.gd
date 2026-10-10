class_name EdgeCover
extends Node3D
## Край карты без «пустоты»: сразу за невидимыми стенами — «стена тумана» (несколько полупрозрачных
## слоёв цвета горизонта, к внешнему краю плотнее, кверху тают в небо), за ней — земля того же цвета
## и страховочный пол (не упасть под карту). Внутри карты туман не меняется — видно, как раньше.
## Работает на любом рендере (простые прозрачные сетки, без тумана движка).
## Размер карты берётся из узла Bounds (StaticBody3D со стенами). Ставит MissionManager.

const GROUND_SIZE: float = 1200.0
const SAFETY_FLOOR_Y: float = -1.5
## Слои стены тумана: отступ наружу от стены (м) и непрозрачность у земли
const LAYER_OFFSETS: PackedFloat32Array = [0.6, 3.0, 6.0, 10.0]
const LAYER_ALPHAS: PackedFloat32Array = [0.35, 0.55, 0.8, 1.0]
## Высота стены тумана; верхняя часть плавно уходит в прозрачность
const WALL_HEIGHT: float = 30.0
## Цвет подстраивается под горизонт (день/ночь) раз в столько секунд
const COLOR_SYNC_INTERVAL: float = 0.5
const FALLBACK_COLOR: Color = Color(0.62, 0.64, 0.66)


## Добавить в сцену (один раз)
static func apply(scene: Node) -> void:
	if scene == null or scene.has_node(^"EdgeCover"):
		return
	var cover := EdgeCover.new()
	cover.name = "EdgeCover"
	scene.add_child(cover)


var _environment: Environment
var _sky_material: ProceduralSkyMaterial
var _materials: Array[StandardMaterial3D] = []
var _ground_material: StandardMaterial3D
var _sync_timer: float = 0.0


func _ready() -> void:
	# Уровень с водой (порт) опускает край ниже воды: метаданные корня edge_cover_y
	var scene_root: Node = get_parent()
	if scene_root != null and scene_root.has_meta(&"edge_cover_y"):
		position.y = float(scene_root.get_meta(&"edge_cover_y"))
	_find_environment()
	var half: Vector2 = _measure_half_size()
	_build_ground()
	_build_safety_floor()
	_build_fog_walls(half)
	_sync_color()


func _process(delta: float) -> void:
	_sync_timer -= delta
	if _sync_timer <= 0.0:
		_sync_timer = COLOR_SYNC_INTERVAL
		_sync_color()


## Небо уровня заменили (LevelDressing: время суток) — взять новое и сразу перекрасить край
func refresh_environment() -> void:
	_find_environment()
	_sync_color()


func _find_environment() -> void:
	for node: Node in get_parent().find_children("*", "WorldEnvironment", true, false):
		var world := node as WorldEnvironment
		if world != null and world.environment != null:
			_environment = world.environment
			if _environment.sky != null:
				_sky_material = _environment.sky.sky_material as ProceduralSkyMaterial
			return


## Цвет горизонта: небо (его меняет смена дня и ночи), иначе цвет тумана уровня
func _horizon_color() -> Color:
	if _sky_material != null:
		return _sky_material.sky_horizon_color
	if _environment != null and _environment.fog_enabled:
		return _environment.fog_light_color
	return FALLBACK_COLOR


func _sync_color() -> void:
	var color: Color = _horizon_color()
	if _ground_material != null and not _ground_material.albedo_color.is_equal_approx(color):
		_ground_material.albedo_color = color
	for i in _materials.size():
		var layer_color := Color(color, LAYER_ALPHAS[i])
		if not _materials[i].albedo_color.is_equal_approx(layer_color):
			_materials[i].albedo_color = layer_color


## Полуразмер карты по стенам Bounds: x — по боковым стенам, y — по передней/задней; нет стен — 30 м
func _measure_half_size() -> Vector2:
	var scene: Node = get_parent()
	var bounds := scene.find_child("Bounds", true, false) as StaticBody3D
	var half := Vector2.ZERO
	if bounds != null:
		for child: Node in bounds.get_children():
			var shape := child as CollisionShape3D
			if shape == null:
				continue
			var at: Vector3 = shape.global_position
			if absf(at.x) > absf(at.z):
				half.x = maxf(half.x, absf(at.x))
			else:
				half.y = maxf(half.y, absf(at.z))
	if half.x <= 1.0 or half.y <= 1.0:
		push_warning("EdgeCover: у '%s' нет стен Bounds — край по 30 м" % scene.name)
		half = Vector2(maxf(half.x, 30.0), maxf(half.y, 30.0))
	return half


## Стена тумана по периметру: слои вертикальных полос с градиентом (снизу плотно, вверху прозрачно)
func _build_fog_walls(half: Vector2) -> void:
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0, 0.0))  # верх — прозрачный
	fade.set_color(1, Color(1.0, 1.0, 1.0, 1.0))  # низ — плотный
	fade.add_point(0.55, Color(1.0, 1.0, 1.0, 0.85))
	var texture := GradientTexture2D.new()
	texture.gradient = fade
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	texture.width = 4
	texture.height = 64
	for i in LAYER_OFFSETS.size():
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.disable_fog = true
		material.albedo_texture = texture
		material.albedo_color = Color(FALLBACK_COLOR, LAYER_ALPHAS[i])
		material.render_priority = -i  # дальние слои рисуются раньше
		_materials.append(material)
		var offset: float = LAYER_OFFSETS[i]
		var span_x: float = (half.x + offset) * 2.0
		var span_z: float = (half.y + offset) * 2.0
		# Север/юг — вдоль X, запад/восток — вдоль Z
		_add_strip(Vector3(0.0, 0.0, -(half.y + offset)), 0.0, span_x, material)
		_add_strip(Vector3(0.0, 0.0, half.y + offset), PI, span_x, material)
		_add_strip(Vector3(-(half.x + offset), 0.0, 0.0), PI * 0.5, span_z, material)
		_add_strip(Vector3(half.x + offset, 0.0, 0.0), -PI * 0.5, span_z, material)


func _add_strip(at: Vector3, yaw: float, length: float, material: StandardMaterial3D) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(length, WALL_HEIGHT)
	var strip := MeshInstance3D.new()
	strip.mesh = quad
	strip.material_override = material
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	strip.position = at + Vector3.UP * (WALL_HEIGHT * 0.5 - 0.5)
	strip.rotation.y = yaw
	add_child(strip)


## Земля за краем — без освещения и тумана, цвета горизонта: нет границы «пол / пустота»
func _build_ground() -> void:
	_ground_material = StandardMaterial3D.new()
	_ground_material.albedo_color = FALLBACK_COLOR
	_ground_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ground_material.disable_fog = true
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * GROUND_SIZE
	plane.material = _ground_material
	var ground := MeshInstance3D.new()
	ground.name = "FarGround"
	ground.mesh = plane
	ground.position.y = -0.06
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)


## Пол под всей картой: если кто-то провалился сквозь щель — стоит на нём, а не падает в небо
func _build_safety_floor() -> void:
	var body := StaticBody3D.new()
	body.name = "SafetyFloor"
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	var box := BoxShape3D.new()
	box.size = Vector3(GROUND_SIZE, 1.0, GROUND_SIZE)
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position.y = SAFETY_FLOOR_Y - 0.5
	body.add_child(shape)
	add_child(body)
