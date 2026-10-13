extends RefCounted
## Base class for test suites. The runner calls every method whose name starts
## with "test_". Use check()/check_eq() instead of assert(), so a failing test
## reports a message and the run continues.

var failures: Array[String] = []
## The running SceneTree, for tests that need nodes or frames.
var tree: SceneTree


func _reset() -> void:
	failures.clear()


func check(cond: bool, msg: String = "check failed") -> bool:
	if not cond:
		failures.append(msg)
	return cond


## Compares type first: in Godot 4, == between unrelated types is a runtime error.
func check_eq(actual: Variant, expected: Variant, msg: String = "") -> bool:
	var same: bool = typeof(actual) == typeof(expected) and actual == expected
	if not same:
		var prefix := msg + ": " if msg != "" else ""
		failures.append("%sexpected %s, got %s" % [prefix, var_to_str(expected), var_to_str(actual)])
	return same


## Element-wise comparison, so typed and untyped arrays can be compared.
func check_list(actual: Array, expected: Array, msg: String = "") -> bool:
	var same := actual.size() == expected.size()
	if same:
		for i in actual.size():
			if typeof(actual[i]) != typeof(expected[i]) or actual[i] != expected[i]:
				same = false
				break
	if not same:
		var prefix := msg + ": " if msg != "" else ""
		failures.append("%sexpected %s, got %s" % [prefix, str(expected), str(actual)])
	return same


func fail(msg: String) -> void:
	failures.append(msg)
