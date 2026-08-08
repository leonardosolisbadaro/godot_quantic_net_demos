## @file test_spawn_authoritative_entity_use_case.gd
## @path res://tests/test_spawn_authoritative_entity_use_case.gd
##
## @description
## Testes unitários para SpawnAuthoritativeEntityUseCase.
## Valida se o Use Case interage corretamente com a camada de infraestrutura
## abstrata (MockGateway) para registrar entidades.
##
## @created 2026-08-07
## @updated 2026-08-07
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)

extends GutTest

const SpawnAuthoritativeEntityUseCase = preload("res://src/use_cases/spawn_authoritative_entity_use_case.gd")

var _use_case: SpawnAuthoritativeEntityUseCase
var _mock_gateway: Object

class MockGateway:
	var registered_id: int = -1
	var registered_is_peer: bool = false
	var registered_has_initial_state: bool = false
	var registered_profile: QNEntityProfile = null
	
	func register_entity(id: int, is_peer: bool, has_initial_state: bool, profile: QNEntityProfile) -> void:
		registered_id = id
		registered_is_peer = is_peer
		registered_has_initial_state = has_initial_state
		registered_profile = profile

func before_each() -> void:
	_mock_gateway = MockGateway.new()
	_use_case = SpawnAuthoritativeEntityUseCase.new(_mock_gateway)

func test_deve_chamar_register_entity_no_gateway_com_parametros_corretos() -> void:
	# Arrange
	var entity_id = 42
	var is_peer = true
	var profile = QNEntityProfile.new()
	profile.init(60.0, 1.0, 20.0)
	
	# Act
	_use_case.execute(entity_id, is_peer, profile)
	
	# Assert
	assert_eq(_mock_gateway.registered_id, 42)
	assert_eq(_mock_gateway.registered_is_peer, true)
	assert_eq(_mock_gateway.registered_has_initial_state, true)
	assert_eq(_mock_gateway.registered_profile, profile)
