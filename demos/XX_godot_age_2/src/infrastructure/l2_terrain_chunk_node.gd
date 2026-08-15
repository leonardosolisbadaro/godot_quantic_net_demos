## @file l2_terrain_chunk_node.gd
## @path res://src/infrastructure/l2_terrain_chunk_node.gd
##
## @description
## Nó de infraestrutura 3D que orquestra a apresentação visual (Mesh + Shader)
## e o corpo físico de colisão local (StaticBody3D + HeightMapShape3D) de um chunk.
##
## @created 2026-08-15
## @updated 2026-08-15
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)
extends Node3D

const TerrainChunkData = preload("res://src/domain/terrain_chunk_data.gd")
const BuildChunkCollisionUseCase = preload("res://src/use_cases/build_chunk_collision_use_case.gd")
const ChunkResourceAdapter = preload("res://src/adapters/chunk_resource_adapter.gd")
const TerrainShader = preload("res://src/infrastructure/l2_terrain.gdshader")

var chunk_data: TerrainChunkData
var visual_instance: Node3D
var visual_mesh: MeshInstance3D
var static_body: StaticBody3D
var collision_shape: CollisionShape3D


func setup(
	p_chunk_name: String,
	p_adapter: ChunkResourceAdapter,
	p_collision_uc: BuildChunkCollisionUseCase
) -> bool:
	chunk_data = p_adapter.load_chunk_meta(p_chunk_name)
	if not chunk_data:
		push_error("Falha ao carregar metadados do chunk: " + p_chunk_name)
		return false

	# 1. Posicionamento do Chunk no Mundo
	position = chunk_data.world_origin

	# 2. Configuração Visual (GLB + Shader)
	var recipe = p_adapter.load_chunk_recipe(p_chunk_name)
	_setup_visual(p_chunk_name, p_adapter, recipe)

	# 3. Configuração Física (HeightMapShape3D)
	var hf_bytes = p_adapter.load_heightfield_bytes(p_chunk_name)
	_setup_collision(hf_bytes, p_collision_uc)

	return true


func _setup_visual(chunk_name: String, adapter: ChunkResourceAdapter, recipe: Dictionary) -> void:
	var glb_path = "%s/%s/client/%s_visual.glb" % [adapter.base_maps_path, chunk_name, chunk_name]
	if ResourceLoader.exists(glb_path):
		var glb_scene = load(glb_path) as PackedScene
		if glb_scene:
			visual_instance = glb_scene.instantiate()
			add_child(visual_instance)
			visual_mesh = _find_mesh_instance(visual_instance)

	if visual_mesh and not recipe.is_empty():
		var mat = ShaderMaterial.new()
		mat.shader = TerrainShader

		# Configura Lightmap
		var lm_file = recipe.get("lightmap")
		if lm_file and lm_file is String and not lm_file.is_empty():
			var lm_tex = adapter.load_texture_file(chunk_name, lm_file)
			if lm_tex:
				mat.set_shader_parameter("lightmap_tex", lm_tex)
				mat.set_shader_parameter("has_lightmap", true)
			else:
				mat.set_shader_parameter("has_lightmap", false)
		else:
			mat.set_shader_parameter("has_lightmap", false)

		# Configura Splatmaps
		var splatmaps = recipe.get("splatmaps", [])
		for i in range(splatmaps.size()):
			var s_file = splatmaps[i]
			if s_file and s_file is String and not s_file.is_empty():
				var s_tex = adapter.load_texture_file(chunk_name, s_file)
				if s_tex:
					mat.set_shader_parameter("splatmap_%d" % i, s_tex)

		# Configura Texturas das Camadas
		var layers = recipe.get("layers", [])
		var has_base_tex = false

		for l in layers:
			var idx = int(l.get("layer_index", 0))
			var tex_file = l.get("texture_file")
			var u_sc = float(l.get("u_scale", 1.0))
			var v_sc = float(l.get("v_scale", 1.0))

			if tex_file and tex_file is String and not tex_file.is_empty():
				var t_tex = adapter.load_texture_file(chunk_name, tex_file)
				if t_tex:
					if idx == 0:
						mat.set_shader_parameter("tex_base", t_tex)
						mat.set_shader_parameter("uv_scale_base", Vector2(u_sc, v_sc))
						has_base_tex = true
					else:
						mat.set_shader_parameter("tex_layer_%d" % idx, t_tex)
						mat.set_shader_parameter("uv_scale_%d" % idx, Vector2(u_sc, v_sc))

		# Se não houver textura base explícita, injeta uma textura sólida padrão (Grama Aden)
		if not has_base_tex:
			var default_img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
			default_img.fill(Color(0.25, 0.38, 0.20, 1.0))
			var default_tex = ImageTexture.create_from_image(default_img)
			mat.set_shader_parameter("tex_base", default_tex)

		visual_mesh.material_override = mat


func _setup_collision(hf_bytes: PackedByteArray, collision_uc: BuildChunkCollisionUseCase) -> void:
	if hf_bytes.is_empty() or not chunk_data:
		return

	var shape = collision_uc.from_raw_bytes(hf_bytes, chunk_data.grid_width, chunk_data.grid_depth)
	if not shape:
		return

	static_body = StaticBody3D.new()
	collision_shape = CollisionShape3D.new()
	collision_shape.shape = shape

	# Ajusta a escala da colisão para coincidir com o tamanho de célula em metros
	collision_shape.scale = Vector3(chunk_data.cell_size_x, 1.0, chunk_data.cell_size_z)

	static_body.add_child(collision_shape)
	add_child(static_body)


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found = _find_mesh_instance(child)
		if found:
			return found
	return null
