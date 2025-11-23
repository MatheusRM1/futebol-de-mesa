extends Node2D

@export var jogadores_time1: Array[RigidBody2D] = []
@export var jogadores_time2: Array[RigidBody2D] = []
@export var bola: RigidBody2D
@export var tempo_espera_turno: float = 1.0
@export var area_gol_jogador1: Area2D
@export var area_gol_jogador2: Area2D
@export var label_vencedor: Label

enum Turno { JOGADOR1, JOGADOR2, AGUARDANDO }
var turno_atual: Turno = Turno.JOGADOR1
var ultimo_jogador: int = 0
var timer_espera: float = 0.0

var gols_jogador1: int = 0
var gols_jogador2: int = 0
var placar_label: Label = null

var posicoes_iniciais_time1: Array[Vector2] = []
var posicoes_iniciais_time2: Array[Vector2] = []

signal turno_mudou(turno: Turno)
signal gol_marcado(jogador: int, placar_j1: int, placar_j2: int)

var reset_em_andamento: bool = false
var jogo_finalizado: bool = false

func _on_jogador1_soltou_signal(_jogador) -> void:
	_on_jogador_soltou(1)

func _on_jogador2_soltou_signal(_jogador) -> void:
	_on_jogador_soltou(2)

func _on_gol_jogador1_body_entered_signal(body: Node2D) -> void:
	_on_gol_body_entered(2, body)

func _on_gol_jogador2_body_entered_signal(body: Node2D) -> void:
	_on_gol_body_entered(1, body)

func _ready() -> void:
	randomize()
	for i in range(get_child_count()):
		var child = get_child(i)
		if child is RigidBody2D:
			if child.get("e_jogador_humano") == true:
				jogadores_time1.append(child)
				posicoes_iniciais_time1.append(child.global_position)
				if child.has_signal("jogador_soltou"):
					child.jogador_soltou.connect(_on_jogador1_soltou_signal)
			elif child.get("e_jogador_humano") == false:
				jogadores_time2.append(child)
				posicoes_iniciais_time2.append(child.global_position)
				if child.has_signal("jogador_soltou"):
					child.jogador_soltou.connect(_on_jogador2_soltou_signal)
			elif child.is_in_group("bola"):
				bola = child

	if not placar_label and has_node("../Placar"):
		placar_label = get_node("../Placar")
		_atualizar_placar()

	if not label_vencedor and has_node("../Vencedor"):
		label_vencedor = get_node("../Vencedor")

	if not area_gol_jogador1 and has_node("../AreaGolJogador1"):
		area_gol_jogador1 = get_node("../AreaGolJogador1")
	if not area_gol_jogador2 and has_node("../AreaGolJogador2"):
		area_gol_jogador2 = get_node("../AreaGolJogador2")

	if area_gol_jogador1:
		area_gol_jogador1.body_entered.connect(_on_gol_jogador1_body_entered_signal)
	if area_gol_jogador2:
		area_gol_jogador2.body_entered.connect(_on_gol_jogador2_body_entered_signal)

	_iniciar_turno_jogador1()

func _process(delta: float) -> void:
	if jogo_finalizado:
		return
	if turno_atual == Turno.AGUARDANDO:
		timer_espera -= delta
		if timer_espera <= 0 and _tudo_parado():
			_proximo_turno()

func _iniciar_turno_jogador1() -> void:
	turno_atual = Turno.JOGADOR1
	for jogador in jogadores_time1:
		jogador.set("pode_jogar", true)
	for jogador in jogadores_time2:
		jogador.set("pode_jogar", false)
	turno_mudou.emit(Turno.JOGADOR1)

func _iniciar_turno_jogador2() -> void:
	turno_atual = Turno.JOGADOR2
	for jogador in jogadores_time1:
		jogador.set("pode_jogar", false)
	for jogador in jogadores_time2:
		jogador.set("pode_jogar", false)
	
	await get_tree().create_timer(0.5).timeout
	
	if jogadores_time2.size() > 0:
		var jogador_aleatorio = jogadores_time2[randi() % jogadores_time2.size()]
		jogador_aleatorio.set("pode_jogar", true)
		if jogador_aleatorio.has_method("executar_jogada_ia"):
			jogador_aleatorio.call("executar_jogada_ia")
	
	turno_mudou.emit(Turno.JOGADOR2)

func _on_jogador_soltou(jogador: int) -> void:
	if (jogador == 1 and turno_atual == Turno.JOGADOR1) or (jogador == 2 and turno_atual == Turno.JOGADOR2):
		ultimo_jogador = jogador
		turno_atual = Turno.AGUARDANDO
		for j in jogadores_time1:
			j.set("pode_jogar", false)
		for j in jogadores_time2:
			j.set("pode_jogar", false)
		timer_espera = tempo_espera_turno

