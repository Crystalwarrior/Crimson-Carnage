extends Marker3D


var usable = true


func _on_area_3d_body_entered(_body):
	usable = false


func _on_area_3d_body_exited(_body):
	usable = true
