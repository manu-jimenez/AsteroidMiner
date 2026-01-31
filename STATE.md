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

`Wo
