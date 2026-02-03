# scripts/world.gd
extends Node2D

@onready var fuel_bar: ProgressBar = $UI/FuelBox/FuelBar
@onready var fuel_label: Label = $UI/FuelBox/FuelLabel

@onready var game_over_label: Label = $UI/GameOverLabel
var is_game_over := false
var game_started := false

# Start menu references
@onready var start_menu: CanvasLayer = $StartMenu
@onready var sld_alpha: HSlider = $StartMenu/CenterContainer/VBoxContainer/AlphaBox/AlphaSlider
@onready var lbl_alpha_value: Label = $StartMenu/CenterContainer/VBoxContainer/AlphaBox/AlphaValue

@onready var ship: Ship = $Ship
var cam: Camera2D

# Sliders parametros
@onready var sld_thrust: HSlider = $UI/TuningPanel/VBox/HBoxThrust/HSliderThrust
@onready var lbl_thrust: Label = $UI/TuningPanel/VBox/HBoxThrust/LabelThrust
@onready var sld_damp: HSlider = $UI/TuningPanel/VBox/HBoxDamp/HSliderDamp
@onready var lbl_damp: Label = $UI/TuningPanel/VBox/HBoxDamp/LabelDamp
@onready var sld_turn: HSlider = $UI/TuningPanel/VBox/HBoxTurn/HSliderTurn
@onready var lbl_turn: Label = $UI/TuningPanel/VBox/HBoxTurn/LabelTurn
@onready var sld_fuel_burn: HSlider = $UI/TuningPanel/VBox/HBoxFuelBurn/HSliderFuelBurn
@onready var lbl_fuel_burn: Label = $UI/TuningPanel/VBox/HBoxFuelBurn/LabelFuelBurn


# ============================================================
# CHUNK STREAMING SYSTEM
# ============================================================

# Chunk system configuration
var chunk_size: float  # Calculated from viewport (1.5 * screen width)
@export var chunk_size_multiplier: float = 1.5  # How many screens wide is a chunk
@export var asteroid_density: float = 0.00003  # Asteroids per square world unit

# Spawn/despawn configuration (as multiples of screen size)
@export var spawn_radius_screens: float = 3.5  # How many screens away to spawn chunks
@export var despawn_radius_screens: float = 5.0  # How many screens away to despawn asteroids

# Asteroid size distribution (power-law)
@export_group("Asteroid Size")
@export var radius_min: float = 16.0   # Smallest asteroid (~half ship size)
@export var radius_max: float = 192.0  # Largest asteroid (~6x ship size)
@export var power_law_alpha: float = 2.2  # Distribution shape (higher = more small asteroids)

# Global seed for deterministic generation
@export var global_seed: int = 123456

# Runtime state
var spawned_chunks: Dictionary = {}  # Vector2i -> Array[RigidBody2D]
var spawn_radius: float  # Calculated from viewport
var despawn_radius: float  # Calculated from viewport

# Cached viewport size for calculations
var screen_size: Vector2


var AsteroidScene: PackedScene = preload("res://scenes/Asteroid.tscn")
var _asteroid_max_amplitude: float = 0.45  # Cached worst-case total noise amplitude

