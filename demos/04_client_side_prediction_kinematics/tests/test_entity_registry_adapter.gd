## @file test_entity_registry_adapter.gd
## @path res://tests/test_entity_registry_adapter.gd
##
## @description
## Testes unitários para EntityRegistryAdapter.
## Garante que os eventos da Engine (sinais) sejam traduzidos 
## em comandos de domínio (Use Cases) quando no servidor, e em
## eventos visuais quando atuando como cliente.
##
## @created 2026-08-07
## @updated 2026-08-07
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)

extends GutTest

const EntityRegistryAdapter = preload("res://src/adapters/entity_registry_adapter.gd")
const SpawnAuthoritativeEntityUseCase = preload("res://src/use_cases/spawn_authoritative_entity_use_case.gd")
const DespawnAuthoritativeEntityUseCase = preload("res://src/use_cases/despawn_authoritative_entity_use_case.gd")
const EntityProfileFactory = preload("res://src/domain/entity_profile_factory.gd")

var _adapter: EntityRegistryAdapter
var _mock_gateway: Object
var _mock_spawn_use_case: Object
var _mock_despawn_use_case: Object
var _mock_factory: EntityProfileFactory

class MockGateway:
	signal peer_joined(id: int)
	signal peer_left(id: int)
	signal state_received(id: int, pos: Vector3, rot: Vector3, custom: int)
	
	var _is_server_flag: bool = false
	
	func is_server() -> bool:
		return _is_server_flag
		
	func simulate_peer_joined(id: int) -> void:
		peer_joined.emit(id)
		
	func simulate_peer_left(id: int) -> void:
		peer_left.emit(id)
		
	func simulate_state_received(id: int, pos: Vector3, rot: Vector3, custom: int) -> void:
		state_received.emit(id, pos, rot, custom)

class MockSpawnUseCase extends SpawnAuthoritativeEntityUseCase:
	var executed_id: int = -1
	var executed_is_peer: bool = false
	var executed_profile: QNEntityProfile = null
	
	func _init() -> void:
		super(null)
		
	func execute(entity_id: int, is_peer: bool, profile: QNEntityProfile) -> void:
		executed_id = entity_id
		executed_is_peer = is_peer
		executed_profile = profile

class MockDespawnUseCase extends DespawnAuthoritativeEntityUseCase:
	var executed_id: int = -1
	
	func _init() -> void:
		super(null)
		
	func execute(entity_id: int) -> void:
		executed_id = entity_id

func before_each() -> void:
	_mock_gateway = MockGateway.new()
	_mock_spawn_use_case = MockSpawnUseCase.new()
	_mock_despawn_use_case = MockDespawnUseCase.new()
	_mock_factory = EntityProfileFactory.new()
	_adapter = EntityRegistryAdapter.new(_mock_gateway, _mock_spawn_use_case, _mock_despawn_use_case, _mock_factory)

func test_deve_chamar_spawn_use_case_quando_peer_entra_como_servidor() -> void:
	# Arrange
	_mock_gateway._is_server_flag = true
	
	# Act
	_mock_gateway.simulate_peer_joined(42)
	
	# Assert
	assert_eq(_mock_spawn_use_case.executed_id, 42)
	assert_eq(_mock_spawn_use_case.executed_is_peer, true)
	assert_not_null(_mock_spawn_use_case.executed_profile)

func test_nao_deve_chamar_spawn_use_case_quando_peer_entra_como_cliente() -> void:
	# Arrange
	_mock_gateway._is_server_flag = false
	
	# Act
	_mock_gateway.simulate_peer_joined(42)
	
	# Assert
	assert_eq(_mock_spawn_use_case.executed_id, -1)

func test_deve_chamar_despawn_use_case_quando_peer_sai_como_servidor() -> void:
	# Arrange
	_mock_gateway._is_server_flag = true
	
	# Act
	_mock_gateway.simulate_peer_left(42)
	
	# Assert
	assert_eq(_mock_despawn_use_case.executed_id, 42)

func test_deve_emitir_visual_state_quando_state_received() -> void:
	# Arrange
	watch_signals(_adapter)
	var pos = Vector3(1, 2, 3)
	var rot = Vector3(0, 180, 0)
	
	# Act
	_mock_gateway.simulate_state_received(42, pos, rot, 0)
	
	# Assert
	assert_signal_emitted_with_parameters(_adapter, "visual_state_received", [42, pos, rot])

func test_deve_emitir_visual_entity_removed_quando_peer_left() -> void:
	# Arrange
	watch_signals(_adapter)
	
	# Act
	_mock_gateway.simulate_peer_left(42)
	
	# Assert
	assert_signal_emitted_with_parameters(_adapter, "visual_entity_removed", [42])
