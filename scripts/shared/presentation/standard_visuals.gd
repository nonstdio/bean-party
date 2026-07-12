class_name StandardVisuals

const IDENTITY_IDS: Array[StringName] = [
	&"circle",
	&"triangle",
	&"square",
	&"diamond",
]

const IDENTITY_COLORS: Array[Color] = [
	Color(0.337255, 0.705882, 0.913725), #56B4E9
	Color(0.901961, 0.623529, 0.0), #E69F00
	Color(0.0, 0.619608, 0.45098), #009E73
	Color(0.8, 0.47451, 0.654902), #CC79A7
]

const IDENTITY_ICONS: Array[Texture2D] = [
	preload("res://assets/standard/identities/player-circle.svg"),
	preload("res://assets/standard/identities/player-triangle.svg"),
	preload("res://assets/standard/identities/player-square.svg"),
	preload("res://assets/standard/identities/player-diamond.svg"),
]

const IDENTITY_MATERIALS: Array[StandardMaterial3D] = [
	preload("res://assets/standard/materials/identity-circle.tres"),
	preload("res://assets/standard/materials/identity-triangle.tres"),
	preload("res://assets/standard/materials/identity-square.tres"),
	preload("res://assets/standard/materials/identity-diamond.tres"),
]

const CANVAS := Color(0.039216, 0.070588, 0.101961) #0A121A
const SURFACE := Color(0.086275, 0.137255, 0.176471) #16232D
const SURFACE_RAISED := Color(0.129412, 0.2, 0.247059) #21333F
const BORDER := Color(0.27451, 0.376471, 0.415686) #46606A
const TEXT_PRIMARY := Color(0.901961, 0.933333, 0.913725) #E6EEE9
const TEXT_SECONDARY := Color(0.721569, 0.788235, 0.756863) #B8C9C1
const TEXT_MUTED := Color(0.533333, 0.639216, 0.603922) #88A39A
const FOCUS := Color(0.941176, 0.894118, 0.258824) #F0E442


static func identity_index_for_color(slot_color: Color) -> int:
	return IDENTITY_COLORS.find(slot_color)


static func fallback_identity_index(identity_index: int) -> int:
	if identity_index >= 0 and identity_index < IDENTITY_IDS.size():
		return identity_index
	return 0


static func identity_icon_for_color(slot_color: Color) -> Texture2D:
	var identity_index := fallback_identity_index(identity_index_for_color(slot_color))
	return IDENTITY_ICONS[identity_index]


static func identity_material_for_color(slot_color: Color) -> StandardMaterial3D:
	var identity_index := fallback_identity_index(identity_index_for_color(slot_color))
	return IDENTITY_MATERIALS[identity_index]
