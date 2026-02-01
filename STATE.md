# AsteroidMiner — Sprint 4 Snapshot (Current Game State)

## 🎯 Current Sprint Status

**Sprint 4: Asteroid Stream Spawner System** ✅ COMPLETE

---

## 📋 Next Session Priorities

1. **Implement collision avoidance during asteroid spawning**
   - Check for overlaps before finalizing spawn position
   - Reject positions that would cause asteroids to overlap
   - Consider performance implications (spatial queries vs brute force)

2. **Implement ship-asteroid collisions**
   - Enable physics collisions between ship and asteroids
   - Ship is indestructible (for now) but can impart momentum to asteroids
   - Asteroids should collide with each other (chain reactions)
   - Discuss computational feasibility and optimization strategies

3. **Add ship health/damage system** (after collisions work)
   - Implement life bar UI
   - Decrease health on asteroid collision
   - Consider damage scaling based on collision velocity/asteroid size

---

## ⚠️ Known Issues / Technical Debt

- Asteroids spawn with overlaps (no collision avoidance yet)
- No collision detection between ship and asteroids
- No collision response between asteroids themselves
- Ship sprite is placeholder (needs pixel art per GDD)
- No visual feedback for thrust (particle effects needed)
- Tuning panel values not persisted between sessions
- No background/stars

---

## 📦 Recent Changes (Last Updated: February 2026)

### Sprint 4: Asteroid Stream Spawner System
- ✅ Implemented chunk-based infinite world streaming
- ✅ Deterministic procedural generation per chunk (seeded RNG)
- ✅ Power-law radius distribution (many small, few large asteroids)
- ✅ Dynamic spawning based on ship position (spawn_radius)
- ✅ Dynamic despawning of far asteroids (despawn_radius)
- ✅ Chunk size auto-calculated from viewport (1.5× screen width)
- ✅ Density-based asteroid count per chunk (tunable via export vars)
- ✅ Asteroids spawn with zero velocity (static relative to world)

### Sprint 3: Core Movement & Fuel System (Previous)
- ✅ Implemented fuel consumption system with visual UI bar
- ✅ Added game over state when fuel depletes
- ✅ Created tuning panel for real-time ship parameter adjustment
- ✅ Ship physics working with custom integrator (thrust + turning)
- ✅ Pause system functional
- ✅ Camera smoothing enabled

---

## 🎮 What the Game Is Right Now

A 2D top-down space traversal prototype. You pilot a ship with Asteroids-style thrust and turning in zero-gravity 2D space. The game generates an **infinite procedural asteroid field** using a chunk streaming system—asteroids spawn ahead of you and despawn behind as you explore. Fuel is a hard constraint: thrust consumes fuel continuously; when fuel hits zero the game pauses and shows an "OUT OF FUEL — Press R to restart" label.

The asteroid field feels infinite and coherent—revisiting the same world coordinates generates the same asteroids (deterministic). Asteroids vary in size following a power-law distribution (mostly small, occasionally large).

**Current limitations**: No mining mechanics, no collisions, asteroids spawn overlapped, no visual polish.

---

## 🏗️ Scene / Node Structure

**World** (Node2D) is the root.

Inside it:

- **Ship** is an instanced Ship.tscn and is a RigidBody2D with the Ship script attached. It has `lock_rotation = true` at the node level, and contains Camera2D as a child.

- **Camera2D** is enabled and uses position smoothing.

- **UI** (CanvasLayer) contains:
  - **TuningPanel** (PanelContainer) → VBoxContainer → five rows, each row has a label + slider for thrust, damp, turn, fuel burn, max fuel.
  - **GameOverLabel** (Label) hidden by default, centered-ish, shows the out-of-fuel message.
  - **FuelBox** (VBoxContainer) at bottom-left-ish: FuelLabel ("Fuel") + FuelBar (ProgressBar). The bar is normalized to [0,1] by setting `value = fuel/max_fuel`.

- **Asteroids** are spawned dynamically as children of World using the chunk streaming system. They are RigidBody2D instances from Asteroid.tscn with:
  - `freeze = false` (not frozen, but have zero velocity)
  - `linear_velocity = Vector2.ZERO`
  - `angular_velocity = 0.0`
  - Radius determines size (collision shape + visual)

---

