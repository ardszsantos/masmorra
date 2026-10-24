extends Node2D

const TileArt = preload("res://scripts/gameplay/tile_art.gd")

@export_group("Floor Appearance")
@export var floor_art_seed: int = 0
@export_range(0.0, 1.0, 0.01) var floor_wear_coverage: float = 0.2
@export_range(1, 5, 1) var floor_patch_radius: int = 2


func _ready() -> void:
	TileArt.apply($Floor, $Walls, floor_art_seed, floor_wear_coverage, floor_patch_radius)
