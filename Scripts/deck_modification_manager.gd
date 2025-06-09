

# Option 2: Using absolute paths from root
extends Control
# Main controller for drag and drop functionality
# Attach this to a Control node that can access both lists

# Option 1: Using relative paths from current position
@onready var collection_list: ItemList = $"../Collection/Collection_list"
@onready var deck_list: ItemList = $"../Deck/Deck_list"

# Variables for drag state
var is_dragging: bool = false
var dragged_item_data: Dictionary = {}
var drag_visual: TextureRect

# Reference to deck manager (if needed for communication)
var deck_manager: Node

func _ready():
	# Connect to collection input
	collection_list.gui_input.connect(_on_collection_input)
	
	# Find and store reference to deck manager if it exists
	deck_manager = get_node_or_null("../Deck/Deck_manager")

func _on_collection_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start dragging
				var index = collection_list.get_item_at_position(event.position)
				if index != -1:
					_start_drag(index)
			else:
				# End dragging
				if is_dragging:
					_handle_drop()

func _start_drag(index: int):
	# Store the dragged item data
	dragged_item_data = {
		"index": index,
		"text": collection_list.get_item_text(index),
		"icon": collection_list.get_item_icon(index)
	}
	
	# Create visual representation
	drag_visual = TextureRect.new()
	drag_visual.texture = dragged_item_data.icon
	drag_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_visual.modulate.a = 0.8  # Slight transparency
	
	# Scale down to 1/10th of original size
	drag_visual.scale = Vector2(0.1, 0.1)
	
	# Add to scene at top level to ensure it renders above everything
	get_tree().root.add_child(drag_visual)
	
	# Position at mouse (accounting for scaled size)
	var mouse_pos = get_global_mouse_position()
	var scaled_size = drag_visual.size * drag_visual.scale
	drag_visual.global_position = mouse_pos - (scaled_size / 2)
	
	is_dragging = true

func _handle_drop():
	if not is_dragging:
		return
	
	# Check if mouse is over deck list
	var mouse_pos = get_global_mouse_position()
	var deck_rect = deck_list.get_global_rect()
	
	if deck_rect.has_point(mouse_pos):
		# If we have a deck manager, let it handle the add
		if deck_manager and deck_manager.has_method("add_card"):
			deck_manager.add_card(dragged_item_data.text, dragged_item_data.icon)
		else:
			# Otherwise add directly
			# Create a scaled version of the icon for the deck
			var scaled_icon = ImageTexture.new()
			var image = dragged_item_data.icon.get_image()
			image.resize(image.get_width() / 10, image.get_height() / 10, Image.INTERPOLATE_BILINEAR)
			scaled_icon.set_image(image)
			
			# Add card to deck with scaled icon
			deck_list.add_item(dragged_item_data.text, scaled_icon)
	
	# Clean up
	_end_drag()

func _end_drag():
	is_dragging = false
	dragged_item_data.clear()
	
	# Remove visual
	if is_instance_valid(drag_visual):
		drag_visual.queue_free()
		drag_visual = null

func _input(event: InputEvent):
	# Update drag visual position
	if is_dragging and event is InputEventMouseMotion:
		if is_instance_valid(drag_visual):
			var scaled_size = drag_visual.size * drag_visual.scale
			drag_visual.global_position = event.global_position - (scaled_size / 2)
	
	# Handle mouse release anywhere in case it's outside our controls
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if is_dragging:
				_handle_drop()