## 🧠 Inputs Assumed by Code

The code uses these actions (must exist in Input Map):
- `thrust`
- `turn_left`
- `turn_right`
- `restart`
- `toggle_tuning`
- `pause`

---

## 🌍 World Logic (world.gd)

**World** owns the "meta" loop: UI updates, tuning propagation, chunk streaming system, pause/restart/game-over state.

### Chunk Streaming System

On `_ready()` it:
1. Calculates `screen_size` from viewport and camera zoom
2. Calculates `chunk_size = screen_size.x * chunk_size_multiplier` (default 1.5)
3. Calculates `spawn_radius` and `despawn_radius` based on screen size multiples
4. Initializes ship fuel, UI, and tuning panel
5. Enables camera and prints debug info

During `_process(delta)` it:
- Updates the fuel bar every frame (normalized to max fuel)
- Checks game over: if `ship.fuel <= 0` and not already game over, sets `is_game_over = true`, shows the label, pauses the tree, and forces the ship to high damp so it stops moving
- Handles "restart" by unpausing and reloading the current scene
- Toggles tuning panel visibility
- Toggles pause (only if not game over)
- **Calls `_update_chunk_system()`** every frame when not paused

### Chunk System Methods

- `_update_chunk_system()`: Calls spawn and despawn logic
- `_spawn_chunks_around(center)`: Iterates through chunk grid around ship, spawns any unvisited chunks within `spawn_radius`
- `_spawn_chunk(chunk_key)`: 
  - Seeds RNG deterministically using `_hash_chunk(chunk_key)`
  - Calculates asteroid count based on `chunk_size² * asteroid_density`
  - Generates random positions and power-law distributed radii
  - Instantiates asteroids and stores them in `spawned_chunks` dictionary
- `_despawn_far_asteroids(center)`: Removes asteroids beyond `despawn_radius`, cleans up empty chunks
- `_world_to_chunk()` / `_chunk_to_world()`: Coordinate conversion helpers
- `_hash_chunk()`: Deterministic seed generation combining `global_seed` with chunk coordinates
- `_sample_power_law_radius()`: Power-law distribution for asteroid sizes
- `_create_asteroid()`: Instantiates Asteroid.tscn with position and radius

