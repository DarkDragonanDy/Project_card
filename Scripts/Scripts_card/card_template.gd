extends Node2D
class_name Card

static var card_scene = preload("res://Scenes/card_template.tscn")

@export var card_name: String = ""
@export var card_description: String = ""
@export var card_cost: int = 0
@export var card_unique_id: String = ""
@export var card_art: Texture2D = null

@onready var card_back: Sprite2D = $Card_back
@onready var text_box = $Card_box_text/Card_text_box
@onready var cost_box = $Card_box_cost/Card_text_cost
@onready var art = $Card_art
@onready var name_label = $Card_box_name/Card_text_name

func _init(name: String = "", desc: String = "", cost: int = 0, id: String = "", art_texture: Texture2D = null):
	card_name = name
	card_description = desc
	card_cost = cost
	card_unique_id = id
	card_art = art_texture

func _ready():
	update_card_display()

func update_card_display():
	if is_instance_valid(name_label):
		name_label.text = card_name
	if is_instance_valid(text_box):
		text_box.text = card_description
	if is_instance_valid(cost_box):
		cost_box.text = str(card_cost)
	if is_instance_valid(art) and card_art:
		art.texture = card_art

# Simpler, more reliable texture generation


# Even simpler version using existing nodes
static func generate_card_texture(name: String, desc: String, cost: int, art_texture: Texture2D = null, texture_size: Vector2 = Vector2(63.5, 88.9)) -> ImageTexture:
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
	card.position = texture_size / 2

	# Wait for nodes to be ready
	await current_scene.get_tree().process_frame

	# Set data directly on nodes
	var name_node = card.get_node_or_null("Card_box_name/Card_text_name")
	if name_node:
		name_node.text = name

	var desc_node = card.get_node_or_null("Card_box_text/Card_text_box")
	if desc_node:
		desc_node.text = desc

	var cost_node = card.get_node_or_null("Card_box_cost/Card_text_cost")
	if cost_node:
		cost_node.text = str(cost)

	var art_node = card.get_node_or_null("Card_art")
	if art_node and art_texture:
		art_node.texture = art_texture

	# Wait for rendering
	await current_scene.get_tree().process_frame
	await current_scene.get_tree().process_frame

	# Capture
	var image = viewport.get_texture().get_image()
	var texture = ImageTexture.create_from_image(image)
	image = texture.get_image()
	var filename = "res://" + name.to_lower().replace(" ", "_") + ".png"
	var error = image.save_png(filename)

	if error == OK:
		print("Saved card texture: ", filename)
	else:
		print("Failed to save texture: ", error)

	# Cleanup
	viewport.queue_free()
	
	return texture

# Simple instance method
func get_texture() -> ImageTexture:
	return await Card.generate_card_texture(card_name, card_description, card_cost, card_art)


func apply_card_data(data: Card):
	card_name = data.card_name
	card_description = data.card_description
	card_cost = data.card_cost
	card_art = data.card_art
	
#func clone() -> Card:
	#var new_card = Card.new()
	#new_card.card_name = card_name
	#new_card.card_description = card_description
	#new_card.card_cost = card_cost
	#new_card.card_unique_id = card_unique_id
	#return new_card
