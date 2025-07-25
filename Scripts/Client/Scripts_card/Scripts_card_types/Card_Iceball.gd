class_name IceballCard
extends Card
static var scene = preload("res://Scenes/card_template.tscn")
static func create() -> IceballCard:
	var instance = scene.instantiate()
	instance.set_script(preload("res://Scripts/Client/Scripts_card/Scripts_card_types/Card_Iceball.gd"))
	return instance
	
func _init():
	card_name = "Rocket"
	card_description = "Generates 20 gold per turn"
	card_cost = 300
	income_per_turn = 20
	special_effects = ["income_generation"]
	# Load textures
	card_art = preload("res://Sprites/Sprites_card_art/photo_2025-06-09_19-39-50.jpg")
	tile_source_id = 4  # Main tileset
	tile_atlas_coords = Vector2i(0, 0)
	
