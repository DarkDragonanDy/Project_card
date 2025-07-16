extends Node
class_name TurnManager

# Game phases for each turn
enum GamePhase {
	DRAW_PHASE,
	MAIN_PHASE,
	END_PHASE
}



# Player management
var current_player: int = 1
var total_players: int = 2
var current_turn: int = 1
var current_phase: GamePhase = GamePhase.DRAW_PHASE

# Phase timing
var draw_phase_duration: float = 1.5
var end_phase_duration: float = 1.0
var turn_time_limit: float = 60.0  # For future online play

# Game state
var game_started: bool = false
var game_paused: bool = false

# References to other systems
@onready var hand_manager: HandManager =$"../Playable_lair/Hand_manager"
@onready var deck_manager: DeckToHandManager =$"../Playable_lair/DeckToHand_manager"

#@onready var end_turn_button: Button = $"../Control_lair/Game_UI/Right_info_display/Turn_space/End_Turn"



# Turn timer (for online play preparation)
var turn_timer: float = 0.0
var is_timer_active: bool = false

# Signals
signal game_started_signal
signal turn_started(player: int, turn: int)
signal phase_changed(new_phase: GamePhase, player: int)
signal turn_ended(player: int)
signal turn_timer_updated(time_remaining: float)
signal turn_timer_expired(player: int)


# This exists - the function that emits the signal


func _ready():
	_connect_to_systems()

func _connect_to_systems():
	#end_turn_button.pressed.connect(await advance_to_end_phase())
	
	if not hand_manager:
		print("Warning: HandManager not found in TurnManager")
	if not deck_manager:
		print("Warning: DeckToHandManager not found in TurnManager")
	
	

func _process(delta):
	if is_timer_active and not game_paused:
		turn_timer -= delta
		turn_timer_updated.emit(turn_timer)
		
		if turn_timer <= 0:
			_on_turn_timer_expired()

# Called from GameSetupCoordinator when everything is ready

	

func start_turn(player: int, turn: int):
	
	current_turn=turn
	current_player=player
	print("=== Turn ", current_turn, " - Player ", current_player, " ===")
	current_phase = GamePhase.DRAW_PHASE
	
	# Reset turn timer
	turn_timer = turn_time_limit
	is_timer_active = false  # Will activate in main phase
	
	# Notify all systems
	turn_started.emit(current_player, current_turn)
	
	# Lock hand during draw phase
	_set_hand_interaction_allowed(false)
	
	# Start with draw phase
	await _process_draw_phase()

func _process_draw_phase():
	print("Draw Phase - Player ", current_player)
	current_phase = GamePhase.DRAW_PHASE
	phase_changed.emit(current_phase, current_player)

	# Process income at start of turn (instead of drawing cards)
	var economy_manager = get_node_or_null("../Economy_manager")
	if economy_manager:
		economy_manager.process_turn_income(current_player)

	# Draw a card if possible
	if deck_manager and current_player == 1:
		var success = await deck_manager.draw_card()
		if not success:
			print("Failed to draw card - deck might be empty")

	advance_to_main_phase()

func advance_to_main_phase():
	print("Main Phase - Player ", current_player, " can play cards")
	current_phase = GamePhase.MAIN_PHASE
	phase_changed.emit(current_phase, current_player)
	
	# Allow hand interactions for current player
	if current_player == 1:  # Local player
		_set_hand_interaction_allowed(true)
		is_timer_active = true  # Start turn timer
	else:
		# For opponent (future AI/network)
		_set_hand_interaction_allowed(false)
		# TODO: Handle AI or network opponent turn

func advance_to_end_phase():
	print("End Phase - Player ", current_player)
	current_phase = GamePhase.END_PHASE
	phase_changed.emit(current_phase, current_player)
	
	# Lock hand interactions
	_set_hand_interaction_allowed(false)
	is_timer_active = false
	
	# Process end phase effects
	await _process_end_phase()

func _process_end_phase():
	# Handle end-of-turn effects
	#if play_event_manager:
		#play_event_manager.clear_turn_plays()
	
	# Check win conditions
	_check_win_conditions()
	
	# Wait for end phase duration
	await get_tree().create_timer(end_phase_duration).timeout
	
	# End the turn
	end_turn()


	


