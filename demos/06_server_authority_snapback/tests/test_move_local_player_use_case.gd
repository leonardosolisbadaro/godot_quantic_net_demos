## @file test_move_local_player_use_case.gd
## @path res://tests/test_move_local_player_use_case.gd
##
## @description
## Verifica a lógica de movimentação do jogador local, incluindo a injeção
## proposital do teleporte de teste (speedhack artificial).
##
## @created 2026-08-08
## @updated 2026-08-08
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)
extends "res://addons/gut/test.gd"

const MoveLocalPlayerUseCase = preload("res://src/use_cases/move_local_player_use_case.gd")

var _move_uc: MoveLocalPlayerUseCase
var _gateway_mock: QuanticNetMock


func before_each() -> void:
	_gateway_mock = QuanticNetMock.new()
	_move_uc = MoveLocalPlayerUseCase.new(_gateway_mock)


func after_each() -> void:
	_gateway_mock.free()


func test_movimento_regular() -> void:
	# Arrange
	var initial_pos = Vector3(0, 0, 0)
	var dir = Vector3(0, 0, -1)
	var speed = 10.0
	var delta = 0.1

	# Act
	var result = _move_uc.execute(initial_pos, dir, speed, delta, false)

	# Assert
	assert_eq(result, Vector3(0, 0, -1.0), "Movimento regular para a frente")


func test_teleporte_injetado() -> void:
	# Arrange
	var initial_pos = Vector3(0, 0, 0)
	var dir = Vector3(0, 0, 0)
	var speed = 10.0
	var delta = 0.1

	# Act
	# Injetando teleporte = true
	var result = _move_uc.execute(initial_pos, dir, speed, delta, true)

	# Assert
	assert_eq(result.z, -2.0, "O cheat de teleporte deve subtrair 2.0 no eixo Z")


class QuanticNetMock extends Node:
	var last_pos: Vector3


	func submit_state(pos: Vector3, _rot: Vector3, _custom: int, _dt: float) -> void:
		last_pos = pos
