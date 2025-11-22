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

var gols_jogador1: int = 0
var gols_jogador2: int = 0
var placar_label: Label = null

var posicao_inicial_jogador1: Vector2 = Vector2.ZERO
var posicao_inicial_jogador2: Vector2 = Vector2.ZERO

signal turno_mudou(turno: Turno)
signal gol_marcado(jogador: int, placar_j1: int, placar_j2: int)

var reset_em_andamento: bool = false

func _on_jogador1_soltou_signal() -> void:
	_on_jogador_soltou(1)

func _on_jogador2_soltou_signal() -> void:
	_on_jogador_soltou(2)

func _on_gol_jogador1_body_entered_signal(body: Node2D) -> void:
	_on_gol_body_entered(2, body)

func _on_gol_jogador2_body_entered_signal(body: Node2D) -> void:
	_on_gol_body_entered(1, body)

func _ready() -> void:
	if not jogador1 and has_node("Jogador1"):
		jogador1 = get_node("Jogador1")
	if not jogador2 and has_node("Jogador2"):
		jogador2 = get_node("Jogador2")
	if not bola and has_node("Bola"):
		bola = get_node("Bola")

	if jogador1:
		posicao_inicial_jogador1 = jogador1.global_position
		if jogador1.has_signal("jogador_soltou"):
			jogador1.jogador_soltou.connect(_on_jogador1_soltou_signal)
	
	if jogador2:
		posicao_inicial_jogador2 = jogador2.global_position
		if jogador2.has_signal("jogador_soltou"):
			jogador2.jogador_soltou.connect(_on_jogador2_soltou_signal)

	if not placar_label and has_node("../Placar"):
		placar_label = get_node("../Placar")
		_atualizar_placar()

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

func _on_jogador_soltou(jogador: int) -> void:
	if (jogador == 1 and turno_atual == Turno.JOGADOR1) or (jogador == 2 and turno_atual == Turno.JOGADOR2):
		ultimo_jogador = jogador
		turno_atual = Turno.AGUARDANDO
		if jogador == 1 and jogador1:
			jogador1.set("pode_jogar", false)
		elif jogador == 2 and jogador2:
			jogador2.set("pode_jogar", false)
		timer_espera = tempo_espera_turno

func _proximo_turno() -> void:
	if turno_atual == Turno.AGUARDANDO:
		if ultimo_jogador == 1:
			_iniciar_turno_jogador2()
		else:
			_iniciar_turno_jogador1()

func _tudo_parado() -> bool:
	var bola_parada = bola and bola.linear_velocity.length() < 0.1 and bola.angular_velocity < 0.1
	var jogador1_parado = jogador1 and jogador1.linear_velocity.length() < 0.1 and jogador1.angular_velocity < 0.1
	var jogador2_parado = jogador2 and jogador2.linear_velocity.length() < 0.1 and jogador2.angular_velocity < 0.1
	return bola_parada and jogador1_parado and jogador2_parado

func _on_gol_body_entered(jogador: int, body: Node2D) -> void:
	if body == bola:
		_marcar_gol(jogador)

func _marcar_gol(jogador_marcou: int) -> void:
	if jogador_marcou == 1:
		gols_jogador1 += 1
	else:
		gols_jogador2 += 1
	_atualizar_placar()
	_verificar_vitoria()
	gol_marcado.emit(jogador_marcou, gols_jogador1, gols_jogador2)
	await get_tree().create_timer(1.5).timeout
	_resetar_posicoes()
	if jogador_marcou == 1:
		_iniciar_turno_jogador2()
	else:
		_iniciar_turno_jogador1()

func _resetar_posicoes(final_do_jogo: bool = false) -> void:
	reset_em_andamento = true
	if jogador1:
		jogador1.set("pode_jogar", false)
	if jogador2:
		jogador2.set("pode_jogar", false)
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
	if jogador1:
		jogador1.linear_velocity = Vector2.ZERO
		jogador1.angular_velocity = 0.0
		jogador1.global_position = posicao_inicial_jogador1
		jogador1.set_deferred("global_position", jogador1.global_position)
		await get_tree().process_frame
	if jogador2:
		jogador2.linear_velocity = Vector2.ZERO
		jogador2.angular_velocity = 0.0
		jogador2.global_position = posicao_inicial_jogador2
		jogador2.set_deferred("global_position", jogador2.global_position)
		await get_tree().process_frame
	if not final_do_jogo:
		while bola.linear_velocity.length() > 0.1 or bola.angular_velocity > 0.1:
			bola.linear_velocity = Vector2.ZERO
			bola.angular_velocity = 0.0
			await get_tree().process_frame
	await get_tree().process_frame
	if turno_atual == Turno.JOGADOR1 and jogador1:
		jogador1.set("pode_jogar", true)
	elif turno_atual == Turno.JOGADOR2 and jogador2:
		jogador2.set("pode_jogar", true)

func _atualizar_placar() -> void:
	if placar_label:
		placar_label.text = "Placar: %d x %d" % [gols_jogador1, gols_jogador2]
	else:
		if has_node("../Placar"):
			placar_label = get_node("../Placar")
			placar_label.text = "Placar: %d x %d" % [gols_jogador1, gols_jogador2]

func _verificar_vitoria() -> void:
	while not _tudo_parado():
		await get_tree().process_frame
	if gols_jogador1 == 3:
		_resetar_placar_completo()
	elif gols_jogador2 == 3:
		_resetar_placar_completo()

func _resetar_placar_completo() -> void:
	gols_jogador1 = 0
	gols_jogador2 = 0
	_atualizar_placar()
	_resetar_posicoes(true)
