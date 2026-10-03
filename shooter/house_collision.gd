extends StaticBody3D

@export var wall_thickness: float = 0.35
@export var wall_height: float = 5.0
@export var inset: float = 0.15

func _ready() -> void:
    call_deferred("_build_walls")

func _build_walls() -> void:
    for child in get_children():
        if child is CollisionShape3D:
            child.queue_free()
    var bounds: AABB = _get_model_bounds()
    if bounds.size.x <= 0.1 or bounds.size.z <= 0.1:
        bounds = AABB(Vector3(-6.0, 0.0, -6.0), Vector3(12.0, wall_height, 12.0))
    var min_x: float = bounds.position.x + inset
    var max_x: float = bounds.end.x - inset
    var min_z: float = bounds.position.z + inset
    var max_z: float = bounds.end.z - inset
    var height: float = minf(wall_height, maxf(bounds.size.y, 3.0))
    var center_y: float = bounds.position.y + height * 0.5
    _add_wall("North", Vector3((min_x + max_x) * 0.5, center_y, min_z), Vector3(max_x - min_x, height, wall_thickness))
    _add_wall("South", Vector3((min_x + max_x) * 0.5, center_y, max_z), Vector3(max_x - min_x, height, wall_thickness))
    _add_wall("West", Vector3(min_x, center_y, (min_z + max_z) * 0.5), Vector3(wall_thickness, height, max_z - min_z))
    _add_wall("East", Vector3(max_x, center_y, (min_z + max_z) * 0.5), Vector3(wall_thickness, height, max_z - min_z))

func _add_wall(wall_name: String, center: Vector3, size: Vector3) -> void:
    var shape_node: CollisionShape3D = CollisionShape3D.new()
    shape_node.name = wall_name
    var box: BoxShape3D = BoxShape3D.new()
    box.size = size
    shape_node.shape = box
    shape_node.position = center
    add_child(shape_node)

func _get_model_bounds() -> AABB:
    var found: bool = false
    var result: AABB = AABB()
    for node in get_children():
        if node is Node3D:
            var meshes: Array[Node] = []
            _collect_meshes(node, meshes)
            for mesh_node in meshes:
                var mesh_instance: MeshInstance3D = mesh_node as MeshInstance3D
                var local_aabb: AABB = mesh_instance.get_aabb()
                var t: Transform3D = global_transform.affine_inverse() * mesh_instance.global_transform
                for corner in _aabb_corners(local_aabb):
                    var p: Vector3 = t * corner
                    if not found:
                        result = AABB(p, Vector3.ZERO)
                        found = true
                    else:
                        result = result.expand(p)
    return result

func _collect_meshes(node: Node, result: Array[Node]) -> void:
    if node is MeshInstance3D:
        result.append(node)
    for child in node.get_children():
        _collect_meshes(child, result)

func _aabb_corners(aabb: AABB) -> Array[Vector3]:
    var p: Vector3 = aabb.position
    var s: Vector3 = aabb.size
    return [
        p,
        p + Vector3(s.x, 0, 0),
        p + Vector3(0, s.y, 0),
        p + Vector3(0, 0, s.z),
        p + Vector3(s.x, s.y, 0),
        p + Vector3(s.x, 0, s.z),
        p + Vector3(0, s.y, s.z),
        p + s
    ]
