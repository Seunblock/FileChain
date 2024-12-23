;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_ALREADY_EXISTS (err u101))
(define-constant ERR_DOES_NOT_EXIST (err u102))
(define-constant ERR_INVALID_PAYMENT (err u103))
(define-constant ERR_EXPIRED_ACCESS (err u104))
(define-constant ERR_INVALID_PARAMS (err u105))

;; Data Variables
(define-data-var contract-owner principal tx-sender)
(define-data-var platform-fee uint u50) ;; 0.5% fee in basis points

;; Data Maps
(define-map file-registry
    { file-id: (string-ascii 64) }
    {
        owner: principal,
        hash: (string-ascii 64),
        price: uint,
        is-public: bool,
        created-at: uint,
        content-type: (string-ascii 10),
        description: (string-ascii 256)
    }
)

(define-map access-rights
    { file-id: (string-ascii 64), user: principal }
    {
        expiry: uint,
        access-type: (string-ascii 10), ;; "preview", "full", "commercial"
        payment-amount: uint,
        granted-by: principal,
        granted-at: uint
    }
)

(define-map revenue-sharing
    { file-id: (string-ascii 64) }
    {
        contributors: (list 5 principal),
        shares: (list 5 uint),  ;; In basis points (total should be 10000)
        total-revenue: uint
    }
)

(define-map user-stats
    { user: principal }
    {
        files-owned: uint,
        total-revenue: uint,
        total-paid: uint,
        last-activity: uint
    }
)

;; Private Functions
(define-private (calculate-platform-fee (amount uint))
    (/ (* amount (var-get platform-fee)) u10000)
)

(define-private (distribute-revenue (file-id (string-ascii 64)) (payment uint))
    (let (
        (revenue-info (unwrap! (map-get? revenue-sharing {file-id: file-id}) (ok payment)))
        (owner-share (- payment (calculate-platform-fee payment)))
        )
        (if (is-some (get contributors revenue-info))
            (begin
                ;; Distribute to contributors based on shares
                (map-set revenue-sharing
                    {file-id: file-id}
                    {
                        contributors: (get contributors revenue-info),
                        shares: (get shares revenue-info),
                        total-revenue: (+ payment (get total-revenue revenue-info))
                    }
                )
                (ok true))
            ;; If no contributors, all revenue goes to owner
            (ok true)
        )
    )
)

;; Public Functions

;; Register a new file
(define-public (register-file 
    (file-id (string-ascii 64))
    (file-hash (string-ascii 64))
    (price uint)
    (is-public bool)
    (content-type (string-ascii 10))
    (description (string-ascii 256)))
    (let
        ((caller tx-sender))
        (begin
            (asserts! (is-none (map-get? file-registry {file-id: file-id})) 
                ERR_ALREADY_EXISTS)
            (map-set file-registry
                {file-id: file-id}
                {
                    owner: caller,
                    hash: file-hash,
                    price: price,
                    is-public: is-public,
                    created-at: block-height,
                    content-type: content-type,
                    description: description
                }
            )
            (map-set user-stats 
                {user: caller}
                {
                    files-owned: (+ (default-to u0 (get files-owned (map-get? user-stats {user: caller}))) u1),
                    total-revenue: (default-to u0 (get total-revenue (map-get? user-stats {user: caller}))),
                    total-paid: (default-to u0 (get total-paid (map-get? user-stats {user: caller}))),
                    last-activity: block-height
                }
            )
            (ok true)
        )
    )
)

;; Grant access to a file
(define-public (grant-access
    (file-id (string-ascii 64))
    (user principal)
    (duration uint)
    (access-type (string-ascii 10)))
    (let
        ((file (unwrap! (map-get? file-registry {file-id: file-id}) ERR_DOES_NOT_EXIST))
         (caller tx-sender))
        (begin
            (asserts! (is-eq (get owner file) caller) ERR_NOT_AUTHORIZED)
            (map-set access-rights
                {file-id: file-id, user: user}
                {
                    expiry: (+ block-height duration),
                    access-type: access-type,
                    payment-amount: u0,
                    granted-by: caller,
                    granted-at: block-height
                }
            )
            (ok true)
        )
    )
)

;; Request paid access
(define-public (request-access
    (file-id (string-ascii 64))
    (access-type (string-ascii 10)))
    (let
        ((file (unwrap! (map-get? file-registry {file-id: file-id}) ERR_DOES_NOT_EXIST))
         (caller tx-sender)
         (payment (get price file)))
        (begin
            (asserts! (not (is-eq (get owner file) caller)) ERR_INVALID_PARAMS)
            ;; Process payment
            (try! (stx-transfer? payment caller (get owner file)))
            ;; Update user stats
            (map-set user-stats 
                {user: caller}
                {
                    files-owned: (default-to u0 (get files-owned (map-get? user-stats {user: caller}))),
                    total-revenue: (default-to u0 (get total-revenue (map-get? user-stats {user: caller}))),
                    total-paid: (+ (default-to u0 (get total-paid (map-get? user-stats {user: caller}))) payment),
                    last-activity: block-height
                }
            )
            ;; Distribute revenue
            (try! (distribute-revenue file-id payment))
            ;; Grant access
            (map-set access-rights
                {file-id: file-id, user: caller}
                {
                    expiry: (+ block-height u144), ;; 24-hour default access
                    access-type: access-type,
                    payment-amount: payment,
                    granted-by: (get owner file),
                    granted-at: block-height
                }
            )
            (ok true)
        )
    )
)

;; Set up revenue sharing
(define-public (set-revenue-sharing
    (file-id (string-ascii 64))
    (contributors (list 5 principal))
    (shares (list 5 uint)))
    (let
        ((file (unwrap! (map-get? file-registry {file-id: file-id}) ERR_DOES_NOT_EXIST))
         (caller tx-sender))
        (begin
            (asserts! (is-eq (get owner file) caller) ERR_NOT_AUTHORIZED)
            (asserts! (is-eq (fold + shares u0) u10000) ERR_INVALID_PARAMS)
            (map-set revenue-sharing
                {file-id: file-id}
                {
                    contributors: contributors,
                    shares: shares,
                    total-revenue: u0
                }
            )
            (ok true)
        )
    )
)

;; Read-only functions

;; Verify file access
(define-read-only (verify-access
    (file-id (string-ascii 64))
    (user principal))
    (let
        ((access-info (map-get? access-rights {file-id: file-id, user: user}))
         (file (unwrap! (map-get? file-registry {file-id: file-id}) ERR_DOES_NOT_EXIST)))
        (if (is-some access-info)
            (ok (< block-height (get expiry (unwrap! access-info ERR_DOES_NOT_EXIST))))
            (ok (get is-public file))
        )
    )
)

;; Get file details
(define-read-only (get-file-details (file-id (string-ascii 64)))
    (map-get? file-registry {file-id: file-id})
)

;; Get user stats
(define-read-only (get-user-stats (user principal))
    (map-get? user-stats {user: user})
)

;; Get revenue sharing info
(define-read-only (get-revenue-sharing (file-id (string-ascii 64)))
    (map-get? revenue-sharing {file-id: file-id})
)

;; Administrative functions

;; Update platform fee
(define-public (set-platform-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
        (asserts! (<= new-fee u1000) ERR_INVALID_PARAMS) ;; Max 10% fee
        (var-set platform-fee new-fee)
        (ok true)
    )
)

;; Transfer contract ownership
(define-public (transfer-ownership (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
        (var-set contract-owner new-owner)
        (ok true)
    )
)