extends Node2D
class_name LevelSfx

const FIRE_SEQUENCE: Array[int] = [1, 2, 1, 1, 1, 2, 2, 1, 2, 1, 2, 2, 1, 2, 1, 2, 2, 1]
const DAMAGE_SEQUENCE: Array[int] = [1, 2, 1, 2, 2, 1, 1, 2, 1, 2, 1, 1, 2, 2, 1, 2]
const SHIELD_SEQUENCE: Array[int] = [2, 1, 1, 2, 1, 2, 2, 1, 2, 1, 2, 1, 1, 2, 2, 1]
const FIRE_POOL_SIZE: int = 14
const IMPACT_POOL_SIZE: int = 12
const PERK_POOL_SIZE: int = 2
const SFX_BUS_NAME: StringName = &"Master"
const FIRE_SOUND_1_PATH: String = "res://audio/FireCell_1.ogg"
const FIRE_SOUND_2_PATH: String = "res://audio/FireCell_2.ogg"
const DAMAGE_SOUND_1_PATH: String = "res://audio/DemageCell.ogg"
const DAMAGE_SOUND_2_PATH: String = "res://audio/cell_demage_2.ogg"
const FRIENDLY_FIRE_SOUND_PATH: String = "res://audio/frendly_fire.ogg"
const SHIELD_SOUND_1_PATH: String = "res://audio/shot_shield.ogg"
const SHIELD_SOUND_2_PATH: String = "res://audio/shot_shield_1.ogg"
const ACTIVE_PERK_SOUND_PATH: String = "res://audio/active_perk.ogg"

@export var fire_sound_1: AudioStream = null
@export var fire_sound_2: AudioStream = null
@export var damage_sound_1: AudioStream = null
@export var damage_sound_2: AudioStream = null
@export var friendly_fire_sound: AudioStream = null
@export var shield_sound_1: AudioStream = null
@export var shield_sound_2: AudioStream = null
@export var active_perk_sound: AudioStream = null
@export var fire_sound_1_volume_db: float = -7.0
@export var fire_sound_2_volume_db: float = -7.0
@export var damage_sound_1_volume_db: float = -4.0
@export var damage_sound_2_volume_db: float = -15.0
@export var friendly_fire_volume_db: float = -3.0
@export var shield_sound_1_volume_db: float = 0.0
@export var shield_sound_2_volume_db: float = 0.0
@export var active_perk_volume_db: float = -4.0
@export var max_distance: float = 1800.0

var _fire_players: Array[AudioStreamPlayer2D] = []
var _impact_players: Array[AudioStreamPlayer2D] = []
var _perk_players: Array[AudioStreamPlayer] = []
var _fire_sequence_index: int = 0
var _damage_sequence_index: int = 0
var _shield_sequence_index: int = 0
var _fire_player_index: int = 0
var _impact_player_index: int = 0
var _perk_player_index: int = 0

func _ready() -> void:
	add_to_group("level_sfx")
	_load_missing_streams()
	_build_pool(_fire_players, FIRE_POOL_SIZE, fire_sound_1_volume_db)
	_build_pool(_impact_players, IMPACT_POOL_SIZE, damage_sound_1_volume_db)
	_build_perk_pool()

func play_fire(at_position: Vector2) -> void:
	if _fire_players.is_empty():
		return

	var stream_id: int = FIRE_SEQUENCE[_fire_sequence_index]
	_fire_sequence_index = (_fire_sequence_index + 1) % FIRE_SEQUENCE.size()
	var next_stream: AudioStream = fire_sound_2 if stream_id == 2 else fire_sound_1
	var volume_db: float = fire_sound_2_volume_db if stream_id == 2 else fire_sound_1_volume_db
	if next_stream == null:
		return

	var player: AudioStreamPlayer2D = _next_player(_fire_players, _fire_player_index)
	_fire_player_index = (_fire_player_index + 1) % _fire_players.size()
	player.stream = next_stream
	player.volume_db = volume_db
	_play_at(player, at_position)

func play_damage(at_position: Vector2) -> void:
	var stream_id: int = DAMAGE_SEQUENCE[_damage_sequence_index]
	_damage_sequence_index = (_damage_sequence_index + 1) % DAMAGE_SEQUENCE.size()
	var next_stream: AudioStream = damage_sound_2 if stream_id == 2 else damage_sound_1
	var volume_db: float = damage_sound_2_volume_db if stream_id == 2 else damage_sound_1_volume_db
	_play_impact(next_stream, at_position, volume_db)

func play_friendly_hit(at_position: Vector2) -> void:
	_play_impact(friendly_fire_sound, at_position, friendly_fire_volume_db)

func play_shield(at_position: Vector2) -> void:
	var stream_id: int = SHIELD_SEQUENCE[_shield_sequence_index]
	_shield_sequence_index = (_shield_sequence_index + 1) % SHIELD_SEQUENCE.size()
	var next_stream: AudioStream = shield_sound_2 if stream_id == 2 else shield_sound_1
	var volume_db: float = shield_sound_2_volume_db if stream_id == 2 else shield_sound_1_volume_db
	_play_impact(next_stream, at_position, volume_db)

