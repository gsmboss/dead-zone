class_name HubDecor
extends RefCounted
## Сборщики построек и обустройства убежища (BuildingData.builder, DecorData.builder):
## модели Kenney (через PropBatch — MultiMesh и коробки коллизий) и примитивы.
## Локальные оси: начало — точка постройки, «перёд» — +Z, поворот — yaw.
## Каждый сборщик возвращает места для жильцов: {"pos": Vector3, "yaw": float, "seated": bool}.

const FURNITURE: String = "res://models/furniture/"
const NATURE: String = "res://models/nature/"
const FOOD: String = "res://models/food/"
const HOLIDAY: String = "res://models/holiday/"
const INDUSTRIAL: String = "res://models/industrial/"
const SURVIVAL: String = "res://models/survival/"
## Мебель Kenney — как в зоне отдыха
const FURNITURE_SCALE: float = 2.1
## Сидящее тело: ноги на этой высоте (поза сама поднимает таз)
const BENCH_SEAT_Y: float = 0.42

static var _materials: Dictionary = {}


## Собрать по имени. root — узел убежища (мировые координаты), xform — место и поворот
static func build(builder: StringName, root: Node3D, batch: PropBatch, xform: Transform3D) -> Array[Dictionary]:
	var method: StringName = StringName("_build_" + String(builder))
	var spots: Array[Dictionary] = []
	if builder == &"" or not HubDecor.new().has_method(method):
		push_warning("HubDecor: нет сборщика «%s»" % builder)
		return spots
	var result: Variant = HubDecor.new().call(method, root, batch, xform)
	if result is Array:
		for spot: Variant in result:
			if spot is Dictionary:
				spots.append(spot)
	return spots


# ---------- Общие детали ----------

static func material(color: Color, emission: float = 0.0, transparent: bool = false) -> StandardMaterial3D:
	var key: String = "%s|%.2f|%s" % [color.to_html(), emission, transparent]
	if _materials.has(key):
		return _materials[key]
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.85
	if emission > 0.0:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = emission
	if transparent:
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		result.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials[key] = result
	return result


static func _scene(path: String) -> PackedScene:
	var scene: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
	if scene == null:
		push_warning("HubDecor: нет модели %s" % path)
	return scene


## Модель в точке local (оси постройки), поворот yaw_deg, масштаб; начало модели — как есть
static func _model(batch: PropBatch, path: String, xform: Transform3D, local: Vector3, yaw_deg: float,
		model_scale: float, collide: bool) -> void:
	var scene: PackedScene = _scene(path)
	if scene == null:
		return
	var basis := Basis(Vector3.UP, deg_to_rad(yaw_deg)).scaled(Vector3.ONE * model_scale)
	batch.add(scene, xform * Transform3D(basis, local), collide)


## Модель Kenney с началом в углу — ставим центром габаритов (как HubCamp.add_centered)
static func _centered(batch: PropBatch, path: String, xform: Transform3D, local: Vector3, yaw_deg: float,
		model_scale: float, collide: bool) -> void:
	var scene: PackedScene = _scene(path)
	if scene == null:
		return
	var bounds: AABB = batch.get_bounds(scene)
	var center := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	var basis := Basis(Vector3.UP, deg_to_rad(yaw_deg)).scaled(Vector3.ONE * model_scale)
	batch.add(scene, xform * Transform3D(basis, local) * Transform3D(Basis.IDENTITY, -center), collide)


static func _mesh(root: Node3D, mesh: Mesh, xform: Transform3D, local: Transform3D, mat: Material,
		shadow: bool = true) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	instance.transform = xform * local
	if not shadow:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(instance)
	return instance


## Коробка-примитив; collide — коробка коллизии в PropBatch
static func _box(root: Node3D, batch: PropBatch, xform: Transform3D, center: Vector3, box_size: Vector3,
		mat: Material, collide: bool = false, yaw_deg: float = 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var local := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), center)
	if collide:
		batch.add_oriented_box(xform * local, AABB(-box_size * 0.5, box_size))
	return _mesh(root, mesh, xform, local, mat)


static func _cylinder(root: Node3D, xform: Transform3D, center: Vector3, radius: float, height: float,
		mat: Material, axis: Vector3 = Vector3.UP) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	var basis := Basis.IDENTITY
	if axis != Vector3.UP:
		basis = Basis(Vector3.UP.cross(axis).normalized(), Vector3.UP.angle_to(axis))
	return _mesh(root, mesh, xform, Transform3D(basis, center), mat)


