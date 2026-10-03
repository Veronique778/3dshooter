extends CharacterBody3D

const SPEED: float = 6.0
const RUN_SPEED: float = 9.0
const JUMP: float = 5.0
const MOUSE_SENS: float = 0.0025
const MAX_SHOT_DISTANCE: float = 120.0

var hp: int = 100
var gravity: float = 9.8
var pitch: float = -0.10
var defeated: bool = false
var current_slot: int = 0
var inventory: Array[String] = []
var weapon_ammo: Dictionary = {}
var cooldown_left: float = 0.0
var reload_left: float = 0.0
var pickup_message_left: float = 0.0
var held_model: Node3D = null

const WEAPONS: Dictionary = {
    "pistol": {"name":"PISTOL", "damage":1, "cooldown":0.28, "reload":1.5, "mag":12, "kind":"pistol", "model":"res://assets/models/gun.blend"},
    "rifle": {"name":"RIFLE", "damage":1, "cooldown":0.11, "reload":2.0, "mag":30, "kind":"rifle", "model":"res://assets/models/rifle.glb"},
    "sniper": {"name":"SNIPER", "damage":6, "cooldown":0.9, "reload":5.0, "mag":1, "kind":"sniper", "model":"res://assets/models/sniper_rifle.glb"},
    "blaster": {"name":"BLASTER", "damage":2, "cooldown":0.38, "reload":2.8, "mag":8, "kind":"blaster", "model":"res://assets/models/blaster.glb"}
}

@onready var cam: Camera3D = $Camera3D
@onready var bunny: Node3D = $Bunny
@onready var gun: Node3D = $Gun
@onready var hp_label: Label = get_node("../HUD/HP") as Label
@onready var status_label: Label = get_node("../HUD/Status") as Label
@onready var weapon_label: Label = get_node("../HUD/WeaponName") as Label
@onready var ammo_label: Label = get_node("../HUD/Ammo") as Label
@onready var pickup_label: Label = get_node("../HUD/Pickup") as Label
@onready var slots: Array[Label] = [get_node("../HUD/Slot1") as Label, get_node("../HUD/Slot2") as Label, get_node("../HUD/Slot3") as Label, get_node("../HUD/Slot4") as Label, get_node("../HUD/Slot5") as Label]
@onready var crosshairs: Array[Control] = [get_node("../HUD/CrossPistol") as Control, get_node("../HUD/CrossRifle") as Control, get_node("../HUD/CrossShotgun") as Control, get_node("../HUD/CrossSniper") as Control, get_node("../HUD/CrossBlaster") as Control]

func _ready() -> void:
    gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    cam.current = true
    inventory.append("pistol")
    weapon_ammo["pistol"] = int(WEAPONS["pistol"]["mag"])
    _select_slot(0)
    _refresh_held_weapon()
    hp_label.text = "♥ %d" % hp
    _update_hud()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not defeated:
        var motion: InputEventMouseMotion = event as InputEventMouseMotion
        rotate_y(-motion.relative.x * MOUSE_SENS)
        pitch = clampf(pitch - motion.relative.y * MOUSE_SENS, -0.75, 0.5)
        cam.rotation.x = pitch

    if event is InputEventMouseButton:
        var mouse_event: InputEventMouseButton = event as InputEventMouseButton
        if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
            Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
            shoot()

    if event is InputEventKey:
        var key_event: InputEventKey = event as InputEventKey
        if key_event.pressed and not key_event.echo:
            if key_event.keycode == KEY_ESCAPE:
                Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
            elif key_event.keycode == KEY_R:
                if defeated:
                    get_tree().reload_current_scene()
                else:
                    _start_reload()
            elif key_event.keycode >= KEY_1 and key_event.keycode <= KEY_5:
                var slot_index: int = key_event.keycode - KEY_1
                _select_slot(slot_index)

