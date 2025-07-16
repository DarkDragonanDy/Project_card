extends Node2D

class_name GameSetupCoordinator

# This script coordinates the initialization of all game systems
# Attach this to your main game scene


# References to game systems
@onready var deck_to_hand_manager: DeckToHandManager = $Playable_lair/DeckToHand_manager
@onready var hand_manager: HandManager = $Playable_lair/Hand_manager
@onready var game_manager: Node = $Game_manager
@onready var turn_manager: TurnManager = $Turn_manager
@onready var card_play_manager: CardPlayManager = $"card_play_manager"

# Setup state
var is_setup_complete: bool = false
var setup_steps_completed: int = 0
var total_setup_steps: int = 5


# Signals
signal setup_complete
signal setup_step_completed(step_name: String)
signal game_ready_to_start


func _ready():
	print("=== Game Setup Starting ===")
	_initialize_game_systems()

func _initialize_game_systems():
	# Step 1: Validate deck data
	_validate_deck_data()
	
	# Step 2: Connect system signals
	_connect_system_signals()
	
	setup_complete.emit()
	
	
	
	
	
	#_complete_setup()
	
	game_ready_to_start.emit()
	
	

func _validate_deck_data():
	var deck_data = DeckData.get_deck()
	
	if deck_data.is_empty():
		print("Error: No deck data found!")
		_show_error_message("No deck found. Please build a deck first.")
		return
	
	if not DeckData.is_deck_valid():
		print("Error: Invalid deck composition!")
		_show_error_message("Invalid deck. Please check your deck composition.")
		return
	
	print("✓ Deck validation passed (", deck_data.size(), " cards)")
	_complete_setup_step("Deck Validation")

func _connect_system_signals():
	# Connect deck-to-hand signals
	if deck_to_hand_manager:
		if deck_to_hand_manager.has_signal("deck_loaded"):
			deck_to_hand_manager.deck_loaded.connect(_on_deck_loaded)
		if deck_to_hand_manager.has_signal("deck_empty"):
			deck_to_hand_manager.deck_empty.connect(_on_deck_empty)
	
	# Connect hand manager signals
	if hand_manager:
		if hand_manager.has_signal("card_drawn"):
			hand_manager.card_drawn.connect(_on_card_drawn)
		#if hand_manager.has_signal("card_played"):
			#hand_manager.card_played.connect(_on_card_played)
		if hand_manager.has_signal("hand_full"):
			hand_manager.hand_full.connect(_on_hand_full)
			
	if turn_manager:
		turn_manager.turn_started.connect(_on_turn_started)
		turn_manager.phase_changed.connect(_on_phase_changed)
		turn_manager.turn_ended.connect(_on_turn_ended)
	if game_manager:
		game_manager.game_started_signal.connect(_on_game_started)
	
	print("✓ System signals connected")
	_complete_setup_step("Signal Connection")


func _wait_for_deck_initialization():
	# Wait for deck to load and starting hand to be drawn
	print("Waiting for deck initialization...")
	
	# Wait a frame to ensure all managers are ready
	await get_tree().process_frame
	
	# Wait for starting hand to be drawn
	var max_wait_time = 10.0  # Maximum time to wait
	var wait_time = 0.0
	var check_interval = 0.1
	
	while wait_time < max_wait_time:
		if hand_manager and hand_manager.get_hand_size() >= DeckToHandManager.STARTING_HAND_SIZE:
			break
		
		await get_tree().create_timer(check_interval).timeout
		wait_time += check_interval
	
	if wait_time >= max_wait_time:
		print("Warning: Deck initialization took longer than expected")
	else:
		print("✓ Starting hand drawn successfully")
	
	_complete_setup_step("Deck Initialization")




func _complete_setup():
	
	# Final system checks
	is_setup_complete=_perform_final_checks()
	
	print("=== Game Setup Complete ===")
	print("Hand size: ", hand_manager.get_hand_size() if hand_manager else "N/A")
	print("Deck size: ", deck_to_hand_manager.get_deck_size() if deck_to_hand_manager else "N/A")
	
	setup_complete.emit()

func _perform_final_checks():
	var issues = []
	
	# Check hand manager
	if not hand_manager:
		issues.append("HandManager missing")
	elif hand_manager.get_hand_size() == 0:
		issues.append("Hand is empty")
	
	# Check deck manager
	if not deck_to_hand_manager:
		issues.append("DeckToHandManager missing")
	
	# Check game manager
	if not game_manager:
		issues.append("GameManager missing")
	
	if not turn_manager:
		issues.append("TurnManager missing")
	
	if issues.is_empty():
		print("✓ All systems operational")
		return true
	else:
		print("⚠ Issues detected: ", issues)

func _complete_setup_step(step_name: String):
	setup_steps_completed += 1
	print("Setup step completed (", setup_steps_completed, "/", total_setup_steps, "): ", step_name)
	setup_step_completed.emit(step_name)

func _show_error_message(message: String):
	print("SETUP ERROR: ", message)
	# Here you could show a popup or error dialog
	# For now, just print to console

# Signal handlers
func _on_game_started():
	print("🎮 GAME STARTED!")
	
	# Update UI to show it's game time
	# Enable/disable appropriate controls

func _on_turn_started(player: int, turn: int):
	print("🔄 Turn ", turn, " started for Player ", player)
	
	# Update UI to show current player and turn
	# Could show turn indicator, highlight active player, etc.

func _on_phase_changed(new_phase: TurnManager.GamePhase, player: int):
	var phase_name = ""
	match new_phase:
		TurnManager.GamePhase.DRAW_PHASE:
			phase_name = "Draw"
		TurnManager.GamePhase.MAIN_PHASE:
			phase_name = "Main"
		TurnManager.GamePhase.END_PHASE:
			phase_name = "End"
	
	print("📋 Phase changed to ", phase_name, " for Player ", player)
	
	# Update UI to show current phase
	# Enable/disable appropriate game actions

func _on_turn_ended(player: int):
	print("⏹ Turn ended for Player ", player)

# Existing signal handlers
func _on_deck_loaded():
	print("Deck loaded successfully")

func _on_deck_empty():
	print("Deck is now empty!")

func _on_card_drawn(card: Card):
	print("Card drawn: ", card.card_name)
	
	# Set up card with proper references
	if hand_manager:
		card.set_hand_manager(hand_manager)

func _on_card_played(card: Card, hex_position: Vector2i):
	print("Card played: ", card.card_name, " at position: ", hex_position)
	
	# The play event manager will handle the actual play logic

func _on_card_play_executed(play_event):
	print("Card play executed: ", play_event.card.card_name)
	
	# Could trigger UI updates, sound effects, etc.

func _on_hand_full():
	print("Hand is full - cannot draw more cards")

# Public methods
func is_game_ready() -> bool:
	return is_setup_complete

func get_setup_progress() -> float:
	return float(setup_steps_completed) / float(total_setup_steps)

# Input handling for testing
func _input(event):
	if not is_setup_complete:
		return
	
	# Debug controls
	if event.is_action_pressed("ui_home"):  # Home key
		print_game_state()

func print_game_state():
	print("=== Game Setup State ===")
	print("Setup complete: ", is_setup_complete)
	print("Setup progress: ", get_setup_progress() * 100, "%")
	
	if turn_manager:
		
		turn_manager.print_game_state()
	
	if hand_manager:
	
		hand_manager.print_hand_state()
	
	if deck_to_hand_manager:
		deck_to_hand_manager.print_deck_state()
