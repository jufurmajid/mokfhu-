extends CanvasLayer

signal fire_requested
signal reload_requested
signal jump_requested
signal crouch_requested
signal aim_changed(active: bool)
signal move_changed(value: Vector2)
signal look_delta(value: Vector2)
signal restart_requested

const FIRE_REPEAT := 0.105
const JOYSTICK_RADIUS := 68.0
const SAFE_MARGIN := 22.0

var root: Control
var weapon_panel: Panel
var weapon_label: Label
var ammo_label: Label
var health_panel: Panel
var health_label: Label
var enemy_label: Label
var status_label: Label
var reticle: Label
var damage_overlay: ColorRect
var restart_button: Button

var fire_button: Button
var reload_button: Button
var aim_button: Button
var crouch_button: Button
var jump_button: Button
var joystick_base: Panel
var joystick_knob: Panel

var move_origin := Vector2.ZERO
var move_touch := -1
var look_touch := -1
var fire_held := false
var fire_timer := 0.0
var last_health := 100
var hitmarker_serial := 0

func _ready() -> void:
	_build_ui()
	get_viewport().size_changed.connect(_layout_controls)
	call_deferred("_layout_controls")

func _process(delta: float) -> void:
	if fire_held:
		fire_timer -= delta
		if fire_timer <= 0.0:
			fire_requested.emit()
			fire_timer = FIRE_REPEAT

func _build_ui() -> void:
	root = Control.new()
	root.name = "HUDRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root)

	damage_overlay = ColorRect.new()
	damage_overlay.name = "DamageOverlay"
	damage_overlay.color = Color(0.55, 0.02, 0.02, 0.0)
	damage_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(damage_overlay)

	reticle = Label.new()
	reticle.name = "Reticle"
	reticle.text = "·"
	reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reticle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reticle.set_anchors_preset(Control.PRESET_CENTER)
	reticle.offset_left = -16.0
	reticle.offset_top = -16.0
	reticle.offset_right = 16.0
	reticle.offset_bottom = 16.0
	reticle.add_theme_font_size_override("font_size", 32)
	reticle.add_theme_color_override("font_color", Color(1, 1, 1, 0.93))
	reticle.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	reticle.add_theme_constant_override("shadow_offset_x", 1)
	reticle.add_theme_constant_override("shadow_offset_y", 1)
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(reticle)

	weapon_panel = _make_info_panel()
	weapon_panel.name = "WeaponPanel"
	root.add_child(weapon_panel)

	weapon_label = _make_label("AK-74M", 20)
	weapon_label.name = "WeaponName"
	weapon_panel.add_child(weapon_label)

	ammo_label = _make_label("30 / 120", 27)
	ammo_label.name = "Ammo"
	weapon_panel.add_child(ammo_label)

	health_panel = _make_info_panel()
	health_panel.name = "HealthPanel"
	root.add_child(health_panel)

	health_label = _make_label("صحة 100", 22)
	health_label.name = "Health"
	health_panel.add_child(health_label)

	enemy_label = _make_label("الأعداء 4", 18)
	enemy_label.name = "EnemyCount"
	health_panel.add_child(enemy_label)

	status_label = _make_label("", 25)
	status_label.name = "Status"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	status_label.add_theme_constant_override("shadow_offset_x", 2)
	status_label.add_theme_constant_override("shadow_offset_y", 2)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(status_label)

	fire_button = _make_round_button("إطلاق", 20, 0.46)
	fire_button.name = "FireButton"
	fire_button.button_down.connect(_start_fire)
	fire_button.button_up.connect(_stop_fire)
	root.add_child(fire_button)

	aim_button = _make_round_button("تصويب", 14, 0.42)
	aim_button.name = "AimButton"
	aim_button.toggle_mode = true
	aim_button.toggled.connect(_on_aim_toggled)
	root.add_child(aim_button)

	crouch_button = _make_round_button("انحناء", 13, 0.42)
	crouch_button.name = "CrouchButton"
	crouch_button.toggle_mode = true
	crouch_button.toggled.connect(func(_pressed: bool): crouch_requested.emit())
	root.add_child(crouch_button)

	jump_button = _make_round_button("قفز", 14, 0.42)
	jump_button.name = "JumpButton"
	jump_button.pressed.connect(jump_requested.emit)
	root.add_child(jump_button)

	reload_button = _make_round_button("تلقيم", 13, 0.42)
	reload_button.name = "ReloadButton"
	reload_button.pressed.connect(reload_requested.emit)
	root.add_child(reload_button)

	joystick_base = Panel.new()
	joystick_base.name = "MovePad"
	joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base_style := StyleBoxFlat.new()
	base_style.bg_color = Color(0.02, 0.025, 0.025, 0.24)
	base_style.border_color = Color(1.0, 1.0, 1.0, 0.36)
	base_style.set_border_width_all(2)
	base_style.set_corner_radius_all(96)
	joystick_base.add_theme_stylebox_override("panel", base_style)
	root.add_child(joystick_base)

	joystick_knob = Panel.new()
	joystick_knob.name = "MoveKnob"
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var knob_style := StyleBoxFlat.new()
	knob_style.bg_color = Color(0.95, 0.95, 0.95, 0.48)
	knob_style.border_color = Color(1, 1, 1, 0.22)
	knob_style.set_border_width_all(1)
	knob_style.set_corner_radius_all(48)
	joystick_knob.add_theme_stylebox_override("panel", knob_style)
	joystick_base.add_child(joystick_knob)

	restart_button = Button.new()
	restart_button.name = "RestartButton"
	restart_button.text = "إعادة المحاولة"
	restart_button.visible = false
	restart_button.focus_mode = Control.FOCUS_NONE
	restart_button.add_theme_font_size_override("font_size", 22)
	restart_button.pressed.connect(restart_requested.emit)
	var restart_style := StyleBoxFlat.new()
	restart_style.bg_color = Color(0.08, 0.10, 0.10, 0.92)
	restart_style.border_color = Color(1, 1, 1, 0.35)
	restart_style.set_border_width_all(2)
	restart_style.set_corner_radius_all(10)
	restart_button.add_theme_stylebox_override("normal", restart_style)
	restart_button.add_theme_stylebox_override("pressed", restart_style)
	restart_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	root.add_child(restart_button)

