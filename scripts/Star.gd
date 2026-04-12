extends Sprite2D

# Constants
const LONG_PRESS_TIME = 0.5
const MAX_DRAG_Y = 300.0
const SLINGSHOT_THRESHOLD = 50.0

# Enums
enum StarType { STAR, NEBULA, ECLIPSE }

# Spectral Class Colors
const SPECTRAL_COLORS = [
	Color("#00f0ff"), # O: Electric Blue
	Color("#ffffd0"), # A/F: White-Yellow
	Color("#ffaa00"), # G: Gold
	Color("#ff4500")  # K/M: Orange-Red
]

# State variables
var is_dragging = false
var touch_start_pos = Vector2.ZERO
var drag_start_pos = Vector2.ZERO
var long_press_timer = 0.0
var ghost_ui_spawned = false

# Persistence
const SAVE_PATH = "user://star_data.cfg"

# Star properties
var magnitude = 1.0 # Scales size and depth
var turbulence = 0.0 # Shader parameter
var star_type = StarType.STAR
var star_color_idx = 2 # Default to Gold (G)
var brightness = 1.0
var halo_active = 0.0

# Physics
var velocity = Vector2.ZERO
var resting_y = 0.0
var is_slingshotting = false

# Haptics
var last_haptic_intensity = 0.0
const HAPTIC_THRESHOLD = 0.15

@onready var main_node = get_tree().root.get_child(0)

func _ready():
	if not material:
		var mat = ShaderMaterial.new()
		mat.shader = load("res://shaders/Turbulence.gdshader")
		material = mat

	load_star_data()
	resting_y = global_position.y
	_update_visuals()

func _process(delta):
	if not is_dragging and is_slingshotting:
		_handle_physics(delta)

	if is_dragging:
		long_press_timer += delta
		if long_press_timer >= LONG_PRESS_TIME and not ghost_ui_spawned:
			_spawn_ghost_ui()

	# Nebula 60 BPM pulse
	if star_type == StarType.NEBULA:
		var pulse_val = 1.0 + sin(Time.get_ticks_msec() * 0.001 * PI * 2.0 * (60.0/60.0)) * 0.1
		material.set_shader_parameter("pulse", pulse_val)
	else:
		material.set_shader_parameter("pulse", 1.0)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			reset_star_state()

	if event is InputEventScreenTouch:
		if event.pressed:
			if get_rect().has_point(to_local(event.position)):
				_start_drag(event.position)
				get_viewport().set_input_as_handled()
		else:
			if is_dragging:
				_end_drag(event.position)
				get_viewport().set_input_as_handled()

	elif event is InputEventScreenDrag:
		if is_dragging:
			# Multi-touch protection: only handle the first touch that started the drag
			# (In most mobile Godot setups, the first touch is index 0)
			if event.index == 0:
				_update_drag(event.position)
				get_viewport().set_input_as_handled()

func _start_drag(pos):
	is_dragging = true
	touch_start_pos = pos
	drag_start_pos = global_position
	long_press_timer = 0.0
	ghost_ui_spawned = false
	is_slingshotting = false
	velocity = Vector2.ZERO

func _update_drag(pos):
	var diff = pos - touch_start_pos

	turbulence = clamp(abs(diff.x) / 300.0, 0.0, 1.0)
	_trigger_haptic(turbulence)

	if diff.y > 0:
		global_position.y = drag_start_pos.y + diff.y
	else:
		global_position.y = drag_start_pos.y + diff.y * 0.2

	magnitude = clamp(1.0 - (diff.y / 500.0), 0.5, 2.0)
	_update_visuals()

func _update_visuals():
	scale = Vector2(magnitude, magnitude)
	z_index = int(magnitude * 10)

	material.set_shader_parameter("star_type", star_type)
	material.set_shader_parameter("star_color", SPECTRAL_COLORS[star_color_idx])
	material.set_shader_parameter("brightness", brightness)
	material.set_shader_parameter("turbulence", turbulence)
	material.set_shader_parameter("halo", halo_active)

	resting_y = get_viewport_rect().size.y * 0.5 - (magnitude - 1.0) * 200.0

func _end_drag(pos):
	is_dragging = false
	var diff = pos - touch_start_pos

	if diff.y > SLINGSHOT_THRESHOLD:
		_fire_slingshot(diff.y)
	else:
		_update_visuals()
		is_slingshotting = true

	save_star_data()

func _fire_slingshot(tension):
	is_slingshotting = true
	velocity.y = -tension * 10.0

