class_name PlayerSlotConnectivity
extends RefCounted


static func is_participating(slot: PlayerSlot) -> bool:
	return slot.connection_status == PlayerSlot.ConnectionStatus.CONNECTED


static func mark_peer_inactive(slots: Array[PlayerSlot], peer_id: int) -> bool:
	var changed := false
	for slot in slots:
		if slot.owning_peer_id != peer_id:
			continue
		if slot.connection_status == PlayerSlot.ConnectionStatus.CONNECTED:
			slot.connection_status = PlayerSlot.ConnectionStatus.INACTIVE
			slot.ready = false
			changed = true
	return changed


static func reclaim_slot(slots: Array[PlayerSlot], player_id: String, peer_id: int) -> bool:
	for slot in slots:
		if slot.player_id != player_id:
			continue
		if slot.connection_status != PlayerSlot.ConnectionStatus.INACTIVE:
			return false
		slot.owning_peer_id = peer_id
		slot.connection_status = PlayerSlot.ConnectionStatus.CONNECTED
		return true
	return false


static func can_reclaim_slot(slots: Array[PlayerSlot], player_id: String) -> bool:
	for slot in slots:
		if slot.player_id == player_id:
			return slot.connection_status == PlayerSlot.ConnectionStatus.INACTIVE
	return false


static func participating_slot_count(slots: Array[PlayerSlot]) -> int:
	var count := 0
	for slot in slots:
		if is_participating(slot):
			count += 1
	return count


static func duplicate_slots(slots: Array[PlayerSlot]) -> Array[PlayerSlot]:
	var copy: Array[PlayerSlot] = []
	for slot in slots:
		copy.append(slot.duplicate_slot())
	return copy


static func copy_slots_into(target: Array[PlayerSlot], source: Array[PlayerSlot]) -> void:
	target.clear()
	for slot in source:
		target.append(slot.duplicate_slot())
