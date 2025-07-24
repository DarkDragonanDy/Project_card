extends Node
class_name DeckToHandManager

var is_server_side: bool = false

# Клиентские ссылки
@onready var hand_manager: HandManager = get_node_or_null("../Hand_manager")

signal card_drawn(card: Card)

# In DeckToHandManager:
func _ready():
	is_server_side = NetworkMode.is_server()
	
	if is_server_side:
		queue_free()
		return
	
	print("DeckToHandManager ready and listening")
	
	# Connect to server updates
	NetworkManager.game_action_received.connect(_on_server_update)

func _on_server_update(update_data: Dictionary):
	print("DeckToHandManager received: ", update_data.type)
	
	match update_data.type:
		"initial_hand":
			_handle_initial_hand(update_data.data)
		"card_drawn":
			_handle_single_card_drawn(update_data.data)

func _handle_initial_hand(data: Dictionary):
	var card_names = data.get("cards", [])
	print("Handling initial hand with ", card_names.size(), " cards")
	
	# Create cards with delay for animation
	for i in range(card_names.size()):
		await get_tree().create_timer(0.3 * i).timeout
		_create_card_for_hand(card_names[i])

func _handle_single_card_drawn(data: Dictionary):
	var card_name = data.get("card_name", "")
	print("Drawing single card: ", card_name)
	_create_card_for_hand(card_name)

func _create_card_for_hand(card_name: String):
	print("Creating card: ", card_name)
	
	# Create the card instance
	var card_instance = CardDatabase.create_card_instance(card_name)
	if not card_instance:
		print("Failed to create card!")
		return
	
	# Add to scene
	get_tree().current_scene.add_child(card_instance)
	
	# Give to hand manager
	if hand_manager:
		hand_manager.add_card_to_hand(card_instance)
	else:
		print("No hand manager found!")
















#extends Node
#class_name DeckToHandManager
#
## Deck configuration
#const STARTING_HAND_SIZE: int = 4
#const DRAW_DELAY: float = 0.8
#
## Deck state
#var player_deck: Array = []
#var deck_size: int = 30
#var cards_drawn: int = 0
#
## References
#var hand_manager: HandManager
#var game_manager: Node
#var turn_manager: TurnManager
#
## Signals
#signal card_ready_for_hand(card: Card)
#signal deck_empty
#signal deck_loaded
#
#func _ready():
	## Get references
	#hand_manager = get_node_or_null("../Hand_manager")
	#game_manager = get_node_or_null("../../Game_manager")
	#turn_manager = get_node_or_null("../../Turn_manager")
	#
	#
	#
	#if not hand_manager:
		#print("Error: HandManager not found!")
		#return
	#
	## Connect signals
	#
	#hand_manager.hand_full.connect(_on_hand_full)
	##game_manager.game_started_signal.connect(_load_deck_from_data)
	#
	#
	## Load and initialize deck
	#
	  ## Wait for scene setup
	#
	#
#
#func _load_deck_from_data():
	## Load deck from singleton
	#player_deck = DeckData.get_deck()
	#deck_size = player_deck.size()
	#
	#print("Deck loaded with ", deck_size, " cards")
	#
	## Shuffle deck
	#_shuffle_deck()
	#
	#deck_loaded.emit()
#
#func _shuffle_deck():
	## Fisher-Yates shuffle
	#for i in range(player_deck.size() - 1, 0, -1):
		#var j = randi() % (i + 1)
		#var temp = player_deck[i]
		#player_deck[i] = player_deck[j]
		#player_deck[j] = temp
	#
	#print("Deck shuffled")
#
#func _draw_starting_hand():
	#print("Drawing starting hand...")
	#
	#for i in range(STARTING_HAND_SIZE):
		#var success = await draw_card()
		#if not success:
			#print("Failed to draw card ", i + 1, " for starting hand")
			#break
	#
	#print("Starting hand drawn. Cards in deck: ", player_deck.size())
