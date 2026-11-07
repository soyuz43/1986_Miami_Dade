class_name CrashScene
extends Node3D

## Main controller for the crash opening (Milestone 1).
##
## Launches straight into the crash opening with no menu. Runs the scripted
## blockout, then hands the viewer an inspectable camera over the settled
## vehicles. Restart replays the identical sequence from the beginning.

const SOURCE_NOTE: String = "Layout estimated from written sources, not from the official Exhibit A diagram."

@onready var camera: Camera3D = $Camera3D
@onready var status_label: Label = $CanvasLayer/StatusLabel
@onready var source_label: Label = $CanvasLayer/SourceLabel
@onready var help_label: Label = $CanvasLayer/HelpLabel
@onready var crash_sequence: CrashSequence = $CrashSequence

var _inspect_mode: bool = false


func _ready() -> void:
	if crash_sequence == null:
		push_error("CrashScene requires a CrashSequence node.")
		return

	CrashBlockout.build(self)
	_configure_camera()
	_update_labels()

	crash_sequence.phase_changed.connect(_on_phase_changed)
	crash_sequence.sequence_finished.connect(_on_sequence_finished)


func _process(_delta: float) -> void:
	if _inspect_mode:
		return
	_follow_subject_vehicle()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	match event.keycode:
		KEY_R:
			_restart()
		KEY_C:
			_toggle_camera()


func _restart() -> void:
	_inspect_mode = false
	crash_sequence.start()
	_configure_camera()
	_update_labels()


func _toggle_camera() -> void:
	_inspect_mode = not _inspect_mode
	if _inspect_mode:
		_place_inspection_camera()
	_update_labels()


## Track the subject vehicle during the sequence so the action stays framed.
func _follow_subject_vehicle() -> void:
	var subject: Node3D = crash_sequence.subject_vehicle
	if subject == null:
		return
	var target: Vector3 = subject.position
	var desired_position: Vector3 = target + Vector3(13.0, 9.5, 15.0)
	camera.position = camera.position.lerp(desired_position, 0.08)
	camera.look_at(target + Vector3(0.0, 0.6, 0.0), Vector3.UP)


## Place the camera in a fixed overview of the final vehicle arrangement.
func _place_inspection_camera() -> void:
	var subject: Node3D = crash_sequence.subject_vehicle
	if subject == null:
		return
	var focus: Vector3 = subject.position + Vector3(0.0, 0.6, 0.0)
	camera.position = focus + Vector3(13.0, 9.5, 15.0)
	camera.look_at(focus, Vector3.UP)


func _configure_camera() -> void:
	camera.position = Vector3(21.0, 13.5, -25.0)
	camera.look_at(Vector3(2.0, 0.6, -18.0), Vector3.UP)


func _on_phase_changed(_phase_name: String, _phase_index: int) -> void:
	_update_labels()


func _on_sequence_finished() -> void:
	_inspect_mode = true
	_place_inspection_camera()
	_update_labels()


func _update_labels() -> void:
	if crash_sequence == null:
		return

	if crash_sequence.is_finished():
		status_label.text = "Crash settled  |  Press R to replay  |  Press C for camera toggle"
	else:
		var beat: CrashChoreography.Beat = crash_sequence.get_current_beat()
		status_label.text = "%s  |  Press R to replay  |  Press C for camera toggle" % crash_sequence.get_phase_name()
		if beat != null and not beat.source.is_empty():
			source_label.text = "%s: %s" % [beat.source, beat.description]
		return

	source_label.text = "Blockout reconstruction - not a photographic reconstruction. %s" % SOURCE_NOTE
	help_label.text = "Phase timing is relative. The FBI incident report places the car stop near 9:32 a.m.; the Miami Herald reconstruction places it near 9:19 a.m."