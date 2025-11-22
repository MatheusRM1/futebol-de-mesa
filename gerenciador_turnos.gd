extends Node2D

@export var jogador1: RigidBody2D
@export var jogador2: RigidBody2D
@export var bola: RigidBody2D
@export var tempo_espera_turno: float = 1.0

enum Turno { JOGADOR1, JOGADOR2, AGUARDANDO }
var turno_atual: Turno = Turno.JOGADOR1
var ultimo_jogador: int = 0
var aguardando_movimento: bool = false
var timer_espera: float = 0.0

signal turno_mudou(turno: Turno)


func _ready() -> void:
	if not jogador1 and has_node("Jogador1"):
		jogador1 = get_node("Jogador1")
	if not jogador2 and has_node("Jogador2"):
		jogador2 = get_node("Jogador2")
	if not bola and has_node("Bola"):
		bola = get_node("Bola")

	if jogador1 and jogador1.has_signal("jogador_soltou"):
		jogador1.jogador_soltou.connect(_on_jogador1_soltou)

	if jogador2 and jogador2.has_signal("jogador_soltou"):
		jogador2.jogador_soltou.connect(_on_jogador2_soltou)

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
