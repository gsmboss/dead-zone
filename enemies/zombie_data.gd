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
## Цвет капсулы-заглушки. На реальную модель не влияет
@export var body_color: Color = Color(0.35, 0.5, 0.3)
## Своя модель типа (glTF с анимациями Idle/Walk/Run/Punch/HitReact/Death).
## Пусто — остаётся модель из zombie.tscn (Visual/Model)
@export var model_scene: PackedScene
## Масштаб своей модели (модель зомби в zombie.tscn — 1.6)
@export var model_scale: float = 1.6

@export_group("Tactics")
## Участвует в очереди атак (не больше MAX_ATTACKERS бьют одновременно, остальные кружат)
@export var uses_attack_queue: bool = true
## Издалека заходит со спины игрока
@export var flank_from_behind: bool = false
## Зигзаг, когда игрок целится в зомби издалека (0 = бежит прямо), метры
@export var zigzag_amplitude: float = 0.0
@export var zigzag_frequency: float = 2.5
## Потеряв игрока, проверяет столько точек вокруг места, где видел его последним
@export_range(0, 8) var search_points: int = 3
@export var search_radius: float = 6.0
## Слышит бегущего игрока на этом расстоянии без прямой видимости (0 = не слышит)
@export var footstep_hearing_radius: float = 7.0

@export_group("Boss")
## Босс: полоска здоровья в HUD, задание «убить босса»
@export var is_boss: bool = false
## Рывок к игроку с дистанции
@export var charge_enabled: bool = false
@export var charge_speed: float = 9.0
@export var charge_min_distance: float = 5.0
@export var charge_max_distance: float = 16.0
## Замах перед рывком (окно, чтобы отскочить), сек
@export var charge_windup: float = 0.7
@export var charge_duration: float = 1.3
@export var charge_cooldown: float = 7.0
@export var charge_damage: float = 30.0
## Удар по площади вблизи (вместо обычного удара, когда готов)
@export var slam_enabled: bool = false
@export var slam_radius: float = 4.0
@export var slam_windup: float = 0.9
@export var slam_cooldown: float = 6.0
@export var slam_damage: float = 30.0
## Сила отбрасывания игрока рывком и ударом, м/с
@export var knockback: float = 9.0

@export_group("Audio")
## Высота голоса: танк ниже, бегун выше
@export_range(0.3, 2.0, 0.05) var voice_pitch: float = 1.0
## Громкость голоса, дБ
@export_range(-30.0, 10.0, 0.5) var voice_volume_db: float = 0.0

@export_group("Reward")
## Очки за убийство (понадобится на этапе 4)
@export var score: int = 10