func _ready() -> void:
	# Cache worst-case noise amplitude (sum of all layers) for overlap estimation
	var _tmp := AsteroidScene.instantiate()
	_asteroid_max_amplitude = _tmp.noise_amplitude + _tmp.medium_amplitude + _tmp.large_amplitude
	_tmp.free()

	# Calculate screen size and radii
	var viewport_size := get_viewport().get_visible_rect().size
	screen_size = viewport_size / cam.zoom if cam else viewport_size  # World units visible on screen
	
	# We need to get the camera first
	cam = $Ship/Camera2D
	if cam:
		screen_size = viewport_size / cam.zoom
	
	# Calculate chunk size based on screen width
	chunk_size = screen_size.x * chunk_size_multiplier
	
	# Calculate spawn/despawn radii based on screen size
	var max_screen_dimension: float = max(screen_size.x, screen_size.y)
	spawn_radius = max_screen_dimension * spawn_radius_screens
	despawn_radius = max_screen_dimension * despawn_radius_screens
	
	print("=== Chunk System Initialized ===")
	print("  Screen size (world): ", screen_size)
	print("  Chunk size: ", chunk_size)
	print("  Spawn radius: ", spawn_radius)
	print("  Despawn radius: ", despawn_radius)
	print("================================")
	
	# Inicializa UI
	_apply_tuning_from_sliders()
	
	ship.refuel_full()
	_update_fuel_ui()
	game_over_label.visible = false
	
	# Conecta señales
	sld_thrust.value_changed.connect(_on_tuning_changed)
	sld_damp.value_changed.connect(_on_tuning_changed)
	sld_turn.value_changed.connect(_on_tuning_changed)
	sld_fuel_burn.value_changed.connect(_on_tuning_changed)
	
	get_tree().paused = false
	print("World ready. paused =", get_tree().paused)
	
	print("Camera enabled=", cam.enabled)
	cam.enabled = true
	print("Camera enabled=", cam.enabled)
	print("Active viewport cam =", get_viewport().get_camera_2d(), " my cam =", cam)

	# Start menu setup: sync slider to current power_law_alpha and connect signal
	sld_alpha.value = power_law_alpha
	lbl_alpha_value.text = "%.1f" % power_law_alpha
	sld_alpha.value_changed.connect(_on_alpha_slider_changed)

	# Hide gameplay elements until the player starts
	ship.visible = false
	ship.freeze = true
	$UI.visible = false


func _process(_delta: float) -> void:
	# Restart is always available (menu or gameplay)
	if Input.is_action_just_pressed("restart"):
		get_tree().paused = false
		get_tree().reload_current_scene()
		return  # Scene is being freed; don't access anything else

	# Everything below only runs after the player starts the game
	if not game_started:
		return

	_update_fuel_ui()
	_check_game_over()

	if Input.is_action_just_pressed("toggle_tuning"):
		$UI/TuningPanel.visible = not $UI/TuningPanel.visible

	if Input.is_action_just_pressed("pause") and not is_game_over:
		get_tree().paused = not get_tree().paused
		print("PAUSED =", get_tree().paused)

	# Update chunk streaming system
	if not get_tree().paused:
		_update_chunk_system()


func _update_fuel_ui() -> void:
	var maxf: float = max(1.0, ship.max_fuel)
	var f: float = clamp(ship.fuel, 0.0, maxf)
	
	fuel_bar.value = f / maxf


func _check_game_over() -> void:
	if is_game_over:
		return
	
	if ship.fuel <= 0.0:
		is_game_over = true
		game_over_label.visible = true
		# Optional: freeze world physics but keep UI
		get_tree().paused = true
		# Set linear damp high so the ship stops
		ship.linear_damp = sld_damp.max_value
	
# ============================================================
# START MENU
# ============================================================

func _unhandled_input(event: InputEvent) -> void:
	"""Detect 'any key' press to start the game from the menu.
	Uses _unhandled_input (not _input) so that slider mouse interactions
	are consumed by the GUI first and don't accidentally trigger game start."""
	if game_started:
		return

	# Only react to actual presses (not releases, mouse motion, or key repeats)
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		if event.is_pressed() and not event.is_echo():
			_start_game()


func _on_alpha_slider_changed(value: float) -> void:
	"""Update power_law_alpha in real-time as the player adjusts the slider."""
	power_law_alpha = value
	lbl_alpha_value.text = "%.1f" % value


func _start_game() -> void:
	"""Transition from menu to gameplay."""
	game_started = true

	# Hide menu, show gameplay elements
	start_menu.visible = false
	ship.visible = true
	ship.freeze = false
	$UI.visible = true

	# Initialize ship fuel
	ship.refuel_full()
	_update_fuel_ui()

	print("Game started! power_law_alpha = ", power_law_alpha)


func _on_tuning_changed(_v: float) -> void:
	_apply_tuning_from_sliders()

func _apply_tuning_from_sliders() -> void:
	var thrust := float(sld_thrust.value)
	var damp := float(sld_damp.value)
	var turn := float(sld_turn.value)
	var fuel_burn := float(sld_fuel_burn.value)

	# Ship script variables
	ship.thrust_force = thrust
	ship.turn_speed = turn
	ship.linear_damp = damp 	# Propiedad directa del RigidBody2D
	ship.fuel_burn_per_sec = fuel_burn
	ship.max_fuel = 100.0

	lbl_thrust.text = "Thrust: %d" % int(thrust)
	lbl_damp.text = "Linear damp: %.2f" % damp
	lbl_turn.text = "Turn: %.1f" % turn
	lbl_fuel_burn.text = "Fuel burn: %.0f/s" % fuel_burn


