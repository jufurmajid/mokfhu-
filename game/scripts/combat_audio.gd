extends Node

const PLAYER_SHOT = preload("res://assets/audio/صوت سلاح الاعب .ogg")
const MID_SHOT = preload("res://assets/audio/صوت سلاح متوسط المسافة.ogg")
const FAR_SHOT = preload("res://assets/audio/صوت سلاح بعيد المدئ.ogg")
const WHIZ = preload("res://assets/audio/bullet_whiz.wav")
const RELOAD = preload("res://assets/audio/reload_click.wav")

const MAX_VOICES := 12
var active_voices := 0
var master_db := -2.0

func play_player_shot(at: Vector3) -> void:
	_play_3d(PLAYER_SHOT, at, 0.0, 36.0, 2)

func play_reload(at: Vector3) -> void:
	_play_3d(RELOAD, at, -3.0, 8.0, 1)

func play_enemy_shot(at: Vector3, listener: Vector3) -> void:
	var distance := at.distance_to(listener)
	var near_weight := _falloff(distance, 0.0, 32.0)
	var mid_weight := _falloff(distance, 18.0, 105.0)
	var far_weight := _falloff(distance, 75.0, 230.0)
	var total := near_weight + mid_weight + far_weight
	if total <= 0.001:
		return
	if near_weight > 0.02:
		_play_3d(PLAYER_SHOT, at, _weight_db(near_weight / maxf(total, 1.0)), 42.0, 1, 16000.0, -1.0)
	if mid_weight > 0.02:
		_play_3d(MID_SHOT, at, _weight_db(mid_weight / maxf(total, 1.0)), 115.0, 1, 6200.0, -7.0)
	if far_weight > 0.02:
		_play_3d(FAR_SHOT, at, _weight_db(far_weight / maxf(total, 1.0)), 250.0, 1, 2600.0, -15.0)

func play_bullet_whiz(at: Vector3, intensity: float) -> void:
	_play_3d(WHIZ, at, linear_to_db(maxf(0.05, intensity)) - 1.0, 9.0, 1)

func set_master_volume(value: float) -> void:
	master_db = linear_to_db(clampf(value, 0.0, 1.0))

func _play_3d(stream: AudioStream, at: Vector3, offset_db: float, range_m: float, cost: int, cutoff_hz: float = 16000.0, filter_db: float = -2.0) -> void:
	if active_voices >= MAX_VOICES:
		return
	active_voices += cost
	var voice := AudioStreamPlayer3D.new()
	voice.stream = stream
	voice.position = at
	voice.volume_db = master_db + offset_db
	voice.max_distance = range_m
	voice.unit_size = 4.0
	voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	voice.attenuation_filter_cutoff_hz = cutoff_hz
	voice.attenuation_filter_db = filter_db
	voice.bus = "Master"
	add_child(voice)
	voice.finished.connect(func():
		active_voices = maxi(0, active_voices - cost)
		voice.queue_free()
	)
	voice.play()

func _falloff(value: float, start: float, end: float) -> float:
	return 1.0 - smoothstep(start, end, value)

func _weight_db(value: float) -> float:
	return linear_to_db(maxf(0.015, value))