static func _sphere(root: Node3D, xform: Transform3D, center: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	return _mesh(root, mesh, xform, Transform3D(Basis.IDENTITY, center), mat, false)


## Место жильца: позиция в осях постройки, смотрит на точку look (тоже в осях постройки)
static func _spot(xform: Transform3D, local: Vector3, look: Vector3, seated: bool = false) -> Dictionary:
	var at: Vector3 = xform * local
	var target: Vector3 = xform * look
	return {"pos": at, "yaw": atan2(at.x - target.x, at.z - target.z), "seated": seated}


## Узел-пустышка в осях постройки (для анимации частей)
static func _pivot(root: Node3D, xform: Transform3D, local: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.transform = xform * Transform3D(Basis.IDENTITY, local)
	root.add_child(pivot)
	return pivot


static func _label(root: Node3D, xform: Transform3D, local: Vector3, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.outline_size = 12
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	label.position = xform * local
	root.add_child(label)


## Лампочки гирлянды между точками (свечение без источников света — дёшево)
static func _bulbs(root: Node3D, from: Vector3, to: Vector3, sag: float, count: int) -> void:
	var colors: Array[Color] = [Color(1.0, 0.3, 0.3), Color(1.0, 0.85, 0.3), Color(0.35, 1.0, 0.45),
		Color(0.35, 0.65, 1.0), Color(1.0, 0.45, 0.95)]
	var wire := material(Color(0.1, 0.1, 0.1))
	for i in count + 1:
		var t: float = float(i) / float(count)
		var at: Vector3 = from.lerp(to, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)
		if i < count:
			var next_t: float = float(i + 1) / float(count)
			var next: Vector3 = from.lerp(to, next_t) + Vector3.DOWN * sag * 4.0 * next_t * (1.0 - next_t)
			var segment := BoxMesh.new()
			segment.size = Vector3(0.02, 0.02, at.distance_to(next))
			var look := Transform3D.IDENTITY.looking_at(next - at, Vector3.UP) if not (next - at).cross(Vector3.UP).is_zero_approx() \
				else Transform3D.IDENTITY
			_mesh(root, segment, Transform3D.IDENTITY, Transform3D(look.basis, (at + next) * 0.5), wire, false)
		_sphere(root, Transform3D.IDENTITY, at + Vector3.DOWN * 0.08, 0.07, material(colors[i % colors.size()], 2.5))


# ---------- Постройки ----------

## Огород: грядки с кукурузой, пшеницей, зеленью и тыквами; ограда со стороны двора, пугало
func _build_garden(root: Node3D, batch: PropBatch, xform: Transform3D) -> Array:
	var crops: Array[String] = ["crops_cornStageD", "crops_wheatStageB", "crops_leafsStageB", "crops_cornStageD",
		"crops_wheatStageB"]
	for i in 6:
		var center := Vector3(-0.7, 0.0, -5.5 + float(i) * 2.2)
		_model(batch, NATURE + "crops_dirtDoubleRow.glb", xform, center, 90.0, 2.2, false)
		for k in 4:
			var offset := Vector3(-0.45 if k < 2 else 0.45, 0.0, -0.5 if k % 2 == 0 else 0.5)
			if i < crops.size():
				_model(batch, NATURE + crops[i] + ".glb", xform, center + offset, float(k * 70), 1.5, false)
			else:
				_model(batch, NATURE + ("crop_pumpkin" if k != 1 else "crop_melon") + ".glb", xform, center + offset,
					float(k * 70), 2.0, false)
	# Ограда со стороны двора, вход посередине
	for z: float in [-6.0, -4.0, -2.0, 2.0, 4.0, 6.0]:
		_model(batch, NATURE + "fence_simple.glb", xform, Vector3(1.9, 0.0, z), 90.0, 2.0, false)
	batch.add_box(xform * Vector3(1.9, 0.4, -4.0), Vector3(0.15, 0.8, 6.0))
	batch.add_box(xform * Vector3(1.9, 0.4, 4.0), Vector3(0.15, 0.8, 6.0))
	# Пугало в куртке
	var wood := material(Color(0.45, 0.32, 0.2))
	var jacket := material(Color(0.25, 0.4, 0.75))
	_box(root, batch, xform, Vector3(1.0, 1.0, 2.6), Vector3(0.1, 2.0, 0.1), wood)
	_box(root, batch, xform, Vector3(1.0, 1.55, 2.6), Vector3(0.1, 0.1, 1.3), wood)
	_box(root, batch, xform, Vector3(1.0, 1.4, 2.6), Vector3(0.28, 0.6, 0.5), jacket)
	_sphere(root, xform, Vector3(1.0, 2.0, 2.6), 0.2, material(Color(0.95, 0.85, 0.5)))
	_cylinder(root, xform, Vector3(1.0, 2.2, 2.6), 0.3, 0.05, material(Color(0.8, 0.65, 0.3)))
	_model(batch, SURVIVAL + "tool-hoe.glb", xform, Vector3(1.4, 0.0, -1.6), 20.0, 3.0, false)
	_model(batch, SURVIVAL + "bucket.glb", xform, Vector3(1.4, 0.0, -2.4), 0.0, 3.0, false)
	return [_spot(xform, Vector3(0.9, 0, -3.4), Vector3(-0.7, 0, -3.4)),
		_spot(xform, Vector3(0.9, 0, 5.0), Vector3(-0.7, 0, 5.3))]


## Сторожевая вышка: деревянные опоры, площадка с бортом, крыша, прожектор; дозорный наверху
func _build_watchtower(root: Node3D, batch: PropBatch, xform: Transform3D) -> Array:
	var wood := material(Color(0.5, 0.36, 0.22))
	var dark := material(Color(0.32, 0.23, 0.15))
	var height: float = 4.2
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_box(root, batch, xform, Vector3(corner.x * 1.1, height * 0.5, corner.y * 1.1), Vector3(0.22, height, 0.22),
			wood, true)
	# Раскосы
	for side: float in [-1.1, 1.1]:
		var brace := BoxMesh.new()
		brace.size = Vector3(0.12, 3.2, 0.12)
		_mesh(root, brace, xform, Transform3D(Basis(Vector3.FORWARD, 0.6), Vector3(0.0, 2.0, side)), dark)
	_box(root, batch, xform, Vector3(0.0, height, 0.0), Vector3(2.8, 0.18, 2.8), dark)
	for side: Vector3 in [Vector3(0, 0, -1.35), Vector3(0, 0, 1.35)]:
		_box(root, batch, xform, Vector3(0, height + 0.55, 0) + side, Vector3(2.8, 0.9, 0.1), wood)
	for side: Vector3 in [Vector3(-1.35, 0, 0), Vector3(1.35, 0, 0)]:
		_box(root, batch, xform, Vector3(0, height + 0.55, 0) + side, Vector3(0.1, 0.9, 2.8), wood)
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_box(root, batch, xform, Vector3(corner.x * 1.3, height + 1.3, corner.y * 1.3), Vector3(0.12, 2.4, 0.12), dark)
	var roof := PrismMesh.new()
	roof.size = Vector3(3.4, 0.9, 3.4)
	_mesh(root, roof, xform, Transform3D(Basis.IDENTITY, Vector3(0, height + 2.95, 0)), material(Color(0.55, 0.2, 0.15)))
	# Лестница
	for i in 9:
		_box(root, batch, xform, Vector3(0.0, 0.4 + i * 0.45, 1.45), Vector3(0.7, 0.07, 0.07), wood)
	_box(root, batch, xform, Vector3(-0.35, height * 0.5, 1.45), Vector3(0.07, height, 0.07), wood)
	_box(root, batch, xform, Vector3(0.35, height * 0.5, 1.45), Vector3(0.07, height, 0.07), wood)
	# Прожектор: светится и медленно водит лучом по округе
	var spot_pivot := _pivot(root, xform, Vector3(0.9, height + 1.2, -0.9))
	var lamp := MeshInstance3D.new()
	var lamp_mesh := CylinderMesh.new()
	lamp_mesh.top_radius = 0.22
	lamp_mesh.bottom_radius = 0.16
	lamp_mesh.height = 0.4
	lamp.mesh = lamp_mesh
	lamp.material_override = material(Color(1.0, 0.95, 0.75), 3.0)
	lamp.rotation.x = -PI * 0.5
	spot_pivot.add_child(lamp)
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.2
	beam_mesh.bottom_radius = 2.2
	beam_mesh.height = 22.0
	beam_mesh.cap_top = false
	beam_mesh.cap_bottom = false
	var beam := MeshInstance3D.new()
	beam.mesh = beam_mesh
	beam.material_override = material(Color(1.0, 0.95, 0.7, 0.07), 1.0, true)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5 - 0.25), Vector3(0, -1.3, -11.0))
	spot_pivot.add_child(beam)
	var sweep := spot_pivot.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	spot_pivot.rotation.y = 0.4
	sweep.tween_property(spot_pivot, "rotation:y", 2.2, 6.0)
	sweep.tween_property(spot_pivot, "rotation:y", 0.4, 6.0)
	return [_spot(xform, Vector3(-0.5, height + 0.1, 0.0), Vector3(-6.0, height, -6.0))]


## Радиостанция: решётчатая мачта, будка с рацией, антенна с мигающим огнём
func _build_radio(root: Node3D, batch: PropBatch, xform: Transform3D) -> Array:
	var steel := material(Color(0.6, 0.32, 0.24))
	var white := material(Color(0.85, 0.85, 0.85))
	var height: float = 11.0
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_box(root, batch, xform, Vector3(-1.2 + corner.x * 0.6, height * 0.5, -1.2 + corner.y * 0.6),
			Vector3(0.12, height, 0.12), steel, true)
	var y: float = 1.5
	var band: int = 0
	while y < height:
		var mat: Material = steel if band % 2 == 0 else white
		_box(root, batch, xform, Vector3(-1.2, y, -1.8), Vector3(1.3, 0.08, 0.08), mat)
		_box(root, batch, xform, Vector3(-1.2, y, -0.6), Vector3(1.3, 0.08, 0.08), mat)
		_box(root, batch, xform, Vector3(-1.8, y, -1.2), Vector3(0.08, 0.08, 1.3), mat)
		_box(root, batch, xform, Vector3(-0.6, y, -1.2), Vector3(0.08, 0.08, 1.3), mat)
		y += 1.5
		band += 1
	_box(root, batch, xform, Vector3(-1.2, height + 1.2, -1.2), Vector3(0.08, 2.4, 0.08), steel)
	var lamp := _sphere(root, xform, Vector3(-1.2, height + 2.5, -1.2), 0.18, material(Color(1.0, 0.15, 0.1), 4.0))
	var blink := lamp.create_tween().set_loops()
	blink.tween_property(lamp, "visible", false, 0.0).set_delay(0.7)
	blink.tween_property(lamp, "visible", true, 0.0).set_delay(0.5)
	# Будка радиста с навесом
	var walls := material(Color(0.42, 0.5, 0.42))
	_box(root, batch, xform, Vector3(1.0, 1.1, 0.4), Vector3(2.4, 2.2, 2.0), walls, true)
	_box(root, batch, xform, Vector3(1.0, 2.3, 0.6), Vector3(2.8, 0.15, 2.6), material(Color(0.3, 0.3, 0.32)))
	_box(root, batch, xform, Vector3(1.0, 1.4, 1.41), Vector3(1.2, 0.7, 0.04), material(Color(0.5, 0.75, 0.9), 0.4))
	# Стол с рацией снаружи под навесом
	_centered(batch, FURNITURE + "table.glb", xform, Vector3(1.0, 0.0, 2.3), 0.0, 1.6, true)
	_centered(batch, FURNITURE + "radio.glb", xform, Vector3(1.0, 0.53, 2.25), 180.0, 1.6, false)
	_centered(batch, FURNITURE + "chair.glb", xform, Vector3(1.0, 0.0, 3.2), 180.0, FURNITURE_SCALE, false)
	_label(root, xform, Vector3(1.0, 3.0, 1.6), "РАДИО", Color(0.55, 0.85, 1.0))
	return [_spot(xform, Vector3(1.0, BENCH_SEAT_Y, 3.25), Vector3(1.0, 0.0, 2.0), true)]


## Генератор: ряд солнечных панелей вдоль стены, бак, щит с лампой (перёд +Z — к двору)
func _build_generator(root: Node3D, batch: PropBatch, xform: Transform3D) -> Array:
	for x: float in [-2.5, 2.5]:
		_model(batch, INDUSTRIAL + "solar-panel-landscape-group.glb", xform, Vector3(x, 0.0, -0.3), 0.0, 3.0, true)
	_model(batch, INDUSTRIAL + "detail-tank.glb", xform, Vector3(6.2, 0.0, -0.2), 90.0, 2.6, true)
	var box := material(Color(0.35, 0.4, 0.38))
	_box(root, batch, xform, Vector3(0.0, 0.8, 1.4), Vector3(1.2, 1.6, 0.8), box, true)
	var lamp := _box(root, batch, xform, Vector3(0.0, 1.35, 1.82), Vector3(0.15, 0.15, 0.05),
		material(Color(0.3, 1.0, 0.35), 3.0))
	var blink := lamp.create_tween().set_loops()
	blink.tween_property(lamp, "visible", false, 0.0).set_delay(1.2)
	blink.tween_property(lamp, "visible", true, 0.0).set_delay(0.3)
	_box(root, batch, xform, Vector3(0.0, 1.0, 1.82), Vector3(0.7, 0.4, 0.04), material(Color(0.9, 0.75, 0.2)))
	_label(root, xform, Vector3(0.0, 2.4, 1.4), "ГЕНЕРАТОР", Color(1.0, 0.9, 0.4))
	return [_spot(xform, Vector3(0.9, 0.0, 2.4), Vector3(0.0, 0.8, 1.4))]


## Столовая: навес на столбах, плита и холодильник, два длинных стола со скамейками, еда
func _build_canteen(root: Node3D, batch: PropBatch, xform: Transform3D) -> Array:
	var wood := material(Color(0.48, 0.34, 0.22))
	var canvas := material(Color(0.85, 0.35, 0.25))
	for x: float in [-4.5, 0.0, 4.5]:
		for z: float in [-2.6, 2.6]:
			_box(root, batch, xform, Vector3(x, 1.4, z), Vector3(0.18, 2.8, 0.18), wood, true)
	var roof := PrismMesh.new()
	roof.size = Vector3(5.8, 0.9, 9.8)
	_mesh(root, roof, xform, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.0, 3.25, 0.0)), canvas)
	# Кухня у задней стены
	_centered(batch, FURNITURE + "kitchenStove.glb", xform, Vector3(-3.4, 0.0, -2.0), 0.0, FURNITURE_SCALE, true)
	_centered(batch, FURNITURE + "kitchenFridge.glb", xform, Vector3(-4.4, 0.0, -2.0), 0.0, FURNITURE_SCALE, true)
	_centered(batch, FURNITURE + "kitchenBar.glb", xform, Vector3(-2.4, 0.0, -2.0), 0.0, FURNITURE_SCALE, true)
	_model(batch, FOOD + "pot-stew.glb", xform, Vector3(-3.4, 0.95, -2.0), 0.0, 0.7, false)
	_model(batch, FOOD + "loaf.glb", xform, Vector3(-2.4, 0.9, -2.0), 30.0, 0.8, false)
	var spots: Array = [_spot(xform, Vector3(-3.0, 0.0, -1.0), Vector3(-3.4, 0.9, -2.0))]
	# Столы и скамейки: люди сидят друг напротив друга
	for x: float in [-0.8, 2.6]:
		_box(root, batch, xform, Vector3(x, 0.75, 0.6), Vector3(1.0, 0.08, 3.4), wood, true)
		for z: float in [-0.7, 1.9]:
			_box(root, batch, xform, Vector3(x, 0.37, z), Vector3(0.7, 0.74, 0.12), wood)
		for side: float in [-0.95, 0.95]:
			_box(root, batch, xform, Vector3(x + side, 0.4, 0.6), Vector3(0.35, 0.08, 3.4), wood)
			for z: float in [-0.6, 1.8]:
				_box(root, batch, xform, Vector3(x + side, 0.2, z), Vector3(0.3, 0.4, 0.1), wood)
		for z: float in [-0.3, 0.6, 1.5]:
			_model(batch, FOOD + "bowl-soup.glb", xform, Vector3(x - 0.3, 0.79, z), 0.0, 0.45, false)
			_model(batch, FOOD + "bowl-soup.glb", xform, Vector3(x + 0.3, 0.79, z), 0.0, 0.45, false)
		_model(batch, FOOD + "apple.glb", xform, Vector3(x, 0.79, 0.2), 0.0, 0.6, false)
		for z: float in [-0.3, 0.6, 1.5]:
			spots.append(_spot(xform, Vector3(x - 0.95, BENCH_SEAT_Y, z), Vector3(x, BENCH_SEAT_Y, z), true))
			spots.append(_spot(xform, Vector3(x + 0.95, BENCH_SEAT_Y, z), Vector3(x, BENCH_SEAT_Y, z), true))
	_label(root, xform, Vector3(0.0, 3.9, 0.0), "СТОЛОВАЯ", Color(1.0, 0.7, 0.45))
	return spots


