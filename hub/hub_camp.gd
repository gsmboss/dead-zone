class_name HubCamp
extends Node3D
## Лагерь выживших во дворе убежища (модели Kenney Survival Kit): палатка, костёр с огнём,
## спальник, ящики, бочки, инструменты. Создаётся кодом (hub.gd), коллизии — в одном теле.

const DIR: String = "res://models/survival/"
## Модели Kenney маленькие: палатка 0.56 → ~1.9 м
const PROP_SCALE: float = 3.4
const FIRE_COLOR: Color = Color(1.0, 0.6, 0.25)

## [модель, позиция, поворот в градусах, коллизия]
const LAYOUT: Array = [
	["tent-canvas", Vector3(-6.7, 0.0, 1.4), 90.0, true],
	["campfire-pit", Vector3(-4.6, 0.0, 1.3), 0.0, false],
	["campfire-stand", Vector3(-4.6, 0.0, 1.3), 0.0, false],
	["bedroll", Vector3(-4.9, 0.0, 2.9), 80.0, false],
	["box-large", Vector3(-7.2, 0.0, -0.9), 0.0, true],
	["box", Vector3(-6.4, 0.0, -1.1), 25.0, true],
	["barrel-open", Vector3(-3.4, 0.0, 2.6), 0.0, true],
	["bucket", Vector3(-3.6, 0.0, 0.4), 0.0, false],
	["signpost", Vector3(-2.9, 0.0, -0.4), -30.0, true],
	["workbench", Vector3(2.9, 0.0, 0.6), 0.0, true],
	["tool-axe", Vector3(2.7, 1.0, 0.6), 0.0, false],
	["tool-hammer", Vector3(3.1, 1.0, 0.7), 30.0, false],
]


func _ready() -> void:
	var batch := PropBatch.new(self)
	for entry: Array in LAYOUT:
		var path: String = DIR + str(entry[0]) + ".glb"
		var scene: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
		if scene == null:
			push_warning("HubCamp: нет модели %s" % path)
			continue
		var at: Vector3 = entry[1]
		var xform := Transform3D(Basis(Vector3.UP, deg_to_rad(float(entry[2]))).scaled(Vector3.ONE * PROP_SCALE), at)
		batch.add(scene, xform, bool(entry[3]))
	batch.build()
	_build_fire(Vector3(-4.6, 0.0, 1.3))
	_build_survivors(Vector3(-4.6, 0.0, 1.3))


## Спасённые в сюжете люди греются у костра (до MAX_SURVIVORS фигур)
const MAX_SURVIVORS: int = 6
var _survivors: Array[PlayerBody] = []


func _build_survivors(fire: Vector3) -> void:
	var count: int = mini(GameState.get_rescued_count(), MAX_SURVIVORS)
	if count <= 0:
		return
	var skins: Array[PlayerSkin] = []
	for skin: PlayerSkin in GameState.skins:
		if skin.hide_weapon:
			skins.append(skin)
	if skins.is_empty():
		return
	for i in count:
		# Полукруг с восточной стороны костра (с запада — палатка)
		var angle: float = lerpf(-1.2, 1.2, float(i) / maxf(count - 1, 1.0))
		var at: Vector3 = fire + Vector3(cos(angle), 0.0, sin(angle)) * 1.9
		var body := PlayerBody.new()
		add_child(body)
		body.set_skin(skins[i % skins.size()])
		body.position = at
		body.rotation.y = atan2(at.x - fire.x, at.z - fire.z)  # лицом к огню
		_survivors.append(body)
	set_process(true)


func _process(delta: float) -> void:
	for body: PlayerBody in _survivors:
		body.update_motion(0.0, true, delta)


func _build_fire(at: Vector3) -> void:
	var light := OmniLight3D.new()
	light.light_color = FIRE_COLOR
	light.light_energy = 1.4
	light.omni_range = 6.0
	light.position = at + Vector3.UP * 0.8
	add_child(light)
	var flames := GraveyardBuilder.make_flames()
	flames.position = at + Vector3.UP * 0.25
	add_child(flames)
