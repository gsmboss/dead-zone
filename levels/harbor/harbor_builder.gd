class_name HarborBuilder
extends LocationBuilder
## «Южный порт»: на севере — вода (z < QUAY_Z) с пришвартованным сухогрузом, буксиром и лодками,
## деревянный пирс (узел Pier) и каменный мол с маяком (узел Mole) — пол из CSGBox3D в сцене уровня.
## На берегу — портальный кран из примитивов, штабеля контейнеров, грузы, фонари, бочки с огнём.
## Края причала — невидимые стены (в воду не упасть), по ним же строится навмеш.
## Модели: Kenney Watercraft Kit и Pirate Kit (CC0), models/harbor/.

const WATER: String = "res://models/harbor/watercraft/"
const PIRATE: String = "res://models/harbor/pirate/"
const ENV: String = "res://models/environment/"
const VEH: String = "res://models/vehicles/"
## Линия причала: севернее — вода
const QUAY_Z: float = -10.0
## Пирс и мол (как узлы Pier и Mole в сцене): x от и до, конец по z
const PIER_X: Vector2 = Vector2(-19.0, -13.0)
const PIER_END_Z: float = -26.0
const MOLE_X: float = 14.0
const WATER_Y: float = -0.8
const WALL_HEIGHT: float = 4.0
## Контейнеры Watercraft: 1.38×1.1×2.76 → ~3×2.4×6 м
const CONTAINER_SCALE: float = 2.2
const CONTAINERS: Array[String] = ["res://models/harbor/watercraft/cargo-container-a.glb",
	"res://models/harbor/watercraft/cargo-container-b.glb", "res://models/harbor/watercraft/cargo-container-c.glb"]
const COVER: Array[String] = ["res://models/harbor/pirate/crate.glb", "res://models/harbor/pirate/crate-bottles.glb",
	"res://models/harbor/pirate/barrel.glb", "res://models/environment/Pallet.gltf",
	"res://models/environment/CinderBlock.gltf", "res://models/environment/Wheels_Stack.gltf"]
const PILES: Array[String] = ["res://models/harbor/watercraft/cargo-pile-a.glb",
	"res://models/harbor/watercraft/cargo-pile-b.glb"]
const WRECKS: Array[String] = ["res://models/vehicles/Vehicle_Truck.gltf", "res://models/vehicles/Vehicle_Pickup.gltf"]
const LIGHTHOUSE_AT: Vector3 = Vector3(22.0, 0.0, -21.0)
const LIGHTHOUSE_SCALE: float = 1.5
const CRANE_COLOR: Color = Color(0.95, 0.58, 0.1)

var _curb: StandardMaterial3D
var _bollard: CylinderMesh

const WATER_SHADER: String = """
shader_type spatial;
uniform vec4 deep_color : source_color = vec4(0.05, 0.2, 0.26, 1.0);
uniform vec4 crest_color : source_color = vec4(0.18, 0.38, 0.42, 1.0);

void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float wave_a = sin(world.x * 0.35 + TIME * 0.9 + world.z * 0.12);
	float wave_b = sin(world.z * 0.55 - TIME * 0.7 + world.x * 0.21);
	float mixing = clamp((wave_a + wave_b) * 0.25 + 0.5, 0.0, 1.0);
	ALBEDO = mix(deep_color.rgb, crest_color.rgb, mixing * mixing);
	vec3 tilt = vec3(cos(world.x * 0.35 + TIME * 0.9) * 0.12, 0.0, cos(world.z * 0.55 - TIME * 0.7) * 0.12);
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(tilt, 0.0)).xyz);
	ROUGHNESS = 0.12;
	METALLIC = 0.15;
	SPECULAR = 0.7;
}
"""


func _init() -> void:
	outside_ground = false
	fog_color = Color(0.46, 0.53, 0.58)
	fog_density = 0.016
	sun_color = Color(1.0, 0.9, 0.78)
	sun_energy = 0.95
	ground_color = Color(0.36, 0.36, 0.37)