# ---------- Обустройство ----------

## Флаг: мачта и полотнище, колышется на ветру
func _build_flag(root: Node3D, batch: PropBatch, xform: Transform3D) -> Array:
	# Невысокий: из центра двора не закрывает надпись DEAD ZONE в небе
	_cylinder(root, xform, Vector3(0.0, 2.2, 0.0), 0.06, 4.4, material(Color(0.75, 0.75, 0.78)))
	batch.add_box(xform * Vector3(0.0, 1.0, 0.0), Vector3(0.2, 2.0, 0.2))
	_box(root, batch, xform, Vector3(0.0, 0.15, 0.0), Vector3(0.7, 0.3, 0.7), material(Color(0.45, 0.45, 0.45)), true)
	var pivot := _pivot(root, xform, Vector3(0.0, 3.85, 0.0))
	var cloth := MeshInstance3D.new()
	var cloth_mesh := BoxMesh.new()
	cloth_mesh.size = Vector3(1.6, 1.0, 0.03)
	cloth.mesh = cloth_mesh
	cloth.material_override = material(Color(0.85, 0.2, 0.18))
	cloth.position = Vector3(0.85, 0.0, 0.0)
	pivot.add_child(cloth)
	var stripe := MeshInstance3D.new()
	var stripe_mesh := BoxMesh.new()
	stripe_mesh.size = Vector3(1.6, 0.22, 0.04)
	stripe.mesh = stripe_mesh
	stripe.material_override = material(Color(0.95, 0.85, 0.3))
	stripe.position = Vector3(0.85, 0.0, 0.0)
	pivot.add_child(stripe)
	var wave := pivot.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	wave.tween_property(pivot, "rotation:y", 0.35, 1.3)
	wave.tween_property(pivot, "rotation:y", -0.25, 1.5)
	return []


