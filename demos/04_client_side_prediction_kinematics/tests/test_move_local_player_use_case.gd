## @file test_move_local_player_use_case.gd
## @path res://tests/test_move_local_player_use_case.gd
##
## @description
## Testes unitários para MoveLocalPlayerUseCase.
## Valida se a predição client-side calcula a nova posição e submete corretamente à engine.
##
## @created 2026-08-08
## @updated 2026-08-08
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)
extends "res://addons/gut/test.gd"

var MoveLocalPlayerUseCase = preload("res://src/use_cases/move_local_player_use_case.gd")

class QuanticNetGatewayMock:
	var submitted_pos: Vector3 = Vector3.ZERO
	var submitted_rot: Vector3 = Vector3.ZERO
	var submitted_custom: int = 0
	var submitted_dt: float = 0.0
	
	func submit_state(pos: Vector3, rot: Vector3, custom: int, dt: float) -> void:
		submitted_pos = pos
		submitted_rot = rot
		submitted_custom = custom
		submitted_dt = dt

func test_deve_calcular_nova_posicao_e_chamar_submit_state() -> void:
	# Arrange
	var gateway_mock = QuanticNetGatewayMock.new()
	var sut = MoveLocalPlayerUseCase.new(gateway_mock)
	var current_pos = Vector3.ZERO
	var input_dir = Vector3(1.0, 0.0, 0.0)
	var speed = 10.0
	var delta = 1.0
	
	# Act
	var new_pos = sut.execute(current_pos, input_dir, speed, delta)
	
	# Assert
	assert_eq(new_pos, Vector3(10.0, 0.0, 0.0), "Deve calcular o deslocamento correto no domínio")
	assert_eq(gateway_mock.submitted_pos, new_pos, "Deve enviar a nova posição prevista")
	assert_eq(gateway_mock.submitted_dt, delta, "Deve encaminhar o delta para a engine")
