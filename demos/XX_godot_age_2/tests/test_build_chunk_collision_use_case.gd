## @file test_build_chunk_collision_use_case.gd
## @path res://tests/test_build_chunk_collision_use_case.gd
##
## @description
## Testes unitários para o caso de uso BuildChunkCollisionUseCase.
## SUT: BuildChunkCollisionUseCase
##
## @created 2026-08-15
## @updated 2026-08-15
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)
extends "res://addons/gut/test.gd"

const BuildChunkCollisionUseCase = preload("res://src/use_cases/build_chunk_collision_use_case.gd")

var _use_case: BuildChunkCollisionUseCase


func before_each() -> void:
	_use_case = BuildChunkCollisionUseCase.new()


func test_construir_heightmap_shape_valido() -> void:
	# Arrange
	var width = 4
	var depth = 4
	var float_data = PackedFloat32Array()
	float_data.resize(width * depth)
	for i in range(float_data.size()):
		float_data[i] = float(i) * 1.5

	# Act
	var shape = _use_case.execute(float_data, width, depth)

	# Assert
	assert_not_null(shape, "Shape deve ser instanciado")
	assert_eq(shape.map_width, 4)
	assert_eq(shape.map_depth, 4)
	assert_eq(shape.map_data.size(), 16)
	assert_almost_eq(shape.map_data[2], 3.0, 0.001)


func test_construir_a_partir_de_bytes_brutos() -> void:
	# Arrange
	var width = 2
	var depth = 2
	var floats = PackedFloat32Array([10.0, 20.0, 30.0, 40.0])
	var raw_bytes = floats.to_byte_array()

	# Act
	var shape = _use_case.from_raw_bytes(raw_bytes, width, depth)

	# Assert
	assert_not_null(shape, "Shape deve ser gerado a partir de bytes Little-Endian")
	assert_eq(shape.map_width, 2)
	assert_eq(shape.map_depth, 2)
	assert_almost_eq(shape.map_data[3], 40.0, 0.001)


func test_dados_vazios_retornam_nulo() -> void:
	# Arrange & Act
	var shape = _use_case.execute(PackedFloat32Array(), 0, 0)

	# Assert
	assert_null(shape, "Dados invalidos devem retornar null")
