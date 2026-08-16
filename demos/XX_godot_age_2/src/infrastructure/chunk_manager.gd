## @file chunk_manager.gd
## @path res://src/infrastructure/chunk_manager.gd
##
## @description
## Gerenciador de streaming contínuo de chunks de terreno no cliente.
## Monitora a coordenada do jogador e gerencia o ciclo de vida dos nós 3D.
##
## @created 2026-08-15
## @updated 2026-08-15
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)
extends Node3D

const ChunkResourceAdapter = preload("../adapters/chunk_resource_adapter.gd")
const BuildChunkCollisionUseCase = preload("../use_cases/build_chunk_collision_use_case.gd")
const L2TerrainChunkNode = preload("l2_terrain_chunk_node.gd")

var _adapter: ChunkResourceAdapter
var _collision_uc: BuildChunkCollisionUseCase
var _loaded_chunks: Dictionary = {}  # { "16_24": L2TerrainChunkNode }


func _init(p_maps_path: String = "res://assets/maps") -> void:
	_adapter = ChunkResourceAdapter.new(p_maps_path)
	_collision_uc = BuildChunkCollisionUseCase.new()


func load_chunk(chunk_name: String) -> L2TerrainChunkNode:
	if _loaded_chunks.has(chunk_name):
		return _loaded_chunks[chunk_name]

	var chunk_node = L2TerrainChunkNode.new()
	chunk_node.name = "Chunk_" + chunk_name
	add_child(chunk_node)

	var success = chunk_node.setup(chunk_name, _adapter, _collision_uc)
	if not success:
		chunk_node.queue_free()
		return null

	_loaded_chunks[chunk_name] = chunk_node
	return chunk_node


func unload_chunk(chunk_name: String) -> void:
	if _loaded_chunks.has(chunk_name):
		var chunk_node = _loaded_chunks[chunk_name]
		_loaded_chunks.erase(chunk_name)
		chunk_node.queue_free()


func load_cluster(chunk_names: Array) -> void:
	for c_name in chunk_names:
		load_chunk(str(c_name))


func is_chunk_loaded(chunk_name: String) -> bool:
	return _loaded_chunks.has(chunk_name)


func get_loaded_chunks_count() -> int:
	return _loaded_chunks.size()
