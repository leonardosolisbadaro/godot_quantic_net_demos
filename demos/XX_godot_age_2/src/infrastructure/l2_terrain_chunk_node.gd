## @file l2_terrain_chunk_node.gd
## @path res://src/infrastructure/l2_terrain_chunk_node.gd
##
## @description
## Nó de infraestrutura 3D que orquestra a apresentação visual (Mesh + Shader)
## e o corpo físico de colisão contínua (StaticBody3D + Trimesh / ConcavePolygonShape3D)
## eliminando frestas entre chunks vizinhos.
##
## @created 2026-08-15
## @updated 2026-08-16
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)
extends Node3D

const TerrainChunkData = preload("../domain/terrain_chunk_data.gd")
const BuildChunkCollisionUseCase = preload("../use_cases/build_chunk_collision_use_case.gd")
const ChunkResourceAdapter = preload("../adapters/chunk_resource_adapter.gd")
const TerrainShader = preload("l2_terrain.gdshader")

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

	# 3. Configuração Física Contínua (Trimesh ConcavePolygonShape3D)
	_setup_collision()

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

		# Configura Splatmaps
		var splatmaps = recipe.get("splatmaps", [])
		for i in range(splatmaps.size()):
			var s_file = splatmaps[i]
			if s_file and s_file is String and not s_file.is_empty():
				var s_tex = adapter.load_texture_file(chunk_name, s_file)
				if s_tex:
					mat.set_shader_parameter("splatmap_%d" % i, s_tex)

		# Configura Texturas das Camadas e ativa flags
		var layers = recipe.get("layers", [])
		var has_base_tex = false
		var extra_layers_count = 0

		for l in layers:
			var idx = int(l.get("layer_index", 0))
			var tex_file = l.get("texture_file")
			if not tex_file or (tex_file is String and tex_file.is_empty()):
				tex_file = l.get("diffuse_texture")
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
						mat.set_shader_parameter("has_layer_%d" % idx, true)
						extra_layers_count += 1

		# Se for um chunk sem camadas extras (ex: mar/oceano 17_24), harmoniza a textura base com o solo de Aden
		if extra_layers_count == 0:
			var common_tex = adapter.load_texture_file("16_24", "textures/layer_1_tex_SL_S6.png")
			if common_tex:
				mat.set_shader_parameter("tex_base", common_tex)
				has_base_tex = true

		# Se não houver textura base explícita, injeta uma textura sólida padrão (Grama Aden)
		if not has_base_tex:
			var default_img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
			default_img.fill(Color(0.25, 0.38, 0.20, 1.0))
			var default_tex = ImageTexture.create_from_image(default_img)
			mat.set_shader_parameter("tex_base", default_tex)

		visual_mesh.material_override = mat


func _setup_collision() -> void:
	if not visual_mesh or not visual_mesh.mesh:
		return

	# Cria colisão Trimesh contínua eliminando frestas físicas entre chunks
	var shape = visual_mesh.mesh.create_trimesh_shape()
	if not shape:
		return

	static_body = StaticBody3D.new()
	collision_shape = CollisionShape3D.new()
	collision_shape.shape = shape

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
