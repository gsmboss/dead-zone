class_name SocialLink
extends Resource
## Соцсеть студии: ссылка, награда за подписку (один раз), цвет и значок (окно СОЦСЕТИ, настройки)

@export var id: String = ""
@export var title: String = ""
## Что на канале (подпись в окне)
@export var description: String = ""
@export var url: String = ""
## Монеты за подписку (выдаются один раз, после перехода по ссылке)
@export var reward: int = 300
@export var color: Color = Color.WHITE
@export var icon: Texture2D
