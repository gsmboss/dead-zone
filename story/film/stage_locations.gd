class_name StageLocations
extends RefCounted
## Диорамы мест для сюжетного кино (StoryStage), кроме улицы и порта: лес с трассой и вышкой связи,
## кладбище с часовней, промзона с цехами и трубами, горный перевал с деревней. Каждая стоит в своей
## точке мира (ORIGINS) далеко от улицы и строится один раз — при первом плане в этом месте.
## Актёры (зомби, люди) — в StoryStage._actors, меняются вместе с настроением.

const FOREST_ORIGIN: Vector3 = Vector3(-300.0, 0.0, 0.0)
const GRAVEYARD_ORIGIN: Vector3 = Vector3(0.0, 0.0, 300.0)
const INDUSTRIAL_ORIGIN: Vector3 = Vector3(0.0, 0.0, -300.0)
const MOUNTAIN_ORIGIN: Vector3 = Vector3(-300.0, 0.0, -300.0)

const GRAVE: String = "res://models/graveyard/"
const SURV: String = "res://models/survival/"
const IND: String = "res://models/industrial/"
const ENV: String = "res://models/environment/"
const PINES: Array[String] = ["res://models/graveyard/pine.glb", "res://models/graveyard/pine-crooked.glb"]
const GRAVESTONES: Array[String] = ["res://models/graveyard/gravestone-cross.glb",
	"res://models/graveyard/gravestone-round.glb", "res://models/graveyard/gravestone-bevel.glb",
	"res://models/graveyard/gravestone-decorative.glb", "res://models/graveyard/gravestone-broken.glb"]
const FACTORIES: Array[String] = ["res://models/industrial/building-a.glb", "res://models/industrial/building-c.glb",
	"res://models/industrial/building-e.glb", "res://models/industrial/building-f.glb",
	"res://models/industrial/building-l.glb", "res://models/industrial/building-m.glb"]
const CONTAINERS: Array[String] = ["res://models/industrial/shipping-container-a.glb",
	"res://models/industrial/shipping-container-b.glb", "res://models/industrial/shipping-container-c.glb"]
const BIG_ROCKS: Array[String] = ["res://models/harbor/pirate/rocks-a.glb", "res://models/harbor/pirate/rocks-b.glb",
	"res://models/harbor/pirate/rocks-c.glb"]
const HOUSES: Array[String] = ["res://models/city/suburban/building-type-a.glb",
	"res://models/city/suburban/building-type-c.glb", "res://models/city/suburban/building-type-f.glb",
	"res://models/city/suburban/building-type-k.glb"]
## Модели Kenney маленькие: как в уровнях леса/кладбища и промзоны
const KENNEY_SCALE: float = 2.2
const SURVIVAL_SCALE: float = 3.4
const KIT_SCALE: float = 7.0

