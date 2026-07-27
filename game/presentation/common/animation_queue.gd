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
## Пълната имплементация е обхваната от задача
## "Създаване на AnimationQueue за последователно проиграване на събития".
