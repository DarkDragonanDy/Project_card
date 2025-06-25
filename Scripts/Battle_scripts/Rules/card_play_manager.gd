extends Node
class_name CardPlayManager

@onready var hex_grid: TileMapLayer = $"../Control_lair/Game_UI/GridContainer/Game_board/TileMapLayer"
@onready var game_manager: GameManager = $"../Game_manager"
@onready var economy_manager: EconomyManager = $"../Economy_manager"
# Store card data per hex
var played_cards: Dictionary = {}  # hex_position: Card

# If you need a separate layer for cards
var card_layer_index: int = 0  # Or create a second TileMapLayer

signal card_successfully_played(card: Card, hex_position: Vector2i)

func _ready():
	# Option: Create a second layer for cards if needed
	# This keeps terrain and cards separate
	if hex_grid.get_parent().has_node("CardTileMapLayer"):
		card_layer_index = 1

func play_card(card: Card, hex_position: Vector2i) -> bool:
	# Validate placement
	if not _is_valid_play(card, hex_position):
		return false
	
	# Check affordability
	if not game_manager.purchase_card(card):
		return false
	
	# Get current tile data to preserve terrain
	var current_tile = hex_grid.get_cell_source_id(hex_position)
	var current_atlas = hex_grid.get_cell_atlas_coords(hex_position)
	
	# Store the original terrain (if you want to restore it later)
	if not "original_terrain" in played_cards:
		played_cards["original_terrain"] = {}
	played_cards["original_terrain"][hex_position] = {
		"source": current_tile,
		"atlas": current_atlas
	}
	
	# Place the card tile
	hex_grid.set_cell(
		hex_position,
		card.tile_source_id,
		card.tile_atlas_coords,
		
	)
	
	# Store card reference
	played_cards[hex_position] = card
	
	# Hide the card from hand
	card.visible = false
	if card.state_manager:
		card.state_manager.change_state("played")
	
	# Execute card effects
	card.on_play({
		"player": game_manager.current_player,
		"hex_position": hex_position
	})
	
	card_successfully_played.emit(card, hex_position)
	return true

func _is_valid_play(card: Card, hex_position: Vector2i) -> bool:
	# Check if hex exists
	var tile_data = hex_grid.get_cell_tile_data(hex_position)
	if not tile_data:
		return false
	
	# Check if already has a card
	if hex_position in played_cards:
		return false

	
	return true 


func remove_card_from_hex(hex_position: Vector2i):
	if not hex_position in played_cards:
		return
	
	var card = played_cards[hex_position]
	
	# Restore original terrain
	if "original_terrain" in played_cards:
		var original = played_cards["original_terrain"][hex_position]
		hex_grid.set_cell(
			hex_position,
			original.source,
			original.atlas
		)
	
	# Clean up
	played_cards.erase(hex_position)
	card.on_remove({"hex_position": hex_position})
	card.queue_free()
func _is_valid_hex(hex_position: Vector2i) -> bool:
	# Check if hex exists in tilemap
	var tile_data = hex_grid.get_cell_tile_data(hex_position)
	return tile_data != null