**Key detail**: Fuel UI updates even when paused (because it's done in `_process`), but physics thrust won't run while paused.

**Export variables for tuning**:
- `chunk_size_multiplier`: How many screens wide is a chunk (default 1.5)
- `asteroid_density`: Asteroids per square world unit (default 0.00003)
- `spawn_radius_screens`: Spawn radius in screen sizes (default 3.5)
- `despawn_radius_screens`: Despawn radius in screen sizes (default 5.0)
- `radius_min` / `radius_max`: Asteroid size range (16.0 - 192.0)
- `power_law_alpha`: Distribution shape parameter (default 2.2)
- `global_seed`: Seed for deterministic generation (default 123456)

---

## 🚀 Ship Logic (ship.gd)

The ship is a **RigidBody2D** with arcade-ish settings: `gravity_scale = 0`, `linear_damp` default 0.9, `angular_damp` 6.0, and it hard-prevents spin/torque.

Movement is split across callbacks:

- `_physics_process(delta)` is where thrust + fuel burn happens only if not paused:
  - If thrust is pressed and `fuel > 0`: it applies a central force in the ship's local +X direction (`transform.x.normalized()`), and subtracts `fuel_burn_per_sec * delta`.
  - After that it clamps `linear_velocity` to `max_speed`.
  - There's debug printing every ~0.33s while thrust is pressed, to confirm paused/freeze/custom integrator/fuel etc.

- `_integrate_forces(state)` is used for turning and anti-torque:
  - Every physics step, it sets `state.angular_velocity = 0.0` so collisions don't spin the ship.
  - If not paused, it reads turn input and directly modifies `state.transform` rotation by `turn_speed * state.step`.

- `_process(delta)` only does one thing: if the tree is paused, it still rotates the ship visually using input, so you can "turn" while paused (even though physics isn't integrating).

**Fuel helpers**: `refuel_full()` sets `fuel = max_fuel`; `has_fuel()` is `fuel > 0`.

---

## 🪨 Asteroid Logic (asteroid.gd)

An asteroid is a **RigidBody2D** that can be "frozen" (static) and has a procedural circle visual + collision driven by its **radius**.

**Important behaviors**:

- `radius` is an exported property with a setter. Setting it triggers `_apply_radius()` once the node is inside the tree; if assigned before `_ready()`, it sets a `_pending_radius_apply` flag and applies later.

- `_apply_radius()` always creates a new **CircleShape2D** so collision shapes aren't shared between instances.

- `mass` is computed from area (PI * r^2 * density) with a minimum clamp.

- `visual` is a Polygon2D generated as a 48-point circle polygon.

- `frozen` sets `freeze = v` and uses `FREEZE_MODE_STATIC`.

Right now, asteroids are effectively static landmarks (frozen true in the world spawner for Sprint 3, but support dynamic ones). The script supports dynamic asteroids with velocity, but chunk spawner sets them to zero velocity and `freeze = false`.

---

## 🎬 Current "Game Over"

The only death condition implemented is fuel depletion. When fuel reaches 0:

- **World** pauses the whole tree.
- **GameOverLabel** becomes visible.
- The ship is forced to stop quickly by boosting its linear damp to max slider value.
- Pressing restart reloads the scene.

---

## 🔧 Tuning System

The tuning panel has sliders for:
- Thrust force
- Linear damping
- Turn speed
- Fuel burn rate
- Max fuel capacity

All sliders are connected to `_on_tuning_changed()` which calls `_apply_tuning_from_sliders()`. This reads slider values and assigns them to ship properties. Labels update to show current values.

Values are **not persisted** between sessions—they reset to slider defaults on restart.

---

## 🎨 Visual State

- **Ship**: Placeholder sprite (needs proper pixel art per GDD visual constraints)
- **Asteroids**: Procedural white circle polygons (48 vertices)
- **Background**: Plain Godot default (needs starfield)
- **UI**: Functional but basic styling

---

## 📊 Performance Characteristics

- Chunk system spawns/despawns efficiently based on distance
- Deterministic generation means no cache needed for revisiting chunks (they regenerate identically)
- Current density settings spawn ~10-20 asteroids per chunk
- No performance issues observed at default settings
- Asteroids currently have no physics interactions (all static relative to world)

---

## 🚧 Deferred Features (Stage 2)

These are explicitly **out of scope** until core loop is complete:
- Enemies
- Combat mechanics
- Projectiles
- Enemy AI
- Weapon systems

---

## 🎓 Learning Notes

This sprint taught:
- **Chunk-based world streaming** for infinite procedural content
- **Deterministic generation** using seeded RNG and hash functions
- **Power-law distributions** for natural-looking size variation
- **Spatial partitioning** concepts (chunk grid)
- **Godot's RNG system** and seed management
- **Export variable patterns** for designer-friendly tuning

---

## 📝 Implementation Notes for Next Sprint

### Collision Avoidance During Spawn
**Considerations**:
- Need to check if new asteroid position overlaps with existing asteroids in chunk
- Options:
  1. **Brute force**: Check distance against all asteroids in current chunk (simple, works for low density)
  2. **Rejection sampling**: Try random positions until non-overlapping found (may fail for high density)
  3. **Spatial grid**: More complex but scales better
- Recommend starting with rejection sampling with max attempts (e.g., 10 tries, then accept overlap)
- Consider adding minimum spacing parameter (e.g., `radius_a + radius_b + min_gap`)

### Ship-Asteroid Collisions
**Considerations**:
- Enable collision layers/masks between ship and asteroids
- Ship RigidBody2D will naturally interact with asteroid RigidBody2D
- **Performance concern**: Many dynamic asteroids = many physics calculations
  - Current frozen=false but zero velocity is OK (physics engine handles sleeping)
  - Chain reactions could wake many asteroids
- May need collision damping to prevent excessive bouncing
- Consider limiting number of "active" (non-sleeping) asteroids
- Potential optimization: keep asteroids frozen until ship is nearby

### Health System
**Simple approach**:
- Add `@export var max_health: float = 100.0` to ship
- Add `var health: float = max_health`
- Connect to `body_entered` signal or use `_integrate_forces` collision detection
- Calculate damage from `collision_impulse.length()` or relative velocity
- Add UI health bar (similar to fuel bar)
- Game over when `health <= 0`

---

**End of STATE.md**
