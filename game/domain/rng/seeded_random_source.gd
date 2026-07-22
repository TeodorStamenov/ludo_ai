class_name SeededRandomSource
extends RandomSource
## Детерминиран RNG с начален seed (docs/V1_ARCHITECTURE.md, раздел 4.5).
##
## Еднакъв seed + еднакви команди = еднакво GameState и еднакви DomainEvent-и.
## Това е критичен инвариант за replay, debug и бъдещ authoritative сървър.
##
## Пълната имплементация е обхваната от задачи:
##   - "Създаване на SeededRandomSource имплементация"
##   - "Добавяне на export и restore на RNG state"
##   - "Създаване на тест за еднакви резултати при еднакъв seed"
