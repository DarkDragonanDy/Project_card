extends Node
# Deck management script
# Attach this to a Node child of your Deck container

@onready var deck_list: ItemList = $"../Deck_list"
@onready var collection_list: ItemList = get_node("../../Collection/Collection_list")

# Deck configuration
var max_cards: int = 30  # Maximum cards allowed in deck
var current_card_count: int = 0

# Visual feedback
var is_hovering: bool = false


const SAVE_PATH = "user://deck_save.dat"
var deck_data: Array = []

func valid_deck():
	if (current_card_count==max_cards):
		return true
	else:
		return false
		
func _ready():
	# Configure deck list for horizontal layout
	deck_list.max_columns = 0  # 0 means unlimited columns (horizontal layout)
	deck_list.same_column_width = true
	deck_list.fixed_icon_size = Vector2(63.5, 88.9)  # Adjust this to match 1/10th of your card size
	deck_list.icon_mode = ItemList.ICON_MODE_TOP
	
	# Connect deck events
	deck_list.mouse_entered.connect(_on_deck_mouse_entered)
	deck_list.mouse_exited.connect(_on_deck_mouse_exited)
	deck_list.item_selected.connect(_on_item_selected)
	
	# Optional: Set item selection mode
	deck_list.select_mode = ItemList.SELECT_SINGLE
	if collection_list.has_signal("collection_loaded"):
		collection_list.collection_loaded.connect(_on_collection_loaded)
	
	
func _on_collection_loaded():
	load_deck()
	
func add_card(collection_index: int):
	# Check if deck is full
	if current_card_count >= max_cards:
		print("Deck is full! Maximum cards: ", max_cards)
		return false
	
	# Create a scaled version of the icon
	
	var image = collection_list.get_item_icon(collection_index)
	var card_name = collection_list.get_item_text(collection_index)

	
	
	deck_data.append({
		"name": card_name,
		"collection_index": collection_index
	})
	# Add the card
	deck_list.add_item(card_name, image)
	current_card_count += 1
	
	# Optional: Show count in deck name or somewhere else
	_update_deck_display()
	print("Selected card: ", card_name )
	save_deck()
	return true

func remove_card(index: int):
	if index >= 0 and index < deck_list.get_item_count():
		deck_list.remove_item(index)
		deck_data.remove_at(index)
		current_card_count -= 1
		_update_deck_display()
		save_deck()

func _on_item_selected(index: int):
	# Handle card selection in deck (e.g., for removal or inspection)
	print("Selected card: ", deck_list.get_item_text(index))
	remove_card(index)
	
func clear_deck():
	deck_list.clear()
	deck_data.clear()
	current_card_count = 0
	_update_deck_display()
	save_deck()
	
func save_deck():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(deck_data)
		file.close()
		print("Deck saved successfully")

func load_deck():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			deck_data = file.get_var()
			file.close()
			
			# Rebuild deck list from saved data
			deck_list.clear()
			current_card_count = 0
			
			for card in deck_data:
				# Try to load the icon
				var icon = null
				
				icon = collection_list.get_item_icon(card["collection_index"])
				
				
				
				deck_list.add_item(collection_list.get_item_text(card["collection_index"]), icon)
				
				
				current_card_count += 1
			
			_update_deck_display()
			print("Deck loaded successfully")

# Get deck data for transferring to game scene
func get_deck_data() -> Array:
	return deck_data.duplicate()

# Load deck from provided data (useful when coming back from game)
func set_deck_data(data: Array):
	deck_data = data
	save_deck()
	load_deck()
	
func _on_deck_mouse_entered():
	is_hovering = true
	# Visual feedback when hovering
	deck_list.modulate = Color(1.1, 1.1, 1.1)

func _on_deck_mouse_exited():
	is_hovering = false
	# Reset visual feedback
	deck_list.modulate = Color.WHITE

func _update_deck_display():
	# Update any UI elements that show deck status
	# For example, you could update a label showing card count
	print("Deck size: ", current_card_count, "/", max_cards)
	
	# If you have a label node for deck count, update it here:
	# var deck_label = get_node_or_null("../DeckLabel")
	# if deck_label:
	#     deck_label.text = "Deck: %d/%d" % [current_card_count, max_cards]
	
func _exit_tree():
	save_deck()
