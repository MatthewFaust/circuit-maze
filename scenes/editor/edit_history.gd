class_name EditHistory
extends RefCounted
## Undo/redo as snapshots of the program Dictionary. Quick repeated edits of
## the same parameter (typing a repeat count) share one snapshot.

const LIMIT := 100
const COALESCE_MS := 1500

var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _last_key := ""
var _last_time := 0


## Call before changing the program, with the program as it is now.
func push(snapshot: Dictionary, coalesce_key: String = "") -> void:
	var now := Time.get_ticks_msec()
	if coalesce_key != "" and coalesce_key == _last_key and now - _last_time < COALESCE_MS:
		_last_time = now
		return
	_undo.append(snapshot.duplicate(true))
	if _undo.size() > LIMIT:
		_undo.pop_front()
	_redo.clear()
	_last_key = coalesce_key
	_last_time = now


## Returns the program to restore, or {} if there is nothing to undo.
func undo(current: Dictionary) -> Dictionary:
	if _undo.is_empty():
		return {}
	_redo.append(current.duplicate(true))
	_last_key = ""
	return _undo.pop_back()


func redo(current: Dictionary) -> Dictionary:
	if _redo.is_empty():
		return {}
	_undo.append(current.duplicate(true))
	_last_key = ""
	return _redo.pop_back()


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


func clear() -> void:
	_undo.clear()
	_redo.clear()
	_last_key = ""
