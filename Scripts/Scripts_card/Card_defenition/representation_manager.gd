# card_representation_manager.gd
extends Node
class_name CardRepresentationManager

static func create_collection_view(card: Card) -> TextureRect:
	# Create collection image view
	var texture_rect = TextureRect.new()
	
	# Use cached texture or generate new one
	if not card.collection_texture:
		card.collection_texture = await Card.generate_card_texture(
			card.card_name,
			card.card_description,
			card.card_cost,
			card.card_art
		)
	
	texture_rect.texture = card.collection_texture
	texture_rect.set_meta("source_card", card)
	return texture_rect

static func create_hex_view(card: Card) -> Node2D:
	var hex_container = Node2D.new()
	hex_container.name = "Hex_" + card.card_name
	
	# Just use the card art - no scene file needed!
	var icon = Sprite2D.new()
	icon.texture = card.card_art
	
	# Scale based on your hex size
	if icon.texture:
		var texture_size = icon.texture.get_size()
		# Assuming hex cells are roughly 64x64
		var target_size = 48.0  # Slightly smaller than cell
		var scale_factor = target_size / max(texture_size.x, texture_size.y)
		icon.scale = Vector2(scale_factor, scale_factor)
	
	hex_container.add_child(icon)
	
	# Store reference
	hex_container.set_meta("source_card", card)
	card.hex_representation = hex_container
	
	return hex_container