## Клумбы: ящики с цветами вокруг флага
func _build_flowers(root: Node3D, batch: PropBatch, xform: Transform3D) -> Array:
	var flowers: Array[String] = ["flower_redA", "flower_purpleA", "flower_yellowA"]
	var planter := material(Color(0.45, 0.3, 0.2))
	for i in 4:
		var angle: float = PI * 0.25 + float(i) * PI * 0.5
		var at := Vector3(cos(angle), 0.0, sin(angle)) * 2.3
		_box(root, batch, xform, at + Vector3.UP * 0.2, Vector3(1.3, 0.4, 0.6), planter, true, -rad_to_deg(angle) + 90.0)
		for k in 4:
			var offset := Vector3(-0.45 + k * 0.3, 0.38, 0.0).rotated(Vector3.UP, -angle + PI * 0.5)
			_model(batch, NATURE + flowers[(i + k) % flowers.size()] + ".glb", xform, at + offset, k * 70.0, 2.4, false)
	_model(batch, NATURE + "pot_large.glb", xform, Vector3(0.0, 0.3, 1.1), 0.0, 1.6, false)
	return [_spot(xform, Vector3(2.6, 0.0, 0.8), Vector3(1.6, 0.0, 1.6))]


## Гирлянды над костром: четыре столба и лампочки крест-накрест
func _build_garlands(root: Node3D, batch: PropBatch, xform: Transform3D) -> Array:
	var wood := material(Color(0.4, 0.3, 0.2))
	var corners: Array[Vector3] = [Vector3(-3.4, 0, -3.4), Vector3(3.4, 0, -3.4), Vector3(3.4, 0, 3.4), Vector3(-3.4, 0, 3.4)]
	for corner: Vector3 in corners:
		_box(root, batch, xform, corner + Vector3.UP * 1.6, Vector3(0.1, 3.2, 0.1), wood)
	var tops: Array[Vector3] = []
	for corner: Vector3 in corners:
		tops.append(xform * (corner + Vector3.UP * 3.1))
	for i in 4:
		_bulbs(root, tops[i], tops[(i + 1) % 4], 0.45, 12)
	_bulbs(root, tops[0], tops[2], 0.8, 16)
	_bulbs(root, tops[1], tops[3], 0.8, 16)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.75, 0.5)
	glow.light_energy = 0.6
	glow.omni_range = 7.0
	glow.position = xform * Vector3(0.0, 2.6, 0.0)
	root.add_child(glow)
	return []


