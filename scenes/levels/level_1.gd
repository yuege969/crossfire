extends Node2D


@onready var _a1_light: PointLight2D = $Lights/A1PointLight
@onready var _a2_light: PointLight2D = $Lights/A2PointLight
@onready var _r1_light: PointLight2D = $Lights/R1PointLight
@onready var _r2_light: PointLight2D = $Lights/R2PointLight
@onready var _r3_light: PointLight2D = $Lights/R3PointLight
@onready var _r4_light: PointLight2D = $Lights/R4PointLight
@onready var _r5_light: PointLight2D = $Lights/R5PointLight

var _light_tweens: Array[Tween] = []


func _ready() -> void:
	_start_light_blinking()


func _start_light_blinking() -> void:
	_start_accent_lights()
	_start_ring_lights()


func _start_accent_lights() -> void:
	# A1/A2: alternating slow pulse — one fades in while the other fades out
	var tween_a1 := create_tween()
	tween_a1.set_loops()
	tween_a1.tween_property(_a1_light, "energy", 1.6, 2).set_ease(Tween.EASE_OUT)
	tween_a1.tween_property(_a1_light, "energy", 0.4, 2).set_ease(Tween.EASE_IN)
	_light_tweens.append(tween_a1)

	var tween_a2 := create_tween()
	tween_a2.set_loops()
	tween_a2.tween_property(_a2_light, "energy", 0.4, 2).set_ease(Tween.EASE_IN)
	tween_a2.tween_property(_a2_light, "energy", 1.6, 2).set_ease(Tween.EASE_OUT)
	_light_tweens.append(tween_a2)


func _start_ring_lights() -> void:
	# R1~R5: alternating slow pulse — same pattern as A1/A2
	var ring_lights: Array[PointLight2D] = [_r1_light, _r2_light, _r3_light, _r4_light, _r5_light]

	for i: int in ring_lights.size():
		var light := ring_lights[i]
		var tween := create_tween()
		tween.set_loops()
		if i % 2 == 0:
			# R1,R3,R5: fade in then fade out (same phase as A1)
			tween.tween_property(light, "energy", 1.6, 2).set_ease(Tween.EASE_OUT)
			tween.tween_property(light, "energy", 0.4, 2).set_ease(Tween.EASE_IN)
		else:
			# R2,R4: fade out then fade in (same phase as A2)
			tween.tween_property(light, "energy", 0.4, 2).set_ease(Tween.EASE_IN)
			tween.tween_property(light, "energy", 1.6, 2).set_ease(Tween.EASE_OUT)
		_light_tweens.append(tween)


func _stop_light_tweens() -> void:
	for tween in _light_tweens:
		if is_instance_valid(tween) and tween.is_valid():
			tween.kill()
	_light_tweens.clear()
