extends Sprite2D

# Constants
const LONG_PRESS_TIME = 0.5
const MAX_DRAG_Y = 300.0
const SLINGSHOT_THRESHOLD = 50.0

# State variables
var is_dragging = false
var touch_start_pos = Vector2.ZERO
var drag_start_pos = Vector2.ZERO
var long_press_timer = 0.0
var ghost_ui_spawned = false

# Star properties
var magnitude = 1.0 # Scales size and depth
var turbulence = 0.0 # Shader parameter

# Physics
var velocity = Vector2.ZERO
var resting_y = 0.0
var is_slingshotting = false

@onready var main_node = get_tree().root.get_child(0)

func _ready():
	resting_y = global_position.y
	# Ensure we have a material for the shader
	if not material:
		material = ShaderMaterial.new()
		material.shader = load("res://shaders/Turbulence.gdshader")

func _process(delta):
	if not is_dragging and is_slingshotting:
		_handle_physics(delta)

	if is_dragging:
		long_press_timer += delta
		if long_press_timer >= LONG_PRESS_TIME and not ghost_ui_spawned:
			_spawn_ghost_ui()

func _input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			if get_rect().has_point(to_local(event.position)):
				_start_drag(event.position)
		else:
			if is_dragging:
				_end_drag(event.position)

	elif event is InputEventScreenDrag:
		if is_dragging:
			_update_drag(event.position)

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

	# X-Axis: Turbulence & Haptics
	turbulence = clamp(abs(diff.x) / 300.0, 0.0, 1.0)
	material.set_shader_parameter("turbulence", turbulence)
	_trigger_haptic(turbulence)

	# Y-Axis: Magnitude and Slingshot Tension
	# Slingshot Tension is only active if we are pulling down
	if diff.y > 0:
		global_position.y = drag_start_pos.y + diff.y
	else:
		global_position.y = drag_start_pos.y + diff.y * 0.2

	# Magnitude is always updated based on the total vertical displacement from rest
	# Moving up increases magnitude, moving down decreases it slightly from the resting scale
	magnitude = clamp(1.0 - (diff.y / 500.0), 0.5, 2.0)
	scale = Vector2(magnitude, magnitude)
	z_index = int(magnitude * 10)

func _end_drag(pos):
	is_dragging = false
	var diff = pos - touch_start_pos

	if diff.y > SLINGSHOT_THRESHOLD:
		_fire_slingshot(diff.y)
	else:
		# Update resting_y based on the new magnitude
		resting_y = get_viewport_rect().size.y * 0.5 - (magnitude - 1.0) * 200.0
		is_slingshotting = true

func _fire_slingshot(tension):
	is_slingshotting = true
	# Apply upward impulse
	velocity.y = -tension * 10.0

func _handle_physics(delta):
	# Simple gravity/spring towards resting_y
	var force = (resting_y - global_position.y) * 5.0
	velocity.y += force
	velocity.y *= 0.9 # Damping
	global_position.y += velocity.y * delta

	if abs(velocity.y) < 0.1 and abs(global_position.y - resting_y) < 0.1:
		global_position.y = resting_y
		is_slingshotting = false

func _trigger_haptic(intensity):
	if intensity > 0.1:
		# Godot's mobile haptic support (simplified)
		Input.vibrate_handheld(int(intensity * 100))

func _spawn_ghost_ui():
	ghost_ui_spawned = true
	var overlay = Node2D.new()
	overlay.name = "GhostUI"
	add_child(overlay)

	for i in range(3):
		var angle = i * (TAU / 3.0)
		var button = ColorRect.new()
		button.custom_minimum_size = Vector2(40, 40)
		button.position = Vector2(cos(angle), sin(angle)) * 80.0 - Vector2(20, 20)
		button.color = Color(1, 1, 1, 0.5)
		overlay.add_child(button)

		# Add a simple touch detection for buttons
		button.gui_input.connect(_on_ghost_button_pressed.bind(overlay))

func _on_ghost_button_pressed(event, overlay):
	if event is InputEventScreenTouch and event.pressed:
		_apply_ozone_effect()
		overlay.queue_free()

func _apply_ozone_effect():
	var canvas_layer = CanvasLayer.new()
	get_tree().root.add_child(canvas_layer)

	var ozone = ColorRect.new()
	ozone.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Set size manually just in case anchors don't trigger immediately
	ozone.size = get_viewport_rect().size

	var mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/Ozone.gdshader")
	ozone.material = mat
	canvas_layer.add_child(ozone)

	# Auto-remove after some time for demo purposes
	await get_tree().create_timer(2.0).timeout
	canvas_layer.queue_free()
