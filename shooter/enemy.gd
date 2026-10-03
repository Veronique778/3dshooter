extends CharacterBody3D

var hp: int = 5
var attack_cd: float = 0.0
var dead: bool = false
var player: CharacterBody3D
@onready var label: Label = get_node("../HUD/EnemyHP") as Label

func _ready() -> void:
    player = get_tree().get_first_node_in_group("player") as CharacterBody3D
    label.text = "ENEMY  ♥ %d" % hp

func _physics_process(delta: float) -> void:
    if dead:
        return
    if not is_instance_valid(player):
        player = get_tree().get_first_node_in_group("player") as CharacterBody3D
    if not is_instance_valid(player):
        return

    var flat: Vector3 = player.global_position - global_position
    flat.y = 0.0
    var dist: float = flat.length()
    if dist > 3.0 and dist > 0.001:
        var d: Vector3 = flat.normalized()
        velocity.x = d.x * 2.2
        velocity.z = d.z * 2.2
        look_at(global_position + Vector3(d.x, 0.0, d.z), Vector3.UP)
    else:
        velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
        look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)

    attack_cd -= delta
    if dist < 12.0 and attack_cd <= 0.0:
        attack_cd = 0.9
        player.call("damage", 5)
    move_and_slide()

func damage(amount: int) -> void:
    if dead:
        return
    hp = maxi(0, hp - amount)
    label.text = "ENEMY  ♥ %d" % hp
    if hp <= 0:
        dead = true
        label.text = "ENEMY  ☠"
        var status: Label = get_node("../HUD/Status") as Label
        status.text = "VICTORY!\nYou defeated the enemy"
        status.visible = true
        var hero: CharacterBody3D = get_node("../Hero") as CharacterBody3D
        hero.set("defeated", true)
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        queue_free()
