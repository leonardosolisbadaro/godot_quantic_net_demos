## @file evaluate_ocean_presence_use_case.gd
## @path res://src/use_cases/evaluate_ocean_presence_use_case.gd
##
## @description
## Caso de uso puro que avalia se um chunk de terreno específico necessita
## da instanciação de um tile de água/oceano, comparando a cota mínima do relevo
## do chunk contra o nível global do mar configurado no OceanEnvironmentData.
## Totalmente agnóstico à Engine visual e à Rede.
##
## @created 2026-08-16
## @updated 2026-08-16
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)
extends RefCounted

const OceanEnvironmentData = preload("res://src/domain/ocean_environment_data.gd")
const TerrainChunkData = preload("res://src/domain/terrain_chunk_data.gd")


## Determina se o chunk deve possuir uma superfície de mar visível
func should_instantiate_water(chunk_data: TerrainChunkData, ocean_data: OceanEnvironmentData) -> bool:
	if not chunk_data or not ocean_data or not ocean_data.enabled:
		return false
	
	# Se a cota mínima de altitude do chunk for inferior ou igual ao nível do mar, o relevo toca a água
	return chunk_data.min_altitude <= ocean_data.sea_level_y
