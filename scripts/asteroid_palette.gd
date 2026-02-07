# scripts/asteroid_palette.gd
# Resource that defines asteroid color palette.
# Swap this resource to try different color schemes.
# Future: a fragment shader can read these values for per-pixel variation at zero CPU cost.
class_name AsteroidPalette
extends Resource

## Base fill color for interior pixels
@export var base_color: Color = Color(0.40, 0.45, 0.55)  # bluish gray

## Color for edge/outline pixels (adjacent to empty space)
@export var edge_color: Color = Color(0.82, 0.84, 0.88)  # near-white

## Per-pixel random brightness variation applied to base_color.
## Each pixel shifts by a random value in [-color_variation, +color_variation].
@export_range(0.0, 0.2) var color_variation: float = 0.06
