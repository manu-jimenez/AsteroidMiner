# AsteroidMiner – Game Design Document (Project Bible)

## 1. High-Level Vision

**AsteroidMiner** is a 2D top-down pixel-art roguelike focused on mining, traversal, and moment-to-moment physical interaction with an asteroid field that *feels infinite*. The core fantasy is not space combat dominance, but *skillful navigation, resource extraction, and improvisation* inside a hostile, slowly flowing asteroid stream.

The game blends classic pixel-art aesthetics with modern rendering and physics conveniences: sprites are pixel-authored, but movement, rotation, lighting, blur, and scaling are smooth and continuous. The result should feel tactile and grounded rather than grid-locked or retro-stiff.

The player is not conquering space; they are *surviving inside a system larger than them*.

---

## 2. Core Pillars

1. **Illusion of Infinity**
   The asteroid field is chunk-streamed and deterministic. The player can move endlessly in a direction, revisit old regions later, and the world feels persistent even if full coherence is deferred.

2. **Physicality Over Abstraction**
   Asteroids are real bodies with size, mass, inertia, and breakage. Mining, shooting, and collisions modify trajectories and shapes.

3. **Readable Silhouette & Feedback**
   At any zoom level, the player must instantly parse ship orientation, fuel state, danger, and intent.

4. **Low UI, Diegetic Information**
   Critical information (fuel, thrust, damage state) is conveyed through the ship sprite and immediate effects rather than HUD bars.

5. **Roguelike Progression with Soft Persistence**
   Runs end. Knowledge, unlocks, and some meta-systems persist.

---

## 3. Camera & Perspective

* **Perspective:** Top-down 2D
* **Camera:** Smooth follow with mild inertia
* **Zoom:** Fixed for now; potential dynamic zoom later
* **Rotation:** Ship and asteroids rotate freely (no 90° snapping)

Camera motion should reinforce the sensation of floating inside a moving medium rather than standing on a static plane.

---

## 4. World Structure – Asteroid Stream

### 4.1 Chunk System

* The world is divided into square **stream chunks** (multiple screen sizes each).
* Chunk size: ~4–6 screen widths (large enough that asteroids rarely cross boundaries while loaded).
* Only nearby chunks are loaded.
* Distant chunks despawn when they fall ~4–5 screen lengths behind the player.
* **Moving asteroids:** Each asteroid has a "home chunk" (where it spawned). When an asteroid's center crosses a chunk boundary, ownership transfers to the new chunk. On despawn, moving asteroids are stored in their current owner chunk, not their origin chunk.

### 4.2 Determinism & Memory

* Each chunk has a deterministic seed.
* On despawn, asteroid *summaries* are stored:

  * Size
  * Relative position (approximate)
  * Velocity (for later coherence)
  * Current owner chunk (may differ from spawn chunk if asteroid moved)
* Full coherence is *not required yet*, but data is stored as groundwork.
* **Imperfect coherence is acceptable:** Asteroids that gained velocity from player interaction (shooting, collisions) and then despawned may not be perfectly restored on revisit. This is an acceptable trade-off for Stage 1.

### 4.3 Stream Motion

* The asteroid field has a **global flow direction**.

  * Constant stream velocity (slow: 2–5 px/s)
  * Mild per-asteroid velocity noise
  * Small angular momentum (few degrees/sec) for natural rotation
  * **Comoving chunk frame:** When stream velocity is introduced (initially it is 0), chunks will be conceptually comoving with the stream. Asteroids spawn with stream velocity as their base velocity, plus noise. This prevents chunks from "emptying out" as asteroids drift away.
  * **Natural collisions:** Low angular momentum and velocity noise may cause occasional collisions between closely spawned asteroids. This is intentional emergent behavior and adds to the "living world" feel. Keep spawn density and rotation rates low enough that collisions remain infrequent.

The illusion is that the ship moves through the stream, not that the stream is generated around the ship.

---

## 5. Asteroids

### 5.1 Representation

* Asteroids are **RigidBody2D** with full physics simulation.
* Each asteroid has:
  * Mass (derived from size/area)
  * Linear velocity (stream velocity + noise)
  * Angular velocity (small, for natural rotation)
  * Underlying 2D data array, when the ship mines it eats through the array, releasing particle resource that the ship can collect, possibly generating splits of the asteroid
  * Collision shape (convex polygon cover of underlying 2d grid)