func _build_location() -> void:
	_build_water()
	_build_quay_walls()
	_build_pier_and_mole()
	_build_ships()
	_build_crane(Vector3(-3.5, 0.0, -5.5))
	_build_lighthouse()
	_build_container_yard()
	_build_land_fence()
	_scatter(PILES, 5, Vector2(1.4, 1.6), 3.0)
	_scatter(COVER, 22, Vector2(0.75, 1.0), 1.6)
	_scatter(WRECKS, 2, Vector2(1.0, 1.0), 4.0)
	_explosive_barrels(6)
	for i in 3:
		var at := Vector3(_rng.randf_range(-22.0, 10.0), 0.0, _rng.randf_range(-6.0, 22.0))
		if _is_free(at, 1.0):
			_place(PIRATE + "barrel.glb", at, 0.0, 0.75)
			_fire(at, 0.95, 8.0)
			_keep_clear.append(at)


# ---------- Общие заготовки (их же берёт сюжетное кино StoryStage) ----------

## Материал воды: волны цветом и бликами (без сетки с вершинами — дёшево на телефоне)
static func make_water_material(deep: Color = Color(0.05, 0.2, 0.26),
		crest: Color = Color(0.18, 0.38, 0.42)) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = WATER_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter(&"deep_color", deep)
	material.set_shader_parameter(&"crest_color", crest)
	return material


## Портальный кран из примитивов под parent: 4 ноги, рама, стрела к -Z (над водой), кабина, трос.
## Возвращает центры ног (для коллизий)
static func make_crane(parent: Node3D, base: Vector3, height: float, boom_to_z: float) -> Array[Vector3]:
	var material := StandardMaterial3D.new()
	material.albedo_color = CRANE_COLOR
	material.roughness = 0.6
	material.metallic = 0.3
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.2, 0.2, 0.22)
	var span_x: float = 5.0
	var span_z: float = 7.0
	var legs: Array[Vector3] = []
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var leg_at: Vector3 = base + Vector3(corner.x * span_x * 0.5, height * 0.5, corner.y * span_z * 0.5)
		_crane_part(parent, leg_at, Vector3(0.6, height, 0.6), material)
		legs.append(leg_at)
	# Поперечины рамы и связи между ногами
	for side: float in [-1.0, 1.0]:
		_crane_part(parent, base + Vector3(side * span_x * 0.5, height, 0.0), Vector3(0.7, 0.8, span_z + 0.6), material)
		_crane_part(parent, base + Vector3(side * span_x * 0.5, height * 0.37, 0.0), Vector3(0.35, 0.35, span_z), material)
	for side: float in [-1.0, 1.0]:
		_crane_part(parent, base + Vector3(0.0, height * 0.37, side * span_z * 0.5), Vector3(span_x, 0.35, 0.35), material)
	# Стрела: от противовеса на суше до края над водой
	var boom_from: float = base.z + 9.0
	_crane_part(parent, Vector3(base.x, height + 1.0, (boom_from + boom_to_z) * 0.5),
		Vector3(1.6, 1.2, boom_from - boom_to_z), material)
	_crane_part(parent, Vector3(base.x, height + 0.4, boom_from - 1.5), Vector3(3.0, 2.0, 3.0), dark)  # противовес
	_crane_part(parent, Vector3(base.x + 1.4, height - 0.6, base.z - 2.0), Vector3(1.8, 1.8, 2.2), material)  # кабина
	var hook_z: float = lerpf(base.z - span_z * 0.5, boom_to_z, 0.6)
	_crane_part(parent, Vector3(base.x, height - 3.5, hook_z), Vector3(0.08, 7.0, 0.08), dark)  # трос
	_crane_part(parent, Vector3(base.x, height - 7.2, hook_z), Vector3(1.2, 0.4, 2.4), dark)  # захват
	return legs


static func _crane_part(parent: Node3D, at: Vector3, part_size: Vector3, material: Material) -> void:
	var box := BoxMesh.new()
	box.size = part_size
	box.material = material
	var part := MeshInstance3D.new()
	part.mesh = box
	part.position = at
	parent.add_child(part)


