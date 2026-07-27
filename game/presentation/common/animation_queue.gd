class_name AnimationQueue
extends Node
## Проиграва DomainEvent-и последователно като анимации
## (docs/V1_ARCHITECTURE.md, раздел 6.1).
##
## GamePresenter получава батч events от MatchSession и ги поставя тук.
## AnimationQueue ги изпълнява един по един:
##   1. Избира правилния view (BoardView, PawnView, DiceView, GiftView).
##   2. Стартира анимацията (напр. DiceRolled → DiceView.present_dice_rolled).
##   3. Изчаква сигнал animation_finished.
##   4. Преминава към следващото събитие.
##   5. При изпразване емитира all_done(sequence).
##
## GamePresenter слуша all_done и извиква session.events_presented(sequence).
## Domain не чака tween — само Presentation го прави.
##
## MVP (#165): play_batch завършва синхронно (instant gate) — същият договор
## като MatchSimulator. Последователните анимации са задача #168 / #169.

signal all_done(sequence: int)

var _playing: bool = false
var _current_sequence: int = -1


## Стартира батч за дадения command_sequence. MVP: незабавно all_done.
## Пълното последователно проиграване е #168.
func play_batch(sequence: int, _events: Array) -> void:
	_playing = true
	_current_sequence = sequence
	_playing = false
	_current_sequence = -1
	all_done.emit(sequence)


func is_playing() -> bool:
	return _playing


func get_current_sequence() -> int:
	return _current_sequence
