;; title: thrift-pool-manager
;; version: 0.0.1
;; summary: Decentralized thrift pool management system with group staking
;; description: Manages thrift groups where members can stake STX and participate in collective pools

;; traits
;;

;; token definitions
;;

;; constants
;;
(define-constant contract-version "0.0.1")

(define-constant min-stake-amount u10000000)

(define-constant err-invalid-group (err u1))

(define-constant err-insufficient-stake (err u2))

(define-constant err-group-not-active (err u3))

(define-constant err-member-not-found (err u4))

(define-constant err-unauthorized (err u5))

(define-constant err-invalid-stake-amount (err u6))

(define-constant err-duplicate-member (err u7))

(define-constant err-history-not-found (err u8))

;; data vars
;;
(define-data-var group-counter uint u0)
(define-data-var total-stake-pool uint u0)
(define-data-var total-members uint u0)

;; data maps
;;

(define-map thrift-groups
  {group-id: uint}
  {
    members: (list 1000 principal),
    total-staked: uint,
    created-at: uint,
    is-active: bool
  }
)

(define-map member-history
  {member: principal}
  {
    name: (string-utf8 256),
    join-dates: (list 100 uint),
    total-stakes: (list 100 uint)
  }
)

;; public functions
;;
(define-public (create-group)
  (let ((new-group-id (+ (var-get group-counter) u1)))
    (begin
      (var-set group-counter new-group-id)
      (var-set total-members (+ (var-get total-members) u1))
      (map-set thrift-groups
        {group-id: new-group-id}
        {
          members: (list),
          total-staked: u0,
          created-at: block-height,
          is-active: true
        }
      )
      (ok new-group-id)
    )
  )
)

(define-public (join-group (group-id uint) (stake-amount uint))
  (let ((group (unwrap! (map-get? thrift-groups {group-id: group-id}) err-invalid-group)))
    (begin
      (asserts! (>= stake-amount min-stake-amount) err-insufficient-stake)
      (asserts! (get is-active group) err-group-not-active)
      (match (stx-transfer? stake-amount tx-sender (as-contract tx-sender))
        success (begin
          (var-set total-stake-pool (+ (var-get total-stake-pool) stake-amount))
          (map-set thrift-groups
            {group-id: group-id}
            (merge group {
              members: (unwrap! (as-max-len? (append (get members group) tx-sender) u1000) err-invalid-group),
              total-staked: (+ (get total-staked group) stake-amount)
            })
          )
          (ok true)
        )
        error (err error)
      )
    )
  )
)

(define-public (add-member (group-id uint) (member-name (string-utf8 256)))
  (let ((group (unwrap! (map-get? thrift-groups {group-id: group-id}) err-invalid-group)))
    (begin
      (asserts! (get is-active group) err-group-not-active)
      (var-set total-members (+ (var-get total-members) u1))
      (map-set member-history
        {member: tx-sender}
        {
          name: member-name,
          join-dates: (list block-height),
          total-stakes: (list u0)
        }
      )
      (ok true)
    )
  )
)

(define-public (remove-member (group-id uint) (member-address principal))
  (let ((group (unwrap! (map-get? thrift-groups {group-id: group-id}) err-invalid-group)))
    (begin
      (asserts! (get is-active group) err-group-not-active)
      (map-set thrift-groups
        {group-id: group-id}
        (merge group {
          members: (filter (lambda (x) (not (is-eq x member-address))) (get members group))
        })
      )
      (var-set total-members (if (> (var-get total-members) u0) (- (var-get total-members) u1) u0))
      (ok true)
    )
  )
)

(define-public (show-member-history)
  (let ((history (map-get? member-history {member: tx-sender})))
    (match history
      h (ok {name: (get name h), join-dates: (get join-dates h), total-stakes: (get total-stakes h)})
      (err err-history-not-found)
    )
  )
)

(define-public (withdraw-from-group (group-id uint) (withdrawal-amount uint))
  (let ((group (unwrap! (map-get? thrift-groups {group-id: group-id}) err-invalid-group)))
    (begin
      (asserts! (get is-active group) err-group-not-active)
      (match (stx-transfer? withdrawal-amount (as-contract tx-sender) tx-sender)
        success (begin
          (var-set total-stake-pool (if (>= (var-get total-stake-pool) withdrawal-amount) (- (var-get total-stake-pool) withdrawal-amount) u0))
          (map-set thrift-groups
            {group-id: group-id}
            (merge group {
              total-staked: (if (>= (get total-staked group) withdrawal-amount) (- (get total-staked group) withdrawal-amount) u0)
            })
          )
          (ok true)
        )
        error (err error)
      )
    )
  )
)

;; read only functions
;;
(define-read-only (get-group-details (group-id uint))
  (let ((group (unwrap! (map-get? thrift-groups {group-id: group-id}) err-invalid-group)))
    (ok {
      members: (get members group),
      total-staked: (get total-staked group),
      created-at: (get created-at group),
      is-active: (get is-active group)
    })
  )
)

(define-read-only (get-total-groups)
  (ok (var-get group-counter))
)

(define-read-only (get-group-member-count (group-id uint))
  (let ((group (unwrap! (map-get? thrift-groups {group-id: group-id}) err-invalid-group)))
    (ok (len (get members group)))
  )
)
(define-read-only (is-member-in-group (group-id uint) (member principal))
  (let ((group (unwrap! (map-get? thrift-groups {group-id: group-id}) err-invalid-group)))
    (ok (is-some (index-of? (get members group) member)))
  )
)(define-read-only (get-total-stake-pool)
  (ok (var-get total-stake-pool))
)

(define-read-only (get-total-members)
  (ok (var-get total-members))
)

;; additional read-only functions for member queries
;;
(define-read-only (get-group-members (group-id uint))
  (let ((group (unwrap! (map-get? thrift-groups {group-id: group-id}) err-invalid-group)))
    (ok (get members group))
  )
)
(define-read-only (get-group-creation-date (group-id uint))
  (let ((group (unwrap! (map-get? thrift-groups {group-id: group-id}) err-invalid-group)))
    (ok (get created-at group))
  )
)

(define-read-only (is-group-active (group-id uint))
  (let ((group (unwrap! (map-get? thrift-groups {group-id: group-id}) err-invalid-group)))
    (ok (get is-active group))
  )
)

(define-read-only (check-group-exists (group-id uint))
  (ok (is-some (map-get? thrift-groups {group-id: group-id})))
)

(define-read-only (validate-stake-amount (amount uint))
  (ok (>= amount min-stake-amount))
)
