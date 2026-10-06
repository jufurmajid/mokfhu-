extends CanvasLayer

signal fire_requested
signal reload_requested
signal jump_requested
signal crouch_requested
signal aim_changed(active: bool)
signal move_changed(value: Vector2)
signal look_delta(value: Vector2)

signal tune_axis_requested(axis_name: String, amount: float)
signal tune_scale_requested(amount: float)
signal tune_fov_requested(amount: float)
signal tune_reset_requested

const FIRE_REPEAT := 0.105
const JOYSTICK_RADIUS := 68.0
const SAFE_MARGIN := 22.0

const TUNE_POSITION_STEP := 0.01
const TUNE_SCALE_STEP := 0.005
const TUNE_FOV_STEP := 1.0

var root: Control
var weapon_panel: Panel
var weapon_label: Label
var ammo_label: Label
var fire_button: Button
var reload_button: Button
var aim_button: Button
var crouch_button: Button
var jump_button: Button
var joystick_base: Panel
var joystick_knob: Panel

var tuning_toggle_button: Button
var tuning_panel: Panel
var tuning_value_label: Label
var tuning_copy_button: Button
var tuning_hit_controls: Array = []
var tuning_text := "X=0.160 Y=-0.180 Z=-0.560 | SCALE=0.155 | FOV=78.0"

var move_origin := Vector2.ZERO
var move_touch := -1
var look_touch := -1
var fire_held := false
var fire_timer := 0.0

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

	var reticle := Label.new()
	reticle.name = "Reticle"
	reticle.text = "·"
	reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reticle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reticle.set_anchors_preset(Control.PRESET_CENTER)
	reticle.offset_left = -14.0
	reticle.offset_top = -14.0
	reticle.offset_right = 14.0
	reticle.offset_bottom = 14.0
	reticle.add_theme_font_size_override("font_size", 32)
	reticle.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.92))
	reticle.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.72))
	reticle.add_theme_constant_override("shadow_offset_x", 1)
	reticle.add_theme_constant_override("shadow_offset_y", 1)
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(reticle)

	weapon_panel = Panel.new()
	weapon_panel.name = "WeaponPanel"
	weapon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.025, 0.025, 0.68)
	panel_style.border_color = Color(1, 1, 1, 0.08)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	weapon_panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(weapon_panel)

	weapon_label = Label.new()
	weapon_label.name = "WeaponName"
	weapon_label.text = "AK-74M"
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	weapon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	weapon_label.add_theme_font_size_override("font_size", 20)
	weapon_label.add_theme_color_override("font_color", Color.WHITE)
	weapon_panel.add_child(weapon_label)

	ammo_label = Label.new()
	ammo_label.name = "Ammo"
	ammo_label.text = "30 / 120"
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	ammo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ammo_label.add_theme_font_size_override("font_size", 27)
	ammo_label.add_theme_color_override("font_color", Color.WHITE)
	weapon_panel.add_child(ammo_label)

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
	crouch_button.toggled.connect(_on_crouch_toggled)
	root.add_child(crouch_button)

	jump_button = _make_round_button("قفز", 14, 0.42)
	jump_button.name = "JumpButton"
	jump_button.pressed.connect(_on_jump_pressed)
	root.add_child(jump_button)

	reload_button = _make_round_button("تلقيم", 13, 0.42)
	reload_button.name = "ReloadButton"
	reload_button.pressed.connect(_on_reload_pressed)
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

	_build_tuning_panel()

