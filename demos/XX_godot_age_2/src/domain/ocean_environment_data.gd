## @file ocean_environment_data.gd
## @path res://src/domain/ocean_environment_data.gd
##
## @description
## Entidade de domínio pura que encapsula as configurações macro do oceano global:
## cota do nível do mar (sea_level_y), cores de profundidade, velocidade das ondas,
## atenuação de turbidez e propriedades físicas/visuais.
## Totalmente agnóstica de nós da Engine e de Rede.
##
## @created 2026-08-16
## @updated 2026-08-16
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)
extends RefCounted

var enabled: bool = true
var sea_level_y: float = -149.0
var deep_color: Color = Color(0.02, 0.08, 0.18, 0.95)
var shallow_color: Color = Color(0.12, 0.42, 0.55, 0.65)
var foam_color: Color = Color(0.92, 0.96, 1.0, 0.9)
var wave_speed: float = 0.03
var wave_scale: float = 0.08
var foam_thickness: float = 0.8
var water_murkiness: float = 0.08
var metallic: float = 0.1
var roughness: float = 0.15


func _init(p_sea_level_y: float = -149.0) -> void:
	sea_level_y = p_sea_level_y


func is_submerged(world_y: float) -> bool:
	return enabled and world_y < sea_level_y


func get_water_depth_at(world_y: float) -> float:
	if not enabled or world_y >= sea_level_y:
		return 0.0
	return sea_level_y - world_y


static func from_dictionary(dict: Dictionary) -> RefCounted:
	var instance = load("res://src/domain/ocean_environment_data.gd").new()
	if dict.has("enabled"):
		instance.enabled = bool(dict["enabled"])
	if dict.has("sea_level_y"):
		instance.sea_level_y = float(dict["sea_level_y"])
	if dict.has("wave_speed"):
		instance.wave_speed = float(dict["wave_speed"])
	if dict.has("wave_scale"):
		instance.wave_scale = float(dict["wave_scale"])
	if dict.has("foam_thickness"):
		instance.foam_thickness = float(dict["foam_thickness"])
	if dict.has("water_murkiness"):
		instance.water_murkiness = float(dict["water_murkiness"])
	if dict.has("metallic"):
		instance.metallic = float(dict["metallic"])
	if dict.has("roughness"):
		instance.roughness = float(dict["roughness"])

	if dict.has("deep_color") and dict["deep_color"] is Array and dict["deep_color"].size() >= 4:
		instance.deep_color = Color(
			float(dict["deep_color"][0]),
			float(dict["deep_color"][1]),
			float(dict["deep_color"][2]),
			float(dict["deep_color"][3])
		)
	if dict.has("shallow_color") and dict["shallow_color"] is Array and dict["shallow_color"].size() >= 4:
		instance.shallow_color = Color(
			float(dict["shallow_color"][0]),
			float(dict["shallow_color"][1]),
			float(dict["shallow_color"][2]),
			float(dict["shallow_color"][3])
		)
	if dict.has("foam_color") and dict["foam_color"] is Array and dict["foam_color"].size() >= 4:
		instance.foam_color = Color(
			float(dict["foam_color"][0]),
			float(dict["foam_color"][1]),
			float(dict["foam_color"][2]),
			float(dict["foam_color"][3])
		)

	return instance
