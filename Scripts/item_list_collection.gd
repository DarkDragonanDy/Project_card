extends ItemList
  # or whatever your scene extends

@onready var item_list: ItemList =$"."  # Reference to your ItemList node
# Reference to your ItemList


# Array to store your created objects


func _ready():
	# Set ItemList to custom mode
	item_list.set_icon_mode(ItemList.ICON_MODE_TOP)
	item_list.set_fixed_icon_size(Vector2(63.5, 88.9))  # Card size

	populate_with_card_scenes()

func populate_with_card_scenes():
	for card_name in CardDatabase.card_database.keys():
		var card_instance = CardDatabase.create_card_instance(card_name)
		var texture = await CardDatabase.art_capture(card_name)
		item_list.add_item(card_instance.card_name)
		item_list.set_item_icon(item_list.get_item_count() - 1, texture)
