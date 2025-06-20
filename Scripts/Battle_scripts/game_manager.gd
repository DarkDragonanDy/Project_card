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

var current_state: GameState = GameState.LOADING
var winner: int = 0
var current_turn: int = 1
var max_turns: int = 10

# References
var turn_manager: TurnManager
var economy_manager: EconomyManager
var business_cards_manager: BusinessCardsManager




# Signals
signal game_state_changed(new_state: GameState)
signal game_over(winner: int)

func _ready():
	_get_system_references()
	_connect_signals()

func _get_system_references():
	turn_manager = get_node_or_null("../Turn_manager")
	economy_manager = get_node_or_null("../Economy_manager")
	business_cards_manager = get_node_or_null("../Playable_lair/BusinessCards_manager")

func _connect_signals():
	if turn_manager:
		turn_manager.turn_started.connect(_on_turn_started)
		turn_manager.turn_ended.connect(_on_turn_ended)
	if economy_manager:
		economy_manager.wealth_changed.connect(_on_wealth_changed)
		
		
func start_game():
	current_state = GameState.PLAYING
	game_state_changed.emit(current_state)
	print("GameManager: Game started")
	
func _on_turn_ended(player: int):
	if current_turn >= max_turns:
		_end_game()

func _on_turn_started(player: int, turn: int):
	current_turn = turn
	if economy_manager:
		economy_manager.process_turn_income(player)

func _end_game():
	if economy_manager:
		winner = economy_manager.determine_winner()
		current_state = GameState.GAME_OVER
		game_over.emit(winner)

func can_afford_card(card: Card, player: int = 1) -> bool:
	if not economy_manager:
		return false
	return economy_manager.get_wealth(player) >= card.card_cost

func purchase_card(card: Card, player: int = 1) -> bool:
	if not can_afford_card(card, player):
		return false

	return economy_manager.spend_wealth(player, card.card_cost)

func _on_wealth_changed(player: int, new_wealth: int):
	print("Player ", player, " wealth: $", new_wealth)

func is_play_phase() -> bool:
	return turn_manager and turn_manager.can_play_cards()
