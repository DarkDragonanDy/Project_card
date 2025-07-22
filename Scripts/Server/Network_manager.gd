# NetworkManager.gd - Autoload
extends Node

# Сигналы для связи с игровой логикой
signal game_action_received(action_data: Dictionary)
signal player_connected(player_id: String)
signal player_disconnected(player_id: String)
signal connection_established
signal connection_failed_signal
signal server_started
signal game_state_synchronized(state: Dictionary)

# Сетевые переменные
var multiplayer_peer: ENetMultiplayerPeer
var connected_clients: Dictionary = {}  # peer_id: {player_name, ready_status}
var game_state: Dictionary = {
	"current_turn": 1,
	"current_player": 1,
	"players": {},
	"board_state": {},
	"game_phase": "waiting"
}

# Состояние подключения
var is_connected: bool = false
var my_peer_id: int = 0

# Лобби
var lobby_players: Dictionary = {}  # player_name: is_ready

# Серверная логика
var server_logic: ServerGameLogic

func _ready():
	pass
	# Определяем режим работы по аргументам командной строки
	#var args = OS.get_cmdline_args()
	#if "--server" in args:
		#NetworkMode.set_mode(NetworkMode.Mode.SERVER)
		#await get_tree().create_timer(0.5).timeout
		#start_server()
	# Если не сервер - значит клиент, никаких дополнительных проверок

func start_server() -> bool:
	print("Starting server on port ", NetworkMode.server_port)
	
	# Создаем сетевой интерфейс
	multiplayer_peer = ENetMultiplayerPeer.new()
	
	# Запускаем сервер
	var error = multiplayer_peer.create_server(NetworkMode.server_port, 4)
	if error != OK:
		print("Failed to start server: ", error)
		return false
	
	# Подключаем интерфейс к системе мультиплеера
	multiplayer.multiplayer_peer = multiplayer_peer
	
	# Подписываемся на события
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	# Инициализируем игровое состояние
	#_initialize_server_game_state()
	
	# Создаем серверную логику
	
	
	print("Server started successfully")
	server_started.emit()
	return true

func connect_to_server() -> bool:
	print("Connecting to server at ", NetworkMode.server_address)
	
	multiplayer_peer = ENetMultiplayerPeer.new()
	
	# Подключаемся к серверу
	var error = multiplayer_peer.create_client(NetworkMode.server_address, NetworkMode.server_port)
	if error != OK:
		print("Failed to connect to server: ", error)
		return false
	
	multiplayer.multiplayer_peer = multiplayer_peer
	
	# Подписываемся на события клиента
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	return true

func _create_server_logic():
	"""Создает серверную игровую логику"""
	server_logic = preload("res://Scripts/Server/ServerGameLogic.gd").new()
	server_logic.name = "ServerGameLogic"
	add_child(server_logic)
	
	# Подключаем логи сервера к консоли
	if server_logic.has_signal("server_log"):
		server_logic.server_log.connect(_on_server_log)
	
	print("Server game logic created and connected")

func _on_server_log(log_message: String):
	"""Обработчик логов от ServerGameLogic"""
	# Логи уже выводятся в ServerGameLogic, можно добавить дополнительную обработку
	pass

# ============= ОТПРАВКА ДЕЙСТВИЙ =============

