# AsteroidMiner — Sprint 6 Snapshot (Current Game State)

## 🎯 Current Sprint Status

**Sprint 6: Background, Start Menu & UI Cleanup** ✅ COMPLETE

---

## 📋 Next Session Priorities

1. **Implement ship-asteroid collisions**
   - Enable physics collisions between ship and asteroids
   - Ship is indestructible (for now) but can impart momentum to asteroids
   - Asteroids should collide with each other (chain reactions)
   - Discuss computational feasibility and optimization strategies

2. **Add ship health/damage system** (after collisions work)
   - Implement life bar UI
   - Decrease health on asteroid collision
   - Consider damage scaling based on collision velocity/asteroid size

3. **Visual polish**
   - Ship sprite (needs pixel art per GDD)
   - Background/starfield
   - Thrust particle effects

---

## ⚠️ Known Issues / Technical Debt

- No collision detection between ship and asteroids
- No collision response between asteroids themselves
- Collision shape is CircleShape2D (base radius) while visual is irregular — minor mismatch at noise edges
- Ship sprite is placeholder (needs pixel art per GDD)
- No visual feedback for thrust (particle effects needed)
- Tuning panel values not persisted between sessions
- Cannot visually inspect asteroid chunks in Godot's 2D editor (Polygon2D visuals don't render in Remote view — would need debug draw or sprites)

---

## 📦 Recent Changes (Last Updated: February 2026)