## Шезлонги: два кресла-лежака и столик с газировкой
func _build_loungers(root: Node3D, batch: PropBatch, xform: Transform3D) -> Array:
	for x: float in [-0.8, 0.8]:
		_centered(batch, FURNITURE + "loungeChairRelax.glb", xform, Vector3(x, 0.0, 0.0), 180.0, FURNITURE_SCALE, true)
	_centered(batch, FURNITURE + "tableCoffee.glb", xform, Vector3(0.0, 0.0, 1.0), 0.0, 1.2, false)
	_model(batch, FOOD + "soda-can.glb", xform, Vector3(0.1, 0.42, 1.0), 0.0, 0.5, false)
	_model(batch, FOOD + "cocktail.glb", xform, Vector3(-0.15, 0.42, 1.05), 0.0, 0.5, false)
	return [_spot(xform, Vector3(-0.8, BENCH_SEAT_Y, 0.15), Vector3(-0.8, 0.0, 2.0), true),
		_spot(xform, Vector3(0.8, BENCH_SEAT_Y, 0.15), Vector3(0.8, 0.0, 2.0), true)]


## Спортуголок: турник, брусья, гиря
func _build_pullup(root: Node3D, batch: PropBatch, xform: Transform3D) -> Array:
	var steel := material(Color(0.3, 0.45, 0.65))
	for x: float in [-0.8, 0.8]:
		_cylinder(root, xform, Vector3(x, 1.2, 0.0), 0.05, 2.4, steel)
	_cylinder(root, xform, Vector3(0.0, 2.35, 0.0), 0.035, 1.7, steel, Vector3.RIGHT)
	batch.add_box(xform * Vector3(-0.8, 1.0, 0.0), Vector3(0.12, 2.0, 0.12))
	batch.add_box(xform * Vector3(0.8, 1.0, 0.0), Vector3(0.12, 2.0, 0.12))
	for z: float in [1.6, 2.2]:
		for x: float in [1.6, 2.9]:
			_cylinder(root, xform, Vector3(x, 0.6, z), 0.04, 1.2, steel)
		_cylinder(root, xform, Vector3(2.25, 1.2, z), 0.035, 1.4, steel, Vector3.RIGHT)
	var iron := material(Color(0.15, 0.15, 0.15))
	_sphere(root, xform, Vector3(-1.6, 0.18, 1.0), 0.18, iron)
	_cylinder(root, xform, Vector3(-1.6, 0.4, 1.0), 0.03, 0.18, iron, Vector3.RIGHT)
	return [_spot(xform, Vector3(0.0, 0.0, 0.6), Vector3(0.0, 1.5, 0.0))]


## Качели: рама, два сиденья качаются; рядом песочница
func _build_swings(root: Node3D, batch: PropBatch, xform: Transform3D) -> Array:
	var frame := material(Color(0.9, 0.45, 0.2))
	for x: float in [-1.6, 1.6]:
		for z: float in [-0.7, 0.7]:
			var leg := BoxMesh.new()
			leg.size = Vector3(0.1, 2.7, 0.1)
			_mesh(root, leg, xform, Transform3D(Basis(Vector3.RIGHT, -signf(z) * 0.26), Vector3(x, 1.3, z * 0.5)), frame)
		batch.add_box(xform * Vector3(x, 1.0, 0.0), Vector3(0.15, 2.0, 1.4))
	_cylinder(root, xform, Vector3(0.0, 2.6, 0.0), 0.06, 3.4, frame, Vector3.RIGHT)
	var rope := material(Color(0.25, 0.25, 0.25))
	var seat := material(Color(0.3, 0.55, 0.9))
	for i in 2:
		var x: float = -0.7 + i * 1.4
		var pivot := _pivot(root, xform, Vector3(x, 2.6, 0.0))
		for side: float in [-0.25, 0.25]:
			var line := MeshInstance3D.new()
			var line_mesh := BoxMesh.new()
			line_mesh.size = Vector3(0.025, 2.0, 0.025)
			line.mesh = line_mesh
			line.material_override = rope
			line.position = Vector3(side, -1.0, 0.0)
			pivot.add_child(line)
		var board := MeshInstance3D.new()
		var board_mesh := BoxMesh.new()
		board_mesh.size = Vector3(0.6, 0.06, 0.3)
		board.mesh = board_mesh
		board.material_override = seat
		board.position = Vector3(0.0, -2.0, 0.0)
		pivot.add_child(board)
		var swing := pivot.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var amplitude: float = 0.45 if i == 0 else 0.25
		pivot.rotation.x = -amplitude
		swing.tween_property(pivot, "rotation:x", amplitude, 1.4 + i * 0.2)
		swing.tween_property(pivot, "rotation:x", -amplitude, 1.4 + i * 0.2)
	# Песочница
	var sand := material(Color(0.9, 0.8, 0.55))
	_box(root, batch, xform, Vector3(0.0, 0.08, 2.4), Vector3(2.0, 0.16, 1.6), sand)
	for side: Vector3 in [Vector3(0, 0, -0.8), Vector3(0, 0, 0.8)]:
		_box(root, batch, xform, Vector3(0.0, 0.15, 2.4) + side, Vector3(2.1, 0.3, 0.1), frame)
	_model(batch, SURVIVAL + "bucket.glb", xform, Vector3(0.4, 0.16, 2.3), 0.0, 1.6, false)
	return [_spot(xform, Vector3(-1.4, 0.0, 1.6), Vector3(-0.7, 1.0, 0.0)),
		_spot(xform, Vector3(1.2, 0.0, 3.6), Vector3(0.0, 0.0, 2.4))]


## Ёлка с огоньками и подарками
func _build_christmas(root: Node3D, batch: PropBatch, xform: Transform3D) -> Array:
	_model(batch, HOLIDAY + "tree-snow-a.glb", xform, Vector3.ZERO, 0.0, 2.0, false)
	batch.add_box(xform * Vector3(0.0, 1.0, 0.0), Vector3(0.6, 2.0, 0.6))
	var colors: Array[Color] = [Color(1.0, 0.3, 0.3), Color(1.0, 0.85, 0.3), Color(0.4, 0.7, 1.0)]
	for i in 18:
		var height: float = 0.6 + float(i) * 0.17
		var radius: float = 1.1 * (1.0 - height / 3.9)
		var angle: float = float(i) * 2.4
		_sphere(root, xform, Vector3(cos(angle) * radius, height, sin(angle) * radius), 0.07,
			material(colors[i % colors.size()], 2.5))
	_sphere(root, xform, Vector3(0.0, 3.95, 0.0), 0.16, material(Color(1.0, 0.85, 0.2), 3.0))
	for at: Vector3 in [Vector3(1.1, 0, 0.6), Vector3(-0.9, 0, 0.9), Vector3(0.3, 0, 1.3)]:
		_model(batch, HOLIDAY + "present-a-cube.glb", xform, at, at.x * 40.0, 1.0, false)
	return [_spot(xform, Vector3(1.6, 0.0, 1.8), Vector3(0.0, 1.0, 0.0))]


