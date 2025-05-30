extends Area2D
var is_dragging = false
var drag_offset = Vector2.ZERO
var draggable_object: Node2D

# Border constraints
var screen_bounds: Rect2
var object_size: Vector2

# Visual feedback
var original_modulate = Color.WHITE
var selected_modulate = Color(1.2, 1.2, 1.2, 1.0)

func _ready():
	# Determine what object to move
	draggable_object = get_parent() if get_parent() != get_tree().current_scene else self
	
	# Connect signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)
	
	# Store original appearance
	original_modulate = modulate
	
	# Initialize bounds
	_update_screen_bounds()
	_calculate_object_size()
	
	# Update bounds when window is resized
	get_tree().get_root().size_changed.connect(_update_screen_bounds)

func _update_screen_bounds():
	var viewport_size = get_viewport().get_visible_rect().size
	screen_bounds = Rect2(Vector2.ZERO, viewport_size)

func _calculate_object_size():
	# Try to get object bounds from collision shape or visual elements
	var collision_shape = get_node_or_null("CollisionShape2D")
	if collision_shape and collision_shape.shape:
		var shape = collision_shape.shape
		if shape is RectangleShape2D:
			object_size = shape.size
		elif shape is CircleShape2D:
			var radius = shape.radius
			object_size = Vector2(radius * 2, radius * 2)
		else:
			object_size = Vector2(64, 64)  # Default fallback
	else:
		object_size = Vector2(64, 64)  # Default fallback

func _process(_delta):
	if is_dragging:
		var mouse_pos = get_global_mouse_position()
		var new_position = mouse_pos - drag_offset
		
		# Apply boundary constraints
		new_position = _constrain_to_bounds(new_position)
		
		draggable_object.global_position = new_position

func _constrain_to_bounds(pos: Vector2) -> Vector2:
	
	# Clamp position to keep object within screen bounds
	pos.x = clampf(pos.x, object_size.x, screen_bounds.size.x - object_size.x)
	pos.y = clampf(pos.y, object_size.y, screen_bounds.size.y - object_size.y)
	
	return pos

func _input(event):
	# Handle global mouse release (in case mouse leaves area while dragging)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if is_dragging:
			_stop_dragging()

func _on_mouse_entered():
	if not is_dragging:
		modulate = selected_modulate

func _on_mouse_exited():
	if not is_dragging:
		modulate = original_modulate

func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_dragging()
		else:
			_stop_dragging()

func _start_dragging():
	is_dragging = true
	
	# Calculate offset between mouse and object center
	drag_offset = get_global_mouse_position() - draggable_object.global_position
	
	# Visual feedback
	modulate = selected_modulate
	
	# Bring to front
	if draggable_object.has_method("set_z_index"):
		draggable_object.z_index = 100

func _stop_dragging():
	is_dragging = false
	
	# Reset appearance
	modulate = original_modulate
	
	# Reset z-index
	if draggable_object.has_method("set_z_index"):
		draggable_object.z_index = 0