func _physics_process(delta: float) -> void:
    if defeated:
        return

    if not is_on_floor():
        velocity.y -= gravity * delta
    else:
        velocity.y = -0.2

    if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
        velocity.y = JUMP

    var x_axis: float = 0.0
    var z_axis: float = 0.0
    if Input.is_key_pressed(KEY_A): x_axis -= 1.0
    if Input.is_key_pressed(KEY_D): x_axis += 1.0
    if Input.is_key_pressed(KEY_W): z_axis -= 1.0
    if Input.is_key_pressed(KEY_S): z_axis += 1.0

    var input_vec: Vector2 = Vector2(x_axis, z_axis)
    if input_vec.length() > 1.0:
        input_vec = input_vec.normalized()

    var local_dir: Vector3 = Vector3(input_vec.x, 0.0, input_vec.y)
    var dir: Vector3 = (global_transform.basis * local_dir).normalized()
    var spd: float = RUN_SPEED if Input.is_key_pressed(KEY_SHIFT) else SPEED

    if dir.length_squared() > 0.0:
        velocity.x = dir.x * spd
        velocity.z = dir.z * spd
        bunny.rotation.z = lerpf(bunny.rotation.z, -input_vec.x * 0.08, delta * 8.0)
        bunny.position.y = 0.02 + sin(Time.get_ticks_msec() * 0.012) * 0.025
    else:
        velocity.x = move_toward(velocity.x, 0.0, spd * 7.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, spd * 7.0 * delta)
        bunny.rotation.z = lerpf(bunny.rotation.z, 0.0, delta * 8.0)
        bunny.position.y = 0.02 + sin(Time.get_ticks_msec() * 0.004) * 0.012

    cooldown_left = maxf(0.0, cooldown_left - delta)
    if reload_left > 0.0:
        reload_left = maxf(0.0, reload_left - delta)
        if reload_left == 0.0:
            _finish_reload()
    pickup_message_left = maxf(0.0, pickup_message_left - delta)
    if pickup_message_left <= 0.0:
        pickup_label.visible = false

    move_and_slide()

func pickup_weapon(weapon_id: String) -> bool:
    if not WEAPONS.has(weapon_id):
        return false
    if inventory.has(weapon_id):
        weapon_ammo[weapon_id] = int(WEAPONS[weapon_id]["mag"])
        pickup_message_left = 2.0
        pickup_label.text = "%s — AMMO REFILLED" % WEAPONS[weapon_id]["name"]
        pickup_label.visible = true
        _update_hud()
        return true
    if inventory.size() >= 5:
        pickup_label.text = "INVENTORY FULL — SLOTS 1-5"
        pickup_label.visible = true
        pickup_message_left = 2.0
        return false
    inventory.append(weapon_id)
    weapon_ammo[weapon_id] = int(WEAPONS[weapon_id]["mag"])
    pickup_message_left = 2.0
    pickup_label.text = "PICKED UP: %s" % WEAPONS[weapon_id]["name"]
    pickup_label.visible = true
    _select_slot(inventory.size() - 1)
    _update_hud()
    return true

func _select_slot(index: int) -> void:
    if index < 0 or index >= inventory.size():
        return
    if index >= 5:
        return
    current_slot = index
    cooldown_left = 0.0
    reload_left = 0.0
    _update_hud()
    _refresh_held_weapon()

func _refresh_held_weapon() -> void:
    if is_instance_valid(held_model):
        held_model.queue_free()
        held_model = null
    var weapon: Dictionary = _current_weapon()
    var path: String = str(weapon.get("model", ""))
    var packed: PackedScene = load(path) as PackedScene
    if packed == null:
        return
    held_model = packed.instantiate() as Node3D
    if held_model == null:
        return
    gun.add_child(held_model)
    held_model.position = Vector3.ZERO
    held_model.rotation = Vector3.ZERO
    held_model.scale = Vector3(0.32, 0.32, 0.32)

func _current_weapon_id() -> String:
    if current_slot < 0 or current_slot >= inventory.size():
        return "pistol"
    return inventory[current_slot]

func _current_weapon() -> Dictionary:
    return WEAPONS[_current_weapon_id()] as Dictionary

func _start_reload() -> void:
    var w: Dictionary = _current_weapon()
    var weapon_id: String = _current_weapon_id()
    if float(w["reload"]) <= 0.0:
        weapon_ammo[weapon_id] = int(w["mag"])
        _update_hud()
        return
    if int(weapon_ammo.get(weapon_id, 0)) >= int(w["mag"]):
        return
    reload_left = float(w["reload"])
    cooldown_left = reload_left
    _update_hud()

