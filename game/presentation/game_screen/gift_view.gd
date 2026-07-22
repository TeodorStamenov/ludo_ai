class_name GiftView
extends Node2D
## Визуализация на подарък върху дъската (docs/V1_ARCHITECTURE.md, раздел 6).
##
## Отговорности:
##   - слуша GiftSpawnedEvent → появява се на cell_id с анимация;
##   - слуша GiftCollectedEvent → анимира разкриване на power-up и изчезва;
##   - не знае съдържанието на подаръка преди GiftCollectedEvent;
##   - не пази gameplay state.
##
## Пълната имплементация е обхваната от задача "Създаване на GiftView".
