## @file main.gd
## @path res://main.gd
##
## @description
## Ponto de entrada da Demo XX_godot_age_2 (Godotage II / Lineage II MMO).
## Orquestra o servidor dedicado headless (física e validação autoritativa)
## e o cliente gráfico (avatar em terceira pessoa, câmera orbital e streaming).
##
## @created 2026-08-15
## @updated 2026-08-15
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)
extends Node3D

const ChunkManager = preload("res://src/infrastructure/chunk_manager.gd")
const ServerWorldManager = preload("res://src/infrastructure/server_world_manager.gd")
const QuanticNetServerAdapter = preload("res://src/adapters/quantic_net_server_adapter.gd")
const PlayerAvatar = preload("res://src/infrastructure/player_avatar.gd")

const PORT := 4242
const SECRET := "secret"
const CLUSTER := ["16_24", "16_25", "17_24", "17_25"]

var _is_server: bool = false
var _server_world: ServerWorldManager
var _server_adapter: QuanticNetServerAdapter
var _chunk_manager: ChunkManager
var _local_player: PlayerAvatar
var _remote_players: Dictionary = {}  # { peer_id: PlayerAvatar }


func _ready() -> void:
	var args = OS.get_cmdline_user_args()
	_is_server = "--server" in args

	if _is_server:
		_start_server()
	else:
		_start_client()


func _notification(what: int) -> void:
	# Encerramento limpo do socket UDP para liberar portas do sistema operacional
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		var qn = get_node_or_null("/root/QuanticNet")
		if qn and qn.has_method("disconnect_net"):
			qn.disconnect_net(true)
		get_tree().quit()


func _start_server() -> void:
	DisplayServer.window_set_title("Godotage II [SERVER - Headless]")
	print("\n=======================================================")
	print("[SERVER] Iniciando Servidor Autoritativo Godotage II...")
	print("=======================================================")

	# 1. Carrega Samplers de Terreno em RAM (Física pura, zero VRAM)
	_server_world = ServerWorldManager.new("res://assets/maps")
	add_child(_server_world)
	_server_world.load_cluster(CLUSTER)

	# 2. Inicializa o Adaptador QuanticNet
	var qn = get_node_or_null("/root/QuanticNet")
	if qn:
		_server_adapter = QuanticNetServerAdapter.new(_server_world)
		_server_adapter.setup_host(qn, PORT, SECRET)
	else:
		print("ERRO: Autoload QuanticNet nao encontrado no servidor.")


func _start_client() -> void:
	DisplayServer.window_set_title("Godotage II — Lineage II Godot Edition")
	print("\n=======================================================")
	print("[CLIENT] Iniciando Cliente Godotage II...")
	print("=======================================================")

	_setup_environment()

	# 1. Carrega o Terreno Visual e Colisão Local
	_chunk_manager = ChunkManager.new("res://assets/maps")
	add_child(_chunk_manager)
	_chunk_manager.load_cluster(CLUSTER)

	# 2. Instancia o Avatar do Jogador Local em Terceira Pessoa
	_local_player = PlayerAvatar.new()
	_local_player.name = "LocalPlayer"
	_local_player.is_local = true
	_local_player.position = Vector3(-2184.5, 30.0, 4056.9)
	add_child(_local_player)

	# 3. Conecta ao Servidor QuanticNet
	var qn = get_node_or_null("/root/QuanticNet")
	if qn:
		var use_netem = "--netem" in OS.get_cmdline_user_args()
		print("[CLIENT] Conectando ao host 127.0.0.1:%d (NetEm=%s)..." % [PORT, str(use_netem)])
		qn.join("127.0.0.1", PORT, SECRET, use_netem)

		# Encapsulamento de Rede e Bypass do SceneTree
		get_tree().set_multiplayer(qn.get_tree().get_multiplayer(qn.get_path()), self.get_path())
	else:
		print("AVISO: QuanticNet nao encontrado. Executando em modo local standalone.")


func _setup_environment() -> void:
	# Iluminação Direcional (Sol de Aden)
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, 45, 0)
	light.light_color = Color(0.98, 0.95, 0.88)
	light.light_energy = 1.2
	light.shadow_enabled = true
	add_child(light)

	# Céu e Atmosfera
	var world_env = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.53, 0.72, 0.91)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.70, 0.75)
	env.ambient_light_energy = 0.6
	world_env.environment = env
	add_child(world_env)
