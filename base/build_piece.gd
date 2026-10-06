class_name BuildPiece
extends Resource
## Блок стройки в убежище: одна клетка 1×1×1 м, как в Minecraft. Куб с пиксельной текстурой
## (BLOCK) или модель, вписанная в клетку (MODEL). Цена — монеты и лом.

enum Kind { BLOCK, MODEL }
enum Category { BLOCKS, WALLS, THINGS, LIGHT }
## Рисунок пиксельной текстуры куба
enum Pattern { NOISE, PLANKS, BRICKS, PANEL, GLASS, LAMP }

const CATEGORY_NAMES: PackedStringArray = ["БЛОКИ", "ОГРАДА", "ВЕЩИ", "СВЕТ"]

@export var id: String = ""
@export var title: String = ""
@export var category: Category = Category.BLOCKS
@export var kind: Kind = Kind.BLOCK
@export_range(0, 100000, 1) var price: int = 10
## Лом (из миссий) для металлических и сложных вещей
@export_range(0, 99, 1) var scrap: int = 0
## Можно встать и упереться (коллизия на всю клетку по высоте модели)
@export var solid: bool = true

@export_group("Block")
@export var color: Color = Color(0.6, 0.6, 0.6)
## Разброс яркости пикселей
@export_range(0.0, 0.5, 0.01) var color_variation: float = 0.08
@export var pattern: Pattern = Pattern.NOISE
@export var transparent: bool = false
@export var emissive: bool = false

@export_group("Model")
@export var model: PackedScene
## Доля клетки, которую занимает модель по ширине
@export_range(0.3, 1.0, 0.01) var fill: float = 0.92
@export var model_yaw_degrees: float = 0.0

@export_group("Light")
## Свет (альфа 0 — без света)
@export var light_color: Color = Color(1.0, 0.7, 0.35, 0.0)
@export_range(0.0, 20.0, 0.1) var light_range: float = 7.0


func has_light() -> bool:
	return light_color.a > 0.0


func get_price_text() -> String:
	return "%d МОНЕТ" % price if scrap <= 0 else "%d МОНЕТ + %d ЛОМ" % [price, scrap]
