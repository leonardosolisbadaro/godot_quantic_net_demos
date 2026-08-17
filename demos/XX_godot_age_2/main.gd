## @file main.gd
## @path res://main.gd
##
## @description
## Ponto de entrada da Demo XX_godot_age_2 (Godotage II / Lineage II MMO).
## Orquestra o servidor dedicado headless (física e validação autoritativa),
## o cliente gráfico (avatar, câmera orbital, streaming contínuo) e a UI de Depuração.
##
## @created 2026-08-15
## @updated 2026-08-16
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)
extends Node3D

const ChunkManager = preload("src/infrastructure/chunk_manager.gd")
const ServerWorldManager = preload("src/infrastructure/server_world_manager.gd")
const QuanticNetServerAdapter = preload("src/adapters/quantic_net_server_adapter.gd")
const PlayerAvatar = preload("src/infrastructure/player_avatar.gd")
const DebugHUD = preload("src/infrastructure/debug_hud.gd")

const PORT := 4242
const SECRET := "secret"
const CLUSTER := ["16_24", "16_25", "17_24", "17_25"]

# Ponto de Spawn suave na junção dos 4 chunks de Talking Island (estrada da falésia)
const SPAWN_X := -14979.0
const SPAWN_Z := 34952.0

var _is_server: bool = false
var _server_world: ServerWorldManager
var _server_adapter: QuanticNetServerAdapter
var _chunk_manager: ChunkManager
var _local_player: PlayerAvatar
var _debug_hud: DebugHUD
var _remote_players: Dictionary = { } # { peer_id: PlayerAvatar }


func _ready() -> void:
	var args = OS.get_cmdline_user_args()
	_is_server = "--server" in args

	if _is_server:
		_start_server()
	else:
		_start_client()


func _process(_delta: float) -> void:
	if _is_server or not _local_player or not _debug_hud or not _server_world:
		return

	# Atualiza contexto do chunk ativo na UI de Depuração
	var c_name = _server_world.get_chunk_name_at(_local_player.position.x, _local_player.position.z)
	if not c_name.is_empty():
		var sampler = _server_world.find_sampler_at(
			_local_player.position.x,
			_local_player.position.z,
		)
		if sampler:
			_debug_hud.update_chunk_context(c_name, sampler.world_origin)


func _unhandled_input(event: InputEvent) -> void:
	if _is_server:
		return

	# Tecla F2: Alterna Modo de Depuração de Wireframe da Engine (Colisão/Geometria)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F2:
			var vp = get_viewport()
			if vp:
				if vp.debug_draw == Viewport.DEBUG_DRAW_DISABLED:
					vp.debug_draw = Viewport.DEBUG_DRAW_WIREFRAME
					print("[DEBUG] Viewport Wireframe: ATIVADO")
				elif vp.debug_draw == Viewport.DEBUG_DRAW_WIREFRAME:
					vp.debug_draw = Viewport.DEBUG_DRAW_OVERDRAW
					print("[DEBUG] Viewport Overdraw: ATIVADO")
				else:
					vp.debug_draw = Viewport.DEBUG_DRAW_DISABLED
					print("[DEBUG] Viewport Debug: DESATIVADO")
		elif event.keycode == KEY_F3:
			if _debug_hud:
				_debug_hud.toggle_visibility()
				print("[DEBUG] HUD Visibilidade: ", "LIGADA" if _debug_hud.visible else "OCULTA")


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

	# 2. Obtém a altitude exata do terreno no ponto de spawn a partir do sampler
	_server_world = ServerWorldManager.new("res://assets/maps")
	add_child(_server_world)
	_server_world.load_cluster(CLUSTER)

	var ground_y = _server_world.get_height_at(SPAWN_X, SPAWN_Z)
	var min_world_y = _server_world.get_min_world_altitude()

	# 3. Instancia o Avatar do Jogador Local exatamente rente ao solo (Zero-Drop Spawn)
	_local_player = PlayerAvatar.new()
	_local_player.name = "LocalPlayer"
	_local_player.is_local = true
	_local_player.safe_spawn_position = Vector3(SPAWN_X, ground_y, SPAWN_Z)
	_local_player.min_fall_limit_y = min_world_y - 50.0 # 50m abaixo do ponto mais profundo do cluster
	_local_player.position = Vector3(SPAWN_X, ground_y, SPAWN_Z)
	add_child(_local_player)
	print(
		"[CLIENT] Avatar instanciado perfeitamente rente ao solo na altitude: %.2fm (Gatilho Anti-Limbo: %.2fm)"
		% [ground_y, _local_player.min_fall_limit_y]
	)

	# 4. Instancia a HUD de Depuração de Coordenadas
	_debug_hud = DebugHUD.new()
	_debug_hud.target_player = _local_player
	add_child(_debug_hud)

	# 5. Conecta ao Servidor QuanticNet (se não estiver em modo isolado)
	var args = OS.get_cmdline_user_args()
	var is_offline = "--offline" in args or "--solo" in args

	var qn = get_node_or_null("/root/QuanticNet")
	if qn and not is_offline:
		var use_netem = "--netem" in args
		print("[CLIENT] Conectando ao host 127.0.0.1:%d (NetEm=%s)..." % [PORT, str(use_netem)])
		qn.join("127.0.0.1", PORT, SECRET, use_netem)
		get_tree().set_multiplayer(qn.get_tree().get_multiplayer(qn.get_path()), self.get_path())
	else:
		print("[CLIENT] Executando em modo local standalone (Offline).")


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
