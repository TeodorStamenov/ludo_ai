class_name RollDiceCommand
extends GameCommand
## Заявка за хвърляне на зара от даден играч (docs/V1_ARCHITECTURE.md, раздел 4.3).
##
## Не носи резултат — GameEngine го генерира чрез инжектирания RandomSource.
## Валидно само в TurnState.AWAITING_ROLL за активния играч.
##
## Пълната имплементация е обхваната от задача "Създаване на RollDiceCommand".
