---
name: asteroidminer-context
description: Context for working on AsteroidMiner, a 2D physics-driven asteroid mining roguelike in Godot 4. Use this skill when working on any AsteroidMiner code, design, or implementation tasks.
---

# AsteroidMiner Development Context

## Quick Reference

**Before each session:** Read `STATE.md` for current implementation status and priorities.  
**For design decisions:** Reference `GDD.md` for vision, constraints, and architecture.

## Essential Constraints (Non-Negotiable)

### Visual
- Ship sprite: 32×32 px display, ≥2px thick extremities
- Pixel art assets + modern rendering (smooth rotation, lighting, blur)

### Architecture
- **Ship:** Custom physics integrator (not default RigidBody2D behavior)
- **Asteroids:** Discrete RigidBody2D entities (NOT noise fields), sizes from power law distribution
- **Chunks:** 4-6 screen widths, deterministic seeding, ownership handoff on boundary crossing
- **Imperfect coherence:** Acceptable for despawned moving asteroids (Stage 1)

### Physics
- Velocity capping for arcade feel, small angular momentum for natural rotation
- Collision shapes: convex polygon covers, stream velocity (future): 2-5 px/s comoving frame

### Development Philosophy
1. Build illusion first, coherence later
2. Physicality over abstraction
3. Simple systems that compose well
4. No feature creep until core feel is locked
5. **This is a learning project** - explain technical concepts

## Stage Boundaries

**Stage 1 (Current):** Core loop - mining, traversal, fuel management, asteroid physics  
**Stage 2 (Deferred):** Enemies, combat, advanced hazards

Never implement Stage 2 features before Stage 1 is solid.

## Code Style (GDScript)

- Use GDScript idioms (not Python/C++ patterns)
- Prefer signals over polling
- Physics in `_physics_process`, rendering in `_process`
- Comment complex physics/math logic
- Use typed GDScript (`var name: Type`)

## File Locations

- `STATE.md` - Current sprint status, implemented features, next priorities
- `GDD.md` - Complete design document with vision and constraints
- Both live in project root: `C:\Users\pc\Dev\asteroides`

## Session Workflow

1. Read `STATE.md` to understand current status
2. Reference `GDD.md` for design decisions
3. Implement changes (explain concepts as you go)
4. User tests in Godot
5. User updates `STATE.md` with progress
6. User commits and pushes to GitHub

## When In Doubt

- Check GDD.md for design alignment
- Keep chunks large (4-6 screens) to minimize cross-boundary issues
- Accept imperfect coherence over premature optimization
- Prefer readable code over clever optimizations (until profiling shows need)
