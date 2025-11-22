extends Node2D

@export var jogador1: RigidBody2D
@export var jogador2: RigidBody2D
@export var bola: RigidBody2D
@export var tempo_espera_turno: float = 1.0
@export var area_gol_jogador1: Area2D  
@export var area_gol_jogador2: Area2D  

enum Turno { JOGADOR1, JOGADOR2, AGUARDANDO }
var turno_atual: Turno = Turno.JOGADOR1
var ultimo_jogador: int = 0
var aguardando_movimento: bool = false
var timer_espera: float = 0.0

# Sistema de placar
var gols_jogador1: int = 0
var gols_jogador2: int = 0
var placar_label: Label = null

var posicao_inicial_jogador1: Vector2 = Vector2.ZERO
var posicao_inicial_jogador2: Vector2 = Vector2.ZERO

signal turno_mudou(turno: Turno)
signal gol_marcado(jogador: int, placar_j1: int, placar_j2: int)


func _ready() -> void:
	if not jogador1 and has_node("Jogador1"):
		jogador1 = get_node("Jogador1")
	if not jogador2 and has_node("Jogador2"):
		jogador2 = get_node("Jogador2")
	if not bola and has_node("Bola"):
		bola = get_node("Bola")

	# Salva posições iniciais
	if jogador1:
		posicao_inicial_jogador1 = jogador1.global_position
		print("Posição inicial do Jogador 1 registrada: ", posicao_inicial_jogador1)
	if jogador2:
		posicao_inicial_jogador2 = jogador2.global_position
		print("Posição inicial do Jogador 2 registrada: ", posicao_inicial_jogador2)
	if bola:
		print("Posição inicial da Bola (salva na bola): ", bola.posicao_inicial)
		print("Posição atual da Bola: ", bola.global_position)

	# Conecta o Label do placar
	if not placar_label and has_node("../Placar"):
		placar_label = get_node("../Placar")
		print("Placar Label conectado: ", placar_label)
		_atualizar_placar()
	else:
		print("AVISO: Label do placar não encontrado no caminho ../Placar")

	# Conecta áreas de gol se não foram exportadas
	if not area_gol_jogador1 and has_node("../AreaGolJogador1"):
		area_gol_jogador1 = get_node("../AreaGolJogador1")
	if not area_gol_jogador2 and has_node("../AreaGolJogador2"):
		area_gol_jogador2 = get_node("../AreaGolJogador2")

	if jogador1 and jogador1.has_signal("jogador_soltou"):
		jogador1.jogador_soltou.connect(_on_jogador1_soltou)

	if jogador2 and jogador2.has_signal("jogador_soltou"):
		jogador2.jogador_soltou.connect(_on_jogador2_soltou)

	# Conecta detecção de gols
	if area_gol_jogador1:
		area_gol_jogador1.body_entered.connect(_on_gol_jogador1_body_entered)
	if area_gol_jogador2:
		area_gol_jogador2.body_entered.connect(_on_gol_jogador2_body_entered)

	_iniciar_turno_jogador1()


func _process(delta: float) -> void:
	if turno_atual == Turno.AGUARDANDO:
		timer_espera -= delta
		timer_espera -= delta
		if timer_espera <= 0 and _tudo_parado():
			_proximo_turno()


func _iniciar_turno_jogador1() -> void:
	turno_atual = Turno.JOGADOR1
	if jogador1:
		jogador1.set("pode_jogar", true)
	if jogador2:
		jogador2.set("pode_jogar", false)
	turno_mudou.emit(Turno.JOGADOR1)
	print("--- Turno do Jogador 1 ---")


func _iniciar_turno_jogador2() -> void:
	turno_atual = Turno.JOGADOR2
	if jogador1:
		jogador1.set("pode_jogar", false)
	if jogador2:
		jogador2.set("pode_jogar", true)
		await get_tree().create_timer(0.5).timeout
		if jogador2 and jogador2.has_method("executar_jogada_ia"):
			jogador2.call("executar_jogada_ia")
	turno_mudou.emit(Turno.JOGADOR2)
	print("--- Turno do Jogador 2 (IA) ---")


func _on_jogador1_soltou(_jogador) -> void:
	if turno_atual == Turno.JOGADOR1:
		ultimo_jogador = 1
		turno_atual = Turno.AGUARDANDO
		if jogador1:
			jogador1.set("pode_jogar", false)
		timer_espera = tempo_espera_turno


func _on_jogador2_soltou(_jogador) -> void:
	if turno_atual == Turno.JOGADOR2:
		ultimo_jogador = 2
		turno_atual = Turno.AGUARDANDO
		if jogador2:
			jogador2.set("pode_jogar", false)
		timer_espera = tempo_espera_turno


func _proximo_turno() -> void:
	if turno_atual == Turno.AGUARDANDO:
		if ultimo_jogador == 1:
			_iniciar_turno_jogador2()
		else:
			_iniciar_turno_jogador1()