func _make_info_panel() -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.025, 0.025, 0.68)
	style.border_color = Color(1, 1, 1, 0.08)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _make_label(caption: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = caption
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	return label

func _make_round_button(caption: String, font_size: int, alpha: float) -> Button:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.025, 0.03, 0.03, alpha)
	normal.border_color = Color(1, 1, 1, 0.30)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(100)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.20, 0.23, 0.23, 0.82)
	pressed.border_color = Color(1, 1, 1, 0.62)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button

func _layout_controls() -> void:
	if root == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var ui_scale := clampf(minf(viewport_size.x, viewport_size.y) / 720.0, 0.72, 1.15)
	var margin := SAFE_MARGIN * ui_scale

	var weapon_size := Vector2(230, 96) * ui_scale
	weapon_panel.size = weapon_size
	weapon_panel.position = Vector2(viewport_size.x - weapon_size.x - margin, 18.0 * ui_scale)
	weapon_label.position = Vector2(14, 7) * ui_scale
	weapon_label.size = Vector2(weapon_size.x - 28.0 * ui_scale, 34.0 * ui_scale)
	weapon_label.add_theme_font_size_override("font_size", int(20.0 * ui_scale))
	ammo_label.position = Vector2(14, 45) * ui_scale
	ammo_label.size = Vector2(weapon_size.x - 28.0 * ui_scale, 42.0 * ui_scale)
	ammo_label.add_theme_font_size_override("font_size", int(27.0 * ui_scale))

	var health_size := Vector2(190, 82) * ui_scale
	health_panel.size = health_size
	health_panel.position = Vector2(margin, 18.0 * ui_scale)
	health_label.position = Vector2(12, 6) * ui_scale
	health_label.size = Vector2(health_size.x - 24.0 * ui_scale, 34.0 * ui_scale)
	health_label.add_theme_font_size_override("font_size", int(21.0 * ui_scale))
	enemy_label.position = Vector2(12, 42) * ui_scale
	enemy_label.size = Vector2(health_size.x - 24.0 * ui_scale, 30.0 * ui_scale)
	enemy_label.add_theme_font_size_override("font_size", int(17.0 * ui_scale))

	status_label.size = Vector2(560, 44) * ui_scale
	status_label.position = Vector2((viewport_size.x - status_label.size.x) * 0.5, 18.0 * ui_scale)
	status_label.add_theme_font_size_override("font_size", int(24.0 * ui_scale))

	var fire_size := 116.0 * ui_scale
	fire_button.size = Vector2(fire_size, fire_size)
	fire_button.position = Vector2(viewport_size.x - fire_size - 118.0 * ui_scale, viewport_size.y - fire_size - 58.0 * ui_scale)

	var small_size := 74.0 * ui_scale
	aim_button.size = Vector2(small_size, small_size)
	aim_button.position = Vector2(viewport_size.x - small_size - 28.0 * ui_scale, viewport_size.y - 322.0 * ui_scale)
	crouch_button.size = Vector2(small_size, small_size)
	crouch_button.position = Vector2(viewport_size.x - small_size - 28.0 * ui_scale, viewport_size.y - 228.0 * ui_scale)
	jump_button.size = Vector2(small_size, small_size)
	jump_button.position = Vector2(viewport_size.x - small_size - 28.0 * ui_scale, viewport_size.y - 134.0 * ui_scale)

	var reload_size := 68.0 * ui_scale
	reload_button.size = Vector2(reload_size, reload_size)
	reload_button.position = Vector2(fire_button.position.x - reload_size - 18.0 * ui_scale, fire_button.position.y + fire_size * 0.5 - reload_size * 0.5)

	var pad_size := 158.0 * ui_scale
	joystick_base.size = Vector2(pad_size, pad_size)
	joystick_base.position = Vector2(44.0 * ui_scale, viewport_size.y - pad_size - 44.0 * ui_scale)
	var knob_size := 68.0 * ui_scale
	joystick_knob.size = Vector2(knob_size, knob_size)
	_reset_knob()

	restart_button.size = Vector2(230, 58) * ui_scale
	restart_button.position = Vector2((viewport_size.x - restart_button.size.x) * 0.5, viewport_size.y * 0.58)

