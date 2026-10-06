extends Node

const PLAYER_SHOT = preload("res://assets/audio/صوت سلاح الاعب .ogg")
const MID_SHOT = preload("res://assets/audio/صوت سلاح متوسط المسافة.ogg")
const FAR_SHOT = preload("res://assets/audio/صوت سلاح بعيد المدئ.ogg")
const WHIZ = preload("res://assets/audio/bullet_whiz.wav")
const RELOAD = preload("res://assets/audio/reload_click.wav")

const ENEMY_VOICE_COUNT := 6
const WHIZ_VOICE_COUNT := 2

var player_shot: AudioStreamPlayer
var player_tail: AudioStreamPlayer
var reload_voice: AudioStreamPlayer
var enemy_voices: Array[AudioStreamPlayer3D] = []
var whiz_voices: Array[AudioStreamPlayer3D] = []
var enemy_cursor := 0
var whiz_cursor := 0

func _ready() -> void:
	player_shot = AudioStreamPlayer.new()
	player_shot.name = "PlayerShotNear"
	player_shot.stream = PLAYER_SHOT
	player_shot.volume_db = -1.0
	add_child(player_shot)

	player_tail = AudioStreamPlayer.new()
	player_tail.name = "PlayerShotTail"
	player_tail.stream = FAR_SHOT
	player_tail.volume_db = -11.0
	add_child(player_tail)

	reload_voice = AudioStreamPlayer.new()
	reload_voice.name = "ReloadVoice"
	reload_voice.stream = RELOAD
	reload_voice.volume_db = -3.0
	add_child(reload_voice)

	for i in range(ENEMY_VOICE_COUNT):
		var voice := AudioStreamPlayer3D.new()
		voice.name = "EnemyVoice_%02d" % i
		voice.max_distance = 58.0
		voice.unit_size = 4.0
		voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		voice.attenuation_filter_cutoff_hz = 8500.0
		voice.attenuation_filter_db = -4.0
		add_child(voice)
		enemy_voices.append(voice)

	for i in range(WHIZ_VOICE_COUNT):
		var voice := AudioStreamPlayer3D.new()
		voice.name = "WhizVoice_%02d" % i
		voice.stream = WHIZ
		voice.max_distance = 10.0
		voice.unit_size = 2.0
		voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(voice)
		whiz_voices.append(voice)

func play_player_shot() -> void:
	if player_shot == null:
		return
	player_shot.stop()
	player_shot.pitch_scale = randf_range(0.985, 1.015)
	player_shot.play()

	# A quiet distant tail adds space without spawning transient audio nodes.
	if player_tail != null:
		player_tail.stop()
		player_tail.pitch_scale = randf_range(0.98, 1.02)
		player_tail.play()

func play_reload() -> void:
	if reload_voice != null:
		reload_voice.stop()
		reload_voice.play()

func play_enemy_shot(at: Vector3, listener: Vector3) -> void:
	if enemy_voices.is_empty():
		return
	var voice := enemy_voices[enemy_cursor]
	enemy_cursor = (enemy_cursor + 1) % enemy_voices.size()

	var distance := at.distance_to(listener)
	if distance < 15.0:
		voice.stream = PLAYER_SHOT
		voice.volume_db = -2.5
		voice.attenuation_filter_cutoff_hz = 12000.0
	elif distance < 32.0:
		voice.stream = MID_SHOT
		voice.volume_db = -4.5
		voice.attenuation_filter_cutoff_hz = 7000.0
	else:
		voice.stream = FAR_SHOT
		voice.volume_db = -6.5
		voice.attenuation_filter_cutoff_hz = 4300.0

	voice.stop()
	voice.global_position = at
	voice.pitch_scale = randf_range(0.965, 1.035)
	voice.play()

func play_bullet_whiz(at: Vector3, intensity := 1.0) -> void:
	if whiz_voices.is_empty():
		return
	var voice := whiz_voices[whiz_cursor]
	whiz_cursor = (whiz_cursor + 1) % whiz_voices.size()
	voice.stop()
	voice.global_position = at
	voice.volume_db = linear_to_db(clampf(intensity, 0.08, 1.0)) - 2.0
	voice.pitch_scale = randf_range(0.96, 1.04)
	voice.play()

func _exit_tree() -> void:
	if is_instance_valid(player_shot):
		player_shot.stop()
	if is_instance_valid(player_tail):
		player_tail.stop()
	if is_instance_valid(reload_voice):
		reload_voice.stop()
	for voice in enemy_voices:
		if is_instance_valid(voice):
			voice.stop()
	for voice in whiz_voices:
		if is_instance_valid(voice):
			voice.stop()
