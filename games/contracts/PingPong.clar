;; title: ping-pong
;; version: 0.0.1
;; summary: Two-player competitive ping pong game with staking and powerups
;; description: Players stake STX to create and join games, compete with powerups, and claim winnings

;; traits
;;

;; token definitions
;;

;; constants
;;
(define-constant waiting-status u1)

(define-constant active-status u2)

(define-constant ended-status u3)

(define-constant cancelled-status u4)

(define-constant powerup-pad-stretch u1)

(define-constant powerup-multiball u2)

(define-constant powerup-shield u3)

(define-constant dev-fee-percentage u5)

(define-constant game-timeout u604800)

(define-constant max-player-games u10000)

(define-constant err-gameplay-paused (err u1))
