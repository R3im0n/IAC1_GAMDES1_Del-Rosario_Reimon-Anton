extends CharacterBody2D

var bullet = preload("res://scenes/bullet.tscn")
var pushable_box: CharacterBody2D = null

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var muzzle : Marker2D = $Muzzle

@onready var jump_sound: AudioStreamPlayer2D = $JumpSound
@onready var death_sound: AudioStreamPlayer2D = $DeathSound

# @export makes it so you can change the values in the inspector tab
@export var SPEED : float = 1000.0
@export var SLOW_DOWN_SPEED : float = 2000.0 #sliding recoil
@export var MAX_HORIZONTAL_SPEED: float = 300.0 #delta time implementation
@export var JUMP_VELOCITY : float = -750.0

@export var GRAVITY : float = 1000

#for pushing a box
@onready var push_ray: RayCast2D = $PushRay
@export var push_speed: float = 60.0

# Where the gun barrel is for each pose (for a right-facing sprite).
# The x value is mirrored automatically when the player faces left.
const MUZZLE_STAND := Vector2(16, -29)
const MUZZLE_RUN := Vector2(16, -26)
const MUZZLE_DUCK := Vector2(16, -15)
const MUZZLE_UP := Vector2(4, -43)

# Capsule collision size when standing / ducking (feet stay at the same spot)
const STAND_HEIGHT := 36.0
const STAND_Y := -19.0
const DUCK_HEIGHT := 22.0
const DUCK_Y := -12.0

# How long the "shooting" version of an animation stays on screen after a shot
const SHOOT_ANIM_TIME := 0.3

var alive = true
var facing : int = 1 # 1 = right, -1 = left (stays set while standing still)
var is_ducking := false
var shoot_timer := 0.0

# Shooting cooldown: after shots_per_burst shots you have to wait burst_cooldown seconds
@export var shots_per_burst : int = 3
@export var burst_cooldown : float = 0.8
var shots_fired := 0
var cooldown_timer := 0.0

# Health: enemies call take_damage(). After a hit you are briefly invulnerable (blinks).
@export var max_health : int = 5
@export var invulnerable_time : float = 1.0
@export var knockback : Vector2 = Vector2(260, -350)
var health : int
var invulnerable_timer := 0.0


func _ready():
	health = max_health
	# give this player its own collision shape so ducking never leaks into other scenes
	collision_shape_2d.shape = collision_shape_2d.shape.duplicate()
	push_ray.position = Vector2(0, -10)
	push_ray.target_position = Vector2(10, 0)


func _physics_process(delta: float) -> void:
	#death
	if !alive:
		return

	# invulnerability after a hit: count down and blink
	if invulnerable_timer > 0.0:
		invulnerable_timer -= delta
		animated_sprite_2d.modulate.a = 0.35 if int(invulnerable_timer * 20.0) % 2 == 0 else 1.0
	else:
		animated_sprite_2d.modulate.a = 1.0

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	var input_dir := Input.get_axis("left", "right")
	var aim_up := Input.is_action_pressed("up")

	# Facing is updated first, so the sprite and muzzle are already on the
	# correct side when a shot is fired this same frame.
	if input_dir > 0:
		facing = 1
	elif input_dir < 0:
		facing = -1
	animated_sprite_2d.flip_h = facing < 0

	# Duck: on the floor, holding down (and not aiming up).
	# Stay ducked if there is no room above to stand back up.
	if is_on_floor() and Input.is_action_pressed("down") and not aim_up:
		set_ducking(true)
	elif is_ducking and can_stand():
		set_ducking(false)

	# Turning around while ducked
	var direction := 0.0 if is_ducking else input_dir

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_ducking:
		velocity.y = JUMP_VELOCITY
		jump_sound.play()

	# Horizontal movement/deceleration.
	if direction:
		velocity.x += direction * SPEED * delta
		velocity.x = clamp(velocity.x, -MAX_HORIZONTAL_SPEED, MAX_HORIZONTAL_SPEED) #delta time implementation
	else:
		velocity.x = move_toward(velocity.x, 0, SLOW_DOWN_SPEED * delta) #SLOW_DOWN_SPEED added for delta time

	# Shooting
	shoot_timer = maxf(shoot_timer - delta, 0.0)
	cooldown_timer = maxf(cooldown_timer - delta, 0.0)
	update_muzzle(aim_up, direction)
	if Input.is_action_just_pressed("shoot"):
		shoot(aim_up)

	#Checking for pushable box
	handle_pushing(direction)

	move_and_slide()

	# Animations are chosen after moving, so they reflect the real state this frame
	update_animation(aim_up, direction)


