class_name MatchPhase
extends RefCounted

enum Phase {
	LOBBY,
	BOARD,
	MINIGAME_SELECTION,
	BRIEFING,
	COUNTDOWN,
	ACTIVE_MINIGAME,
	RESULTS,
	RETURN_TO_BOARD,
	MATCH_RESULTS,
}

const _PHASE_KEYS: Array[String] = [
	"Lobby",
	"Board",
	"MinigameSelection",
	"Briefing",
	"Countdown",
	"ActiveMinigame",
	"Results",
	"ReturnToBoard",
	"MatchResults",
]


static func to_key(phase: Phase) -> String:
	return _PHASE_KEYS[phase]


static func from_key(key: String) -> Phase:
	var index := _PHASE_KEYS.find(key)
	if index < 0:
		push_error("Unknown match phase key: %s" % key)
		return Phase.LOBBY
	return index as Phase