# ============================================================
# CHUNK STREAMING SYSTEM METHODS
# ============================================================

func _update_chunk_system() -> void:
	"""Main update loop for chunk streaming - called every frame."""
	var ship_pos := ship.global_position
	
	# 1. Spawn chunks within spawn radius
	_spawn_chunks_around(ship_pos)
	
	# 2. Despawn asteroids beyond despawn radius
	_despawn_far_asteroids(ship_pos)


func _spawn_chunks_around(center: Vector2) -> void:
	"""Spawn all unspawned chunks within spawn_radius of center."""
	# Find chunk bounds to check
	var min_chunk := _world_to_chunk(center - Vector2.ONE * spawn_radius)
	var max_chunk := _world_to_chunk(center + Vector2.ONE * spawn_radius)
	
	for cx in range(min_chunk.x, max_chunk.x + 1):
		for cy in range(min_chunk.y, max_chunk.y + 1):
			var chunk_key := Vector2i(cx, cy)
			
			# Skip if already spawned
			if chunk_key in spawned_chunks:
				continue
			
			# Check if chunk center is within spawn radius
			var chunk_center := _chunk_to_world(chunk_key) + Vector2.ONE * chunk_size * 0.5
			if center.distance_to(chunk_center) > spawn_radius:
				continue
			
			# Spawn this chunk
			_spawn_chunk(chunk_key)


func _spawn_chunk(chunk_key: Vector2i) -> void:
	"""Generate and spawn all asteroids for a chunk."""
	# Seed RNG deterministically
	var rng := RandomNumberGenerator.new()
	var seed_value := _hash_chunk(chunk_key)
	rng.seed = seed_value

	# Calculate chunk bounds
	var chunk_origin := _chunk_to_world(chunk_key)
	var chunk_area := chunk_size * chunk_size

	# Determine asteroid count based on density
	var asteroid_count := int(chunk_area * asteroid_density)
	asteroid_count = max(1, asteroid_count)  # At least 1 asteroid per chunk

	# Storage for this chunk's asteroids
	var chunk_asteroids: Array[RigidBody2D] = []

	# Overlap avoidance: track placed positions/radii and largest radius
	var placed: Array[Vector2] = []  # positions of placed asteroids
	var placed_radii: Array[float] = []  # their radii
	var max_placed_radius: float = 0.0

	# Generate asteroids
	var spawned := 0
	for i in range(asteroid_count):
		# Sample radius from power-law distribution
		var radius := _sample_power_law_radius(rng)

		# Use worst-case radius for the new asteroid (max possible noise expansion)
		var worst_case_radius := radius * (1.0 + _asteroid_max_amplitude)

		# Try to find a non-overlapping position
		var world_pos := Vector2.ZERO
		var valid := false
		for attempt in range(10):
			var local_x := rng.randf() * chunk_size
			var local_y := rng.randf() * chunk_size
			world_pos = chunk_origin + Vector2(local_x, local_y)

			if _is_spawn_point_clear(world_pos, worst_case_radius, placed, placed_radii, max_placed_radius) \
					and _is_clear_of_neighbors(world_pos, worst_case_radius, chunk_key):
				valid = true
				break

		if not valid:
			continue  # Skip this asteroid

		# Spawn asteroid with deterministic noise seed
		var asteroid_seed := rng.randi()
		var asteroid := _create_asteroid(world_pos, radius, asteroid_seed)
		chunk_asteroids.append(asteroid)
		placed.append(world_pos)
		# Store actual max_radius (accounts for real noise) for future overlap checks
		placed_radii.append(asteroid.max_radius)
		if asteroid.max_radius > max_placed_radius:
			max_placed_radius = asteroid.max_radius
		spawned += 1

	# Register chunk
	spawned_chunks[chunk_key] = chunk_asteroids

	print("[Chunk System] Spawned chunk ", chunk_key, " with ", spawned, "/", asteroid_count, " asteroids")


