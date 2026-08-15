## @file load_server_heightfield_use_case.gd
## @path res://src/use_cases/load_server_heightfield_use_case.gd
##
## @description
## Caso de uso responsável por ler os artefatos de servidor (heightfield.bin e chunk_meta.json)
## e instanciar a entidade de domínio puro HeightfieldSampler.
##
## @created 2026-08-15
## @updated 2026-08-15
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)

const ChunkResourceAdapter = preload("res://src/adapters/chunk_resource_adapter.gd")
const HeightfieldSampler = preload("res://src/domain/heightfield_sampler.gd")


func execute(chunk_name: String, adapter: ChunkResourceAdapter) -> HeightfieldSampler:
	var meta = adapter.load_chunk_meta(chunk_name)
	if not meta:
		return null

	var hf_bytes = adapter.load_heightfield_bytes(chunk_name)
	if hf_bytes.is_empty():
		return null

	var heights_array = hf_bytes.to_float32_array()
	if heights_array.is_empty():
		return null

	return HeightfieldSampler.new(
		heights_array,
		meta.grid_width,
		meta.grid_depth,
		meta.cell_size_x,
		meta.cell_size_z,
		meta.world_origin,
		meta.total_width_meters,
		meta.total_depth_meters
	)
