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
#@export var frozen: bool = true : set = set_frozen 

# --- Pixel art grid ---
# How many world units each art pixel covers. Uniform for all asteroids.
# cell_size=4 → each art pixel is 4×4 world units → 4 screen pixels at 1080p.
# Tunable: try 3 (finer detail), 6 (chunkier), 8 (very retro).
@export_group("Pixel Art")
@export var cell_size: float = 4.0

# Color palette — assign an AsteroidPalette resource, or leave null for defaults.
@export var palette: AsteroidPalette

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
@onready var visual: Sprite2D = $Visual

var max_radius: float = 48.0  # Furthest vertex extent (radius + noise), used for overlap checks
var _pending_radius_apply: bool = false

# The 2D grid of booleans representing the asteroid's filled pixels.
# 1 = solid, 0 = empty. Used for edge detection and future mining.
var grid: PackedByteArray
var grid_width: int = 0
var grid_height: int = 0


func _ready() -> void:
	gravity_scale = 0.0
	linear_damp = 0.2
	angular_damp = 0.2
	lock_rotation = false  # Allow rotation from collisions

	# Create default palette if none assigned
	if palette == null:
		palette = AsteroidPalette.new()

	# If radius was assigned before entering tree, apply it now.
	if _pending_radius_apply:
		_apply_radius()
	else:
		# Ensure default value is applied
		_apply_radius()


func set_radius(r: float) -> void:
	radius = max(r, 6.0)

	# If we're not in the tree yet (onready vars not set), defer application.
	if not is_inside_tree():
		_pending_radius_apply = true
		return

	_apply_radius()


func _apply_radius() -> void:
	_pending_radius_apply = false

	# 1) Collision: ALWAYS create a new shape (prevents shared shapes between instances)
	var cs := CircleShape2D.new()
	cs.radius = radius
	collision.shape = cs

	# 2) Mass (2D): area-based
	var area := PI * radius * radius
	mass = max(0.1, area * density)

	# 3) Generate the noise polygon (defines the silhouette)
	var polygon := _make_noisy_polygon(radius, 48)

	# 4) Rasterize polygon onto a grid and generate the pixel-art texture
	_generate_texture(polygon)


# ============================================================
# TEXTURE GENERATION
# ============================================================
# Approach: ImageTexture on Sprite2D (one-time CPU cost at spawn, zero per-frame).
#
# Alternatives considered (documented for future reference):
# - _draw() with rects: More flexible for per-frame updates (e.g., real-time mining
#   damage). But heavier per-frame unless manually cached. Better if mining chips
#   happen very frequently.
# - Polygon2D + shader: Can't easily do per-pixel edge detection. Limited to
#   polygon-level effects.
# - For future mining: modify the grid array, call _regenerate_texture_from_grid().
#   Fast enough if mining doesn't happen every frame.
# - For future crater/crack overlays: stamp fixed patterns onto the grid before
#   generating the texture.
# ============================================================

