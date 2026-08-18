extends Node3D
class_name EditorCameraController

@export_category("References")
@export var camera: Camera3D

@export_category("Orbit")
@export var orbit_sensitivity: float = 0.01

@export_category("Pan")
@export var pan_sensitivity: float = 0.01

@export_category("Zoom")
@export var zoom_speed: float = 2.0
@export var min_distance: float = 2.0
@export var max_distance: float = 50.0

var orbit_pitch: float = deg_to_rad(-30.0)
var orbit_yaw: float = 0.0
var distance: float = 10.0

var focus_point: Vector3 = Vector3.ZERO


func _ready() -> void:
	if camera == null:
		camera = get_node_or_null("Camera3D")

	if camera == null:
		push_error("EditorCameraController: Camera3D not found.")


func _process(_delta: float) -> void:
	_update_camera_transform()


func _unhandled_input(event: InputEvent) -> void:

	# ----------------------------------------
	# Mouse wheel zoom
	# ----------------------------------------
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance -= zoom_speed
			distance = clamp(distance, min_distance, max_distance)

		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance += zoom_speed
			distance = clamp(distance, min_distance, max_distance)

	# ----------------------------------------
	# Mouse movement
	# ----------------------------------------
	if event is InputEventMouseMotion:

		# Middle mouse button
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):

			# Shift + MMB = Pan
			if Input.is_key_pressed(KEY_SHIFT):
				_pan_camera(event.relative)

			# MMB = Orbit
			else:
				_orbit_camera(event.relative)


func _orbit_camera(mouse_delta: Vector2) -> void:
	orbit_yaw -= mouse_delta.x * orbit_sensitivity
	orbit_pitch -= mouse_delta.y * orbit_sensitivity

	# Prevent flipping upside down
	orbit_pitch = clamp(
		orbit_pitch,
		deg_to_rad(-89.0),
		deg_to_rad(89.0)
	)


func _pan_camera(mouse_delta: Vector2) -> void:
	var right := camera.global_transform.basis.x
	var up := camera.global_transform.basis.y

	focus_point -= right * mouse_delta.x * pan_sensitivity * distance
	focus_point += up * mouse_delta.y * pan_sensitivity * distance


func _update_camera_transform() -> void:
	if camera == null:
		return

	var rotation_basis := Basis.from_euler(
		Vector3(
			orbit_pitch,
			orbit_yaw,
			0.0
		)
	)

	var offset := rotation_basis * Vector3(0, 0, distance)

	camera.global_position = focus_point + offset

	camera.look_at(
		focus_point,
		Vector3.UP
	)
