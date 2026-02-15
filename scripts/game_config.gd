# scripts/game_config.gd
# Autoload singleton that stores all tunable game parameters.
# Reads from user://config.cfg on startup; writes on every change.
# Other scripts read GameConfig.<property> instead of hard-coding defaults.
#
# Usage from any script:
#   var thrust := GameConfig.ship_thrust_force
#   GameConfig.ship_thrust_force = 200000.0   # auto-saves
extends Node

const CONFIG_PATH := "user://config.cfg"

# ============================================================
# SHIP
# ============================================================
var ship_thrust_force: float = 150000.0 : set = _set_ship_thrust_force
var ship_linear_damp: float = 0.9 : set = _set_ship_linear_damp
var ship_turn_speed: float = 4.5 : set = _set_ship_turn_speed
var ship_max_speed: float = 900.0 : set = _set_ship_max_speed
var ship_fuel_burn_per_sec: float = 5.0 : set = _set_ship_fuel_burn_per_sec
var ship_max_fuel: float = 100.0 : set = _set_ship_max_fuel
var ship_max_health: float = 100.0 : set = _set_ship_max_health
var ship_damage_per_impulse: float = 0.0005 : set = _set_ship_damage_per_impulse
var ship_damage_cooldown: float = 0.15 : set = _set_ship_damage_cooldown
var ship_mass: float = 200.0 : set = _set_ship_mass

# ============================================================
# CHUNK STREAMER
# ============================================================
var chunk_size_multiplier: float = 1.5 : set = _set_chunk_size_multiplier
var asteroid_density: float = 0.00001 : set = _set_asteroid_density
var spawn_radius_screens: float = 1.5 : set = _set_spawn_radius_screens
var despawn_radius_screens: float = 2.5 : set = _set_despawn_radius_screens
var radius_min: float = 16.0 : set = _set_radius_min
var radius_max: float = 192.0 : set = _set_radius_max
var power_law_alpha: float = 2.2 : set = _set_power_law_alpha
var global_seed: int = 123456 : set = _set_global_seed
var max_asteroids_per_frame: int = 20 : set = _set_max_asteroids_per_frame

# Density multiplier (the start-menu slider value, 0.2–3.0)
var density_multiplier: float = 1.0 : set = _set_density_multiplier

# ============================================================
# ASTEROID VISUAL / PHYSICS
# ============================================================
var asteroid_cell_size: float = 4.0 : set = _set_asteroid_cell_size
var asteroid_density_mass: float = 0.25 : set = _set_asteroid_density_mass

# Palette
var asteroid_base_color: Color = Color(0.40, 0.45, 0.55) : set = _set_asteroid_base_color
var asteroid_edge_color: Color = Color(0.82, 0.84, 0.88) : set = _set_asteroid_edge_color
var asteroid_color_variation: float = 0.06 : set = _set_asteroid_color_variation

# Shape noise
var noise_amplitude: float = 0.18 : set = _set_noise_amplitude
var noise_freq_min: float = 1.5 : set = _set_noise_freq_min
var noise_freq_max: float = 4.0 : set = _set_noise_freq_max
var medium_threshold: float = 60.0 : set = _set_medium_threshold
var medium_amplitude: float = 0.12 : set = _set_medium_amplitude
var medium_frequency: float = 0.8 : set = _set_medium_frequency
var large_threshold: float = 120.0 : set = _set_large_threshold
var large_amplitude: float = 0.15 : set = _set_large_amplitude
var large_frequency: float = 0.4 : set = _set_large_frequency

# ============================================================
# DISPLAY
# ============================================================
var viewport_width: int = 1920 : set = _set_viewport_width
var viewport_height: int = 1080 : set = _set_viewport_height

# ============================================================
# INTERNALS
# ============================================================
var _cfg: ConfigFile
var _dirty := false
# Suppress auto-save during initial load to avoid writing defaults on first run
var _loading := false


func _ready() -> void:
	_cfg = ConfigFile.new()
	_loading = true
	_load()
	_loading = false


# ============================================================
# LOAD / SAVE
# ============================================================