# Manual phase advancement (for player input)
func try_advance_phase():
	if not can_advance_phase():
		print("Cannot advance phase at this time")
		return false
	
	match current_phase:
		GamePhase.MAIN_PHASE:
			advance_to_end_phase()
			return true
		_:
			print("Cannot manually advance from ", current_phase)
			return false

func can_advance_phase() -> bool:
	# Players can only advance from main phase
	return (current_phase == GamePhase.MAIN_PHASE and 
			current_player == 1 and  # Only local player for now
			not game_paused)

# Hand interaction control
func _set_hand_interaction_allowed(allowed: bool):
	if hand_manager:
		hand_manager.lock_hand(not allowed)
		print("Hand interaction ", "enabled" if allowed else "disabled", " for Player ", current_player)

# Game state queries
func can_play_cards() -> bool:
	return (current_phase == GamePhase.MAIN_PHASE and 
			current_player == 1 and  # Local player
			not game_paused)

func get_current_player() -> int:
	return current_player

func get_current_turn() -> int:
	return current_turn

func get_current_phase() -> GamePhase:
	return current_phase

func get_phase_name() -> String:
	match current_phase:
		GamePhase.DRAW_PHASE:
			return "Draw"
		GamePhase.MAIN_PHASE:
			return "Main"
		GamePhase.END_PHASE:
			return "End"
		_:
			return "Unknown"

func is_local_player_turn() -> bool:
	return current_player == 1

# Timer management
func _on_turn_timer_expired():
	print("Turn timer expired for Player ", current_player)
	turn_timer_expired.emit(current_player)
	
	# Auto-advance to end phase
	if current_phase == GamePhase.MAIN_PHASE:
		advance_to_end_phase()

func extend_turn_timer(additional_seconds: float):
	turn_timer += additional_seconds
	print("Turn timer extended by ", additional_seconds, " seconds")


# Game control
func pause_game():
	game_paused = true
	is_timer_active = false
	print("Game paused")

func resume_game():
	game_paused = false
	if current_phase == GamePhase.MAIN_PHASE:
		is_timer_active = true
	print("Game resumed")

func _check_win_conditions():
	# TODO: Implement win condition checking
	# For now, just a placeholder
	pass

# Network preparation methods (for future online play)
func sync_turn_state(player: int, turn: int, phase: GamePhase):
	# For network synchronization
	current_player = player
	current_turn = turn
	current_phase = phase
	print("Turn state synced: Player ", player, ", Turn ", turn, ", Phase ", get_phase_name())

func handle_network_turn_start(player: int):
	# Handle when network opponent starts their turn
	if player != 1:  # Not local player
		current_player = player
		_set_hand_interaction_allowed(false)
		print("Network opponent (Player ", player, ") started their turn")

func handle_network_phase_change(new_phase: GamePhase, player: int):
	# Handle phase changes from network
	current_phase = new_phase
	phase_changed.emit(new_phase, player)
	
	if player == 1:  # Local player
		_set_hand_interaction_allowed(new_phase == GamePhase.MAIN_PHASE)
		
func end_turn():
	print("Turn ", current_turn, " ended for Player ", current_player)
	turn_ended.emit(current_player)  # <-- Signal is emitted here

	
	# Switch to next player
	
# Debug functions
func print_game_state():
	print("=== Turn Manager State ===")
	print("Game Started: ", game_started)
	print("Current Player: ", current_player)
	print("Current Turn: ", current_turn)
	print("Current Phase: ", get_phase_name())
	print("Can Play Cards: ", can_play_cards())
	print("Turn Timer: ", turn_timer if is_timer_active else "Inactive")
	print("Game Paused: ", game_paused)

# Input handling for testing
func _input(event):
	if not game_started:
		return
	
	# Debug controls (remove in production)
	if event.is_action_pressed("ui_accept"):  # Space
		if Input.is_action_pressed("ui_select"):  # Shift+Space
			print_game_state()
		else:
			try_advance_phase()
	
	elif event.is_action_pressed("ui_cancel"):  # Escape
		if game_paused:
			resume_game()
		else:
			pause_game()
