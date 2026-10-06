class_name ChapterData
extends Resource
## Глава сюжетной кампании: место на карте, миссия, текст до и после, награды
## (спасённые люди, новый дом в лагере, своя машина).

@export var id: String = ""
@export var title: String = ""
@export var location_name: String = ""
## Положение на карте области (0..1 по ширине и высоте)
@export var map_position: Vector2 = Vector2(0.5, 0.5)
@export var mission: MissionData
## Страницы рассказа перед главой и после победы
@export_multiline var intro_pages: PackedStringArray = []
@export_multiline var outro_pages: PackedStringArray = []
## Сюжетные фильмы (StoryCinema): перед главой и после победы
@export var intro_film: StoryFilm
@export var outro_film: StoryFilm

@export_group("Rewards")
## Сколько людей спасено в главе (живут в лагере)
@export var rescued: int = 0
## Новый дом в лагере выживших
@export var unlock_house: bool = false
## Своя машина: модель (в городе — первая машина у старта) и название
@export var unlock_car: PackedScene
@export var unlock_car_name: String = ""
