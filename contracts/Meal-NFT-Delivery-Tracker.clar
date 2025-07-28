(define-non-fungible-token meal-nft uint)

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NFT-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-CLAIMED (err u102))
(define-constant ERR-INVALID-STATUS (err u103))
(define-constant ERR-MEAL-EXPIRED (err u104))
(define-constant ERR-NOT-RESTAURANT (err u105))
(define-constant ERR-NOT-DELIVERY-PERSON (err u106))
(define-constant ERR-INVALID-RECIPIENT (err u107))
(define-constant ERR-MEAL-NOT-READY (err u108))

(define-constant MEAL-STATUS-ORDERED u0)
(define-constant MEAL-STATUS-PREPARING u1)
(define-constant MEAL-STATUS-READY u2)
(define-constant MEAL-STATUS-OUT-FOR-DELIVERY u3)
(define-constant MEAL-STATUS-DELIVERED u4)

(define-constant FRESHNESS-WINDOW u144)

(define-data-var nft-counter uint u0)
(define-data-var contract-owner principal tx-sender)

(define-map meals uint {
    customer: principal,
    restaurant: principal,
    delivery-person: (optional principal),
    meal-name: (string-ascii 50),
    order-time: uint,
    prep-time: (optional uint),
    ready-time: (optional uint),
    pickup-time: (optional uint),
    delivery-time: (optional uint),
    status: uint,
    freshness-guarantee: uint,
    price: uint
})

(define-map restaurants principal {
    name: (string-ascii 100),
    active: bool,
    total-orders: uint
})

(define-map delivery-persons principal {
    name: (string-ascii 50),
    active: bool,
    current-deliveries: uint,
    total-deliveries: uint
})

(define-map customer-orders principal (list 50 uint))

(define-public (register-restaurant (name (string-ascii 100)))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (ok (map-set restaurants tx-sender {
            name: name,
            active: true,
            total-orders: u0
        }))
    )
)

(define-public (register-delivery-person (name (string-ascii 50)))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (ok (map-set delivery-persons tx-sender {
            name: name,
            active: true,
            current-deliveries: u0,
            total-deliveries: u0
        }))
    )
)

(define-public (place-order (restaurant principal) (meal-name (string-ascii 50)) (price uint) (freshness-guarantee uint))
    (let (
        (nft-id (+ (var-get nft-counter) u1))
        (current-orders (default-to (list) (map-get? customer-orders tx-sender)))
    )
        (asserts! (is-some (map-get? restaurants restaurant)) ERR-NOT-RESTAURANT)
        (try! (nft-mint? meal-nft nft-id tx-sender))
        (map-set meals nft-id {
            customer: tx-sender,
            restaurant: restaurant,
            delivery-person: none,
            meal-name: meal-name,
            order-time: stacks-block-height,
            prep-time: none,
            ready-time: none,
            pickup-time: none,
            delivery-time: none,
            status: MEAL-STATUS-ORDERED,
            freshness-guarantee: freshness-guarantee,
            price: price
        })
        (map-set customer-orders tx-sender (unwrap! (as-max-len? (append current-orders nft-id) u50) ERR-INVALID-RECIPIENT))
        (var-set nft-counter nft-id)
        (ok nft-id)
    )
)

(define-public (start-preparation (nft-id uint))
    (let (
        (meal-data (unwrap! (map-get? meals nft-id) ERR-NFT-NOT-FOUND))
        (restaurant-data (unwrap! (map-get? restaurants tx-sender) ERR-NOT-RESTAURANT))
    )
        (asserts! (is-eq tx-sender (get restaurant meal-data)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status meal-data) MEAL-STATUS-ORDERED) ERR-INVALID-STATUS)
        (map-set meals nft-id (merge meal-data {
            status: MEAL-STATUS-PREPARING,
            prep-time: (some stacks-block-height)
        }))
        (map-set restaurants tx-sender (merge restaurant-data {
            total-orders: (+ (get total-orders restaurant-data) u1)
        }))
        (ok true)
    )
)

(define-public (mark-ready (nft-id uint))
    (let (
        (meal-data (unwrap! (map-get? meals nft-id) ERR-NFT-NOT-FOUND))
    )
        (asserts! (is-eq tx-sender (get restaurant meal-data)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status meal-data) MEAL-STATUS-PREPARING) ERR-INVALID-STATUS)
        (map-set meals nft-id (merge meal-data {
            status: MEAL-STATUS-READY,
            ready-time: (some stacks-block-height)
        }))
        (ok true)
    )
)

