class_name MatchSnapshot
extends RefCounted

const SCHEMA_VERSION := 1

var match_epoch: int = 1
var phase: MatchPhase.Phase = MatchPhase.Phase.LOBBY
var rng_seed: int = 0
var rng_state: int = 0
var slots: Array[PlayerSlot] = []
var match_settings: Dictionary = {}
var board_stub: BoardStub = null
var selected_minigame_id: String = ""
var teams_by_player_id: Dictionary = {}
var minigame_outcome_applied: bool = false
var pending_board_rewards: Array = []
var final_scores_by_player_id: Dictionary = {}
