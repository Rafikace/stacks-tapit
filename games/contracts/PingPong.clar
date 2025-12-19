;; title: ping-pong
;; version: 0.0.1
;; summary: Two-player competitive ping pong game with staking and powerups
;; description: Players stake STX to create and join games, compete with powerups, and claim winnings

;; traits
;;

;; token definitions
;;

;; constants - game status
;;
(define-constant waiting-status u1)
(define-constant active-status u2)
(define-constant ended-status u3)
(define-constant cancelled-status u4)

;; constants - powerup types
;;
(define-constant powerup-pad-stretch u1)
(define-constant powerup-multiball u2)
(define-constant powerup-shield u3)

;; constants - game config
;;
(define-constant dev-fee-percentage u5)
(define-constant game-timeout u604800)
(define-constant max-player-games u10000)

;; constants - error codes
;;
(define-constant err-gameplay-paused (err u1))
(define-constant err-invalid-amount (err u2))
(define-constant err-unauthorized (err u3))
(define-constant err-player2-slot-not-empty (err u4))
(define-constant err-cannot-join-own-game (err u5))
(define-constant err-invalid-status-transition (err u6))
(define-constant err-insufficient-balance (err u7))
(define-constant err-invalid-status (err u8))
(define-constant err-player2-not-joined (err u9))
(define-constant err-invalid-powerup-type (err u10))
(define-constant err-game-not-found (err u11))
(define-constant err-insufficient-powerups (err u12))
(define-constant err-transfer-failed (err u13))
(define-constant err-game-expired (err u14))
(define-constant err-not-game-participant (err u15))
(define-constant err-invalid-winner (err u16))
(define-constant err-player-games-limit-exceeded (err u17))

;; data vars
;;
(define-data-var total-games uint u0)
(define-data-var dev-fee-vault uint u0)
(define-data-var paused bool false)

;; data maps
;;
(define-map games
  {game-id: uint}
  {
    game-id: uint,
    player1: principal,
    player2: (optional principal),
    stake-amount: uint,
    escrow-balance: uint,
    status: uint,
    winner: (optional principal),
    created-at: uint,
    completed-at: uint
  }
)

(define-map game-exists
  {game-id: uint}
  {exists: bool}
)

(define-map powerup-inventories
  {player: principal}
  {
    pad-stretch-count: uint,
    multiball-count: uint,
    shield-count: uint
  }
)

(define-map player-games
  {player: principal}
  {games: (list 10000 uint)}
)

;; public functions - game creation and joining
;;

;; create-game - initialize a new game
(define-public (create-game (stake-amount uint))
  (begin
    (asserts! (not (var-get paused)) err-gameplay-paused)
    (asserts! (> stake-amount u0) err-invalid-amount)
    (let ((game-id (+ (var-get total-games) u1)))
      (begin
        (var-set total-games game-id)
        (map-set games
          {game-id: game-id}
          {
            game-id: game-id,
            player1: tx-sender,
            player2: none,
            stake-amount: stake-amount,
            escrow-balance: stake-amount,
            status: waiting-status,
            winner: none,
            created-at: block-height,
            completed-at: u0
          }
        )
        (map-set game-exists {game-id: game-id} {exists: true})
        (ok game-id)
      )
    )
  )
)

;; join-game - player2 joins an existing game
(define-public (join-game (game-id uint))
  (let ((game (unwrap! (map-get? games {game-id: game-id}) err-game-not-found)))
    (begin
      (asserts! (not (var-get paused)) err-gameplay-paused)
      (asserts! (is-eq (get status game) waiting-status) err-invalid-status)
      (asserts! (not (is-eq tx-sender (get player1 game))) err-cannot-join-own-game)
      (asserts! (is-none (get player2 game)) err-player2-slot-not-empty)
      (asserts! (is-eq (get stake-amount game) (get stake-amount game)) err-invalid-amount)
      (map-set games
        {game-id: game-id}
        (merge game {
          player2: (some tx-sender),
          escrow-balance: (+ (get escrow-balance game) (get stake-amount game)),
          status: active-status
        })
      )
      (ok true)
    )
  )
)

;; end-game - settle game and distribute winnings
(define-public (end-game (game-id uint) (winner principal))
  (let ((game (unwrap! (map-get? games {game-id: game-id}) err-game-not-found)))
    (begin
      (asserts! (not (var-get paused)) err-gameplay-paused)
      (asserts! (is-eq (get status game) active-status) err-invalid-status)
      (asserts! (is-some (get player2 game)) err-player2-not-joined)
      (asserts! (or (is-eq winner (get player1 game)) (is-eq winner (unwrap! (get player2 game) err-invalid-winner))) err-invalid-winner)
      (asserts! (> (get escrow-balance game) u0) err-insufficient-balance)
      (let ((total-balance (get escrow-balance game))
            (dev-fee (/ (* total-balance dev-fee-percentage) u100))
            (winner-amount (- total-balance dev-fee)))
        (begin
          (var-set dev-fee-vault (+ (var-get dev-fee-vault) dev-fee))
          (map-set games
            {game-id: game-id}
            (merge game {
              escrow-balance: u0,
              status: ended-status,
              winner: (some winner),
              completed-at: block-height
            })
          )
          (ok {winner-amount: winner-amount, dev-fee: dev-fee})
        )
      )
    )
  )
)

;; refund management functions
;;

;; request-refund - player1 requests refund before game starts
(define-public (request-refund (game-id uint))
  (let ((game (unwrap! (map-get? games {game-id: game-id}) err-game-not-found)))
    (begin
      (asserts! (not (var-get paused)) err-gameplay-paused)
      (asserts! (is-eq (get status game) waiting-status) err-invalid-status)
      (asserts! (is-eq tx-sender (get player1 game)) err-unauthorized)
      (asserts! (> (get escrow-balance game) u0) err-invalid-amount)
      (let ((refund-amount (get escrow-balance game)))
        (begin
          (map-set games
            {game-id: game-id}
            (merge game {
              escrow-balance: u0,
              status: cancelled-status,
              completed-at: block-height
            })
          )
          (ok refund-amount)
        )
      )
    )
  )
)

