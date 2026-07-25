class_name DiceView
extends Node
## Визуализация на зара — само presentation (docs/V1_ARCHITECTURE.md, раздел 6.4).
##
## Отговорности:
##   - получава резултат от DiceRolledEvent (не го генерира сам);
##   - проиграва анимация, която завършва на точния резултат;
##   - уведомява GamePresenter при завършена анимация;
##   - debug бутони съществуват САМО в debug build — изпращат тестова команда
##     чрез разрешен debug adapter (не директно в логиката).
##
## Gameplay случайността е в SeededRandomSource в Domain слоя.
## Козметичните вариации (spin, wobble, jump) ползват PresentationRandomSource
## (docs/V1_ARCHITECTURE.md §4.5) — отделен RNG, който не влияе върху мача.
##
## Пълната имплементация е обхваната от задача
## "Рефакториране на текущия dice.gd до DiceView".


## Козметичен RNG — никога не се подава към GameEngine / MatchSession.
var cosmetic_rng: PresentationRandomSource = PresentationRandomSource.new()


## Задава presentation RNG (напр. от GamePresenter). Null → нов randomized instance.
func set_cosmetic_rng(rng: PresentationRandomSource) -> void:
	cosmetic_rng = rng if rng != null else PresentationRandomSource.new()
