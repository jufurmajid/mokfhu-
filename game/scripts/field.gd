extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player_controller.gd")
const ENEMY_SCRIPT = preload("res://scripts/enemy.gd")
const AUDIO_SCRIPT = preload("res://scripts/combat_audio.gd")
const HUD_SCRIPT = preload("res://scripts/mobile_hud.gd")

const DESERT_GROUND_LIGHT := "res://vendor/desert/ground_light.glb"
const DESERT_GROUND_DARK := "res://vendor/desert/ground_dark.glb"
const DESERT_ROCK := "res://vendor/desert/rock_outcrop.glb"
const DESERT_DRIFT := "res://vendor/desert/sand_drift.glb"
const TILE_SIZE := 6.0
const TILE_RADIUS := 3
const ARENA_HALF_SIZE := 21.0

const PLAYER_SPAWN := Vector3(0.0, 0.25, 16.0)
const ENEMY_SPAWNS := [
	Vector3(-13.0, 0.25, -11.0),
	Vector3(12.0, 0.25, -12.0),
	Vector3(-11.0, 0.25, 3.0),
	Vector3(12.0, 0.25, 4.0)
]

const ROCK_LAYOUT := [
	[Vector3(-16.0, 0.12, -15.0), 1.65, -0.35],
	[Vector3(-6.0, 0.12, -12.0), 1.15, 0.65],
	[Vector3(7.0, 0.12, -15.0), 1.45, 1.20],
	[Vector3(16.0, 0.12, -8.0), 1.30, -0.80],
	[Vector3(-15.0, 0.12, -1.0), 1.25, 0.20],
	[Vector3(4.0, 0.12, -3.0), 1.05, -1.10],
	[Vector3(15.0, 0.12, 10.0), 1.50, 0.90],
	[Vector3(-14.0, 0.12, 12.0), 1.40, -1.25],
	[Vector3(-3.0, 0.12, 10.0), 0.95, 0.45]
]

const DRIFT_LAYOUT := [
	[Vector3(-9.0, 0.12, -18.0), -0.15],
	[Vector3(9.0, 0.12, -18.0), 0.30],
	[Vector3(-18.0, 0.12, 7.0), 1.55],
	[Vector3(18.0, 0.12, 3.0), -1.45],
	[Vector3(-5.0, 0.12, 18.0), 2.70],
	[Vector3(8.0, 0.12, 17.0), -2.50]
]

var player: CharacterBody3D
var hud: CanvasLayer
var combat_audio: Node
var enemies: Array[Node3D] = []
var remaining := 0
var status_label: Label

func _ready() -> void:
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	_build_environment()
	_build_desert_arena()
	_build_gameplay()

func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	world_env.name = "DesertEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("4f83ad")
	sky_material.sky_horizon_color = Color("d8c29d")
	sky_material.ground_bottom_color = Color("6a5035")
	sky_material.ground_horizon_color = Color("c39a64")
	sky_material.sun_angle_max = 12.0
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = 0.62
	environment.ambient_light_energy = 0.68
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = false
	world_env.environment = environment
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "DesertSun"
	sun.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	sun.light_color = Color("ffe0aa")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 46.0
	add_child(sun)

func _build_desert_arena() -> void:
	var light_ground := load(DESERT_GROUND_LIGHT) as PackedScene
	var dark_ground := load(DESERT_GROUND_DARK) as PackedScene
	var rock_scene := load(DESERT_ROCK) as PackedScene
	var drift_scene := load(DESERT_DRIFT) as PackedScene
	if light_ground == null or dark_ground == null or rock_scene == null or drift_scene == null:
		push_error("One or more ready-made desert assets are missing")
		return

	var arena := Node3D.new()
	arena.name = "CompactDesertArena"
	add_child(arena)

	# 42 x 42 m authored desert floor. Two ready-made variants and rotations break repetition.
	for x in range(-TILE_RADIUS, TILE_RADIUS + 1):
		for z in range(-TILE_RADIUS, TILE_RADIUS + 1):
			var source: PackedScene = light_ground if posmod(x + z, 3) != 0 else dark_ground
			var tile := source.instantiate() as Node3D
			if tile == null:
				continue
			tile.position = Vector3(float(x) * TILE_SIZE, 0.0, float(z) * TILE_SIZE)
			tile.rotation.y = float(posmod(x * 3 + z, 4)) * (PI * 0.5)
			arena.add_child(tile)

	for entry in ROCK_LAYOUT:
		var position: Vector3 = entry[0]
		var scale_factor: float = entry[1]
		var yaw: float = entry[2]
		var rock := rock_scene.instantiate() as Node3D
		if rock == null:
			continue
		rock.position = position
		rock.rotation.y = yaw
		rock.scale = Vector3.ONE * scale_factor
		arena.add_child(rock)
		_add_rock_collision(position, scale_factor, yaw)

	for entry in DRIFT_LAYOUT:
		var drift := drift_scene.instantiate() as Node3D
		if drift == null:
			continue
		drift.position = entry[0]
		drift.rotation.y = entry[1]
		arena.add_child(drift)

	_add_invisible_floor()
	_add_arena_boundaries()

func _add_invisible_floor() -> void:
	var floor := StaticBody3D.new()
	floor.name = "DesertFloorCollision"
	floor.position = Vector3(0.0, 0.0, 0.0)
	add_child(floor)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(42.0, 0.20, 42.0)
	collider.shape = shape
	collider.position.y = -0.02
	floor.add_child(collider)

func _add_rock_collision(position: Vector3, scale_factor: float, yaw: float) -> void:
	var body := StaticBody3D.new()
	body.name = "RockCollision"
	body.position = position
	body.rotation.y = yaw
	add_child(body)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.25, 1.75, 2.20) * scale_factor
	collider.shape = shape
	collider.position.y = shape.size.y * 0.48
	body.add_child(collider)

func _add_arena_boundaries() -> void:
	_add_boundary(Vector3(0.0, 1.25, -ARENA_HALF_SIZE), Vector3(42.0, 2.5, 0.7))
	_add_boundary(Vector3(0.0, 1.25, ARENA_HALF_SIZE), Vector3(42.0, 2.5, 0.7))
	_add_boundary(Vector3(-ARENA_HALF_SIZE, 1.25, 0.0), Vector3(0.7, 2.5, 42.0))
	_add_boundary(Vector3(ARENA_HALF_SIZE, 1.25, 0.0), Vector3(0.7, 2.5, 42.0))

func _add_boundary(position: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "ArenaBoundary"
	body.position = position
	add_child(body)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)

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
		status_label.text = "تم تأمين الساحة"

func _on_player_died() -> void:
	if is_instance_valid(status_label):
		status_label.text = "انتهت المهمة — أعد المحاولة"

func _update_status() -> void:
	if is_instance_valid(status_label):
		status_label.text = "الساحة الصحراوية  •  أعداء متبقون: %d" % remaining
