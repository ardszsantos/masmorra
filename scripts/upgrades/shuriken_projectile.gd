extends "res://scripts/upgrades/plasma_projectile.gd"

var _spin: float = 0.0
const TEXTURE = preload("res://assets/sprites/item-upgrades/shuriken/shuriken-icon.png")
@export var sprite_size: float = 24.0
@export var spin_speed: float = 14.0


func _process(delta: float) -> void:
	_spin += delta * spin_speed
	queue_redraw()


func _draw() -> void:
	var dimensions := TEXTURE.get_size()
	dimensions *= sprite_size / maxf(dimensions.x, dimensions.y)
	draw_set_transform(Vector2.ZERO, _spin)
	draw_texture_rect(TEXTURE, Rect2(-dimensions * 0.5, dimensions), false)
	draw_set_transform(Vector2.ZERO)
