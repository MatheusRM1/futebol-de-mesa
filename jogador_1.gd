extends RigidBody2D

@export var forca_maxima: float = 4000.0
@export var distancia_maxima_arraste: float = 200.0
@export var friccao: float = 2.5
@export var quique: float = 0.6
@export var velocidade_minima: float = 8.0
@export var e_jogador_humano: bool = true
@export var mostrar_linha_arraste: bool = true

var pode_jogar: bool = true
var arrastando: bool = false
var posicao_inicial_arraste: Vector2 = Vector2.ZERO
var offset_mouse: Vector2 = Vector2.ZERO
var tempo_inicio_arraste: float = 0.0

signal jogador_tocou_bola(jogador)
signal jogador_soltou(jogador)


func _ready() -> void:
	gravity_scale = 0.0
	linear_damp = friccao
	angular_damp = 10.0
	lock_rotation = true
	mass = 1.5
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = quique
	contact_monitor = true
	max_contacts_reported = 10


func _input(event: InputEvent) -> void:
	if not e_jogador_humano or not pode_jogar:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_tentar_iniciar_arraste()
		else:
			_soltar_jogador()


func _tentar_iniciar_arraste() -> void:
	if not pode_jogar:
		return
		
	var mouse_pos: Vector2 = get_global_mouse_position()

	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = mouse_pos
	query.collide_with_bodies = true
	var result = space_state.intersect_point(query, 32)

	for colisao in result:
		if colisao.collider == self:
			arrastando = true
			posicao_inicial_arraste = global_position
			offset_mouse = global_position - mouse_pos
			tempo_inicio_arraste = Time.get_ticks_msec() / 1000.0
			freeze = true
			break


func _soltar_jogador() -> void:
	if not arrastando:
		return
	
	if not pode_jogar:
		arrastando = false
		freeze = false
		global_position = posicao_inicial_arraste
		return

	arrastando = false

	var mouse_pos: Vector2 = get_global_mouse_position()
	var posicao_arraste: Vector2 = mouse_pos
	var vetor_arraste: Vector2 = posicao_inicial_arraste - posicao_arraste
	var distancia: float = vetor_arraste.length()

	if distancia > distancia_maxima_arraste:
		vetor_arraste = vetor_arraste.normalized() * distancia_maxima_arraste
		distancia = distancia_maxima_arraste

	var multiplicador: float = forca_maxima / distancia_maxima_arraste
	var forca: Vector2 = vetor_arraste * multiplicador

	global_position = posicao_inicial_arraste

	if distancia > 5.0:
		pode_jogar = false
		set_deferred("freeze", false)
		set_deferred("linear_velocity", forca / mass)
		jogador_soltou.emit(self)
		print("Impulso aplicado: ", forca, " | Velocidade: ", forca / mass, " | Distância: ", distancia)


func _physics_process(_delta: float) -> void:
	if linear_velocity.length() < velocidade_minima and not arrastando:
		linear_velocity = Vector2.ZERO


func _process(_delta: float) -> void:
	queue_redraw()
	
func _draw() -> void:
	if arrastando:
		var mouse_pos: Vector2 = get_global_mouse_position()
		var vetor_arraste: Vector2 = global_position - mouse_pos

		if vetor_arraste.length() > distancia_maxima_arraste:
			vetor_arraste = vetor_arraste.normalized() * distancia_maxima_arraste

		var raio_circulo = 100.0
		draw_arc(Vector2.ZERO, raio_circulo, 0, TAU, 64, Color(1, 1, 1, 0.5), 3.0)
		
		if vetor_arraste.length() > 5.0:
			var direcao = vetor_arraste.normalized()
			var comprimento = min(vetor_arraste.length(), distancia_maxima_arraste)
			var largura_seta = 15.0
			var tamanho_ponta = 25.0
			
			var ponta = direcao * comprimento
			var base = Vector2.ZERO
			var perpendicular = Vector2(-direcao.y, direcao.x)
			
			var pontos = PackedVector2Array([
				base + perpendicular * largura_seta / 2,
				base - perpendicular * largura_seta / 2,
				ponta - direcao * tamanho_ponta - perpendicular * largura_seta / 2,
				ponta - direcao * tamanho_ponta - perpendicular * largura_seta,
				ponta,
				ponta - direcao * tamanho_ponta + perpendicular * largura_seta,
				ponta - direcao * tamanho_ponta + perpendicular * largura_seta / 2
			])
			
			draw_colored_polygon(pontos, Color(1, 1, 0, 0.7))


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("bola"):
		jogador_tocou_bola.emit(self)
