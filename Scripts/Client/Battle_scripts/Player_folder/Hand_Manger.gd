extends Node2D
class_name HandManager

# Конфигурация визуализации
const MAX_HAND_SIZE: int = 7
const CARD_SPACING: float = 80.0
const HAND_ARC_RADIUS: float = 800.0
const HAND_Y_OFFSET: float = 40.0
const DRAW_ANIMATION_DURATION: float = 0.3

# Локальное состояние для визуализации
var cards_in_hand: Array[Card] = []
var hand_positions: Array[Vector2] = []
var is_hand_locked: bool = false

# Визуальные параметры
var screen_size: Vector2
var hand_center: Vector2

signal card_selected(card: Card)
signal card_play_requested(card: Card, hex_position: Vector2i)

func _ready():
	if NetworkMode.is_server():
		queue_free()
		return
	
	screen_size = get_viewport().get_visible_rect().size
	hand_center = Vector2(screen_size.x / 2, screen_size.y - HAND_Y_OFFSET)
	
	# Слушаем команды от сервера
	NetworkManager.game_action_received.connect(_on_server_command)

func _on_server_command(command: Dictionary):
	match command.type:
		"card_drawn":
			_handle_card_drawn(command.data)
		"card_removed_from_hand":
			_handle_card_removed(command.data)
		"hand_locked":
			lock_hand(command.data.locked)

func _handle_card_drawn(data: Dictionary):
	var card_name = data.card_name
	
	# Создаем визуальную карту
	var card_instance = CardDatabase.create_card_instance(card_name)
	if not card_instance:
		return
	
	# Добавляем в сцену
	get_tree().current_scene.add_child(card_instance)
	
	# Настраиваем карту для руки
	_setup_card_for_hand(card_instance)
	
	# Добавляем в массив
	cards_in_hand.append(card_instance)
	
	# Пересчитываем позиции
	_calculate_hand_positions()
	
	# Анимируем появление
	_animate_card_draw(card_instance)
	_animate_hand_layout()
	
func add_card_to_hand(card: Card) -> bool:
	if cards_in_hand.size() >= MAX_HAND_SIZE:
		
		return false
	
	if not card:
		print("Error: Attempted to add null card to hand")
		return false
	
	# Add card to hand array
	cards_in_hand.append(card)
	
	# Set up card for hand
	_setup_card_for_hand(card)
	
	# Calculate new positions for all cards
	_calculate_hand_positions()
	
	# Animate card into position
	_animate_card_draw(card)
	_animate_hand_layout()
	
	
	print("Card added to hand: ", card.card_name, " (", cards_in_hand.size(), "/", MAX_HAND_SIZE, ")")
	
	return true

func _handle_card_removed(data: Dictionary):
	var card_name = data.card_name
	
	# Находим карту по имени
	var card_to_remove: Card = null
	for card in cards_in_hand:
		if card.card_name == card_name:
			card_to_remove = card
			break
	
	if not card_to_remove:
		return
	
	# Удаляем из массива
	cards_in_hand.erase(card_to_remove)
	
	# Отключаем сигналы
	_disconnect_card_signals(card_to_remove)
	
	# Пересчитываем позиции
	_calculate_hand_positions()
	_animate_hand_layout()

func _setup_card_for_hand(card: Card):
	# Подключаем сигналы для интерактивности
	if not card.card_played.is_connected(_on_card_played):
		card.card_played.connect(_on_card_played)
	if not card.card_selected.is_connected(_on_card_selected):
		card.card_selected.connect(_on_card_selected)
	
	# Настраиваем drag handler
	if card.drag_handler:
		card.drag_handler.set_hand_reference(self)
	
	# Устанавливаем состояние
	if card.state_manager:
		card.state_manager.change_state("in_hand")

func _disconnect_card_signals(card: Card):
	if card.card_played.is_connected(_on_card_played):
		card.card_played.disconnect(_on_card_played)
	if card.card_selected.is_connected(_on_card_selected):
		card.card_selected.disconnect(_on_card_selected)

func _on_card_played(card: Card, hex_position: Vector2i):
	# Отправляем запрос на сервер через CardPlayManager
	var play_manager = get_node_or_null("/root/Battle_scene/card_play_manager")
	if play_manager:
		play_manager.request_card_play(card, hex_position)

