## @file main.gd
extends Node

const QuanticNetAdapter = preload("res://src/adapters/quantic_net_adapter.gd")
var _adapter: QuanticNetAdapter
var _lbl_status: Label

func _ready() -> void:
	print(">>> Demo 01 Iniciada <<<")
	
	# Limitamos o framerate para parear com o Tick Rate do servidor (60Hz)
	Engine.max_fps = 60
	
	_adapter = QuanticNetAdapter.new()
	add_child(_adapter)
	_adapter.session_state_updated.connect(_on_state_updated)
	
	_build_ui()
	
	var args = OS.get_cmdline_user_args()
	if args.has("--server"):
		DisplayServer.window_set_title("SERVER (Authority)")
		_adapter.host_server(4242, "secret")
	elif args.has("--client"):
		DisplayServer.window_set_title("CLIENT")
		# Cliente já invocado via terminal (Auto-Move logic for tests)
		_adapter.join_server("127.0.0.1", 4242, "secret")

func _build_ui() -> void:
	var canvas = CanvasLayer.new()
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	
	var vbox = VBoxContainer.new()
	
	_lbl_status = Label.new()
	_lbl_status.text = "State: DISCONNECTED"
	_lbl_status.add_theme_font_size_override("font_size", 24)
	_lbl_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_lbl_status)
	
	var btn = Button.new()
	btn.text = "Trigger Handshake (Join)"
	btn.custom_minimum_size = Vector2(200, 50)
	btn.pressed.connect(func(): _adapter.join_server("127.0.0.1", 4242, "secret"))
	vbox.add_child(btn)
	
	panel.add_child(vbox)
	canvas.add_child(panel)
	add_child(canvas)

func _on_state_updated(_new_state: int) -> void:
	_lbl_status.text = "State: " + _adapter.get_current_state_name()