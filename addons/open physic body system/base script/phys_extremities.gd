extends RigidBody
#"base of both feet and hand of the vr character an AI physic character or a flatscreen player 
#"the hands, the stabilizing spehere and the head have an extends script that follow the controller"
#"for the feet they are instructed by the hip script"

# determine the body (node a of the joint)
export var body_p : NodePath 
onready var body : RigidBody = get_node(body_p)

#if true the rigisdbody will set its joint to stay at the same local position as set in the editor
export var is_stable : bool = false

var is_grabbing := false
var grab_obj := []
var grab_joint := []

# coords and basis for the joint and PID controller to target
export var target_pos := Vector3.ZERO
export var target_basis : Basis

#reffer to the 6DOFJoint that allows the rigidbody to move
onready var pos_joint : Generic6DOFJoint = get_node("Generic6DOFJoint")

#to enable the rotation
export var is_stabilizing_rotation : bool = true
export var is_targeting_basis : bool = true

#(PID is a Vector 3 X = Proportionnal, Y = Integral and Z = Differential)
# the variable for the PID setting it to no angular momentum
export var PID_to_zero := Vector3(2,0,0) 
var last_error_z := Vector3.ZERO
var integral_z   := Vector3.ZERO

# the variable for the 2 axis of rotation : pitch and yaw
export var PID_to_target := Vector3(50,0,0.1)
var last_error_t := Vector3.ZERO
var integral_t   := Vector3.ZERO

# the variable for the roll axis of rotation
export var PID_to_roll := Vector3(15,0,0.01)
var last_error_r := Vector3.ZERO
var integral_r   := Vector3.ZERO

# set the maximum lenght the joint can push, usefull if you don't want to have a limit for exemple of arm lenght
export var max_length := Vector3.INF

# joint force (stiffness) and damping, note that the damping is what smooths out the impulse, thus reducing the pendulum effect
export var stiffness := 100
export var damping := 5

#if you want to have offset from the instructed posistion, 
#due note that the offset between the node a and node b is added to insure that the local pos correspond with the actual local pos
export var offset := Vector3.ZERO

func _ready():
	if body == null:
		body = get_node(pos_joint.get_node_a())
	
	if pos_joint != null:
		
		pos_joint.set("linear_spring_x/enabled",true)
		
		pos_joint.set("linear_spring_y/enabled",true)
		
		pos_joint.set("linear_spring_z/enabled",true)
		
		pos_joint.set("linear_spring_x/stiffness",stiffness)
		pos_joint.set("linear_spring_y/stiffness",stiffness)
		pos_joint.set("linear_spring_z/stiffness",stiffness)

		pos_joint.set("linear_spring_x/damping",damping)
		pos_joint.set("linear_spring_y/damping",damping)
		pos_joint.set("linear_spring_z/damping",damping)
		
#		the offset between the node a(body) and node b(self) is added to insure that the local pos correspond with the actual local pos
		offset = body.global_transform.origin - self.global_transform.origin + offset
		
#		disable the linear_limit if no max_lenght is set,
#		note that if you are using a max_lenght you are not force to have a joint linear limit
#		thus you could have an hand that cannot be targetted farther than 1 meter away, but could be pulled away from it limit, creating a slingshot effect
		if max_length.length() < INF:
			pos_joint.set("linear_limit_x/enabled",false)
			pos_joint.set("linear_limit_y/enabled",false)
			pos_joint.set("linear_limit_z/enabled",false)
	
		
	else:
		print("pos_joint is null ")

func grab():
#	 add the function of grabbing to allow for both hand and feet grabbing with a single script insuring consistant behavior between the two
	if get_colliding_bodies().size() > 1:
		print("too many body")
	elif get_colliding_bodies().size() > 0:
		var obj = get_colliding_bodies()[0]
		
#		if the object is static and we want a perfect grab, we make the rigidbody go static as to not have offset when push and pulled around
		if obj is StaticBody:
			mode = MODE_KINEMATIC
#			print("static grabbing")
		else:
			var joint := Generic6DOFJoint.new()
			self.add_child(joint)
			joint.global_transform = global_transform
			joint.set_node_a(self.get_path())
			joint.set_node_b(obj.get_path())
			grab_joint.append(joint)
#			print("joint grabbing")
		is_grabbing = true
		
#		grab_obj.append(obj)
		
		

func drop():
	if mode == MODE_KINEMATIC:
		mode = MODE_RIGID
	
	for j in grab_joint:
		j.queue_free()
		grab_joint.erase(j)
	is_grabbing = false

func _physics_process(delta):
			#position
			if !is_stable:
				target_pos += offset
			
			
			if pos_joint != null:
				pos_joint.set("linear_spring_x/equilibrium_point", clamp(target_pos.x,-max_length.x, max_length.x))
				pos_joint.set("linear_spring_y/equilibrium_point", clamp(target_pos.y,-max_length.y, max_length.y))
				pos_joint.set("linear_spring_z/equilibrium_point", clamp(target_pos.z,-max_length.z, max_length.z))
			
#			print(target_pos)
			#rotation
			if is_stabilizing_rotation:
				#restore angular velocity to 0
				var correction_to_zero = PID(-angular_velocity,delta,0)
				add_torque(correction_to_zero)
				#rotation
			if is_targeting_basis:
				var error_target :Vector3 = - target_basis.z.cross(transform.basis.z)
				var correction_to_target = PID(error_target,delta,1)
				add_torque(correction_to_target)
				#roll
				var error_roll : Vector3 
				var cross_p_roll :Vector3 = target_basis.x.cross(transform.basis.x)
				if target_basis.x.x > 0 && target_basis.y.y > 0 || target_basis.z.z > 0:
					if cross_p_roll.z >= 0 :
						error_roll = transform.basis.z * - cross_p_roll.length()
					else:
						error_roll = transform.basis.z *  cross_p_roll.length()
				else:
					if cross_p_roll.z >= 0 :
						error_roll = transform.basis.z * cross_p_roll.length()
					else:
						error_roll = transform.basis.z * - cross_p_roll.length()
				add_torque(PID(error_roll,delta,2))



func PID(current_error:Vector3,time:float,PID_num:int):

	if PID_num == 0:
		integral_z += current_error * time
		var deriv = (current_error - last_error_z) /time
		last_error_z = current_error
		return current_error*PID_to_zero.x + integral_z *PID_to_zero.y + deriv*PID_to_zero.z
	elif PID_num == 1:
		integral_t += current_error * time
		var deriv = (current_error - last_error_t) /time
		last_error_t = current_error
		return current_error*PID_to_target.x + integral_t *PID_to_target.y + deriv*PID_to_target.z
	else:
		integral_r += current_error * time
		var deriv = (current_error - last_error_r) /time
		last_error_r = current_error
#		if deriv.length() > 15:
#			print(rotation_degrees)
		return current_error*PID_to_roll.x + integral_t *PID_to_roll.y + deriv*PID_to_roll.z
#

