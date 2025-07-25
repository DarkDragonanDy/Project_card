class_name Meadow_Card
extends Card
static var scene = preload("res://Scenes/card_template.tscn")

static func create() -> Meadow_Card:
	var instance = scene.instantiate()
	instance.set_script(preload("res://Scripts/Client/Scripts_card/Scripts_card_types/Card_Meadow.gd"))
	return instance
func _init():
	card_name = "Meadow Card"
	card_description = "Generates 5 gold per turn"
	card_cost = 150
	income_per_turn = 5
	special_effects = ["income_generation"]
	# Load textures
	card_art = preload("res://Sprites/Sprites_card_art/photo_2025-06-09_19-39-55.jpg")
	tile_source_id = 4  # Main tileset
	tile_atlas_coords = Vector2i(1, 0)
	
