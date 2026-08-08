extends Node

func _ready() -> void:
	print(">>> Nova Demo Iniciada <<<")
	var qn = get_node_or_null("/root/QuanticNet")
	if not qn:
		print("ERRO: Autoload QuanticNet nao encontrado.")
		return
		
	var args = OS.get_cmdline_args()
	if "--server" in args:
		qn.host(8080, "secret")
		print("Servidor escutando...")
	elif "--client" in args:
		qn.join("127.0.0.1", 8080, "secret")
		print("Cliente conectando...")