## Мангал: жаровня с углями и мясом, дым, стол с хлебом
func _build_grill(root: Node3D, batch: PropBatch, xform: Transform3D) -> Array:
	var iron := material(Color(0.18, 0.18, 0.2))
	_box(root, batch, xform, Vector3(0.0, 0.75, 0.0), Vector3(1.2, 0.3, 0.45), iron, true)
	for x: float in [-0.5, 0.5]:
		for z: float in [-0.15, 0.15]:
			_box(root, batch, xform, Vector3(x, 0.3, z), Vector3(0.05, 0.6, 0.05), iron)
	_box(root, batch, xform, Vector3(0.0, 0.88, 0.0), Vector3(1.1, 0.02, 0.38), material(Color(1.0, 0.4, 0.1), 2.0))
	for i in 4:
		_model(batch, FOOD + "sausage.glb", xform, Vector3(-0.4 + i * 0.27, 0.9, 0.0), 90.0, 0.8, false)
	_model(batch, FOOD + "meat-ribs.glb", xform, Vector3(0.2, 0.9, 0.05), 0.0, 0.6, false)
	var smoke := CPUParticles3D.new()
	smoke.amount = 10
	smoke.lifetime = 2.6
	smoke.direction = Vector3.UP
	smoke.spread = 12.0
	smoke.initial_velocity_min = 0.4
	smoke.initial_velocity_max = 0.8
	smoke.gravity = Vector3(0.15, 0.2, 0.0)
	smoke.scale_amount_min = 0.5
	smoke.scale_amount_max = 1.2
	var puff := SphereMesh.new()
	puff.radius = 0.18
	puff.height = 0.36
	puff.radial_segments = 6
	puff.rings = 3
	puff.material = material(Color(0.7, 0.7, 0.7, 0.35), 0.0, true)
	smoke.mesh = puff
	smoke.position = xform * Vector3(0.0, 1.0, 0.0)
	root.add_child(smoke)
	var embers := OmniLight3D.new()
	embers.light_color = Color(1.0, 0.5, 0.2)
	embers.light_energy = 0.8
	embers.omni_range = 3.0
	embers.position = xform * Vector3(0.0, 1.1, 0.0)
	root.add_child(embers)
	_centered(batch, FURNITURE + "table.glb", xform, Vector3(1.6, 0.0, 0.0), 90.0, 1.6, true)
	_model(batch, FOOD + "loaf.glb", xform, Vector3(1.6, 0.55, -0.2), 0.0, 0.7, false)
	_model(batch, FOOD + "soda-can.glb", xform, Vector3(1.6, 0.55, 0.25), 0.0, 0.5, false)
	return [_spot(xform, Vector3(0.0, 0.0, 0.9), Vector3(0.0, 0.8, 0.0)),
		_spot(xform, Vector3(1.0, 0.0, 1.3), Vector3(0.0, 0.8, 0.0)),
		_spot(xform, Vector3(-1.0, 0.0, 1.2), Vector3(0.0, 0.8, 0.0))]


## Летний душ: кабинка, бочка на крыше, шторка
func _build_shower(root: Node3D, batch: PropBatch, xform: Transform3D) -> Array:
	var wood := material(Color(0.5, 0.36, 0.22))
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_box(root, batch, xform, Vector3(corner.x * 0.6, 1.1, corner.y * 0.6), Vector3(0.1, 2.2, 0.1), wood)
	_box(root, batch, xform, Vector3(0.0, 1.0, -0.6), Vector3(1.3, 1.8, 0.06), wood, true)
	_box(root, batch, xform, Vector3(-0.6, 1.0, 0.0), Vector3(0.06, 1.8, 1.3), wood, true)
	_box(root, batch, xform, Vector3(0.6, 1.0, 0.0), Vector3(0.06, 1.8, 1.3), wood, true)
	_box(root, batch, xform, Vector3(0.0, 1.2, 0.6), Vector3(1.2, 1.4, 0.03), material(Color(0.3, 0.65, 0.95)))
	_box(root, batch, xform, Vector3(0.0, 2.25, 0.0), Vector3(1.4, 0.1, 1.4), wood)
	_model(batch, SURVIVAL + "barrel.glb", xform, Vector3(0.0, 2.3, 0.0), 0.0, 3.0, false)
	_box(root, batch, xform, Vector3(0.0, 0.05, 0.0), Vector3(1.1, 0.1, 1.1), material(Color(0.55, 0.55, 0.55)))
	return []


