# scripts/world.gd
extends Node2D

@onready var fuel_bar: ProgressBar = $UI/StatusBars/FuelBox/FuelBar
@onready var fuel_label: Label = $UI/StatusBars/FuelBox/FuelLabel
@onready var health_bar: ProgressBar = $UI/StatusBars/HealthBox/HealthBar
@onready var health_label: Label = $UI/StatusBars/HealthBox/HealthLabel

@onready var game_over_label: Label = $UI/GameOverLabel
@onready var pause_label: Label = $UI/PauseLabel
var is_game_over := false
var game_started := false

# Start menu references
@onready var start_menu: CanvasLayer = $StartMenu
@onready var sld_alpha: HSlider = $StartMenu/CenterContainer/VBoxContainer/AlphaBox/AlphaSlider
@onready var lbl_alpha_value: Label = $StartMenu/CenterContainer/VBoxContainer/AlphaBox/AlphaValue
@onready var sld_density: HSlider = $StartMenu/CenterContainer/VBoxContainer/DensityBox/DensitySlider
@onready var lbl_density_value: Label = $StartMenu/CenterContainer/VBoxContainer/DensityBox/DensityValue

@onready var ship: Ship = $Ship
@onready var chunk_streamer: ChunkStreamer = $ChunkStreamer
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
@onready var sld_dmg: HSlider = $UI/TuningPanel/VBox/HBoxDmg/HSliderDmg
@onready var lbl_dmg: Label = $UI/TuningPanel/VBox/HBoxDmg/LabelDmg


func _ready() -> void:
	# Resolve camera and initialize chunk streaming system
	cam = $Ship/Camera2D
	var viewport_size := get_viewport().get_visible_rect().size
	var camera_zoom := cam.zoom if cam else Vector2.ONE
	chunk_streamer.initialize(viewport_size, camera_zoom)

	# Inicializa UI
	_apply_tuning_from_sliders()

	ship.refuel_full()
	ship.heal_full()
	_update_fuel_ui()
	_update_health_ui()
	game_over_label.visible = false

	# Conecta señales
	sld_thrust.value_changed.connect(_on_tuning_changed)
	sld_damp.value_changed.connect(_on_tuning_changed)
	sld_turn.value_changed.connect(_on_tuning_changed)
	sld_fuel_burn.value_changed.connect(_on_tuning_changed)
	sld_dmg.value_changed.connect(_on_tuning_changed)

	get_tree().paused = false
	print("World ready. paused =", get_tree().paused)

	print("Camera enabled=", cam.enabled)
	cam.enabled = true
	print("Camera enabled=", cam.enabled)
	print("Active viewport cam =", get_viewport().get_camera_2d(), " my cam =", cam)

	# Start menu setup: sync sliders to current values and connect signals
	sld_alpha.value = chunk_streamer.power_law_alpha
	lbl_alpha_value.text = "%.1f" % chunk_streamer.power_law_alpha
	sld_alpha.value_changed.connect(_on_alpha_slider_changed)

	# Density slider: value is a multiplier (0.2x – 2.0x), default 1.0x
	sld_density.value = 1.0
	lbl_density_value.text = "1.0x"
	sld_density.value_changed.connect(_on_density_slider_changed)

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
	_update_health_ui()
	_check_game_over()

	if Input.is_action_just_pressed("toggle_tuning"):
		$UI/TuningPanel.visible = not $UI/TuningPanel.visible

	if Input.is_action_just_pressed("pause") and not is_game_over:
		get_tree().paused = not get_tree().paused
		pause_label.visible = get_tree().paused

	# Update asteroids chunk streaming system
	if not get_tree().paused:
		chunk_streamer.update_streaming(ship.global_position)


# ============================================================
# UI HELPERS
# ============================================================

func _update_fuel_ui() -> void:
	var maxf: float = max(1.0, ship.max_fuel)
	var f: float = clamp(ship.fuel, 0.0, maxf)

	fuel_bar.value = f / maxf


func _update_health_ui() -> void:
	var maxh: float = max(1.0, ship.max_health)
	var h: float = clamp(ship.health, 0.0, maxh)

	health_bar.value = h / maxh


func _check_game_over() -> void:
	if is_game_over:
		return

	if ship.fuel <= 0.0:
		is_game_over = true
		game_over_label.text = "OUT OF FUEL\nPress R to restart"
		game_over_label.visible = true
		get_tree().paused = true
		ship.linear_damp = sld_damp.max_value
	elif ship.health <= 0.0:
		is_game_over = true
		game_over_label.text = "SHIP DESTROYED\nPress R to restart"
		game_over_label.visible = true
		get_tree().paused = true
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
	chunk_streamer.power_law_alpha = value
	lbl_alpha_value.text = "%.1f" % value


func _on_density_slider_changed(value: float) -> void:
	"""Update asteroid_density based on multiplier slider (0.2x – 2.0x)."""
	var default_density: float = 0.00003
	chunk_streamer.asteroid_density = default_density * value
	lbl_density_value.text = "%.1fx" % value


func _start_game() -> void:
	"""Transition from menu to gameplay."""
	game_started = true

	# Hide menu, show gameplay elements
	start_menu.visible = false
	ship.visible = true
	ship.freeze = false
	$UI.visible = true

	# Initialize ship
	ship.refuel_full()
	ship.heal_full()
	_update_fuel_ui()
	_update_health_ui()

	print("Game started! power_law_alpha = ", chunk_streamer.power_law_alpha)


# ============================================================
# TUNING PANEL
# ============================================================

func _on_tuning_changed(_v: float) -> void:
	_apply_tuning_from_sliders()

func _apply_tuning_from_sliders() -> void:
	var thrust := float(sld_thrust.value)
	var damp := float(sld_damp.value)
	var turn := float(sld_turn.value)
	var fuel_burn := float(sld_fuel_burn.value)
	var dmg := float(sld_dmg.value)

	# Ship script variables
	ship.thrust_force = thrust
	ship.turn_speed = turn
	ship.linear_damp = damp 	# Propiedad directa del RigidBody2D
	ship.fuel_burn_per_sec = fuel_burn
	ship.max_fuel = 100.0
	ship.damage_per_impulse = dmg

	lbl_thrust.text = "Thrust: %d" % int(thrust)
	lbl_damp.text = "Linear damp: %.2f" % damp
	lbl_turn.text = "Turn: %.1f" % turn
	lbl_fuel_burn.text = "Fuel burn: %.0f/s" % fuel_burn
	lbl_dmg.text = "Dmg/impulse: %.4f" % dmg
