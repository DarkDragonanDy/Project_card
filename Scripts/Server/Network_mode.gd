# NetworkMode.gd - Autoload (упрощенная версия)
extends Node

enum Mode {
	CLIENT,      # Игрок
	SERVER       # Сервер
}

var current_mode: Mode = Mode.CLIENT  # По умолчанию клиент
var server_port: int = 8080
var server_address: String = "127.0.0.1"

func _ready():
	var args = OS.get_cmdline_args()
	
	if "--server" in args:
		current_mode = Mode.SERVER
		var success = await NetworkManager.start_server()
		
		print("Starting as SERVER")
	else:
		current_mode = Mode.CLIENT
		print("Starting as CLIENT")

func set_mode(mode: Mode):
	current_mode = mode
	print("Network mode set to: ", Mode.keys()[mode])

func is_server() -> bool:
	return current_mode == Mode.SERVER

func is_client() -> bool:
	return current_mode == Mode.CLIENT
