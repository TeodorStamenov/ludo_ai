class_name AtomicFileWriter
extends RefCounted
## Атомичен запис на текст във файл чрез временен файл (#248).
##
## Пише в "<path>.tmp", после rename → path. На платформи, където rename
## презаписва съществуваща цел (POSIX — единичен atomic syscall), няма
## прозорец, в който файлът липсва. Ако директният rename се провали (напр.
## Windows, където rename по подразбиране НЕ презаписва), пада към
## remove + rename — единственият случай с кратък прозорец на риск,
## неизбежен без платформено-специфични extensions.
##
## Предишна версия винаги правеше remove преди rename — ако процесът/
## устройството катастрофира между двете, файлът изчезваше напълно вместо
## просто да остане стар (точно обратното на целта на "атомичен запис").
##
## Domain-агностичен: не знае нищо за envelope/schema_version — само пише
## произволен текст безопасно. LocalSaveRepository го ползва за трите си
## JSON файла.


## True при успех. path трябва да е записваем Godot път (напр. "user://x.json").
static func write(path: String, content: String) -> bool:
	if path.is_empty():
		push_error("AtomicFileWriter.write: празен path")
		return false

	var tmp_path := path.get_basename() + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if not file:
		push_error("AtomicFileWriter: cannot write '%s' (error %d)" % [
			tmp_path, FileAccess.get_open_error()])
		return false
	file.store_string(content)
	file = null

	var dir_path := path.get_base_dir()
	var dir := DirAccess.open(dir_path)
	if not dir:
		push_error("AtomicFileWriter: cannot open dir '%s'" % dir_path)
		return false

	var tmp_name := tmp_path.get_file()
	var final_name := path.get_file()

	var err := dir.rename(tmp_name, final_name)
	if err != OK and dir.file_exists(final_name):
		dir.remove(final_name)
		err = dir.rename(tmp_name, final_name)
	if err != OK:
		push_error("AtomicFileWriter: rename '%s' -> '%s' failed: %d" % [
			tmp_name, final_name, err])
		return false
	return true