func _load() -> void:
	var err := _cfg.load(CONFIG_PATH)
	if err != OK:
		# No config file yet — use defaults (they're already set above)
		print("[GameConfig] No config file found, using defaults.")
		return

	print("[GameConfig] Loaded config from ", CONFIG_PATH)

	# Ship
	ship_thrust_force = _cfg.get_value("ship", "thrust_force", ship_thrust_force)
	ship_linear_damp = _cfg.get_value("ship", "linear_damp", ship_linear_damp)
	ship_turn_speed = _cfg.get_value("ship", "turn_speed", ship_turn_speed)
	ship_max_speed = _cfg.get_value("ship", "max_speed", ship_max_speed)
	ship_fuel_burn_per_sec = _cfg.get_value("ship", "fuel_burn_per_sec", ship_fuel_burn_per_sec)
	ship_max_fuel = _cfg.get_value("ship", "max_fuel", ship_max_fuel)
	ship_max_health = _cfg.get_value("ship", "max_health", ship_max_health)
	ship_damage_per_impulse = _cfg.get_value("ship", "damage_per_impulse", ship_damage_per_impulse)
	ship_damage_cooldown = _cfg.get_value("ship", "damage_cooldown", ship_damage_cooldown)
	ship_mass = _cfg.get_value("ship", "mass", ship_mass)

	# Chunk streamer
	chunk_size_multiplier = _cfg.get_value("chunks", "chunk_size_multiplier", chunk_size_multiplier)
	asteroid_density = _cfg.get_value("chunks", "asteroid_density", asteroid_density)
	spawn_radius_screens = _cfg.get_value("chunks", "spawn_radius_screens", spawn_radius_screens)
	despawn_radius_screens = _cfg.get_value("chunks", "despawn_radius_screens", despawn_radius_screens)
	radius_min = _cfg.get_value("chunks", "radius_min", radius_min)
	radius_max = _cfg.get_value("chunks", "radius_max", radius_max)
	power_law_alpha = _cfg.get_value("chunks", "power_law_alpha", power_law_alpha)
	global_seed = _cfg.get_value("chunks", "global_seed", global_seed)
	max_asteroids_per_frame = _cfg.get_value("chunks", "max_asteroids_per_frame", max_asteroids_per_frame)
	density_multiplier = _cfg.get_value("chunks", "density_multiplier", density_multiplier)

	# Asteroid visual/physics
	asteroid_cell_size = _cfg.get_value("asteroid", "cell_size", asteroid_cell_size)
	asteroid_density_mass = _cfg.get_value("asteroid", "density_mass", asteroid_density_mass)
	asteroid_base_color = _cfg.get_value("asteroid", "base_color", asteroid_base_color)
	asteroid_edge_color = _cfg.get_value("asteroid", "edge_color", asteroid_edge_color)
	asteroid_color_variation = _cfg.get_value("asteroid", "color_variation", asteroid_color_variation)

	# Shape noise
	noise_amplitude = _cfg.get_value("asteroid_noise", "amplitude", noise_amplitude)
	noise_freq_min = _cfg.get_value("asteroid_noise", "freq_min", noise_freq_min)
	noise_freq_max = _cfg.get_value("asteroid_noise", "freq_max", noise_freq_max)
	medium_threshold = _cfg.get_value("asteroid_noise", "medium_threshold", medium_threshold)
	medium_amplitude = _cfg.get_value("asteroid_noise", "medium_amplitude", medium_amplitude)
	medium_frequency = _cfg.get_value("asteroid_noise", "medium_frequency", medium_frequency)
	large_threshold = _cfg.get_value("asteroid_noise", "large_threshold", large_threshold)
	large_amplitude = _cfg.get_value("asteroid_noise", "large_amplitude", large_amplitude)
	large_frequency = _cfg.get_value("asteroid_noise", "large_frequency", large_frequency)

	# Display
	viewport_width = _cfg.get_value("display", "viewport_width", viewport_width)
	viewport_height = _cfg.get_value("display", "viewport_height", viewport_height)


func save() -> void:
	# Ship
	_cfg.set_value("ship", "thrust_force", ship_thrust_force)
	_cfg.set_value("ship", "linear_damp", ship_linear_damp)
	_cfg.set_value("ship", "turn_speed", ship_turn_speed)
	_cfg.set_value("ship", "max_speed", ship_max_speed)
	_cfg.set_value("ship", "fuel_burn_per_sec", ship_fuel_burn_per_sec)
	_cfg.set_value("ship", "max_fuel", ship_max_fuel)
	_cfg.set_value("ship", "max_health", ship_max_health)
	_cfg.set_value("ship", "damage_per_impulse", ship_damage_per_impulse)
	_cfg.set_value("ship", "damage_cooldown", ship_damage_cooldown)
	_cfg.set_value("ship", "mass", ship_mass)

	# Chunk streamer
	_cfg.set_value("chunks", "chunk_size_multiplier", chunk_size_multiplier)
	_cfg.set_value("chunks", "asteroid_density", asteroid_density)
	_cfg.set_value("chunks", "spawn_radius_screens", spawn_radius_screens)
	_cfg.set_value("chunks", "despawn_radius_screens", despawn_radius_screens)
	_cfg.set_value("chunks", "radius_min", radius_min)
	_cfg.set_value("chunks", "radius_max", radius_max)
	_cfg.set_value("chunks", "power_law_alpha", power_law_alpha)
	_cfg.set_value("chunks", "global_seed", global_seed)
	_cfg.set_value("chunks", "max_asteroids_per_frame", max_asteroids_per_frame)
	_cfg.set_value("chunks", "density_multiplier", density_multiplier)

	# Asteroid visual/physics
	_cfg.set_value("asteroid", "cell_size", asteroid_cell_size)
	_cfg.set_value("asteroid", "density_mass", asteroid_density_mass)
	_cfg.set_value("asteroid", "base_color", asteroid_base_color)
	_cfg.set_value("asteroid", "edge_color", asteroid_edge_color)
	_cfg.set_value("asteroid", "color_variation", asteroid_color_variation)

	# Shape noise
	_cfg.set_value("asteroid_noise", "amplitude", noise_amplitude)
	_cfg.set_value("asteroid_noise", "freq_min", noise_freq_min)
	_cfg.set_value("asteroid_noise", "freq_max", noise_freq_max)
	_cfg.set_value("asteroid_noise", "medium_threshold", medium_threshold)
	_cfg.set_value("asteroid_noise", "medium_amplitude", medium_amplitude)
	_cfg.set_value("asteroid_noise", "medium_frequency", medium_frequency)
	_cfg.set_value("asteroid_noise", "large_threshold", large_threshold)
	_cfg.set_value("asteroid_noise", "large_amplitude", large_amplitude)
	_cfg.set_value("asteroid_noise", "large_frequency", large_frequency)

	# Display
	_cfg.set_value("display", "viewport_width", viewport_width)
	_cfg.set_value("display", "viewport_height", viewport_height)

	var err := _cfg.save(CONFIG_PATH)
	if err == OK:
		print("[GameConfig] Saved config to ", CONFIG_PATH)
	else:
		push_warning("[GameConfig] Failed to save config: error %d" % err)


