## @file server_world_manager.gd
## @path res://src/infrastructure/server_world_manager.gd
##
## @description
## Gerenciador de mundo autoritativo no Servidor Headless.
## Mantém os samplers de terreno de todos os chunks ativos em RAM sem overhead gráfico.
##
## @created 2026-08-15
## @updated 2026-08-15
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)
extends Node

const ChunkResourceAdapter = preload("res://src/adapters/chunk_resource_adapter.gd")
const LoadServerHeightfieldUseCase = preload("res://src/use_cases/load_server_heightfield_use_case.gd")
const ValidatePlayerMovementUseCase = preload("res://src/use_cases/validate_player_movement_use_case.gd")
const HeightfieldSampler = preload("res://src/domain/heightfield_sampler.gd")

var _adapter: ChunkResourceAdapter
var _load_hf_uc: LoadServerHeightfieldUseCase
var _validate_move_uc: ValidatePlayerMovementUseCase

# Dicionário de Samplers: { "16_24": HeightfieldSampler }
var _samplers: Dictionary = {}


func _init(p_maps_path: String = "res://assets/maps") -> void:
	_adapter = ChunkResourceAdapter.new(p_maps_path)
	_load_hf_uc = LoadServerHeightfieldUseCase.new()
	_validate_move_uc = ValidatePlayerMovementUseCase.new()


func load_chunk(chunk_name: String) -> bool:
	if _samplers.has(chunk_name):
		return true

	var sampler = _load_hf_uc.execute(chunk_name, _adapter)
	if not sampler:
		push_error("[SERVER] Falha ao carregar Heightfield do chunk: " + chunk_name)
		return false

	_samplers[chunk_name] = sampler
	return true


func load_cluster(chunk_names: Array) -> void:
	for c_name in chunk_names:
		load_chunk(str(c_name))
	print("[SERVER] Samplers de terreno ativos em RAM: %d chunks" % _samplers.size())


func get_height_at(world_x: float, world_z: float) -> float:
	var sampler = find_sampler_at(world_x, world_z)
	if sampler:
		return sampler.get_height_at(world_x, world_z)
	return 0.0


func find_sampler_at(world_x: float, world_z: float) -> HeightfieldSampler:
	# Encontra o sampler que contém a coordenada de mundo
	for c_name in _samplers:
		var s: HeightfieldSampler = _samplers[c_name]
		var half_w = s.total_width / 2.0
		var half_d = s.total_depth / 2.0
		if (
			world_x >= (s.world_origin.x - half_w) and world_x <= (s.world_origin.x + half_w) and
			world_z >= (s.world_origin.z - half_d) and world_z <= (s.world_origin.z + half_d)
		):
			return s

	# Se não encontrar no bounding box exato, retorna o primeiro disponível como fallback
	if not _samplers.is_empty():
		return _samplers.values()[0]
	return null


func validate_player_move(
	current_pos: Vector3,
	requested_pos: Vector3,
	delta_time: float,
	max_speed: float = 30.0
) -> Dictionary:
	var sampler = find_sampler_at(requested_pos.x, requested_pos.z)
	return _validate_move_uc.execute(current_pos, requested_pos, delta_time, max_speed, sampler)
