# AsteroidMiner — Sprint 3 Snapshot (Current Game State)

## 🎯 Current Sprint Status
**Sprint 3: Core Movement & Fuel System** ✅ COMPLETE

## 📋 Next Session Priorities
1. Begin asteroid destruction mechanics (design carving approach)
2. Plan gas particle system architecture
3. Prototype fuel-making mode state machine
4. Decide on asteroid mask rendering approach (texture vs shader)

## ⚠️ Known Issues / Technical Debt
- Asteroids are static circles - no mining/destruction implemented
- No visual feedback for thrust (particle effects needed)
- Tuning panel values not persisted between sessions
- No collision detection between ship and asteroids
- Ship sprite is placeholder (needs pixel art per GDD)
- No background/stars

## 🔄 Recent Changes (Last Updated: January 2026)
- ✅ Implemented fuel consumption system with visual UI bar
- ✅ Added game over state when fuel depletes
- ✅ Created tuning panel for real-time ship parameter adjustment
- ✅ Ship physics working with custom integrator (thrust + turning)
- ✅ Pause system functional
- ✅ Camera smoothing enabled

---

## What the game is right now

A single "World" scene runs the whole loop. You pilot a ship with Asteroids-style thrust + turning, in a zero-gravity 2D space. Fuel is a hard constraint: thrust consumes fuel continuously; when fuel hits zero the game pauses and shows a "OUT OF FUEL — Press R to restart" label. There are a handful of big frozen asteroids spawned at startup as spatial reference points (currently just static obstacles/landmarks).

## Scene / node structure

`World` (Node2D) is the root.

Inside it:

* `Ship` is an instanced Ship.tscn and is a RigidBody2D with the Ship script attached. It has lock_rotation = true at the node level, and it contains Camera2D as a child.

* `Camera2D` is enabled and uses position smoothing.

* `UI` (CanvasLayer) contains:

  * `TuningPanel` (PanelContainer) → VBoxContainer → five rows, each row has a label + slider for thrust, damp, turn, fuel burn, max fuel.

  * `GameOverLabel` (Label) hidden by default, centered-ish, shows the out-of-fuel message.

  * `FuelBox` (VBoxContainer) at bottom-left-ish: FuelLabel ("Fuel") + FuelBar (ProgressBar). The bar is normalized to [0,1] by setting `value = fuel/max_fuel`.

## Inputs assumed by code

The code uses these actions (must exist in Input Map): `thrust`, `turn_left`, `turn_right`, `restart`, `toggle_tuning`, `pause`.

## World logic (world.gd)

`World` owns the "meta" loop: UI updates, tuning propagation, spawning test asteroids, pause/restart/game-over state.

On `_ready()` it does the following, in this order:

1. Spawns a small set of "test asteroids" (5) using a preloaded Asteroid.tscn, sets each asteroid's radius, sets it to frozen = true, places them at fixed positions.

2. Applies tuning values from the sliders to the ship (thrust, turn speed, damp, fuel burn rate, max fuel). This is done via `_apply_tuning_to_ship()`.

3. Refuels the ship to full (ship.refuel_full()), updates the fuel UI, hides the game over label.

4. Connects all slider value_changed signals to `_on_tuning_changed()`.

5. Ensures the tree is unpaused; explicitly enables the ship camera and prints debug info about camera selection.

During `_process(delta)` it:

* Updates the fuel bar every frame (normalized to max fuel).

* Checks game over: if `ship.fuel <= 0` and not already game over, sets `is_game_over = true`, shows the label, pauses the tree, and forces the ship to high damp so it stops moving.

* Handles "restart" by unpausing and reloading the current scene.

* Toggles tuning panel visibility.

* Toggles pause (only if not game over).

Key detail: fuel UI updates even when paused (because it's done in `_process`), but physics thrust won't run while paused.

## Ship logic (ship.gd)

The ship is a `RigidBody2D` with arcade-ish settings: `gravity_scale = 0`, linear_damp default 0.9, angular_damp 6.0, and it hard-prevents spin/torque.

Movement is split across callbacks:

* `_physics_process(delta)` is where thrust + fuel burn happens only if not paused.

  * If `thrust` is pressed and `fuel > 0`: it applies a central force in the ship's local +X direction (`transform.x.normalized()`), and subtracts `fuel_burn_per_sec * delta`.

  * After that it clamps `linear_velocity` to `max_speed`.

  * There's debug printing every ~0.33s while thrust is pressed, to confirm paused/freeze/custom integrator/fuel etc.

* `_integrate_forces(state)` is used for turning and anti-torque:

  * Every physics step, it sets `state.angular_velocity = 0.0` so collisions don't spin the ship.

  * If not paused, it reads turn input and directly modifies `state.transform` rotation by `turn_speed * state.step`.

* `_process(delta)` only does one thing: if the tree is paused, it still rotates the ship visually using input, so you can "turn" while paused (even though physics isn't integrating).

Fuel helpers: refuel_full() sets fuel = max_fuel; has_fuel() is fuel > 0.

## Asteroid logic (asteroid.gd)

An asteroid is a `RigidBody2D` that can be "frozen" (static) and has a procedural circle visual + collision driven by its `radius`.

Important behaviors:

* `radius` is an exported property with a setter. Setting it triggers `_apply_radius()` once the node is inside the tree; if assigned before `_ready()`, it sets a `_pending_radius_apply` flag and applies later.

* `_apply_radius()` always creates a new `CircleShape2D` so collision shapes aren't shared between instances.

* `mass` is computed from area (PI * r^2 * density) with a minimum clamp.

* `visual` is a Polygon2D generated as a 48-point circle polygon.

* `frozen` sets freeze = v and uses `FREEZE_MODE_STATIC`.

Right now, asteroids are effectively static landmarks (frozen true in the world spawner), but the script supports dynamic ones.

## Current "game over"

The only death condition implemented is fuel depletion. When fuel reaches 0:

* `World` pauses the whole tree.

* `GameOverLabel` becomes visible.

* The ship is forced to stop quickly by boosting its linear damp to max slider value.

* Pressing restart reloads the scene.
