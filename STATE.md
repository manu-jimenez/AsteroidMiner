# AsteroidMiner — Sprint 8 Snapshot (Current Game State)

## 🎯 Current Sprint Status

**Sprint 8: Pixel-Art Asteroid Visuals & Performance** ✅ COMPLETE

---

## 📋 Next Session Priorities

1. **Tangram Tile Assembly System** (major feature — next sprint)
   - Replace per-pixel procedural coloring with pre-authored tile pieces
   - Variable-size tiles (tangram-style): large pieces fill interior, smaller pieces at edges
   - Greedy packing algorithm: largest rectangles first, then progressively smaller
   - Two layers: structural base tiles + decorative overlays (craters, cracks, veins)
   - Tile atlas: pre-drawn PNG spritesheet, editable in any pixel editor, visible in Godot
   - Benefits: editor-visible art, easy iteration, mining = remove/modify hit piece only, splitting = subset of existing pieces (no regeneration)
   - Needs careful design session before implementation

2. **Visual polish (continued)**
   - Ship sprite (needs pixel art per GDD)
   - Thrust particle effects
   - Collision visual feedback (flash, screen shake, etc.)

3. **Asteroid splitting**
   - Larger asteroids break into smaller rigid bodies when sufficiently damaged
   - Each piece maintains physics properties (velocity, angular momentum)
   - With tile system: splitting becomes selecting which pieces belong to each fragment

4. **Stream velocity**
   - Global flow direction for the asteroid field
   - Constant stream velocity (slow: 2–5 px/s comoving frame)
   - Mild per-asteroid velocity noise

---

## ⚠️ Known Issues / Technical Debt

- Collision shape is CircleShape2D (base radius) while visual is irregular — minor mismatch at noise edges
- Ship sprite is placeholder (needs pixel art per GDD)
- No visual feedback for thrust (particle effects needed)
- No visual feedback for collisions (flash/shake)
- ~~Tuning panel values not persisted between sessions~~ → Fixed: GameConfig autoload persists all parameters to `user://config.cfg`
- Cannot visually inspect asteroids in Godot's 2D editor Remote view (runtime-generated textures not visible — tile system will fix this since tiles are real asset PNGs)
- Density slider defaults say 0.2x–3.0x but design intent was 0.2x–2.0x (slider max_value is 3.0)
- Debug collision prints still active in ship.gd (useful for tuning, remove when stable)

---

## 📦 Recent Changes (Last Updated: February 2026)

### Sprint 8: Pixel-Art Asteroid Visuals & Performance
- ✅ Configured display: viewport 1920×1080, stretch mode `canvas_items`, aspect `expand` (maximizable window)
- ✅ Set default texture filter to Nearest (pixel-art crisp edges)
- ✅ Created `AsteroidPalette` resource (base_color, edge_color, color_variation) — easy palette swapping
- ✅ Replaced Polygon2D visual with Sprite2D + procedural ImageTexture
- ✅ Grid-based rasterization: noise polygon → scanline fill → 2D byte grid (1 = solid, 0 = empty)
- ✅ Edge detection: 4-neighbor check, edge pixels colored near-white, interior bluish-gray with random variation
- ✅ Floating pixel cleanup: pixels with ≤1 cardinal neighbor removed after rasterization (fixes sharp peak artifacts)
- ✅ Uniform cell_size (default 4.0 world units per art pixel) — exported, tunable in inspector
- ✅ PackedByteArray bulk pixel writes instead of per-pixel `set_pixel()` (~10-50x faster)
- ✅ `Image.create_from_data()` for single-call image creation from raw RGBA bytes
- ✅ Per-asteroid spawn budget: `max_asteroids_per_frame` (default 20) replaces `chunks_per_frame`. Two-phase: pre-compute chunk data (pure math, instant), then instantiate nodes up to budget per frame. Eliminates micro-teleport frame spikes.
- ✅ Chunk queue sorted by distance to ship (closest chunks spawn first)
- ✅ `_regenerate_texture_from_grid()` method ready for future mining (modify grid, call to update visual)
- ✅ Extracted chunk streaming into `ChunkStreamer` node (`scripts/chunk_streamer.gd`) — `world.gd` went from ~600 to ~220 lines
- ✅ Added PAUSED label (centered on screen, shown/hidden on pause toggle)
- ✅ Documented rendering alternatives in GDD (tile-based, shader-based, pre-generated pool)

