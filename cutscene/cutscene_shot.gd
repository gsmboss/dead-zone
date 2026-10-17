class_name CutsceneShot
extends Resource
## Один план кат-сцены: камера летит из from в to, глядя на look, с субтитром.
## Координаты — в мире или относительно якоря (игрок, босс), см. relative_to.

enum Space { WORLD, ANCHOR }

@export var relative_to: Space = Space.WORLD
@export var from_position: Vector3 = Vector3(0, 5, 10)
@export var to_position: Vector3 = Vector3(0, 3, 6)
@export var look_from: Vector3 = Vector3.ZERO
@export var look_to: Vector3 = Vector3.ZERO
@export var duration: float = 3.0
@export_multiline var subtitle: String = ""
## Смешная озвучка плана (синтез речи; язык — как в телефоне). Пусто — без голоса
@export_multiline var voice_ru: String = ""
@export_multiline var voice_en: String = ""
