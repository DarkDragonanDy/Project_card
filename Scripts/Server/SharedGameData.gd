# SharedGameData.gd - Общие структуры данных для сервера и клиента
class_name SharedGameData

# Основное состояние игры
class GameState:
	var players: Dictionary = {}  # player_name -> PlayerData
	var field: Dictionary = {}    # "x,y" -> FieldCard
	var current_turn: int = 1
	var current_player: String = ""
	var max_turns: int = 10
	var game_phase: String = "playing"  # "waiting", "playing", "ended"
	
	func get_current_player_data() -> PlayerData:
		if current_player in players:
			return players[current_player]
		return null
	
	func get_player_data(player_name: String) -> PlayerData:
		return players.get(player_name, null)
	
	func is_position_occupied(hex_pos: Vector2i) -> bool:
		var pos_key = str(hex_pos.x) + "," + str(hex_pos.y)
		return pos_key in field
	
	func get_card_at_position(hex_pos: Vector2i) -> FieldCard:
		var pos_key = str(hex_pos.x) + "," + str(hex_pos.y)
		return field.get(pos_key, null)

# Данные игрока
class PlayerData:
	var name: String = ""
	var wealth: int = 1000
	var income: int = 100
	var hand: Array[String] = []  # card names
	var deck: Array[String] = []  # remaining cards
	
	func can_afford(cost: int) -> bool:
		return wealth >= cost
	
	func has_card_in_hand(card_name: String) -> bool:
		return card_name in hand
	
	func remove_card_from_hand(card_name: String) -> bool:
		var index = hand.find(card_name)
		if index != -1:
			hand.remove_at(index)
			return true
		return false
	
	func add_card_to_hand(card_name: String):
		hand.append(card_name)
	
	func spend_wealth(amount: int) -> bool:
		if can_afford(amount):
			wealth -= amount
			return true
		return false

# Карта на поле
class FieldCard:
	var card_name: String = ""
	var owner: String = ""
	var hex_position: Vector2i
	var placed_turn: int = 0
	var effects_applied: bool = false
	
	func _init(name: String = "", owner_name: String = "", pos: Vector2i = Vector2i.ZERO, turn: int = 0):
		card_name = name
		owner = owner_name
		hex_position = pos
		placed_turn = turn

# Данные карты из базы
class CardData:
	var name: String = ""
	var description: String = ""
	var cost: int = 0
	var effects: Dictionary = {}
	
	func _init(card_name: String = "", card_desc: String = "", card_cost: int = 0):
		name = card_name
		description = card_desc
		cost = card_cost
	
	# Применяет эффекты карты к игровому состоянию
	func apply_effects(game_state: GameState, player_name: String, hex_pos: Vector2i):
		var player_data = game_state.get_player_data(player_name)
		if not player_data:
			return
		
		# Эффекты конкретных карт
		match name:
			"Meadow":
				player_data.income += 50
				print("Meadow effect: +50 income for ", player_name)
			"iceball":
				# Боевая карта - пока просто размещается
				print("Iceball played by ", player_name)
			"Fishing Place":
				player_data.income += 30
				print("Fishing Place effect: +30 income for ", player_name)
			_:
				print("No special effects for card: ", name)

# Действие игрока
class PlayerAction:
	var type: String = ""
	var player: String = ""
	var data: Dictionary = {}
	var timestamp: float = 0.0
	
	func _init(action_type: String, player_name: String, action_data: Dictionary = {}):
		type = action_type
		player = player_name
		data = action_data
		timestamp = Time.get_unix_time_from_system()

# Результат действия
class ActionResult:
	var success: bool = false
	var message: String = ""
	var game_state_changes: Dictionary = {}
	
	func _init(is_success: bool, result_message: String = "", changes: Dictionary = {}):
		success = is_success
		message = result_message
		game_state_changes = changes