func _on_card_selected(card: Card):
	# Локальная визуализация выбора
	_bring_card_to_front(card)
	card_selected.emit(card)

func _bring_card_to_front(card: Card):
	var highest_z = 0
	for hand_card in cards_in_hand:
		if hand_card.z_index > highest_z:
			highest_z = hand_card.z_index
	card.z_index = highest_z + 1

func lock_hand(locked: bool):
	is_hand_locked = locked
	for card in cards_in_hand:
		if card.drag_handler:
			card.drag_handler.set_draggable(not locked)

# Визуальные функции (без изменений)
func _calculate_hand_positions():
	hand_positions.clear()
	
	if cards_in_hand.is_empty():
		return
	
	var card_count = cards_in_hand.size()
	
	if card_count == 1:
		hand_positions.append(hand_center)
		return
	
	var total_width = (card_count - 1) * CARD_SPACING
	var start_angle = -atan2(total_width / 2, HAND_ARC_RADIUS)
	var end_angle = atan2(total_width / 2, HAND_ARC_RADIUS)
	var angle_step = (end_angle - start_angle) / (card_count - 1)
	
	for i in range(card_count):
		var angle = start_angle + (angle_step * i)
		var x = hand_center.x + sin(angle) * HAND_ARC_RADIUS
		var y = hand_center.y - cos(angle) * HAND_ARC_RADIUS + HAND_ARC_RADIUS
		
		x = clampf(x, 80, screen_size.x - 80)
		y = clampf(y, screen_size.y - 200, screen_size.y - 50)
		
		hand_positions.append(Vector2(x, y))

func _animate_card_draw(card: Card):
	var target_index = cards_in_hand.find(card)
	if target_index == -1 or target_index >= hand_positions.size():
		return
	
	var target_position = hand_positions[target_index]
	
	# Стартовая позиция сверху
	card.global_position = Vector2(target_position.x, -100)
	card.scale = Vector2(0.5, 0.5)
	card.rotation = 0
	
	# Анимация появления
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(card, "global_position", target_position, DRAW_ANIMATION_DURATION)
	tween.tween_property(card, "scale", Vector2(1.0, 1.0), DRAW_ANIMATION_DURATION)
	
	var rotation_offset = (target_index - float(cards_in_hand.size() - 1) / 2) * 0.1
	tween.tween_property(card, "rotation", rotation_offset, DRAW_ANIMATION_DURATION)
	
	card.z_index = target_index

func _animate_hand_layout():
	for i in range(cards_in_hand.size()):
		var card = cards_in_hand[i]
		if i < hand_positions.size():
			var target_position = hand_positions[i]
			var rotation_offset = (i - float(cards_in_hand.size() - 1) / 2) * 0.1
			
			var tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(card, "global_position", target_position, 0.3)
			tween.tween_property(card, "rotation", rotation_offset, 0.3)
			card.z_index = i

func get_card_hand_position(card: Card) -> Vector2:
	var index = cards_in_hand.find(card)
	if index != -1 and index < hand_positions.size():
		return hand_positions[index]
	return Vector2.ZERO

func get_card_hand_index(card: Card) -> int:
	return cards_in_hand.find(card)

func get_hand_size() -> int:
	return cards_in_hand.size()

func is_hand_full() -> bool:
	return cards_in_hand.size() >= MAX_HAND_SIZE






















#extends Node2D
#class_name HandManager
#
## Hand configuration
#const MAX_HAND_SIZE: int = 7
#const CARD_SPACING: float = 80.0
#const HAND_ARC_RADIUS: float = 800.0
#const HAND_Y_OFFSET: float = 40.0
#const DRAW_ANIMATION_DURATION: float = 0.1
#
## Hand state
#var cards_in_hand: Array[Card] = []
#var hand_positions: Array[Vector2] = []
#var is_hand_locked: bool = false
#
## Screen dimensions
#var screen_size: Vector2
#var hand_center: Vector2
#
## Signals
#signal card_drawn(card: Card)
#signal card_played(card: Card, hex_position: Vector2i)
#signal hand_full
#signal hand_empty
#
#@onready var play_manager: CardPlayManager = get_node_or_null("../../card_play_manager")
#func _ready():
	#screen_size = get_viewport().get_visible_rect().size
	#hand_center = Vector2(screen_size.x / 2, screen_size.y - HAND_Y_OFFSET)
	#
	## Connect to deck manager
	#var deck_manager = get_node_or_null("../DeckToHand_manager")
	#if deck_manager:
		#deck_manager.card_ready_for_hand.connect(_on_card_ready_for_hand)
