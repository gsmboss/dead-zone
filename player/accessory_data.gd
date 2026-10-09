class_name AccessoryData
extends Resource
## Аксессуар персонажа: шляпа или вещь на лицо. Внешний вид собирается кодом из простых фигур
## (AccessoryBuilder по kind) — без отдельных моделей. Покупка и надевание — GameState.

enum Category { REGULAR, FUNNY, RARE }
enum Slot { HEAD, FACE }
const CATEGORY_NAMES: PackedStringArray = ["ОБЫЧНЫЕ", "СМЕШНЫЕ", "РЕДКИЕ"]
const CATEGORY_COLORS: Array[Color] = [Color(0.75, 0.8, 0.85), Color(1.0, 0.6, 0.3), Color(0.85, 0.55, 1.0)]

@export var id: String = ""
@export var title: String = ""
@export var category: Category = Category.REGULAR
## Место: на голове (шляпы, уши, нимб) или на лице (очки, нос, усы, бандана)
@export var slot: Slot = Slot.HEAD
@export var price: int = 200
## Форма (см. AccessoryBuilder.build): cap, beanie, cowboy, top_hat, party_hat, crown, halo, bunny_ears,
## viking, chef, propeller, traffic_cone, pot, headphones, sunglasses, glasses_round, clown_nose,
## mustache, bandana, eyepatch
@export var kind: String = "cap"
@export var color: Color = Color(0.8, 0.2, 0.2)