### Sprint 6: Background, Start Menu & UI Cleanup
- ✅ Added seamless tileable starfield background (ParallaxBackground with 0.1x motion scale)
- ✅ Background texture: "2D Starfield 1" from SpaceSphereMaps (2048×2048, free license)
- ✅ Added start menu screen with title "ASTEROID MINER" and "Press any key to start"
- ✅ Start menu includes power-law alpha slider (1.5–4.0) for tweaking asteroid size distribution before gameplay
- ✅ Game stays frozen on menu until player presses any key (uses `_unhandled_input` so slider clicks don't trigger start)
- ✅ Removed max fuel slider — max fuel hardcoded to 100
- ✅ Fixed GameOverLabel positioning (was offset off-screen, now centered)
- ✅ Fixed restart crash (added `return` after `reload_current_scene()` to prevent accessing freed nodes)
- ✅ Added credits section to GDD.md

### Sprint 5: Overlap Avoidance & Irregular Asteroid Shapes
- ✅ Implemented spawn overlap avoidance via rejection sampling (up to 10 attempts per asteroid)
- ✅ Overlap check uses full circle-circle intersection (sum of both radii)
- ✅ Cross-chunk overlap avoidance — checks 8 neighboring chunks for boundary overlaps
- ✅ Irregular asteroid shapes using layered Perlin noise (FastNoiseLite)
- ✅ Noise sampled on unit circle in 2D noise space for seamless wrapping (no seam)
- ✅ Base noise frequency scales with asteroid radius (small=smooth, large=more bumps)
- ✅ Three noise layers gated by radius thresholds:
  - Base layer (all asteroids): small surface bumps
  - Medium layer (radius >= 60): broad lumps/dents
  - Large layer (radius >= 120): overall shape warp/elongation
- ✅ Each layer uses independent seed offset for uncorrelated patterns
- ✅ `max_radius` tracked per asteroid (actual furthest vertex) for accurate overlap checks
- ✅ Worst-case amplitude estimation for new asteroids during spawn checks
- ✅ All noise parameters exported and tunable in Godot inspector via Asteroid.tscn
- ✅ Deterministic shapes — each asteroid gets a seed from the chunk RNG

### Sprint 4: Asteroid Stream Spawner System (Previous)
- ✅ Implemented chunk-based infinite world streaming
- ✅ Deterministic procedural generation per chunk (seeded RNG)
- ✅ Power-law radius distribution (many small, few large asteroids)
- ✅ Dynamic spawning based on ship position (spawn_radius)
- ✅ Dynamic despawning of far asteroids (despawn_radius)
- ✅ Chunk size auto-calculated from viewport (1.5x screen width)
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

A 2D top-down space traversal prototype. The game opens with a **start menu** showing "ASTEROID MINER" over a scrolling starfield background, where you can tweak the power-law alpha parameter before pressing any key to start. You pilot a ship with Asteroids-style thrust and turning in zero-gravity 2D space. The game generates an **infinite procedural asteroid field** using a chunk streaming system — asteroids spawn ahead of you and despawn behind as you explore. Fuel is a hard constraint (max 100): thrust consumes fuel continuously; when fuel hits zero the game pauses and shows a centered "OUT OF FUEL — Press R to restart" label.

The asteroid field feels infinite and coherent — revisiting the same world coordinates generates the same asteroids (deterministic). Asteroids vary in size following a power-law distribution (mostly small, occasionally large). **Asteroids have irregular, natural-looking shapes** generated via layered Perlin noise, with larger asteroids having more complex shapes (additional noise layers for broad lumps and overall shape warp). Asteroids **never overlap** thanks to rejection sampling with cross-chunk boundary checks.

**Current limitations**: No mining mechanics, no collisions, ship sprite is placeholder.

---

## 🏗️ Scene / Node Structure

**World** (Node2D) is the root.

Inside it:

- **ParallaxBackground** → ParallaxLayer (motion_scale 0.1, mirroring 2048×2048) → Sprite2D (starfield texture, centered=false)

- **Ship** is an instanced Ship.tscn and is a RigidBody2D with the Ship script attached. It has `lock_rotation = true` at the node level, and contains Camera2D as a child.

- **Camera2D** is enabled and uses position smoothing.

- **UI** (CanvasLayer) contains:
  - **TuningPanel** (PanelContainer) → VBoxContainer → four rows, each row has a label + slider for thrust, damp, turn, fuel burn.
  - **GameOverLabel** (Label) hidden by default, centered on screen, shows the out-of-fuel message.
  - **FuelBox** (VBoxContainer) at bottom-left: FuelLabel ("Fuel") + FuelBar (ProgressBar). The bar is normalized to [0,1] by setting `value = fuel/max_fuel`.

- **StartMenu** (CanvasLayer, layer=10) contains:
  - CenterContainer → VBoxContainer with title label, power-law alpha slider (1.5–4.0), and "Press any key to start" label.
  - Hidden after game starts. Reappears on restart (scene reload).

- **Asteroids** are spawned dynamically as children of World using the chunk streaming system. They are RigidBody2D instances from Asteroid.tscn with:
  - `freeze = false` (not frozen, but have zero velocity)
  - `linear_velocity = Vector2.ZERO`
  - `angular_velocity = 0.0`
  - Radius determines size (collision shape = CircleShape2D, visual = irregular Polygon2D from noise)
  - Each asteroid has a unique `noise_seed` for deterministic shape generation
  - `max_radius` tracks the actual furthest vertex extent (used for overlap checks)

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
1. Caches worst-case noise amplitude from Asteroid.tscn defaults (sum of all layer amplitudes)
2. Calculates `screen_size` from viewport and camera zoom
3. Calculates `chunk_size = screen_size.x * chunk_size_multiplier` (default 1.5)
4. Calculates `spawn_radius` and `despawn_radius` based on screen size multiples
5. Initializes ship fuel, UI, and tuning panel
6. Enables camera and prints debug info

During `_process(delta)` it:
- Handles "restart" (always available, even on menu) — unpauses and reloads scene, then returns immediately to avoid accessing freed nodes
- If `game_started` is false, returns early (menu is showing)
- Updates the fuel bar every frame (normalized to max fuel)
- Checks game over: if `ship.fuel <= 0` and not already game over, sets `is_game_over = true`, shows the label, pauses the tree, and forces the ship to high damp so it stops moving
- Toggles tuning panel visibility
- Toggles pause (only if not game over)
- **Calls `_update_chunk_system()`** every frame when not paused

Start menu logic:
- `_unhandled_input()` detects any key/click/button press and calls `_start_game()`
- `_start_game()` sets `game_started = true`, hides menu, shows ship + UI, unfreezes ship
- `_on_alpha_slider_changed()` updates `power_law_alpha` in real-time from slider

### Chunk System Methods

- `_update_chunk_system()`: Calls spawn and despawn logic
- `_spawn_chunks_around(center)`: Iterates through chunk grid around ship, spawns any unvisited chunks within `spawn_radius`
- `_spawn_chunk(chunk_key)`:
  - Seeds RNG deterministically using `_hash_chunk(chunk_key)`
  - Calculates asteroid count based on `chunk_size^2 * asteroid_density`
  - For each asteroid: samples radius, computes worst-case radius, tries up to 10 random positions
  - Checks overlap against same-chunk asteroids (`_is_spawn_point_clear`) and neighboring chunks (`_is_clear_of_neighbors`)
  - Skips asteroid if no valid position found after 10 attempts
  - Passes deterministic `noise_seed` to each asteroid via `rng.randi()`
  - Stores actual `max_radius` (post-noise) for future overlap checks
  - Debug prints spawned/total count per chunk
- `_despawn_far_asteroids(center)`: Removes asteroids beyond `despawn_radius`, cleans up empty chunks
- `_is_spawn_point_clear()`: Checks new position against placed asteroids in current chunk, with distance culling using `max_placed_radius`
- `_is_clear_of_neighbors()`: Checks new position against asteroids in 8 surrounding already-spawned chunks
- `_world_to_chunk()` / `_chunk_to_world()`: Coordinate conversion helpers
- `_hash_chunk()`: Deterministic seed generation combining `global_seed` with chunk coordinates
- `_sample_power_law_radius()`: Power-law distribution for asteroid sizes
- `_create_asteroid()`: Instantiates Asteroid.tscn with position, radius, and noise seed

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

An asteroid is a **RigidBody2D** with an irregular procedural visual and a circular collision shape driven by its **radius**.

**Important behaviors**:

- `radius` is an exported property with a setter. Setting it triggers `_apply_radius()` once the node is inside the tree; if assigned before `_ready()`, it sets a `_pending_radius_apply` flag and applies later.

- `_apply_radius()` always creates a new **CircleShape2D** (at base radius) so collision shapes aren't shared between instances.

- `mass` is computed from area (PI * r^2 * density) with a minimum clamp.

- `visual` is a Polygon2D generated as a 48-point **irregular polygon** using layered Perlin noise.

- `max_radius` tracks the actual furthest vertex distance from center (used by world.gd for overlap checks).

- `frozen` sets `freeze = v` and uses `FREEZE_MODE_STATIC`.

### Noise Shape Generation (`_make_noisy_polygon`)

Generates irregular asteroid shapes by sampling Perlin noise along a unit circle in 2D noise space (ensures seamless wrapping with no visible seam).

**Three noise layers** (each with independent seed offset):

| Layer | Threshold | Amplitude | Frequency | Effect |
|-------|-----------|-----------|-----------|--------|
| Base | All asteroids | 0.18 | 1.5-4.0 (lerped by radius) | Small surface bumps |
| Medium | radius >= 60 | 0.12 | 0.8 | Broad lumps and dents |
| Large | radius >= 120 | 0.15 | 0.4 | Overall shape warp / elongation |

**Export variables** (tunable in Asteroid.tscn inspector):
- `noise_amplitude`: Base layer displacement fraction (default 0.18)
- `noise_freq_min` / `noise_freq_max`: Base frequency range (1.5 - 4.0)
- `noise_radius_range`: Radius range for frequency lerp (16.0 - 192.0)
- `medium_threshold`: Min radius for medium layer (default 60.0)
- `medium_amplitude`: Medium layer displacement (default 0.12)
- `medium_frequency`: Medium layer frequency (default 0.8)
- `large_threshold`: Min radius for large layer (default 120.0)
- `large_amplitude`: Large layer displacement (default 0.15)
- `large_frequency`: Large layer frequency (default 0.4)

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

Max fuel is hardcoded to 100.

All sliders are connected to `_on_tuning_changed()` which calls `_apply_tuning_from_sliders()`. This reads slider values and assigns them to ship properties. Labels update to show current values.

Values are **not persisted** between sessions — they reset to slider defaults on restart.

---

## 🎨 Visual State

- **Ship**: Placeholder sprite (needs proper pixel art per GDD visual constraints)
- **Asteroids**: Procedural irregular white polygons (48 vertices, layered Perlin noise)
- **Background**: Seamless tileable starfield (ParallaxBackground, 0.1x parallax scroll)
- **UI**: Functional but basic styling

---

## 📊 Performance Characteristics

- Chunk system spawns/despawns efficiently based on distance
- Deterministic generation means no cache needed for revisiting chunks (they regenerate identically)
- Current density settings spawn ~10-20 asteroids per chunk
- Overlap avoidance adds minor cost per chunk spawn (rejection sampling + neighbor checks)
- Noise generation is one-time per asteroid at spawn (not per-frame)
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
- **ParallaxBackground** for depth illusion with slow-scrolling starfield
- **`_unhandled_input` vs `_input`** — GUI nodes consume events first, so slider clicks don't trigger "any key" detection
- **State gating with booleans** — `game_started` splits `_process()` into menu vs gameplay, same pattern as `is_game_over`
- **Scene reload pitfall** — `reload_current_scene()` starts freeing immediately; must `return` to avoid null access on the dying node

Previous sprint taught:
- **Rejection sampling** for overlap avoidance with graceful degradation
- **Cross-chunk boundary checks** for seamless world generation
- **Layered noise** for organic procedural shapes (multiple octaves at different scales)
- **Perlin noise on a circle** — sampling 2D noise along a unit circle for seamless periodic patterns
- **FastNoiseLite** usage in Godot (seed, frequency, noise type)
- **max_radius tracking** for accurate collision estimation with irregular shapes

Previous sprints:
- **Chunk-based world streaming** for infinite procedural content
- **Deterministic generation** using seeded RNG and hash functions
- **Power-law distributions** for natural-looking size variation
- **Spatial partitioning** concepts (chunk grid)
- **Godot's RNG system** and seed management
- **Export variable patterns** for designer-friendly tuning

---

## 📝 Implementation Notes for Next Sprint

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
- **Collision shape vs visual mismatch**: CircleShape2D may not match irregular visual edges perfectly — consider if this feels OK during gameplay or if ConvexPolygonShape2D is needed

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
