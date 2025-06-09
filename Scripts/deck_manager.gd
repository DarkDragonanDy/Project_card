extends Node
# Deck management script
# Attach this to a Node child of your Deck container

@onready var deck_list: ItemList = $"../Deck_list"

# Deck configuration
var max_cards: int = 30  # Maximum cards allowed in deck
var current_card_count: int = 0

# Visual feedback
var is_hovering: bool = false

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

func add_card(card_name: String, card_icon: Texture2D):
	# Check if deck is full
	if current_card_count >= max_cards:
		print("Deck is full! Maximum cards: ", max_cards)
		return false
	
	# Create a scaled version of the icon
	var scaled_icon = ImageTexture.new()
	var image = card_icon.get_image()
	image.resize(image.get_width() / 10, image.get_height() / 10, Image.INTERPOLATE_BILINEAR)
	scaled_icon.set_image(image)
	
	# Add the card
	deck_list.add_item(card_name, scaled_icon)
	current_card_count += 1
	
	# Optional: Show count in deck name or somewhere else
	_update_deck_display()
	
	return true

func remove_card(index: int):
	if index >= 0 and index < deck_list.get_item_count():
		deck_list.remove_item(index)
		current_card_count -= 1
		_update_deck_display()

func _on_item_selected(index: int):
	# Handle card selection in deck (e.g., for removal or inspection)
	print("Selected card: ", deck_list.get_item_text(index))

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
