## @file debug_hud.gd
## @path res://src/infrastructure/debug_hud.gd
##
## @description
## Camada de Interface de Depuração Ultraleve (CanvasLayer).
## Exibe coordenadas globais e locais relativas ao chunk ativo com throttle de 100ms
## para consumo zero de performance e garbage collection.
##
## @created 2026-08-16
## @updated 2026-08-16
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)
extends CanvasLayer

var _label_info: Label
var _last_update_ms: int = 0
const THROTTLE_MS: int = 100

var current_chunk_name: String = "--"
var chunk_origin: Vector3 = Vector3.ZERO
var target_player: Node3D = null


func _ready() -> void:
	layer = 100
	_setup_ui()


func _setup_ui() -> void:
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)

	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.12, 0.85)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.2, 0.6, 0.9, 0.8)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)

	_label_info = Label.new()
	_label_info.text = "Iniciando métricas..."
	_label_info.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	_label_info.add_theme_constant_override("outline_size", 2)
	_label_info.add_theme_color_override("font_outline_color", Color.BLACK)

	panel.add_child(_label_info)
	margin.add_child(panel)
	add_child(margin)


func _process(_delta: float) -> void:
	var now = Time.get_ticks_msec()
	if now - _last_update_ms < THROTTLE_MS:
		return
	_last_update_ms = now

	if not target_player or not is_instance_valid(target_player):
		return

	var g_pos = target_player.global_position
	var l_pos = g_pos - chunk_origin

	var text = "[ GODOTAGE II — CHUNK & POSIÇÃO ]\n"
	text += "Chunk Atual: %s\n" % current_chunk_name
	text += "Global:  X: %8.2f  Y: %8.2f  Z: %8.2f\n" % [g_pos.x, g_pos.y, g_pos.z]
	text += "Local:   X: %8.2f  Y: %8.2f  Z: %8.2f\n" % [l_pos.x, l_pos.y, l_pos.z]
	text += "FPS: %d | [F1] Colisor | [F2] Wireframe" % Engine.get_frames_per_second()

	_label_info.text = text


func update_chunk_context(p_chunk_name: String, p_origin: Vector3) -> void:
	current_chunk_name = p_chunk_name
	chunk_origin = p_origin
