extends Node
class_name ClientUIUpdater

# UI элементы
@onready var income_label_player: Label = $"../Control_lair/Game_UI/Right_info_display/Player_wealth_display/Player_income"
@onready var wealth_label_player: Label = $"../Control_lair/Game_UI/Right_info_display/Player_wealth_display/Player_wealth"
@onready var income_label_opponent: Label = $"../Control_lair/Game_UI/Right_info_display/Opponent_wealth_display/Player_income"
@onready var wealth_label_opponent: Label = $"../Control_lair/Game_UI/Right_info_display/Opponent_wealth_display/Player_wealth"
@onready var turn_label: Label = $"../Control_lair/Game_UI/Right_info_display/Turn_space/Turns"
@onready var hand_manager: HandManager = $"../Playable_lair/Hand_manager"

var my_player_id: String

func _ready():
	if NetworkMode.is_server():
		queue_free()
		return
	
	print("ClientUIUpdater ready and listening for updates")
	
	my_player_id = PlayerDatabase.current_user
	NetworkManager.game_action_received.connect(_on_server_update)

func _on_server_update(update_data: Dictionary):
	print("ClientUIUpdater received: ", update_data.type)
	
	match update_data.type:
		"game_started":
			_handle_game_start(update_data.data)
		"turn_started":
			_handle_turn_start(update_data.data)
		"phase_changed":
			_handle_phase_change(update_data.data)
		"wealth_update":
			_handle_wealth_update(update_data.data)
		"opponent_wealth_update":  # Add this
			_handle_opponent_wealth_update(update_data.data)
		"income_update":  # Add this
			_handle_income_update(update_data.data)
		"opponent_income_update":  # Add this
			_handle_opponent_income_update(update_data.data)
		"board_update":
			_handle_board_update(update_data.data)
		_:
			print("Unhandled update type: ", update_data.type)

func _handle_game_start(data: Dictionary):
	# Инициализация UI
	wealth_label_player.text = "1000"
	income_label_player.text = "100"
	wealth_label_opponent.text = "1000"
	income_label_opponent.text = "100"
	turn_label.text = "1"

func _handle_turn_start(data: Dictionary):
	turn_label.text = str(data.turn)

func _handle_phase_change(data: Dictionary):
	var phase = data.phase
	var player = data.player
	
	# Блокируем/разблокируем руку
	if hand_manager:
		if phase == "main" and player == my_player_id:
			hand_manager.lock_hand(false)
		else:
			hand_manager.lock_hand(true)



func _handle_wealth_update(data: Dictionary):
	var player_id = data.player_id
	var wealth = data.wealth
	var spent = data.get("spent", 0)
	var income_gained = data.get("income_gained", false)
	
	if player_id == my_player_id:
		wealth_label_player.text = str(wealth)
		ClientGameState.my_wealth = wealth
		
		# Показать анимацию траты/получения
		if spent > 0:
			_show_wealth_change_animation(-spent, wealth_label_player.global_position)
		elif income_gained:
			var income = data.get("income", 0)
			_show_wealth_change_animation(income, wealth_label_player.global_position)

func _handle_opponent_wealth_update(data: Dictionary):
	wealth_label_opponent.text = str(data.wealth)
	ClientGameState.opponent_wealth = data.wealth

func _handle_income_update(data: Dictionary):
	income_label_player.text = str(data.income)
	ClientGameState.my_income = data.income

func _handle_opponent_income_update(data: Dictionary):
	income_label_opponent.text = str(data.income)
	ClientGameState.opponent_income = data.income
	
func _handle_board_update(data: Dictionary):
	print("Handling board update: ", data)
	
	var hex_position = Vector2i(data.hex_position.x, data.hex_position.y)
	var card_name = data.card_name
	var player_id = data.player_id
	
	# Get the card play manager to visualize the card
	var play_manager = get_node_or_null("../card_play_manager")
	if play_manager:
		# Create a visual representation of the opponent's card
		play_manager.show_opponent_card(card_name, hex_position)

func _show_wealth_change_animation(amount: int, position: Vector2):
	# Создать анимацию +/- денег
	var label = Label.new()
	label.text = ("+" if amount > 0 else "") + str(amount)
	label.modulate = Color.GREEN if amount > 0 else Color.RED
	label.position = position
	get_tree().current_scene.add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "position:y", position.y - 50, 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)