## Камеры мест: [откуда, куда, взгляд с, взгляд на] — как StoryStage.CAMERAS (координаты мира)
const CAMERAS: Dictionary = {
	# Лес (FOREST_ORIGIN -300, 0, 0): трасса вдоль X, лагерь на (12, 10), вышка на (-14, -14)
	"forest_wide": [Vector3(-340, 18, 40), Vector3(-300, 16, 44), Vector3(-302, 0, 0), Vector3(-296, 0, -4)],
	"forest_road": [Vector3(-330, 1.4, 1.0), Vector3(-314, 1.4, 1.0), Vector3(-296, 1.6, 0.0), Vector3(-280, 1.6, 0.0)],
	"forest_low": [Vector3(-294, 0.4, 4.0), Vector3(-296, 0.5, 3.0), Vector3(-304, 1.4, -1.0), Vector3(-306, 1.4, -1.0)],
	"forest_camp": [Vector3(-282, 2.2, 18.0), Vector3(-284, 2.0, 16.5), Vector3(-288, 0.8, 10.0), Vector3(-288, 0.9, 10.0)],
	"forest_tower": [Vector3(-308, 1.6, -3.0), Vector3(-309, 1.8, -4.0), Vector3(-314, 6.0, -14.0), Vector3(-314, 26.0, -14.0)],
	# Кладбище (GRAVEYARD_ORIGIN 0, 0, 300): часовня-склеп на (0, -14), мамина могила у (5, -3)
	"grave_wide": [Vector3(-30, 14, 330), Vector3(26, 13, 330), Vector3(0, 0, 292), Vector3(2, 0, 290)],
	"grave_low": [Vector3(8, 0.45, 306), Vector3(6, 0.55, 305), Vector3(-2, 1.4, 298), Vector3(-4, 1.4, 296)],
	"grave_mom": [Vector3(10, 2.0, 303), Vector3(9, 1.8, 302), Vector3(5, 0.7, 297), Vector3(5, 0.8, 297)],
	"grave_chapel": [Vector3(-6, 2.0, 302), Vector3(-3, 2.4, 300), Vector3(0, 3.0, 286), Vector3(0, 5.0, 286)],
	"grave_sky": [Vector3(0, 2, 312), Vector3(0, 2.5, 312), Vector3(0, 3, 300), Vector3(0, 40, 290)],
	# Промзона (INDUSTRIAL_ORIGIN 0, 0, -300): цеха по краям, бочки с огнём, цистерны
	"ind_wide": [Vector3(-40, 22, -262), Vector3(30, 20, -262), Vector3(0, 0, -300), Vector3(4, 0, -304)],
	"ind_low": [Vector3(10, 0.5, -290), Vector3(7, 0.6, -291), Vector3(-2, 1.5, -300), Vector3(-5, 1.5, -301)],
	"ind_fire": [Vector3(-8, 2.5, -288), Vector3(-6, 2.0, -290), Vector3(-2, 1.0, -298), Vector3(-2, 1.2, -298)],
	"ind_gate": [Vector3(0, 1.7, -268), Vector3(0, 1.7, -276), Vector3(0, 2.0, -300), Vector3(0, 3.0, -310)],
	# Горы (MOUNTAIN_ORIGIN -300, 0, -300): перевал вдоль Z, деревня за воротами на севере (z = -322)
	"mount_wide": [Vector3(-350, 30, -250), Vector3(-260, 28, -254), Vector3(-300, 2, -300), Vector3(-298, 2, -310)],
	"mount_pass": [Vector3(-301, 1.7, -268), Vector3(-301, 1.7, -284), Vector3(-300, 2.0, -300), Vector3(-300, 3.0, -320)],
	"mount_gate": [Vector3(-294, 2.0, -306), Vector3(-296, 2.0, -309), Vector3(-300, 2.5, -318), Vector3(-300, 3.0, -322)],
	"mount_village": [Vector3(-290, 6.5, -316), Vector3(-310, 6.5, -316), Vector3(-300, 1.5, -334), Vector3(-300, 1.5, -334)],
	"mount_low": [Vector3(-296, 0.5, -290), Vector3(-298, 0.6, -291), Vector3(-302, 1.6, -300), Vector3(-303, 1.6, -303)],
}

## Настроения мест: небо (верх, горизонт), солнце (цвет, сила, высота°), окружение, туман, цвет окружения
const MOODS: Dictionary = {
	StoryShot.Mood.FOREST: [Color(0.18, 0.28, 0.42), Color(0.75, 0.6, 0.45), Color(1.0, 0.8, 0.6), 0.9, 16.0, 0.55,
		0.012, Color(0.45, 0.5, 0.42)],
	StoryShot.Mood.GRAVEYARD: [Color(0.02, 0.03, 0.08), Color(0.12, 0.16, 0.22), Color(0.55, 0.65, 0.95), 0.4, 40.0,
		0.45, 0.014, Color(0.3, 0.36, 0.46)],
	StoryShot.Mood.INDUSTRIAL: [Color(0.35, 0.28, 0.22), Color(0.85, 0.55, 0.32), Color(1.0, 0.7, 0.42), 0.9, 18.0, 0.6,
		0.01, Color(0.6, 0.5, 0.42)],
	StoryShot.Mood.MOUNTAIN: [Color(0.35, 0.55, 0.85), Color(0.85, 0.88, 0.92), Color(1.0, 0.97, 0.92), 1.3, 35.0, 0.75,
		0.004, Color(0.72, 0.75, 0.8)],
}