## Баскетбол: щит с кольцом на стойке, разметка, мяч
func _build_basketball(root: Node3D, batch: PropBatch, xform: Transform3D) -> Array:
	var pole := material(Color(0.25, 0.25, 0.28))
	_cylinder(root, xform, Vector3(0.0, 1.6, -0.6), 0.08, 3.2, pole)
	batch.add_box(xform * Vector3(0.0, 1.5, -0.6), Vector3(0.25, 3.0, 0.25))
	_box(root, batch, xform, Vector3(0.0, 3.0, -0.3), Vector3(1.6, 1.0, 0.06), material(Color(0.95, 0.95, 0.95)))
	_box(root, batch, xform, Vector3(0.0, 2.85, -0.26), Vector3(0.6, 0.45, 0.02), material(Color(0.9, 0.2, 0.15)))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.2
	ring.outer_radius = 0.24
	_mesh(root, ring, xform, Transform3D(Basis.IDENTITY, Vector3(0.0, 2.7, 0.0)), material(Color(1.0, 0.45, 0.1)))
	var paint := material(Color(0.95, 0.95, 0.95))
	for line: Array in [[Vector3(0, 0.012, 3.0), Vector3(3.6, 0.01, 0.08)], [Vector3(-1.8, 0.012, 1.5), Vector3(0.08, 0.01, 3.0)],
			[Vector3(1.8, 0.012, 1.5), Vector3(0.08, 0.01, 3.0)], [Vector3(0, 0.012, 6.0), Vector3(6.0, 0.01, 0.08)]]:
		_mesh(root, _plain_box(line[1]), xform, Transform3D(Basis.IDENTITY, line[0]), paint, false)
	var ball := _sphere(root, xform, Vector3(0.0, 1.2, 2.2), 0.13, material(Color(0.95, 0.45, 0.1)))
	var bounce := ball.create_tween().set_loops()
	var low: Vector3 = ball.position
	bounce.tween_property(ball, "position", low + Vector3.UP * 0.9, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bounce.tween_property(ball, "position", low - Vector3.UP * 1.05, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	bounce.tween_property(ball, "position", low, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return [_spot(xform, Vector3(0.0, 0.0, 2.5), Vector3(0.0, 2.7, 0.0)),
		_spot(xform, Vector3(1.3, 0.0, 3.6), Vector3(0.0, 0.0, 2.5))]


static func _plain_box(box_size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	return mesh


## Игровые автоматы: два корпуса с мигающими экранами
func _build_arcade(root: Node3D, batch: PropBatch, xform: Transform3D) -> Array:
	var spots: Array = []
	var bodies: Array[Color] = [Color(0.45, 0.2, 0.75), Color(0.15, 0.35, 0.75)]
	var screens: Array[Color] = [Color(0.3, 1.0, 0.6), Color(1.0, 0.4, 0.8)]
	for i in 2:
		var x: float = -0.6 + i * 1.2
		_box(root, batch, xform, Vector3(x, 0.95, 0.0), Vector3(0.9, 1.9, 0.8), material(bodies[i]), true)
		var screen := _box(root, batch, xform, Vector3(x, 1.35, 0.41), Vector3(0.6, 0.45, 0.02), material(screens[i], 2.5))
		var flicker := screen.create_tween().set_loops()
		flicker.tween_property(screen, "scale", Vector3(1.0, 0.92, 1.0), 0.25 + i * 0.1)
		flicker.tween_property(screen, "scale", Vector3.ONE, 0.2)
		_box(root, batch, xform, Vector3(x, 1.0, 0.5), Vector3(0.8, 0.08, 0.3), material(Color(0.15, 0.15, 0.15)))
		_box(root, batch, xform, Vector3(x, 1.8, 0.42), Vector3(0.8, 0.15, 0.02), material(Color(1.0, 0.85, 0.3), 2.0))
		spots.append(_spot(xform, Vector3(x, 0.0, 1.05), Vector3(x, 1.2, 0.0)))
	return spots


## Барная стойка: стойка вдоль X, табуреты перед ней (+Z), полка с бутылками, лампы
func _build_bar(root: Node3D, batch: PropBatch, xform: Transform3D) -> Array:
	for x: float in [-0.9, 0.0, 0.9]:
		_centered(batch, FURNITURE + "kitchenBar.glb", xform, Vector3(x, 0.0, 0.0), 0.0, FURNITURE_SCALE, true)
	for x: float in [-1.0, 0.0, 1.0]:
		_centered(batch, FURNITURE + "stoolBar.glb", xform, Vector3(x, 0.0, 0.75), 0.0, FURNITURE_SCALE, false)
	return _bar_details(root, batch, xform)


## Детали стойки: табуреты перед ней (+Z), бармен за ней, бутылки, лампы
func _bar_details(root: Node3D, batch: PropBatch, xform: Transform3D) -> Array:
	var spots: Array = []
	var shelf := material(Color(0.4, 0.28, 0.18))
	_box(root, batch, xform, Vector3(0.0, 1.3, -1.1), Vector3(3.0, 0.08, 0.35), shelf)
	_box(root, batch, xform, Vector3(0.0, 0.65, -1.25), Vector3(3.0, 1.3, 0.05), shelf, true)
	var bottles: Array[Color] = [Color(0.3, 0.7, 0.35), Color(0.75, 0.35, 0.2), Color(0.35, 0.5, 0.85)]
	for i in 9:
		_cylinder(root, xform, Vector3(-1.3 + i * 0.32, 1.47, -1.1), 0.05, 0.25, material(bottles[i % 3]))
	for i in 3:
		var x: float = -1.0 + i * 1.0
		_sphere(root, xform, Vector3(x, 2.4, 0.1), 0.12, material(Color(1.0, 0.8, 0.45), 3.0))
		_box(root, batch, xform, Vector3(x, 2.7, 0.1), Vector3(0.02, 0.5, 0.02), material(Color(0.1, 0.1, 0.1)))
		if i < 2:
			spots.append(_spot(xform, Vector3(x + 0.5, 0.0, 1.0), Vector3(x + 0.5, 1.0, 0.0)))
	spots.append(_spot(xform, Vector3(0.3, 0.0, -0.75), Vector3(0.3, 1.0, 1.0)))
	return spots


## Бильярд: стол с сукном, лузы, шары, кий у стены
func _build_billiard(root: Node3D, batch: PropBatch, xform: Transform3D) -> Array:
	var wood := material(Color(0.4, 0.22, 0.12))
	_box(root, batch, xform, Vector3(0.0, 0.7, 0.0), Vector3(2.5, 0.16, 1.4), wood, true)
	_box(root, batch, xform, Vector3(0.0, 0.79, 0.0), Vector3(2.3, 0.03, 1.2), material(Color(0.1, 0.5, 0.25)))
	for x: float in [-1.1, 1.1]:
		for z: float in [-0.6, 0.6]:
			_box(root, batch, xform, Vector3(x, 0.32, z), Vector3(0.14, 0.64, 0.14), wood)
			_cylinder(root, xform, Vector3(x * 1.02, 0.79, z * 1.05), 0.06, 0.04, material(Color(0.05, 0.05, 0.05)))
	var balls: Array[Color] = [Color.WHITE, Color(0.95, 0.85, 0.2), Color(0.2, 0.35, 0.9), Color(0.9, 0.2, 0.2),
		Color(0.5, 0.2, 0.6), Color(1.0, 0.5, 0.1), Color(0.1, 0.1, 0.1)]
	for i in balls.size():
		var at := Vector3(-0.7, 0.85, 0.0) if i == 0 else Vector3(0.4 + float(i % 3) * 0.1, 0.85, -0.12 + float(i % 4) * 0.08)
		_sphere(root, xform, at, 0.05, material(balls[i]))
	var cue := BoxMesh.new()
	cue.size = Vector3(1.4, 0.03, 0.03)
	_mesh(root, cue, xform, Transform3D(Basis(Vector3.BACK, -0.15), Vector3(-1.4, 0.95, 0.15)), material(Color(0.85, 0.7, 0.45)))
	return [_spot(xform, Vector3(-1.75, 0.0, 0.25), Vector3(0.0, 0.8, 0.0)),
		_spot(xform, Vector3(0.6, 0.0, 1.1), Vector3(0.0, 0.8, 0.0))]


## Надувной бассейн: круглый бортик, вода (шейдер порта), круг, лежак
func _build_pool(root: Node3D, batch: PropBatch, xform: Transform3D) -> Array:
	var rim := TorusMesh.new()
	rim.inner_radius = 1.5
	rim.outer_radius = 1.85
	rim.rings = 24
	rim.ring_segments = 8
	_mesh(root, rim, xform, Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 1.6, 1.0)), Vector3(0.0, 0.28, 0.0)),
		material(Color(0.3, 0.6, 1.0)))
	var water := CylinderMesh.new()
	water.top_radius = 1.55
	water.bottom_radius = 1.55
	water.height = 0.04
	water.radial_segments = 24
	_mesh(root, water, xform, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.42, 0.0)),
		HarborBuilder.make_water_material(Color(0.1, 0.5, 0.7), Color(0.75, 0.95, 1.0)), false)
	batch.add_box(xform * Vector3(0.0, 0.3, 0.0), Vector3(3.4, 0.6, 3.4))
	var float_ring := TorusMesh.new()
	float_ring.inner_radius = 0.18
	float_ring.outer_radius = 0.34
	var ring := _mesh(root, float_ring, xform, Transform3D(Basis.IDENTITY, Vector3(0.5, 0.48, -0.3)),
		material(Color(1.0, 0.85, 0.2)), false)
	var drift := ring.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	drift.tween_property(ring, "position", ring.position + Vector3(-0.6, 0.0, 0.5), 3.0)
	drift.tween_property(ring, "position", ring.position, 3.0)
	_centered(batch, FURNITURE + "loungeChairRelax.glb", xform, Vector3(-2.6, 0.0, 0.5), 90.0, FURNITURE_SCALE, true)
	return [_spot(xform, Vector3(-2.55, BENCH_SEAT_Y, 0.5), Vector3(0.0, 0.0, 0.5), true),
		_spot(xform, Vector3(2.2, 0.0, 0.8), Vector3(0.0, 0.0, 0.0))]


