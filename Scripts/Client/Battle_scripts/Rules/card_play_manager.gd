extends Node
class_name CardPlayManager

@onready var hex_grid: TileMapLayer = $"../Control_lair/Game_UI/GridContainer/Game_board/TileMapLayer"
@onready var cards_container: Node2D

var played_cards: Dictionary[Vector2i,Card] = {}
var pending_plays: Dictionary = {}  # request_id: {card, hex_position}

signal card_play_requested(card: Card, hex_position: Vector2i)

func _ready():
	cards_container = Node2D.new()
	cards_container.name = "CardsContainer"
	hex_grid.get_parent().add_child(cards_container)
	
	# Подключаемся к ответам от сервера
	NetworkManager.game_action_received.connect(_on_server_response)

func request_card_play(card: Card, hex_position: Vector2i) -> bool:
	# Визуальное размещение
	_show_card_preview_at_hex(card, hex_position)
	
	# Сохраняем запрос
	var request_id = str(Time.get_unix_time_from_system())
	pending_plays[request_id] = {"card": card, "hex": hex_position}
	
	# Отправляем запрос
	NetworkManager.send_game_action("request_card_play", {
		"card_name": card.card_name,
		"hex_position": {"x": hex_position.x, "y": hex_position.y},
		"request_id": request_id
	})
	
	return true

func _show_card_preview_at_hex(card: Card, hex_position: Vector2i):
	var world_pos = hex_grid.map_to_local(hex_position)
	card.global_position = hex_grid.to_global(world_pos)
	card.modulate.a = 0.5



func _finalize_card_placement(card: Card, hex_position: Vector2i):
	card.modulate.a = 1.0
	card.visible = false
	
	if card.get_parent() != cards_container:
		card.get_parent().remove_child(card)
		cards_container.add_child(card)
	
	played_cards[hex_position] = card
	
	hex_grid.set_cell(
		hex_position,
		card.tile_source_id,
		card.tile_atlas_coords
	)
	
	if card.state_manager:
		card.state_manager.change_state("played")

func _cancel_card_placement(card: Card):
	card.modulate.a = 1.0
	if card.drag_handler:
		card.drag_handler.force_return_to_hand()


func show_opponent_card(card_name: String, hex_position: Vector2i):
	print("Showing opponent card: ", card_name, " at ", hex_position)
	
	# Create the card instance
	var card_instance = CardDatabase.create_card_instance(card_name)
	if not card_instance:
		print("Failed to create opponent card!")
		return
	
	# Add to scene
	if card_instance.get_parent():
		card_instance.get_parent().remove_child(card_instance)
	cards_container.add_child(card_instance)
	
	# Position at hex
	var world_pos = hex_grid.map_to_local(hex_position)
	card_instance.global_position = hex_grid.to_global(world_pos)
	card_instance.visible = false  # Keep invisible as per original logic
	
	# Store reference
	played_cards[hex_position] = card_instance
	
	# Update tilemap
	hex_grid.set_cell(
		hex_position,
		card_instance.tile_source_id,
		card_instance.tile_atlas_coords
	)
	
	# Set state
	if card_instance.state_manager:
		card_instance.state_manager.change_state("played")





func _on_server_response(response: Dictionary):
	print("CardPlayManager received response: ", response.type)
	
	if response.type != "card_play_response":
		return
	
	var request_id = response.data.get("request_id", "")
	if not request_id in pending_plays:
		print("No pending play for request_id: ", request_id)
		return
	
	var pending = pending_plays[request_id]
	var card = pending["card"]
	var hex_position = pending["hex"]
	
	print("Processing response for card: ", card.card_name, " approved: ", response.data.get("approved", false))
	
	if response.data.get("approved", false):
		_finalize_card_placement(card, hex_position)
	else:
		_cancel_card_placement(card)
		print("Card play rejected: ", response.data.get("reason", "unknown"))
	
	# Always clear the pending play
	pending_plays.erase(request_id)











#extends Node
#class_name CardPlayManager
#
#@onready var hex_grid: TileMapLayer = $"../Control_lair/Game_UI/GridContainer/Game_board/TileMapLayer"
#@onready var game_manager: GameManager = $"../Game_manager"
#@onready var economy_manager: EconomyManager = $"../Economy_manager"
#@onready var cards_container: Node2D
#
#var played_cards: Dictionary[Vector2i,Card] = {}  # hex_position: Card
#
## If you need a separate layer for cards
#var card_layer_index: int = 0  # Or create a second TileMapLayer
#
#signal card_successfully_played(card: Card, hex_position: Vector2i)
#
#func _ready():
	## Create container for played cards if it doesn't exist
	#
	#cards_container = Node2D.new()
	#cards_container.name = "CardsContainer"
	#hex_grid.get_parent().add_child(cards_container)
#
#func play_card(card: Card, hex_position: Vector2i) -> bool:
	## Validate placement
	#
	#if not _is_valid_play(card, hex_position):
		#return false
	#
	## Check affordability
	#if not game_manager.purchase_card(card):
		#return false
	#
	## Get current tile data to preserve terrain
	#card.get_parent().remove_child(card)
	#cards_container.add_child(card)
	#
	#
	## Position card at hex location
	#var world_pos = hex_grid.map_to_local(hex_position)
	#card.global_position = hex_grid.to_global(world_pos)
	#
	## Make card invisible but keep it active
	#card.visible = false
	#card.set_process(true)  
	#
	#
	## Store reference
	#played_cards[hex_position] = card
	#
	## Update card state
	#if card.state_manager:
		#card.state_manager.change_state("played")
	#
	## Update tilemap to show card tile (visual only)
	#hex_grid.set_cell(
		#hex_position,
		#card.tile_source_id,
		#card.tile_atlas_coords,
	#)
	#
	## Execute card effects - card can now use signals normally
	#card.on_play({
		#"player": game_manager.current_player,
		#"hex_position": hex_position
	#})
	#
	## Connect card signals for board interactions
	#
	#
	#return true
#
#func _is_valid_play(card: Card, hex_position: Vector2i) -> bool:
	## Check if hex exists
	#var tile_data = hex_grid.get_cell_tile_data(hex_position)
	#if not tile_data:
		#return false
	#
	## Check if already has a card
	#if hex_position in played_cards:
		#return false
#
	#
	#return true 
#
#func _is_valid_hex(hex_position: Vector2i) -> bool:
	## Check if hex exists in tilemap
	#var tile_data = hex_grid.get_cell_tile_data(hex_position)
	#return tile_data != null
#
func get_card_at_hex(hex_position: Vector2i) -> Card:
	# Safe access with null check
	if hex_position in played_cards:
		return played_cards[hex_position]
	return null
