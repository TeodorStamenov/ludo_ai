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
##
## Пълната имплементация е обхваната от задача
## "Рефакториране на текущия dice.gd до DiceView".
