extends CanvasLayer

signal fire_requested
signal reload_requested
signal move_changed(value: Vector2)
signal look_delta(value: Vector2)

const FIRE_REPEAT := 0.105
const JOYSTICK_RADIUS := 64.0
const SAFE_MARGIN := 26.0

var root: Control
var ammo_label: Label
var fire_button: Button
var reload_button: Button
var joystick_base: Panel
var joystick_knob: Panel

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
	reticle.text = "+"
	reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reticle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reticle.set_anchors_preset(Control.PRESET_CENTER)
	reticle.offset_left = -18.0
	reticle.offset_top = -18.0
	reticle.offset_right = 18.0
	reticle.offset_bottom = 18.0
	reticle.add_theme_font_size_override("font_size", 24)
	reticle.add_theme_color_override("font_color", Color(1.0, 0.97, 0.88, 0.88))
	reticle.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	reticle.add_theme_constant_override("shadow_offset_x", 1)
	reticle.add_theme_constant_override("shadow_offset_y", 1)
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(reticle)

	ammo_label = Label.new()
	ammo_label.name = "Ammo"
	ammo_label.text = "30 / 120"
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_label.add_theme_font_size_override("font_size", 28)
	ammo_label.add_theme_color_override("font_color", Color("fff0ca"))
	ammo_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	ammo_label.add_theme_constant_override("shadow_offset_x", 2)
	ammo_label.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(ammo_label)

	fire_button = _make_button("إطلاق", Color("9f3c31"), 22)
	fire_button.name = "FireButton"
	fire_button.button_down.connect(_start_fire)
	fire_button.button_up.connect(_stop_fire)
	root.add_child(fire_button)

	reload_button = _make_button("تلقيم", Color("344a3d"), 17)
	reload_button.name = "ReloadButton"
	reload_button.pressed.connect(reload_requested.emit)
	root.add_child(reload_button)

	joystick_base = Panel.new()
	joystick_base.name = "MovePad"
	joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base_style := StyleBoxFlat.new()
	base_style.bg_color = Color(0.03, 0.04, 0.035, 0.28)
	base_style.border_color = Color(1.0, 0.93, 0.77, 0.38)
	base_style.set_border_width_all(2)
	base_style.set_corner_radius_all(80)
	joystick_base.add_theme_stylebox_override("panel", base_style)
	root.add_child(joystick_base)

	joystick_knob = Panel.new()
	joystick_knob.name = "MoveKnob"
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var knob_style := StyleBoxFlat.new()
	knob_style.bg_color = Color(0.96, 0.89, 0.72, 0.56)
	knob_style.set_corner_radius_all(36)
	joystick_knob.add_theme_stylebox_override("panel", knob_style)
	joystick_base.add_child(joystick_knob)

func _make_button(caption: String, tint: Color, font_size: int) -> Button:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(tint, 0.80)
	normal.border_color = Color(1, 1, 1, 0.12)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(30)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(tint.lightened(0.12), 0.96)

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

	var fire_size := 108.0 * ui_scale
	fire_button.size = Vector2(fire_size, fire_size)
	fire_button.position = Vector2(viewport_size.x - fire_size - margin, viewport_size.y - fire_size - margin)
	fire_button.add_theme_font_size_override("font_size", int(22.0 * ui_scale))

	reload_button.size = Vector2(92, 50) * ui_scale
	reload_button.position = Vector2(
		fire_button.position.x - reload_button.size.x - 16.0 * ui_scale,
		fire_button.position.y + (fire_size - reload_button.size.y) * 0.5
	)
	reload_button.add_theme_font_size_override("font_size", int(17.0 * ui_scale))

	ammo_label.size = Vector2(190, 42) * ui_scale
	ammo_label.position = Vector2(viewport_size.x - ammo_label.size.x - margin, fire_button.position.y - 48.0 * ui_scale)
	ammo_label.add_theme_font_size_override("font_size", int(26.0 * ui_scale))

	var pad_size := 140.0 * ui_scale
	joystick_base.size = Vector2(pad_size, pad_size)
	joystick_base.position = Vector2(30.0 * ui_scale, viewport_size.y - pad_size - 30.0 * ui_scale)
	var knob_size := 60.0 * ui_scale
	joystick_knob.size = Vector2(knob_size, knob_size)
	_reset_knob()

func _input(event: InputEvent) -> void:
	var size := get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		if event.pressed:
			if _inside(event.position, fire_button) or _inside(event.position, reload_button):
				return
			if event.position.x < size.x * 0.48 and event.position.y > size.y * 0.35 and move_touch == -1:
				move_touch = event.index
				move_origin = event.position
				_place_move_pad(event.position)
			elif event.position.x > size.x * 0.43 and look_touch == -1:
				look_touch = event.index
		else:
			if event.index == move_touch:
				move_touch = -1
				move_changed.emit(Vector2.ZERO)
				_layout_controls()
			if event.index == look_touch:
				look_touch = -1
	elif event is InputEventScreenDrag:
		if event.index == move_touch:
			var scale := maxf(joystick_base.size.x / 140.0, 0.5)
			var delta: Vector2 = (event.position - move_origin) / (JOYSTICK_RADIUS * scale)
			var clamped: Vector2 = delta.limit_length(1.0)
			var center := (joystick_base.size - joystick_knob.size) * 0.5
			joystick_knob.position = center + clamped * (joystick_base.size.x * 0.25)
			move_changed.emit(clamped)
		elif event.index == look_touch:
			look_delta.emit(event.relative * 0.00235)

func _inside(point: Vector2, control: Control) -> bool:
	return control.get_global_rect().has_point(point)

func _place_move_pad(point: Vector2) -> void:
	var size := get_viewport().get_visible_rect().size
	var half := joystick_base.size * 0.5
	joystick_base.position = Vector2(
		clampf(point.x - half.x, 10.0, size.x * 0.48 - joystick_base.size.x),
		clampf(point.y - half.y, size.y * 0.35, size.y - joystick_base.size.y - 10.0)
	)
	_reset_knob()

func _reset_knob() -> void:
	if joystick_base != null and joystick_knob != null:
		joystick_knob.position = (joystick_base.size - joystick_knob.size) * 0.5

func _start_fire() -> void:
	fire_held = true
	fire_timer = 0.0

func _stop_fire() -> void:
	fire_held = false

func set_ammo(current: int, reserve: int) -> void:
	if ammo_label != null:
		ammo_label.text = "%02d / %03d" % [current, reserve]
