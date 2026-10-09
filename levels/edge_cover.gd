class_name EdgeCover
extends Node3D
## Край карты без «пустоты»: большая земля за невидимыми стенами, страховочный пол (не упасть
## под карту) и туман по глубине — внутри карты видно, за стенами всё уходит в туман цвета неба.
## Размер карты берётся из узла Bounds (StaticBody3D со стенами). Ставит MissionManager.

const GROUND_SIZE: float = 1200.0
const GROUND_COLOR: Color = Color(0.27, 0.28, 0.26)
## Туман начинается на этой доле полуразмера карты и густеет до полного к FOG_END_SHARE
const FOG_BEGIN_SHARE: float = 0.75
const FOG_END_SHARE: float = 1.9
const FOG_SKY_AFFECT: float = 0.75
const SAFETY_FLOOR_Y: float = -1.5


## Добавить в сцену (один раз)
static func apply(scene: Node) -> void:
	if scene == null or scene.has_node(^"EdgeCover"):
		return
	var cover := EdgeCover.new()
	cover.name = "EdgeCover"
	scene.add_child(cover)


func _ready() -> void:
	var half: float = _measure_half_size()
	_build_ground()
	_build_safety_floor()
	_setup_fog(half)


## Полуразмер карты по стенам Bounds (самая дальняя стена); нет стен — 30 м
func _measure_half_size() -> float:
	var scene: Node = get_parent()
	var bounds := scene.find_child("Bounds", true, false) as StaticBody3D
	var half: float = 0.0
	if bounds != null:
		for child: Node in bounds.get_children():
			var shape := child as CollisionShape3D
			if shape != null:
				var at: Vector3 = shape.global_position
				half = maxf(half, maxf(absf(at.x), absf(at.z)))
	if half <= 1.0:
		push_warning("EdgeCover: у '%s' нет стен Bounds — туман по размеру 30 м" % scene.name)
		half = 30.0
	return half


func _build_ground() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = GROUND_COLOR
	material.roughness = 1.0
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * GROUND_SIZE
	plane.material = material
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


## Туман по глубине: чистая середина, плотная стена тумана за краем карты
func _setup_fog(half: float) -> void:
	var world: WorldEnvironment = null
	for node: Node in get_parent().find_children("*", "WorldEnvironment", true, false):
		world = node as WorldEnvironment
		break
	if world == null or world.environment == null:
		push_warning("EdgeCover: нет WorldEnvironment — без тумана")
		return
	var environment: Environment = world.environment
	if not environment.fog_enabled:
		environment.fog_enabled = true
		var sky_material := environment.sky.sky_material as ProceduralSkyMaterial if environment.sky != null else null
		environment.fog_light_color = sky_material.sky_horizon_color if sky_material != null else Color(0.6, 0.62, 0.64)
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_density = 1.0
	environment.fog_depth_begin = half * FOG_BEGIN_SHARE
	environment.fog_depth_end = half * FOG_END_SHARE
	environment.fog_depth_curve = 1.4
	environment.fog_sky_affect = FOG_SKY_AFFECT
