class_name FishingPlace_Card
extends Card
static var scene = preload("res://Scenes/card_template.tscn")

static func create() -> FishingPlace_Card:
	var instance = scene.instantiate()
	instance.set_script(preload("res://Scripts/Client/Scripts_card/Scripts_card_types/Card_FishingPlace.gd"))
	return instance
func _init():
	card_name = "Fishing Place"
	card_description = "Generates 10 gold per turn"
	card_cost = 400
	income_per_turn = 10
	special_effects = ["income_generation"]
	# Load textures
	card_art = preload("res://Sprites/Sprites_card_art/photo_2025-06-09_19-39-59.jpg")
	tile_source_id = 4  # Main tileset
	tile_atlas_coords = Vector2i(3, 0)