## Свет маяка под parent: лампа и вращающийся луч (полупрозрачный конус) в точке top
static func make_lighthouse_light(parent: Node3D, top: Vector3, beam_length: float = 30.0,
		beam_alpha: float = 0.22) -> Node3D:
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.92, 0.7)
	glow.light_energy = 1.6
	glow.omni_range = 12.0
	glow.position = top
	parent.add_child(glow)
	var pivot := Node3D.new()
	pivot.name = "LighthouseBeam"
	pivot.position = top
	parent.add_child(pivot)
	var beam_material := StandardMaterial3D.new()
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam_material.albedo_color = Color(1.0, 0.9, 0.6, beam_alpha)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.3
	cone.bottom_radius = beam_length * 0.1
	cone.height = beam_length
	cone.radial_segments = 10
	cone.cap_top = false
	cone.cap_bottom = false
	cone.material = beam_material
	var beam := MeshInstance3D.new()
	beam.mesh = cone
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Конус лёжа: узкий конец у лампы, широкий — наружу по +X
	beam.rotation = Vector3(0.0, 0.0, PI * 0.5)
	beam.position = Vector3(beam_length * 0.5, 0.0, 0.0)
	pivot.add_child(beam)
	var turn: Tween = pivot.create_tween().set_loops()
	turn.tween_property(pivot, ^"rotation:y", TAU, 8.0).from(0.0)
	return pivot


# ---------- Вода и берега ----------

func _build_water() -> void:
	# Днём в тумане тёмная вода сливалась с бетоном — ярче и зеленее
	var material: ShaderMaterial = make_water_material(Color(0.07, 0.34, 0.44), Color(0.28, 0.58, 0.64))
	var plane := PlaneMesh.new()
	plane.size = Vector2(1200.0, 1200.0)
	plane.material = material
	var water := MeshInstance3D.new()
	water.name = "Water"
	water.mesh = plane
	water.position = Vector3(0.0, WATER_Y, 0.0)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	# Суша за краем площадки (юг, запад и восток от причала) — вода видна только с моря
	var land := MeshInstance3D.new()
	land.name = "OutsideLand"
	var land_plane := PlaneMesh.new()
	land_plane.size = Vector2(1200.0, 600.0)
	var land_material := StandardMaterial3D.new()
	land_material.albedo_color = ground_color.darkened(0.1)
	land_material.roughness = 1.0
	land_plane.material = land_material
	land.mesh = land_plane
	land.position = Vector3(0.0, -0.04, QUAY_Z + 300.0)
	land.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(land)


## Невидимые стены по кромке причала, пирса и мола + жёлтый бордюр и кнехты
func _build_quay_walls() -> void:
	var edge: float = half_size + 2.0
	# Причал: от западной стены до пирса и от пирса до мола
	_edge_wall(Vector2(-edge, QUAY_Z), Vector2(PIER_X.x, QUAY_Z))
	_edge_wall(Vector2(PIER_X.y, QUAY_Z), Vector2(MOLE_X, QUAY_Z))
	# Пирс: бока и конец
	_edge_wall(Vector2(PIER_X.x, QUAY_Z), Vector2(PIER_X.x, PIER_END_Z))
	_edge_wall(Vector2(PIER_X.y, QUAY_Z), Vector2(PIER_X.y, PIER_END_Z))
	_edge_wall(Vector2(PIER_X.x, PIER_END_Z), Vector2(PIER_X.y, PIER_END_Z))
	# Мол: западный край до северной стены уровня
	_edge_wall(Vector2(MOLE_X, QUAY_Z), Vector2(MOLE_X, -edge))


## Стена (коллизия) и бордюр (вид) вдоль кромки от a до b (x, z)
func _edge_wall(a: Vector2, b: Vector2) -> void:
	var middle: Vector2 = (a + b) * 0.5
	var length: float = a.distance_to(b)
	var along_x: bool = absf(b.x - a.x) > absf(b.y - a.y)
	var wall_size: Vector3 = Vector3(length, WALL_HEIGHT, 0.3) if along_x else Vector3(0.3, WALL_HEIGHT, length)
	_batch.add_box(Vector3(middle.x, WALL_HEIGHT * 0.5, middle.y), wall_size)
	var curb := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(length, 0.14, 0.35) if along_x else Vector3(0.35, 0.14, length)
	box.material = _curb_material()
	curb.mesh = box
	curb.position = Vector3(middle.x, 0.07, middle.y)
	curb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(curb)
	# Кнехты каждые 6 м
	var count: int = int(length / 6.0)
	for i in count:
		var t: float = (float(i) + 0.5) / float(count)
		var at: Vector2 = a.lerp(b, t)
		var bollard := MeshInstance3D.new()
		bollard.mesh = _bollard_mesh()
		bollard.position = Vector3(at.x, 0.3, at.y)
		add_child(bollard)


