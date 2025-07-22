# SimpleLobbyManager.gd
extends Control

# UI элементы
@onready var players_list: VBoxContainer
@onready var ready_button: Button
@onready var status_label: Label

# Состояние лобби
var players_ready: Dictionary = {}  # player_name: bool
var my_name: String = ""
var is_ready: bool = false

signal start_game

func _ready():
	_create_lobby_ui()
	my_name = PlayerDatabase.current_user
	
	# Подключаемся к сетевым событиям
	NetworkManager.game_action_received.connect(_on_lobby_action)
	
	# Регистрируемся в лобби
	_join_lobby()

func _create_lobby_ui():
	# Основной контейнер
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Фон
	var bg = ColorRect.new()
	bg.color = Color(0.2, 0.2, 0.3, 0.9)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Центральная панель
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(300, 200)
	add_child(panel)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	# Заголовок
	var title = Label.new()
	title.text = "GAME LOBBY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Статус
	status_label = Label.new()
	status_label.text = "Connecting..."
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(status_label)
	
	# Список игроков
	players_list = VBoxContainer.new()
	vbox.add_child(players_list)
	
	# Кнопка готовности
	ready_button = Button.new()
	ready_button.text = "READY"
	ready_button.pressed.connect(_on_ready_pressed)
	vbox.add_child(ready_button)

func _join_lobby():
	print("Joining lobby as: ", my_name)
	NetworkManager.send_game_action("join_lobby", {"player_name": my_name})

func _on_ready_pressed():
	is_ready = !is_ready
	ready_button.text = "NOT READY" if is_ready else "READY"
	ready_button.modulate = Color.GREEN if is_ready else Color.WHITE
	
	NetworkManager.send_game_action("player_ready", {
		"player_name": my_name,
		"is_ready": is_ready
	})

func _on_lobby_action(action_data: Dictionary):
	match action_data.type:
		"lobby_update":
			_update_lobby_display(action_data.data)
		"game_start":
			_start_game()

func _update_lobby_display(lobby_data: Dictionary):
	players_ready = lobby_data.players
	
	# Обновляем список игроков
	for child in players_list.get_children():
		child.queue_free()
	
	for player_name in players_ready.keys():
		var is_player_ready = players_ready[player_name]
		
		var player_row = HBoxContainer.new()
		players_list.add_child(player_row)
		
		var name_label = Label.new()
		name_label.text = player_name
		player_row.add_child(name_label)
		
		var ready_label = Label.new()
		ready_label.text = "READY" if is_player_ready else "NOT READY"
		ready_label.modulate = Color.GREEN if is_player_ready else Color.RED
		player_row.add_child(ready_label)
	
	# Обновляем статус
	var ready_count = 0
	for ready_status in players_ready.values():
		if ready_status:
			ready_count += 1
	
	status_label.text = "Players ready: " + str(ready_count) + "/" + str(players_ready.size())

func _start_game():
	print("Starting game!")
	start_game.emit()
	queue_free()
