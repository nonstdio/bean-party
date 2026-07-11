class_name MinigameRegistry
extends RefCounted

const DEFAULT_BASE_PATH := "res://minigames"
const MANIFEST_FILENAME := "minigame.tres"

var manifests_by_id: Dictionary = {}
var errors: PackedStringArray = PackedStringArray()


func discover(base_path: String = DEFAULT_BASE_PATH) -> bool:
	manifests_by_id.clear()
	errors.clear()

	var directory := DirAccess.open(base_path)
	if directory == null:
		errors.append("Could not open minigame directory: %s" % base_path)
		return false

	var folders := directory.get_directories()
	folders.sort()
	for folder in folders:
		if folder.begins_with("_"):
			continue
		_discover_folder(base_path, folder)

	return errors.is_empty()


func get_manifest(minigame_id: StringName) -> MinigameManifest:
	return manifests_by_id.get(minigame_id) as MinigameManifest


func get_minigame_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for minigame_id in manifests_by_id:
		ids.append(minigame_id)
	ids.sort()
	return ids


func _discover_folder(base_path: String, folder: String) -> void:
	var error_count_before := errors.size()
	var folder_path := "%s/%s" % [base_path, folder]
	var manifest_path := "%s/%s" % [folder_path, MANIFEST_FILENAME]
	if not ResourceLoader.exists(manifest_path):
		errors.append("Minigame folder is missing %s: %s" % [MANIFEST_FILENAME, folder_path])
		return

	var resource := ResourceLoader.load(manifest_path)
	if not resource is MinigameManifest:
		errors.append("Manifest does not use MinigameManifest: %s" % manifest_path)
		return

	var manifest := resource as MinigameManifest
	var manifest_errors := manifest.validate()
	for manifest_error in manifest_errors:
		errors.append("%s: %s" % [manifest_path, manifest_error])

	if String(manifest.minigame_id) != folder:
		errors.append("Manifest id must match folder '%s': %s" % [folder, manifest_path])
	if manifest.root_scene != null and not manifest.root_scene.resource_path.begins_with(folder_path + "/"):
		errors.append("Root scene must be owned by its minigame folder: %s" % manifest_path)
	if not FileAccess.file_exists("%s/README.md" % folder_path):
		errors.append("Minigame folder is missing README.md: %s" % folder_path)
	if manifests_by_id.has(manifest.minigame_id):
		errors.append("Duplicate minigame id: %s" % manifest.minigame_id)
	elif errors.size() == error_count_before:
		manifests_by_id[manifest.minigame_id] = manifest
