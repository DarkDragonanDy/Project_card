extends Area2D
class_name AntiStackingDragHandler

# Drag state
var is_dragging: bool = false
var drag_offset: Vector2
var original_parent: Node
var original_z_index: int
var original_position: Vector2
var original_rotation

# Visual feedback
const HOVER_SCALE: Vector2 = Vector2(1.1, 1.1)
const DRAG_SCALE: Vector2 = Vector2(0.9, 0.9)
const COLLISION_PUSH_FORCE: float = 60.0
const MIN_CARD_DISTANCE: float = 80.0

var original_scale: Vector2

# References
var card_ref: Card
var hand_manager: HandManager
var collision_detector: Area2D

# Collision avoidance
var collision_bodies: Array[Card] = []
var avoidance_velocity: Vector2 = Vector2.ZERO
var is_avoiding_collision: bool = false

# Animation
var position_tween: Tween
var scale_tween: Tween


# Signals
signal drag_started(card: Card)
signal drag_ended(card: Card)
signal dropped_on_hex(card: Card, hex_position: Vector2i)
signal collision_detected(other_card: Card)

func _ready():
	# Setup Area2D
	input_pickable = true
	monitoring = true
	monitorable = true

	# Get card reference
	card_ref = get_parent() as Card
	if not card_ref:
		print("Error: DragHandler must be child of Card")
		return

	# Setup collision detection for other cards
	_setup_collision_detection()

	# Connect Area2D signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)

	# Store original scale
	original_scale = card_ref.scale

func _setup_collision_detection():
	# Create collision detector for other cards
	collision_detector = Area2D.new()
	collision_detector.name = "CollisionDetector"
	add_child(collision_detector)
	
	# Create larger collision shape for detection
	var collision_shape = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = MIN_CARD_DISTANCE
	collision_shape.shape = shape
	collision_detector.add_child(collision_shape)
	
	# Connect collision signals
	collision_detector.area_entered.connect(_on_collision_area_entered)
	collision_detector.area_exited.connect(_on_collision_area_exited)



func _update_drag_position(delta):
	if not card_ref:
		return
	
	var target_position = get_global_mouse_position() - drag_offset
	
	# Apply collision avoidance
	if is_avoiding_collision:
		target_position += avoidance_velocity * delta
	
	# Smooth movement
	card_ref.global_position = card_ref.global_position.lerp(target_position, 15.0 * delta)
	
	# Constrain to screen bounds
	_constrain_to_screen()



func _constrain_to_screen():
	if not card_ref:
		return
	
	var viewport_size = get_viewport().get_visible_rect().size
	var card_size = _get_card_size()
	var half_size = card_size * 0.5
	
	var pos = card_ref.global_position
	pos.x = clampf(pos.x, half_size.x, viewport_size.x - half_size.x)
	pos.y = clampf(pos.y, half_size.y, viewport_size.y - half_size.y)
	card_ref.global_position = pos

func _get_card_size() -> Vector2:
	# Try to get card size from collision shape
	var collision_shape = get_node_or_null("CollisionShape2D")
	if collision_shape and collision_shape.shape:
		var shape = collision_shape.shape
		if shape is RectangleShape2D:
			return shape.size * card_ref.scale
		elif shape is CircleShape2D:
			var radius = shape.radius
			return Vector2(radius * 2, radius * 2) * card_ref.scale
	
	# Fallback to texture size
	if card_ref.art_box and card_ref.art_box.texture:
		return card_ref.art_box.texture.get_size() * card_ref.scale
	
	# Default size
	return Vector2(64, 89) * card_ref.scale

func _on_mouse_entered():
	if not is_dragging:
		_animate_hover(true)

func _on_mouse_exited():
	if not is_dragging :
		_animate_hover(false)
		

func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not is_dragging:
			_animate_hover(false)
			_start_drag()

func _input(event):
	if is_dragging and event is InputEventMouseButton:
		if  not event.pressed:
			_end_drag()

func _start_drag():
	if not card_ref:
		return
	
	
	
	is_dragging = true
	drag_offset = get_global_mouse_position() - card_ref.global_position
	
	# Store original state
	original_parent = card_ref.get_parent()
	original_z_index = card_ref.z_index
	original_position = card_ref.global_position
	original_rotation=card_ref.rotation
	
	
	if hand_manager:
		original_position = hand_manager.get_card_hand_position(card_ref)
	
	# Visual feedback
	card_ref.z_index = 1000  # Bring to front
	_animate_scale(DRAG_SCALE)
	
	position_tween = create_tween()
	position_tween.tween_property(card_ref, "rotation", 0.0, 0.2)
	# Enable collision detection
	collision_detector.monitoring = true
	
	drag_started.emit(card_ref)
	
	print("Started dragging: ", card_ref.card_name)

