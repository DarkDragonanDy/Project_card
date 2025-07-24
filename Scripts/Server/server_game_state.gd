extends Node
class_name ServerGameState

var players: Dictionary = {}  # player_id: PlayerState
var board_state: Dictionary = {}  # Vector2i as string: card_name
var current_turn: int = 1
var current_player: String = ""

class PlayerState:
	var wealth: int = 1000
	var income: int = 100
	var deck: Array = []
	var hand: Array = []
	var played_cards: Dictionary = {}
	var max_hand_size: int = 7
	
	func can_draw_card() -> bool:
		return hand.size() < max_hand_size and not deck.is_empty()
	
	func draw_card() -> String:
		if not can_draw_card():
			return ""
		
		var card_data = deck.pop_front()
		var card_name = card_data.get("name", "")
		hand.append(card_name)
		return card_name
	
	func remove_card_from_hand(card_name: String) -> bool:
		var index = hand.find(card_name)
		if index >= 0:
			hand.remove_at(index)
			return true
		return false
	
	func get_hand_size() -> int:
		return hand.size()

# Add these functions to ServerGameState (not inside PlayerState):
func remove_card_from_player_hand(player_id: String, card_name: String) -> bool:
	if not player_id in players:
		return false
	return players[player_id].remove_card_from_hand(card_name)

func draw_card_for_player(player_id: String) -> String:
	if not player_id in players:
		return ""
	return players[player_id].draw_card()

func get_player_hand_size(player_id: String) -> int:
	if not player_id in players:
		return 0
	return players[player_id].get_hand_size()

func get_player_wealth(player_id: String) -> int:
	if player_id in players:
		return players[player_id].wealth
	return 0

func spend_player_wealth(player_id: String, amount: int) -> bool:
	if player_id in players and players[player_id].wealth >= amount:
		players[player_id].wealth -= amount
		return true
	return false

func add_player_income(player_id: String, amount: int):
	if player_id in players:
		players[player_id].income += amount

func place_card_on_board(player_id: String, card_name: String, hex_position: Vector2i):
	var hex_key = _vec2i_to_string(hex_position)
	board_state[hex_key] = card_name
	players[player_id].played_cards[hex_key] = card_name

func is_hex_occupied(hex_position: Vector2i) -> bool:
	return _vec2i_to_string(hex_position) in board_state

func initialize_player(player_id: String, deck_data: Array):
	var player = PlayerState.new()
	player.deck = deck_data.duplicate()
	players[player_id] = player

func _vec2i_to_string(vec: Vector2i) -> String:
	return str(vec.x) + "," + str(vec.y)

func _string_to_vec2i(s: String) -> Vector2i:
	var parts = s.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))
