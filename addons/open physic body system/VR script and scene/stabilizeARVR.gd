extends "res://addons/open physic body system/base script/Stabilize_cam.gd"


onready var left_controller : Spatial = get_node("left_controller")
onready var right_controller : Spatial =get_node("right_controller")
onready var hmd : Spatial = get_node("hmd")

enum LocomotionStickTurnType {CLICK , SMOOTH}
export(LocomotionStickTurnType) var turn_type = LocomotionStickTurnType.CLICK

var last_click_rotate = false
export var dead_zone = 0.5 # originally 0.125
var dead_zone_epsilon = 0.8
export var smooth_turn_speed := 90.0;
export var click_turn_angle := 45.0; 

func _physics_process(delta):
	#function from the oculus quest toolkit with a few replacement due to a different structure
	var dlr = -right_controller.axis[0]

	if (last_click_rotate): # reset to false only when stick is moved in deadzone; but with epsilon
		last_click_rotate = (abs(dlr) > dead_zone * dead_zone_epsilon); 

	if (abs(dlr) <= dead_zone): 
		return;

	var origHeadPos = hmd.global_transform.origin;
	
	# click turning
	if (turn_type == LocomotionStickTurnType.CLICK && !last_click_rotate):
		last_click_rotate = true;
		var dsign = sign(dlr);
		rotate_y(dsign * deg2rad(click_turn_angle));
			
	# smooth turning
	elif (turn_type == LocomotionStickTurnType.SMOOTH):
#		if (enable_vignette) : movement_vignette_rect.visible = true;
		rotate_y(deg2rad(dlr * smooth_turn_speed * delta));

	# reposition vrOrigin for in place rotation
	global_transform.origin +=  origHeadPos - hmd.global_transform.origin;
	global_transform = global_transform.orthonormalized();
	