func _build_tuning_panel() -> void:
	tuning_toggle_button = _make_tune_button("إخفاء الضبط")
	tuning_toggle_button.name = "TuningToggle"
	tuning_toggle_button.pressed.connect(_toggle_tuning_panel)
	root.add_child(tuning_toggle_button)
	tuning_hit_controls.append(tuning_toggle_button)

	tuning_panel = Panel.new()
	tuning_panel.name = "ViewmodelTuner"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.02, 0.02, 0.78)
	style.border_color = Color(1, 1, 1, 0.18)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	tuning_panel.add_theme_stylebox_override("panel", style)
	root.add_child(tuning_panel)

	var title := Label.new()
	title.text = "ضبط السلاح والكاميرا"
	title.position = Vector2(14, 10)
	title.size = Vector2(340, 30)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("fff2d1"))
	tuning_panel.add_child(title)

	tuning_value_label = Label.new()
	tuning_value_label.name = "TuningValues"
	tuning_value_label.text = "X 0.160   Y -0.180   Z -0.560\nScale 0.155   FOV 78.0"
	tuning_value_label.position = Vector2(14, 40)
	tuning_value_label.size = Vector2(340, 52)
	tuning_value_label.add_theme_font_size_override("font_size", 15)
	tuning_value_label.add_theme_color_override("font_color", Color.WHITE)
	tuning_panel.add_child(tuning_value_label)

	_add_axis_row("X يمين / يسار", 98.0, "x")
	_add_axis_row("Y فوق / جوه", 136.0, "y")
	_add_axis_row("Z قرب / بعد", 174.0, "z")

	var scale_label := _make_tune_row_label("Scale", 212.0)
	tuning_panel.add_child(scale_label)
	var scale_minus := _make_tune_button("-")
	scale_minus.position = Vector2(196, 210)
	scale_minus.size = Vector2(64, 32)
	scale_minus.pressed.connect(_on_tune_scale_pressed.bind(-TUNE_SCALE_STEP))
	tuning_panel.add_child(scale_minus)
	tuning_hit_controls.append(scale_minus)
	var scale_plus := _make_tune_button("+")
	scale_plus.position = Vector2(270, 210)
	scale_plus.size = Vector2(64, 32)
	scale_plus.pressed.connect(_on_tune_scale_pressed.bind(TUNE_SCALE_STEP))
	tuning_panel.add_child(scale_plus)
	tuning_hit_controls.append(scale_plus)

	var fov_label := _make_tune_row_label("FOV", 250.0)
	tuning_panel.add_child(fov_label)
	var fov_minus := _make_tune_button("-")
	fov_minus.position = Vector2(196, 248)
	fov_minus.size = Vector2(64, 32)
	fov_minus.pressed.connect(_on_tune_fov_pressed.bind(-TUNE_FOV_STEP))
	tuning_panel.add_child(fov_minus)
	tuning_hit_controls.append(fov_minus)
	var fov_plus := _make_tune_button("+")
	fov_plus.position = Vector2(270, 248)
	fov_plus.size = Vector2(64, 32)
	fov_plus.pressed.connect(_on_tune_fov_pressed.bind(TUNE_FOV_STEP))
	tuning_panel.add_child(fov_plus)
	tuning_hit_controls.append(fov_plus)

	var reset_button := _make_tune_button("إعادة")
	reset_button.position = Vector2(14, 289)
	reset_button.size = Vector2(104, 38)
	reset_button.pressed.connect(_on_tune_reset_pressed)
	tuning_panel.add_child(reset_button)
	tuning_hit_controls.append(reset_button)

	tuning_copy_button = _make_tune_button("نسخ القيم")
	tuning_copy_button.position = Vector2(128, 289)
	tuning_copy_button.size = Vector2(130, 38)
	tuning_copy_button.pressed.connect(_copy_tuning_values)
	tuning_panel.add_child(tuning_copy_button)
	tuning_hit_controls.append(tuning_copy_button)

	var hint := Label.new()
	hint.text = "كل ضغطة: XYZ = 0.01 | Scale = 0.005 | FOV = 1"
	hint.position = Vector2(14, 334)
	hint.size = Vector2(340, 24)
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.66))
	tuning_panel.add_child(hint)

func _add_axis_row(caption: String, y: float, axis_name: String) -> void:
	var row_label := _make_tune_row_label(caption, y)
	tuning_panel.add_child(row_label)

	var minus_button := _make_tune_button("-")
	minus_button.position = Vector2(196, y - 2)
	minus_button.size = Vector2(64, 32)
	minus_button.pressed.connect(_on_tune_axis_pressed.bind(axis_name, -TUNE_POSITION_STEP))
	tuning_panel.add_child(minus_button)
	tuning_hit_controls.append(minus_button)

	var plus_button := _make_tune_button("+")
	plus_button.position = Vector2(270, y - 2)
	plus_button.size = Vector2(64, 32)
	plus_button.pressed.connect(_on_tune_axis_pressed.bind(axis_name, TUNE_POSITION_STEP))
	tuning_panel.add_child(plus_button)
	tuning_hit_controls.append(plus_button)

func _make_tune_row_label(caption: String, y: float) -> Label:
	var label := Label.new()
	label.text = caption
	label.position = Vector2(14, y)
	label.size = Vector2(170, 30)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
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

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.08, 0.09, 0.09, minf(0.72, alpha + 0.16))

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button

func _make_tune_button(caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color.WHITE)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.12, 0.12, 0.92)
	normal.border_color = Color(1, 1, 1, 0.22)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.28, 0.32, 0.32, 0.98)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button

