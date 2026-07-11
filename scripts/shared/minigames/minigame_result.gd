class_name MinigameResult
extends RefCounted

enum Status {
	COMPLETED,
	ABORTED,
}

var status: Status = Status.COMPLETED
## Ordered best-to-worst. Each item is a PackedStringArray; multiple ids represent a tie.
var placements: Array = []
var scores_by_player_id: Dictionary = {}
var abort_reason: String = ""
var diagnostics: Dictionary = {}


static func completed(
		placement_groups: Array,
		scores: Dictionary = {},
		diagnostic_values: Dictionary = {},
) -> MinigameResult:
	var result := MinigameResult.new()
	result.status = Status.COMPLETED
	for group in placement_groups:
		var normalized := PackedStringArray()
		if group is PackedStringArray or group is Array:
			for player_id in group:
				normalized.append(String(player_id))
		result.placements.append(normalized)
	result.scores_by_player_id = scores.duplicate(true)
	result.diagnostics = diagnostic_values.duplicate(true)
	return result


static func aborted(reason: String) -> MinigameResult:
	var result := MinigameResult.new()
	result.status = Status.ABORTED
	result.abort_reason = reason.strip_edges()
	return result


func validate(participant_ids: PackedStringArray) -> PackedStringArray:
	var errors := PackedStringArray()
	var participants: Dictionary = {}
	for player_id in participant_ids:
		if participants.has(player_id):
			errors.append("Participant list contains duplicate player id: %s" % player_id)
		participants[player_id] = true

	if status == Status.ABORTED:
		if abort_reason.is_empty():
			errors.append("An aborted result requires a reason.")
		if not placements.is_empty() or not scores_by_player_id.is_empty():
			errors.append("An aborted result must not contain placements or scores.")
		return errors

	if placements.is_empty():
		errors.append("A completed result requires ordered placements.")

	var placed: Dictionary = {}
	for rank_index in placements.size():
		var group: Variant = placements[rank_index]
		if not (group is PackedStringArray) or group.is_empty():
			errors.append("Placement rank %d must contain at least one player id." % (rank_index + 1))
			continue
		for player_id in group:
			var resolved_id := String(player_id)
			if not participants.has(resolved_id):
				errors.append("Placement references unknown player id: %s" % resolved_id)
			elif placed.has(resolved_id):
				errors.append("Player appears in more than one placement: %s" % resolved_id)
			else:
				placed[resolved_id] = true

	for player_id in participants:
		if not placed.has(player_id):
			errors.append("Placement is missing participant: %s" % player_id)

	for player_id in scores_by_player_id:
		if not participants.has(String(player_id)):
			errors.append("Score references unknown player id: %s" % player_id)
		elif not (scores_by_player_id[player_id] is int or scores_by_player_id[player_id] is float):
			errors.append("Score for %s must be numeric." % player_id)

	return errors


func duplicate_result() -> MinigameResult:
	var copy := MinigameResult.new()
	copy.status = status
	for group in placements:
		copy.placements.append((group as PackedStringArray).duplicate())
	copy.scores_by_player_id = scores_by_player_id.duplicate(true)
	copy.abort_reason = abort_reason
	copy.diagnostics = diagnostics.duplicate(true)
	return copy