func play_active_perk() -> void:
	if active_perk_sound == null or _perk_players.is_empty():
		return
	var player: AudioStreamPlayer = _perk_players[_perk_player_index]
	_perk_player_index = (_perk_player_index + 1) % _perk_players.size()
	player.volume_db = active_perk_volume_db
	player.stop()
	player.play()

func get_sound_volume_db(sound_id: StringName, fallback: float) -> float:
	match sound_id:
		&"fire_cell_1":
			return fire_sound_1_volume_db
		&"fire_cell_2":
			return fire_sound_2_volume_db
		&"damage_cell_1":
			return damage_sound_1_volume_db
		&"damage_cell_2":
			return damage_sound_2_volume_db
		&"friendly_fire":
			return friendly_fire_volume_db
		&"shield_1":
			return shield_sound_1_volume_db
		&"shield_2":
			return shield_sound_2_volume_db
		&"active_perk":
			return active_perk_volume_db
	return fallback

func set_sound_volume_db(sound_id: StringName, value: float) -> void:
	match sound_id:
		&"fire_cell_1":
			fire_sound_1_volume_db = value
			_set_stream_volume(_fire_players, fire_sound_1, value)
		&"fire_cell_2":
			fire_sound_2_volume_db = value
			_set_stream_volume(_fire_players, fire_sound_2, value)
		&"damage_cell_1":
			damage_sound_1_volume_db = value
			_set_stream_volume(_impact_players, damage_sound_1, value)
		&"damage_cell_2":
			damage_sound_2_volume_db = value
			_set_stream_volume(_impact_players, damage_sound_2, value)
		&"friendly_fire":
			friendly_fire_volume_db = value
			_set_stream_volume(_impact_players, friendly_fire_sound, value)
		&"shield_1":
			shield_sound_1_volume_db = value
			_set_stream_volume(_impact_players, shield_sound_1, value)
		&"shield_2":
			shield_sound_2_volume_db = value
			_set_stream_volume(_impact_players, shield_sound_2, value)
		&"active_perk":
			active_perk_volume_db = value
			for player in _perk_players:
				player.volume_db = value

func _play_impact(stream: AudioStream, at_position: Vector2, volume_db: float) -> void:
	if _impact_players.is_empty():
		return
	if stream == null:
		return

	var player: AudioStreamPlayer2D = _next_player(_impact_players, _impact_player_index)
	_impact_player_index = (_impact_player_index + 1) % _impact_players.size()
	player.stream = stream
	player.volume_db = volume_db
	_play_at(player, at_position)

func _load_missing_streams() -> void:
	if fire_sound_1 == null:
		fire_sound_1 = AudioStreamOggVorbis.load_from_file(FIRE_SOUND_1_PATH)
	if fire_sound_2 == null:
		fire_sound_2 = AudioStreamOggVorbis.load_from_file(FIRE_SOUND_2_PATH)
	if damage_sound_1 == null:
		damage_sound_1 = AudioStreamOggVorbis.load_from_file(DAMAGE_SOUND_1_PATH)
	if damage_sound_2 == null:
		damage_sound_2 = AudioStreamOggVorbis.load_from_file(DAMAGE_SOUND_2_PATH)
	if friendly_fire_sound == null:
		friendly_fire_sound = AudioStreamOggVorbis.load_from_file(FRIENDLY_FIRE_SOUND_PATH)
	if shield_sound_1 == null:
		shield_sound_1 = AudioStreamOggVorbis.load_from_file(SHIELD_SOUND_1_PATH)
	if shield_sound_2 == null:
		shield_sound_2 = AudioStreamOggVorbis.load_from_file(SHIELD_SOUND_2_PATH)
	if active_perk_sound == null:
		active_perk_sound = AudioStreamOggVorbis.load_from_file(ACTIVE_PERK_SOUND_PATH)

func _build_pool(pool: Array[AudioStreamPlayer2D], amount: int, volume_db: float) -> void:
	for _i in range(amount):
		var player := AudioStreamPlayer2D.new()
		player.bus = SFX_BUS_NAME
		player.volume_db = volume_db
		player.max_distance = max_distance
		player.attenuation = 1.0
		add_child(player)
		pool.append(player)

func _build_perk_pool() -> void:
	for _i in range(PERK_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.stream = active_perk_sound
		player.bus = SFX_BUS_NAME
		player.volume_db = active_perk_volume_db
		add_child(player)
		_perk_players.append(player)

func _set_stream_volume(pool: Array[AudioStreamPlayer2D], stream: AudioStream, volume_db: float) -> void:
	for player in pool:
		if player.stream == stream:
			player.volume_db = volume_db

func _next_player(pool: Array[AudioStreamPlayer2D], index: int) -> AudioStreamPlayer2D:
	return pool[index % pool.size()]

func _play_at(player: AudioStreamPlayer2D, at_position: Vector2) -> void:
	player.global_position = at_position
	player.stop()
	player.play()
