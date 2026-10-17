class_name MountainBuilder
extends LocationBuilder
## «Горный перевал»: снежная площадка между скалами. По краям — стена из громадных камней (за ней
## невидимые стены Bounds уровня), дорога через перевал с юга на север, на севере — частокол и ворота
## деревни Верхние Ключи (точка обороны у ворот), за частоколом — крыши домов. Внутри — валуны,
## сосны, брошенные машины и ящики как укрытия, костры. Холодный свет, лёгкий туман.

const GRAVE: String = "res://models/graveyard/"
const SURV: String = "res://models/survival/"
const ENV: String = "res://models/environment/"
const PINES: Array[String] = ["res://models/nature/tree_pineTallA.glb", "res://models/nature/tree_pineTallB.glb",
	"res://models/nature/tree_pineTallC.glb"]
## Заснеженные ёлки (Kenney Holiday Kit, высота 1.9 → ~6 м)
const SNOW_TREES: Array[String] = ["res://models/holiday/tree-snow-a.glb", "res://models/holiday/tree-snow-b.glb",
	"res://models/holiday/tree-snow-c.glb"]
## Скалы (Kenney Nature Kit): стена — cliff_large (1×1×0.42 → 10 м), валуны — rock_tall
const CLIFFS: Array[String] = ["res://models/nature/cliff_large_rock.glb", "res://models/nature/cliff_block_rock.glb"]
const BIG_ROCKS: Array[String] = ["res://models/nature/rock_tallA.glb", "res://models/nature/rock_tallB.glb",
	"res://models/nature/rock_tallE.glb"]
const SMALL_ROCKS: Array[String] = ["res://models/graveyard/rocks.glb", "res://models/graveyard/rocks-tall.glb",
	"res://models/graveyard/trunk.glb"]
const HOUSES: Array[String] = ["res://models/city/suburban/building-type-a.glb",
	"res://models/city/suburban/building-type-c.glb", "res://models/city/suburban/building-type-f.glb",
	"res://models/city/suburban/building-type-k.glb"]
const WRECKS: Array[String] = ["res://models/vehicles/Vehicle_Pickup.gltf", "res://models/vehicles/Vehicle_Truck.gltf"]
const COVER: Array[String] = ["res://models/survival/box-large.glb", "res://models/survival/barrel.glb",
	"res://models/environment/Pallet.gltf"]
const KENNEY_SCALE: float = 2.2
## Деревья и скалы Nature Kit маленькие: сосна 1.5–1.9 → 11–14 м, скала 1 → 10 м, валун 1 → 3.5 м
const PINE_SCALE: float = 7.0
const CLIFF_SCALE: float = 10.0
const ROCK_SCALE: float = 3.5
const SNOW_TREE_SCALE: float = 3.0
const SURVIVAL_SCALE: float = 3.4
const PINE_TRUNK: Vector3 = Vector3(0.6, 4.0, 0.6)
## Частокол деревни: линия по z и полуширина проёма ворот
const GATE_Z: float = -24.0
const GATE_HALF: float = 3.2
## Дома Kenney Suburban: ширина ~1 → ×8
const HOUSE_SCALE: float = 8.0


func _init() -> void:
	fog_color = Color(0.78, 0.82, 0.88)
	fog_density = 0.014
	sun_color = Color(1.0, 0.97, 0.92)
	sun_energy = 1.05
	ground_color = Color(0.82, 0.84, 0.88)


func _build_location() -> void:
	_build_rock_wall()
	_build_road()
	_build_village()
	# Укрытия на перевале
	_scatter(BIG_ROCKS, 9, Vector2(ROCK_SCALE * 0.8, ROCK_SCALE * 1.2), 2.4)
	_scatter(PINES, 10, Vector2(PINE_SCALE * 0.8, PINE_SCALE * 1.0), 2.4, true, PINE_TRUNK, 5.0)
	_scatter(SNOW_TREES, 10, Vector2(SNOW_TREE_SCALE * 0.8, SNOW_TREE_SCALE * 1.2), 2.0, true, Vector3(1.0, 4.0, 1.0), 4.0)
	_scatter(SMALL_ROCKS, 14, Vector2(KENNEY_SCALE, KENNEY_SCALE * 1.4), 1.6)
	_scatter(WRECKS, 3, Vector2(1.0, 1.0), 4.0)
	_scatter(COVER, 12, Vector2(1.0, 1.0), 1.4)
	_explosive_barrels(3)
	for i in 3:
		var at := Vector3(_rng.randf_range(-16.0, 16.0), 0.0, _rng.randf_range(-12.0, 18.0))
		if _is_free(at, 1.5):
			_place(SURV + "campfire-pit.glb", at, 0.0, SURVIVAL_SCALE, false)
			_fire(at, 0.3, 8.0)
			_keep_clear.append(at)


