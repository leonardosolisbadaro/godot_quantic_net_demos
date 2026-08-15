## @file test_terrain_chunk_data.gd
## @path res://tests/test_terrain_chunk_data.gd
##
## @description
## Testes unitários para a entidade de domínio TerrainChunkData.
## SUT: TerrainChunkData
##
## @created 2026-08-15
## @updated 2026-08-15
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)
extends "res://addons/gut/test.gd"

const TerrainChunkData = preload("res://src/domain/terrain_chunk_data.gd")


func test_instanciacao_padrao() -> void:
	# Arrange & Act
	var data = TerrainChunkData.new("16_24", 16, 24)

	# Assert
	assert_eq(data.chunk_name, "16_24")
	assert_eq(data.chunk_x, 16)
	assert_eq(data.chunk_y, 24)


func test_from_meta_dictionary() -> void:
	# Arrange
	var data = TerrainChunkData.new()
	var dict = {
		"chunk_name": "16_24",
		"chunk_indices": [16, 24],
		"grid_resolution": [256, 256],
		"cell_size_meters": [2.438, 2.438],
		"chunk_dimensions_meters": [624.15, 624.15],
		"world_origin_meters": [-2184.53, 3.36, 4056.99],
		"altitude_meters": {
			"min": -185.3,
			"max": -24.8
		}
	}

	# Act
	data.from_meta_dictionary(dict)

	# Assert
	assert_eq(data.chunk_name, "16_24")
	assert_eq(data.chunk_x, 16)
	assert_eq(data.chunk_y, 24)
	assert_eq(data.grid_width, 256)
	assert_eq(data.grid_depth, 256)
	assert_almost_eq(data.cell_size_x, 2.438, 0.001)
	assert_almost_eq(data.world_origin.x, -2184.53, 0.01)
	assert_almost_eq(data.min_altitude, -185.3, 0.01)


func test_contains_world_point() -> void:
	# Arrange
	var data = TerrainChunkData.new()
	data.world_origin = Vector3(0.0, 0.0, 0.0)
	data.total_width_meters = 100.0
	data.total_depth_meters = 100.0

	# Act & Assert
	assert_true(data.contains_world_point(0.0, 0.0), "Origem deve estar contida")
	assert_true(data.contains_world_point(40.0, -40.0), "Dentro dos limites (-50 a 50)")
	assert_false(data.contains_world_point(60.0, 0.0), "Fora dos limites em X")
	assert_false(data.contains_world_point(0.0, -60.0), "Fora dos limites em Z")
