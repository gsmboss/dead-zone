class_name BaseBuilder
extends Node3D
## Постройки игрока в убежище (стройка как в Minecraft, клетка 1×1×1 м).
## Кубы — MultiMesh на каждый вид блока с пиксельной текстурой, сгенерированной кодом (мало вызовов
## отрисовки); модели — экземпляры, вписанные в клетку; коллизии — коробки в одном StaticBody3D
## (слой WORLD: по блокам ходят и прыгают); у ламп и костров — свет (не больше MAX_LIGHTS).
## Данные хранит GameState (blocks_changed), место проверяет can_place().

const GROUP: StringName = &"base_builder"
## Где можно строить: внутри стен убежища (±8 м, у самих стен — нельзя), до 8 блоков в высоту
const MIN_CELL: Vector3i = Vector3i(-7, 0, -7)
const MAX_CELL: Vector3i = Vector3i(6, 7, 6)
const MAX_LIGHTS: int = 8
## Свободно у терминалов (радиус по горизонтали, м) — до них всегда можно дойти
const KEEP_CLEAR_RADIUS: float = 1.8
## Костёр с выжившими (hub/hub_camp.gd) — вокруг него не строим
const CAMP_FIRE: Vector3 = Vector3(-4.6, 0.0, 1.3)
const CAMP_RADIUS: float = 2.7
## Блоки не ставятся выше этого над землёй рядом с терминалами (проход)
const KEEP_CLEAR_HEIGHT: int = 3
const TEXTURE_SIZE: int = 16

var _body: StaticBody3D
var _query: PhysicsShapeQueryParameters3D
var _cells: Dictionary = {}       # Vector3i → id блока (быстрый поиск без строк)
var _shapes: Dictionary = {}      # Vector3i → CollisionShape3D
var _models: Dictionary = {}      # Vector3i → Node3D
var _lights: Dictionary = {}      # Vector3i → Node3D (свет и огонь)
var _multimeshes: Dictionary = {} # id → MultiMeshInstance3D
var _materials: Dictionary = {}   # id → StandardMaterial3D
var _textures: Dictionary = {}    # id → ImageTexture (и для иконок палитры)
var _model_fit: Dictionary = {}   # id → {"scale": float, "offset": Vector3, "height": float}
var _box_mesh: BoxMesh
var _keep_clear: Array[Vector3] = []


func _ready() -> void:
	add_to_group(GROUP)
	_body = StaticBody3D.new()
	_body.name = "BuildBody"
	_body.collision_layer = PhysicsLayers.WORLD
	_body.collision_mask = 0
	add_child(_body)
	_box_mesh = BoxMesh.new()
	_box_mesh.size = Vector3.ONE

	var probe := BoxShape3D.new()
	probe.size = Vector3.ONE * 0.9
	_query = PhysicsShapeQueryParameters3D.new()
	_query.shape = probe
	_query.collision_mask = PhysicsLayers.WORLD
	_query.exclude = [_body.get_rid()]

	GameState.blocks_changed.connect(_on_blocks_changed)
	_collect_keep_clear.call_deferred()
	_rebuild_all()


# ---------- Публичное ----------

func has_block(cell: Vector3i) -> bool:
	return _cells.has(cell)


func get_body_rid() -> RID:
	return _body.get_rid()


