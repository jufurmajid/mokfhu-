extends SceneTree

func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _fail(message: String) -> int:
	push_error("MOKFHU_FATAL: " + message)
	return 1

func _has_visible_mesh(root_node: Node) -> bool:
	for node in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance != null and mesh_instance.mesh != null and mesh_instance.is_visible_in_tree():
			return true
	return false

func _inside_viewport(control: Control, viewport_size: Vector2) -> bool:
	if control == null:
		return false
	var rect := control.get_global_rect()
	return rect.position.x >= -1.0 and rect.position.y >= -1.0 and rect.end.x <= viewport_size.x + 1.0 and rect.end.y <= viewport_size.y + 1.0

func _run() -> void:
	var scene := load("res://scenes/field.tscn") as PackedScene
	if scene == null:
		push_error("MOKFHU_FATAL: field scene missing")
		quit(1)
		return

	var field := scene.instantiate() as Node3D
	root.add_child(field)
	await process_frame
	await process_frame
	await process_frame

	var failures := 0

	var floor := field.get("test_floor") as MeshInstance3D
	if floor == null or floor.mesh == null:
		failures += _fail("desert ground missing")
	elif not (floor.mesh is PlaneMesh):
		failures += _fail("desert ground is not the optimized PlaneMesh")
	else:
		var plane := floor.mesh as PlaneMesh
		if plane.size.x < 70.0 or plane.size.y < 70.0:
			failures += _fail("playable desert floor is too small")
		if plane.material == null or not (plane.material is ShaderMaterial):
			failures += _fail("sand shader missing")

	var cover_root := field.get("cover_root") as Node3D
	if cover_root == null:
		failures += _fail("realistic cover root missing")
	else:
		var cover_children := cover_root.get_children()
		if cover_children.size() < 12:
			failures += _fail("not enough placed cover meshes")
		var visible_cover_count := 0
		for cover in cover_children:
			if _has_visible_mesh(cover):
				visible_cover_count += 1
		if visible_cover_count < 12:
			failures += _fail("one or more cover GLBs are not visibly rendered")
		print("Visible cover models: %d" % visible_cover_count)

	var primitive_failures := 0
	for node in field.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null or not mesh_instance.is_visible_in_tree():
			continue
		if mesh_instance == floor:
			continue
		var mesh := mesh_instance.mesh
		if mesh is BoxMesh or mesh is CapsuleMesh or mesh is CylinderMesh or mesh is SphereMesh:
			primitive_failures += 1
	if primitive_failures > 0:
		failures += _fail("visible primitive placeholder meshes detected: %d" % primitive_failures)

	var enemies: Array = field.get("enemies")
	if enemies.size() != 4:
		failures += _fail("expected exactly 4 optimized tactical enemies")
	else:
		for enemy_node in enemies:
			var enemy := enemy_node as Node3D
			if enemy == null or not _has_visible_mesh(enemy):
				failures += _fail("enemy has no visible tactical soldier mesh")
		print("Enemy count: %d" % enemies.size())

	var player := field.get("player") as CharacterBody3D
	if player == null:
		failures += _fail("player missing")
	else:
		var camera := player.get("camera") as Camera3D
		var pivot := player.get("view_pivot") as Node3D
		var mount := player.get("viewmodel_mount") as Node3D
		var viewmodel := player.get("viewmodel") as Node3D
		var animation_player := player.get("viewmodel_anim") as AnimationPlayer

		if camera == null or not camera.current or absf(camera.fov - 60.0) > 0.1:
			failures += _fail("final device-selected 60 degree camera FOV is not active")
		if pivot == null or absf(pivot.position.y - 1.55) > 0.03:
			failures += _fail("player eye height is incorrect")
		if mount == null:
			failures += _fail("viewmodel mount missing")
		else:
			var desired := Vector3(0.090, -0.200, -0.160)
			if mount.position.distance_to(desired) > 0.025:
				failures += _fail("device-selected weapon coordinates are not active")
		if viewmodel == null or not _has_visible_mesh(viewmodel):
			failures += _fail("AK hands viewmodel is not visible")
		elif absf(viewmodel.scale.x - 0.300) > 0.005:
			failures += _fail("device-selected AK scale is not active")

		if animation_player == null:
			failures += _fail("AK animation player missing")
		else:
			for property_name in ["anim_idle", "anim_walk", "anim_fire", "anim_reload"]:
				var animation_name := String(player.get(property_name))
				if animation_name.is_empty() or not animation_player.has_animation(StringName(animation_name)):
					failures += _fail("AK animation unresolved: %s" % property_name)

		var health_before := int(player.get("health"))
		player.call("take_damage", 7, Vector3.ZERO, Vector3.ZERO)
		if int(player.get("health")) != health_before - 7:
			failures += _fail("player damage system is not functional")

	var combat_audio := field.get("combat_audio") as Node
	if combat_audio == null:
		failures += _fail("combat audio manager missing")
	else:
		var shot_voice := combat_audio.get("player_shot") as AudioStreamPlayer
		var tail_voice := combat_audio.get("player_tail") as AudioStreamPlayer
		var reload_voice := combat_audio.get("reload_voice") as AudioStreamPlayer
		var enemy_voices: Array = combat_audio.get("enemy_voices")
		if shot_voice == null or shot_voice.stream == null:
			failures += _fail("local player gunshot stream missing")
		if tail_voice == null or tail_voice.stream == null:
			failures += _fail("player gunshot tail stream missing")
		if reload_voice == null or reload_voice.stream == null:
			failures += _fail("reload stream missing")
		if enemy_voices.size() < 4:
			failures += _fail("enemy audio voice pool too small")

	var hud := field.get("hud") as CanvasLayer
	if hud == null:
		failures += _fail("mobile HUD missing")
	else:
		for property_name in [
			"fire_button", "reload_button", "aim_button", "crouch_button", "jump_button",
			"joystick_base", "weapon_panel", "health_panel", "enemy_label", "restart_button"
		]:
			if hud.get(property_name) == null:
				failures += _fail("HUD control missing: %s" % property_name)

		var viewport_size := root.get_visible_rect().size
		for property_name in ["fire_button", "reload_button", "aim_button", "crouch_button", "jump_button", "joystick_base", "weapon_panel", "health_panel"]:
			var control := hud.get(property_name) as Control
			if not _inside_viewport(control, viewport_size):
				failures += _fail("HUD control outside safe area: %s" % property_name)

		hud.call("show_mission_result", "تم تأمين المنطقة", true)
		var restart := hud.get("restart_button") as Button
		if restart == null or not restart.visible:
			failures += _fail("mission result does not expose restart button")

	if failures == 0:
		print("--- PLAYABLE COMBAT VALIDATION PASSED ---")
	else:
		push_error("MOKFHU_FATAL: playable validation failed with %d issue(s)" % failures)

	field.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures == 0 else 1)
