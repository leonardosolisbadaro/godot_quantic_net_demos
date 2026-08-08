## @file main.gd
## @path res://main.gd
##
## @description
## Ponto de entrada da Demo 07. Configura a topologia de rede e implementa
## Server Authority & Snapback. O servidor valida movimentos e pune cheats.
##
## @created 2026-08-08
## @updated 2026-08-08
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)
extends Node3D

const EntityProfileFactory = preload("res://src/domain/entity_profile_factory.gd")
const SpawnAuthoritativeEntityUseCase = preload(
	"res://src/use_cases/spawn_authoritative_entity_use_case.gd"
)
const DespawnAuthoritativeEntityUseCase = preload(
	"res://src/use_cases/despawn_authoritative_entity_use_case.gd"
)
const MoveLocalPlayerUseCase = preload("res://src/use_cases/move_local_player_use_case.gd")
const InterpolateRemoteEntitiesUseCase = preload(
	"res://src/use_cases/interpolate_remote_entities_use_case.gd"
)
const EntityRegistryAdapter = preload("res://src/adapters/entity_registry_adapter.gd")

var _adapter: EntityRegistryAdapter
var _move_uc: MoveLocalPlayerUseCase
var _interp_uc: InterpolateRemoteEntitiesUseCase
var _active_visuals: Dictionary = { }

var _local_id: int = 0
var _local_pos: Vector3 = Vector3.ZERO


func _ready() -> void:
	Engine.max_fps = 60
	_setup_scene()

	var factory = EntityProfileFactory.new()
	var spawn_uc = SpawnAuthoritativeEntityUseCase.new(QuanticNet)
	var despawn_uc = DespawnAuthoritativeEntityUseCase.new(QuanticNet)
	_move_uc = MoveLocalPlayerUseCase.new(QuanticNet)
	_interp_uc = InterpolateRemoteEntitiesUseCase.new(QuanticNet)

	_adapter = EntityRegistryAdapter.new(QuanticNet, spawn_uc, despawn_uc, factory)
	_adapter.visual_state_received.connect(_on_visual_state_received)
	_adapter.visual_entity_removed.connect(_on_visual_entity_removed)

	QuanticNet.snapback_received.connect(_on_snapback)

	var args = OS.get_cmdline_user_args()
	var use_netem = args.has("--netem")

	# Confiamos na engine C++ para validar a física nativamente.
	# Definimos max_speed = 12.0 m/s para uma tolerância mínima acima da velocidade base (10.0).
	# Definimos hard_cap igual ao max_speed para eliminar a absorção elástica (clamp) e punir imediatamente.
	# Definimos max_strikes alto para não sermos banidos do servidor enquanto testamos.
	var config = {
		"max_speed": 12.0,
		"hard_cap": 12.0,
		"max_strikes": 9999,
		"netem_loss": 10.0 if use_netem else 0.0,
		"netem_latency": 150 if use_netem else 0,
		"netem_jitter": 50 if use_netem else 0,
	}

	if args.has("--server"):
		DisplayServer.window_set_title("SERVER")
		QuanticNet.host(4242, "demo-secret", "*", 32, config)
		# O Servidor nasce autoritativo: registra a si mesmo e o cenário.
		spawn_uc.execute(1, true, factory.create_player_profile())
		spawn_uc.execute(1001, false, factory.create_prop_profile())
		spawn_uc.execute(1002, false, factory.create_prop_profile())
	else:
		DisplayServer.window_set_title("CLIENT (NETEM ON)" if use_netem else "CLIENT")
		QuanticNet.join("127.0.0.1", 4242, "demo-secret", use_netem, config)

	get_tree().set_multiplayer(QuanticNet.get_tree().get_multiplayer(QuanticNet.get_path()), self.get_path())


func _process(delta: float) -> void:
	# O Servidor não recebe 'state_received' passivamente pela rede (pois ele é a fonte da verdade).
	# Para vermos o mundo na tela do Servidor, lemos o cache ativamente:
	if QuanticNet.is_server():
		var registry = QuanticNet.get_registry()
		for id in registry.keys():
			var st = QuanticNet.remote_state(id)
			if not st.is_empty():
				_on_visual_state_received(id, st.get("pos", Vector3.ZERO), Vector3.ZERO)

	# Interpolação Visual (Snapshot Interpolation) para entidades remotas
	for id in _active_visuals.keys():
		if not QuanticNet.is_server() and id == _local_id:
			continue

		var visual = _active_visuals[id]
		# Usamos o delta * velocidade de aproximação para a fórmula de lerp
		var lerp_weight = delta * 15.0
		visual.position = _interp_uc.execute(id, visual.position, lerp_weight)


