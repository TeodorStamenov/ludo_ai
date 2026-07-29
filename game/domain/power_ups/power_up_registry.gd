class_name PowerUpRegistry
extends RefCounted
## Свързва PowerUpId с PowerUpResolver instance (docs/V1_ARCHITECTURE.md §4.7:
## "Няма match power_up_id из различни UI скриптове. Registry свързва
## power_up_id с resolver."; #196-#213).

var _resolvers: Dictionary = {}


func _init() -> void:
	_resolvers[PowerUpId.TELEPORT_FORWARD] = TeleportEffect.new()
	_resolvers[PowerUpId.SHIELD] = ShieldEffect.new()
	_resolvers[PowerUpId.EXTRA_TURN] = ExtraTurnEffect.new()
	_resolvers[PowerUpId.PUSH] = PushEffect.new()


## Resolver за power_up_id, или null ако не е регистриран.
func resolver_for(power_up_id: StringName) -> PowerUpResolver:
	return _resolvers.get(power_up_id) as PowerUpResolver