* Shapes are irregular, visually organic, procedural shape generation with noise.
* Pixel-art appearance with smooth rotation.

### 5.2 Sprite Generation

Preferred approach:

* Cheap procedural generation (noise-based silhouettes, marching-squares-like logic, or signed-distance contours).
* Avoid hand-drawing dozens of static sprites.

Asteroid visuals are layered:

1. Core silhouette (pixel art)
2. Lighting/shading pass
3. Optional non-pixel blur/glow effects

### 5.3 Interaction

* **Shooting asteroids:**
  * Alters trajectory and imparts momentum
  * Chips mass
  * Smaller asteroids gain more velocity (inverse mass relationship)
  * Velocity gain is capped for arcade feel (prevents too many asteroids from flying off-screen)
  * Chipped mass releases particles of fuel that the ship can collect

* **Collisions:**
  * Asteroids exchange momentum and angular momentum realistically
  * Collision shapes defined by convex polygon covers of underlying grid
  * Natural collisions between asteroids are infrequent but possible (emergent gameplay)
  * Player-asteroid collisions will damage the ship depending on relative momentum exchange.

* **Splitting:**
  * Larger asteroids break into smaller rigid bodies when sufficiently damaged
  * Each piece maintains physics properties (velocity, angular momentum)

---

## 6. Player Ship

### 6.1 Sprite Constraints

* Base design canvas: **32×32 px**
* Upscaled runtime sprite: **64×64 px** (or higher via filtering)
* Clear front/back/side silhouette

### 6.2 Diegetic UI

* **Fuel meter integrated into the ship sprite**:
  * Glowing bar, tanks, or segmented hull elements
  * Updates in real time
* No need to look at screen corners to assess fuel.

### 6.3 Motion

* Thrust-based movement
* Rotation with inertia
* Fuel consumption tied directly to thrust

Ship should feel *slightly unwieldy*, not arcade-snappy.

---

## 7. Controls (Conceptual)

* Thrust forward
* Rotate left/right
* Brake / counter-thrust
* Fire mining tool / weapon
* Optional secondary tool (future)

Exact bindings are platform-dependent.

---

## 8. Mining & Combat

### 8.1 Mining

* Mining is destructive interaction with asteroids.
* Output is raw material chunks or abstract resources.

### 8.2 Weapons

* Weapons are tools first, combat second.
* Firing has physical consequences (recoil, impulse transfer).

Combat should never overshadow traversal and mining.

---

## 9. Progression & Roguelike Structure

* Each run is self-contained.
* Death ends the run.

Between runs (Placeholder, future version):

* Unlock ship modules
* Unlock asteroid types
* Unlock biomes / stream modifiers

Meta-progression should *expand possibility space*, not trivialize difficulty.

---

## 10. Visual Style

* **Pixel art assets** for ships and asteroids
* **Modern rendering** for:

  * Motion blur
  * Lighting
  * Soft shadows
  * Background parallax

Background elements may break pixel purity (blurred nebulae, gradients) to enhance depth.

---

## 11. Audio Direction (Placeholder)

* Low, ambient soundscape
* Emphasis on:

  * Thrust
  * Impacts
  * Mining hits
* Minimalist music or long ambient loops

Silence is allowed and encouraged.

---

## 12. Technical Assumptions

* Engine: Godot (2D)
* Physics: Godot 2D physics
* Deterministic chunk seeding
* Data-oriented approach for asteroids

---

## 13. Development Philosophy

* Build illusion first, coherence later.
* Store data even if unused yet.
* Prefer simple systems that compose well.
* Avoid feature creep until the *core feel* is locked.

---

## 14. Near-Term Roadmap (Abstract)

**Current sprint focus:**

* Chunk streaming -> implemented with stream speed 0
* Static asteroid field -> implemented
* Illusion of infinite traversal -> implemented

**Next sprints:**

* Background and first visual assets for asteroids
* Collisions
* Asteroid splitting
* Stream velocity
* Basic enemies / hazards

---

## 15. Non-Goals (For Now)

* Realistic orbital mechanics
* Complex story or lore
* Large NPC factions
* Hard-science simulation

---

### One-Sentence Thesis

> *AsteroidMiner is about mining asteroids and surviving in a dangerous environment*