extends Node

const PLAYER_SHOT = preload("res://assets/audio/صوت سلاح الاعب .ogg")
const MID_SHOT = preload("res://assets/audio/صوت سلاح متوسط المسافة.ogg")
const FAR_SHOT = preload("res://assets/audio/صوت سلاح بعيد المدئ.ogg")
const WHIZ = preload("res://assets/audio/bullet_whiz.wav")
const RELOAD = preload("res://assets/audio/reload_click.wav")

const MAX_VOICES := 12
var active_voices := 0
var master_db := 0.0
var whiz_cooldown := 0.0

func _process(delta: float) -> void:
	whiz_cooldown = maxf(0.0, whiz_cooldown - delta)

func play_player_shot(_at: Vector3) -> void:
	# The player's own gun must never depend on 3D listener/attenuation state.
	# A normal AudioStreamPlayer is reliable on Android and still uses the same
	# original weapon recording.
	_play_local(PLAYER_SHOT, 0.0, 1, randf_range(0.985, 1.015))

func play_reload(_at: Vector3) -> void:
	_play_local(RELOAD, -2.0, 1, 1.0)

func play_enemy_shot(at: Vector3, listener: Vector3) -> void:
	var distance := at.distance_to(listener)
	var near_weight := 1.0 - smoothstep(18.0, 44.0, distance)
	var mid_weight := smoothstep(16.0, 42.0, distance) * (1.0 - smoothstep(92.0, 132.0, distance))
	var far_weight := smoothstep(78.0, 120.0, distance) * (1.0 - smoothstep(210.0, 252.0, distance))
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
	if whiz_cooldown > 0.0:
		return
	whiz_cooldown = 0.13
	_play_3d(WHIZ, at, linear_to_db(maxf(0.05, intensity)) - 1.0, 9.0, 1)

func set_master_volume(value: float) -> void:
	var level := clampf(value, 0.0, 1.0)
	master_db = -80.0 if level <= 0.001 else linear_to_db(level)

func _play_local(stream: AudioStream, offset_db: float, cost: int, pitch: float) -> void:
	if active_voices >= MAX_VOICES:
		return
	active_voices += cost
	var voice := AudioStreamPlayer.new()
	voice.stream = stream
	voice.volume_db = master_db + offset_db
	voice.pitch_scale = pitch
	voice.bus = "Master"
	add_child(voice)
	voice.finished.connect(func():
		active_voices = maxi(0, active_voices - cost)
		voice.queue_free()
	)
	voice.play()

func _exit_tree() -> void:
	for child in get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer3D:
			child.stop()
			child.queue_free()

func _play_3d(stream: AudioStream, at: Vector3, offset_db: float, range_m: float, cost: int, cutoff_hz: float = 16000.0, filter_db: float = -2.0) -> void:
	if active_voices >= MAX_VOICES:
		return
	active_voices += cost
	var voice := AudioStreamPlayer3D.new()
	voice.stream = stream
	voice.volume_db = master_db + offset_db
	voice.max_distance = range_m
	voice.unit_size = 4.0
	voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	voice.attenuation_filter_cutoff_hz = cutoff_hz
	voice.attenuation_filter_db = filter_db
	voice.pitch_scale = randf_range(0.97, 1.03)
	voice.bus = "Master"
	add_child(voice)
	# Set the global position after parenting. This avoids treating a world-space
	# muzzle coordinate as a local offset when the audio node ever gets moved.
	voice.global_position = at
	voice.finished.connect(func():
		active_voices = maxi(0, active_voices - cost)
		voice.queue_free()
	)
	voice.play()

func _weight_db(value: float) -> float:
	return linear_to_db(maxf(0.015, value))