#
#func _on_card_ready_for_hand(card: Card):
	#add_card_to_hand(card)
#
#func add_card_to_hand(card: Card) -> bool:
	#if cards_in_hand.size() >= MAX_HAND_SIZE:
		#hand_full.emit()
		#return false
	#
	#if not card:
		#print("Error: Attempted to add null card to hand")
		#return false
	#
	## Add card to hand array
	#cards_in_hand.append(card)
	#
	## Set up card for hand
	#_setup_card_for_hand(card)
	#
	## Calculate new positions for all cards
	#_calculate_hand_positions()
	#
	## Animate card into position
	#_animate_card_to_hand(card)
	#_animate_hand_layout()
	#
	#card_drawn.emit(card)
	#print("Card added to hand: ", card.card_name, " (", cards_in_hand.size(), "/", MAX_HAND_SIZE, ")")
	#
	#return true
#
#func _setup_card_for_hand(card: Card):
	## Connect card signals
	#if not card.card_played.is_connected(_on_card_played):
		#card.card_played.connect(_on_card_played)
	#if not card.card_selected.is_connected(_on_card_selected):
		#card.card_selected.connect(_on_card_selected)
	#if not card.card_deselected.is_connected(_on_card_deselected):
		#card.card_deselected.connect(_on_card_deselected)
	#
	## Set initial state
	#if card.state_manager:
		#card.state_manager.change_state("in_hand")
	#
	## Configure drag handler
	#if card.drag_handler:
		#card.drag_handler.set_hand_reference(self)
#
#func remove_card_from_hand(card: Card):
	#var index = cards_in_hand.find(card)
	#if index == -1:
		#print("Warning: Attempted to remove card not in hand")
		#return
	#
	#cards_in_hand.remove_at(index)
	#
	## Disconnect signals
	#if card.card_played.is_connected(_on_card_played):
		#card.card_played.disconnect(_on_card_played)
	#if card.card_selected.is_connected(_on_card_selected):
		#card.card_selected.disconnect(_on_card_selected)
	#if card.card_deselected.is_connected(_on_card_deselected):
		#card.card_deselected.disconnect(_on_card_deselected)
	#
	## Recalculate positions for remaining cards
	#_calculate_hand_positions()
	#_animate_hand_layout()
	#
	#if cards_in_hand.is_empty():
		#hand_empty.emit()
	#
	#print("Card removed from hand: ", card.card_name, " (", cards_in_hand.size(), "/", MAX_HAND_SIZE, ")")
#
#func _calculate_hand_positions():
	#hand_positions.clear()
	#
	#if cards_in_hand.is_empty():
		#return
	#
	#var card_count = cards_in_hand.size()
	#
	#if card_count == 1:
		## Single card in center
		#hand_positions.append(hand_center)
		#return
	#
	## Calculate arc positions
	#var total_width = (card_count - 1) * CARD_SPACING
	#var start_angle = -atan2(total_width / 2, HAND_ARC_RADIUS)
	#var end_angle = atan2(total_width / 2, HAND_ARC_RADIUS)
	#var angle_step = (end_angle - start_angle) / (card_count - 1) if card_count > 1 else 0
	#
	#for i in range(card_count):
		#var angle = start_angle + (angle_step * i)
		#var x = hand_center.x + sin(angle) * HAND_ARC_RADIUS
		#var y = hand_center.y - cos(angle) * HAND_ARC_RADIUS + HAND_ARC_RADIUS
		#
		## Clamp to screen bounds
		#x = clampf(x, 80, screen_size.x - 80)
		#y = clampf(y, screen_size.y - 200, screen_size.y - 50)
		#
		#hand_positions.append(Vector2(x, y))
