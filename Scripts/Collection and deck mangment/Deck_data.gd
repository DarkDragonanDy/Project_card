extends Node
# Singleton for managing deck data across scenes
# Add this as an autoload in Project Settings

var current_deck: Array = []
var deck_modified: bool = false

# Save/Load functions for persistent storage
const SAVE_PATH = "user://deck_save.dat"

func set_deck(deck_data: Array):
	current_deck = deck_data.duplicate()
	deck_modified = true
	save_deck_to_file()

func get_deck() -> Array:
	if current_deck.is_empty():
		load_deck_from_file()
	return current_deck.duplicate()

func add_card_to_deck(card_data: Dictionary):
	current_deck.append(card_data)
	deck_modified = true
	save_deck_to_file()

func remove_card_from_deck(index: int):
	if index >= 0 and index < current_deck.size():
		current_deck.remove_at(index)
		deck_modified = true
		save_deck_to_file()

func clear_deck():
	current_deck.clear()
	deck_modified = true
	save_deck_to_file()

func save_deck_to_file():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(current_deck)
		file.close()

func load_deck_from_file():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			current_deck = file.get_var()
			file.close()

func get_deck_size() -> int:
	return current_deck.size()

# Optional: Validate deck before game starts
func is_deck_valid(min_cards: int = 30, max_cards: int = 30) -> bool:
	var size = current_deck.size()
	return size >= min_cards and size <= max_cards
