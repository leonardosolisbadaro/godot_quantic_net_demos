## @file player_avatar.gd
## @path res://src/infrastructure/player_avatar.gd
##
## @description
## Nó 3D do Avatar do Jogador (CharacterBody3D).
## Implementa câmera orbital em terceira pessoa (SpringArm3D), spawn perfeitamente rente ao solo
## via raycast contra o colisor físico do terreno, inércia balística de queda e depuração visual (F1/F2).
##
## @created 2026-08-15
## @updated 2026-08-16
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)
extends CharacterBody3D

const CLIENT_MOVE_SPEED := 22.0
const SPRINT_MULTIPLIER := 2.0
const GRAVITY := 20.0
const MAX_FALL_SPEED := 45.0
const JUMP_VELOCITY := 8.5

const CAMERA_START_ROT := Vector3(-25.0, 0.0, 0.0)
const CAMERA_DEFAULT_SPRING_LENGTH := 18.0
const CAMERA_SPRING_MARGIN := 0.2
const CAMERA_TARGET_Y_OFFSET := 1.4
const CAMERA_LERP_SPEED := 12.0
const MOUSE_SENSITIVITY := 0.3
const CAMERA_PITCH_MIN := -65.0
const CAMERA_PITCH_MAX := 40.0
const ZOOM_MIN := 3.0
const ZOOM_MAX := 100.0
const ZOOM_STEP := 2.0

var is_local: bool = true
var peer_id: int = 1

var _camera_pivot: Node3D
var _spring_arm: SpringArm3D
var _camera: Camera3D
var _current_zoom: float = CAMERA_DEFAULT_SPRING_LENGTH

var _mesh_instance: MeshInstance3D
var _visor_instance: MeshInstance3D
var _col_shape: CollisionShape3D
var _debug_collider_visual: MeshInstance3D
var _debug_contact_point: MeshInstance3D

var _target_net_pos: Vector3 = Vector3.ZERO
var _target_net_rot: Vector3 = Vector3.ZERO
var _air_momentum_velocity: Vector3 = Vector3.ZERO
var _is_debug_visual_visible: bool = false
var _has_settled_on_ground: bool = false


func _ready() -> void:
	_setup_physics_properties()
	_setup_visuals()

	if is_local:
		_setup_camera()
	else:
		_target_net_pos = position
		_target_net_rot = rotation


func _exit_tree() -> void:
	if _camera_pivot and is_instance_valid(_camera_pivot):
		_camera_pivot.queue_free()


func _setup_physics_properties() -> void:
	floor_max_angle = deg_to_rad(65.0)
	floor_snap_length = 1.0
	floor_constant_speed = true
	floor_block_on_wall = true
	floor_stop_on_slope = true


func _setup_visuals() -> void:
	# Cápsula de Colisão Física: 2.0m de altura, centro em Y = 1.0m (base dos pés toca em Y = 0.0m)
	_col_shape = CollisionShape3D.new()
	var cap_shape = CapsuleShape3D.new()
	cap_shape.radius = 0.5
	cap_shape.height = 2.0
	_col_shape.shape = cap_shape
	_col_shape.position = Vector3(0, 1.0, 0)
	add_child(_col_shape)

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

	# Visualizador de Colisão de Depuração (Atalho F1)
	_debug_collider_visual = MeshInstance3D.new()
	var dbg_cap = CapsuleMesh.new()
	dbg_cap.radius = 0.52
	dbg_cap.height = 2.04
	_debug_collider_visual.mesh = dbg_cap
	_debug_collider_visual.position = Vector3(0, 1.0, 0)
	var dbg_mat = StandardMaterial3D.new()
	dbg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dbg_mat.albedo_color = Color(0.0, 1.0, 0.8, 0.35)
	dbg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_debug_collider_visual.material_override = dbg_mat
	_debug_collider_visual.visible = false
	add_child(_debug_collider_visual)

	# Ponto de Contato no Solo
	_debug_contact_point = MeshInstance3D.new()
	var sph_mesh = SphereMesh.new()
	sph_mesh.radius = 0.12
	sph_mesh.height = 0.24
	_debug_contact_point.mesh = sph_mesh
	_debug_contact_point.position = Vector3(0, 0.05, 0)
	var sph_mat = StandardMaterial3D.new()
	sph_mat.albedo_color = Color(1.0, 0.2, 0.0, 0.9)
	sph_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_debug_contact_point.material_override = sph_mat
	_debug_contact_point.visible = false
	add_child(_debug_contact_point)


func _setup_camera() -> void:
	_camera_pivot = Node3D.new()
	_camera_pivot.name = "CameraPivot"
	_camera_pivot.top_level = true
	_camera_pivot.position = position
	_camera_pivot.rotation_degrees = CAMERA_START_ROT
	add_child(_camera_pivot)

	_spring_arm = SpringArm3D.new()
	_spring_arm.spring_length = _current_zoom
	_spring_arm.margin = CAMERA_SPRING_MARGIN
	_spring_arm.position.y = CAMERA_TARGET_Y_OFFSET
	_spring_arm.add_excluded_object(get_rid())
	_camera_pivot.add_child(_spring_arm)

	_camera = Camera3D.new()
	_camera.current = true
	_camera.far = 4000.0
	_spring_arm.add_child(_camera)


