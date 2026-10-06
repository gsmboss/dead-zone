class_name ForestBuilder
extends LocationBuilder
## «Лесной лагерь»: густое кольцо сосен по краю (стена леса), поляна с брошенным лагерем
## выживших (палатки, костры, ящики, верстак), поваленные деревья, камни, пни.

const GRAVE: String = "res://models/graveyard/"
const SURV: String = "res://models/survival/"
const ENV: String = "res://models/environment/"
const PINES: Array[String] = ["res://models/graveyard/pine.glb", "res://models/graveyard/pine-crooked.glb",
	"res://models/graveyard/pine-fall.glb"]
const ROCKS: Array[String] = ["res://models/graveyard/rocks.glb", "res://models/graveyard/rocks-tall.glb",
	"res://models/graveyard/trunk.glb"]
const CAMP_PROPS: Array[String] = ["res://models/survival/box-large.glb", "res://models/survival/box.glb",
	"res://models/survival/barrel.glb", "res://models/survival/bedroll.glb", "res://models/survival/bucket.glb"]
const PINE_TRUNK: Vector3 = Vector3(0.6, 4.0, 0.6)
const KENNEY_SCALE: float = 2.2
const SURVIVAL_SCALE: float = 3.4


func _init() -> void:
	fog_color = Color(0.32, 0.4, 0.34)
	fog_density = 0.03
	sun_color = Color(0.95, 0.92, 0.75)
	sun_energy = 0.75
	ground_color = Color(0.2, 0.27, 0.16)


func _build_location() -> void:
	# Стена леса: два ряда сосен по краю (видно, что дальше не пройти)
	for row in 2:
		var edge: float = half_size - 0.5 - row * 2.2
		var step: float = 3.0 + row * 1.2
		for side in 4:
			var yaw: float = side * PI * 0.5
			var along: float = -edge
			while along < edge:
				var at: Vector3 = Vector3(along + _rng.randf_range(-0.6, 0.6), 0.0, edge).rotated(Vector3.UP, yaw)
				along += step + _rng.randf_range(-0.4, 0.8)
				if row == 1 and not _is_free(at, 1.0):
					continue
				_place(PINES[_rng.randi() % PINES.size()], at, _rng.randf() * TAU,
					KENNEY_SCALE * _rng.randf_range(1.2, 1.7), true, PINE_TRUNK)

	# Лагерь выживших на поляне у центра
	var camp := Vector3(_rng.randf_range(-4.0, 4.0), 0.0, _rng.randf_range(-6.0, -2.0))
	if _is_free(camp, 3.0):
		_place(SURV + "campfire-pit.glb", camp, 0.0, SURVIVAL_SCALE, false)
		_place(SURV + "campfire-stand.glb", camp, 0.0, SURVIVAL_SCALE, false)
		_fire(camp, 0.3, 10.0)
		for i in 3:
			var angle: float = TAU * i / 3.0 + 0.4
			var tent_at: Vector3 = camp + Vector3(cos(angle), 0.0, sin(angle)) * 5.0
			if _is_free(tent_at, 1.6):
				_place(SURV + "tent-canvas.glb", tent_at, -angle + PI * 0.5, SURVIVAL_SCALE, true, Vector3.ZERO, 1.8)
		_place(SURV + "workbench.glb", camp + Vector3(3.2, 0.0, 2.8), 0.6, SURVIVAL_SCALE)
		_reserved.append(Rect2(camp.x - 2.0, camp.z - 2.0, 4.0, 4.0))

	# Деревья внутри, камни, пни, ящики лагеря
	_scatter(PINES, 22, Vector2(KENNEY_SCALE * 1.1, KENNEY_SCALE * 1.6), 2.4, true, PINE_TRUNK, 5.0)
	_scatter(ROCKS, 16, Vector2(KENNEY_SCALE, KENNEY_SCALE * 1.5), 1.6)
	_scatter(CAMP_PROPS, 12, Vector2(SURVIVAL_SCALE, SURVIVAL_SCALE), 1.2)
	_scatter([ENV + "Pallet_Broken.gltf", ENV + "TrashBag_1.gltf", ENV + "Wheel.gltf"], 6, Vector2(1.0, 1.0), 1.0, false)
	# Ещё два костра — ориентиры в тумане
	for i in 2:
		var at := Vector3(_rng.randf_range(-16.0, 16.0), 0.0, _rng.randf_range(4.0, 18.0))
		if _is_free(at, 1.5):
			_place(SURV + "campfire-pit.glb", at, 0.0, SURVIVAL_SCALE, false)
			_fire(at, 0.3, 7.0)
			_keep_clear.append(at)
