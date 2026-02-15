# scripts/ship.gd
extends RigidBody2D
class_name Ship

@export var thrust_force: float = 150000.0
@export var turn_speed: float = 4.5   # rad/s
@export var max_speed: float = 900.0

@export var max_fuel: float = 100.0
@export var fuel: float = 100.0
@export var fuel_burn_per_sec: float = 5.0  # consumo mientras haces thrust

@export var max_health: float = 100.0
@export var health: float = 100.0

# Collision damage tuning
# damage_per_impulse converts physics impulse (kg·px/s) into health points.
# Impulse = relative_speed × reduced_mass, where reduced_mass = m1*m2/(m1+m2).
# Ship mass ≈ 200, reduced_mass vs big asteroids ≈ 190.
# At 50 px/s  → impulse ~9500   → damage ~5 HP  (gentle bump)
# At 300 px/s → impulse ~57000  → damage ~28 HP  (medium hit)
# At 900 px/s → impulse ~171000 → damage ~85 HP  (near-fatal)
@export var damage_per_impulse: float = 0.0005
@export var damage_cooldown: float = 0.15  # Seconds of invulnerability after a hit

var _damage_timer: float = 0.0  # Counts down to 0; immune while > 0
# Velocity from the previous physics frame, captured at the end of _physics_process.
# This is the true pre-collision velocity because _physics_process runs BEFORE the
# next frame's collision resolution. By contrast, _integrate_forces and body_entered
# both see post-collision velocities within the same physics tick.
var _prev_frame_velocity: Vector2 = Vector2.ZERO

var _dbg_accum := 0.0

func _ready() -> void:
	print("Ship freeze=", freeze, " custom_integrator=", custom_integrator)

	# Initialize from persisted config
	thrust_force = GameConfig.ship_thrust_force
	turn_speed = GameConfig.ship_turn_speed
	max_speed = GameConfig.ship_max_speed
	max_fuel = GameConfig.ship_max_fuel
	fuel = GameConfig.ship_max_fuel
	fuel_burn_per_sec = GameConfig.ship_fuel_burn_per_sec
	max_health = GameConfig.ship_max_health
	health = GameConfig.ship_max_health
	damage_per_impulse = GameConfig.ship_damage_per_impulse
	damage_cooldown = GameConfig.ship_damage_cooldown

	# Un poco de amortiguación arcade
	linear_damp = GameConfig.ship_linear_damp
	angular_damp = 6.0
	gravity_scale = 0.0

	lock_rotation = true
	angular_velocity = 0.0

	# Ship mass from config
	mass = GameConfig.ship_mass

	# Connect collision signal (contact_monitor + max_contacts_reported set in scene)
	body_entered.connect(_on_body_entered)

func _turn_input() -> float:
	var t := 0.0
	if Input.is_action_pressed("turn_left"):
		t -= 1.0
	if Input.is_action_pressed("turn_right"):
		t += 1.0
	return t

func _process(delta: float) -> void:
	# While paused, physics isn't running, so rotate visually here
	if get_tree().paused:
		rotation += _turn_input() * turn_speed * delta

func _physics_process(delta: float) -> void:
	# Tick damage cooldown
	if _damage_timer > 0.0:
		_damage_timer -= delta

	_dbg_accum += delta
	if _dbg_accum >= 0.33:
		_dbg_accum = 0.0
		#if Input.is_action_pressed("thrust"):
			#print("THRUST pressed | paused=", get_tree().paused,
				#" freeze=", freeze,
				#" custom_integrator=", custom_integrator,
				#" fuel=", fuel,
				#" thrust_force=", thrust_force,
				#" pos=", global_position,
				#" lin_vel=", linear_velocity,
				#" paused=", get_tree().paused)
		#var t := _turn_input()
		#if t != 0.0:
		#	print("TURN input =", t, " paused=", get_tree().paused)

	if get_tree().paused:
		return
	
	# thrust + fuel aquí
	if Input.is_action_pressed("thrust") and fuel > 0.0:
		var forward := transform.x.normalized()
		apply_central_force(forward * thrust_force)
		fuel = max(0.0, fuel - fuel_burn_per_sec * delta)

	# Clamp de velocidad para evitar que se dispare por colisiones
	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed

	# Snapshot velocity at end of this frame. Next frame's collision resolution hasn't
	# happened yet, so this is the true "approach velocity" for any collision that
	# occurs during the next physics tick.
	_prev_frame_velocity = linear_velocity

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Prevent collision torque from spinning the ship:
	state.angular_velocity = 0.0

	# Apply player turning in the physics step (works at any speed)
	if not get_tree().paused:
		var t := _turn_input()
		if t != 0.0:
			var rot := state.transform.get_rotation() + t * turn_speed * state.step
			state.transform = Transform2D(rot, state.transform.origin)
	
func refuel_full() -> void:
	fuel = max_fuel

func has_fuel() -> bool:
	return fuel > 0.0

func heal_full() -> void:
	health = max_health

func is_alive() -> bool:
	return health > 0.0


func _on_body_entered(body: Node) -> void:
	"""Handle collision with an asteroid. Damage is proportional to impulse exchanged.

	Physics recap:
	  - Impulse J = relative_speed × reduced_mass
	  - reduced_mass = (m1 × m2) / (m1 + m2)
	  - For ship (light) vs huge asteroid: reduced_mass ≈ ship.mass
	  - For ship vs tiny asteroid: reduced_mass ≈ asteroid.mass
	  This naturally makes big-asteroid collisions more dangerous.
	"""
	if not body is Asteroid:
		return

	# Cooldown prevents multiple hits from the same collision
	if _damage_timer > 0.0:
		return

	var asteroid: Asteroid = body

	# Use previous frame's velocity (captured at end of _physics_process).
	# By the time body_entered fires, linear_velocity is already post-bounce.
	# _prev_frame_velocity was saved before this frame's collision resolution.
	var relative_vel: Vector2 = _prev_frame_velocity - asteroid.linear_velocity
	var relative_speed: float = relative_vel.length()

	# Reduced mass: how much momentum is actually exchanged
	var m_ship: float = mass
	var m_ast: float = asteroid.mass
	var reduced_mass: float = (m_ship * m_ast) / max(m_ship + m_ast, 0.01)

	# Impulse magnitude and resulting damage
	var impulse: float = relative_speed * reduced_mass
	var damage: float = impulse * damage_per_impulse

	# Apply damage
	health = max(0.0, health - damage)
	_damage_timer = damage_cooldown

	print("COLLISION! ast_r=%.0f ast_mass=%.0f ship_mass=%.0f | prev_vel=(%.0f,%.0f) ast_vel=(%.0f,%.0f) post_vel=(%.0f,%.0f) | rel_speed=%.0f reduced_mass=%.1f impulse=%.0f damage=%.1f health=%.1f" \
		% [asteroid.radius, m_ast, m_ship,
		   _prev_frame_velocity.x, _prev_frame_velocity.y,
		   asteroid.linear_velocity.x, asteroid.linear_velocity.y,
		   linear_velocity.x, linear_velocity.y,
		   relative_speed, reduced_mass, impulse, damage, health])
