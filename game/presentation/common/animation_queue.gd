class_name AnimationQueue
extends Node
## Проиграва DomainEvent-и последователно като анимации
## (docs/V1_ARCHITECTURE.md, раздел 6.1).
##
## GamePresenter получава батч events от MatchSession и ги поставя тук.
## AnimationQueue ги изпълнява един по един:
##   1. Избира правилния view чрез EventViewBinder (#167).
##   2. Стартира анимацията (напр. DiceRolled → DiceView.present_dice_rolled).
##   3. Изчаква сигнал animation_finished (#169).
##   4. Преминава към следващото събитие.
##   5. При изпразване емитира all_done(sequence).
##
## GamePresenter слуша all_done и извиква session.events_presented(sequence).
## Domain не чака tween — само Presentation го прави.
##
## MVP (#167): play_batch прилага events синхронно през EventViewBinder (snap),
## после all_done — същият gate договор като MatchSimulator.
## Последователният await на анимации е задача #168 / #169.

signal all_done(sequence: int)

var _playing: bool = false
var _current_sequence: int = -1
var _binder: EventViewBinder = null


func set_event_binder(binder: EventViewBinder) -> void:
	_binder = binder


func get_event_binder() -> EventViewBinder:
	return _binder


## Стартира батч за дадения command_sequence.
## MVP: синхронно present на всеки DomainEvent, после незабавно all_done.
func play_batch(sequence: int, events: Array) -> void:
	_playing = true
	_current_sequence = sequence
	if _binder != null:
		for entry in events:
			if entry is DomainEvent:
				_binder.present(entry as DomainEvent)
	_playing = false
	_current_sequence = -1
	all_done.emit(sequence)


func is_playing() -> bool:
	return _playing


func get_current_sequence() -> int:
	return _current_sequence
