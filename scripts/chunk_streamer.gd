# scripts/chunk_streamer.gd
# Manages the chunk-based asteroid streaming system. Chunks are rectangular regions
# of the world that get populated with asteroids when the player is nearby.
# Asteroid data is pre-computed (cheap math) and then nodes are instantiated
# gradually across frames to avoid frame spikes.
extends Node2D
class_name ChunkStreamer

# ============================================================
# CONFIGURATION (tunable from the inspector)
# ============================================================

# Chunk system
@export var chunk_size_multiplier: float = 1.5  # How many screens wide is a chunk
@export var asteroid_density: float = 0.00001  # Asteroids per square world unit

# Spawn/despawn configuration (as multiples of screen size)
@export var spawn_radius_screens: float = 1.5  # How many screens away to spawn chunks
@export var despawn_radius_screens: float = 2.5  # How many screens away to despawn asteroids

# Asteroid size distribution (power-law)
@export_group("Asteroid Size")
@export var radius_min: float = 16.0   # Smallest asteroid
@export var radius_max: float = 192.0  # Largest asteroid
@export var power_law_alpha: float = 2.2  # Distribution shape (higher = more small asteroids)

# Global seed for deterministic generation
@export var global_seed: int = 123456

# Staggered asteroid spawning — prevents frame spikes by spreading work across frames.
# Instead of spawning whole chunks, we pre-compute asteroid data for queued chunk, 
# then add asteroid nodes up to max_asteroids_per_frame.
@export var max_asteroids_per_frame: int = 20

# ============================================================
# RUNTIME STATE
# ============================================================

var chunk_size: float  # Calculated from viewport (multiplier * screen width)
var spawned_chunks: Dictionary = {}  # Vector2i -> Array[RigidBody2D]
var spawn_radius: float  # Calculated from viewport
var despawn_radius: float  # Calculated from viewport

var _chunk_spawn_queue: Array[Vector2i] = []  # Chunks waiting to have their data pre-computed
var _queued_set: Dictionary = {}  # Fast lookup to avoid duplicate queue entries

# Pre-computed asteroid data waiting to be instantiated as actual nodes.
# Each entry: { "pos": Vector2, "radius": float, "seed": int, "chunk": Vector2i }
var _asteroid_spawn_queue: Array[Dictionary] = []

# Cached viewport size for calculations
var screen_size: Vector2

var AsteroidScene: PackedScene = preload("res://scenes/Asteroid.tscn")
var _asteroid_max_amplitude: float = 0.45  # Cached worst-case total noise amplitude TODO: Will this value be affected if I change the amplitudes? Can we compute it from the noise amplitudes?


# ============================================================
# PUBLIC API
# ============================================================

func initialize(viewport_size: Vector2, camera_zoom: Vector2) -> void:
	"""Set up chunk sizes and radii based on the viewport and camera.
	Call this once from World._ready() after the camera is resolved."""
	# Sync config values into our export vars so the streaming system
	# uses persisted settings (world.gd may override some of these after).
	chunk_size_multiplier = GameConfig.chunk_size_multiplier
	asteroid_density = GameConfig.asteroid_density
	spawn_radius_screens = GameConfig.spawn_radius_screens
	despawn_radius_screens = GameConfig.despawn_radius_screens
	radius_min = GameConfig.radius_min
	radius_max = GameConfig.radius_max
	power_law_alpha = GameConfig.power_law_alpha
	global_seed = GameConfig.global_seed
	max_asteroids_per_frame = GameConfig.max_asteroids_per_frame

	# Cache worst-case noise amplitude (sum of all layers) for overlap estimation
	var _tmp := AsteroidScene.instantiate()
	_asteroid_max_amplitude = _tmp.noise_amplitude + _tmp.medium_amplitude + _tmp.large_amplitude
	_tmp.free()

	# Calculate screen size in world units
	screen_size = viewport_size / camera_zoom

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


func update_streaming(ship_pos: Vector2) -> void:
	"""Main update loop for chunk streaming — call every frame from World._process()."""
	# 1. Queue any new chunks that need spawning
	_queue_chunks_around(ship_pos)

	# 2. Pre-compute new chunks and spawn asteroids (budget-limited per frame)
	_process_chunk_queue(ship_pos)

	# 3. Despawn asteroids beyond despawn radius
	_despawn_far_asteroids(ship_pos)


# ============================================================
# CHUNK QUEUE & SPAWNING
# ============================================================

func _queue_chunks_around(center: Vector2) -> void:
	"""Find unspawned chunks within spawn_radius and add them to the spawn queue."""
	var min_chunk := _world_to_chunk(center - Vector2.ONE * spawn_radius)
	var max_chunk := _world_to_chunk(center + Vector2.ONE * spawn_radius)

	for cx in range(min_chunk.x, max_chunk.x + 1):
		for cy in range(min_chunk.y, max_chunk.y + 1):
			var chunk_key := Vector2i(cx, cy)

			# Skip if already spawned or already in queue
			if chunk_key in spawned_chunks:
				continue
			if chunk_key in _queued_set:
				continue

			# Check if chunk center is within spawn radius
			var chunk_center := _chunk_to_world(chunk_key) + Vector2.ONE * chunk_size * 0.5
			if center.distance_to(chunk_center) > spawn_radius:
				continue

			_chunk_spawn_queue.append(chunk_key)
			_queued_set[chunk_key] = true

	# Sort queue by distance to ship — closest chunks spawn first.
	# This ensures the player always sees nearby asteroids first.
	_chunk_spawn_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var ca := _chunk_to_world(a) + Vector2.ONE * chunk_size * 0.5
		var cb := _chunk_to_world(b) + Vector2.ONE * chunk_size * 0.5
		return center.distance_squared_to(ca) < center.distance_squared_to(cb)
	)


