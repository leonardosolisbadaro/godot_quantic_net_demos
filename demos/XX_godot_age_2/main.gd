## @file main.gd
## @path res://main.gd
##
## @description
## Ponto de entrada da Demo XX_godot_age_2 (Godotage II / Lineage II MMO).
## Inicializa a topologia de rede QuanticNet e orquestra o streaming
## visual e físico do terreno de Aden via ChunkManager.
##
## @created 2026-08-15
## @updated 2026-08-15
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)
extends Node3D

const ChunkManager = preload("res://src/infrastructure/chunk_manager.gd")

var _chunk_manager: ChunkManager
var _camera: Camera3D
var _light: DirectionalLight3D


func _ready() -> void:
	DisplayServer.window_set_title("Godotage II — Lineage II Godot Edition")
	_setup_environment()

	# Inicializa o Gerenciador de Chunks de Terreno
	_chunk_manager = ChunkManager.new("res://assets/maps")
	add_child(_chunk_manager)

	# Carrega o cluster 2x2 de chunks adjacentes (Talking Island / Aden)
	var initial_cluster = ["16_24", "16_25", "17_24", "17_25"]
	print("[Godotage II] Carregando cluster inicial de terreno: ", initial_cluster)
	_chunk_manager.load_cluster(initial_cluster)
	print("[Godotage II] Chunks ativos na memoria: ", _chunk_manager.get_loaded_chunks_count())

	var qn = get_node_or_null("/root/QuanticNet")
	if not qn:
		print("AVISO: Autoload QuanticNet nao encontrado. Rodando em modo standalone local.")
		return

	var args = OS.get_cmdline_user_args()
	if "--server" in args:
		DisplayServer.window_set_title("Godotage II [SERVER]")
		qn.host(4242, "secret")
		print("[SERVER] Servidor QuanticNet escutando na porta 4242...")
	else:
		DisplayServer.window_set_title("Godotage II [CLIENT]")
		qn.join("127.0.0.1", 4242, "secret")
		print("[CLIENT] Cliente conectando ao servidor...")


func _setup_environment() -> void:
	# Câmera Tática / Terceira Pessoa
	_camera = Camera3D.new()
	_camera.position = Vector3(-2184.5, 50.0, 4056.9 + 100.0)
	_camera.rotation_degrees = Vector3(-30, 0, 0)
	_camera.current = true
	_camera.far = 4000.0
	add_child(_camera)

	# Iluminação Direcional (Sol)
	_light = DirectionalLight3D.new()
	_light.rotation_degrees = Vector3(-55, 45, 0)
	_light.light_color = Color(0.98, 0.95, 0.88)
	_light.light_energy = 1.2
	_light.shadow_enabled = true
	add_child(_light)

	# Ambiente e Céu
	var world_env = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.53, 0.72, 0.91)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.70, 0.75)
	env.ambient_light_energy = 0.6
	world_env.environment = env
	add_child(world_env)


func _process(delta: float) -> void:
	# Controle simples de câmera livre (WASD + Q/E para subir/descer) para inspeção de terreno
	var move_speed = 150.0 * delta
	if Input.is_key_pressed(KEY_SHIFT):
		move_speed *= 3.0

	var cam_dir = Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		cam_dir -= _camera.transform.basis.z
	if Input.is_key_pressed(KEY_S):
		cam_dir += _camera.transform.basis.z
	if Input.is_key_pressed(KEY_A):
		cam_dir -= _camera.transform.basis.x
	if Input.is_key_pressed(KEY_D):
		cam_dir += _camera.transform.basis.x
	if Input.is_key_pressed(KEY_E):
		cam_dir.y += 1.0
	if Input.is_key_pressed(KEY_Q):
		cam_dir.y -= 1.0

	_camera.position += cam_dir.normalized() * move_speed