### Sprint 7: Health, Damage & Collision System
- ✅ Added ship health system (0–100) with `max_health`, `health`, `heal_full()`, `is_alive()`
- ✅ Added health bar UI next to fuel bar (StatusBars HBoxContainer with FuelBox + HealthBox)
- ✅ Game over on health=0 shows "SHIP DESTROYED — Press R to restart"
- ✅ Implemented impulse-based collision damage: `damage = relative_speed × reduced_mass × damage_per_impulse`
- ✅ Reduced mass formula: `(m_ship × m_ast) / (m_ship + m_ast)` — big asteroids hit harder naturally
- ✅ Pre-collision velocity capture: `_prev_frame_velocity` saved at end of `_physics_process` (before next frame's collision resolution)
- ✅ Damage cooldown (0.15s invulnerability after each hit) prevents multi-hit from single collision
- ✅ Set ship mass to 200 (based on triangle polygon area ~208 sq px)
- ✅ Scaled thrust force to 150000 (maintains ~750 px/s² acceleration with new mass)
- ✅ Set collision layers: Ship=layer 1 mask 2, Asteroids=layer 2 mask 3 (ship↔asteroid + asteroid↔asteroid)
- ✅ Enabled contact_monitor + max_contacts_reported=4 on Ship
- ✅ Asteroid density changed from 1.0 to 0.25 (small asteroids ≈ ship mass, big ones much heavier)
- ✅ Asteroids now rotate from collisions (`lock_rotation = false`)
- ✅ Fixed freeze mode: `FREEZE_MODE_KINEMATIC` instead of `FREEZE_MODE_STATIC` (static gives infinite mass)
- ✅ Fixed spawn order: `add_child()` before `asteroid.frozen = false` (prevents `_ready()` from re-freezing)
- ✅ Added asteroid density multiplier slider to start menu (0.2x–3.0x range)
- ✅ Added damage_per_impulse slider to in-game tuning panel (0.0001–0.005)
- ✅ Updated thrust slider range to 60000–360000 (step 2000)

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

A 2D top-down space traversal prototype with **physics-based collision damage**. The game opens with a **start menu** showing "ASTEROID MINER" over a scrolling starfield background, where you can tweak the power-law alpha and asteroid density before pressing any key to start. You pilot a ship with Asteroids-style thrust and turning in zero-gravity 2D space. The game generates an **infinite procedural asteroid field** using a chunk streaming system — asteroids spawn ahead of you and despawn behind as you explore.

**Collisions are physically simulated**: the ship and asteroids exchange momentum realistically. Small asteroids get knocked around, medium ones get nudged, and large ones barely move. **Collision damage** is proportional to the impulse exchanged (relative speed × reduced mass), so grazing a small rock does little damage while slamming into a large asteroid at full speed is near-fatal. Asteroids spin naturally from collision impacts.

Fuel is a hard constraint (max 100): thrust consumes fuel continuously; when fuel hits zero the game pauses and shows "OUT OF FUEL — Press R to restart". When health reaches zero from collision damage, the game shows "SHIP DESTROYED — Press R to restart".

The asteroid field feels infinite and coherent — revisiting the same world coordinates generates the same asteroids (deterministic). Asteroids vary in size following a power-law distribution (mostly small, occasionally large). **Asteroids have irregular, natural-looking shapes** generated via layered Perlin noise, with larger asteroids having more complex shapes. **Asteroids are rendered as pixel-art**: each asteroid has a grid of art pixels (cell_size=4 world units each), with a bluish-gray interior and bright edge outline, giving a consistent retro look across all sizes.

**Current limitations**: No mining mechanics, no asteroid splitting, ship sprite is placeholder. Asteroid texture generation causes some pop-in (staggered spawning mitigates but doesn't eliminate).

---

## 🏗️ Scene / Node Structure

**World** (Node2D) is the root.

Inside it:

- **ParallaxBackground** → ParallaxLayer (motion_scale 0.1, mirroring 2048×2048) → Sprite2D (starfield texture, centered=false)

- **Ship** is an instanced Ship.tscn and is a RigidBody2D with the Ship script attached. It has `lock_rotation = true` at the node level, `collision_layer = 1`, `collision_mask = 2`, `contact_monitor = true`, `max_contacts_reported = 4`, and contains Camera2D as a child.

- **Camera2D** is enabled and uses position smoothing.

- **ChunkStreamer** (Node2D, `scripts/chunk_streamer.gd`) — owns all chunk streaming logic and all dynamically spawned asteroids. World calls `chunk_streamer.initialize()` once and `chunk_streamer.update_streaming(ship_pos)` each frame. All asteroid config exports live here.

- **UI** (CanvasLayer) contains:
  - **TuningPanel** (PanelContainer) → VBoxContainer → five rows, each row has a label + slider for thrust, damp, turn, fuel burn, and damage_per_impulse.
  - **GameOverLabel** (Label) hidden by default, centered on screen, shows the out-of-fuel or ship-destroyed message.
  - **PauseLabel** (Label) hidden by default, centered on screen, shows "PAUSED" when game is paused.
  - **StatusBars** (HBoxContainer) at bottom-left: FuelBox (FuelLabel + FuelBar) + Spacer + HealthBox (HealthLabel + HealthBar). Both bars are normalized to [0,1].

- **StartMenu** (CanvasLayer, layer=10) contains:
  - CenterContainer → VBoxContainer with title label, power-law alpha slider (1.5–4.0), asteroid density slider (0.2x–3.0x), and "Press any key to start" label.
  - Hidden after game starts. Reappears on restart (scene reload).

- **Asteroids** are spawned dynamically as children of ChunkStreamer (two-phase: pre-compute data, then instantiate up to `max_asteroids_per_frame` per frame, queue sorted by distance to ship). They are RigidBody2D instances from Asteroid.tscn with:
  - `collision_layer = 2`, `collision_mask = 3` (collides with ship + other asteroids)
  - `frozen = false` after add_child (unfrozen for physics, but start with zero velocity)
  - `freeze_mode = FREEZE_MODE_KINEMATIC` (so they behave as normal dynamic bodies when unfrozen)
  - Radius determines size (collision shape = CircleShape2D)
  - Visual = Sprite2D with procedural ImageTexture (grid-rasterized pixel art, cell_size=4)
  - Mass = PI × radius² × density (density = 0.25)
  - `lock_rotation = false` (allows spin from collisions)
  - Each asteroid has a unique `noise_seed` for deterministic shape generation
  - `max_radius` tracks the actual furthest vertex extent (used for overlap checks)
  - `grid` (PackedByteArray) stores solid/empty state per art pixel (ready for mining)
  - `palette` (AsteroidPalette) defines colors — defaults to bluish-gray interior, near-white edge

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

## 🌍 World Logic (world.gd, ~220 lines)

**World** owns the "meta" loop: UI updates, tuning propagation, pause/restart/game-over state. Chunk streaming is delegated to ChunkStreamer.

On `_ready()` it:
1. Resolves camera reference
2. Calls `chunk_streamer.initialize(viewport_size, camera_zoom)` to set up the streaming system
3. Initializes ship fuel and health, UI, and tuning panel
4. Enables camera and prints debug info

During `_process(delta)` it:
- Handles "restart" (always available, even on menu) — unpauses and reloads scene, then returns immediately to avoid accessing freed nodes
- If `game_started` is false, returns early (menu is showing)
- Updates the fuel bar and health bar every frame (normalized to max values)
- Checks game over: fuel=0 → "OUT OF FUEL", health=0 → "SHIP DESTROYED"
- Toggles tuning panel visibility
- Toggles pause (only if not game over), shows/hides PauseLabel
- **Calls `chunk_streamer.update_streaming(ship.global_position)`** every frame when not paused

Start menu logic:
- `_unhandled_input()` detects any key/click/button press and calls `_start_game()`
- `_start_game()` sets `game_started = true`, hides menu, shows ship + UI, unfreezes ship
- `_on_alpha_slider_changed()` updates `chunk_streamer.power_law_alpha` from slider
- `_on_density_slider_changed()` sets `chunk_streamer.asteroid_density` (base density × multiplier)

## 🌐 Chunk Streaming (chunk_streamer.gd, ~310 lines)

**ChunkStreamer** is a Node2D child of World that owns all chunk streaming logic and all dynamically spawned asteroid nodes.

**Public API:**
- `initialize(viewport_size, camera_zoom)`: Computes screen_size, chunk_size, spawn/despawn radii
- `update_streaming(ship_pos)`: Queues chunks, pre-computes data, spawns asteroid nodes (budget-limited)

**Two-phase spawning:**
- Phase 1 — Pre-compute: all queued chunks have their asteroid data computed (positions, radii, seeds) using pure math. This is instant (no scene tree work).
- Phase 2 — Instantiate: up to `max_asteroids_per_frame` (default 20) actual nodes created from the pre-computed queue per frame.

**Key methods:**
- `_queue_chunks_around(center)`: Finds unspawned chunks within `spawn_radius`, sorts by distance
- `_process_chunk_queue(ship_pos)`: Runs both phases
- `_precompute_chunk(chunk_key)`: Seeds RNG deterministically, samples radii (power-law), finds non-overlapping positions (up to 10 attempts), queues data
- `_create_asteroid()`: Instantiates Asteroid.tscn, sets properties, adds as child of ChunkStreamer
- `_despawn_far_asteroids(center)`: Removes far asteroids, purges queued data for removed chunks

**Export variables for tuning** (on ChunkStreamer node in inspector):
- `chunk_size_multiplier`: How many screens wide is a chunk (default 1.5)
- `asteroid_density`: Asteroids per square world unit (default 0.00001)
- `spawn_radius_screens` / `despawn_radius_screens`: In screen sizes (default 1.5 / 2.5)
- `radius_min` / `radius_max`: Asteroid size range (16.0 - 192.0)
- `power_law_alpha`: Distribution shape parameter (default 2.2)
- `max_asteroids_per_frame`: Per-frame node creation budget (default 20)
- `global_seed`: Seed for deterministic generation (default 123456)

---

## 🚀 Ship Logic (ship.gd)

The ship is a **RigidBody2D** with arcade-ish settings: `gravity_scale = 0`, `linear_damp` default 0.9, `angular_damp` 6.0, `mass = 200`, and it hard-prevents spin/torque.

Movement is split across callbacks:

- `_physics_process(delta)`:
  - Ticks damage cooldown timer
  - If thrust is pressed and `fuel > 0`: applies central force in the ship's local +X direction, subtracts `fuel_burn_per_sec * delta`
  - Clamps `linear_velocity` to `max_speed` (900)
  - Captures `_prev_frame_velocity = linear_velocity` at end of frame (pre-collision velocity for next frame's collision resolution)

- `_integrate_forces(state)`:
  - Sets `state.angular_velocity = 0.0` every step to prevent collision torque from spinning the ship
  - If not paused, reads turn input and directly modifies `state.transform` rotation by `turn_speed * state.step`

- `_process(delta)`: If the tree is paused, still rotates the ship visually using input (turn while paused)

### Collision Handling

- `body_entered` signal connected in `_ready()`
- `_on_body_entered(body)`:
  - Ignores non-Asteroid bodies
  - Respects damage cooldown (0.15s invulnerability)
  - Uses `_prev_frame_velocity` (not current `linear_velocity`, which is post-bounce)
  - Calculates relative velocity: `_prev_frame_velocity - asteroid.linear_velocity`
  - Calculates reduced mass: `(m_ship × m_ast) / (m_ship + m_ast)`
  - Impulse = relative_speed × reduced_mass
  - Damage = impulse × damage_per_impulse (default 0.0005)
  - Big asteroids → reduced_mass ≈ ship mass → more damage
  - Small asteroids → reduced_mass ≈ asteroid mass → less damage

**Key physics values**:
- `thrust_force = 150000` → ~750 px/s² acceleration
- `max_speed = 900`
- `mass = 200` (set in `_ready()`)
- `damage_per_impulse = 0.0005`
- `damage_cooldown = 0.15s`

---

## 🪨 Asteroid Logic (asteroid.gd)

An asteroid is a **RigidBody2D** with an irregular procedural visual and a circular collision shape driven by its **radius**.

**Important behaviors**:

- `radius` is an exported property with a setter. Setting it triggers `_apply_radius()` once the node is inside the tree; if assigned before `_ready()`, it sets a `_pending_radius_apply` flag and applies later.

- `_apply_radius()` always creates a new **CircleShape2D** (at base radius) so collision shapes aren't shared between instances.

- `mass` is computed from area: `PI * radius² * density` (density = 0.25). Example masses:
  - r=16 → mass ≈ 200 (≈ ship mass, can be knocked around)
  - r=48 → mass ≈ 1800 (gets nudged)
  - r=192 → mass ≈ 29000 (barely moves)

- `visual` is a **Sprite2D** with a procedurally generated **ImageTexture**:
  - Noise polygon (48 vertices) → scanline-rasterized onto a 2D byte grid
  - Grid cell_size = 4 world units per art pixel (uniform, exported, tunable)
  - Edge detection (4-neighbor) → edge pixels colored with `palette.edge_color`
  - Interior pixels colored with `palette.base_color` + random brightness variation
  - Raw RGBA bytes built in a PackedByteArray → `Image.create_from_data()` → `ImageTexture`
  - `grid` (PackedByteArray) persists for future mining (modify grid → call `_regenerate_texture_from_grid()`)

- `palette` is an **AsteroidPalette** resource (base_color, edge_color, color_variation). Defaults created in `_ready()` if none assigned. Easy to swap for different color schemes.

- `max_radius` tracks the actual furthest vertex distance from center (used by world.gd for overlap checks).

- `frozen` sets `freeze = v` and uses `FREEZE_MODE_KINEMATIC` (not STATIC — STATIC gives infinite mass during collision resolution, making the asteroid immovable).

- `lock_rotation = false` — asteroids spin naturally from collision impacts.

### Noise Shape Generation (`_make_noisy_polygon`)

Generates irregular asteroid shapes by sampling Perlin noise along a unit circle in 2D noise space (ensures seamless wrapping with no visible seam).

**Three noise layers** (each with independent seed offset):

| Layer | Threshold | Amplitude | Frequency | Effect |
|-------|-----------|-----------|-----------|--------|
| Base | All asteroids | 0.18 | 1.5-4.0 (lerped by radius) | Small surface bumps |
| Medium | radius >= 60 | 0.12 | 0.8 | Broad lumps and dents |
| Large | radius >= 120 | 0.15 | 0.4 | Overall shape warp / elongation |

---

## 🎬 Current "Game Over"

Two death conditions are implemented:

1. **Fuel depletion** — fuel reaches 0: shows "OUT OF FUEL — Press R to restart"
2. **Ship destruction** — health reaches 0 from collision damage: shows "SHIP DESTROYED — Press R to restart"

In both cases:
- **World** pauses the whole tree
- **GameOverLabel** becomes visible with the appropriate message
- The ship is forced to stop by boosting linear damp to max slider value
- Pressing restart reloads the scene

---

## 🔧 Tuning System

The tuning panel (press T) has sliders for:
- **Thrust force** (60000–360000, default 150000)
- **Linear damping** (0–1.5, default 0.9)
- **Turn speed** (1.0–7.0, default 4.5)
- **Fuel burn rate** (0–60, default 1.0)
- **Damage per impulse** (0.0001–0.005, default 0.0005)

The start menu has additional sliders for:
- **Power-law alpha** (1.5–4.0, default 2.2) — asteroid size distribution
- **Asteroid density** (0.2x–3.0x, default 1.0x) — multiplier on base density

All tuning panel sliders are connected to `_on_tuning_changed()` which calls `_apply_tuning_from_sliders()`. Values are **persisted** to `user://config.cfg` via the `GameConfig` autoload singleton (36 parameters across ship, chunks, asteroid visuals, noise, and display).

---

## 🎨 Visual State

- **Display**: Viewport 1920×1080, stretch mode `canvas_items`, aspect `expand`, texture filter `Nearest`
- **Ship**: Placeholder sprite (needs proper pixel art per GDD visual constraints)
- **Asteroids**: Pixel-art ImageTextures (bluish-gray fill, near-white edges, cell_size=4)
  - Palette: AsteroidPalette resource (`scripts/asteroid_palette.gd`) — easily swappable
  - Grid stored per asteroid for future mining support
- **Background**: Seamless tileable starfield (ParallaxBackground, 0.1x parallax scroll)
- **UI**: Functional but basic styling

---

## 📊 Performance Characteristics

- **Per-asteroid spawn budget** (default 20/frame) — chunk data is pre-computed instantly (pure math), then nodes instantiated gradually. Eliminates frame spikes from chunk spawning.
- Chunks are queued and sorted by distance — closest to ship spawn first
- Deterministic generation means no cache needed for revisiting chunks (they regenerate identically)
- Current density settings spawn ~80 asteroids per chunk (~4 frames to fully populate a chunk at budget=20)
- Texture generation uses **PackedByteArray bulk writes** + `Image.create_from_data()` (~10-50x faster than `set_pixel()`)
- Scanline rasterization for polygon→grid is O(rows × edges), much faster than per-cell point-in-polygon
- Overlap avoidance adds minor cost per chunk spawn (rejection sampling + neighbor checks)
- Noise generation + texture creation are one-time per asteroid at spawn (not per-frame)
- Asteroids are dynamic RigidBody2D with physics interactions
- Chain reactions possible when ship collides into clusters — may need monitoring at high densities

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
- **`Image.set_pixel()` is slow** — each call crosses the GDScript↔engine boundary. Building a `PackedByteArray` of raw RGBA bytes and calling `Image.create_from_data()` once is 10-50x faster.
- **Scanline rasterization** — for filling a polygon on a grid, iterate rows and find edge crossings per row (O(rows×edges)) instead of testing every cell (O(cells×edges))
- **Two-phase spawning** — separate pre-computation (cheap math) from node instantiation (expensive). Budget the expensive part per-frame for smooth performance.
- **Viewport stretch modes** — `viewport` mode renders at fixed resolution (pixel-perfect but rigid); `canvas_items` scales nodes (flexible resize, need Nearest filter for pixel art)
- **Godot Remote scene tree** doesn't render runtime-generated textures in the 2D editor view — known limitation, not a bug
- **Node extraction for maintainability** — moving self-contained systems (chunk streaming) into their own Node2D scripts keeps files manageable and reduces context needed per session
- **Typed array `.pop_front()` returns Variant** — in GDScript with warnings-as-errors, use `array[0]` + `remove_at(0)` or explicit `as Type` cast instead

Previous sprint taught:
- **Collision layers/masks** — bit-field system for filtering which bodies interact
- **`body_entered` signal timing** — fires AFTER Godot's physics solver, so `linear_velocity` is already post-bounce; must capture pre-collision velocity manually
- **Godot physics tick order**: `_physics_process()` → physics step (collision detection + solver + `_integrate_forces`) → `body_entered` signals
- **`_prev_frame_velocity` pattern** — save velocity at end of `_physics_process`; it becomes the pre-collision velocity for the next frame's collision resolution
- **Impulse-based damage** — `impulse = relative_speed × reduced_mass` where `reduced_mass = (m1×m2)/(m1+m2)` naturally scales damage by both speed and asteroid size
- **`FREEZE_MODE_STATIC` vs `FREEZE_MODE_KINEMATIC`** — STATIC gives infinite mass during collision resolution (immovable); KINEMATIC allows normal dynamic behavior when unfrozen
- **`_ready()` and `add_child()` ordering** — `_ready()` runs during `add_child()`, so properties set before `add_child` can be overridden by `_ready()` defaults; set properties AFTER `add_child`
- **Mass scaling** — changing mass requires proportional changes to all force values (thrust, etc.) to maintain the same acceleration

Previous sprints taught:
- **ParallaxBackground** for depth illusion with slow-scrolling starfield
- **`_unhandled_input` vs `_input`** — GUI nodes consume events first
- **State gating with booleans** — `game_started` splits `_process()` into menu vs gameplay
- **Rejection sampling** for overlap avoidance with graceful degradation
- **Layered noise** for organic procedural shapes
- **Chunk-based world streaming** for infinite procedural content
- **Deterministic generation** using seeded RNG and hash functions
- **Power-law distributions** for natural-looking size variation

---

**End of STATE.md**