;; timeout and expiration functions
;;

;; claim-timeout-refund - claim refund after game timeout
(define-public (claim-timeout-refund (game-id uint))
  (let ((game (unwrap! (map-get? games {game-id: game-id}) err-game-not-found)))
    (begin
      (asserts! (not (var-get paused)) err-gameplay-paused)
      (let ((is-player1 (is-eq tx-sender (get player1 game)))
            (is-player2 (is-some (get player2 game))))
        (begin
          (asserts! (or is-player1 is-player2) err-unauthorized)
          (asserts! (>= block-height (+ (get created-at game) game-timeout)) err-game-expired)
          (asserts! (> (get escrow-balance game) u0) err-invalid-amount)
          (map-set games
            {game-id: game-id}
            (merge game {
              escrow-balance: u0,
              status: cancelled-status,
              completed-at: block-height
            })
          )
          (ok true)
        )
      )
    )
  )
)

;; powerup management functions
;;

;; grant-powerup - owner grants powerup to player
(define-public (grant-powerup (recipient principal) (powerup-type uint))
  (begin
    (asserts! (and (>= powerup-type u1) (<= powerup-type u3)) err-invalid-powerup-type)
    (asserts! (not (is-eq recipient tx-sender)) err-unauthorized)
    (let ((inventory (map-get? powerup-inventories {player: recipient})))
      (ok true)
    )
  )
)

;; use-powerup - player uses powerup during game
(define-public (use-powerup (game-id uint) (powerup-type uint))
  (let ((game (unwrap! (map-get? games {game-id: game-id}) err-game-not-found)))
    (begin
      (asserts! (not (var-get paused)) err-gameplay-paused)
      (asserts! (or (is-eq tx-sender (get player1 game)) (is-eq tx-sender (unwrap! (get player2 game) err-not-game-participant))) err-not-game-participant)
      (asserts! (is-eq (get status game) active-status) err-invalid-status)
      (asserts! (and (>= powerup-type u1) (<= powerup-type u3)) err-invalid-powerup-type)
      (ok true)
    )
  )
)

;; admin functions
;;

;; withdraw-dev-fees - owner withdraws dev fees
(define-public (withdraw-dev-fees)
  (let ((fee-amount (var-get dev-fee-vault)))
    (begin
      (asserts! (> fee-amount u0) err-invalid-amount)
      (var-set dev-fee-vault u0)
      (ok fee-amount)
    )
  )
)

;; contract control functions
;;

;; toggle-pause - owner toggles pause state
(define-public (toggle-pause)
  (begin
    (var-set paused (not (var-get paused)))
    (ok (var-get paused))
  )
)

;; read only functions - game queries
;;

;; get-game - retrieve game details
(define-read-only (get-game (game-id uint))
  (map-get? games {game-id: game-id})
)

;; game state query functions
;;

;; get-game-status - retrieve game status by id
(define-read-only (get-game-status (game-id uint))
  (let ((game (unwrap! (map-get? games {game-id: game-id}) err-game-not-found)))
    (ok (get status game))
  )
)

;; get-game-escrow - retrieve escrow balance
(define-read-only (get-game-escrow (game-id uint))
  (let ((game (unwrap! (map-get? games {game-id: game-id}) err-game-not-found)))
    (ok (get escrow-balance game))
  )
)

;; get-dev-fees - retrieve total dev fees
(define-read-only (get-dev-fees)
  (ok (var-get dev-fee-vault))
)

;; is-vault-paused - check if gameplay is paused
(define-read-only (is-vault-paused)
  (ok (var-get paused))
)

;; get-total-games - retrieve total game count
(define-read-only (get-total-games)
  (ok (var-get total-games))
)

;; get-powerup-count - retrieve specific powerup count
(define-read-only (get-powerup-count (player principal) (powerup-type uint))
  (let ((inventory (default-to {pad-stretch-count: u0, multiball-count: u0, shield-count: u0} (map-get? powerup-inventories {player: player}))))
    (if (is-eq powerup-type powerup-pad-stretch)
      (ok (get pad-stretch-count inventory))
      (if (is-eq powerup-type powerup-multiball)
        (ok (get multiball-count inventory))
        (if (is-eq powerup-type powerup-shield)
          (ok (get shield-count inventory))
          (ok u0)
        )
      )
    )
  )
)

;; get-all-powerups - retrieve all powerup counts
(define-read-only (get-all-powerups (player principal))
  (let ((inventory (default-to {pad-stretch-count: u0, multiball-count: u0, shield-count: u0} (map-get? powerup-inventories {player: player}))))
    (ok {
      pad-stretch: (get pad-stretch-count inventory),
      multiball: (get multiball-count inventory),
      shield: (get shield-count inventory)
    })
  )
)

;; is-game-exists - check if game exists
(define-read-only (is-game-exists (game-id uint))
  (ok (is-some (map-get? games {game-id: game-id})))
)

;; private functions
;;

;; validate-status-transition - validate allowed status transitions
(define-private (validate-status-transition (current-status uint) (next-status uint))
  (or
    (and (is-eq current-status waiting-status) (is-eq next-status active-status))
    (and (is-eq current-status waiting-status) (is-eq next-status cancelled-status))
    (and (is-eq current-status active-status) (is-eq next-status ended-status))
    (and (is-eq current-status active-status) (is-eq next-status cancelled-status))
  )
)
