extends Node3D

## Screenshot tool for the crash opening.
##
## Run with:
##   godot --path . scenes/capture_shots.tscn --resolution 1280x720
##
## Captures the main scene at each phase of the crash sequence so the staging
## can be reviewed without watching the animation in real time. Output lands in
## the user data directory under "crash_shots".

const MAIN_SCENE: String = "res://scenes/main.tscn"
const OUTPUT_DIR: String = "user://crash_shots"
const SHOT_TIMES: Array[float] = [0.0, 2.6, 4.0, 5.5, 7.0, 8.6, 10.0, 13.0]
const STEP: float = 1.0 / 60.0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)

	var scene: Node3D = load(MAIN_SCENE).instantiate()
	var sequence: CrashSequence = scene.get_node("CrashSequence")
	sequence.auto_start = false
	sequence.set_process(false)
	scene.set_process(false)
	add_child(scene)

	var camera: Camera3D = scene.get_node("Camera3D")
	camera.current = true

	print("CAPTURE: ground present = %s" % (scene.get_node_or_null("Ground") != null))

	for shot_time: float in SHOT_TIMES:
		sequence.start()
		var elapsed: float = 0.0
		while elapsed < shot_time:
			sequence._process(STEP)
			elapsed += STEP

		# Frame the subject vehicle the same way the running game does.
		var focus: Vector3 = sequence.subject_vehicle.position + Vector3(0.0, 0.6, 0.0)
		camera.global_position = focus + Vector3(13.0, 9.5, 15.0)
		camera.look_at(focus, Vector3.UP)

		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame

		var image: Image = get_viewport().get_texture().get_image()
		var path: String = "%s/shot_%0.1f.png" % [OUTPUT_DIR, shot_time]
		image.save_png(path)
		print("CAPTURE: %s" % ProjectSettings.globalize_path(path))

	get_tree().quit(0)
