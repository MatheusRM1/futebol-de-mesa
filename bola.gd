extends RigidBody2D

@export var friccao: float = 1.8
@export var quique: float = 0.7
@export var velocidade_minima: float = 5.0
@export var velocidade_maxima: float = 1500.0

var posicao_inicial: Vector2 = Vector2.ZERO

func _ready() -> void:
	posicao_inicial = global_position
	gravity_scale = 0.0
	linear_damp = friccao
	angular_damp = 5.0
	lock_rotation = false
	mass = 0.5
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = quique
	physics_material_override.friction = 0.1
	contact_monitor = true
	max_contacts_reported = 10

func _physics_process(_delta: float) -> void:
	if linear_velocity.length() < velocidade_minima:
		linear_velocity = Vector2.ZERO
	if linear_velocity.length() > velocidade_maxima:
		linear_velocity = linear_velocity.normalized() * velocidade_maxima

func esta_parada() -> bool:
	return linear_velocity.length() < velocidade_minima
