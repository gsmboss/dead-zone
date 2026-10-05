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