(define-public (assign-delivery (nft-id uint) (delivery-person principal))
    (let (
        (meal-data (unwrap! (map-get? meals nft-id) ERR-NFT-NOT-FOUND))
        (delivery-data (unwrap! (map-get? delivery-persons delivery-person) ERR-NOT-DELIVERY-PERSON))
    )
        (asserts! (is-eq tx-sender (get restaurant meal-data)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status meal-data) MEAL-STATUS-READY) ERR-INVALID-STATUS)
        (asserts! (get active delivery-data) ERR-NOT-DELIVERY-PERSON)
        (map-set meals nft-id (merge meal-data {
            delivery-person: (some delivery-person)
        }))
        (map-set delivery-persons delivery-person (merge delivery-data {
            current-deliveries: (+ (get current-deliveries delivery-data) u1)
        }))
        (ok true)
    )
)

(define-public (pickup-meal (nft-id uint))
    (let (
        (meal-data (unwrap! (map-get? meals nft-id) ERR-NFT-NOT-FOUND))
        (delivery-data (unwrap! (map-get? delivery-persons tx-sender) ERR-NOT-DELIVERY-PERSON))
    )
        (asserts! (is-eq tx-sender (unwrap! (get delivery-person meal-data) ERR-NOT-AUTHORIZED)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status meal-data) MEAL-STATUS-READY) ERR-INVALID-STATUS)
        (asserts! (check-freshness nft-id) ERR-MEAL-EXPIRED)
        (map-set meals nft-id (merge meal-data {
            status: MEAL-STATUS-OUT-FOR-DELIVERY,
            pickup-time: (some stacks-block-height)
        }))
        (ok true)
    )
)

(define-public (deliver-meal (nft-id uint))
    (let (
        (meal-data (unwrap! (map-get? meals nft-id) ERR-NFT-NOT-FOUND))
        (delivery-data (unwrap! (map-get? delivery-persons tx-sender) ERR-NOT-DELIVERY-PERSON))
    )
        (asserts! (is-eq tx-sender (unwrap! (get delivery-person meal-data) ERR-NOT-AUTHORIZED)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status meal-data) MEAL-STATUS-OUT-FOR-DELIVERY) ERR-INVALID-STATUS)
        (asserts! (check-freshness nft-id) ERR-MEAL-EXPIRED)
        (map-set meals nft-id (merge meal-data {
            status: MEAL-STATUS-DELIVERED,
            delivery-time: (some stacks-block-height)
        }))
        (map-set delivery-persons tx-sender (merge delivery-data {
            current-deliveries: (- (get current-deliveries delivery-data) u1),
            total-deliveries: (+ (get total-deliveries delivery-data) u1)
        }))
        (ok true)
    )
)

(define-public (claim-meal (nft-id uint))
    (let (
        (meal-data (unwrap! (map-get? meals nft-id) ERR-NFT-NOT-FOUND))
    )
        (asserts! (is-eq tx-sender (get customer meal-data)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status meal-data) MEAL-STATUS-DELIVERED) ERR-INVALID-STATUS)
        (asserts! (check-freshness nft-id) ERR-MEAL-EXPIRED)
        (ok true)
    )
)

(define-read-only (get-meal-info (nft-id uint))
    (map-get? meals nft-id)
)

(define-read-only (get-restaurant-info (restaurant principal))
    (map-get? restaurants restaurant)
)

(define-read-only (get-delivery-person-info (delivery-person principal))
    (map-get? delivery-persons delivery-person)
)

(define-read-only (get-customer-orders (customer principal))
    (default-to (list) (map-get? customer-orders customer))
)

(define-read-only (check-freshness (nft-id uint))
    (match (map-get? meals nft-id)
        meal-data (let (
            (current-block stacks-block-height)
            (guarantee-blocks (get freshness-guarantee meal-data))
            (order-block (get order-time meal-data))
        )
            (<= current-block (+ order-block guarantee-blocks))
        )
        false
    )
)

(define-read-only (get-meal-status (nft-id uint))
    (match (map-get? meals nft-id)
        meal-data (get status meal-data)
        u999
    )
)

(define-read-only (get-delivery-time-estimate (nft-id uint))
    (match (map-get? meals nft-id)
        meal-data (let (
            (status (get status meal-data))
            (order-time (get order-time meal-data))
            (current-time stacks-block-height)
        )
            (if (is-eq status MEAL-STATUS-ORDERED)
                (some (+ current-time u50))
                (if (is-eq status MEAL-STATUS-PREPARING)
                    (some (+ current-time u30))
                    (if (is-eq status MEAL-STATUS-READY)
                        (some (+ current-time u20))
                        (if (is-eq status MEAL-STATUS-OUT-FOR-DELIVERY)
                            (some (+ current-time u10))
                            none
                        )
                    )
                )
            )
        )
        none
    )
)

(define-read-only (get-nft-owner (nft-id uint))
    (nft-get-owner? meal-nft nft-id)
)

(define-read-only (get-last-token-id)
    (ok (var-get nft-counter))
)

(define-read-only (get-contract-owner)
    (ok (var-get contract-owner))
)
