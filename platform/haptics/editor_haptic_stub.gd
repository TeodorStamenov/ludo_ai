class_name EditorHapticStub
extends HapticService
## No-op имплементация на HapticService за Godot editor и тестове.
##
## Всички методи са наследени от HapticService и по дефиниция са no-op.
## Класът съществува като изричен именован адаптер, за да може Bootstrap
## да го инстанцира по name, а не чрез условна логика:
##
##   var haptics := EditorHapticStub.new()   # editor/PC
##   var haptics := AndroidHapticService.new() # Android export
