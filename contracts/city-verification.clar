;; City Verification Contract
;; Validates floating city infrastructure and certification

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_CITY_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_VERIFIED (err u102))
(define-constant ERR_INVALID_COORDINATES (err u103))

;; City verification status
(define-data-var next-city-id uint u1)

;; City data structure
(define-map cities
  { city-id: uint }
  {
    name: (string-ascii 50),
    coordinates: { lat: int, lng: int },
    population: uint,
    infrastructure-score: uint,
    verified: bool,
    verification-date: uint,
    owner: principal
  }
)

;; Verification requirements
(define-map verification-requirements
  { requirement-type: (string-ascii 20) }
  { min-score: uint, required: bool }
)

;; Initialize verification requirements
(map-set verification-requirements
  { requirement-type: "infrastructure" }
  { min-score: u75, required: true }
)

;; Register a new floating city
(define-public (register-city (name (string-ascii 50)) (lat int) (lng int) (population uint))
  (let ((city-id (var-get next-city-id)))
    (asserts! (and (>= lat -90000000) (<= lat 90000000)) ERR_INVALID_COORDINATES)
    (asserts! (and (>= lng -180000000) (<= lng 180000000)) ERR_INVALID_COORDINATES)

    (map-set cities
      { city-id: city-id }
      {
        name: name,
        coordinates: { lat: lat, lng: lng },
        population: population,
        infrastructure-score: u0,
        verified: false,
        verification-date: u0,
        owner: tx-sender
      }
    )

    (var-set next-city-id (+ city-id u1))
    (ok city-id)
  )
)

;; Update infrastructure score
(define-public (update-infrastructure-score (city-id uint) (score uint))
  (let ((city (unwrap! (map-get? cities { city-id: city-id }) ERR_CITY_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner city)) ERR_UNAUTHORIZED)
    (asserts! (<= score u100) (err u104))

    (map-set cities
      { city-id: city-id }
      (merge city { infrastructure-score: score })
    )
    (ok true)
  )
)

;; Verify city (admin only)
(define-public (verify-city (city-id uint))
  (let ((city (unwrap! (map-get? cities { city-id: city-id }) ERR_CITY_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (not (get verified city)) ERR_ALREADY_VERIFIED)
    (asserts! (>= (get infrastructure-score city) u75) (err u105))

    (map-set cities
      { city-id: city-id }
      (merge city {
        verified: true,
        verification-date: block-height
      })
    )
    (ok true)
  )
)

;; Get city information
(define-read-only (get-city (city-id uint))
  (map-get? cities { city-id: city-id })
)

;; Get verification status
(define-read-only (is-city-verified (city-id uint))
  (match (map-get? cities { city-id: city-id })
    city (get verified city)
    false
  )
)

;; Get total cities count
(define-read-only (get-total-cities)
  (- (var-get next-city-id) u1)
)