func _process_chunk_queue(ship_pos: Vector2) -> void:
	"""Two-phase spawning:
	Phase 1 — Pre-compute asteroid data for ALL queued chunks (just math, very fast).
	Phase 2 — Instantiate up to max_asteroids_per_frame actual nodes from the queue."""

	# Phase 1: Pre-compute pending chunks into asteroid data (RNG, position sampling, overlap checks)
	while not _chunk_spawn_queue.is_empty():
		var chunk_key := _chunk_spawn_queue[0]
		_chunk_spawn_queue.remove_at(0)
		_queued_set.erase(chunk_key)

		# Double-check it hasn't been spawned since it was queued
		if chunk_key in spawned_chunks:
			continue

		# Skip if it's now outside spawn radius (ship moved away)
		var chunk_center := _chunk_to_world(chunk_key) + Vector2.ONE * chunk_size * 0.5
		if ship_pos.distance_to(chunk_center) > spawn_radius:
			continue

		_precompute_chunk(chunk_key)

	# Phase 2: Create actual asteroid nodes, limited to budget per frame.
	var created_this_frame := 0
	while not _asteroid_spawn_queue.is_empty() and created_this_frame < max_asteroids_per_frame:
		# Explicit types to avoid Variant inference (warnings-as-errors)
		var data: Dictionary = _asteroid_spawn_queue[0]
		_asteroid_spawn_queue.remove_at(0)
		var chunk_key := data["chunk"] as Vector2i

		# Skip if chunk was despawned while waiting (ship moved away fast)
		if chunk_key not in spawned_chunks:
			continue

		var pos := data["pos"] as Vector2
		var radius := data["radius"] as float
		var asteroid_seed := data["seed"] as int
		var asteroid := _create_asteroid(pos, radius, asteroid_seed)
		var chunk_asteroids: Array = spawned_chunks[chunk_key]
		chunk_asteroids.append(asteroid)
		created_this_frame += 1


func _precompute_chunk(chunk_key: Vector2i) -> void:
	"""Pre-compute asteroid positions, radii, and seeds for a chunk (pure math, no nodes).
	The data is added to _asteroid_spawn_queue for gradual instantiation.
	We also register the chunk immediately in spawned_chunks (as an empty array)
	so the despawn system and neighbor overlap checks recognize it."""
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

	# Register chunk immediately (empty — nodes added gradually in Phase 2)
	var chunk_asteroids: Array[RigidBody2D] = []
	spawned_chunks[chunk_key] = chunk_asteroids

	# Overlap avoidance: track placed positions/radii and largest radius.
	# We use worst-case radii here since we don't have actual max_radius yet
	# (the real noise-expanded radius is only known after the Asteroid node runs _apply_radius).
	var placed: Array[Vector2] = []
	var placed_radii: Array[float] = []
	var max_placed_radius: float = 0.0

	# Pre-compute asteroid data
	var queued := 0
	for i in range(asteroid_count):
		# Sample radius from power-law distribution
		var radius := _sample_power_law_radius(rng)

		# Use worst-case radius for overlap checks (max possible noise expansion)
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

		# Generate deterministic seed for this asteroid's noise shape
		var asteroid_seed := rng.randi()

		# Queue the data for gradual instantiation
		_asteroid_spawn_queue.append({
			"pos": world_pos,
			"radius": radius,
			"seed": asteroid_seed,
			"chunk": chunk_key,
		})

		# Track placement for overlap avoidance within this chunk
		placed.append(world_pos)
		placed_radii.append(worst_case_radius)
		if worst_case_radius > max_placed_radius:
			max_placed_radius = worst_case_radius
		queued += 1

	print("[Chunk System] Queued chunk ", chunk_key, " with ", queued, "/", asteroid_count, " asteroids")


# ============================================================
# DESPAWNING
# ============================================================

func _despawn_far_asteroids(center: Vector2) -> void:
	"""Remove asteroids beyond despawn_radius and clean up empty chunks.
	Also purges any queued (not yet instantiated) asteroid data for removed chunks."""
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

		# Also check if there are still queued asteroids pending for this chunk.
		# A chunk with remaining_asteroids empty but pending queue entries is still "alive".
		var has_queued := false
		for data in _asteroid_spawn_queue:
			if data["chunk"] == chunk_key:
				has_queued = true
				break

		# Update or remove chunk
		if remaining_asteroids.is_empty() and not has_queued:
			chunks_to_remove.append(chunk_key)
		else:
			spawned_chunks[chunk_key] = remaining_asteroids

	# Remove empty chunks and purge their queued asteroids
	for chunk_key in chunks_to_remove:
		spawned_chunks.erase(chunk_key)
		# Remove any remaining queued data for this chunk (Phase 2 check handles
		# this via `chunk_key not in spawned_chunks`, but cleaning the queue avoids
		# iterating stale entries every frame)
		var filtered: Array[Dictionary] = []
		for data in _asteroid_spawn_queue:
			if data["chunk"] != chunk_key:
				filtered.append(data)
		_asteroid_spawn_queue = filtered
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
	var asteroid: RigidBody2D = AsteroidScene.instantiate()

	# Set noise seed before radius so the shape is ready when _apply_radius runs
	asteroid.noise_seed = asteroid_seed

	# Set properties
	asteroid.position = world_pos
	asteroid.radius = radius  # This will trigger the asteroid's setter

	# No initial velocity (stream velocity deferred to later sprint)
	asteroid.linear_velocity = Vector2.ZERO
	asteroid.angular_velocity = 0.0

	# Add to scene FIRST — _ready() runs here and calls set_frozen(frozen=true)
	add_child(asteroid)

	return asteroid
