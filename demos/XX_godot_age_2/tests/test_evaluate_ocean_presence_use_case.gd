## @file test_evaluate_ocean_presence_use_case.gd
## @path res://tests/test_evaluate_ocean_presence_use_case.gd
##
## @description
## Testes unitários para o Caso de Uso EvaluateOceanPresenceUseCase.
## Valida a regra de negócio que determina se um chunk deve instanciar tile de água
## baseado na sua cota mínima de altitude versus o nível global do mar.
##
## @created 2026-08-16
## @updated 2026-08-16
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)
extends "res://addons/gut/test.gd"

const EvaluateOceanPresenceUseCase = preload("res://src/use_cases/evaluate_ocean_presence_use_case.gd")
const OceanEnvironmentData = preload("res://src/domain/ocean_environment_data.gd")
const TerrainChunkData = preload("res://src/domain/terrain_chunk_data.gd")


func test_chunk_maritimo_precisa_de_mar() -> void:
	# Arrange
	var use_case = EvaluateOceanPresenceUseCase.new()
	var ocean = OceanEnvironmentData.new(-149.0)
	
	# Chunk 17_24 (todo submerso: min=-184.6m, max=-149.3m)
	var chunk_data = TerrainChunkData.new()
	var chunk_meta = {
		"chunk_name": "17_24",
		"chunk_indices": [17, 24],
		"grid_resolution": [256, 256],
		"cell_size_meters": [2.438, 2.438],
		"chunk_dimensions_meters": [624.15, 624.15],
		"world_origin_meters": [-1872.0, -184.6, 4368.0],
		"altitude_meters": {
			"min": -184.6,
			"max": -149.3
		}
	}
	chunk_data.from_meta_dictionary(chunk_meta)

	# Act
	var requires_water = use_case.should_instantiate_water(chunk_data, ocean)

	# Assert
	assert_true(requires_water, "Chunk 17_24 (min_height=-184.6m) deve instanciar água")


func test_chunk_costeiro_precisa_de_mar() -> void:
	# Arrange
	var use_case = EvaluateOceanPresenceUseCase.new()
	var ocean = OceanEnvironmentData.new(-149.0)
	
	# Chunk 16_24 (costeiro: min=-185.3m, max=-24.8m)
	var chunk_data = TerrainChunkData.new()
	var chunk_meta = {
		"chunk_name": "16_24",
		"chunk_indices": [16, 24],
		"grid_resolution": [256, 256],
		"cell_size_meters": [2.438, 2.438],
		"chunk_dimensions_meters": [624.15, 624.15],
		"world_origin_meters": [-2496.0, -185.3, 4368.0],
		"altitude_meters": {
			"min": -185.3,
			"max": -24.8
		}
	}
	chunk_data.from_meta_dictionary(chunk_meta)

	# Act
	var requires_water = use_case.should_instantiate_water(chunk_data, ocean)

	# Assert
	assert_true(requires_water, "Chunk 16_24 que toca o mar deve instanciar água")


func test_chunk_montanha_alta_nao_instancia_mar() -> void:
	# Arrange
	var use_case = EvaluateOceanPresenceUseCase.new()
	var ocean = OceanEnvironmentData.new(-149.0)
	
	# Chunk hipotético de montanha (min=-100.0m, acima de -149.0m)
	var chunk_data = TerrainChunkData.new()
	var chunk_meta = {
		"chunk_name": "mountain_chunk",
		"chunk_indices": [10, 10],
		"grid_resolution": [256, 256],
		"cell_size_meters": [2.438, 2.438],
		"chunk_dimensions_meters": [624.15, 624.15],
		"world_origin_meters": [0.0, -100.0, 0.0],
		"altitude_meters": {
			"min": -100.0,
			"max": 50.0
		}
	}
	chunk_data.from_meta_dictionary(chunk_meta)

	# Act
	var requires_water = use_case.should_instantiate_water(chunk_data, ocean)

	# Assert
	assert_false(requires_water, "Chunk de montanha alta não deve instanciar água")


func test_oceano_desabilitado_nunca_instancia() -> void:
	# Arrange
	var use_case = EvaluateOceanPresenceUseCase.new()
	var ocean = OceanEnvironmentData.new(-149.0)
	ocean.enabled = false
	
	# Mesmo para chunk marítimo profundo (17_24)
	var chunk_data = TerrainChunkData.new()
	var chunk_meta = {
		"chunk_name": "17_24",
		"chunk_indices": [17, 24],
		"grid_resolution": [256, 256],
		"cell_size_meters": [2.438, 2.438],
		"chunk_dimensions_meters": [624.15, 624.15],
		"world_origin_meters": [-1872.0, -184.6, 4368.0],
		"altitude_meters": {
			"min": -184.6,
			"max": -149.3
		}
	}
	chunk_data.from_meta_dictionary(chunk_meta)

	# Act
	var requires_water = use_case.should_instantiate_water(chunk_data, ocean)

	# Assert
	assert_false(requires_water, "Se ocean_data.enabled for false, não deve instanciar água")