## Причина, почему здесь нельзя поставить блок; пусто — можно
func can_place(cell: Vector3i, piece: BuildPiece, player: Player) -> String:
	if piece == null:
		return "ВЫБЕРИ БЛОК"
	if cell.x < MIN_CELL.x or cell.y < MIN_CELL.y or cell.z < MIN_CELL.z \
			or cell.x > MAX_CELL.x or cell.y > MAX_CELL.y or cell.z > MAX_CELL.z:
		return "ЗА ПРЕДЕЛАМИ УБЕЖИЩА"
	if _cells.has(cell):
		return "ЗАНЯТО"
	if GameState.get_block_count() >= GameState.MAX_BLOCKS:
		return "ЛИМИТ: %d БЛОКОВ" % GameState.MAX_BLOCKS
	if piece.has_light() and _lights.size() >= MAX_LIGHTS:
		return "НЕ БОЛЬШЕ %d ИСТОЧНИКОВ СВЕТА" % MAX_LIGHTS
	var center: Vector3 = cell_center(cell)
	var flat := Vector2(center.x, center.z)
	if cell.y < KEEP_CLEAR_HEIGHT:
		for point: Vector3 in _keep_clear:
			if flat.distance_to(Vector2(point.x, point.z)) < KEEP_CLEAR_RADIUS:
				return "ОСТАВЬ ПРОХОД К ТЕРМИНАЛУ"
		if flat.distance_to(Vector2(CAMP_FIRE.x, CAMP_FIRE.z)) < CAMP_RADIUS:
			return "ТУТ ЛАГЕРЬ ВЫЖИВШИХ"
	if player != null and piece.solid:
		var feet: Vector3 = player.global_position
		var player_box := AABB(feet + Vector3(-0.4, 0.0, -0.4), Vector3(0.8, 1.8, 0.8))
		if player_box.intersects(AABB(Vector3(cell) + Vector3.ONE * 0.05, Vector3.ONE * 0.9)):
			return "ТЫ СТОИШЬ ЗДЕСЬ"
	_query.transform = Transform3D(Basis.IDENTITY, center)
	if not get_world_3d().direct_space_state.intersect_shape(_query, 1).is_empty():
		return "МЕШАЕТ ПРЕДМЕТ"
	if GameState.coins < piece.price:
		return "НЕ ХВАТАЕТ МОНЕТ"
	if GameState.get_item_count(GameState.SCRAP_ID) < piece.scrap:
		return "НЕ ХВАТАЕТ ЛОМА (НАЙДИ В МИССИЯХ)"
	return ""


static func cell_center(cell: Vector3i) -> Vector3:
	return Vector3(cell) + Vector3.ONE * 0.5


static func cell_at(point: Vector3) -> Vector3i:
	return Vector3i(floori(point.x), floori(point.y), floori(point.z))


## Пиксельная текстура блока (палитра стройки показывает её иконкой)
func get_texture(piece: BuildPiece) -> Texture2D:
	if piece == null or piece.kind != BuildPiece.Kind.BLOCK:
		return null
	if not _textures.has(piece.id):
		_textures[piece.id] = _make_texture(piece)
	return _textures[piece.id]


# ---------- Обновление ----------

func _on_blocks_changed(cell: Vector3i) -> void:
	if cell == Vector3i.MAX:
		_rebuild_all()
		return
	var entry: Array = GameState.get_block(cell)
	if entry.is_empty():
		_remove_cell(cell)
	else:
		_add_cell(cell, str(entry[0]), int(entry[1]))


func _rebuild_all() -> void:
	for cell: Vector3i in _cells.keys():
		_remove_visual(cell)
	_cells.clear()
	var blocks: Dictionary = GameState.get_blocks()
	for key: String in blocks:
		var cell: Vector3i = GameState.parse_cell(key)
		var entry: Array = blocks[key]
		if cell != Vector3i.MAX:
			_add_cell(cell, str(entry[0]), int(entry[1]), false)
	for piece_id: String in _multimeshes:
		_rebuild_multimesh(piece_id)


func _add_cell(cell: Vector3i, piece_id: String, rotation_step: int, update_mesh: bool = true) -> void:
	var piece: BuildPiece = GameState.build_catalog.find(piece_id)
	if piece == null:
		return
	if _cells.has(cell):
		_remove_cell(cell)
	_cells[cell] = piece_id
	var bottom: Vector3 = Vector3(cell) + Vector3(0.5, 0.0, 0.5)
	var height: float = 1.0
	if piece.kind == BuildPiece.Kind.BLOCK:
		_ensure_multimesh(piece)
		if update_mesh:
			_rebuild_multimesh(piece_id)
	else:
		height = _add_model(cell, piece, rotation_step, bottom)
	if piece.solid:
		var box := BoxShape3D.new()
		box.size = Vector3(1.0, clampf(height, 0.25, 1.0), 1.0)
		var shape := CollisionShape3D.new()
		shape.shape = box
		shape.position = bottom + Vector3.UP * box.size.y * 0.5
		_body.add_child(shape)
		_shapes[cell] = shape
	if piece.has_light() and _lights.size() < MAX_LIGHTS:
		_add_light(cell, piece, bottom)