func _auto_save() -> void:
	if not _loading:
		save()


# ============================================================
# SETTERS (trigger auto-save on change)
# ============================================================

# Ship
func _set_ship_thrust_force(v: float) -> void:
	ship_thrust_force = v; _auto_save()
func _set_ship_linear_damp(v: float) -> void:
	ship_linear_damp = v; _auto_save()
func _set_ship_turn_speed(v: float) -> void:
	ship_turn_speed = v; _auto_save()
func _set_ship_max_speed(v: float) -> void:
	ship_max_speed = v; _auto_save()
func _set_ship_fuel_burn_per_sec(v: float) -> void:
	ship_fuel_burn_per_sec = v; _auto_save()
func _set_ship_max_fuel(v: float) -> void:
	ship_max_fuel = v; _auto_save()
func _set_ship_max_health(v: float) -> void:
	ship_max_health = v; _auto_save()
func _set_ship_damage_per_impulse(v: float) -> void:
	ship_damage_per_impulse = v; _auto_save()
func _set_ship_damage_cooldown(v: float) -> void:
	ship_damage_cooldown = v; _auto_save()
func _set_ship_mass(v: float) -> void:
	ship_mass = v; _auto_save()

# Chunks
func _set_chunk_size_multiplier(v: float) -> void:
	chunk_size_multiplier = v; _auto_save()
func _set_asteroid_density(v: float) -> void:
	asteroid_density = v; _auto_save()
func _set_spawn_radius_screens(v: float) -> void:
	spawn_radius_screens = v; _auto_save()
func _set_despawn_radius_screens(v: float) -> void:
	despawn_radius_screens = v; _auto_save()
func _set_radius_min(v: float) -> void:
	radius_min = v; _auto_save()
func _set_radius_max(v: float) -> void:
	radius_max = v; _auto_save()
func _set_power_law_alpha(v: float) -> void:
	power_law_alpha = v; _auto_save()
func _set_global_seed(v: int) -> void:
	global_seed = v; _auto_save()
func _set_max_asteroids_per_frame(v: int) -> void:
	max_asteroids_per_frame = v; _auto_save()
func _set_density_multiplier(v: float) -> void:
	density_multiplier = v; _auto_save()

# Asteroid visual
func _set_asteroid_cell_size(v: float) -> void:
	asteroid_cell_size = v; _auto_save()
func _set_asteroid_density_mass(v: float) -> void:
	asteroid_density_mass = v; _auto_save()
func _set_asteroid_base_color(v: Color) -> void:
	asteroid_base_color = v; _auto_save()
func _set_asteroid_edge_color(v: Color) -> void:
	asteroid_edge_color = v; _auto_save()
func _set_asteroid_color_variation(v: float) -> void:
	asteroid_color_variation = v; _auto_save()

# Noise
func _set_noise_amplitude(v: float) -> void:
	noise_amplitude = v; _auto_save()
func _set_noise_freq_min(v: float) -> void:
	noise_freq_min = v; _auto_save()
func _set_noise_freq_max(v: float) -> void:
	noise_freq_max = v; _auto_save()
func _set_medium_threshold(v: float) -> void:
	medium_threshold = v; _auto_save()
func _set_medium_amplitude(v: float) -> void:
	medium_amplitude = v; _auto_save()
func _set_medium_frequency(v: float) -> void:
	medium_frequency = v; _auto_save()
func _set_large_threshold(v: float) -> void:
	large_threshold = v; _auto_save()
func _set_large_amplitude(v: float) -> void:
	large_amplitude = v; _auto_save()
func _set_large_frequency(v: float) -> void:
	large_frequency = v; _auto_save()

# Display
func _set_viewport_width(v: int) -> void:
	viewport_width = v; _auto_save()
func _set_viewport_height(v: int) -> void:
	viewport_height = v; _auto_save()