func _input(event: InputEvent) -> void:
	var size := get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		if event.pressed:
			if _point_hits_action(event.position):
				return
			if event.position.x < size.x * 0.34 and event.position.y > size.y * 0.46 and move_touch == -1:
				move_touch = event.index
				move_origin = joystick_base.position + joystick_base.size * 0.5
				_update_joystick(event.position)
			elif event.position.x > size.x * 0.34 and look_touch == -1:
				look_touch = event.index
		else:
			if event.index == move_touch:
				move_touch = -1
				move_changed.emit(Vector2.ZERO)
				_reset_knob()
			if event.index == look_touch:
				look_touch = -1
	elif event is InputEventScreenDrag:
		if event.index == move_touch:
			_update_joystick(event.position)
		elif event.index == look_touch:
			look_delta.emit(event.relative * 0.0021)

func _update_joystick(point: Vector2) -> void:
	var scale := maxf(joystick_base.size.x / 158.0, 0.5)
	var delta: Vector2 = (point - move_origin) / (JOYSTICK_RADIUS * scale)
	var clamped: Vector2 = delta.limit_length(1.0)
	var center := (joystick_base.size - joystick_knob.size) * 0.5
	joystick_knob.position = center + clamped * (joystick_base.size.x * 0.27)
	move_changed.emit(clamped)

func _point_hits_action(point: Vector2) -> bool:
	for control in [fire_button, reload_button, aim_button, crouch_button, jump_button, restart_button]:
		if control != null and control.visible and control.get_global_rect().has_point(point):
			return true
	return false

func _reset_knob() -> void:
	if joystick_base != null and joystick_knob != null:
		joystick_knob.position = (joystick_base.size - joystick_knob.size) * 0.5

func _start_fire() -> void:
	fire_held = true
	fire_timer = 0.0

func _stop_fire() -> void:
	fire_held = false

func _on_aim_toggled(active: bool) -> void:
	aim_changed.emit(active)

func set_ammo(current: int, reserve: int) -> void:
	if ammo_label != null:
		ammo_label.text = "%02d / %03d" % [current, reserve]

func set_health(value: int) -> void:
	if health_label != null:
		health_label.text = "صحة %d" % value
	if value < last_health:
		_flash_damage()
	last_health = value

func set_enemy_count(value: int) -> void:
	if enemy_label != null:
		enemy_label.text = "الأعداء %d" % value

func show_hitmarker(killed: bool) -> void:
	if reticle == null:
		return
	hitmarker_serial += 1
	var serial := hitmarker_serial
	reticle.text = "✕"
	reticle.add_theme_color_override("font_color", Color("ffd7a0") if not killed else Color("ff7f6b"))
	get_tree().create_timer(0.10 if not killed else 0.18).timeout.connect(func():
		if is_instance_valid(reticle) and serial == hitmarker_serial:
			reticle.text = "·"
			reticle.add_theme_color_override("font_color", Color(1, 1, 1, 0.93))
	)

func _flash_damage() -> void:
	if damage_overlay == null:
		return
	damage_overlay.color = Color(0.58, 0.01, 0.01, 0.24)
	var tween := create_tween()
	tween.tween_property(damage_overlay, "color:a", 0.0, 0.28)

func show_mission_result(message: String, success: bool) -> void:
	fire_held = false
	status_label.text = message
	status_label.add_theme_color_override("font_color", Color("c8ffd1") if success else Color("ffb3a8"))
	restart_button.visible = true
