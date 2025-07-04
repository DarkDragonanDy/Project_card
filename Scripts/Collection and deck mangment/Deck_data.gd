extends Node
# Singleton for managing deck data across scenes
# Add this as an autoload in Project Settings

var current_deck: Array = []
var deck_modified: bool = false

# Save/Load functions for persistent storage
#const SAVE_PATH = "user://deck_save.dat"
func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Сохраняем колоду перед выходом
		DeckData.save_deck_to_file()
		get_tree().quit()
func load_user_deck():
	var path = PlayerDatabase.get_user_deck_path()
	if path == "" or not FileAccess.file_exists(path):
		current_deck = []
		return
		
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		current_deck = file.get_var()
		file.close()
		print("Deck loaded for ", PlayerDatabase.current_user)
		
func save_deck_to_file():
	var path = PlayerDatabase.get_user_deck_path()
	if path == "":
		print("No user logged in!")
		return
		
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_var(current_deck)
		file.close()
		print("Deck saved for ", PlayerDatabase.current_user)
		
func set_deck(deck_data: Array):
	current_deck = deck_data.duplicate()
	deck_modified = true
	save_deck_to_file()

func get_deck() -> Array:
	if current_deck.is_empty():
		load_user_deck()
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





func get_deck_size() -> int:
	return current_deck.size()

# Optional: Validate deck before game starts
func is_deck_valid(min_cards: int = 30, max_cards: int = 30) -> bool:
	var size = current_deck.size()
	return size >= min_cards and size <= max_cards
