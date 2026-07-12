class_name MinigameManifest
extends Resource

const CONTRACT_VERSION := 1
const CAPABILITY_LOCAL_ONLY: StringName = &"local_only"
const CAPABILITY_NETWORK_CAPABLE: StringName = &"network_capable"
const SUPPORTED_CAPABILITIES: Array[StringName] = [
	CAPABILITY_LOCAL_ONLY,
	CAPABILITY_NETWORK_CAPABLE,
]
const SUPPORTED_FORMATS: Array[StringName] = [
	&"free_for_all",
	&"two_vs_two",
	&"one_vs_three",
	&"cooperative",
	&"other",
]
const SUPPORTED_SYNC_PROFILES: Array[StringName] = [
	&"TURN_OR_EVENT",
	&"HOST_SNAPSHOT",
	&"HOST_ACTION",
	&"CUSTOM_APPROVED",
]

@export var contract_version: int = CONTRACT_VERSION
@export var minigame_id: StringName
@export var display_name: String = ""
@export var root_scene: PackedScene
@export_range(2, 4, 1) var minimum_players: int = 2
@export_range(2, 4, 1) var maximum_players: int = 4
@export var format: StringName = &"free_for_all"
@export var capability: StringName = CAPABILITY_LOCAL_ONLY
@export var sync_profile: StringName


func validate() -> PackedStringArray:
	var errors := PackedStringArray()

	if contract_version != CONTRACT_VERSION:
		errors.append(
			(
				"Unsupported local minigame contract version %d; expected %d."
				% [contract_version, CONTRACT_VERSION]
			)
		)

	if not is_valid_slug(String(minigame_id)):
		errors.append("Minigame id must use lowercase kebab-case.")
	if display_name.strip_edges().is_empty():
		errors.append("Display name is required.")
	if root_scene == null:
		errors.append("Root scene is required.")
	if minimum_players < 2 or minimum_players > MatchConstants.MAX_PLAYERS:
		errors.append("Minimum players must be between 2 and %d." % MatchConstants.MAX_PLAYERS)
	if maximum_players < minimum_players or maximum_players > MatchConstants.MAX_PLAYERS:
		errors.append(
			(
				"Maximum players must be at least the minimum and no more than %d."
				% MatchConstants.MAX_PLAYERS
			)
		)
	if format not in SUPPORTED_FORMATS:
		errors.append("Unsupported minigame format: %s" % format)
	if capability not in SUPPORTED_CAPABILITIES:
		errors.append("Unsupported capability: %s" % capability)
	elif capability == CAPABILITY_LOCAL_ONLY and not String(sync_profile).is_empty():
		errors.append("A local-only minigame must not declare a networking sync profile.")
	elif capability == CAPABILITY_NETWORK_CAPABLE and sync_profile not in SUPPORTED_SYNC_PROFILES:
		errors.append(
			"A network-capable minigame must declare a supported provisional sync profile."
		)

	return errors


func supports_player_count(player_count: int) -> bool:
	return player_count >= minimum_players and player_count <= maximum_players


static func is_valid_slug(value: String) -> bool:
	if value.is_empty():
		return false
	var expression := RegEx.new()
	if expression.compile("^[a-z0-9]+(?:-[a-z0-9]+)*$") != OK:
		return false
	return expression.search(value) != null