func _end_drag():
	if not is_dragging:
		return
	
	is_dragging = false
	
	# Disable collision detection
	collision_detector.monitoring = false
	collision_bodies.clear()
	is_avoiding_collision = false
	
	# Check for valid drop
	var hex_pos = _get_hex_under_mouse()
	var valid_drop = _is_valid_drop_position(hex_pos)
	
	if valid_drop:
		# Card was played
		dropped_on_hex.emit(card_ref, hex_pos)
		print("Card played at hex: ", hex_pos)
	else:
		# Return to hand
		_return_to_hand()
	
	drag_ended.emit(card_ref)

func _get_hex_under_mouse() -> Vector2i:
	var hex_grid = get_node_or_null("/root/Battle_scene/Control_lair/Game_UI/GridContainer/Game_board/TileMapLayer")
	if not hex_grid:
		return Vector2i(-999, -999)

	var mouse_pos = hex_grid.get_local_mouse_position()
	var hex_coord = hex_grid.local_to_map(mouse_pos)

	# Verify hex exists
	var tile_data = hex_grid.get_cell_tile_data(hex_coord)
	if tile_data:
		return hex_coord

	return Vector2i(-999, -999)

func _is_valid_drop_position(hex_pos: Vector2i) -> bool:
	if hex_pos == Vector2i(-999, -999):
		return false
	
	# Check with game manager
	var game_manager = get_node_or_null("/root/Battle_scene/Game_manager")
	if game_manager and game_manager.has_method("is_valid_play_position"):
		return game_manager.is_valid_play_position(card_ref, hex_pos)

	return false

func _return_to_hand():
	if not card_ref:
		return
	
	# Reset z-index
	if hand_manager:
		var hand_index = hand_manager.get_card_hand_index(card_ref)
		card_ref.z_index = hand_index if hand_index != -1 else original_z_index
	else:
		card_ref.z_index = original_z_index
	
	# Animate back to hand position
	var target_position = original_position
	if hand_manager:
		target_position = hand_manager.get_card_hand_position(card_ref)
	
	_animate_return_to_hand(target_position)

func _animate_return_to_hand(target_position: Vector2):
	if position_tween:
		position_tween.kill()
	
	position_tween = create_tween()
	position_tween.set_parallel(true)
	
	# Animate position
	position_tween.tween_property(card_ref, "global_position", target_position, 0.3)
	position_tween.tween_property(card_ref, "rotation", original_rotation, 0.3)
	
	# Reset scale
	_animate_scale(original_scale)

func _animate_hover(hovering: bool):
	var target_scale = HOVER_SCALE if hovering else original_scale
	_animate_scale(target_scale)
	
	# Optional: slight position adjustment
	if hand_manager and hovering:
		var current_pos = card_ref.global_position
		var hover_offset = Vector2(0, 0)
		
		if position_tween:
			position_tween.kill()
		position_tween = create_tween()
		position_tween.tween_property(card_ref, "global_position", current_pos + hover_offset, 0.2)

func _animate_scale(target_scale: Vector2):
	if scale_tween:
		scale_tween.kill()
	
	scale_tween = create_tween()
	scale_tween.tween_property(card_ref, "scale", target_scale, 0.2)
	

func _on_collision_area_entered(area: Area2D):
	# Check if it's another card's drag handler
	var other_card = area.get_parent() as Card
	if other_card and other_card != card_ref:
		
		collision_bodies.append(other_card)
		collision_detected.emit(other_card)

func _on_collision_area_exited(area: Area2D):
	var other_card = area.get_parent() as Card
	if other_card and other_card in collision_bodies:
		
		collision_bodies.erase(other_card)

func set_hand_reference(hand: HandManager):
	hand_manager = hand

func set_draggable(enabled: bool):
	input_pickable = enabled
	if not enabled and is_dragging:
		_end_drag()

func get_collision_count() -> int:
	return collision_bodies.size()

func is_colliding_with_cards() -> bool:
	return not collision_bodies.is_empty()

func get_colliding_cards() -> Array[Card]:
	return collision_bodies.duplicate()

func set_card_reference(card: Card):
	card_ref = card

func get_original_position() -> Vector2:
	return original_position

func is_currently_dragging() -> bool:
	return is_dragging

# Utility functions for external systems
func force_return_to_hand():
	if is_dragging:
		_return_to_hand()

