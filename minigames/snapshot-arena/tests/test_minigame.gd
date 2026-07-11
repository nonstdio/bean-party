extends GutTest

const MANIFEST_PATH := "res://minigames/snapshot-arena/minigame.tres"


func test_manifest_satisfies_local_contract() -> void:
	var manifest := load(MANIFEST_PATH) as MinigameManifest
	assert_not_null(manifest)
	assert_true(manifest.validate().is_empty())