## Скалы по краю площадки — сразу за стенами Bounds (только вид)
func _build_rock_wall() -> void:
	var edge: float = half_size + 3.0  # скалы видны до стены тумана (EdgeCover — с +0.6 м за стенами)
	for side in 4:
		var yaw: float = side * PI * 0.5
		var along: float = -edge
		while along < edge:
			var at: Vector3 = Vector3(along, -0.6, edge + _rng.randf_range(0.0, 3.0)).rotated(Vector3.UP, yaw)
			# Север — проём для деревни: скалы только по бокам
			if side == 2 and absf(along) < 20.0:
				along += 5.0
				continue
			# Скальная стена лицом внутрь площадки, высота разная — неровный гребень
			_place(CLIFFS[_rng.randi() % CLIFFS.size()], at, yaw + PI + _rng.randf_range(-0.25, 0.25),
				CLIFF_SCALE * _rng.randf_range(0.8, 1.3), false)
			along += 7.0 + _rng.randf_range(0.0, 2.0)
	# Сосны за скалами — силуэт леса на склонах
	for i in 40:
		var angle: float = _rng.randf() * TAU
		var at := Vector3(cos(angle), 0.0, sin(angle)) * _rng.randf_range(half_size + 8.0, half_size + 26.0)
		_place(PINES[i % PINES.size()], at, _rng.randf() * TAU, PINE_SCALE * _rng.randf_range(0.9, 1.3), false)


## Дорога через перевал: тёмная полоса по снегу (вид), с юга к воротам
func _build_road() -> void:
	var road := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(6.0, 0.04, half_size * 2.0 + 30.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.38, 0.36, 0.35)
	material.roughness = 1.0
	box.material = material
	road.mesh = box
	road.position = Vector3(0.0, 0.02, 0.0)
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(road)
	_reserved.append(Rect2(-3.0, -half_size, 6.0, half_size * 2.0))


## Частокол с воротами (проём — точка обороны), дома деревни за ним
func _build_village() -> void:
	var x: float = -half_size
	while x < half_size:
		if absf(x) > GATE_HALF + 1.0:
			_place(SURV + "fence-fortified.glb", Vector3(x, 0.0, GATE_Z), 0.0, SURVIVAL_SCALE, true)
		x += 3.4
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.42, 0.3, 0.2)
	wood.roughness = 0.9
	for side: float in [-1.0, 1.0]:
		_post(Vector3(side * GATE_HALF, 2.6, GATE_Z), Vector3(0.6, 5.2, 0.6), wood)
		_batch.add_box(Vector3(side * GATE_HALF, 2.6, GATE_Z), Vector3(0.6, 5.2, 0.6))
	_post(Vector3(0.0, 5.4, GATE_Z), Vector3(GATE_HALF * 2.0 + 0.6, 0.6, 0.6), wood)
	_reserved.append(Rect2(-half_size, GATE_Z - 6.0, half_size * 2.0, 6.0))
	# Дома за частоколом и за стенами уровня (только вид)
	for i in 6:
		var at := Vector3(-18.0 + i * 7.5, 0.0, GATE_Z - 9.0 - (i % 2) * 6.0)
		_place(HOUSES[i % HOUSES.size()], at, PI, HOUSE_SCALE, false)
	_fire(Vector3(0.0, 0.0, GATE_Z - 4.0), 0.4, 9.0)


func _post(at: Vector3, post_size: Vector3, material: Material) -> void:
	var box := BoxMesh.new()
	box.size = post_size
	box.material = material
	var post := MeshInstance3D.new()
	post.mesh = box
	post.position = at
	add_child(post)