#
#func _animate_card_to_hand(card: Card):
	#if not card:
		#return
	#
	#var target_index = cards_in_hand.find(card)
	#if target_index == -1 or target_index >= hand_positions.size():
		#return
	#
	#var target_position = hand_positions[target_index]
	#
	## Start from above screen
	#card.global_position = Vector2(target_position.x, -100)
	#card.scale = Vector2(0.5, 0.5)
	#card.rotation = 0
	#
	## Animate to position
	#var tween = create_tween()
	#tween.set_parallel(true)
	#tween.tween_property(card, "global_position", target_position, DRAW_ANIMATION_DURATION)
	#tween.tween_property(card, "scale", Vector2(1.0, 1.0), DRAW_ANIMATION_DURATION)
	#
	## Add slight rotation for arc effect
	#var rotation_offset = (target_index - float(cards_in_hand.size() - 1) / 2) * 0.1
	#tween.tween_property(card, "rotation", rotation_offset, DRAW_ANIMATION_DURATION)
	#
	## Set z-index for layering
	#card.z_index = target_index
#
#func _animate_hand_layout():
	#
	#
	#for i in range(cards_in_hand.size()):
		#var card = cards_in_hand[i]
		#if i < hand_positions.size():
			#var target_position = hand_positions[i]
			#var rotation_offset = (i - float(cards_in_hand.size() - 1) / 2) * 0.1
			#
			#var tween = create_tween()
			#tween.set_parallel(true)
			#tween.tween_property(card, "global_position", target_position, 0.3)
			#tween.tween_property(card, "rotation", rotation_offset, 0.3)
			#card.z_index = i
#
#func get_card_hand_position(card: Card) -> Vector2:
	#var index = cards_in_hand.find(card)
	#if index != -1 and index < hand_positions.size():
		#return hand_positions[index]
	#return Vector2.ZERO
#
#func get_card_hand_index(card: Card) -> int:
	#return cards_in_hand.find(card)
#
#######################
#func lock_hand(locked: bool):
	#is_hand_locked = locked
	#for card in cards_in_hand:
		#if card.drag_handler:
			#card.drag_handler.set_draggable(not locked)
#
#func highlight_playable_cards(available_mana: int):
	#for card in cards_in_hand:
		#var can_play = card.card_cost <= available_mana
		#_set_card_highlight(card, can_play)
#
#func _set_card_highlight(card: Card, highlighted: bool):
	#if highlighted:
		#card.modulate = Color.WHITE
	#else:
		#card.modulate = Color(0.7, 0.7, 0.7, 1.0)
#
#
#
#func _on_card_played(card: Card, hex_position: Vector2i):
	## Try to play on hex through play manager
	#if play_manager and play_manager.play_card(card, hex_position):
		#remove_card_from_hand(card)
		#card_played.emit(card, hex_position)
	#else:
		## Return to hand if play failed
		#print("Failed to play card on hex")
###########################################
#
#
#####################################
#func _on_card_selected(card: Card):
	## Bring selected card to front
	#var highest_z = 0
	#for hand_card in cards_in_hand:
		#if hand_card.z_index > highest_z:
			#highest_z = hand_card.z_index
	#card.z_index = highest_z + 1
	#
	## Optional: Show card preview
	#_show_card_preview(card)
#
#func _on_card_deselected(card: Card):
	## Return to normal z-index
	#var index = cards_in_hand.find(card)
	#if index != -1:
		#card.z_index = index
	#
	#_hide_card_preview()
#
#func _show_card_preview(card: Card):
	## Implement card preview/zoom functionality
	#pass
#
#func _hide_card_preview():
	## Hide card preview
	#pass
#
###########################################
#func get_hand_size() -> int:
	#return cards_in_hand.size()
#
#func get_cards_in_hand() -> Array[Card]:
	#return cards_in_hand.duplicate()
#
#func is_hand_full() -> bool:
	#return cards_in_hand.size() >= MAX_HAND_SIZE
#
#func clear_hand():
	#for card in cards_in_hand.duplicate():
		#remove_card_from_hand(card)
		#card.queue_free()
#
## Debug function
#func print_hand_state():
	#print("=== Hand State ===")
	#print("Cards in hand: ", cards_in_hand.size(), "/", MAX_HAND_SIZE)
	#for i in range(cards_in_hand.size()):
		#var card = cards_in_hand[i]
		#print("  [", i, "] ", card.card_name, " at ", card.global_position)
