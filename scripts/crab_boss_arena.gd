extends Area2D
## Boss arena.
##  - Walking into the trigger starts the fight (calls boss.activate()).
##  - While the player is inside this area the camera is locked to the area's rectangle.
##  - If the player leaves the area the camera is released, and it locks again when they come back.
##  - When the boss is defeated the camera is released for good.
##
## The size of the arena is the size of the CollisionShape2D (a RectangleShape2D).
## Make it bigger than the screen, or the camera has no room to move.

## The boss to wake up (the queenCrab node in the level)
@export var boss : Node
## Optional: a separate zone that starts the fight (e.g. a doorway before the arena).
## If empty, the fight starts as soon as the player enters the arena itself.
@export var trigger_area : Area2D
## Seconds the camera takes to move into / out of the arena
@export var camera_blend_time : float = 0.8

@onready var shape_node : CollisionShape2D = $CollisionShape2D

var fight_started := false
var fight_over := false
var locked := false
var camera : Camera2D
var saved_limits := {}
var limit_tween : Tween


func _ready() -> void:
	# the boss was already defeated on an earlier visit: no fight, no camera lock
	if boss and Main.is_removed(boss):
		fight_over = true
		return

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if trigger_area:
		trigger_area.body_entered.connect(_on_trigger_body_entered)

	if boss and boss.has_signal("defeated"):
		boss.defeated.connect(_on_boss_defeated)


# ---------- signals ----------

func _on_trigger_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		start_fight()


func _on_body_entered(body: Node2D) -> void:
	if fight_over or not body.is_in_group("player"):
		return
	if trigger_area == null:
		start_fight()
	if fight_started:
		lock_camera()


func _on_body_exited(body: Node2D) -> void:
	if fight_over or not body.is_in_group("player"):
		return
	unlock_camera()


func _on_boss_defeated() -> void:
	fight_over = true
	unlock_camera()


# ---------- fight ----------

func start_fight() -> void:
	if fight_started or fight_over:
		return
	fight_started = true
	if boss and boss.has_method("activate"):
		boss.activate()

	# If the player is already standing inside the arena when the fight starts, lock now
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			lock_camera()


# ---------- camera ----------

func lock_camera() -> void:
	if locked:
		return
	camera = get_viewport().get_camera_2d()
	if camera == null:
		return

	if saved_limits.is_empty():
		saved_limits = {
			"left": camera.limit_left,
			"top": camera.limit_top,
			"right": camera.limit_right,
			"bottom": camera.limit_bottom,
		}

	locked = true

	# Start with the limits hugging what is on screen right now (so the camera doesn't jump),
	# then ease them out to the arena's edges.
	var view := current_view_rect()
	set_limits(view)
	tween_limits(fit_to_view(arena_rect(), view.size))


func unlock_camera() -> void:
	if not locked or not is_instance_valid(camera):
		return
	locked = false

	# Ease the limits outwards so the camera scrolls to the player, then give the camera
	# its original limits back.
	var tween := tween_limits(arena_rect().grow(1500.0))
	tween.finished.connect(_restore_limits)


func _restore_limits() -> void:
	if locked or not is_instance_valid(camera) or saved_limits.is_empty():
		return
	camera.limit_left = saved_limits["left"]
	camera.limit_top = saved_limits["top"]
	camera.limit_right = saved_limits["right"]
	camera.limit_bottom = saved_limits["bottom"]


# ---------- helpers ----------

# The arena in world coordinates (taken from the CollisionShape2D)
func arena_rect() -> Rect2:
	var size : Vector2 = (shape_node.shape as RectangleShape2D).size * shape_node.global_scale.abs()
	return Rect2(shape_node.global_position - size / 2.0, size)


# What the camera is showing right now, in world coordinates
func current_view_rect() -> Rect2:
	var size := get_viewport_rect().size / camera.zoom
	return Rect2(camera.get_screen_center_position() - size / 2.0, size)


# If the arena is smaller than the screen, grow it (around its centre) so the camera can still work
func fit_to_view(rect: Rect2, view_size: Vector2) -> Rect2:
	var size := Vector2(maxf(rect.size.x, view_size.x), maxf(rect.size.y, view_size.y))
	return Rect2(rect.get_center() - size / 2.0, size)


func set_limits(rect: Rect2) -> void:
	camera.limit_left = roundi(rect.position.x)
	camera.limit_top = roundi(rect.position.y)
	camera.limit_right = roundi(rect.end.x)
	camera.limit_bottom = roundi(rect.end.y)


func tween_limits(rect: Rect2) -> Tween:
	if limit_tween:
		limit_tween.kill()
	limit_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	limit_tween.tween_property(camera, "limit_left", roundi(rect.position.x), camera_blend_time)
	limit_tween.tween_property(camera, "limit_top", roundi(rect.position.y), camera_blend_time)
	limit_tween.tween_property(camera, "limit_right", roundi(rect.end.x), camera_blend_time)
	limit_tween.tween_property(camera, "limit_bottom", roundi(rect.end.y), camera_blend_time)
	return limit_tween
