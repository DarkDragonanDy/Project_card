extends Node

enum CardState {
	IN_DECK,
	IN_HAND,
	DRAGGING,
	HOVERING,
	PLAYED,
	IN_GRAVEYARD
}

var current_state: CardState = CardState.IN_DECK
var previous_state: CardState = CardState.IN_DECK

signal state_changed(new_state, old_state)

func change_state(new_state_name: String):
	var new_state = _get_state_from_string(new_state_name)
	if new_state == current_state:
		return
	
	previous_state = current_state
	current_state = new_state
	
	_handle_state_transition()
	state_changed.emit(current_state, previous_state)

func _get_state_from_string(state_name: String) -> CardState:
	match state_name.to_lower():
		"in_deck": return CardState.IN_DECK
		"in_hand": return CardState.IN_HAND
		"dragging": return CardState.DRAGGING
		"hovering": return CardState.HOVERING
		"played": return CardState.PLAYED
		"in_graveyard": return CardState.IN_GRAVEYARD
		_: return current_state

func _handle_state_transition():
	var card = get_parent()
	if not card:
		return
	
	# Handle exit actions for previous state
	match previous_state:
		CardState.IN_HAND:
			_exit_hand_state()
		CardState.DRAGGING:
			_exit_dragging_state()
	
	# Handle enter actions for new state
	match current_state:
		CardState.IN_HAND:
			_enter_hand_state()
		CardState.PLAYED:
			_enter_played_state()
		CardState.IN_GRAVEYARD:
			_enter_graveyard_state()

func _exit_hand_state():
	pass

func _exit_dragging_state():
	pass

func _enter_hand_state():
	var card = get_parent()
	if card.has_node("DragHandler"):
		card.get_node("DragHandler").input_pickable = true

func _enter_played_state():
	var card = get_parent()
	if card.has_node("DragHandler"):
		card.get_node("DragHandler").input_pickable = false

func _enter_graveyard_state():
	var card = get_parent()
	card.visible = false

func get_current_state_name() -> String:
	match current_state:
		CardState.IN_DECK: return "In Deck"
		CardState.IN_HAND: return "In Hand"
		CardState.DRAGGING: return "Dragging"
		CardState.HOVERING: return "Hovering"
		CardState.PLAYED: return "Played"
		CardState.IN_GRAVEYARD: return "In Graveyard"
		_: return "Unknown"