func _curb_material() -> StandardMaterial3D:
	if _curb == null:
		_curb = StandardMaterial3D.new()
		_curb.albedo_color = Color(0.92, 0.75, 0.15)
		_curb.roughness = 0.8
	return _curb


func _bollard_mesh() -> CylinderMesh:
	if _bollard == null:
		_bollard = CylinderMesh.new()
		_bollard.top_radius = 0.22
		_bollard.bottom_radius = 0.26
		_bollard.height = 0.6
		_bollard.radial_segments = 8
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.12, 0.12, 0.13)
		material.metallic = 0.4
		material.roughness = 0.5
		_bollard.material = material
	return _bollard


## Цвета пирса (дерево) и мола (камень), сваи пирса и валуны вдоль мола
func _build_pier_and_mole() -> void:
	var pier := get_parent().get_node_or_null(^"Pier") as CSGBox3D
	if pier == null:
		push_warning("%s: нет узла Pier (CSGBox3D) — пирс без цвета" % name)
	else:
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color(0.45, 0.32, 0.2)
		wood.roughness = 0.9
		pier.material = wood
	var mole := get_parent().get_node_or_null(^"Mole") as CSGBox3D
	if mole == null:
		push_warning("%s: нет узла Mole (CSGBox3D) — мол без цвета" % name)
	else:
		var stone := StandardMaterial3D.new()
		stone.albedo_color = Color(0.48, 0.47, 0.44)
		stone.roughness = 1.0
		mole.material = stone
	# Сваи пирса по бокам — в воде
	var pile := CylinderMesh.new()
	pile.top_radius = 0.25
	pile.bottom_radius = 0.25
	pile.height = 2.0
	pile.radial_segments = 8
	var pile_material := StandardMaterial3D.new()
	pile_material.albedo_color = Color(0.28, 0.2, 0.13)
	pile.material = pile_material
	var z: float = QUAY_Z - 2.0
	while z > PIER_END_Z:
		for x: float in [PIER_X.x - 0.2, PIER_X.y + 0.2]:
			var post := MeshInstance3D.new()
			post.mesh = pile
			post.position = Vector3(x, -0.4, z)
			add_child(post)
		z -= 4.0
	# Ящики на пирсе — укрытие у края
	_place(PIRATE + "crate.glb", Vector3(PIER_X.x + 1.2, 0.0, PIER_END_Z + 3.0), 0.3, 0.9)
	_place(PIRATE + "barrel.glb", Vector3(PIER_X.y - 1.0, 0.0, PIER_END_Z + 6.0), 0.0, 0.75)
	# Валуны вдоль мола со стороны гавани (в воде — только вид)
	var stone_z: float = QUAY_Z - 3.0
	var rocks: Array[String] = [PIRATE + "rocks-a.glb", PIRATE + "rocks-b.glb", PIRATE + "rocks-c.glb"]
	while stone_z > -half_size - 4.0:
		_place(rocks[_rng.randi() % rocks.size()], Vector3(MOLE_X - 1.6, -1.6, stone_z),
			_rng.randf() * TAU, _rng.randf_range(0.7, 0.9), false)
		stone_z -= 4.5
	_place(PIRATE + "flag-high.glb", Vector3(MOLE_X + 2.0, 0.0, QUAY_Z - 2.0), 0.0, 1.4, true, Vector3(0.4, 5.0, 0.4))


