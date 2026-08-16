## @file ocean_tile_node.gd
## @path res://src/infrastructure/ocean_tile_node.gd
##
## @description
## Nó visual 3D que representa o tile de água/mar cobrindo a área horizontal
## de um chunk ($624.2\text{m} \times 624.2\text{m}$) na cota exata do nível do mar.
## Utiliza uma malha plana otimizada (PlaneMesh) e compartilha o material de shader.
##
## @created 2026-08-16
## @updated 2026-08-16
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)
extends Node3D

const OceanEnvironmentData = preload("res://src/domain/ocean_environment_data.gd")
const TerrainChunkData = preload("res://src/domain/terrain_chunk_data.gd")

var mesh_instance: MeshInstance3D


func setup(
	chunk_data: TerrainChunkData,
	ocean_data: OceanEnvironmentData,
	shared_material: ShaderMaterial
) -> void:
	if not chunk_data or not ocean_data:
		return

	# Posiciona o plano exatamente no nível do mar global
	# (Em relação à origem de mundo do chunk pai)
	var local_water_y = ocean_data.sea_level_y - chunk_data.world_origin.y
	position = Vector3(0.0, local_water_y, 0.0)

	mesh_instance = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(chunk_data.total_width_meters, chunk_data.total_depth_meters)
	plane.subdivide_width = 2
	plane.subdivide_depth = 2

	mesh_instance.mesh = plane
	mesh_instance.material_override = shared_material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	add_child(mesh_instance)