func take_damage(amount: int, from_position: Vector2 = Vector2.ZERO) -> void:
	if not alive or invulnerable_timer > 0.0:
		return

	health -= amount
	invulnerable_timer = invulnerable_time

	# knock the player away from whatever hit them
	var away := signf(global_position.x - from_position.x)
	if away == 0.0:
		away = -facing
	velocity = Vector2(away * knockback.x, knockback.y)

	if health <= 0:
		die()


func die() -> void:
	death_sound.play()
	animated_sprite_2d.animation = "death"
	alive = false


# ---------- shooting ----------

func update_muzzle(aim_up: bool, direction: float) -> void:
	var pos : Vector2
	if aim_up:
		pos = MUZZLE_UP
	elif is_ducking:
		pos = MUZZLE_DUCK
	elif is_on_floor() and (direction != 0 or abs(velocity.x) > 1):
		pos = MUZZLE_RUN
	else:
		pos = MUZZLE_STAND
	muzzle.position = Vector2(pos.x * facing, pos.y)


func shoot(aim_up: bool) -> void:
	if cooldown_timer > 0.0:
		return   # still cooling down after the last burst

	var b = bullet.instantiate()
	get_parent().add_child(b)
	b.global_position = muzzle.global_position
	if aim_up:
		# bullet.gd moves along its own local x axis, so turning it -90 degrees sends it up
		b.direction = 1
		b.rotation = -PI / 2.0
	else:
		b.direction = facing   # uses facing, NOT the input, so it also works standing still
	shoot_timer = SHOOT_ANIM_TIME

	shots_fired += 1
	if shots_fired >= shots_per_burst:
		shots_fired = 0
		cooldown_timer = burst_cooldown


# ---------- ducking ----------

func set_ducking(value: bool) -> void:
	if is_ducking == value:
		return
	is_ducking = value
	var capsule := collision_shape_2d.shape as CapsuleShape2D
	capsule.height = DUCK_HEIGHT if value else STAND_HEIGHT
	collision_shape_2d.position.y = DUCK_Y if value else STAND_Y


func can_stand() -> bool:
	# true if the space above is free for the full-height capsule
	return not test_move(global_transform, Vector2(0, -(STAND_HEIGHT - DUCK_HEIGHT)))


# ---------- animation ----------

func update_animation(aim_up: bool, direction: float) -> void:
	var shooting := shoot_timer > 0.0

	if is_ducking:
		play_anim("duck")
	elif not is_on_floor():
		play_anim("jump")
	elif direction != 0 or abs(velocity.x) > 1:
		play_run("run_shoot" if shooting else "run")
	elif aim_up:
		play_anim("lookUp")
	elif shooting:
		play_anim("stand_shoot")
	else:
		play_anim("idle")


func play_anim(anim: StringName) -> void:
	# only call play() when the animation actually changes, so it doesn't restart every frame
	if animated_sprite_2d.animation != anim:
		animated_sprite_2d.play(anim)


func play_run(anim: StringName) -> void:
	# run and run_shoot both have 10 frames: keep the same frame when switching
	# between them so the legs don't snap back to frame 0 on every shot
	if animated_sprite_2d.animation == anim:
		return
	var was_running : bool = animated_sprite_2d.animation == &"run" or animated_sprite_2d.animation == &"run_shoot"
	var f := animated_sprite_2d.frame
	var p := animated_sprite_2d.frame_progress
	animated_sprite_2d.play(anim)
	if was_running:
		animated_sprite_2d.set_frame_and_progress(f, p)


# ---------- pushing a box ----------

func handle_pushing(direction: float) -> void:
	if direction != 0:
		push_ray.target_position.x = abs(push_ray.target_position.x) * sign(direction)

	var new_box: CharacterBody2D = null
	if push_ray.is_colliding():
		var c = push_ray.get_collider()
		if c is CharacterBody2D and c.has_method("push"):
			new_box = c

	if pushable_box != null and pushable_box != new_box:
		pushable_box.stop_pushing()
	pushable_box = new_box

	if pushable_box != null and direction != 0 and is_on_floor():
		pushable_box.push(direction, push_speed)
		velocity.x = direction * push_speed   # walk at the box's speed so contact is kept
	elif pushable_box != null:
		pushable_box.stop_pushing()