func _generate_texture(polygon: PackedVector2Array) -> void:
	# --- Step 1: Compute bounding box of polygon in world units ---
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	for vertex in polygon:
		min_pos.x = minf(min_pos.x, vertex.x)
		min_pos.y = minf(min_pos.y, vertex.y)
		max_pos.x = maxf(max_pos.x, vertex.x)
		max_pos.y = maxf(max_pos.y, vertex.y)

	# Add 1-cell padding so edge pixels aren't clipped
	min_pos -= Vector2(cell_size, cell_size)
	max_pos += Vector2(cell_size, cell_size)

	# --- Step 2: Calculate grid dimensions ---
	grid_width = ceili((max_pos.x - min_pos.x) / cell_size)
	grid_height = ceili((max_pos.y - min_pos.y) / cell_size)

	# Safety clamp — very large asteroids could produce huge grids
	grid_width = mini(grid_width, 512)
	grid_height = mini(grid_height, 512)

	# --- Step 3: Rasterize using scanline fill (fast) ---
	# For each grid row, find where polygon edges cross that Y value,
	# sort the X crossings, and fill between pairs.
	# This is O(rows × edges) instead of O(cells × edges).
	grid = PackedByteArray()
	grid.resize(grid_width * grid_height)
	grid.fill(0)

	var n := polygon.size()
	for gy in range(grid_height):
		# Y coordinate at the center of this grid row
		var scan_y := min_pos.y + (float(gy) + 0.5) * cell_size

		# Find all X intersections of polygon edges with this scanline
		var x_crossings: Array[float] = []
		var j := n - 1
		for i in range(n):
			var vi := polygon[i]
			var vj := polygon[j]

			# Does this edge cross scan_y?
			if (vi.y <= scan_y and vj.y > scan_y) or (vj.y <= scan_y and vi.y > scan_y):
				# Linear interpolation to find X at scan_y
				var t := (scan_y - vi.y) / (vj.y - vi.y)
				x_crossings.append(vi.x + t * (vj.x - vi.x))
			j = i

		# Sort crossings left to right
		x_crossings.sort()

		# Fill between pairs of crossings (even-odd rule)
		var row_offset := gy * grid_width
		for ci in range(0, x_crossings.size() - 1, 2):
			var x_start := x_crossings[ci]
			var x_end := x_crossings[ci + 1]

			# Convert world X to grid columns
			var gx_start := maxi(0, floori((x_start - min_pos.x) / cell_size))
			var gx_end := mini(grid_width - 1, floori((x_end - min_pos.x) / cell_size))

			for gx in range(gx_start, gx_end + 1):
				grid[row_offset + gx] = 1

	# --- Step 3b: Remove "floating" pixels (sharp peaks / thin antennae) ---
	# A solid pixel with ≤2 cardinal neighbors is likely a noise artifact at a sharp
	# polygon tip. These render as ugly floating edge dots. We erase them so the
	# silhouette stays clean. One pass is enough — we're only trimming the outermost
	# tips, not eroding inward.
	for gy in range(grid_height):
		for gx in range(grid_width):
			var idx := gy * grid_width + gx
			if grid[idx] == 0:
				continue
			# Count filled cardinal neighbors (up/down/left/right)
			var neighbors := 0
			if gx > 0 and grid[idx - 1] == 1:
				neighbors += 1
			if gx < grid_width - 1 and grid[idx + 1] == 1:
				neighbors += 1
			if gy > 0 and grid[(gy - 1) * grid_width + gx] == 1:
				neighbors += 1
			if gy < grid_height - 1 and grid[(gy + 1) * grid_width + gx] == 1:
				neighbors += 1
			if neighbors <= 1:
				grid[idx] = 0

	# --- Step 4: Build raw RGBA pixel data with edge detection and coloring ---
	# Using PackedByteArray + Image.create_from_data() instead of per-pixel set_pixel()
	# for ~10-50x speedup. Each pixel = 4 bytes (R, G, B, A).
	var pixels := PackedByteArray()
	pixels.resize(grid_width * grid_height * 4)
	pixels.fill(0)  # All transparent by default

	# Pre-convert palette colors to byte values (avoid repeated float→int per pixel)
	var edge_r := int(palette.edge_color.r * 255.0)
	var edge_g := int(palette.edge_color.g * 255.0)
	var edge_b := int(palette.edge_color.b * 255.0)
	var base_r := palette.base_color.r
	var base_g := palette.base_color.g
	var base_b := palette.base_color.b
	var variation_range := palette.color_variation

	# Deterministic RNG for per-pixel color variation (seeded from asteroid's noise_seed)
	var rng := RandomNumberGenerator.new()
	rng.seed = noise_seed + 31337  # Offset so variation pattern differs from shape noise

	for gy in range(grid_height):
		for gx in range(grid_width):
			var idx := gy * grid_width + gx

			if grid[idx] == 0:
				continue  # Already transparent (filled with 0)

			# Check if this is an edge pixel (any 4-neighbor is empty or out of bounds)
			var is_edge := false
			if gx == 0 or grid[idx - 1] == 0:
				is_edge = true
			elif gx == grid_width - 1 or grid[idx + 1] == 0:
				is_edge = true
			elif gy == 0 or grid[(gy - 1) * grid_width + gx] == 0:
				is_edge = true
			elif gy == grid_height - 1 or grid[(gy + 1) * grid_width + gx] == 0:
				is_edge = true

			var pixel_offset := idx * 4
			if is_edge:
				pixels[pixel_offset] = edge_r
				pixels[pixel_offset + 1] = edge_g
				pixels[pixel_offset + 2] = edge_b
				pixels[pixel_offset + 3] = 255
			else:
				# Interior pixel: base color + random variation
				var variation := rng.randf_range(-variation_range, variation_range)
				pixels[pixel_offset] = int(clampf(base_r + variation, 0.0, 1.0) * 255.0)
				pixels[pixel_offset + 1] = int(clampf(base_g + variation, 0.0, 1.0) * 255.0)
				pixels[pixel_offset + 2] = int(clampf(base_b + variation, 0.0, 1.0) * 255.0)
				pixels[pixel_offset + 3] = 255

	# --- Step 5: Create image from raw bytes and assign texture ---
	var image := Image.create_from_data(grid_width, grid_height, false, Image.FORMAT_RGBA8, pixels)
	var texture := ImageTexture.create_from_image(image)
	visual.texture = texture

	# Position the sprite so its center aligns with the asteroid's origin.
	# The grid's min_pos is the world-space offset of the top-left corner.
	# Sprite2D.centered = true means it draws from -size/2 to +size/2.
	# We need to offset by the center of the bounding box.
	var grid_center := min_pos + Vector2(float(grid_width), float(grid_height)) * cell_size * 0.5
	visual.offset = grid_center

	# Scale the sprite so each pixel in the image covers cell_size world units
	visual.scale = Vector2(cell_size, cell_size)


