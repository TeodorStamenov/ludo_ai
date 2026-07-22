class_name GamePresenter
extends Node
## Мост между Application (MatchSession) и Presentation view слоя
## (docs/V1_ARCHITECTURE.md, раздел 6.1).
##
## Отговорности:
##   - слуша events_published(sequence, events) от MatchSession;
##   - предава батча към AnimationQueue;
##   - след AnimationQueue.all_done() извиква session.events_presented(sequence);
##   - преобразува ValidMovesChanged → подсветяване на пионки в BoardView;
##   - преобразува клик/tap върху пионка → MovePawnCommand → session.receive_command();
##   - преобразува клик върху зар → RollDiceCommand → session.receive_command();
##   - слуша awaiting_human_action — показва валидните ходове;
##   - слуша match_finished → AppFlow.navigate_to_results(summary).
##
## Не решава дали ход е валиден. Не мести пионки самостоятелно.
##
## Пълната имплементация е обхваната от задача "Създаване на GamePresenter".