func _tudo_parado() -> bool:
	var jogador1_parado = true
	var jogador2_parado = true
	var bola_parada = true
	
	if jogador1:
		jogador1_parado = jogador1.linear_velocity.length() < 5.0
	if jogador2:
		jogador2_parado = jogador2.linear_velocity.length() < 5.0
	if bola:
		bola_parada = bola.linear_velocity.length() < 5.0
	
	return jogador1_parado and jogador2_parado and bola_parada


func _on_gol_jogador1_body_entered(body: Node2D) -> void:
	"""Detecta quando a bola entra no gol do jogador 1 (jogador 2 marcou)"""
	if body == bola:
		_marcar_gol(2)


func _on_gol_jogador2_body_entered(body: Node2D) -> void:
	"""Detecta quando a bola entra no gol do jogador 2 (jogador 1 marcou)"""
	if body == bola:
		_marcar_gol(1)


# Métodos corrigidos e unificados
func _marcar_gol(jogador_marcou: int) -> void:
	"""Registra o gol e reinicia a posição da bola"""
	if jogador_marcou == 1:
		gols_jogador1 += 1
		print("\n⚽ GOL DO JOGADOR 1! Placar: ", gols_jogador1, " x ", gols_jogador2)
	else:
		gols_jogador2 += 1
		print("\n⚽ GOL DO JOGADOR 2! Placar: ", gols_jogador1, " x ", gols_jogador2)
	
	print("Marcando gol para o jogador: ", jogador_marcou)
	print("Placar antes de atualizar Label: Jogador 1 - %d | Jogador 2 - %d" % [gols_jogador1, gols_jogador2])
	
	# Atualiza o placar no Label
	_atualizar_placar()
	
	# Verifica vitória
	_verificar_vitoria()
	
	# Emite sinal de gol
	gol_marcado.emit(jogador_marcou, gols_jogador1, gols_jogador2)
	
	# Aguarda um pouco antes de resetar
	await get_tree().create_timer(1.5).timeout
	
	# Reseta posições
	_resetar_posicoes()
	
	# Quem sofreu o gol começa jogando
	if jogador_marcou == 1:
		_iniciar_turno_jogador2()
	else:
		_iniciar_turno_jogador1()


func _verificar_vitoria() -> void:
	"""Verifica se algum jogador atingiu 3 gols e reseta o placar."""
	if gols_jogador1 == 3:
		print("\n🎉 Vitória do Jogador 1! Placar final: 3 x %d" % gols_jogador2)
		_resetar_placar_completo()
	elif gols_jogador2 == 3:
		print("\n🎉 Vitória do Jogador 2! Placar final: %d x 3" % gols_jogador1)
		_resetar_placar_completo()


func _resetar_placar_completo() -> void:
	"""Reseta o placar e as posições iniciais."""
	gols_jogador1 = 0
	gols_jogador2 = 0
	_atualizar_placar()
	_resetar_posicoes()
	print("\n✅ Placar e posições resetados após vitória!")


func _resetar_posicoes() -> void:
	"""Reseta todas as peças para posição inicial"""
	if bola:
		print("DEBUG BOLA - Posição antes do reset: ", bola.global_position)
		print("DEBUG BOLA - Posição inicial salva na bola: ", bola.posicao_inicial)
		bola.linear_velocity = Vector2.ZERO
		bola.angular_velocity = 0.0
		if bola.has_method("resetar_posicao"):
			bola.resetar_posicao()
		else:
			bola.global_position = bola.posicao_inicial
		print("DEBUG BOLA - Posição depois do reset: ", bola.global_position)
	
	if jogador1:
		print("DEBUG J1 - Posição antes do reset: ", jogador1.global_position)
		print("DEBUG J1 - Posição inicial salva: ", posicao_inicial_jogador1)
		jogador1.linear_velocity = Vector2.ZERO
		jogador1.angular_velocity = 0.0
		jogador1.global_position = posicao_inicial_jogador1
		print("DEBUG J1 - Posição depois do reset: ", jogador1.global_position)
	
	if jogador2:
		print("DEBUG J2 - Posição antes do reset: ", jogador2.global_position)
		print("DEBUG J2 - Posição inicial salva: ", posicao_inicial_jogador2)
		jogador2.linear_velocity = Vector2.ZERO
		jogador2.angular_velocity = 0.0
		jogador2.global_position = posicao_inicial_jogador2
		print("DEBUG J2 - Posição depois do reset: ", jogador2.global_position)
	
	print("\n✅ Posições resetadas! Bola no centro.")


func _atualizar_placar() -> void:
	"""Atualiza o texto do placar no Label"""
	if placar_label:
		placar_label.text = "Placar: %d x %d" % [gols_jogador1, gols_jogador2]
		print("✅ Placar atualizado no Label: ", placar_label.text)
	else:
		print("❌ ERRO: Label do placar não está conectado! Tentando reconectar...")
		if has_node("../Placar"):
			placar_label = get_node("../Placar")
			placar_label.text = "Placar: %d x %d" % [gols_jogador1, gols_jogador2]
			print("✅ Placar reconectado e atualizado: ", placar_label.text)
		else:
			print("❌ ERRO CRÍTICO: Nó ../Placar não existe na cena!")