## Ветряк: мачта, гондола и три лопасти — крутятся (перёд +Z)
func _build_windmill(root: Node3D, batch: PropBatch, xform: Transform3D) -> Array:
	var white := material(Color(0.9, 0.9, 0.92))
	var mast := CylinderMesh.new()
	mast.top_radius = 0.18
	mast.bottom_radius = 0.38
	mast.height = 8.0
	mast.radial_segments = 10
	_mesh(root, mast, xform, Transform3D(Basis.IDENTITY, Vector3(0.0, 4.0, 0.0)), white)
	batch.add_box(xform * Vector3(0.0, 2.0, 0.0), Vector3(0.8, 4.0, 0.8))
	_box(root, batch, xform, Vector3(0.0, 8.15, -0.2), Vector3(0.6, 0.6, 1.5), white)
	_box(root, batch, xform, Vector3(0.0, 8.15, -0.95), Vector3(0.05, 0.4, 0.4), material(Color(0.85, 0.2, 0.18)))
	var hub := _pivot(root, xform, Vector3(0.0, 8.15, 0.65))
	_sphere(hub, Transform3D.IDENTITY, Vector3.ZERO, 0.22, white)
	for i in 3:
		var blade := MeshInstance3D.new()
		var blade_mesh := BoxMesh.new()
		blade_mesh.size = Vector3(0.32, 3.4, 0.06)
		blade.mesh = blade_mesh
		blade.material_override = white
		blade.transform = Transform3D(Basis(Vector3.BACK, float(i) * TAU / 3.0), Vector3.ZERO) \
			* Transform3D(Basis.IDENTITY, Vector3(0.0, 1.8, 0.0))
		hub.add_child(blade)
	var spin := hub.create_tween().set_loops()
	spin.tween_property(hub, "rotation:z", TAU, 7.0).from(0.0)
	_box(root, batch, xform, Vector3(0.0, 0.3, 0.0), Vector3(1.4, 0.6, 1.4), material(Color(0.5, 0.5, 0.52)))
	return []


## Летний кинотеатр: экран на раме, проектор с лучом, скамейки
func _build_cinema(root: Node3D, batch: PropBatch, xform: Transform3D) -> Array:
	var frame := material(Color(0.2, 0.2, 0.22))
	for x: float in [-2.8, 2.8]:
		_box(root, batch, xform, Vector3(x, 1.8, 2.6), Vector3(0.15, 3.6, 0.15), frame, true)
	var screen := _box(root, batch, xform, Vector3(0.0, 2.2, 2.6), Vector3(5.4, 2.8, 0.05), material(Color(0.85, 0.9, 1.0), 0.8))
	var flicker := screen.create_tween().set_loops()
	flicker.tween_callback(func() -> void: screen.material_override = material(Color(0.7, 0.85, 1.0), 0.9))
	flicker.tween_interval(1.1)
	flicker.tween_callback(func() -> void: screen.material_override = material(Color(1.0, 0.85, 0.7), 0.8))
	flicker.tween_interval(0.9)
	# Проектор и луч
	_box(root, batch, xform, Vector3(0.0, 1.0, -4.2), Vector3(0.5, 0.35, 0.6), frame)
	_box(root, batch, xform, Vector3(0.0, 0.4, -4.2), Vector3(0.2, 0.8, 0.2), frame)
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.08
	beam_mesh.bottom_radius = 1.8
	beam_mesh.height = 6.6
	beam_mesh.cap_top = false
	beam_mesh.cap_bottom = false
	var direction: Vector3 = (Vector3(0.0, 2.2, 2.6) - Vector3(0.0, 1.0, -4.2)).normalized()
	var beam_basis := Basis(Vector3.UP.cross(direction).normalized(), Vector3.UP.angle_to(direction))
	_mesh(root, beam_mesh, xform, Transform3D(beam_basis, Vector3(0.0, 1.6, -0.9)),
		material(Color(0.9, 0.95, 1.0, 0.06), 0.8, true), false)
	var spots: Array = []
	for row in 2:
		for x: float in [-1.5, 1.5]:
			var z: float = -1.0 - row * 1.6
			_centered(batch, FURNITURE + "bench.glb", xform, Vector3(x, 0.0, z), 0.0, FURNITURE_SCALE, true)
			spots.append(_spot(xform, Vector3(x - 0.25, BENCH_SEAT_Y, z - 0.05), Vector3(x - 0.25, BENCH_SEAT_Y, 2.6), true))
			spots.append(_spot(xform, Vector3(x + 0.25, BENCH_SEAT_Y, z - 0.05), Vector3(x + 0.25, BENCH_SEAT_Y, 2.6), true))
	return spots
