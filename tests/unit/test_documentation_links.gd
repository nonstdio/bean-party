extends GutTest


func test_relative_markdown_link_targets_exist() -> void:
	var markdown_files := PackedStringArray()
	_collect_markdown_files("res://", markdown_files)
	var failures := PackedStringArray()
	var link_expression := RegEx.new()
	link_expression.compile("(?<!!)\\[[^\\]]+\\]\\(([^)]+)\\)")

	for file_path in markdown_files:
		var contents := FileAccess.get_file_as_string(file_path)
		for match_result in link_expression.search_all(contents):
			var target := match_result.get_string(1).strip_edges().trim_prefix("<").trim_suffix(">")
			if _is_external_or_anchor(target):
				continue
			var path_part := target.split("#", false, 1)[0].uri_decode()
			if path_part.is_empty():
				continue
			var resolved := file_path.get_base_dir().path_join(path_part).simplify_path()
			if not FileAccess.file_exists(resolved) and not DirAccess.dir_exists_absolute(resolved):
				failures.append("%s -> %s" % [file_path, target])

	assert_true(failures.is_empty(), "Broken relative Markdown links:\n%s" % "\n".join(failures))


func _collect_markdown_files(root: String, paths: PackedStringArray) -> void:
	var directory := DirAccess.open(root)
	if directory == null:
		return
	for file_name in directory.get_files():
		if file_name.ends_with(".md"):
			paths.append(root.path_join(file_name))
	for folder in directory.get_directories():
		if folder in [".git", ".godot", "addons"]:
			continue
		_collect_markdown_files(root.path_join(folder), paths)


func _is_external_or_anchor(target: String) -> bool:
	return (
		target.begins_with("http://")
		or target.begins_with("https://")
		or target.begins_with("mailto:")
		or target.begins_with("#")
	)
