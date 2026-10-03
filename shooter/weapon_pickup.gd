extends Area3D

@export var weapon_id: String = "pistol"
@export var display_name: String = "PISTOL"
@export var ammo: int = 12
@export var model_path: String = ""

var taken: bool = false
var bob_time: float = 0.0
var base_y: float = 0.0
var model_holder: Node3D

const MODEL_PATHS: Dictionary = {
    "pistol": "res://assets/models/gun.blend",
    "rifle": "res://assets/models/rifle.glb",
    "sniper": "res://assets/models/sniper_rifle.glb",
    "blaster": "res://assets/models/blaster.glb"
}

func _ready() -> void:
    base_y = position.y
    body_entered.connect(_on_body_entered)
    _spawn_real_model()

func _spawn_real_model() -> void:
    model_holder = Node3D.new()
    model_holder.name = "RealWeaponModel"
    add_child(model_holder)
    var path: String = model_path if not model_path.is_empty() else str(MODEL_PATHS.get(weapon_id, ""))
    var packed: PackedScene = load(path) as PackedScene
    if packed == null:
        return
    var model: Node3D = packed.instantiate() as Node3D
    if model == null:
        return
    model_holder.add_child(model)
    model.scale = Vector3(0.65, 0.65, 0.65)
    model.rotation_degrees = Vector3(0, 35, 90)
    model.position = Vector3(0, 0.15, 0)

func _process(delta: float) -> void:
    if taken:
        return
    bob_time += delta
    rotation.y += delta * 0.8
    position.y = base_y + sin(bob_time * 2.5) * 0.12

func _on_body_entered(body: Node3D) -> void:
    if taken:
        return
    if body.is_in_group("player") and body.has_method("pickup_weapon"):
        var accepted: bool = bool(body.pickup_weapon(weapon_id))
        if accepted:
            taken = true
            queue_free()
