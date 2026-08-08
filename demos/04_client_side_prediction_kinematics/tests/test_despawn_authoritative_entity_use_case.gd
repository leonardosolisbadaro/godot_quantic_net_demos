## @file test_despawn_authoritative_entity_use_case.gd
## @path res://tests/test_despawn_authoritative_entity_use_case.gd
##
## @description
## Testes unitários para DespawnAuthoritativeEntityUseCase.
## Valida se o Use Case interage corretamente com a camada de infraestrutura
## abstrata (MockGateway) para desregistrar entidades.
##
## @created 2026-08-07
## @updated 2026-08-07
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)

extends GutTest

const DespawnAuthoritativeEntityUseCase = preload("res://src/use_cases/despawn_authoritative_entity_use_case.gd")

var _use_case: DespawnAuthoritativeEntityUseCase
var _mock_gateway: Object

class MockGateway:
	var unregistered_id: int = -1
	
	func unregister_entity(id: int) -> void:
		unregistered_id = id

func before_each() -> void:
	_mock_gateway = MockGateway.new()
	_use_case = DespawnAuthoritativeEntityUseCase.new(_mock_gateway)

func test_deve_chamar_unregister_entity_no_gateway_com_id_correto() -> void:
	# Arrange
	var entity_id = 42
	
	# Act
	_use_case.execute(entity_id)
	
	# Assert
	assert_eq(_mock_gateway.unregistered_id, 42)
