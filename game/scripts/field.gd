extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player_controller.gd")
const ENEMY_SCRIPT = preload("res://scripts/enemy.gd")
const AUDIO_SCRIPT = preload("res://scripts/combat_audio.gd")
const HUD_SCRIPT = preload("res://scripts/mobile_hud.gd")
const MAP_PATH := "res://level/structure.glb"

const PLAYER_SPAWN := Vector3(64.8183, -1.00, 78.7639)
const ENEMY_SPAWNS := [
	Vector3(71.5907, -6.00, 46.2736),
	Vector3(53.2126, -6.00, 15.9321),
	Vector3(-2.9610, -11.63, 20.2343),
	Vector3(-9.1553, -11.63, -16.9238),
	Vector3(28.0, -5.8, 4.0)
]

var player: CharacterBody3D
var hud: CanvasLayer
var combat_audio: Node
var enemies: Array[Node3D] = []
var remaining := 0
var status_label: Label

func _ready() -> void:
	_build_environment()
	_build_authored_level()
	_build_gameplay()

func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	world_env.name = "MobileEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("435c69")
	sky_material.sky_horizon_color = Color("bdad92")
	sky_material.ground_bottom_color = Color("252824")
	sky_material.ground_horizon_color = Color("8e846f")
	sky_material.sun_angle_max = 18.0
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = 0.72
	environment.ambient_light_energy = 0.72
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("a69c87")
	environment.fog_light_energy = 0.55
	environment.fog_density = 0.0018
	environment.fog_sky_affect = 0.22
	world_env.environment = environment
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-47.0, -32.0, 0.0)
	sun.light_color = Color("ffe0ad")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)

func _build_authored_level() -> void:
	var packed := load(MAP_PATH) as PackedScene
	if packed == null:
		push_error("Ready-made authored map is missing: %s" % MAP_PATH)
		return
	var map_instance := packed.instantiate() as Node3D
	if map_instance == null:
		push_error("Ready-made authored map could not be instantiated")
		return
	map_instance.name = "AuthoredCombatMap"
	add_child(map_instance)
	_add_runtime_map_collisions(map_instance)
	_add_invisible_safety_floor()

func _add_runtime_map_collisions(map_root: Node3D) -> void:
	# The visible map stays 100% authored 3D geometry. These generated collision
	# bodies are invisible and let the player/enemies interact with the real mesh.
	var meshes := map_root.find_children("*", "MeshInstance3D", true, false)
	for node in meshes:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance != null and mesh_instance.mesh != null:
			mesh_instance.create_trimesh_collision()

func _add_invisible_safety_floor() -> void:
	# Invisible fallback only; no primitive geometry is rendered to the player.
	var floor := StaticBody3D.new()
	floor.name = "SafetyFloor"
	floor.position = Vector3(0, -14.25, 0)
	add_child(floor)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(280, 1.0, 280)
	collider.shape = shape
	floor.add_child(collider)

func _build_gameplay() -> void:
	combat_audio = AUDIO_SCRIPT.new()
	combat_audio.name = "CombatAudio"
	add_child(combat_audio)

	player = CharacterBody3D.new()
	player.name = "Player"
	player.set_script(PLAYER_SCRIPT)
	player.set("combat_audio", combat_audio)
	player.position = PLAYER_SPAWN
	add_child(player)

	hud = HUD_SCRIPT.new()
	hud.name = "MobileHUD"
	add_child(hud)
	hud.fire_requested.connect(player.request_fire)
	hud.reload_requested.connect(player.reload)
	hud.volume_changed.connect(combat_audio.set_master_volume)
	hud.move_changed.connect(player.set_touch_move)
	hud.look_delta.connect(player.add_touch_look)
	combat_audio.set_master_volume(0.85)
	player.connect("health_changed", Callable(hud, "set_health"))
	player.connect("ammo_changed", Callable(hud, "set_ammo"))
	player.connect("died", Callable(self, "_on_player_died"))
	status_label = hud.get_node("HUDRoot/Status") as Label

	_spawn_enemies()
	_update_status()

func _spawn_enemies() -> void:
	for index in ENEMY_SPAWNS.size():
		var enemy := CharacterBody3D.new()
		enemy.name = "Enemy_%02d" % (index + 1)
		enemy.set_script(ENEMY_SCRIPT)
		enemy.position = ENEMY_SPAWNS[index]
		enemy.set("player", player)
		enemy.set("combat_audio", combat_audio)
		enemy.connect("died", Callable(self, "_on_enemy_died"))
		add_child(enemy)
		enemies.append(enemy)
	remaining = enemies.size()

func _on_enemy_died(_enemy: Node3D) -> void:
	remaining = maxi(0, remaining - 1)
	_update_status()
	if remaining == 0 and is_instance_valid(status_label):
		status_label.text = "تم تأمين المنطقة"

func _on_player_died() -> void:
	if is_instance_valid(status_label):
		status_label.text = "انتهت المهمة — أعد المحاولة"

func _update_status() -> void:
	if is_instance_valid(status_label):
		status_label.text = "منطقة العمليات  •  أعداء متبقون: %d" % remaining
