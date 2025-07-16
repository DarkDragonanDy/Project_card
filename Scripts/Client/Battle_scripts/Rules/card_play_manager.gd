extends Node
class_name CardPlayManager

@onready var hex_grid: TileMapLayer = $"../Control_lair/Game_UI/GridContainer/Game_board/TileMapLayer"
@onready var game_manager: GameManager = $"../Game_manager"
@onready var economy_manager: EconomyManager = $"../Economy_manager"
@onready var cards_container: Node2D

var played_cards: Dictionary[Vector2i,Card] = {}  # hex_position: Card

# If you need a separate layer for cards
var card_layer_index: int = 0  # Or create a second TileMapLayer

signal card_successfully_played(card: Card, hex_position: Vector2i)

func _ready():
	# Create container for played cards if it doesn't exist
	
	cards_container = Node2D.new()
	cards_container.name = "CardsContainer"
	hex_grid.get_parent().add_child(cards_container)

func play_card(card: Card, hex_position: Vector2i) -> bool:
	# Validate placement
	if not _is_valid_play(card, hex_position):
		return false
	
	# Check affordability
	if not game_manager.purchase_card(card):
		return false
	
	# Get current tile data to preserve terrain
	card.get_parent().remove_child(card)
	cards_container.add_child(card)
	
	
	# Position card at hex location
	var world_pos = hex_grid.map_to_local(hex_position)
	card.global_position = hex_grid.to_global(world_pos)
	
	# Make card invisible but keep it active
	card.visible = false
	card.set_process(true)  
	
	
	# Store reference
	played_cards[hex_position] = card
	
	# Update card state
	if card.state_manager:
		card.state_manager.change_state("played")
	
	# Update tilemap to show card tile (visual only)
	hex_grid.set_cell(
		hex_position,
		card.tile_source_id,
		card.tile_atlas_coords,
	)
	
	# Execute card effects - card can now use signals normally
	card.on_play({
		"player": game_manager.current_player,
		"hex_position": hex_position
	})
	
	# Connect card signals for board interactions
	
	
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

func _is_valid_hex(hex_position: Vector2i) -> bool:
	# Check if hex exists in tilemap
	var tile_data = hex_grid.get_cell_tile_data(hex_position)
	return tile_data != null

func get_card_at_hex(hex_position: Vector2i) -> Card:
	# Safe access with null check
	if hex_position in played_cards:
		return played_cards[hex_position]
	return null
