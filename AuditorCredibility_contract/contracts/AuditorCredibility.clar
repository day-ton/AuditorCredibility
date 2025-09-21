
;; title: AuditorCredibility
;; version: 1.0.0
;; summary: Address reputation system smart contract for smart contract auditor reliability scoring
;; description: This contract manages auditor profiles, tracks audit history, and maintains reputation scores
;;              to help users identify reliable smart contract auditors.

;; traits
;;

;; token definitions
;;

;; constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_REGISTERED (err u101))
(define-constant ERR_NOT_REGISTERED (err u102))
(define-constant ERR_INVALID_RATING (err u103))
(define-constant ERR_AUDIT_NOT_FOUND (err u104))
(define-constant ERR_ALREADY_RATED (err u105))
(define-constant ERR_CANNOT_RATE_SELF (err u106))
(define-constant ERR_INVALID_PARAMETERS (err u107))

;; data vars
(define-data-var next-audit-id uint u1)

;; data maps

;; Auditor profiles - stores basic information about registered auditors
(define-map auditor-profiles
  principal
  {
    name: (string-ascii 50),
    bio: (string-ascii 200),
    website: (string-ascii 100),
    registration-block: uint,
    is-active: bool
  }
)

;; Auditor statistics - tracks performance metrics
(define-map auditor-stats
  principal
  {
    total-audits: uint,
    completed-audits: uint,
    average-rating: uint, ;; multiplied by 100 for precision (e.g., 450 = 4.50)
    total-ratings: uint,
    reputation-score: uint ;; calculated score out of 1000
  }
)

;; Audit records - stores information about completed audits
(define-map audit-records
  uint ;; audit-id
  {
    auditor: principal,
    project-name: (string-ascii 50),
    project-contract: (optional principal),
    audit-report-hash: (string-ascii 64), ;; IPFS hash or similar
    completion-block: uint,
    severity-findings: uint, ;; number of high/critical findings
    client: principal,
    status: (string-ascii 20) ;; "completed", "verified", "disputed"
  }
)

;; Client ratings for auditors - allows clients to rate auditor performance
(define-map audit-ratings
  { audit-id: uint, rater: principal }
  {
    rating: uint, ;; 1-5 scale
    comment: (string-ascii 200),
    rating-block: uint
  }
)

;; Track which audits a client has rated to prevent duplicate ratings
(define-map client-rated-audits
  { client: principal, audit-id: uint }
  bool
)

;; public functions

;; Register as an auditor
(define-public (register-auditor (name (string-ascii 50))
                                (bio (string-ascii 200))
                                (website (string-ascii 100)))
  (let ((sender tx-sender))
    (asserts! (is-none (map-get? auditor-profiles sender)) ERR_ALREADY_REGISTERED)
    (asserts! (> (len name) u0) ERR_INVALID_PARAMETERS)

    ;; Create auditor profile
    (map-set auditor-profiles sender {
      name: name,
      bio: bio,
      website: website,
      registration-block: block-height,
      is-active: true
    })

    ;; Initialize stats
    (map-set auditor-stats sender {
      total-audits: u0,
      completed-audits: u0,
      average-rating: u0,
      total-ratings: u0,
      reputation-score: u500 ;; start with neutral score
    })

    (ok true)
  )
)

;; Update auditor profile
(define-public (update-profile (name (string-ascii 50))
                              (bio (string-ascii 200))
                              (website (string-ascii 100)))
  (let ((sender tx-sender)
        (current-profile (unwrap! (map-get? auditor-profiles sender) ERR_NOT_REGISTERED)))

    (asserts! (> (len name) u0) ERR_INVALID_PARAMETERS)

    (map-set auditor-profiles sender {
      name: name,
      bio: bio,
      website: website,
      registration-block: (get registration-block current-profile),
      is-active: (get is-active current-profile)
    })

    (ok true)
  )
)

;; Submit completed audit
(define-public (submit-audit (project-name (string-ascii 50))
                            (project-contract (optional principal))
                            (audit-report-hash (string-ascii 64))
                            (severity-findings uint)
                            (client principal))
  (let ((sender tx-sender)
        (audit-id (var-get next-audit-id))
        (auditor-profile (unwrap! (map-get? auditor-profiles sender) ERR_NOT_REGISTERED))
        (current-stats (unwrap! (map-get? auditor-stats sender) ERR_NOT_REGISTERED)))

    (asserts! (get is-active auditor-profile) ERR_UNAUTHORIZED)
    (asserts! (> (len project-name) u0) ERR_INVALID_PARAMETERS)
    (asserts! (> (len audit-report-hash) u0) ERR_INVALID_PARAMETERS)

    ;; Create audit record
    (map-set audit-records audit-id {
      auditor: sender,
      project-name: project-name,
      project-contract: project-contract,
      audit-report-hash: audit-report-hash,
      completion-block: block-height,
      severity-findings: severity-findings,
      client: client,
      status: "completed"
    })

    ;; Update auditor stats
    (map-set auditor-stats sender {
      total-audits: (+ (get total-audits current-stats) u1),
      completed-audits: (+ (get completed-audits current-stats) u1),
      average-rating: (get average-rating current-stats),
      total-ratings: (get total-ratings current-stats),
      reputation-score: (calculate-reputation-score
                          (+ (get completed-audits current-stats) u1)
                          (get average-rating current-stats)
                          severity-findings)
    })

    ;; Increment audit ID for next use
    (var-set next-audit-id (+ audit-id u1))

    (ok audit-id)
  )
)

