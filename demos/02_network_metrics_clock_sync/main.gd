## @file main.gd
extends Node

const TelemetryAdapter = preload("res://src/adapters/telemetry_adapter.gd")

var _adapter: TelemetryAdapter
var _is_server: bool = false

# UI Elements
var _lbl_state: Label
var _lbl_rtt_current: Label
var _lbl_rtt_avg: Label
var _lbl_rtt_1_low: Label
var _lbl_loss: Label
var _btn_netem: Button

func _ready() -> void:
	print(">>> Demo 02 Iniciada: Network Metrics & Clock Sync <<<")
	
	_adapter = TelemetryAdapter.new()
	add_child(_adapter)
	_adapter.metrics_updated.connect(_on_metrics_updated)
	_adapter.connection_state_changed.connect(_on_state_changed)
	
	_build_dashboard()
	
	var args = OS.get_cmdline_user_args()
	if args.has("--server"):
		_is_server = true
		DisplayServer.window_set_title("SERVER (Authority)")
		_adapter.host_server(4242, "secret")
	elif args.has("--client"):
		DisplayServer.window_set_title("CLIENT (Dashboard)")
		_adapter.join_client("127.0.0.1", 4242, "secret", false)

func _build_dashboard() -> void:
	var canvas = CanvasLayer.new()
	add_child(canvas)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(350, 0)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -370
	panel.offset_top = 20
	panel.offset_right = -20
	canvas.add_child(panel)
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.05, 0.05, 0.08, 0.9)
	bg_style.corner_radius_top_left = 8
	bg_style.corner_radius_top_right = 8
	bg_style.corner_radius_bottom_left = 8
	bg_style.corner_radius_bottom_right = 8
	bg_style.content_margin_left = 16
	bg_style.content_margin_right = 16
	bg_style.content_margin_top = 16
	bg_style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", bg_style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "NETWORK PROFILER"
	title.add_theme_color_override("font_color", Color.AQUAMARINE)
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)
	
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	_lbl_state = _add_metric_row(vbox, "Status:", "DISCONNECTED", Color.GRAY)
	_lbl_rtt_current = _add_metric_row(vbox, "Ping Atual:", "0 ms")
	_lbl_rtt_avg = _add_metric_row(vbox, "Ping Médio:", "0 ms")
	_lbl_rtt_1_low = _add_metric_row(vbox, "1% Low (Picos):", "0 ms", Color.ORANGE)
	_lbl_loss = _add_metric_row(vbox, "Packet Loss:", "0.0%", Color.INDIAN_RED)
	
	if not _is_server:
		var sep2 = HSeparator.new()
		vbox.add_child(sep2)
		
		_btn_netem = Button.new()
		_btn_netem.text = "Simular Instabilidade (Netem)"
		_btn_netem.toggle_mode = true
		_btn_netem.toggled.connect(_on_netem_toggled)
		vbox.add_child(_btn_netem)

func _add_metric_row(parent: Control, label_text: String, default_value: String, val_color: Color = Color.WHITE) -> Label:
	var hbox = HBoxContainer.new()
	var lbl_title = Label.new()
	lbl_title.text = label_text
	lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_title.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	
	var lbl_val = Label.new()
	lbl_val.text = default_value
	lbl_val.add_theme_color_override("font_color", val_color)
	lbl_val.add_theme_font_size_override("font_size", 16)
	
	hbox.add_child(lbl_title)
	hbox.add_child(lbl_val)
	parent.add_child(hbox)
	
	return lbl_val

func _on_state_changed(state_name: String, is_connected: bool) -> void:
	if not is_instance_valid(_lbl_state): return
	_lbl_state.text = state_name
	if is_connected:
		_lbl_state.add_theme_color_override("font_color", Color.GREEN_YELLOW)
	else:
		_lbl_state.add_theme_color_override("font_color", Color.YELLOW)

func _on_metrics_updated(data: Dictionary) -> void:
	if not is_instance_valid(_lbl_rtt_current): return
	
	_lbl_rtt_current.text = "%.1f ms" % data["rtt_current"]
	_lbl_rtt_avg.text = "%.1f ms" % data["rtt_avg"]
	_lbl_rtt_1_low.text = "%.1f ms" % data["rtt_1_low"]
	_lbl_loss.text = "%.1f %%" % data["loss_pct"]
	
	# Coloração dinâmica para Packet Loss
	if data["loss_pct"] > 1.0:
		_lbl_loss.add_theme_color_override("font_color", Color.RED)
	else:
		_lbl_loss.add_theme_color_override("font_color", Color.GREEN_YELLOW)

func _on_netem_toggled(pressed: bool) -> void:
	print("Reconectando com Netem = ", pressed)
	_adapter.disconnect_peer()
	# Dá um tempinho para a rede limpar
	await get_tree().create_timer(0.5).timeout
	_adapter.join_client("127.0.0.1", 4242, "secret", pressed)