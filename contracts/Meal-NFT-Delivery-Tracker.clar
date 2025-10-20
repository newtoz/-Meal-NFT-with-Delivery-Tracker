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
(define-constant ERR-INSUFFICIENT-POINTS (err u109))
(define-constant ERR-INVALID-REDEMPTION (err u110))
(define-constant ERR-ALREADY-REDEEMED (err u111))

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

(define-map loyalty-points principal {
    points: uint,
    total-spent: uint,
    total-orders: uint,
    last-earned-at: uint
})

(define-map redemption-records uint {
    customer: principal,
    points-used: uint,
    discount-applied: uint,
    redeemed: bool
})

(define-constant POINTS-PER-ORDER u10)
(define-constant POINTS-PER-100-STX u5)
(define-constant MAX-DISCOUNT-PCT u20)
(define-constant DISCOUNT-DIVISOR u100)

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
        (unwrap! (award-loyalty-points (get customer meal-data) (get price meal-data)) (ok true))
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

(define-private (award-loyalty-points (customer principal) (order-amount uint))
    (let (
        (current-loyalty (default-to 
            { points: u0, total-spent: u0, total-orders: u0, last-earned-at: u0 }
            (map-get? loyalty-points customer)
        ))
        (base-points POINTS-PER-ORDER)
        (spending-points (/ (* order-amount POINTS-PER-100-STX) u100000000))
        (total-points (+ base-points spending-points))
    )
        (map-set loyalty-points customer {
            points: (+ (get points current-loyalty) total-points),
            total-spent: (+ (get total-spent current-loyalty) order-amount),
            total-orders: (+ (get total-orders current-loyalty) u1),
            last-earned-at: stacks-block-height
        })
        (ok total-points)
    )
)

(define-read-only (get-loyalty-points (customer principal))
    (map-get? loyalty-points customer)
)

(define-read-only (calculate-discount (customer principal) (points-to-use uint))
    (let (
        (customer-loyalty (map-get? loyalty-points customer))
    )
        (match customer-loyalty
            some-loyalty (let (
                (available-points (get points some-loyalty))
                (discount-percentage (if (<= (/ points-to-use u10) MAX-DISCOUNT-PCT) 
                                        (/ points-to-use u10) 
                                        MAX-DISCOUNT-PCT))
            )
                (if (>= available-points points-to-use)
                    (ok discount-percentage)
                    ERR-INSUFFICIENT-POINTS
                )
            )
            ERR-INSUFFICIENT-POINTS
        )
    )
)

(define-public (place-order-with-loyalty (restaurant principal) (meal-name (string-ascii 50)) (price uint) (freshness-guarantee uint) (points-to-use uint))
    (let (
        (nft-id (+ (var-get nft-counter) u1))
        (current-orders (default-to (list) (map-get? customer-orders tx-sender)))
        (discount-pct (try! (calculate-discount tx-sender points-to-use)))
        (discount-amount (/ (* price discount-pct) DISCOUNT-DIVISOR))
        (final-price (- price discount-amount))
        (customer-loyalty (unwrap! (map-get? loyalty-points tx-sender) ERR-INSUFFICIENT-POINTS))
    )
        (asserts! (is-some (map-get? restaurants restaurant)) ERR-NOT-RESTAURANT)
        (asserts! (>= (get points customer-loyalty) points-to-use) ERR-INSUFFICIENT-POINTS)
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
            price: final-price
        })
        
        (map-set redemption-records nft-id {
            customer: tx-sender,
            points-used: points-to-use,
            discount-applied: discount-amount,
            redeemed: true
        })
        
        (map-set loyalty-points tx-sender (merge customer-loyalty {
            points: (- (get points customer-loyalty) points-to-use)
        }))
        
        (map-set customer-orders tx-sender (unwrap! (as-max-len? (append current-orders nft-id) u50) ERR-INVALID-RECIPIENT))
        (var-set nft-counter nft-id)
        (ok nft-id)
    )
)

(define-read-only (get-redemption-info (nft-id uint))
    (map-get? redemption-records nft-id)
)

(define-read-only (get-customer-loyalty-stats (customer principal))
    (let (
        (loyalty-data (map-get? loyalty-points customer))
    )
        (match loyalty-data
            some-data (ok {
                available-points: (get points some-data),
                total-spent: (get total-spent some-data),
                total-orders: (get total-orders some-data),
                potential-discount: (if (<= (/ (get points some-data) u10) MAX-DISCOUNT-PCT)
                                      (/ (get points some-data) u10)
                                      MAX-DISCOUNT-PCT)
            })
            (ok { available-points: u0, total-spent: u0, total-orders: u0, potential-discount: u0 })
        )
    )
)

(define-constant ERR-INVALID-RATING (err u112))
(define-constant ERR-NO-DELIVERY-PERSON (err u113))
(define-constant ERR-ALREADY-RATED (err u114))

(define-constant MIN-RATING u1)
(define-constant MAX-RATING u5)

(define-map delivery-feedback uint {
    rater: principal,
    score: uint
})

(define-map restaurant-rating-stats principal {
    total-score: uint,
    count: uint
})

(define-map delivery-rating-stats principal {
    total-score: uint,
    count: uint
})

(define-public (rate-delivery (nft-id uint) (score uint))
    (let (
        (meal-data (unwrap! (map-get? meals nft-id) ERR-NFT-NOT-FOUND))
        (maybe-driver (get delivery-person meal-data))
        (driver (unwrap! maybe-driver ERR-NO-DELIVERY-PERSON))
        (current-restaurant (get restaurant meal-data))
        (existing (map-get? delivery-feedback nft-id))
        (rest-stats (default-to { total-score: u0, count: u0 } (map-get? restaurant-rating-stats current-restaurant)))
        (drv-stats (default-to { total-score: u0, count: u0 } (map-get? delivery-rating-stats driver)))
    )
        (asserts! (is-eq tx-sender (get customer meal-data)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status meal-data) MEAL-STATUS-DELIVERED) ERR-INVALID-STATUS)
        (asserts! (and (>= score MIN-RATING) (<= score MAX-RATING)) ERR-INVALID-RATING)
        (asserts! (is-none existing) ERR-ALREADY-RATED)
        (map-set delivery-feedback nft-id {
            rater: tx-sender,
            score: score
        })
        (map-set restaurant-rating-stats current-restaurant {
            total-score: (+ (get total-score rest-stats) score),
            count: (+ (get count rest-stats) u1)
        })
        (map-set delivery-rating-stats driver {
            total-score: (+ (get total-score drv-stats) score),
            count: (+ (get count drv-stats) u1)
        })
        (ok true)
    )
)

(define-read-only (get-delivery-rating (nft-id uint))
    (map-get? delivery-feedback nft-id)
)

(define-read-only (get-restaurant-average-rating (restaurant principal))
    (match (map-get? restaurant-rating-stats restaurant)
        stats (some { average: (/ (get total-score stats) (get count stats)), count: (get count stats) })
        none
    )
)

(define-read-only (get-delivery-person-average-rating (driver principal))
    (match (map-get? delivery-rating-stats driver)
        stats (some { average: (/ (get total-score stats) (get count stats)), count: (get count stats) })
        none
    )
)
