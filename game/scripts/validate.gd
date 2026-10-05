extends SceneTree

func _init() -> void:
	process_frame.connect(_on_frame, CONNECT_ONE_SHOT)

func _fail(message: String) -> int:
	push_error("MOKFHU_FATAL: " + message)
	return 1

func _on_frame() -> void:
	print("--- MOKFHU RUNTIME ASSET & GAMEPLAY VALIDATION ---")
	var field_scene := load("res://scenes/field.tscn") as PackedScene
	if field_scene == null:
		push_error("MOKFHU_FATAL: Failed to load res://scenes/field.tscn")
		quit(1)
		return

	var field := field_scene.instantiate() as Node3D
	root.add_child(field)
	await process_frame

	var failures := 0

	# Visible environment content.
	var mesh_instances := field.find_children("*", "MeshInstance3D", true, false)
	print("Total MeshInstance3D nodes in scene: %d" % mesh_instances.size())
	if mesh_instances.size() < 10:
		failures += _fail("Insufficient 3D mesh instances in scene")

	var visible_primitives := 0
	for node in mesh_instances:
		var mesh_inst := node as MeshInstance3D
		if mesh_inst == null or mesh_inst.mesh == null or not mesh_inst.is_visible_in_tree():
			continue
		var mesh := mesh_inst.mesh
		if mesh is BoxMesh or mesh is CapsuleMesh or mesh is CylinderMesh or mesh is SphereMesh:
			visible_primitives += 1
			push_error("MOKFHU_FATAL: Visible primitive mesh detected on %s" % mesh_inst.get_path())
			failures += 1
	print("Visible primitive meshes: %d" % visible_primitives)

	# Tactical enemies.
	var enemies: Array = field.get("enemies")
	print("Spawned enemies count: %d" % enemies.size())
	if enemies.size() != 5:
		failures += _fail("Expected 5 tactical enemies, actual: %d" % enemies.size())

	for enemy_node in enemies:
		var enemy := enemy_node as Node3D
		if enemy == null:
			failures += _fail("Enemy entry is not a Node3D")
			continue
		var enemy_meshes := enemy.find_children("*", "MeshInstance3D", true, false)
		var visible_enemy_mesh := false
		for enemy_mesh_node in enemy_meshes:
			var enemy_mesh := enemy_mesh_node as MeshInstance3D
			if enemy_mesh != null and enemy_mesh.mesh != null and enemy_mesh.is_visible_in_tree():
				visible_enemy_mesh = true
				break
		if not visible_enemy_mesh:
			failures += _fail("Enemy %s has no visible 3D mesh" % enemy.name)

	# Player, camera and AK hands viewmodel.
	var player := field.get("player") as CharacterBody3D
	if player == null:
		failures += _fail("Player node missing")
	else:
		var camera := player.get("camera") as Camera3D
		if camera == null:
			failures += _fail("Player camera missing")
		else:
			print("Player camera FOV: %.1f" % camera.fov)
			if absf(camera.fov - 82.0) > 0.05:
				failures += _fail("Player camera FOV is not 82 degrees")
			if not camera.current:
				failures += _fail("Player camera is not current")

		var view_pivot := player.get("view_pivot") as Node3D
		if view_pivot == null:
			failures += _fail("Player view pivot missing")
		else:
			print("Player view height: %.2f" % view_pivot.position.y)
			if absf(view_pivot.position.y - 1.55) > 0.01:
				failures += _fail("Player camera height is not 1.55m")

		var viewmodel := player.get("viewmodel") as Node3D
		if viewmodel == null:
			failures += _fail("AK hands viewmodel missing")
		else:
			var viewmodel_meshes := viewmodel.find_children("*", "MeshInstance3D", true, false)
			if viewmodel_meshes.is_empty():
				failures += _fail("AK hands viewmodel has no MeshInstance3D")

		var anim_player := player.get("viewmodel_anim") as AnimationPlayer
		if anim_player == null:
			failures += _fail("AK Viewmodel AnimationPlayer missing")
		else:
			var required_animations := {
				"idle": String(player.get("anim_idle")),
				"walk": String(player.get("anim_walk")),
				"shot": String(player.get("anim_fire")),
				"reload": String(player.get("anim_reload"))
			}
			for label in required_animations:
				var animation_name: String = required_animations[label]
				if animation_name.is_empty() or not anim_player.has_animation(StringName(animation_name)):
					failures += _fail("AK %s animation is unresolved" % label)
			print("Resolved AK animations: %s" % str(required_animations))

	# Combat audio: prove the local player shot creates a valid non-spatial voice.
	var combat_audio := field.get("combat_audio") as Node
	if combat_audio == null:
		failures += _fail("CombatAudio node missing")
	else:
		combat_audio.call("play_player_shot", Vector3.ZERO)
		var local_voice_found := false
		for audio_child in combat_audio.get_children():
			if audio_child is AudioStreamPlayer and (audio_child as AudioStreamPlayer).stream != null:
				local_voice_found = true
				break
		if not local_voice_found:
			failures += _fail("Player gunshot did not create a valid local AudioStreamPlayer")

	# Mission win/death UI transitions.
	field.set("remaining", 1)
	field.call("_on_enemy_died", null)
	var status_label := field.get("status_label") as Label
	var hud := field.get("hud") as CanvasLayer
	var restart_button: Button = null
	if hud != null:
		restart_button = hud.get("restart_button") as Button
	if status_label == null or status_label.text != "تم تأمين المنطقة":
		failures += _fail("Mission win state text is incorrect")
	if restart_button == null or not restart_button.visible:
		failures += _fail("Restart button is not visible after mission win")

	field.call("_on_player_died")
	if status_label == null or status_label.text != "انتهت المهمة":
		failures += _fail("Mission death state text is incorrect")
	if restart_button == null or not restart_button.visible:
		failures += _fail("Restart button is not visible after player death")

	# Full gameplay reset.
	field.call("restart_game")
	await process_frame
	var restarted_enemies: Array = field.get("enemies")
	var restarted_player := field.get("player") as CharacterBody3D
	var restarted_hud := field.get("hud") as CanvasLayer
	if restarted_enemies.size() != 5:
		failures += _fail("Restart did not restore 5 enemies")
	if restarted_player == null or int(restarted_player.get("health")) != 100:
		failures += _fail("Restart did not restore player health")
	if restarted_player != null and (int(restarted_player.get("magazine")) != 30 or int(restarted_player.get("reserve_ammo")) != 120):
		failures += _fail("Restart did not restore player ammo")
	if restarted_hud == null:
		failures += _fail("Restart did not recreate the mobile HUD")
	else:
		var restarted_button := restarted_hud.get("restart_button") as Button
		if restarted_button == null or restarted_button.visible:
			failures += _fail("Restart button did not reset to hidden state")

	if failures == 0:
		print("--- MOKFHU VALIDATION PASSED SUCCESSFULLY ---")
		quit(0)
	else:
		push_error("MOKFHU_FATAL: Validation failed with %d errors" % failures)
		quit(1)