static func get_camera(camera_name: String) -> Array:
	return CAMERAS.get(camera_name, [])


## Построить место настроения (один раз) и расставить актёров
static func build(stage: StoryStage, mood: int, sets: Dictionary) -> void:
	if not sets.has(mood):
		var root := Node3D.new()
		root.name = "Set_%d" % mood
		stage.add_child(root)
		sets[mood] = root
		match mood:
			StoryShot.Mood.FOREST:
				_build_forest(stage, root)
			StoryShot.Mood.GRAVEYARD:
				_build_graveyard(stage, root)
			StoryShot.Mood.INDUSTRIAL:
				_build_industrial(stage, root)
			StoryShot.Mood.MOUNTAIN:
				_build_mountain(stage, root)
	match mood:
		StoryShot.Mood.FOREST:
			_actors_forest(stage)
		StoryShot.Mood.GRAVEYARD:
			_actors_graveyard(stage)
		StoryShot.Mood.INDUSTRIAL:
			_actors_industrial(stage)
		StoryShot.Mood.MOUNTAIN:
			_actors_mountain(stage)


# ---------- Лес ----------

static func _build_forest(stage: StoryStage, root: Node3D) -> void:
	var h: Vector3 = FOREST_ORIGIN
	_ground(root, h, Color(0.2, 0.27, 0.16), 260.0)
	# Трасса вдоль X
	var straight: PackedScene = stage._load(StoryStage.ROAD_STRAIGHT)
	var x: float = -64.0
	while x <= 64.0:
		stage._place_into(root, straight, h + Vector3(x, 0.0, 0.0), PI * 0.5, 1.0)
		x += StoryStage.ROAD_TILE
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	# Сосны: густо по обе стороны трассы, просвет у лагеря и у вышки
	for i in 170:
		var at := Vector3(rng.randf_range(-70.0, 70.0), 0.0, rng.randf_range(-60.0, 60.0))
		if absf(at.z) < 6.0 or at.distance_to(Vector3(12.0, 0.0, 10.0)) < 8.0 \
				or at.distance_to(Vector3(-14.0, 0.0, -14.0)) < 5.0:
			continue
		stage._place_into(root, stage._load(PINES[i % PINES.size()]), h + at, rng.randf() * TAU,
			KENNEY_SCALE * rng.randf_range(1.2, 1.8))
	for i in 14:
		var at := Vector3(rng.randf_range(-40.0, 40.0), 0.0, rng.randf_range(6.5, 30.0) * (1.0 if i % 2 == 0 else -1.0))
		stage._place_into(root, stage._load(GRAVE + ("rocks.glb" if i % 3 != 0 else "trunk.glb")), h + at,
			rng.randf() * TAU, KENNEY_SCALE * 1.3)
	# Лагерь разведчиков: костёр, палатки
	var camp: Vector3 = h + Vector3(12.0, 0.0, 10.0)
	stage._place_into(root, stage._load(SURV + "campfire-pit.glb"), camp, 0.0, SURVIVAL_SCALE)
	stage._place_into(root, stage._load(SURV + "tent-canvas.glb"), camp + Vector3(-4.0, 0.0, -2.0), 0.8, SURVIVAL_SCALE)
	stage._place_into(root, stage._load(SURV + "tent.glb"), camp + Vector3(3.5, 0.0, -3.0), -0.6, SURVIVAL_SCALE)
	_fire_light(root, camp + Vector3.UP * 0.4, 1.0)
	# Вышка связи из примитивов: 4 ноги, перекладины, красный огонь наверху
	_radio_tower(root, h + Vector3(-14.0, 0.0, -14.0), 26.0)


