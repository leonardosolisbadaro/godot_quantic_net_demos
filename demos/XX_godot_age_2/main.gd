## @file main.gd
## @path res://main.gd
##
## @description
## Ponto de entrada da Demo XX_godot_age_2. "...descricao da demo...".
##
## @created 2026-08-15
## @updated 2026-08-15
##
## @author Leonardo S. BadarÃ³ (with Gemini 3.1 Pro - High)
extends Node


func _ready() -> void:
	print(">>> Nova Demo Iniciada <<<")
	var qn = get_node_or_null("/root/QuanticNet")
	if not qn:
		print("ERRO: Autoload QuanticNet nao encontrado.")
		return

	var args = OS.get_cmdline_user_args()
	if "--server" in args:
		qn.host(8080, "secret")
		print("Servidor escutando...")
	else:
		qn.join("127.0.0.1", 8080, "secret")
		print("Cliente conectando...")