## Суда в гавани (вода недоступна — без коллизий)
func _build_ships() -> void:
	# Сухогруз у причала между пирсом и молом: длинная ось вдоль X
	_place(WATER + "ship-cargo-a.glb", Vector3(0.5, WATER_Y - 0.4, -17.0), PI * 0.5, 2.0, false)
	_place(WATER + "boat-tug-a.glb", Vector3(-6.0, WATER_Y, -25.5), PI * 0.5 + 0.2, 2.2, false)
	_place(WATER + "boat-fishing-small.glb", Vector3(-24.0, WATER_Y, -15.0), 0.1, 2.0, false)
	_place(WATER + "boat-row-large.glb", Vector3(-21.5, WATER_Y + 0.1, -22.0), 1.2, 1.2, false)
	_place(WATER + "boat-row-small.glb", Vector3(-11.2, WATER_Y + 0.1, -11.6), 0.0, 1.0, false)
	for at: Vector3 in [Vector3(-26.0, WATER_Y, -26.0), Vector3(11.0, WATER_Y, -26.0), Vector3(-10.0, WATER_Y, -26.5)]:
		_place(WATER + ("buoy-flag.glb" if at.x > 0.0 else "buoy.glb"), at, 0.0, 1.3, false)
	# Затонувший парусник: накренён, торчит из воды
	var wreck: PackedScene = _scene(PIRATE + "ship-wreck.glb")
	if wreck != null:
		var basis := Basis(Vector3.UP, 0.9) * Basis(Vector3.FORWARD, 0.35)
		_batch.add(wreck, Transform3D(basis.scaled(Vector3.ONE * 1.1), Vector3(-25.0, WATER_Y - 2.4, -27.0)), false)


## Портальный кран на причале: стрела над сухогрузом, ноги — коллизии
func _build_crane(base: Vector3) -> void:
	for leg: Vector3 in make_crane(self, base, 15.0, -22.0):
		_batch.add_box(leg, Vector3(0.7, 15.0, 0.7))


## Маяк на конце мола: башня, свет наверху и вращающийся луч
func _build_lighthouse() -> void:
	_place(PIRATE + "tower-complete-large.glb", LIGHTHOUSE_AT, 0.4, LIGHTHOUSE_SCALE, true,
		Vector3(5.0, 15.0, 5.0), 4.0)
	_keep_clear.append(LIGHTHOUSE_AT)
	# Днём луч еле виден (иначе — белая труба над портом)
	make_lighthouse_light(self, LIGHTHOUSE_AT + Vector3.UP * 15.8, 30.0, 0.07)


## Контейнерный терминал на юго-западе: ряды штабелей с проходами между ними
func _build_container_yard() -> void:
	var rows: Array[float] = [7.0, 15.0]
	for row_z: float in rows:
		var x: float = -24.0
		while x < 2.0:
			var at := Vector3(x, 0.0, row_z + _rng.randf_range(-0.4, 0.4))
			if _is_free(at, 3.2):
				var yaw: float = PI * 0.5 + _rng.randf_range(-0.05, 0.05)
				_place(CONTAINERS[_rng.randi() % CONTAINERS.size()], at, yaw, CONTAINER_SCALE, true, Vector3.ZERO, 3.2)
				var levels: int = _rng.randi_range(0, 2)
				for level in levels:
					_place(CONTAINERS[_rng.randi() % CONTAINERS.size()], at + Vector3.UP * 2.43 * (level + 1),
						yaw + _rng.randf_range(-0.06, 0.06), CONTAINER_SCALE, false)
				_keep_clear.append(at)
			x += 7.5 + _rng.randf_range(0.0, 2.0)
	# Фонари вдоль причала
	var lamp_x: float = -24.0
	while lamp_x < 12.0:
		var at := Vector3(lamp_x, 0.0, QUAY_Z + 2.0)
		if _is_free(at, 0.5):
			_place(ENV + "StreetLights.gltf", at, PI, 1.0, true, Vector3(0.35, 5.0, 0.35))
		lamp_x += 12.0


## Видимая ограда по суше (юг, запад и восток от причала) — за ней стены Bounds уровня
func _build_land_fence() -> void:
	var edge: float = half_size + 0.8
	var along: float = -edge
	while along < edge:
		_place(ENV + ("TrafficBarrier_2.gltf" if _rng.randf() < 0.5 else "PlasticBarrier.gltf"),
			Vector3(along, 0.0, edge), PI, 1.0, false)
		along += 2.2
	for side: float in [-1.0, 1.0]:
		var z: float = QUAY_Z + 1.0 if side < 0.0 else -edge
		while z < edge:
			_place(ENV + ("TrafficBarrier_2.gltf" if _rng.randf() < 0.5 else "PlasticBarrier.gltf"),
				Vector3(side * edge, 0.0, z), PI * 0.5, 1.0, false)
			z += 2.2