static func _radio_tower(root: Node3D, base: Vector3, height: float) -> void:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.55, 0.3, 0.22)
	steel.metallic = 0.4
	steel.roughness = 0.7
	var half: float = 1.6
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_box(root, base + Vector3(corner.x * half, height * 0.5, corner.y * half), Vector3(0.25, height, 0.25), steel)
	var y: float = 3.0
	while y < height:
		_box(root, base + Vector3(0.0, y, -half), Vector3(half * 2.0, 0.15, 0.15), steel)
		_box(root, base + Vector3(0.0, y, half), Vector3(half * 2.0, 0.15, 0.15), steel)
		_box(root, base + Vector3(-half, y, 0.0), Vector3(0.15, 0.15, half * 2.0), steel)
		_box(root, base + Vector3(half, y, 0.0), Vector3(0.15, 0.15, half * 2.0), steel)
		y += 3.0
	_box(root, base + Vector3(0.0, height + 2.0, 0.0), Vector3(0.12, 4.0, 0.12), steel)
	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color(1.0, 0.15, 0.1)
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.15, 0.1)
	lamp.emission_energy_multiplier = 3.0
	_box(root, base + Vector3(0.0, height + 4.1, 0.0), Vector3(0.4, 0.4, 0.4), lamp)


static func _actors_forest(stage: StoryStage) -> void:
	var h: Vector3 = FOREST_ORIGIN
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	# Мертвецы бредут по трассе
	for i in 10:
		var start: Vector3 = h + Vector3(rng.randf_range(-30.0, 30.0), 0.0, rng.randf_range(-3.0, 3.0))
		var finish: Vector3 = start + Vector3(rng.randf_range(-10.0, 10.0), 0.0, rng.randf_range(-2.0, 2.0))
		stage._add_actor(stage._load(StoryStage.ZOMBIES[i % StoryStage.ZOMBIES.size()]), rng.randf_range(1.65, 1.9),
			PackedVector3Array([start, finish, start]), rng.randf_range(0.5, 0.9), &"Walk", &"Idle", rng.randf())
	# Разведчики сидят у костра
	var camp: Vector3 = h + Vector3(12.0, 0.0, 10.0)
	for i in 4:
		var angle: float = TAU * i / 4.0 + 0.5
		var at: Vector3 = camp + Vector3(cos(angle), 0.0, sin(angle)) * 2.0
		var person: StageActor = stage._add_actor(stage._load(StoryStage.PEOPLE_KENNEY[(i * 3) % StoryStage.PEOPLE_KENNEY.size()]),
			1.7, PackedVector3Array([at]), 0.0, &"walk", &"sit", 0.0)
		if person != null:
			person.rotation.y = atan2(at.x - camp.x, at.z - camp.z)
	stage._add_fire(camp + Vector3.UP * 0.3, 0.7)


# ---------- Кладбище ----------