func _handle_physics(delta):
	var force = (resting_y - global_position.y) * 5.0
	velocity.y += force
	velocity.y *= 0.9
	global_position.y += velocity.y * delta

	if abs(velocity.y) < 0.1 and abs(global_position.y - resting_y) < 0.1:
		global_position.y = resting_y
		is_slingshotting = false

func _trigger_haptic(intensity):
	if abs(intensity - last_haptic_intensity) > HAPTIC_THRESHOLD or (intensity > 0.8 and last_haptic_intensity <= 0.8):
		if intensity > 0.1:
			Input.vibrate_handheld(int(intensity * 50))
			last_haptic_intensity = intensity

func _spawn_ghost_ui():
	ghost_ui_spawned = true
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "GhostUILayer"
	get_tree().root.add_child(canvas_layer)

	var overlay = Control.new()
	overlay.name = "GhostUI"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(overlay)

	# Background tap to close
	var bg_btn = Button.new()
	bg_btn.modulate.a = 0
	bg_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg_btn)
	bg_btn.pressed.connect(canvas_layer.queue_free)

	# Center point for UI elements in screen coordinates
	var center = get_global_transform_with_canvas().origin

	# Type Cycle Button
	var btn_type = _create_ghost_button("Type", center + Vector2(0, -180))
	overlay.add_child(btn_type)
	btn_type.pressed.connect(func():
		star_type = (star_type + 1) % 3
		_update_visuals()
		save_star_data()
	)

	# Color Slider
	var color_container = VBoxContainer.new()
	color_container.position = center + Vector2(-220, 20)
	color_container.custom_minimum_size = Vector2(200, 50)
	overlay.add_child(color_container)

	var color_label = Label.new()
	color_label.text = "Color (O-M)"
	color_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	color_container.add_child(color_label)

	var color_slider = HSlider.new()
	color_slider.min_value = 0
	color_slider.max_value = SPECTRAL_COLORS.size() - 1
	color_slider.value = star_color_idx
	color_slider.step = 1
	color_container.add_child(color_slider)
	color_slider.value_changed.connect(func(val):
		star_color_idx = int(val)
		_update_visuals()
		save_star_data()
	)

	# Brightness Slider
	var bright_container = VBoxContainer.new()
	bright_container.position = center + Vector2(20, 20)
	bright_container.custom_minimum_size = Vector2(200, 50)
	overlay.add_child(bright_container)

	var bright_label = Label.new()
	bright_label.text = "Brightness"
	bright_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bright_container.add_child(bright_label)

	var bright_slider = HSlider.new()
	bright_slider.min_value = 0.5
	bright_slider.max_value = 3.0
	bright_slider.value = brightness
	bright_slider.step = 0.1
	bright_container.add_child(bright_slider)
	bright_slider.value_changed.connect(func(val):
		brightness = val
		_update_visuals()
		save_star_data()
	)

	# Halo Toggle Button
	var btn_halo = _create_ghost_button("Halo", center + Vector2(0, 180))
	overlay.add_child(btn_halo)
	btn_halo.pressed.connect(func():
		halo_active = 1.0 if halo_active == 0.0 else 0.0
		_update_visuals()
		save_star_data()
	)

func _create_ghost_button(text, pos):
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(100, 100)
	button.position = pos - Vector2(50, 50)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.2)
	style.set_corner_radius_all(50)
	button.add_theme_stylebox_override("normal", style)
	return button

func save_star_data():
	var config = ConfigFile.new()
	config.set_value("star", "magnitude", magnitude)
	config.set_value("star", "turbulence", turbulence)
	config.set_value("star", "star_type", star_type)
	config.set_value("star", "star_color_idx", star_color_idx)
	config.set_value("star", "brightness", brightness)
	config.set_value("star", "halo_active", halo_active)
	config.save(SAVE_PATH)

func load_star_data():
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err == OK:
		magnitude = config.get_value("star", "magnitude", 1.0)
		turbulence = config.get_value("star", "turbulence", 0.0)
		star_type = config.get_value("star", "star_type", StarType.STAR)
		star_color_idx = config.get_value("star", "star_color_idx", 2)
		brightness = config.get_value("star", "brightness", 1.0)
		halo_active = config.get_value("star", "halo_active", 0.0)

func reset_star_state():
	magnitude = 1.0
	turbulence = 0.0
	star_type = StarType.STAR
	star_color_idx = 2
	brightness = 1.0
	halo_active = 0.0
	velocity = Vector2.ZERO
	is_slingshotting = false
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	_update_visuals()
	global_position.y = get_viewport_rect().size.y * 0.5
	print("Star state reset.")