func _remove_cell(cell: Vector3i) -> void:
	var piece_id: String = str(_cells.get(cell, ""))
	_cells.erase(cell)
	_remove_visual(cell)
	if _multimeshes.has(piece_id):
		_rebuild_multimesh(piece_id)


func _remove_visual(cell: Vector3i) -> void:
	for map: Dictionary in [_shapes, _models, _lights]:
		var node: Node = map.get(cell) as Node
		if node != null and is_instance_valid(node):
			node.queue_free()
		map.erase(cell)


# ---------- Кубы ----------

func _ensure_multimesh(piece: BuildPiece) -> void:
	if _multimeshes.has(piece.id):
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _box_mesh
	var instance := MultiMeshInstance3D.new()
	instance.name = "Blocks_%s" % piece.id
	instance.multimesh = multimesh
	instance.material_override = _material_for(piece)
	if piece.transparent or piece.emissive:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	_multimeshes[piece.id] = instance


func _rebuild_multimesh(piece_id: String) -> void:
	var instance := _multimeshes.get(piece_id) as MultiMeshInstance3D
	if instance == null:
		return
	var count: int = 0
	for cell: Vector3i in _cells:
		if _cells[cell] == piece_id:
			count += 1
	var multimesh: MultiMesh = instance.multimesh
	multimesh.instance_count = count
	var i: int = 0
	for cell: Vector3i in _cells:
		if _cells[cell] == piece_id:
			multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, cell_center(cell)))
			i += 1


func _material_for(piece: BuildPiece) -> StandardMaterial3D:
	if _materials.has(piece.id):
		return _materials[piece.id]
	var material := StandardMaterial3D.new()
	material.albedo_texture = get_texture(piece)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# BoxMesh раскладывает грани сеткой 3×2 — так каждая грань получает текстуру целиком
	material.uv1_scale = Vector3(3.0, 2.0, 1.0)
	material.roughness = 0.95
	if piece.transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if piece.emissive:
		material.emission_enabled = true
		material.emission = piece.color
		material.emission_energy_multiplier = 1.4
		material.emission_texture = material.albedo_texture
	_materials[piece.id] = material
	return material


