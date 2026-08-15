## @file build_chunk_collision_use_case.gd
## @path res://src/use_cases/build_chunk_collision_use_case.gd
##
## @description
## Caso de uso responsável por construir e configurar a forma de colisão matemática
## HeightMapShape3D para o motor de física local da Godot Engine.
##
## @created 2026-08-15
## @updated 2026-08-15
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)

const TerrainChunkData = preload("res://src/domain/terrain_chunk_data.gd")


func execute(height_data: PackedFloat32Array, width: int, depth: int) -> HeightMapShape3D:
	if height_data.is_empty() or width <= 0 or depth <= 0:
		return null

	var shape = HeightMapShape3D.new()
	shape.map_width = width
	shape.map_depth = depth
	shape.map_data = height_data
	return shape


func from_raw_bytes(bytes: PackedByteArray, width: int, depth: int) -> HeightMapShape3D:
	var expected_floats = width * depth
	if bytes.size() < expected_floats * 4:
		return null

	var float_array = bytes.to_float32_array()
	return execute(float_array, width, depth)
