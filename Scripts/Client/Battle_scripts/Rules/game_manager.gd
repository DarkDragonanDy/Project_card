extends Node
class_name GameManager

# Game state
enum GameState {
	MENU,
	LOADING,
	PLAYING,
	PAUSED,
	GAME_OVER
}

var game_started: bool = false
var game_paused: bool = false


var current_state: GameState = GameState.LOADING
var winner: int = 0
var current_player: int = 1
var total_players: int = 1
var current_turn: int = 0
var max_turns: int = 10

# References gloabal systems
@onready var turn_manager: TurnManager=$"../Turn_manager"

@onready var economy_manager: EconomyManager = $"../Economy_manager"
@onready var setup: GameSetupCoordinator = $".."
@onready var deck_to_hand: DeckToHandManager = $"../Playable_lair/DeckToHand_manager"


# References label
@onready var income_label_player: Label = $"../Control_lair/Game_UI/Right_info_display/Player_wealth_display/Player_income"
@onready var wealth_label_player: Label = $"../Control_lair/Game_UI/Right_info_display/Player_wealth_display/Player_wealth"
@onready var income_label_opponent: Label = $"../Control_lair/Game_UI/Right_info_display/Opponent_wealth_display/Player_income"
@onready var wealth_label_opponent: Label = $"../Control_lair/Game_UI/Right_info_display/Opponent_wealth_display/Player_wealth"
@onready var turn_label: Label =$"../Control_lair/Game_UI/Right_info_display/Turn_space/Turns"


signal game_state_changed(new_state: GameState)
signal game_over(winner: int)
signal game_started_signal


func _ready():
	
	connect_signals()
	
func connect_signals():
	if economy_manager:
		if economy_manager.has_signal("wealth_changed"):
			economy_manager.wealth_changed.connect(wealth_changed_text)
		if economy_manager.has_signal("income_changed"):
			economy_manager.income_changed.connect(income_changed_text)
	if turn_manager:
		turn_manager.turn_started.connect(_on_turn_started)
		turn_manager.turn_ended.connect(_on_turn_ended)
	if setup:
		setup.game_ready_to_start.connect(start_game)
	

# Signals


func start_game():
	#current_state = GameState.PLAYING
	#game_state_changed.emit(current_state)
	income_changed_text(1,economy_manager.get_income(1))
	income_changed_text(2,economy_manager.get_income(2))
	wealth_changed_text(1,economy_manager.get_wealth(1))
	wealth_changed_text(2,economy_manager.get_wealth(2))
	if game_started:
		print("Game already started!")
		return
	
	print("=== GAME STARTING ===")
	game_started = true
	current_player = 1
	current_turn = 1
	
	await deck_to_hand._load_deck_from_data()
	await deck_to_hand._draw_starting_hand()
	game_started_signal.emit()
	turn_manager.start_turn(current_player,current_turn)
	

	print("GameManager: Game started")
	
func _on_turn_ended(player: int):
	if current_turn >= max_turns:
		_end_game()
	current_player +=1
	if current_player>total_players:
		current_player=1
	if current_player == 1:
		current_turn += 1
	turn_manager.start_turn(current_player,current_turn)

func _on_turn_started(player: int, turn: int):
	current_turn = turn
	turn_label.text=str(current_turn)
	
	

func _end_game():
	if economy_manager:
		winner = economy_manager.determine_winner()
		current_state = GameState.GAME_OVER
		game_over.emit(winner)
		
		
func wealth_changed_text(player: int, wealth: int):
	if player==1:
		wealth_label_player.text=str(wealth)
	else:
		wealth_label_opponent.text=str(wealth)
func income_changed_text(player: int, income: int):
	if player==1:
		income_label_player.text=str(income)
	else:
		income_label_opponent.text=str(income)

func can_afford_card(card: Card, player: int = 1) -> bool:
	if not economy_manager:
		return false
	return economy_manager.get_wealth(player) >= card.card_cost

func purchase_card(card: Card, player: int = 1) -> bool:
	if not can_afford_card(card, player):
		return false

	return economy_manager.spend_wealth(player, card.card_cost)



func is_play_phase() -> bool:
	return turn_manager and turn_manager.can_play_cards()