;; Rate an auditor's performance on a specific audit
(define-public (rate-audit (audit-id uint) (rating uint) (comment (string-ascii 200)))
  (let ((sender tx-sender)
        (audit-record (unwrap! (map-get? audit-records audit-id) ERR_AUDIT_NOT_FOUND))
        (auditor (get auditor audit-record)))

    (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_RATING)
    (asserts! (not (is-eq sender auditor)) ERR_CANNOT_RATE_SELF)
    (asserts! (is-none (map-get? client-rated-audits { client: sender, audit-id: audit-id })) ERR_ALREADY_RATED)

    ;; Record the rating
    (map-set audit-ratings { audit-id: audit-id, rater: sender } {
      rating: rating,
      comment: comment,
      rating-block: block-height
    })

    ;; Mark as rated by this client
    (map-set client-rated-audits { client: sender, audit-id: audit-id } true)

    ;; Update auditor's average rating and reputation
    (update-auditor-rating auditor rating)

    (ok true)
  )
)

;; Deactivate auditor profile (only by auditor themselves)
(define-public (deactivate-profile)
  (let ((sender tx-sender)
        (current-profile (unwrap! (map-get? auditor-profiles sender) ERR_NOT_REGISTERED)))

    (map-set auditor-profiles sender {
      name: (get name current-profile),
      bio: (get bio current-profile),
      website: (get website current-profile),
      registration-block: (get registration-block current-profile),
      is-active: false
    })

    (ok true)
  )
)

;; read only functions

;; Get auditor profile
(define-read-only (get-auditor-profile (auditor principal))
  (map-get? auditor-profiles auditor)
)

;; Get auditor statistics
(define-read-only (get-auditor-stats (auditor principal))
  (map-get? auditor-stats auditor)
)

;; Get audit record
(define-read-only (get-audit-record (audit-id uint))
  (map-get? audit-records audit-id)
)

;; Get audit rating
(define-read-only (get-audit-rating (audit-id uint) (rater principal))
  (map-get? audit-ratings { audit-id: audit-id, rater: rater })
)

;; Check if auditor is registered and active
(define-read-only (is-active-auditor (auditor principal))
  (match (map-get? auditor-profiles auditor)
    profile (get is-active profile)
    false
  )
)

;; Get reputation score with breakdown
(define-read-only (get-reputation-breakdown (auditor principal))
  (match (map-get? auditor-stats auditor)
    stats (some {
      reputation-score: (get reputation-score stats),
      completed-audits: (get completed-audits stats),
      average-rating: (get average-rating stats),
      total-ratings: (get total-ratings stats),
      rating-display: (if (> (get total-ratings stats) u0)
                        (/ (get average-rating stats) u100)
                        u0)
    })
    none
  )
)

;; Check if client has already rated a specific audit
(define-read-only (has-client-rated-audit (client principal) (audit-id uint))
  (default-to false (map-get? client-rated-audits { client: client, audit-id: audit-id }))
)

;; Get next audit ID
(define-read-only (get-next-audit-id)
  (var-get next-audit-id)
)

;; private functions

;; Calculate reputation score based on various factors
(define-private (calculate-reputation-score (completed-audits uint) (average-rating uint) (severity-findings uint))
  (let ((base-score u500) ;; neutral starting point
        (audit-bonus-raw (* completed-audits u10))
        (audit-bonus (if (> audit-bonus-raw u200) u200 audit-bonus-raw)) ;; cap at 200
        (rating-bonus (if (> average-rating u300)
                        (- average-rating u300) ;; rating above 3.0 adds bonus
                        u0))
        (severity-penalty-raw (* severity-findings u5))
        (severity-penalty (if (> severity-penalty-raw u100) u100 severity-penalty-raw)) ;; cap at 100
        (raw-score (+ (+ base-score audit-bonus) (- rating-bonus severity-penalty))))

    ;; Ensure score is between 100 and 1000
    (if (< raw-score u100)
      u100
      (if (> raw-score u1000)
        u1000
        raw-score))
  )
)

;; Update auditor's average rating when new rating is submitted
(define-private (update-auditor-rating (auditor principal) (new-rating uint))
  (let ((current-stats (unwrap-panic (map-get? auditor-stats auditor)))
        (current-total (get total-ratings current-stats))
        (current-avg (get average-rating current-stats))
        (new-total (+ current-total u1))
        (new-avg-raw (/ (+ (* current-avg current-total) (* new-rating u100)) new-total))
        (new-reputation (calculate-reputation-score
                          (get completed-audits current-stats)
                          new-avg-raw
                          u0))) ;; don't factor severity for rating updates

    (map-set auditor-stats auditor {
      total-audits: (get total-audits current-stats),
      completed-audits: (get completed-audits current-stats),
      average-rating: new-avg-raw,
      total-ratings: new-total,
      reputation-score: new-reputation
    })
  )
)