func _proximo_turno() -> void:
	if turno_atual == Turno.AGUARDANDO:
		if ultimo_jogador == 1:
			_iniciar_turno_jogador2()
		else:
			_iniciar_turno_jogador1()

func _tudo_parado() -> bool:
	var bola_parada = bola and bola.linear_velocity.length() < 0.1 and bola.angular_velocity < 0.1
	
	var todos_jogadores_parados = true
	for jogador in jogadores_time1:
		if jogador.linear_velocity.length() >= 0.1 or jogador.angular_velocity >= 0.1:
			todos_jogadores_parados = false
			break
	
	if todos_jogadores_parados:
		for jogador in jogadores_time2:
			if jogador.linear_velocity.length() >= 0.1 or jogador.angular_velocity >= 0.1:
				todos_jogadores_parados = false
				break
	
	return bola_parada and todos_jogadores_parados

func _on_gol_body_entered(jogador: int, body: Node2D) -> void:
	if body == bola:
		_marcar_gol(jogador)

func _marcar_gol(jogador_marcou: int) -> void:
	if jogador_marcou == 1:
		gols_jogador1 += 1
	else:
		gols_jogador2 += 1
	_atualizar_placar()
	
	var alguem_venceu = await _verificar_vitoria()
	
	if not alguem_venceu:
		gol_marcado.emit(jogador_marcou, gols_jogador1, gols_jogador2)
		await get_tree().create_timer(1.5).timeout
		_resetar_posicoes()
		if jogador_marcou == 1:
			_iniciar_turno_jogador2()
		else:
			_iniciar_turno_jogador1()

func _resetar_posicoes(final_do_jogo: bool = false) -> void:
	reset_em_andamento = true
	
	for jogador in jogadores_time1:
		jogador.set("pode_jogar", false)
	for jogador in jogadores_time2:
		jogador.set("pode_jogar", false)
	
	if bola:
		bola.linear_velocity = Vector2.ZERO
		bola.angular_velocity = 0.0
		await get_tree().process_frame
		if bola.has_method("resetar_posicao"):
			bola.resetar_posicao()
		else:
			bola.global_position = bola.posicao_inicial
		bola.set_deferred("global_position", bola.global_position)
		await get_tree().process_frame
		bola.linear_velocity = Vector2.ZERO
		bola.angular_velocity = 0.0
		await get_tree().process_frame
	
	for i in range(jogadores_time1.size()):
		var jogador = jogadores_time1[i]
		jogador.linear_velocity = Vector2.ZERO
		jogador.angular_velocity = 0.0
		jogador.global_position = posicoes_iniciais_time1[i]
		jogador.set_deferred("global_position", jogador.global_position)
		await get_tree().process_frame
	
	for i in range(jogadores_time2.size()):
		var jogador = jogadores_time2[i]
		jogador.linear_velocity = Vector2.ZERO
		jogador.angular_velocity = 0.0
		jogador.global_position = posicoes_iniciais_time2[i]
		jogador.set_deferred("global_position", jogador.global_position)
		await get_tree().process_frame
	
	if not final_do_jogo:
		while bola.linear_velocity.length() > 0.1 or bola.angular_velocity > 0.1:
			bola.linear_velocity = Vector2.ZERO
			bola.angular_velocity = 0.0
			await get_tree().process_frame
	
	await get_tree().process_frame
	
	if not final_do_jogo:
		if turno_atual == Turno.JOGADOR1:
			for jogador in jogadores_time1:
				jogador.set("pode_jogar", true)
		elif turno_atual == Turno.JOGADOR2:
			for jogador in jogadores_time2:
				jogador.set("pode_jogar", true)

func _atualizar_placar() -> void:
	if placar_label:
		placar_label.text = "Placar: %d x %d" % [gols_jogador1, gols_jogador2]
	else:
		if has_node("../Placar"):
			placar_label = get_node("../Placar")
			placar_label.text = "Placar: %d x %d" % [gols_jogador1, gols_jogador2]

func _verificar_vitoria() -> bool:
	if gols_jogador1 == 3:
		jogo_finalizado = true
		if label_vencedor:
			label_vencedor.text = "Jogador 1 venceu!"
			label_vencedor.visible = true
		await get_tree().create_timer(3.0).timeout
		_resetar_placar_completo()
		jogo_finalizado = false
		return true
	elif gols_jogador2 == 3:
		jogo_finalizado = true
		if label_vencedor:
			label_vencedor.text = "Jogador 2 venceu!"
			label_vencedor.visible = true
		await get_tree().create_timer(3.0).timeout
		_resetar_placar_completo()
		jogo_finalizado = false
		return true
	
	return false

func _resetar_placar_completo() -> void:
	if label_vencedor:
		label_vencedor.text = ""
		label_vencedor.visible = false
	gols_jogador1 = 0
	gols_jogador2 = 0
	_atualizar_placar()
	_resetar_posicoes(true)