func _unhandled_input(event: InputEvent) -> void:
	if not is_local:
		return

	# Controle de captura do mouse (Botão Direito segura para orbitar)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_current_zoom = maxf(ZOOM_MIN, _current_zoom - ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_current_zoom = minf(ZOOM_MAX, _current_zoom + ZOOM_STEP)

	# Rotação Orbital da Câmera pelo Mouse
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if _camera_pivot:
			_camera_pivot.rotation_degrees.y -= event.relative.x * MOUSE_SENSITIVITY
			_camera_pivot.rotation_degrees.x -= event.relative.y * MOUSE_SENSITIVITY
			_camera_pivot.rotation_degrees.x = clampf(
				_camera_pivot.rotation_degrees.x,
				CAMERA_PITCH_MIN,
				CAMERA_PITCH_MAX
			)

	# Tecla F1: Alterna Visualizador de Colisão do Personagem
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			_is_debug_visual_visible = not _is_debug_visual_visible
			if _debug_collider_visual:
				_debug_collider_visual.visible = _is_debug_visual_visible
			if _debug_contact_point:
				_debug_contact_point.visible = _is_debug_visual_visible
			print("[DEBUG] Visualizador de Colisao: ", "ATIVO" if _is_debug_visual_visible else "OCULTO")


func _process(delta: float) -> void:
	if is_local and _camera_pivot:
		_camera_pivot.position = _camera_pivot.position.lerp(position, delta * CAMERA_LERP_SPEED)
		if _spring_arm:
			_spring_arm.spring_length = lerpf(_spring_arm.spring_length, _current_zoom, delta * 10.0)


func _physics_process(delta: float) -> void:
	if is_local:
		_process_local_movement(delta)
	else:
		_process_remote_interpolation(delta)


func _process_local_movement(delta: float) -> void:
	# Raycast Inicial de Pouso Perfeito (Ancoragem de Sub-Milímetro ao Solo)
	if not _has_settled_on_ground:
		var space_state = get_world_3d().direct_space_state
		if space_state:
			var query = PhysicsRayQueryParameters3D.create(
				global_position + Vector3(0, 50.0, 0),
				global_position - Vector3(0, 100.0, 0)
			)
			query.exclude = [get_rid()]
			var hit = space_state.intersect_ray(query)
			if hit and not hit.is_empty():
				global_position = hit.position
				velocity = Vector3.ZERO
				apply_floor_snap()
				_has_settled_on_ground = true
				if _camera_pivot:
					_camera_pivot.position = global_position
				print("[AVATAR] Pouso exato efetuado sobre o solo: Y = %.2fm" % hit.position.y)
				return

	var on_floor = is_on_floor()

	if on_floor:
		# 1. Movimentação no Solo (Entrada WASD orientada pela Câmera)
		var input_dir = Vector3.ZERO
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			input_dir.z -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			input_dir.z += 1.0
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			input_dir.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			input_dir.x += 1.0

		if input_dir.length_squared() > 0.0:
			input_dir = input_dir.normalized()
			if _camera_pivot:
				input_dir = input_dir.rotated(Vector3.UP, _camera_pivot.rotation.y)

			var target_angle = atan2(-input_dir.x, -input_dir.z)
			rotation.y = lerp_angle(rotation.y, target_angle, 15.0 * delta)

		var speed = CLIENT_MOVE_SPEED
		if Input.is_key_pressed(KEY_SHIFT):
			speed *= SPRINT_MULTIPLIER

		velocity.x = input_dir.x * speed
		velocity.z = input_dir.z * speed
		_air_momentum_velocity = Vector3(velocity.x, 0.0, velocity.z)
		velocity.y = 0.0

		if Input.is_key_pressed(KEY_SPACE):
			velocity.y = JUMP_VELOCITY
	else:
		# 2. Inércia Balística no Ar: Conserva o vetor horizontal inicial e acelera a gravidade
		velocity.y = maxf(velocity.y - GRAVITY * delta, -MAX_FALL_SPEED)
		velocity.x = _air_momentum_velocity.x
		velocity.z = _air_momentum_velocity.z

	move_and_slide()

	# 3. Proteção Anti-Limbo
	if position.y < -250.0:
		var space_state = get_world_3d().direct_space_state
		if space_state:
			var query = PhysicsRayQueryParameters3D.create(
				Vector3(position.x, 50.0, position.z),
				Vector3(position.x, -250.0, position.z)
			)
			query.exclude = [get_rid()]
			var hit = space_state.intersect_ray(query)
			if hit and not hit.is_empty():
				global_position = hit.position
			else:
				position.y = -50.0
		velocity = Vector3.ZERO
		_air_momentum_velocity = Vector3.ZERO

	# 4. Sincronização QuanticNet
	var qn = get_node_or_null("/root/QuanticNet")
	if qn and qn.has_method("submit_state"):
		var custom_flags = 1 if is_on_floor() else 0
		qn.submit_state(position, rotation, custom_flags, delta)


func _process_remote_interpolation(delta: float) -> void:
	position = position.lerp(_target_net_pos, 15.0 * delta)
	rotation.y = lerp_angle(rotation.y, _target_net_rot.y, 15.0 * delta)


func update_remote_state(net_pos: Vector3, net_rot: Vector3) -> void:
	_target_net_pos = net_pos
	_target_net_rot = net_rot
