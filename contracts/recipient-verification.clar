;; Recipient Verification Contract
;; This contract validates the eligibility of aid beneficiaries

(define-data-var admin principal tx-sender)

;; Data map to store verified recipients
(define-map verified-recipients principal
  {
    is-verified: bool,
    verification-date: uint,
    verification-expiry: uint,
    category: (string-utf8 20),
    needs-score: uint
  }
)

;; Error codes
(define-constant ERR_UNAUTHORIZED u1)
(define-constant ERR_ALREADY_VERIFIED u2)
(define-constant ERR_NOT_VERIFIED u3)
(define-constant ERR_EXPIRED_VERIFICATION u4)

;; Read-only function to check if a recipient is verified
(define-read-only (is-recipient-verified (recipient principal))
  (default-to false
    (get is-verified (map-get? verified-recipients recipient))
  )
)

;; Read-only function to get recipient details
(define-read-only (get-recipient-details (recipient principal))
  (map-get? verified-recipients recipient)
)

;; Function to verify a recipient
(define-public (verify-recipient
    (recipient principal)
    (category (string-utf8 20))
    (needs-score uint)
    (verification-period uint)
  )
  (let
    (
      (caller tx-sender)
      (current-time (unwrap-panic (get-block-info? time u0)))
      (expiry-time (+ current-time (* verification-period u86400))) ;; Convert days to seconds
    )

    ;; Check if caller is admin
    (asserts! (is-eq caller (var-get admin)) (err ERR_UNAUTHORIZED))

    ;; Check if recipient is already verified
    (asserts! (not (is-recipient-verified recipient)) (err ERR_ALREADY_VERIFIED))

    ;; Add recipient to verified map
    (map-set verified-recipients recipient
      {
        is-verified: true,
        verification-date: current-time,
        verification-expiry: expiry-time,
        category: category,
        needs-score: needs-score
      }
    )

    (ok true)
  )
)

;; Function to revoke verification
(define-public (revoke-verification (recipient principal))
  (let
    (
      (caller tx-sender)
    )

    ;; Check if caller is admin
    (asserts! (is-eq caller (var-get admin)) (err ERR_UNAUTHORIZED))

    ;; Check if recipient is verified
    (asserts! (is-recipient-verified recipient) (err ERR_NOT_VERIFIED))

    ;; Remove recipient from verified map
    (map-delete verified-recipients recipient)

    (ok true)
  )
)

;; Function to update admin
(define-public (set-admin (new-admin principal))
  (let
    (
      (caller tx-sender)
    )

    ;; Check if caller is current admin
    (asserts! (is-eq caller (var-get admin)) (err ERR_UNAUTHORIZED))

    ;; Update admin
    (var-set admin new-admin)

    (ok true)
  )
)

;; Function to check if verification is valid (not expired)
(define-read-only (is-verification-valid (recipient principal))
  (let
    (
      (recipient-data (map-get? verified-recipients recipient))
      (current-time (unwrap-panic (get-block-info? time u0)))
    )

    (if (is-none recipient-data)
      false
      (let
        (
          (is-verified (get is-verified (unwrap-panic recipient-data)))
          (expiry-time (get verification-expiry (unwrap-panic recipient-data)))
        )
        (and is-verified (<= current-time expiry-time))
      )
    )
  )
)

