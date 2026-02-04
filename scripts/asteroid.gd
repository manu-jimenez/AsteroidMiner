# scripts/asteroid.gd
extends RigidBody2D
class_name Asteroid

@export var radius: float = 48.0 : set = set_radius
# Density for mass calculation: mass = PI * radius² * density.
# At density 0.25, a small asteroid (r=16) has mass ~200 (≈ ship mass),
# a medium one (r=48) has mass ~1800, and a large one (r=192) has mass ~29000.
# This means the ship can knock small rocks around, nudge medium ones,
# and barely dent the big ones — which feels physically right.
@export var density: float = 0.25
@export var frozen: bool = true : set = set_frozen

# Irregular shape generation — layered noise
@export_group("Shape Noise")
@export var noise_amplitude: float = 0.18  # Base layer: max displacement as fraction of radius
@export var noise_freq_min: float = 1.5    # Base layer: frequency for smallest asteroids
@export var noise_freq_max: float = 4.0    # Base layer: frequency for largest asteroids
@export var noise_radius_range: Vector2 = Vector2(16.0, 192.0)  # Min/max radius for frequency lerp

@export_group("Shape Noise — Medium Layer")
@export var medium_threshold: float = 60.0   # Min radius to enable medium noise layer
@export var medium_amplitude: float = 0.12   # Displacement fraction for broad lumps
@export var medium_frequency: float = 0.8    # Lower freq = wider features

@export_group("Shape Noise — Large Layer")
@export var large_threshold: float = 120.0   # Min radius to enable large noise layer
@export var large_amplitude: float = 0.15    # Displacement fraction for overall shape warp
@export var large_frequency: float = 0.4     # Very low freq = asymmetric elongation

var noise_seed: int = 0  # Set by world.gd for deterministic shapes

@onready var collision: CollisionShape2D = $Collision
@onready var visual: Polygon2D = $Visual

var max_radius: float = 48.0  # Furthest vertex extent (radius + noise), used for overlap checks
var _pending_radius_apply: bool = false

func _ready() -> void:
	gravity_scale = 0.0
	linear_damp = 0.2
	angular_damp = 0.2
	lock_rotation = false  # Allow rotation from collisions

	set_frozen(frozen)

	# Si radius se asignó antes de entrar al árbol, lo aplicamos ahora.
	if _pending_radius_apply:
		_apply_radius()
	else:
		# Asegura que al menos se aplica el valor por defecto
		_apply_radius()

func set_frozen(v: bool) -> void:
	frozen = v
	freeze = v
	# KINEMATIC so that when unfrozen, the body behaves as a normal dynamic RigidBody2D.
	# STATIC would give it infinite mass during collision resolution, making it immovable.
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC

func set_radius(r: float) -> void:
	radius = max(r, 6.0)

	# Si todavía no estamos en el árbol (o no están listos los onready), aplaza la aplicación.
	if not is_inside_tree():
		_pending_radius_apply = true
		return

	_apply_radius()

func _apply_radius() -> void:
	_pending_radius_apply = false

	# 1) Colisión: SIEMPRE shape nueva (evita shapes compartidos)
	var cs := CircleShape2D.new()
	cs.radius = radius
	collision.shape = cs

	# 2) Masa (2D)
	var area := PI * radius * radius
	mass = max(0.1, area * density)

	# 3) Visual — irregular shape using noise
	visual.polygon = _make_noisy_polygon(radius, 48)

func _make_noisy_polygon(r: float, points: int) -> PackedVector2Array:
	"""Generate an irregular asteroid polygon by sampling noise along a circle."""
	var poly := PackedVector2Array()

	if noise_amplitude <= 0.0:
		# Fast path: perfect circle
		max_radius = r
		for i in range(points):
			var a := TAU * float(i) / float(points)
			poly.append(Vector2(cos(a), sin(a)) * r)
		return poly

	# --- Build noise layers ---
	# Base layer (all asteroids): small surface bumps
	var t := clampf((r - noise_radius_range.x) / max(noise_radius_range.y - noise_radius_range.x, 1.0), 0.0, 1.0)
	var base_freq := lerpf(noise_freq_min, noise_freq_max, t)

	var noise_base := FastNoiseLite.new()
	noise_base.seed = noise_seed
	noise_base.noise_type = FastNoiseLite.TYPE_PERLIN
	noise_base.frequency = base_freq

	# Medium layer (broad lumps) — only for medium+ asteroids
	var use_medium := r >= medium_threshold
	var noise_medium: FastNoiseLite
	if use_medium:
		noise_medium = FastNoiseLite.new()
		noise_medium.seed = noise_seed + 7919  # Different seed offset for independent pattern
		noise_medium.noise_type = FastNoiseLite.TYPE_PERLIN
		noise_medium.frequency = medium_frequency

	# Large layer (overall shape warp) — only for the biggest asteroids
	var use_large := r >= large_threshold
	var noise_large: FastNoiseLite
	if use_large:
		noise_large = FastNoiseLite.new()
		noise_large.seed = noise_seed + 104729  # Another offset
		noise_large.noise_type = FastNoiseLite.TYPE_PERLIN
		noise_large.frequency = large_frequency

	# --- Sample all layers per vertex ---
	var max_perturbed_r := r
	for i in range(points):
		var a := TAU * float(i) / float(points)
		var nx := cos(a)
		var ny := sin(a)
		var sample_x := nx * 100.0
		var sample_y := ny * 100.0

		# Accumulate displacement from each layer
		var displacement := noise_base.get_noise_2d(sample_x, sample_y) * noise_amplitude
		if use_medium:
			displacement += noise_medium.get_noise_2d(sample_x, sample_y) * medium_amplitude
		if use_large:
			displacement += noise_large.get_noise_2d(sample_x, sample_y) * large_amplitude

		var perturbed_r := r * (1.0 + displacement)
		if perturbed_r > max_perturbed_r:
			max_perturbed_r = perturbed_r
		poly.append(Vector2(nx, ny) * perturbed_r)

	max_radius = max_perturbed_r
	return poly
