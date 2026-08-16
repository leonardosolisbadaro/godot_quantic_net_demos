## @file chunk_resource_adapter.gd
## @path res://src/adapters/chunk_resource_adapter.gd
##
## @description
## Adaptador de infraestrutura e IO que localiza e carrega metadados,
## receitas de terreno, malhas GLB, texturas PNG e buffers binários do disco.
##
## @created 2026-08-15
## @updated 2026-08-15
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)

const TerrainChunkData = preload("../domain/terrain_chunk_data.gd")
const OceanEnvironmentData = preload("../domain/ocean_environment_data.gd")

var base_maps_path: String = "res://assets/maps"


func _init(p_base_path: String = "res://assets/maps") -> void:
	base_maps_path = p_base_path


func load_ocean_config() -> RefCounted:
	var config_path = "%s/sea_config.json" % base_maps_path
	if not FileAccess.file_exists(config_path):
		return OceanEnvironmentData.new()

	var file = FileAccess.open(config_path, FileAccess.READ)
	if not file:
		return OceanEnvironmentData.new()

	var json_str = file.get_as_text()
	file.close()

	var json = JSON.new()
	var err = json.parse(json_str)
	if err != OK or not (json.data is Dictionary):
		return OceanEnvironmentData.new()

	return OceanEnvironmentData.from_dictionary(json.data)



func load_chunk_meta(chunk_name: String) -> TerrainChunkData:
	var meta_path = "%s/%s/server/chunk_meta.json" % [base_maps_path, chunk_name]
	if not FileAccess.file_exists(meta_path):
		return null

	var file = FileAccess.open(meta_path, FileAccess.READ)
	if not file:
		return null

	var json_str = file.get_as_text()
	file.close()

	var json = JSON.new()
	var err = json.parse(json_str)
	if err != OK or not (json.data is Dictionary):
		return null

	var data = TerrainChunkData.new(chunk_name)
	data.from_meta_dictionary(json.data)
	return data


func load_chunk_recipe(chunk_name: String) -> Dictionary:
	var recipe_path = "%s/%s/client/terrain_recipe.json" % [base_maps_path, chunk_name]
	if not FileAccess.file_exists(recipe_path):
		return {}

	var file = FileAccess.open(recipe_path, FileAccess.READ)
	if not file:
		return {}

	var json_str = file.get_as_text()
	file.close()

	var json = JSON.new()
	var err = json.parse(json_str)
	if err != OK or not (json.data is Dictionary):
		return {}

	return json.data


func load_heightfield_bytes(chunk_name: String) -> PackedByteArray:
	var hf_path = "%s/%s/server/heightfield.bin" % [base_maps_path, chunk_name]
	if not FileAccess.file_exists(hf_path):
		return PackedByteArray()

	var file = FileAccess.open(hf_path, FileAccess.READ)
	if not file:
		return PackedByteArray()

	var bytes = file.get_buffer(file.get_length())
	file.close()
	return bytes


func load_texture_file(chunk_name: String, relative_path: Variant) -> Texture2D:
	if not relative_path or not (relative_path is String) or relative_path.is_empty():
		return null

	var full_path = "%s/%s/client/%s" % [base_maps_path, chunk_name, relative_path]
	if ResourceLoader.exists(full_path):
		return load(full_path) as Texture2D

	var global_path = ProjectSettings.globalize_path(full_path)
	if not FileAccess.file_exists(full_path) and not FileAccess.file_exists(global_path):
		return null

	var img = Image.load_from_file(global_path if FileAccess.file_exists(global_path) else full_path)
	if not img or img.is_empty():
		return null

	return ImageTexture.create_from_image(img)
