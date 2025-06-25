extends Node2D
class_name Card

# Setup
static var card_scene = preload("res://Scenes/card_template.tscn")

# Card variables
@export var card_name: String = ""
@export var card_description: String = ""
@export var card_cost: int = 0
@export var card_unique_id: String = ""
@export var card_art: Texture2D = null


@export var income_per_turn: int = 0
@export var special_effects: Array[String] = []

@export var tile_source_id: int = 0  # Which source in tileset
@export var tile_atlas_coords: Vector2i = Vector2i(0, 0)  # Position in atlas

var collection_texture: ImageTexture  
var hex_representation: Node2D 
var card_preview: CardPreview


# Card visual children
@onready var card_back: Sprite2D = $Card_visuals/Card_back
@onready var text_box = $Card_visuals/Card_box_text/Card_text_box
@onready var cost_box = $Card_visuals/Card_box_cost/Card_text_cost
@onready var art_box = $Card_visuals/Card_art
@onready var name_label = $Card_visuals/Card_box_name/Card_text_name



# Card functional children - Updated to use new drag handler
@onready var drag_handler: AntiStackingDragHandler = $Drag_handler
@onready var data_node: Node = $Card_data
@onready var state_manager: Node = $State_manager

# Card signals
signal card_played(card: Card, hex_position: Vector2i)
signal card_selected(card: Card)
signal card_deselected(card: Card)

func _init(name: String = "", desc: String = "", cost: int = 0, id: String = "", art_texture: Texture2D = null):
	card_name = name
	card_description = desc
	card_cost = cost
	card_unique_id = id
	card_art = art_texture

func _ready():
	update_card_display()
	_connect_component_signals()
	
	# Pass card reference to components
	if drag_handler and drag_handler.has_method("set_card_reference"):
		drag_handler.set_card_reference(self)
	if state_manager and state_manager.has_method("set_card_reference"):
		state_manager.set_card_reference(self)
	_setup_card_preview()

func update_card_display():
	if is_instance_valid(name_label):
		name_label.text = card_name
	if is_instance_valid(text_box):
		text_box.text = card_description
	if is_instance_valid(cost_box):
		cost_box.text = str(card_cost)
	if is_instance_valid(art_box) and card_art:
		art_box.texture = card_art

func apply_card_data(data: Card):
	card_name = data.card_name
	card_description = data.card_description
	card_cost = data.card_cost
	card_art = data.card_art
	income_per_turn=data.income_per_turn
	special_effects=data.special_effects
	tile_source_id=data.tile_source_id
	tile_atlas_coords=data.tile_atlas_coords
	update_card_display()

func _connect_component_signals():
	# Connect drag handler signals with updated signature
	if drag_handler:
		if drag_handler.has_signal("drag_started"):
			drag_handler.drag_started.connect(_on_drag_started)
		if drag_handler.has_signal("drag_ended"):
			drag_handler.drag_ended.connect(_on_drag_ended)
		if drag_handler.has_signal("dropped_on_hex"):
			drag_handler.dropped_on_hex.connect(_on_dropped_on_hex)
		if drag_handler.has_signal("collision_detected"):
			drag_handler.collision_detected.connect(_on_collision_detected)

# Main functions
func _on_drag_started(card: Card):
	card_selected.emit(self)
	if state_manager:
		state_manager.change_state("dragging")

func _on_drag_ended(card: Card):
	card_deselected.emit(self)
	if state_manager:
		state_manager.change_state("in_hand")

func _on_dropped_on_hex(card: Card, hex_pos: Vector2i):
	card_played.emit(self, hex_pos)
	if state_manager:
		state_manager.change_state("played")

################################
func _on_collision_detected(other_card: Card):
	# Handle visual feedback for collision
	pass
	#_show_collision_feedback()

func _show_collision_feedback():
	# Brief color flash to indicate collision
	var original_modulate = modulate
	modulate = Color.ORANGE
	
	var tween = create_tween()
	tween.tween_property(self, "modulate", original_modulate, 0.2)

func can_be_played(game_state: Dictionary) -> bool:
	# Override in derived classes for specific card types
	return game_state.get("current_mana", 0) >= card_cost

func set_hand_manager(hand_manager: HandManager):
	if drag_handler and drag_handler.has_method("set_hand_reference"):
		drag_handler.set_hand_reference(hand_manager)

func set_draggable(enabled: bool):
	if drag_handler and drag_handler.has_method("set_draggable"):
		drag_handler.set_draggable(enabled)

func is_colliding() -> bool:
	if drag_handler and drag_handler.has_method("is_colliding_with_cards"):
		return drag_handler.is_colliding_with_cards()
	return false
##################################
# Texture generation (unchanged but included for completeness)
static func generate_card_texture(name: String, desc: String, cost: int, art_texture: Texture2D = null, texture_size: Vector2 = Vector2(635, 889)) -> ImageTexture:
	# Get current scene to add viewport to
	var current_scene = Engine.get_main_loop().root.get_child(Engine.get_main_loop().root.get_child_count() - 1)

	# Create viewport
	var viewport = SubViewport.new()
	viewport.size = texture_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = true

	# Add to current scene (not root)
	current_scene.add_child(viewport)

	# Create card
	var card = card_scene.instantiate()
	
	viewport.add_child(card)
	card.scale = Vector2(10, 10)
	card.position = texture_size / 2

	# Wait for nodes to be ready
	await current_scene.get_tree().process_frame

	# Set data directly on nodes
	var name_node = card.name_label
	if name_node:
		name_node.text = name

	var desc_node = card.text_box
	if desc_node:
		desc_node.text = desc

	var cost_node = card.cost_box
	if cost_node:
		cost_node.text = str(cost)

	var art_node = card.art_box
	if art_node and art_texture:
		art_node.texture = art_texture

	# Wait for rendering
	await current_scene.get_tree().process_frame

	# Capture
	var image = viewport.get_texture().get_image()
	var texture = ImageTexture.create_from_image(image)

	# Cleanup
	viewport.queue_free()
	
	return texture

func get_texture() -> ImageTexture:
	return await Card.generate_card_texture(card_name, card_description, card_cost, card_art)
	


func on_play(game_state: Dictionary) -> void:
	# Override in subclasses
	pass

func on_turn_start(game_state: Dictionary) -> void:
	# Override in subclasses
	pass

func on_remove(game_state: Dictionary) -> void:
	# Override in subclasses
	pass

func _setup_card_preview():
	# Wait for the scene tree to be completely ready
	await get_tree().process_frame
	await get_tree().process_frame  # Wait an extra frame to be safe

	# Create preview system
	card_preview = preload("res://Scripts/Scripts_card/Card_defenition/card_preview.gd").new()

	# Add to main scene 
	var main_scene = get_tree().current_scene
	if main_scene:
		main_scene.add_child(card_preview)
		card_preview.setup_preview_for_card(self)