func _finish_reload() -> void:
    var weapon_id: String = _current_weapon_id()
    weapon_ammo[weapon_id] = int(_current_weapon()["mag"])
    cooldown_left = 0.0
    _update_hud()

func shoot() -> void:
    if defeated or reload_left > 0.0 or cooldown_left > 0.0:
        return
    var weapon_id: String = _current_weapon_id()
    var w: Dictionary = _current_weapon()
    var ammo: int = int(weapon_ammo.get(weapon_id, 0))
    if ammo <= 0:
        _start_reload()
        return

    weapon_ammo[weapon_id] = ammo - 1
    cooldown_left = float(w["cooldown"])

    gun.rotation.x = -0.12
    get_tree().create_timer(0.05).timeout.connect(_reset_gun_recoil)

    var viewport_size: Vector2 = get_viewport().get_visible_rect().size
    var center: Vector2 = viewport_size * 0.5
    var from_pos: Vector3 = cam.project_ray_origin(center)
    var direction: Vector3 = cam.project_ray_normal(center).normalized()
    var to_pos: Vector3 = from_pos + direction * MAX_SHOT_DISTANCE

    var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from_pos, to_pos)
    query.exclude = [self]
    query.collide_with_bodies = true
    query.collide_with_areas = true
    var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty():
        var collider: Object = hit["collider"] as Object
        if collider != null and collider.is_in_group("enemy"):
            var pellets: int = 6 if weapon_id == "shotgun" else 1
            collider.call("damage", int(w["damage"]) * pellets)
            make_hit_fx(hit["position"] as Vector3, Color(1.0, 0.25, 0.55))
        else:
            make_hit_fx(hit["position"] as Vector3, Color(1.0, 0.85, 0.45))

    _update_hud()
    if int(weapon_ammo[weapon_id]) <= 0 and float(w["reload"]) > 0.0:
        _start_reload()

func _reset_gun_recoil() -> void:
    if is_instance_valid(gun):
        gun.rotation.x = 0.0

func _update_hud() -> void:
    for i in range(5):
        if i < inventory.size():
            var wid: String = inventory[i]
            var w: Dictionary = WEAPONS[wid] as Dictionary
            slots[i].text = "%d\n%s" % [i + 1, str(w["name"])]
            slots[i].modulate = Color(1.0, 0.55, 0.75, 1.0) if i == current_slot else Color(1,1,1,0.65)
        else:
            slots[i].text = "%d\n—" % [i + 1]
            slots[i].modulate = Color(1,1,1,0.3)

    var w2: Dictionary = _current_weapon()
    var wid2: String = _current_weapon_id()
    weapon_label.text = str(w2["name"])
    var ammo: int = int(weapon_ammo.get(wid2, 0))
    if reload_left > 0.0:
        ammo_label.text = "RELOADING %.1fs" % reload_left
    else:
        ammo_label.text = "%d / %d" % [ammo, int(w2["mag"])]

    for i in range(crosshairs.size()):
        crosshairs[i].visible = false
    var kind: String = str(w2["kind"])
    var map: Dictionary = {"pistol":0, "rifle":1, "shotgun":2, "sniper":3, "blaster":4}
    crosshairs[int(map[kind])].visible = true

func make_hit_fx(pos: Vector3, color: Color) -> void:
    var sphere: SphereMesh = SphereMesh.new()
    sphere.radius = 0.08
    sphere.height = 0.16
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = color
    material.emission_enabled = true
    material.emission = color
    sphere.material = material
    var mesh_instance: MeshInstance3D = MeshInstance3D.new()
    mesh_instance.mesh = sphere
    mesh_instance.global_position = pos
    get_tree().current_scene.add_child(mesh_instance)
    get_tree().create_timer(0.10).timeout.connect(mesh_instance.queue_free)

func damage(amount: int) -> void:
    if defeated:
        return
    hp = maxi(0, hp - amount)
    hp_label.text = "♥ %d" % hp
    if hp <= 0:
        defeated = true
        status_label.text = "GAME OVER\nPress R to restart"
        status_label.visible = true
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
