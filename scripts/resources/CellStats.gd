extends Resource
class_name CellStats

@export_group("Energy")
@export var max_energy: float = 30.0
@export var current_energy: float = 10.0
@export var energy_gain_rate: float = 1.0 # Энергия в секунду

@export_group("Combat")
@export var attack_cost: float = 2.0 # Сколько энергии тратит выстрел
@export var fire_rate: float = 0.5 # Выстрелов в секунду
@export var projectile_speed: float = 400.0
@export var move_speed: float = 50.0

@export_group("Perks")
@export var speed_boost_duration: float = 5.0 # Длительность ускорения
@export var speed_boost_multiplier: float = 2.0 # Множитель скорости

@export_group("Visuals")
@export var size_multiplier: float = 0.05 # Как сильно энергия влияет на размер
