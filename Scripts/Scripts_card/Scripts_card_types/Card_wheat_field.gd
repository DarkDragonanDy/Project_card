extends Card
class_name WheatFieldCard

func _init():
	card_name = "Wheat Field"
	card_description = "Generates 2 gold per turn"
	card_cost = 100
	income_per_turn = 2
	special_effects = ["income_generation"]
	# Load textures
	card_art = preload("res://Sprites/Sprites_card_art/photo_2025-06-09_19-40-41.jpg")
	tile_source_id = 8  # Main tileset
	tile_atlas_coords = Vector2i(1, 0)

func on_play(game_state: Dictionary) -> void:
	var economy_manager = get_node("/root/Battle_scene/Economy_manager")
	if economy_manager:
		economy_manager.add_income_source(game_state.current_player, income_per_turn)