func get_drag_progress() -> float:
	# Returns how far the card has been dragged (0.0 to 1.0)
	if not is_dragging or not card_ref:
		return 0.0
	
	var start_pos = original_position
	var current_pos = card_ref.global_position
	var mouse_pos = get_global_mouse_position()
	
	var max_distance = start_pos.distance_to(mouse_pos)
	var current_distance = start_pos.distance_to(current_pos)
	
	return clampf(current_distance / max_distance, 0.0, 1.0) if max_distance > 0 else 0.0

# Enhanced collision detection
func _update_collision_priorities():
	# Sort collision bodies by distance (closest first)
	collision_bodies.sort_custom(func(a, b): 
		if not is_instance_valid(a) or not is_instance_valid(b):
			return false
		var dist_a = card_ref.global_position.distance_to(a.global_position)
		var dist_b = card_ref.global_position.distance_to(b.global_position)
		return dist_a < dist_b
	)

func _clean_invalid_collisions():
	# Remove any invalid card references
	collision_bodies = collision_bodies.filter(func(card): return is_instance_valid(card))

# Visual feedback improvements
func _update_visual_feedback():
	if not card_ref:
		return
	
	if is_dragging:
		# Change appearance based on collision state
		if is_avoiding_collision:
			card_ref.modulate = Color(1.0, 0.8, 0.8, 0.9)  # Slight red tint when colliding
		else:
			card_ref.modulate = Color(1.0, 1.0, 1.0, 0.9)  # Slight transparency when dragging
	else:
		card_ref.modulate = Color.WHITE  # Normal appearance

# Improved collision handling with momentum
var momentum_velocity: Vector2 = Vector2.ZERO
const MOMENTUM_DECAY: float = 0.9
const MAX_MOMENTUM: float = 300.0

func _apply_momentum(delta: float):
	if momentum_velocity.length() > 1.0:
		card_ref.global_position += momentum_velocity * delta
		momentum_velocity *= MOMENTUM_DECAY
		_constrain_to_screen()
	else:
		momentum_velocity = Vector2.ZERO

func _add_momentum(impulse: Vector2):
	momentum_velocity += impulse
	momentum_velocity = momentum_velocity.limit_length(MAX_MOMENTUM)

# Enhanced process function
func _process(delta):
	if is_dragging:
		_update_drag_position(delta)
		_handle_collision_avoidance(delta)
		_update_visual_feedback()
		_clean_invalid_collisions()
		_update_collision_priorities()
	else:
		_update_visual_feedback()

		_apply_momentum(delta)
	
	# Trigger redraw for debug visualization
	queue_redraw()

# Improved collision avoidance with better physics
func _handle_collision_avoidance(delta):
	avoidance_velocity = Vector2.ZERO
	is_avoiding_collision = false
	
	if collision_bodies.is_empty():
		return
	
	var total_push = Vector2.ZERO
	var collision_count = 0
	
	for other_card in collision_bodies:
		if not is_instance_valid(other_card) or other_card == card_ref:
			continue
		
		var distance_vector = card_ref.global_position - other_card.global_position
		var distance = distance_vector.length()
		
		if distance < MIN_CARD_DISTANCE and distance > 0:
			# Calculate push force with improved physics
			var push_strength = (MIN_CARD_DISTANCE - distance) / MIN_CARD_DISTANCE
			push_strength = pow(push_strength, 2)  # Quadratic falloff for more natural feel
			
			var push_direction = distance_vector.normalized()
			var push_force = push_direction * COLLISION_PUSH_FORCE * push_strength
			
			total_push += push_force
			collision_count += 1
			is_avoiding_collision = true
			
			# Add momentum to the push for more dynamic movement
			_add_momentum(push_force * 0.1)
	
	if collision_count > 0:
		avoidance_velocity = total_push / collision_count

# Debug visualization
func _draw():
	if not is_dragging:
		return
	
	# Draw collision radius in debug mode
	var debug_mode = false  # Set to true for debugging
	if debug_mode:
		draw_circle(Vector2.ZERO, MIN_CARD_DISTANCE, Color.RED, false, 2.0)
		
		# Draw avoidance vector
		if is_avoiding_collision:
			draw_line(Vector2.ZERO, avoidance_velocity.normalized() * 50, Color.YELLOW, 3.0)
		
		# Draw connections to colliding cards
		for other_card in collision_bodies:
			if is_instance_valid(other_card):
				var relative_pos = other_card.global_position - card_ref.global_position
				draw_line(Vector2.ZERO, relative_pos, Color.ORANGE, 1.0)

# Cleanup function
func _exit_tree():
	if position_tween:
		position_tween.kill()
	if scale_tween:
		scale_tween.kill()
	
	collision_bodies.clear()