func _despawn_far_asteroids(center: Vector2) -> void:
	"""Remove asteroids beyond despawn_radius and clean up empty chunks."""
	var chunks_to_remove: Array[Vector2i] = []
	
	for chunk_key in spawned_chunks.keys():
		var chunk_asteroids: Array = spawned_chunks[chunk_key]
		var remaining_asteroids: Array[RigidBody2D] = []
		
		# Check each asteroid in this chunk
		for asteroid in chunk_asteroids:
			if not is_instance_valid(asteroid):
				continue  # Already freed somehow
			
			if center.distance_to(asteroid.global_position) > despawn_radius:
				# Despawn this asteroid
				asteroid.queue_free()
			else:
				# Keep it
				remaining_asteroids.append(asteroid)
		
		# Update or remove chunk
		if remaining_asteroids.is_empty():
			chunks_to_remove.append(chunk_key)
		else:
			spawned_chunks[chunk_key] = remaining_asteroids
	
	# Remove empty chunks
	for chunk_key in chunks_to_remove:
		spawned_chunks.erase(chunk_key)
		print("[Chunk System] Despawned chunk ", chunk_key)


# ============================================================
# HELPER METHODS
# ============================================================

func _is_spawn_point_clear(pos: Vector2, radius: float, placed: Array[Vector2],
		placed_radii: Array[float], max_placed_radius: float) -> bool:
	"""Check that pos doesn't overlap any already-placed asteroid."""
	# Only asteroids within this distance could possibly overlap
	var cull_dist := radius + max_placed_radius
	for j in range(placed.size()):
		var dist := pos.distance_to(placed[j])
		if dist > cull_dist:
			continue
		# Circles overlap if distance between centers < sum of radii
		if dist < placed_radii[j] + radius:
			return false
	return true


func _is_clear_of_neighbors(pos: Vector2, radius: float, current_chunk: Vector2i) -> bool:
	"""Check that pos doesn't overlap asteroids in already-spawned neighboring chunks."""
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue  # Skip current chunk (already checked)
			var neighbor_key := Vector2i(current_chunk.x + dx, current_chunk.y + dy)
			if neighbor_key not in spawned_chunks:
				continue
			for asteroid in spawned_chunks[neighbor_key]:
				if not is_instance_valid(asteroid):
					continue
				var dist := pos.distance_to(asteroid.global_position)
				if dist < asteroid.max_radius + radius:
					return false
	return true


func _world_to_chunk(world_pos: Vector2) -> Vector2i:
	"""Convert world position to chunk coordinates."""
	return Vector2i(
		floori(world_pos.x / chunk_size),
		floori(world_pos.y / chunk_size)
	)


func _chunk_to_world(chunk_key: Vector2i) -> Vector2:
	"""Convert chunk coordinates to world position (chunk origin)."""
	return Vector2(
		chunk_key.x * chunk_size,
		chunk_key.y * chunk_size
	)


func _hash_chunk(chunk_key: Vector2i) -> int:
	"""Generate deterministic seed for a chunk."""
	# Combine global seed with chunk coordinates
	var combined := global_seed
	combined = (combined * 73856093) ^ (chunk_key.x * 19349663)
	combined = (combined * 83492791) ^ (chunk_key.y * 19349669)
	return abs(combined)  # Ensure positive


func _sample_power_law_radius(rng: RandomNumberGenerator) -> float:
	"""Sample radius from power-law distribution."""
	var u := rng.randf()  # Uniform [0, 1)
	u = max(u, 0.0001)  # Avoid log(0)
	
	# Inverse CDF for power-law: r = r_min * (1 - u)^(-1/(alpha-1))
	var exponent := -1.0 / (power_law_alpha - 1.0)
	var radius := radius_min * pow(1.0 - u, exponent)
	
	# Clamp to valid range
	return clamp(radius, radius_min, radius_max)


func _create_asteroid(world_pos: Vector2, radius: float, asteroid_seed: int = 0) -> RigidBody2D:
	"""Create an asteroid RigidBody2D at position with given radius."""
	# Load the asteroid scene (reuse existing scene)
	var asteroid: RigidBody2D = AsteroidScene.instantiate()

	# Set noise seed before radius so the shape is ready when _apply_radius runs
	asteroid.noise_seed = asteroid_seed

	# Set properties
	asteroid.position = world_pos
	asteroid.radius = radius  # This will trigger the asteroid's setter
	
	# Static for this sprint (no velocity)
	asteroid.linear_velocity = Vector2.ZERO
	asteroid.angular_velocity = 0.0
	asteroid.freeze = false  # Not frozen, but no forces applied
	
	# Add to scene
	add_child(asteroid)
	
	return asteroid
