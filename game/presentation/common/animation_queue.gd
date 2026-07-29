class_name AnimationQueue
extends Node
## Проиграва DomainEvent-и последователно като анимации
## (docs/V1_ARCHITECTURE.md, раздел 6.1 / §4.4).
##
## GamePresenter получава батч events от MatchSession и ги поставя тук.
## AnimationQueue ги изпълнява един по един (#168 / #169):
##   1. Избира правилния view чрез EventViewBinder (#167).
##   2. Стартира анимацията (напр. DiceRolled → DiceView.present_dice_rolled).
##   3. Изчаква animation_finished(kind) чрез AnimationFinishedGate (#169).
##   4. Преминава към следващото събитие.
##   5. При изпразване емитира all_done(sequence).
##
## Instant/snap събития (HUD, highlights, още без tween) минават без изчакване.
## GamePresenter слуша all_done и извиква session.events_presented(sequence).
## Domain не чака tween — само Presentation го прави.

signal all_done(sequence: int)

var _playing: bool = false
var _current_sequence: int = -1
var _binder: EventViewBinder = null


func set_event_binder(binder: EventViewBinder) -> void:
	_binder = binder


func get_event_binder() -> EventViewBinder:
	return _binder


## Стартира батч за дадения command_sequence. Последователно await-ва
## present_for_playback (вкл. animation_finished потвърждение #169) за всеки
## DomainEvent, после емитира all_done.
## Повторно извикване докато is_playing() → игнорира се (session gate).
##
## ai_roll_delay_sec: пауза преди DiceRolledEvent playback (GamePresenter я
## подава само когато хвърлящият е AI — усеща се като "компютърът мисли",
## вместо зарът да падне мигновено след завършването на предходната анимация).
func play_batch(sequence: int, events: Array, ai_roll_delay_sec: float = 0.0) -> void:
	if _playing:
		push_warning(
				"AnimationQueue.play_batch: already playing sequence %d — ignored %d"
				% [_current_sequence, sequence]
		)
		return

	_playing = true
	_current_sequence = sequence

	if _binder != null and events != null:
		for entry in events:
			if entry is DomainEvent:
				if entry is DiceRolledEvent and ai_roll_delay_sec > 0.0:
					await get_tree().create_timer(ai_roll_delay_sec).timeout
				await _binder.present_for_playback(entry as DomainEvent)

	_playing = false
	_current_sequence = -1
	all_done.emit(sequence)


## Директно изчакване на view.animation_finished (#169) — за custom playback.
func wait_for_animation(view: Object, kind: StringName = &"") -> void:
	var gate := AnimationFinishedGate.new()
	gate.arm(view, kind)
	await gate.wait()


func is_playing() -> bool:
	return _playing


func get_current_sequence() -> int:
	return _current_sequence