func _layout_controls() -> void:
	if root == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var ui_scale := clampf(minf(viewport_size.x, viewport_size.y) / 720.0, 0.72, 1.15)
	var margin := SAFE_MARGIN * ui_scale

	var panel_size := Vector2(246, 100) * ui_scale
	weapon_panel.size = panel_size
	weapon_panel.position = Vector2(viewport_size.x - panel_size.x - margin, 18.0 * ui_scale)
	weapon_label.position = Vector2(16, 8) * ui_scale
	weapon_label.size = Vector2(panel_size.x - 32.0 * ui_scale, 34.0 * ui_scale)
	weapon_label.add_theme_font_size_override("font_size", int(20.0 * ui_scale))
	ammo_label.position = Vector2(16, 48) * ui_scale
	ammo_label.size = Vector2(panel_size.x - 32.0 * ui_scale, 42.0 * ui_scale)
	ammo_label.add_theme_font_size_override("font_size", int(27.0 * ui_scale))

	var fire_size := 116.0 * ui_scale
	fire_button.size = Vector2(fire_size, fire_size)
	fire_button.position = Vector2(
		viewport_size.x - fire_size - 118.0 * ui_scale,
		viewport_size.y - fire_size - 58.0 * ui_scale
	)
	fire_button.add_theme_font_size_override("font_size", int(20.0 * ui_scale))

	var small_size := 74.0 * ui_scale
	aim_button.size = Vector2(small_size, small_size)
	aim_button.position = Vector2(
		viewport_size.x - small_size - 28.0 * ui_scale,
		viewport_size.y - 322.0 * ui_scale
	)

	crouch_button.size = Vector2(small_size, small_size)
	crouch_button.position = Vector2(
		viewport_size.x - small_size - 28.0 * ui_scale,
		viewport_size.y - 228.0 * ui_scale
	)

	jump_button.size = Vector2(small_size, small_size)
	jump_button.position = Vector2(
		viewport_size.x - small_size - 28.0 * ui_scale,
		viewport_size.y - 134.0 * ui_scale
	)

	var reload_size := 68.0 * ui_scale
	reload_button.size = Vector2(reload_size, reload_size)
	reload_button.position = Vector2(
		fire_button.position.x - reload_size - 18.0 * ui_scale,
		fire_button.position.y + fire_size * 0.5 - reload_size * 0.5
	)

	for action_button in [aim_button, crouch_button, jump_button, reload_button]:
		action_button.add_theme_font_size_override("font_size", int(13.0 * ui_scale))

	var pad_size := 158.0 * ui_scale
	joystick_base.size = Vector2(pad_size, pad_size)
	joystick_base.position = Vector2(44.0 * ui_scale, viewport_size.y - pad_size - 44.0 * ui_scale)

	var knob_size := 68.0 * ui_scale
	joystick_knob.size = Vector2(knob_size, knob_size)
	_reset_knob()

	tuning_toggle_button.position = Vector2(18, 18) * ui_scale
	tuning_toggle_button.size = Vector2(124, 38) * ui_scale
	tuning_toggle_button.add_theme_font_size_override("font_size", int(13.0 * ui_scale))

	tuning_panel.position = Vector2(18, 66) * ui_scale
	tuning_panel.size = Vector2(370, 370)
	tuning_panel.scale = Vector2.ONE * ui_scale

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
			look_delta.emit(event.relative * 0.00215)

func _update_joystick(point: Vector2) -> void:
	var scale := maxf(joystick_base.size.x / 158.0, 0.5)
	var delta: Vector2 = (point - move_origin) / (JOYSTICK_RADIUS * scale)
	var clamped: Vector2 = delta.limit_length(1.0)
	var center := (joystick_base.size - joystick_knob.size) * 0.5
	joystick_knob.position = center + clamped * (joystick_base.size.x * 0.27)
	move_changed.emit(clamped)

func _point_hits_action(point: Vector2) -> bool:
	for control in [fire_button, reload_button, aim_button, crouch_button, jump_button, tuning_toggle_button]:
		if control != null and control.visible and control.get_global_rect().has_point(point):
			return true

	if tuning_panel != null and tuning_panel.visible:
		if tuning_panel.get_global_rect().has_point(point):
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

func _on_crouch_toggled(_active: bool) -> void:
	crouch_requested.emit()

func _on_jump_pressed() -> void:
	jump_requested.emit()

func _on_reload_pressed() -> void:
	reload_requested.emit()

func _toggle_tuning_panel() -> void:
	tuning_panel.visible = not tuning_panel.visible
	tuning_toggle_button.text = "إخفاء الضبط" if tuning_panel.visible else "إظهار الضبط"

func _on_tune_axis_pressed(axis_name: String, amount: float) -> void:
	tune_axis_requested.emit(axis_name, amount)

func _on_tune_scale_pressed(amount: float) -> void:
	tune_scale_requested.emit(amount)

func _on_tune_fov_pressed(amount: float) -> void:
	tune_fov_requested.emit(amount)

func _on_tune_reset_pressed() -> void:
	tune_reset_requested.emit()

func set_tuning_values(position: Vector3, scale_value: float, fov_value: float) -> void:
	tuning_text = "X=%.3f Y=%.3f Z=%.3f | SCALE=%.3f | FOV=%.1f" % [
		position.x,
		position.y,
		position.z,
		scale_value,
		fov_value
	]
	if tuning_value_label != null:
		tuning_value_label.text = "X %.3f   Y %.3f   Z %.3f\nScale %.3f   FOV %.1f" % [
			position.x,
			position.y,
			position.z,
			scale_value,
			fov_value
		]

func _copy_tuning_values() -> void:
	DisplayServer.clipboard_set(tuning_text)
	if tuning_copy_button != null:
		tuning_copy_button.text = "تم النسخ ✓"
		get_tree().create_timer(1.2).timeout.connect(_restore_copy_button)

func _restore_copy_button() -> void:
	if is_instance_valid(tuning_copy_button):
		tuning_copy_button.text = "نسخ القيم"

func set_ammo(current: int, reserve: int) -> void:
	if ammo_label != null:
		ammo_label.text = "%02d / %03d" % [current, reserve]