static func _build_graveyard(stage: StoryStage, root: Node3D) -> void:
	var h: Vector3 = GRAVEYARD_ORIGIN
	_ground(root, h, Color(0.16, 0.2, 0.14), 220.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	# Ряды могил по обе стороны дорожки
	for row in 6:
		for column in 8:
			if column == 3 or column == 4:
				continue  # дорожка к часовне
			var at := Vector3(-14.0 + column * 4.0 + rng.randf_range(-0.4, 0.4), 0.0, -8.0 + row * 4.0)
			stage._place_into(root, stage._load(GRAVESTONES[(row * 8 + column) % GRAVESTONES.size()]), h + at,
				rng.randf_range(-0.15, 0.15), KENNEY_SCALE)
			if (row + column) % 3 == 0:
				stage._place_into(root, stage._load(GRAVE + "grave.glb"), h + at + Vector3(0.0, 0.0, 1.2), 0.0, KENNEY_SCALE)
	# Мамина могила: цветы из кривых свечек
	stage._place_into(root, stage._load(GRAVE + "gravestone-wide.glb"), h + Vector3(5.0, 0.0, -3.0), 0.0, KENNEY_SCALE)
	stage._place_into(root, stage._load(GRAVE + "lantern-candle.glb"), h + Vector3(4.3, 0.0, -1.8), 0.0, KENNEY_SCALE * 0.6)
	stage._place_into(root, stage._load(GRAVE + "lantern-candle.glb"), h + Vector3(5.8, 0.0, -1.9), 0.0, KENNEY_SCALE * 0.6)
	# Часовня (большой склеп) в конце дорожки, ограда и сосны вокруг
	stage._place_into(root, stage._load(GRAVE + "crypt-large.glb"), h + Vector3(0.0, 0.0, -14.0), 0.0, KENNEY_SCALE * 1.8)
	var fence: PackedScene = stage._load(GRAVE + "iron-fence.glb")
	var along: float = -22.0
	while along <= 22.0:
		stage._place_into(root, fence, h + Vector3(along, 0.0, 18.0), 0.0, KENNEY_SCALE)
		stage._place_into(root, fence, h + Vector3(along, 0.0, -22.0), 0.0, KENNEY_SCALE)
		along += 2.2
	for i in 70:
		var at := Vector3(rng.randf_range(-60.0, 60.0), 0.0, rng.randf_range(-60.0, 50.0))
		if absf(at.x) < 26.0 and at.z > -26.0 and at.z < 22.0:
			continue
		stage._place_into(root, stage._load(PINES[i % PINES.size()]), h + at, rng.randf() * TAU,
			KENNEY_SCALE * rng.randf_range(1.2, 1.7))
	for at: Vector3 in [Vector3(-3.0, 0.0, 4.0), Vector3(3.0, 0.0, -8.0)]:
		stage._place_into(root, stage._load(GRAVE + "fire-basket.glb"), h + at, 0.0, KENNEY_SCALE)
		_fire_light(root, h + at + Vector3.UP * 1.6, 0.6)


static func _actors_graveyard(stage: StoryStage) -> void:
	var h: Vector3 = GRAVEYARD_ORIGIN
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for i in 9:
		var start: Vector3 = h + Vector3(rng.randf_range(-14.0, 14.0), 0.0, rng.randf_range(-6.0, 12.0))
		var finish: Vector3 = start + Vector3(rng.randf_range(-4.0, 4.0), 0.0, rng.randf_range(-3.0, 3.0))
		var zombie: StageActor = stage._add_actor(stage._load(StoryStage.ZOMBIES[i % StoryStage.ZOMBIES.size()]),
			rng.randf_range(1.6, 1.85), PackedVector3Array([start, finish, start]), rng.randf_range(0.4, 0.7),
			&"Walk", &"Idle", rng.randf())
		if zombie != null and i % 4 == 1:
			# Встаёт из могилы — ползёт
			zombie.speed = 0.3
			zombie.move_anim = &"Crawl"
			zombie.play(&"Crawl")


# ---------- Промзона ----------

static func _build_industrial(stage: StoryStage, root: Node3D) -> void:
	var h: Vector3 = INDUSTRIAL_ORIGIN
	_ground(root, h, Color(0.27, 0.26, 0.25), 260.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	# Цеха вдоль двух сторон двора
	for side: float in [-1.0, 1.0]:
		var x: float = -40.0
		var index: int = 0
		while x < 40.0:
			stage._place_into(root, stage._load(FACTORIES[index % FACTORIES.size()]), h + Vector3(x, 0.0, side * 22.0),
				0.0 if side < 0.0 else PI, KIT_SCALE)
			index += 1
			x += 14.0 + rng.randf_range(0.0, 3.0)
	stage._place_into(root, stage._load(IND + "chimney-large.glb"), h + Vector3(18.0, 0.0, -34.0), 0.0, KIT_SCALE)
	stage._place_into(root, stage._load(IND + "chimney-medium.glb"), h + Vector3(-24.0, 0.0, -32.0), 0.0, KIT_SCALE)
	stage._place_into(root, stage._load(IND + "water-tower.glb"), h + Vector3(-34.0, 0.0, 30.0), 0.0, KIT_SCALE)
	for at: Vector3 in [Vector3(10.0, 0.0, -8.0), Vector3(-14.0, 0.0, 6.0)]:
		stage._place_into(root, stage._load(IND + "detail-tank-large.glb"), h + at, rng.randf() * TAU, KIT_SCALE * 0.55)
	for i in 6:
		var at := Vector3(rng.randf_range(-24.0, 24.0), 0.0, rng.randf_range(-14.0, 14.0))
		if absf(at.x) < 5.0:
			continue
		stage._place_into(root, stage._load(CONTAINERS[i % CONTAINERS.size()]), h + at, rng.randf() * TAU, KIT_SCALE)
	for i in 12:
		var at := Vector3(rng.randf_range(-20.0, 20.0), 0.0, rng.randf_range(-12.0, 12.0))
		stage._place_into(root, stage._load(ENV + ("Pipes.gltf" if i % 2 == 0 else "Pallet.gltf")), h + at,
			rng.randf() * TAU, 1.0)


static func _actors_industrial(stage: StoryStage) -> void:
	var h: Vector3 = INDUSTRIAL_ORIGIN
	var rng := RandomNumberGenerator.new()
	rng.seed = 29
	for at: Vector3 in [Vector3(-2.0, 0.0, 2.0), Vector3(6.0, 0.0, 9.0), Vector3(-9.0, 0.0, -6.0)]:
		stage._place_actor_prop(stage._load(StoryStage.BARREL), h + at, 1.0)
		stage._add_fire(h + at + Vector3.UP * 1.1, 0.9)
	for i in 10:
		var start: Vector3 = h + Vector3(rng.randf_range(-18.0, 18.0), 0.0, rng.randf_range(-10.0, 10.0))
		var finish: Vector3 = start + Vector3(rng.randf_range(-8.0, 8.0), 0.0, rng.randf_range(-3.0, 3.0))
		stage._add_actor(stage._load(StoryStage.ZOMBIES[i % StoryStage.ZOMBIES.size()]), rng.randf_range(1.65, 1.9),
			PackedVector3Array([start, finish, start]), rng.randf_range(0.5, 0.9), &"Walk", &"Idle", rng.randf())
	var truck: StageCar = stage._add_car(stage._load(StoryStage.ARMORED_TRUCK), PackedVector3Array(), 0.0, false, 0.0, 30.0)
	if truck != null:
		truck.position = h + Vector3(4.0, 0.0, 14.0)


# ---------- Горы ----------

static func _build_mountain(stage: StoryStage, root: Node3D) -> void:
	var h: Vector3 = MOUNTAIN_ORIGIN
	_ground(root, h, Color(0.82, 0.84, 0.88), 300.0)  # снег
	var rng := RandomNumberGenerator.new()
	rng.seed = 53
	# Склоны перевала: громадные камни по обе стороны дороги (дорога вдоль Z)
	for i in 22:
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var at := Vector3(side * rng.randf_range(14.0, 45.0), rng.randf_range(-1.2, 0.0), rng.randf_range(-15.0, 60.0))
		stage._place_into(root, stage._load(BIG_ROCKS[i % BIG_ROCKS.size()]), h + at, rng.randf() * TAU,
			rng.randf_range(1.8, 3.0))
	for i in 90:
		var at := Vector3(rng.randf_range(-70.0, 70.0), 0.0, rng.randf_range(-70.0, 70.0))
		if absf(at.x) < 9.0 or (at.z < -18.0 and absf(at.x) < 22.0):
			continue
		stage._place_into(root, stage._load(PINES[i % PINES.size()]), h + at, rng.randf() * TAU,
			KENNEY_SCALE * rng.randf_range(1.0, 1.6))
	# Дорога: тёмная полоса по снегу
	var road := StandardMaterial3D.new()
	road.albedo_color = Color(0.36, 0.34, 0.33)
	_box(root, h + Vector3(0.0, 0.02, 0.0), Vector3(6.0, 0.04, 140.0), road)
	# Деревня за частоколом и воротами (север)
	var fence: PackedScene = stage._load(SURV + "fence-fortified.glb")
	var x: float = -18.0
	while x <= 18.0:
		if absf(x) > 3.0:
			stage._place_into(root, fence, h + Vector3(x, 0.0, -22.0), 0.0, SURVIVAL_SCALE)
		x += 3.4
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.42, 0.3, 0.2)
	_box(root, h + Vector3(-3.4, 2.5, -22.0), Vector3(0.6, 5.0, 0.6), wood)
	_box(root, h + Vector3(3.4, 2.5, -22.0), Vector3(0.6, 5.0, 0.6), wood)
	_box(root, h + Vector3(0.0, 5.2, -22.0), Vector3(7.6, 0.6, 0.6), wood)
	for i in HOUSES.size() * 2:
		var at := Vector3(-14.0 + (i % 4) * 9.0, 0.0, -32.0 - floorf(i / 4.0) * 10.0)
		stage._place_fitted_into(root, stage._load(HOUSES[i % HOUSES.size()]), h + at, PI, 8.0)
	_fire_light(root, h + Vector3(0.0, 1.0, -30.0), 1.2)


static func _actors_mountain(stage: StoryStage) -> void:
	var h: Vector3 = MOUNTAIN_ORIGIN
	var rng := RandomNumberGenerator.new()
	rng.seed = 61
	# Мертвецы поднимаются по перевалу к воротам
	for i in 12:
		var start: Vector3 = h + Vector3(rng.randf_range(-5.0, 5.0), 0.0, rng.randf_range(4.0, 40.0))
		var finish: Vector3 = h + Vector3(rng.randf_range(-3.0, 3.0), 0.0, -14.0)
		stage._add_actor(stage._load(StoryStage.ZOMBIES[i % StoryStage.ZOMBIES.size()]), rng.randf_range(1.65, 1.9),
			PackedVector3Array([start, finish]), rng.randf_range(0.5, 0.8), &"Walk", &"Idle", rng.randf() * 0.5)
	# Деревенские у костра за воротами
	for i in 6:
		var at: Vector3 = h + Vector3(-5.0 + i * 2.0, 0.0, -28.0 + (i % 2) * 1.5)
		var person: StageActor = stage._add_actor(stage._load(StoryStage.PEOPLE_KENNEY[i % StoryStage.PEOPLE_KENNEY.size()]),
			1.7, PackedVector3Array([at]), 0.0, &"walk", &"idle", 0.0)
		if person != null:
			person.rotation.y = 0.0
	stage._add_fire(h + Vector3(0.0, 0.3, -30.0), 0.9)


# ---------- Общее ----------

static func _ground(root: Node3D, center: Vector3, color: Color, extent: float) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	var plane := PlaneMesh.new()
	plane.size = Vector2(extent, extent)
	plane.material = material
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.position = center + Vector3(0.0, -0.01, 0.0)
	root.add_child(ground)


static func _box(root: Node3D, at: Vector3, box_size: Vector3, material: Material) -> void:
	var box := BoxMesh.new()
	box.size = box_size
	box.material = material
	var part := MeshInstance3D.new()
	part.mesh = box
	part.position = at
	root.add_child(part)


static func _fire_light(root: Node3D, at: Vector3, size_scale: float) -> void:
	var flames := GraveyardBuilder.make_flames()
	flames.position = at
	flames.scale = Vector3.ONE * size_scale
	root.add_child(flames)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 2.0 * size_scale
	light.omni_range = 8.0 * size_scale
	light.position = at + Vector3.UP * 0.5
	root.add_child(light)