func _physics_process(delta: float) -> void:
	if QuanticNet.get_state() != QuanticNet.ConnectionState.CONNECTED:
		return

	if QuanticNet.is_server():
		# O Servidor detém a autoridade dos Props. Como não há movimento real nesta demo,
		# vamos fazê-los orbitar levemente para garantir que o estado "sujo" (dirty) obrigue o envio contínuo!
		var time = float(Time.get_ticks_msec()) / 1000.0
		var pos_prop_1 = Vector3(cos(time) * -3.0, 1.0, sin(time) * 3.0)
		var pos_prop_2 = Vector3(cos(time) * 3.0, 1.0, sin(time) * -3.0)

		QuanticNet.update_entity_state(1001, pos_prop_1, Vector3.ZERO, 0, Time.get_ticks_msec())
		QuanticNet.update_entity_state(1002, pos_prop_2, Vector3.ZERO, 0, Time.get_ticks_msec())
	else:
		# Cria a malha do avatar local no primeiro frame conectado
		if _local_id == 0:
			_setup_local_avatar()

		# Captura input direcional (W, A, S, D)
		var input_dir = Vector3.ZERO
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			input_dir.z -= 1
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			input_dir.z += 1
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			input_dir.x -= 1
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			input_dir.x += 1

		# Injeta o cheat se pressionar Espaço
		var inject_cheat = (
			Input.is_action_just_pressed("ui_select") or Input.is_key_pressed(KEY_SPACE)
		)

		# Envia o input para o Use Case de Predição Local (CSP)
		_local_pos = _move_uc.execute(_local_pos, input_dir, 10.0, delta, inject_cheat)

		# Atualiza a malha instantaneamente, sem esperar o server (Zero Input Lag)
		if _active_visuals.has(_local_id):
			_active_visuals[_local_id].position = _local_pos


func _setup_local_avatar() -> void:
	_local_id = QuanticNet.get_unique_id()
	_local_pos = Vector3(_local_id * 2.0, 1.0, 0) # Posição dummy para a demo

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.GREEN # Local Player = Verde
	mesh_instance.material_override = mat
	add_child(mesh_instance)
	_active_visuals[_local_id] = mesh_instance
	mesh_instance.position = _local_pos


func _setup_scene() -> void:
	var cam = Camera3D.new()
	cam.position = Vector3(0, 8, 10)
	cam.rotation_degrees = Vector3(-35, 0, 0)
	add_child(cam)

	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 45, 0)
	add_child(light)

	var floor_mesh = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(40, 40)
	floor_mesh.mesh = plane
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.2, 0.25)
	floor_mesh.material_override = mat
	add_child(floor_mesh)


func _on_visual_state_received(id: int, pos: Vector3, _rot: Vector3) -> void:
	if not QuanticNet.is_server() and id == _local_id:
		return

	if not _active_visuals.has(id):
		var is_player = id < 1000
		var mesh_instance = MeshInstance3D.new()

		var mat = StandardMaterial3D.new()
		if is_player:
			mesh_instance.mesh = BoxMesh.new()
			mat.albedo_color = Color.RED # Remotos = Vermelho
		else:
			mesh_instance.mesh = SphereMesh.new()
			mat.albedo_color = Color.ORANGE # Props = Laranja

		mesh_instance.material_override = mat
		add_child(mesh_instance)
		_active_visuals[id] = mesh_instance
		# Seta a posição inicial para não vir do (0,0,0) na primeira vez
		_active_visuals[id].position = pos


func _on_visual_entity_removed(id: int) -> void:
	if _active_visuals.has(id):
		_active_visuals[id].queue_free()
		_active_visuals.erase(id)


func _on_snapback(seq: int, pos: Vector3, rot: Vector3, reason: int, replay: Array) -> void:
	# 1. Aceitamos o vetor oficial e absoluto do servidor como a nova verdade local
	_local_pos = pos

	if replay.size() > 0:
		print(
			"SNAPBACK C++ RECEBIDO! Reconciliando: ",
			pos,
			". Re-aplicando ",
			replay.size(),
			" inputs pendentes...",
		)
		# 2. Re-aplicamos (Client Replay) todos os inputs que foram enviados APÓS o frame da correção
		for pending in replay:
			var dir = pending["move"]
			var dt = pending["dt"]
			# Executamos nossa Use Case de domínio exatamente da mesma forma,
			# consumindo a direção original (x, y) que o servidor devolveu.
			# E passamos false no inject_teleport para não engatilhar loop de fraude!
			# E passamos false no submit_network para não re-enviar pacotes!
			_local_pos = _move_uc.execute(_local_pos, Vector3(dir.x, 0, dir.y), 10.0, dt, false, false)
	else:
		print("SNAPBACK C++ RECEBIDO! Reconciliação forçada para: ", pos, " Motivo: ", reason)

	if _active_visuals.has(_local_id):
		_active_visuals[_local_id].position = _local_pos