## Пиксельная текстура 16×16 по рисунку блока (как в Minecraft), одинаковая при каждом запуске
func _make_texture(piece: BuildPiece) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(piece.id)
	var image := Image.create_empty(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var base: Color = piece.color
	var plank_tint := PackedFloat32Array()
	for i in 4:
		plank_tint.append(rng.randf_range(-piece.color_variation, piece.color_variation))
	for y in TEXTURE_SIZE:
		for x in TEXTURE_SIZE:
			var shade: float = 1.0 + rng.randf_range(-piece.color_variation, piece.color_variation)
			var alpha: float = base.a
			var edge: bool = x == 0 or y == 0 or x == TEXTURE_SIZE - 1 or y == TEXTURE_SIZE - 1
			var pixel: Color = base
			match piece.pattern:
				BuildPiece.Pattern.PLANKS:
					var plank: int = int(y / 4.0)
					shade += plank_tint[plank]
					if y % 4 == 3 or x == (plank * 5 + 3) % TEXTURE_SIZE:
						shade *= 0.62
					elif rng.randf() < 0.12:
						shade *= 0.85  # волокна дерева
				BuildPiece.Pattern.BRICKS:
					var row: int = int(y / 4.0)
					if y % 4 == 3 or (x + (row % 2) * 4) % 8 == 7:
						pixel = Color(0.78, 0.75, 0.7)
						shade = 1.0 + rng.randf_range(-0.05, 0.05)
				BuildPiece.Pattern.PANEL:
					if edge:
						shade *= 0.68
					elif (x == 2 or x == 13) and (y == 2 or y == 13):
						shade *= 1.45  # заклёпки
				BuildPiece.Pattern.GLASS:
					if edge:
						pixel = Color(0.85, 0.95, 1.0)
						alpha = 0.9
					elif x - y == 3 or x - y == 4:
						alpha = 0.6  # блик
						pixel = Color.WHITE
				BuildPiece.Pattern.LAMP:
					if edge or x == 1 or y == 1 or x == TEXTURE_SIZE - 2 or y == TEXTURE_SIZE - 2:
						pixel = Color(0.28, 0.28, 0.3)
				_:
					if edge:
						shade *= 0.9
			image.set_pixel(x, y, Color(pixel.r * shade, pixel.g * shade, pixel.b * shade, alpha).clamp())
	return ImageTexture.create_from_image(image)


# ---------- Модели ----------

## Поставить модель в клетку; возвращает высоту модели (для коллизии)
func _add_model(cell: Vector3i, piece: BuildPiece, rotation_step: int, bottom: Vector3) -> float:
	if piece.model == null:
		return 1.0
	var model := piece.model.instantiate() as Node3D
	if model == null:
		push_warning("BaseBuilder: модель блока '%s' не Node3D" % piece.id)
		return 1.0
	var fit: Dictionary = _fit_for(piece, model)
	var basis := Basis(Vector3.UP, rotation_step * PI * 0.5 + deg_to_rad(piece.model_yaw_degrees))
	var scale_value: float = float(fit["scale"])
	model.transform = Transform3D(basis.scaled(Vector3.ONE * scale_value), bottom + basis * (fit["offset"] as Vector3))
	add_child(model)
	_models[cell] = model
	return float(fit["height"])


## Масштаб и сдвиг, чтобы модель стояла на дне клетки по центру и занимала piece.fill по ширине
func _fit_for(piece: BuildPiece, model: Node3D) -> Dictionary:
	if _model_fit.has(piece.id):
		return _model_fit[piece.id]
	var bounds := AABB()
	var has_bounds: bool = false
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var local: AABB = _transform_to(mesh_instance, model) * mesh_instance.get_aabb()
		bounds = bounds.merge(local) if has_bounds else local
		has_bounds = true
	var fit: Dictionary = {"scale": 1.0, "offset": Vector3.ZERO, "height": 1.0}
	if has_bounds:
		var width: float = maxf(maxf(bounds.size.x, bounds.size.z), 0.01)
		var scale_value: float = piece.fill / width
		# Высокие модели — не выше двух клеток
		if bounds.size.y * scale_value > 2.0:
			scale_value = 2.0 / bounds.size.y
		var center: Vector3 = bounds.get_center()
		fit = {
			"scale": scale_value,
			"offset": Vector3(-center.x, -bounds.position.y, -center.z) * scale_value,
			"height": bounds.size.y * scale_value,
		}
	_model_fit[piece.id] = fit
	return fit


func _transform_to(node: Node3D, root: Node3D) -> Transform3D:
	var result: Transform3D = Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != root:
		var spatial := current as Node3D
		if spatial != null:
			result = spatial.transform * result
		current = current.get_parent()
	return result


func _add_light(cell: Vector3i, piece: BuildPiece, bottom: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = bottom
	var light := OmniLight3D.new()
	light.light_color = Color(piece.light_color, 1.0)
	light.light_energy = 1.6
	light.omni_range = piece.light_range
	light.shadow_enabled = false
	light.position = Vector3.UP * (0.5 if piece.kind == BuildPiece.Kind.BLOCK else 0.7)
	holder.add_child(light)
	if piece.kind == BuildPiece.Kind.MODEL:
		var flames := GraveyardBuilder.make_flames()
		flames.position = Vector3.UP * 0.15
		flames.scale = Vector3.ONE * 0.6
		holder.add_child(flames)
	add_child(holder)
	_lights[cell] = holder


func _collect_keep_clear() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"interactables"):
		var area := node as Node3D
		if area != null:
			_keep_clear.append(area.global_position)
