class_name DomainEvent
extends RefCounted
## Базов клас за всички domain събития (docs/V1_ARCHITECTURE.md, раздел 4.4).
##
## Събитията описват вече настъпили факти (минало свършено време).
## Едно движение може да произведе няколко в ред, напр.:
##   PawnMoved → GiftCollected → PowerUpResolved → PawnMoved → TurnChanged
##
## Presentation ги проиграва последователно чрез AnimationQueue.
## Statistics/save ги наблюдават, без да дублират правилата.
##
## Пълен списък на имплементациите:
##   MatchStarted, DiceRolled, ValidMovesChanged, PawnMoved,
##   PawnExitedBase, PawnCaptured, PawnSentHome, PawnStackFormed,
##   PawnFinished, GiftSpawned, GiftCollected, PowerUpResolved,
##   ShieldApplied, TurnChanged, PlayerRanked, MatchFinished

var event_type: StringName = &""
var command_sequence: int = 0
