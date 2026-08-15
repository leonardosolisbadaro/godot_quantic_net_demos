## @file player_avatar.gd
## @path res://src/infrastructure/player_avatar.gd
##
## @description
## Nó 3D do Avatar do Jogador (CharacterBody3D).
## Controla câmera em terceira pessoa com mola (SpringArm3D), rotação orbital
## de mouse, movimentação WASD no plano de câmera e predição/sincronização de rede.
##
## @created 2026-08-15
## @updated 2026-08-15
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)
extends CharacterBody3D

const MOVE_SPEED := 25.0
const SPRINT_MULTIPLIER := 2.5
const GRAVITY := 20.0
const JUMP_VELOCITY := 8.0
const MOUSE_SENSITIVITY := 0.003
const ZOOM_MIN := 3.0
const ZOOM_MAX := 80.0

var is_local: bool = true
var peer_id: int = 1

var _spring_arm: SpringArm3D
var _camera: Camera3D
var _mesh_instance: MeshInstance3D
var _visor_instance: MeshInstance3D

var _cam_yaw: float = 0.0
var _cam_pitch: float = -0.4
var _mouse_captured: bool = false

var _target_net_pos: Vector3 = Vector3.ZERO
var _target_net_rot: Vector3 = Vector3.ZERO


func _ready() -> void:
	_setup_visuals()

	if is_local:
		_setup_camera()
	else:
		_target_net_pos = position
		_target_net_rot = rotation


func _setup_visuals() -> void:
	# Cápsula de Colisão Física
	var col_shape = CollisionShape3D.new()
	var cap_shape = CapsuleShape3D.new()
	cap_shape.radius = 0.5
	cap_shape.height = 2.0
	col_shape.shape = cap_shape
	col_shape.position = Vector3(0, 1.0, 0)
	add_child(col_shape)

	# Malha Visual do Jogador
	_mesh_instance = MeshInstance3D.new()
	var cap_mesh = CapsuleMesh.new()
	cap_mesh.radius = 0.5
	cap_mesh.height = 2.0
	_mesh_instance.mesh = cap_mesh
	_mesh_instance.position = Vector3(0, 1.0, 0)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.7, 0.3) if is_local else Color(0.85, 0.25, 0.2)
	mat.roughness = 0.5
	_mesh_instance.material_override = mat
	add_child(_mesh_instance)

	# Viseira frontal indicativa de orientação
	_visor_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.5, 0.2, 0.3)
	_visor_instance.mesh = box_mesh
	_visor_instance.position = Vector3(0, 1.5, -0.45)

	var visor_mat = StandardMaterial3D.new()
	visor_mat.albedo_color = Color(0.1, 0.1, 0.1)
	_visor_instance.material_override = visor_mat
	add_child(_visor_instance)


func _setup_camera() -> void:
	_spring_arm = SpringArm3D.new()
	_spring_arm.position = Vector3(0, 1.8, 0)
	_spring_arm.spring_length = 15.0
	_spring_arm.margin = 0.3

	_camera = Camera3D.new()
	_camera.current = true
	_camera.far = 4000.0

	_spring_arm.add_child(_camera)
	add_child(_spring_arm)


func _unhandled_input(event: InputEvent) -> void:
	if not is_local:
		return

	# Controle de captura do mouse (Botão Direito segura ou ESC alterna)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_mouse_captured = event.pressed
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if _mouse_captured else Input.MOUSE_MODE_VISIBLE)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			if _spring_arm:
				_spring_arm.spring_length = clampf(_spring_arm.spring_length - 2.0, ZOOM_MIN, ZOOM_MAX)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			if _spring_arm:
				_spring_arm.spring_length = clampf(_spring_arm.spring_length + 2.0, ZOOM_MIN, ZOOM_MAX)

	# Rotação Orbital da Câmera
	if event is InputEventMouseMotion and _mouse_captured:
		_cam_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_cam_pitch = clampf(_cam_pitch - event.relative.y * MOUSE_SENSITIVITY, -1.4, 0.3)
		if _spring_arm:
			_spring_arm.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)


func _physics_process(delta: float) -> void:
	if is_local:
		_process_local_movement(delta)
	else:
		_process_remote_interpolation(delta)


func _process_local_movement(delta: float) -> void:
	# Aplica gravidade
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		if velocity.y < 0:
			velocity.y = -0.5
		if Input.is_key_pressed(KEY_SPACE):
			velocity.y = JUMP_VELOCITY

	# Direção no plano da câmera
	var cam_forward = -Vector3(sin(_cam_yaw), 0, cos(_cam_yaw)).normalized()
	var cam_right = Vector3(cos(_cam_yaw), 0, -sin(_cam_yaw)).normalized()

	var input_dir = Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir.y += 1.0
	if Input.is_key_pressed(KEY_S):
		input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1.0
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1.0

	var move_vec = (cam_forward * input_dir.y + cam_right * input_dir.x).normalized()
	var speed = MOVE_SPEED
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= SPRINT_MULTIPLIER

	velocity.x = move_vec.x * speed
	velocity.z = move_vec.z * speed

	# Gira o avatar em direção ao movimento
	if move_vec.length_squared() > 0.01:
		var target_angle = atan2(-move_vec.x, -move_vec.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 15.0 * delta)

	move_and_slide()

	# Envia estado local ao plugin QuanticNet
	var qn = get_node_or_null("/root/QuanticNet")
	if qn and qn.has_method("submit_state"):
		var custom_flags = 1 if is_on_floor() else 0
		qn.submit_state(position, rotation, custom_flags, delta)


func _process_remote_interpolation(delta: float) -> void:
	# Interpolação suave para avatares remotos
	position = position.lerp(_target_net_pos, 15.0 * delta)
	rotation.y = lerp_angle(rotation.y, _target_net_rot.y, 15.0 * delta)


func update_remote_state(net_pos: Vector3, net_rot: Vector3) -> void:
	_target_net_pos = net_pos
	_target_net_rot = net_rot
