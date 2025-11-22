extends RigidBody2D

# Configurações de física da bola
@export var friccao: float = 1.8  # Fricção da bola
@export var quique: float = 0.7  # Quique da bola nas bordas
@export var velocidade_minima: float = 5.0  # Velocidade abaixo da qual para
@export var velocidade_maxima: float = 1500.0  # Velocidade máxima da bola

# Posição inicial para reset
var posicao_inicial: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Salva posição inicial
	posicao_inicial = global_position
	
	# Configuração física
	gravity_scale = 0.0
	linear_damp = friccao
	angular_damp = 5.0
	lock_rotation = false  # Bola pode girar
	mass = 0.5  # Bola mais leve para ser mais responsiva
	
	# Material físico
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = quique
	physics_material_override.friction = 0.1
	
	# Monitora contatos
	contact_monitor = true
	max_contacts_reported = 10


func _physics_process(_delta: float) -> void:
	# Para completamente se a velocidade for muito baixa
	if linear_velocity.length() < velocidade_minima:
		linear_velocity = Vector2.ZERO
	
	# Limita velocidade máxima
	if linear_velocity.length() > velocidade_maxima:
		linear_velocity = linear_velocity.normalized() * velocidade_maxima

func esta_parada() -> bool:
	"""Retorna true se a bola está parada"""
	return linear_velocity.length() < velocidade_minima