func send_game_action(action_type: String, data: Dictionary):
	var message = {
		"type": action_type,
		"player_id": PlayerDatabase.current_user,
		"data": data,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	if NetworkMode.is_server():
		# Сервер обрабатывает действие локально
		message["sender_peer_id"] = 1
		_process_server_action(message)
	else:
		# Клиент отправляет запрос серверу
		_request_action_from_server.rpc_id(1, message)

# ============= RPC ФУНКЦИИ =============

@rpc("any_peer", "call_remote", "reliable")
func _request_action_from_server(message: Dictionary):
	# Только сервер обрабатывает запросы
	if not NetworkMode.is_server():
		return
	
	# Добавляем информацию о отправителе
	message["sender_peer_id"] = multiplayer.get_remote_sender_id()
	
	print("Server received action request: ", message.type, " from peer ", message.sender_peer_id)
	_process_server_action(message)

@rpc("authority", "call_local", "reliable")
func _broadcast_action_result(message: Dictionary):
	# Выполняется на всех подключенных устройствах
	print("Received action result: ", message.type)
	game_action_received.emit(message)

@rpc("authority", "call_remote", "reliable")
func _send_private_data(data: Dictionary):
	"""RPC для отправки приватных данных игроку"""
	print("Client received private data: ", data.type)
	game_action_received.emit(data)

@rpc("authority", "call_remote", "reliable")
func _send_error_to_client(error_message: String):
	"""RPC для отправки ошибок клиенту"""
	print("Client received error: ", error_message)
	game_action_received.emit({
		"type": "error_message",
		"data": {"message": error_message}
	})

@rpc("any_peer", "call_remote", "reliable")
func _register_player(player_name: String):
	# Только сервер обрабатывает регистрацию
	if not NetworkMode.is_server():
		return
	
	var peer_id = multiplayer.get_remote_sender_id()
	print("Registering player: ", player_name, " with peer ID: ", peer_id)
	
	# Сохраняем информацию об игроке
	connected_clients[peer_id] = {
		"player_name": player_name,
		"ready": false,
		"connected_at": Time.get_unix_time_from_system()
	}
	
	# Уведомляем всех о новом игроке
	player_connected.emit(player_name)

# ============= ОБРАБОТКА ДЕЙСТВИЙ НА СЕРВЕРЕ =============

func _process_server_action(message: Dictionary):
	print("NetworkManager processing action: ", message.type)
	
	# Игровые действия передаем в ServerGameLogic
	if server_logic and _is_game_action(message.type):
		server_logic._process_player_request(message)
	else:
		# Системные действия обрабатываем здесь
		match message.type:
			"join_lobby":
				_handle_join_lobby(message)
			"player_ready":
				_handle_player_ready(message)
			_:
				print("Unknown action for NetworkManager: ", message.type)

func _is_game_action(action_type: String) -> bool:
	"""Определяет, является ли действие игровым"""
	var game_actions = [
		"request_start_game",
		"request_card_play", 
		"request_end_turn",
		"request_game_state"
	]
	return action_type in game_actions

func _handle_join_lobby(message: Dictionary):
	var player_name = message.data.player_name
	lobby_players[player_name] = false
	
	print("Player joined lobby: ", player_name)
	_broadcast_lobby_state()

func _handle_player_ready(message: Dictionary):
	var player_name = message.data.player_name
	var is_ready = message.data.is_ready
	
	lobby_players[player_name] = is_ready
	
	print("Player ready status: ", player_name, " = ", is_ready)
	_broadcast_lobby_state()
	
	# Проверяем, можно ли начать игру
	_check_game_start()

func _broadcast_lobby_state():
	_broadcast_action_result.rpc({
		"type": "lobby_update",
		"data": {"players": lobby_players}
	})

func _check_game_start():
	if lobby_players.size() < 2:
		return
	
	# Проверяем, все ли готовы
	for is_ready in lobby_players.values():
		if not is_ready:
			return
	
	# Все готовы - начинаем игру
	print("All players ready! Starting game...")
	_broadcast_action_result.rpc({
		"type": "game_start",
		"data": {}
	})
	_create_server_logic()

# ============= ОБРАБОТЧИКИ СОБЫТИЙ =============

func _on_peer_connected(peer_id: int):
	print("Peer connected: ", peer_id)
	# Ждем регистрации игрока через RPC

func _on_peer_disconnected(peer_id: int):
	print("Peer disconnected: ", peer_id)
	
	# Находим имя игрока по peer_id
	var player_name = ""
	if peer_id in connected_clients:
		player_name = connected_clients[peer_id].get("player_name", "")
		connected_clients.erase(peer_id)
	
	if player_name != "":
		# Удаляем из лобби
		if player_name in lobby_players:
			lobby_players.erase(player_name)
			_broadcast_lobby_state()
		
		# Уведомляем остальных
		player_disconnected.emit(player_name)

func _on_connected_to_server():
	print("Connected to server successfully")
	is_connected = true
	my_peer_id = multiplayer.get_unique_id()
	connection_established.emit()
	
	# Регистрируем себя на сервере
	_register_player.rpc_id(1, PlayerDatabase.current_user)

func _on_connection_failed():
	print("Failed to connect to server")
	is_connected = false
	connection_failed_signal.emit()

func _on_server_disconnected():
	print("Disconnected from server")
	is_connected = false

# ============= ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ =============

func _initialize_server_game_state():
	game_state = {
		"current_turn": 1,
		"current_player": 1,
		"players": {},
		"board_state": {},
		"game_phase": "waiting"
	}

func get_game_state() -> Dictionary:
	return game_state.duplicate()

func is_connected_to_server() -> bool:
	return is_connected

func get_connected_players() -> Array:
	"""Возвращает список подключенных игроков"""
	if lobby_players.is_empty():
		# Fallback - собираем из connected_clients
		var players = []
		for client_data in connected_clients.values():
			var player_name = client_data.get("player_name", "")
			if player_name != "":
				players.append(player_name)
		return players
	else:
		return lobby_players.keys()

func get_peer_id_for_player(player_name: String) -> int:
	"""Получает peer_id игрока по имени"""
	for peer_id in connected_clients.keys():
		var client_data = connected_clients[peer_id]
		if client_data.get("player_name", "") == player_name:
			return peer_id
	return 0

func disconnect_from_network():
	if multiplayer_peer:
		multiplayer_peer.close()
		multiplayer_peer = null
	
	is_connected = false
	connected_clients.clear()
	lobby_players.clear()
	my_peer_id = 0

# ============= DEBUG ФУНКЦИИ =============

func print_network_state():
	print("=== Network State ===")
	print("Network Mode: ", NetworkMode.current_mode)
	print("Has multiplayer peer: ", multiplayer.has_multiplayer_peer())
	print("Is server: ", multiplayer.is_server() if multiplayer.has_multiplayer_peer() else "N/A")
	print("My peer ID: ", my_peer_id)
	print("Is connected: ", is_connected)
	print("Connected clients: ", connected_clients.keys())
	print("Lobby players: ", lobby_players.keys())

func _input(event):
	# Debug controls
	if event.is_action_pressed("ui_home"):  # Home key
		print_network_state()
		if server_logic:
			server_logic.print_game_status()
