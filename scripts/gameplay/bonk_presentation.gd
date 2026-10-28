extends Node2D

const Pose = preload("res://scripts/abilities/bonk_pose.gd")
const BOOK: Texture2D = preload("res://assets/abilities/nerd_book.svg")
const PlayerVisual = preload("res://scripts/gameplay/player_visual.gd")
@export var visual: PlayerVisual
var _pose := Pose.new()
var _direction := Vector2.RIGHT
var _original_position := Vector2.ZERO
var _original_scale := Vector2.ONE
var _presenting: bool = false

func begin(direction: Vector2) -> void:
	if _presenting:
		finish()
	_direction = direction
	_original_position = visual.position
	_original_scale = visual.scale
	_presenting = true
	visual.begin_action_pose(direction)
	show()

func update_pose(elapsed: float, windup: float, air_time: float, recovery: float, height: float, distance: float) -> void:
	if not _presenting:
		return
	_pose.update(elapsed, _direction, windup, air_time, recovery, height, distance)
	visual.position = _original_position + _pose.body_offset
	visual.scale = _original_scale * _pose.body_scale
	queue_redraw()

func finish() -> void:
	if _presenting and is_instance_valid(visual):
		visual.position = _original_position
		visual.scale = _original_scale
		visual.end_action_pose()
	_presenting = false
	hide()

func _draw() -> void:
	if _presenting:
		draw_set_transform(Vector2(0, 24), 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, 16.0 - _pose.height * 0.08, Color(0, 0, 0, 0.28))
		draw_set_transform(Vector2.ZERO)
		Pose.draw_grip(self, _original_position + _pose.body_offset, _pose.book_offset, _pose.book_rotation, BOOK)

func _exit_tree() -> void:
	finish()
