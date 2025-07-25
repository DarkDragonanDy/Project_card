extends Node
@onready var exit_collection = $Exit/Button
@onready var deck_manager = $VSplitContainer/Deck/Deck_manager


func _ready():
	pass
# In your deck building scene (where deck manager is):
func _on_exit_requested():
	# Save deck data to singleton
	DeckData.set_deck(deck_manager.get_deck_data())
	print("dddd")
	# Check if deck is valid
	if DeckData.is_deck_valid():
		# Transition to game scene
		print("good")

	else:
		print("Deck must have between 10 and 30 cards!")