#
#func draw_card() -> bool:
	#await get_tree().create_timer(DRAW_DELAY).timeout
	#if player_deck.is_empty():
		#print("Cannot draw card: Deck is empty!")
		#deck_empty.emit()
		#return false
	#
	#if hand_manager.is_hand_full():
		#print("Cannot draw card: Hand is full!")
		#return false
	#
	## Get card data from deck
	#var card_data = player_deck.pop_front()
	#
	## Create game card instance
	#var card_instance = await _create_game_card(card_data)
	#
	#if card_instance:
		## Add to scene first
		#get_tree().current_scene.add_child(card_instance)
		#
		## Signal to hand manager
		#card_ready_for_hand.emit(card_instance)
		#
		#cards_drawn += 1
		#print("Drew card: ", card_instance.card_name, " (", cards_drawn, " total drawn)")
		#return true
	#
	#print("Failed to create card instance for: ", card_data.get("name", "Unknown"))
	#return false
#
#func _create_game_card(card_data_deck: Dictionary) -> Card:
	## Validate card data
	#if not card_data_deck.has("name"):
		#print("Error: Card data missing name field")
		#return null
	#
	#var card_name = card_data_deck["name"]
	#
	## Create card instance from database
	#var card_instance = CardDatabase.create_card_instance(card_name)
	#
	#if not card_instance:
		#print("Error: Failed to create card instance for: ", card_name)
		#return null
	#
	## Set up card for gameplay
	#_setup_card_for_game(card_instance, card_data_deck)
	#
	#return card_instance
#
#func _setup_card_for_game(card: Card, card_data: Dictionary):
	## Set unique ID for this game instance
	#card.card_unique_id = str(cards_drawn) + "_" + card.card_name + "_" + str(Time.get_unix_time_from_system())
	#
	## Store original deck data
	#card.set_meta("deck_data", card_data)
	#
	## Connect game-specific signals
	#if game_manager and game_manager.has_method("_on_card_created"):
		#game_manager._on_card_created(card)
#
#
#
#func force_draw_card() -> bool:
	## For manual card drawing (e.g., special abilities)
	#return await draw_card()
#
#func add_card_to_deck(card_data: Dictionary):
	## Add card to deck (e.g., from spells that generate cards)
	#player_deck.append(card_data)
	#print("Added card to deck: ", card_data.get("name", "Unknown"))
#
#func get_deck_size() -> int:
	#return player_deck.size()
#
#func get_cards_drawn() -> int:
	#return cards_drawn
#
#func is_deck_empty() -> bool:
	#return player_deck.is_empty()
#
#func peek_top_card() -> Dictionary:
	## Look at top card without drawing
	#if not player_deck.is_empty():
		#return player_deck[0].duplicate()
	#return {}
#
#func peek_top_cards(count: int) -> Array:
	## Look at top N cards without drawing
	#var cards = []
	#var max_count = min(count, player_deck.size())
	#
	#for i in range(max_count):
		#cards.append(player_deck[i].duplicate())
	#
	#return cards
#
#func shuffle_card_into_deck(card_data: Dictionary, position: String = "random"):
	## Add card to deck at specific position
	#match position:
		#"top":
			#player_deck.push_front(card_data)
		#"bottom":
			#player_deck.push_back(card_data)
		#"random":
			#var insert_pos = randi() % (player_deck.size() + 1)
			#player_deck.insert(insert_pos, card_data)
		#_:
			#player_deck.push_back(card_data)
	#
	#print("Shuffled card into deck (", position, "): ", card_data.get("name", "Unknown"))
#
#func _on_hand_full():
	#print("Hand is full, cannot draw more cards")
#
#
#
## Debug functions
#func print_deck_state():
	#print("=== Deck State ===")
	#print("Cards in deck: ", player_deck.size())
	#print("Cards drawn: ", cards_drawn)
	#print("Top 3 cards:")
	#
	#var top_cards = peek_top_cards(3)
	#for i in range(top_cards.size()):
		#print("  [", i + 1, "] ", top_cards[i].get("name", "Unknown"))
#
#func get_deck_composition() -> Dictionary:
	## Get count of each card type in deck
	#var composition = {}
	#
	#for card_data in player_deck:
		#var name = card_data.get("name", "Unknown")
		#if name in composition:
			#composition[name] += 1
		#else:
			#composition[name] = 1
	#
	#return composition
#
## For testing purposes
#func _input(event):
	#if event.is_action_pressed("ui_accept"):  # Space key
		#if Input.is_action_pressed("ui_select"):  # Shift key
			#print_deck_state()
		#else:
			#force_draw_card()