# Regenerate texture from current grid state (for future mining — modify grid, then call this).
func _regenerate_texture_from_grid() -> void:
	if palette == null:
		palette = AsteroidPalette.new()

	var pixels := PackedByteArray()
	pixels.resize(grid_width * grid_height * 4)
	pixels.fill(0)

	var edge_r := int(palette.edge_color.r * 255.0)
	var edge_g := int(palette.edge_color.g * 255.0)
	var edge_b := int(palette.edge_color.b * 255.0)
	var base_r := palette.base_color.r
	var base_g := palette.base_color.g
	var base_b := palette.base_color.b
	var variation_range := palette.color_variation

	var rng := RandomNumberGenerator.new()
	rng.seed = noise_seed + 31337

	for gy in range(grid_height):
		for gx in range(grid_width):
			var idx := gy * grid_width + gx

			if grid[idx] == 0:
				continue

			var is_edge := false
			if gx == 0 or grid[idx - 1] == 0:
				is_edge = true
			elif gx == grid_width - 1 or grid[idx + 1] == 0:
				is_edge = true
			elif gy == 0 or grid[(gy - 1) * grid_width + gx] == 0:
				is_edge = true
			elif gy == grid_height - 1 or grid[(gy + 1) * grid_width + gx] == 0:
				is_edge = true

			var pixel_offset := idx * 4
			if is_edge:
				pixels[pixel_offset] = edge_r
				pixels[pixel_offset + 1] = edge_g
				pixels[pixel_offset + 2] = edge_b
				pixels[pixel_offset + 3] = 255
			else:
				var variation := rng.randf_range(-variation_range, variation_range)
				pixels[pixel_offset] = int(clampf(base_r + variation, 0.0, 1.0) * 255.0)
				pixels[pixel_offset + 1] = int(clampf(base_g + variation, 0.0, 1.0) * 255.0)
				pixels[pixel_offset + 2] = int(clampf(base_b + variation, 0.0, 1.0) * 255.0)
				pixels[pixel_offset + 3] = 255

	var image := Image.create_from_data(grid_width, grid_height, false, Image.FORMAT_RGBA8, pixels)
	var texture := ImageTexture.create_from_image(image)
	visual.texture = texture


# ============================================================
# NOISE POLYGON GENERATION (unchanged from previous sprint)
# ============================================================
# Generates the irregular asteroid silhouette by sampling layered Perlin noise
# along a unit circle in 2D noise space (ensures seamless wrapping with no seam).

func _make_noisy_polygon(r: float, points: int) -> PackedVector2Array:
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
