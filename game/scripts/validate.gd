extends SceneTree

func _init() -> void:
	process_frame.connect(_on_frame, CONNECT_ONE_SHOT)

func _on_frame() -> void:
	print("--- MOKFHU RUNTIME ASSET & GAMEPLAY VALIDATION ---")
	var field_scene := load("res://scenes/field.tscn") as PackedScene
	if field_scene == null:
		push_error("MOKFHU_FATAL: Failed to load res://scenes/field.tscn")
		quit(1)
		return

	var field := field_scene.instantiate() as Node3D
	root.add_child(field)

	# Give nodes 1 frame to initialize their _ready() callbacks
	await process_frame

	var failures := 0

	# 1. Terrain & Environment
	var mesh_instances := field.find_children("*", "MeshInstance3D", true, false)
	print("Total MeshInstance3D nodes in scene: %d" % mesh_instances.size())
	if mesh_instances.size() < 10:
		push_error("MOKFHU_FATAL: Insufficient 3D mesh instances in scene")
		failures += 1

	# 2. Check for visible primitive meshes
	for mi in mesh_instances:
		var mesh_inst := mi as MeshInstance3D
		if mesh_inst and mesh_inst.visible:
			var mesh := mesh_inst.mesh
			if mesh is BoxMesh or mesh is CapsuleMesh or mesh is CylinderMesh or mesh is SphereMesh:
				push_error("MOKFHU_FATAL: Visible primitive mesh detected on %s" % mesh_inst.get_path())
				failures += 1

	# 3. Enemies
	var enemies := field.get("enemies") as Array
	print("Spawned enemies count: %d" % enemies.size())
	if enemies.size() < 4:
		push_error("MOKFHU_FATAL: Enemy count is less than 4 (actual: %d)" % enemies.size())
		failures += 1

	for enemy_node in enemies:
		var enemy := enemy_node as Node3D
		if enemy == null:
			continue
		var enemy_meshes := enemy.find_children("*", "MeshInstance3D", true, false)
		if enemy_meshes.is_empty():
			push_error("MOKFHU_FATAL: Enemy %s has no visible MeshInstance3D" % enemy.name)
			failures += 1

	# 4. Player & Camera
	var player := field.get("player") as CharacterBody3D
	if player == null:
		push_error("MOKFHU_FATAL: Player node missing")
		failures += 1
	else:
		var camera := player.get("camera") as Camera3D
		if camera == null:
			push_error("MOKFHU_FATAL: Player camera missing")
			failures += 1
		else:
			print("Player camera FOV: %.1f" % camera.fov)
			var view_pivot := player.get("view_pivot") as Node3D
			if view_pivot:
				print("Player view height: %.2f" % view_pivot.position.y)

		var anim_player := player.get("viewmodel_anim") as AnimationPlayer
		if anim_player == null:
			push_error("MOKFHU_FATAL: AK Viewmodel AnimationPlayer missing")
			failures += 1
		else:
			var anim_list := anim_player.get_animation_list()
			print("Viewmodel animation list: %s" % str(anim_list))
			var reload_anim := String(player.get("anim_reload"))
			var fire_anim := String(player.get("anim_fire"))
			if reload_anim.is_empty() or fire_anim.is_empty():
				push_error("MOKFHU_FATAL: AK Reload or Fire animation unresolved")
				failures += 1

	# 5. Combat Audio
	var combat_audio := field.get("combat_audio") as Node
	if combat_audio == null:
		push_error("MOKFHU_FATAL: CombatAudio node missing")
		failures += 1

	# 6. Gameplay State Transition & Restart
	field.call("_on_enemy_died", null)
	field.call("restart_game")
	print("Restart executed successfully.")

	if failures == 0:
		print("--- MOKFHU VALIDATION PASSED SUCCESSFULLY ---")
		quit(0)
	else:
		push_error("MOKFHU_FATAL: Validation failed with %d errors" % failures)
		quit(1)
