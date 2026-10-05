class_name ZombieData
extends Resource
## Параметры типа зомби. Каждый тип — отдельный .tres файл.

@export var display_name: String = "WALKER"

@export_group("Stats")
@export var max_health: float = 100.0
@export var move_speed: float = 1.6
@export var turn_speed: float = 8.0
## Случайный разброс скорости у каждого зомби (0.15 = ±15%)
@export_range(0.0, 0.5, 0.01) var speed_variation: float = 0.15

@export_group("Attack")
@export var attack_damage: float = 10.0
## Дистанция начала атаки (по горизонтали), метры
@export var attack_range: float = 1.4
## Время замаха до удара, сек (окно, чтобы увернуться)
@export var attack_windup: float = 0.5
## Пауза после удара, сек
@export var attack_cooldown: float = 0.8

@export_group("Senses")
## Видит игрока на этом расстоянии (при прямой видимости)
@export var detection_radius: float = 15.0
## Чует игрока вплотную даже без видимости
@export var close_sense_radius: float = 3.0
## Слышит выстрелы на этом расстоянии
@export var hearing_radius: float = 30.0
## Заметив игрока, зовёт других зомби в этом радиусе (0 = не зовёт)
@export var alert_radius: float = 10.0
## Через сколько секунд без видимости сдаётся и уходит бродить
@export var lose_interest_time: float = 6.0

@export_group("Behavior")
## Радиус блуждания вокруг точки появления (0 = стоит на месте)
@export var wander_radius: float = 6.0
## Скорость блуждания относительно move_speed
@export_range(0.1, 1.0, 0.05) var wander_speed_factor: float = 0.4
## Упреждение: бежит туда, где игрок будет через столько секунд
@export_range(0.0, 1.0, 0.05) var prediction_time: float = 0.3
## Длительность вздрагивания от попадания (0 = не вздрагивает)
@export_range(0.0, 1.0, 0.05) var stagger_time: float = 0.3

@export_group("Visual")
## Модель типа (glTF с AnimationPlayer). Пусто → модель из zombie.tscn
@export var model_scene: PackedScene
## Масштаб модели. 1.6 — рост обычного зомби; хитбоксы растут пропорционально
@export_range(0.5, 4.0, 0.05) var model_scale: float = 1.6
## Цвет капсулы-заглушки. На реальную модель не влияет
@export var body_color: Color = Color(0.35, 0.5, 0.3)

@export_group("Reward")
## Очки за убийство (понадобится на этапе 4)
@export var score: int = 10
