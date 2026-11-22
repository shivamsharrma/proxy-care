# Proxy Care: UI/UX state for API design

*Aligned with PRD v2.3 and the current design canvas (updated 1 Nov 2026).*

Context for designing the backend API of **Proxy Care**, a mobile service where a **User** (adult child / sponsor) books a vetted **Caretaker** to accompany a family member (**Patient**) to a hospital visit. Two apps share one backend: **User app** and **Caretaker app**. Third-party **Ride Partners** (Uber/Rapido) handle transport. All money is INR.

**Payments model (v2.3):** there is **no User wallet**. Every charge the User pays goes through a **third-party payment gateway** (redirect, then return to the app). After the booking itself, every charge arrives as a **payment request** the User approves with **"Approve & Pay"**. Money is collected into the **Proxy Care (platform) account**. Caretakers have a **virtual earnings wallet**: a balance of earnings not yet withdrawn. Refunds go to the User's bank account / original payment method.

Screen IDs below match the design canvas (e.g. `B4`, `H1`).

### What changed in this revision
- **Booking form (B3):** pickup time uses a **time picker**; doctor field removed (doctor name goes in instructions); hospital map shows no distance.
- **Cancellation (B5):** confirmation dialog with refund/deduction quote; booking → `CANCELLED`; toast on B1.
- **User home (B1):** ongoing visit card + **pending payment requests** list; upcoming visits moved to the new **Visits** tab (B7); new **Payments** tab (B8) + payment detail (B9).
- **Caretaker home (P1):** ongoing visit card with **visit-stage badge**, **resume arrow** (opens the screen for the current stage) and **View full details**; earnings chip is display-only; no upcoming section.
- **Caretaker visits (P3):** tabs **Upcoming / Past**; new **P3a visit details** screen.
- **Hospital bill flow:** H2 scan (no photo-upload fallback) → **H2a** amount (from QR, or typed if absent) + **description** → payment request → User pays → caretaker **attaches the hospital's bill** (H3 → **H4**).

---

## 1. Core entities

| Entity | Key fields shown in UI |
|---|---|
| User | id, name, sex, age, mobile (verified), address |
| Patient (family member) | id, userId, relation, name, age, sex, mobile (optional; receives pickup OTP), address (same as user or own), mobility category, health notes |
| Caretaker | id, name, sex, age, mobile, email, emergency contact, residential address, occupation, marital status, photo, Aadhaar (masked), PAN, KYC status, bank account (verified by ₹1 test deposit), rating, visit count, languages, online status, skills (e.g. "Wheelchair trained"), **earnings wallet balance**, weekly earnings, visits done |
| Booking (Visit) | id (e.g. `PC-2481`), userId, patientId, caretakerId, date, **pickup time**, purposes[], hospital (name, address, lat/lng), department (optional), instructions (free text; **includes doctor name/appointment if any**), attachments[], price breakdown, state, **stage** (see §2), pickup OTP, timestamps. *No separate doctor field.* |
| Cancellation | bookingId, cancelledAt, cancelledBy, hoursBeforePickup, policyCase (`MORE_THAN_8H` / `WITHIN_8H`), paidAmount, deduction, deductionReason, refundAmount, refundId |
| Attachment | id, bookingId, file name, type (JPG/PNG/PDF), size, url |
| Service (one per booking purpose) | id, bookingId, type, department/detail, status, startedAt, completedAt |
| Ride | id, bookingId, leg (`TO_HOSPITAL` / `TO_HOME`), provider, vehicle type, driver name, plate, ride PIN, ETA, fare estimate, final fare, status events, paymentRequestId |
| Hospital bill | id, bookingId, QR payload, merchant name, MCC, QR check results, **amount**, **amountSource** (`QR` / `MANUAL` — typed by caretaker when the QR has no amount), **description*** (e.g. "OPD registration + consultation fee"), status, paymentRequestId, **finalBill** (file id, type photo/PDF, file name, size, uploadedBy, uploadedAt) |
| **Payment request** | id, bookingId, type (`RIDE_TO_HOSPITAL` / `RIDE_HOME` / `HOSPITAL_BILL` / `CARETAKER_FEE`), amount, **description** (shown to User), payee (hospital / ride partner / Proxy Care), requestedBy, createdAt, status, paidAt, method, gateway transaction ref, attachments[] (e.g. hospital final bill, trip receipt, caretaker bill) |
| **Payment (gateway transaction)** | id, bookingId, paymentRequestId (null for the booking charge), amount, gateway session/order id, status, timestamp |
| Refund | id, bookingId, amount, reason (cancellation / diagnostic pro-rate), destination (bank / original method), status |
| Caretaker earning | bookingId, breakdown (block + extra time), bill number, status, addedToWalletAt |
| Caretaker withdrawal | id, caretakerId, amount, bank (masked), status, UTR, timestamp |
| Dispute | id, bookingId, raisedBy, reason, details, photo, status, ticket no. (e.g. `DS-1093`) |
| Rating | bookingId, stars (1–5) |

---

## 2. Enums and business rules

**Mobility category → hourly wage** (sets price and caretaker skill)
| Category | Wage/hr | Booking price (3-hr block + ₹400 margin + ₹99 fee) |
|---|---|---|
| `AMBULATORY` (walks on own) | ₹200 | ₹1,099 |
| `WHEELCHAIR` | ₹250 | ₹1,249 |
| `BEDRIDDEN` | ₹320 | ₹1,459 |

**Visit purpose** (multi-select): `OPD`, `DIAGNOSTICS`, `DAY_CARE`, `ADMISSION_DISCHARGE`, `EMERGENCY`. One 3-hr block covers all selected purposes in one visit. Each selected purpose becomes a **Service** at the hospital.

**Booking state:** `PAYMENT_PENDING` (gateway not completed) → `WAITING` (paid; broadcast to nearby caretakers) → `ASSIGNED` (first accept) → `IN_PROGRESS` (pickup OTP verified) → `COMPLETED` (caretaker marks Visit Completed) → `SETTLED` (caretaker fee paid) · also `CANCELLED`.

**Visit stage** (while `ASSIGNED`/`IN_PROGRESS`; drives the stage badge on P1/B1 and where P1's resume arrow goes):
| Stage | Badge text | Caretaker resume screen |
|---|---|---|
| `HEADING_TO_PICKUP` | Heading to pickup | P4 |
| `PICKED_UP` | Patient picked up | P6 |
| `RIDE_TO_HOSPITAL` | Ride to hospital | P8a |
| `OWN_TRANSPORT_TO_HOSPITAL` | In transit to hospital | P7b |
| `AT_HOSPITAL` | At hospital | H1 |
| `RIDE_HOME` | Ride home | D3a |
| `OWN_TRANSPORT_HOME` | In transit home | D2b |
| `HANDOVER` | Handover at home | D5 |
| `COMPLETED_PAYOUT_PENDING` | Visit completed · payout pending | (no arrow; "View payout status" → F4) |

**Service status:** `PENDING` → `STARTED` → `COMPLETED`. Start allowed only when PENDING; Complete only when STARTED; a completed card is read-only. Nothing in between.

**Ride events:** `RIDE_PARTNER_ASSIGNED` → `RIDE_PARTNER_ARRIVED` → `TRIP_STARTED` → `TRIP_COMPLETED`. Ride is **optional** on both legs (caretaker may skip: family car, ambulance, walking, family collecting).

**Payment request status:** `REQUESTED` → `PAYING` (redirected to gateway) → `PAID` / `FAILED` (retry) · hospital bills also `DISPUTED`.

**Hospital bill status:** `QR_MISMATCH` (no request sent) · `PAYMENT_REQUESTED` → `PAID_BILL_PENDING` (User paid; caretaker must attach the hospital's bill) → `BILL_ATTACHED` · or `DISPUTED`.

**QR checks:** QR readable (UPI) · merchant name matches hospital · MCC is hospital (e.g. 8062). If the QR carries an amount it is used read-only; otherwise the caretaker must enter it.

**Caretaker KYC status:** `IN_PROGRESS` (step n of 5) → `SUBMITTED` (video KYC scheduled) → `APPROVED` / `REJECTED`. Identity check is **video KYC only** in the UI.

**Caretaker earning status:** `ON_HOLD` (family has unpaid requests) → `AWAITING_FEE` (fee request sent to User) → `IN_WALLET` (fee paid; bill generated) → `WITHDRAWN`.

**Cancellation policy** (quote shown in the B5 dialog; refunds to bank / original payment method). Measured from **now** to the booking's **pickup time**:
| Case | Deduction | Refund (₹1,249 wheelchair example) |
|---|---|---|
| More than 8 h before pickup | ₹99 platform fee | ₹1,150 |
| Within 8 h of pickup | 3-hr caretaker wage (₹750) + ₹99 | ₹400 |
| No-show | everything | ₹0 |

Examples (pickup Mon 2 Nov, 10:00 AM): 31 Oct 19:50 → ₹1,150 / ₹99 · 2 Nov 01:59 → ₹1,150 / ₹99 · 2 Nov 02:01 → ₹400 / ₹849 · 2 Nov 09:30 → ₹400 / ₹849.

**Final fee strategy (proposed, pending confirmation):**
1. Billable time = pickup OTP verified → Visit Completed.
2. 3-hr block paid at booking.
3. Over 3 h: extra time rounded **up to next 30 min** × hourly wage → `CARETAKER_FEE` payment request.
4. Under 3 h: 3-hr minimum, **except Diagnostics**, which is pro-rated (30-min steps, 1-hr min) and the unused wage is refunded to the User's bank.
5. ₹400 margin and ₹99 fee never change.

**Settlement order (PRD 3.6–3.7):** audit all payment requests on the booking → if any unpaid, block closing (F2) → when all cleared, calculate fee and send `CARETAKER_FEE` request → User pays via gateway → money to Proxy Care account → caretaker earning added to the caretaker's virtual wallet → bill generated → caretaker withdraws to bank. Caretaker may raise a dispute if unsettled.

**Location visibility:** Caretaker sees own live location + patient home address. User sees caretaker live location. Patient sees none. Sharing starts when the caretaker toggles "Reaching pickup location" and ends at drop-off.

**Tele-consultation:** "Phone/Video call Caretaker" on the User side opens **WhatsApp** (deep link to the caretaker's number). No in-app call signalling.

---

## 3. Shared payment pattern (User app)

Used on B4, U2b, H5, U3b, F1 (and F2 inline).
1. Screen shows amount + description/line items + **Approve & Pay** (B4: **Confirm & Pay**).
2. Tap → "Opening secure payment" sheet → app redirects to the gateway page.
3. Return from gateway → success ("₹X paid") with Continue, or failure with retry.

API needs: create gateway order for a booking or payment request · handle gateway callback/webhook · return payment status on app resume · idempotency on repeat taps.

---

## 4. User app screens

### Onboarding
**01 Welcome / choose role**
- Displays: value props; language toggle (English / हिन्दी).
- Actions: choose role `USER` → 02 · `CARETAKER` → C1 (via phone + OTP); open Terms / Privacy.

**02 Mobile number** (shared by both roles)
- Inputs: country code (+91), mobile (10 digits).
- Actions: Send OTP.
- States: invalid number, sending, rate-limited.

**03 Verify OTP** (shared)
- Displays: masked number, resend countdown (30 s).
- Inputs: 6-digit OTP.
- Actions: Verify; Resend SMS; Change number.
- States: verifying, wrong code, expired, resend locked. New user → 04 (User) or C1 (Caretaker); existing → home.

**04 User profile (Stage A)**
- Inputs: full name*, sex* (F/M/Other), age, mobile (prefilled, verified, read-only), address* (text or "use current location").
- Actions: Continue → 05.

**05 Add family member (Stage B)**
- Inputs: relation* (Father, Mother, Spouse, Grandparent, Sibling, Other), full name*, age*, sex*, mobile (optional), "lives at my address" toggle (else address), mobility category* (3 options), health notes (optional).
- Actions: Save family member → 06.

**06 Family linked**
- Displays: list of patients (initials, name, relation, age, sex, mobility badge); "you only pay when asked" note.
- Actions: edit patient; add another; Book a caretaker → B1.

### Home, booking and tabs
**B1 Home**
- Displays: greeting, notifications; patient list (single-select) + "Book Caretaker for {name}"; **Ongoing visit** card (patient, caretaker, hospital, **stage badge**, arrow → U2 timeline, "Track caretaker live" → U1; empty state when none); **Pending payment requests** list with count badge (description, payee, requested-by, time, amount; hospital bill → H5, ride → U2b/U3b; empty state); bottom nav (Home, **Visits → B7**, **Payments → B8**, Family).
- Transient: toast "Booking cancelled. ₹X will be refunded to your bank" after a cancellation.
- *No upcoming-visits section on Home.*

**B2 Visit date & purposes**
- Displays: selected patient + mobility; next 5 dates; purpose cards with icon and `(i)` info text.
- Inputs: date* (chips or date picker); purposes* (multi-select, ≥1).
- Actions: toggle purpose; open/close info; Next (disabled when none selected) → B3.

**B3 Hospital, pickup time & attachments**
- Inputs: hospital* (search by name/area → map pin, name, address; **no distance shown**); department (optional select); **pickup time*** via an **M3 time picker dialog** (hour → minute in 5-min steps → AM/PM; Cancel/OK; caretaker arrives at the patient's home at this time); instructions for caretaker (text + quick chips, e.g. "Doctor: Dr. ___", "Carry old reports", "Reach hospital by 10:30 AM"; **doctor name and appointment time go here**); attachments (optional; prescription, appointment receipt, reports; photo or file; JPG/PNG/PDF; ≤10 MB each; ≤5 files; removable).
- Actions: Next → B4.
- States: hospital search loading/no results; upload progress/failure/too large.

**B4 Review · Confirm & Pay**
- Displays: patient, date, purposes, hospital + department, pickup time, instructions, attachments (each with Edit link); price breakdown (wage × 3 h, ₹400, ₹99, total); note that rides/hospital bills come later as payment requests; cancellation policy with refund per case.
- Inputs: "I've read the cancellation policy" checkbox*.
- Actions: **Confirm & Pay ₹X** → gateway (§3) → on success create booking `WAITING` → B5.
- States: redirecting, paid, payment failed (retry), cancelled at gateway.

**B5 Finding caretaker (`WAITING`)**
- Displays: booking id, "sent to N caretakers nearby", visit summary (date, pickup time, hospital), "₹X paid" + receipt.
- Actions: Back to home; **Cancel booking** → confirmation dialog.
- **Cancel dialog:** pickup date/time and time remaining; policy line; You paid · Deduction (with reason) · **Refund**; note that the refund goes to the bank account or original payment method (5–7 working days). Buttons: **Yes, cancel booking** (→ booking `CANCELLED`, refund created, toast, → B1; booking no longer listed in upcoming) · Keep booking.
- Realtime: caretaker accepted → banner → B6. Timeout/no caretaker → not yet designed.

**B6 Caretaker assigned (`ASSIGNED`)**
- Displays: caretaker card (photo, name, KYC verified, skill, rating, visit count, languages); pickup code (4 digits, also SMS to patient); visit progress steps.
- Actions: Call, Message, Track visit live → U1.

**B7 My visits** (Visits tab)
- Tabs: **Upcoming** · **Past**.
- Card: date tile, patient, pickup time + hospital (or purposes · hospital · total for past), status chip (Caretaker assigned · {name} / Finding a caretaker / Completed · all settled / Cancelled · ₹X refunded).
- Actions: open card → B6 (assigned) · B5 (waiting) · F3 statement (past/cancelled).

**B8 Payments** (Payments tab)
- Displays: every payment request the User **approved and paid**, grouped by visit (visit name, date, booking id); each row: type icon, description, payee · time, amount, "Paid". Includes the booking charge.
- Actions: tap row → B9.

**B9 Payment details**
- Displays: Paid chip, description, amount; rows: paid to, QR check (hospital), route (rides), requested by + time, paid on, method, transaction id, visit; **Bills** section (hospital bill attached by caretaker after payment; ride trip receipt; caretaker bill). Booking charge shows its price breakdown instead.
- Actions: Download receipt (PDF); Report a problem with this payment.

### Pickup, hospital & drop-off (User side)
**U1 Caretaker live location**
- Displays: live map with caretaker pin, patient home pin, ETA, 5-step progress (Assigned, Pickup, Ride, Hospital, Home), caretaker card, pickup code.
- Actions: call caretaker; View visit timeline → U2.

**U2 Visit timeline** (events only; **no fares or charges**)
- Displays: ordered events with timestamps and current-step highlight.
- Actions: Call caretaker; Track live.
- Realtime: ride payment request banner → U2b.

**U2b Ride payment request (to hospital)**
- Displays: amount, status chip, ride, trip route, time, driver.
- Actions: **Approve & Pay** (§3); Call caretaker. After paid → H6.

**H5 Hospital payment request**
- Displays: **description** (e.g. "OPD registration + consultation fee"), amount, requested by + time, QR checks passed (hospital name, MCC), "desk is waiting" note. *No bill image at request time.*
- Actions: **Approve & Pay** (§3); "This bill looks wrong" (dispute; nothing paid).
- States: requested, redirecting, paid (note: caretaker will attach the hospital's bill, visible in B9), disputed.

**H6 Services status** (read-only)
- Displays: each booked service with status badge and times; "n of m completed".
- Actions: **Phone/Video call Caretaker** (opens WhatsApp); View visit timeline.
- Realtime: hospital payment request banner → H5; all services completed banner → U3.

**U3 Coming home (live)**
- Displays: live map, ETA, progress at "Home" step, caretaker card.
- Realtime: ride-home payment request banner → U3b.

**U3b Ride home payment request**: same contract as U2b (type `RIDE_HOME`). After paid → U4.

**U4 Visit completed**
- Displays: handover checklist results, documents/prescription photos, final-bill notice.
- Inputs: rating 1–5.
- Actions: Review final bill → F1 (or F2 if unpaid requests); View timeline; Book follow-up visit.

### Final settlement (User side)
**F2 Unpaid requests (block closing)**
- Displays: caretaker reminder message; unpaid payment requests (e.g. hospital bill ₹500) with View / **Approve & Pay**; already-cleared items.
- Actions: pay; "Something looks wrong" → H5. "Review final bill" disabled until all paid → F1.

**F1 Final caretaker bill**
- Displays: actual time vs 3-hr block (bar), pickup→drop-off range, billed duration, fee lines, amount paid at booking, net (to pay / refund to bank / ₹0), rule text, "already paid on this visit" breakdown (booking, rides, hospital bills).
- Actions: **Pay Caretaker ₹X** (§3) / Close visit & get ₹X back / Approve & close visit; Question about this bill.
- States: open, redirecting, settled (→ F3), payment failed.

**F3 Visit statement**
- Displays: total visit cost; split by caretaker / hospital / platform / rides (bar + list); chronological list of the User's payments.
- Actions: Download invoice (PDF); Book follow-up visit; close → B1.

---

## 5. Caretaker app screens

### Onboarding & KYC
**C1 KYC checklist**: 5 steps with status (done / current / to do): mobile, basic info, Aadhaar & PAN, photo + video KYC, payout account. Resumable.

**C2 Basic information**
- Inputs: full name (as on Aadhaar)*, sex*, age (≥18), email*, emergency contact*, residential address*, occupation, marital status (Single/Married).
- Actions: Save and continue → C3; Save and finish later → C1.

**C3 Aadhaar & PAN**
- Displays: Aadhaar masked + "Verified".
- Inputs: PAN* (10 chars); consent checkbox*.
- Actions: Verify PAN; Continue → C4.
- States: pending, verifying, verified, mismatch.

**C4 Photo & identity check**
- Inputs: profile photo* (camera); video KYC slot* (time chips).
- Actions: Book call → C5.

**C5 Payout account**
- Inputs: account holder name*, account number*, re-enter account number*, IFSC* (auto-fills bank, branch, PIN).
- Actions: Submit for review → C6. ₹1 test deposit to confirm the account.
- States: IFSC invalid, numbers mismatch, test deposit failed.

**C6 Under review**
- Displays: status timeline (details submitted, Aadhaar/PAN verified, video KYC at time, approval ~24 h after call).
- Actions: Reschedule call; Go to home → P1.

### Home, visits & pickup
**P1 Home**
- Displays: **earnings wallet chip** (earnings yet to be withdrawn; **display-only, not tappable**); online/offline toggle (requests within 8 km); new request alert → P2; **Ongoing visits** card (patient, hospital, booking id, **stage badge**; empty state when none); stats: this week's earnings, **visits done** (tap → P3 **Past** tab); bottom nav (Home, Visits, Earnings, Profile).
- Ongoing card actions: while in progress → **resume arrow** (opens the screen for the current stage, see §2) + **View full details** → P3a. After Visit Completed → **View payout status** → F4 (shown while payout is pending).
- *No upcoming-visits section on Home.*

**P2 New visit request**
- Displays: countdown; earning (₹ and hours × rate); date + pickup time; patient sex/age/mobility; pickup distance + locality (full address hidden until accepted); hospital + purpose + distance.
- Actions: Accept (first wins → `ASSIGNED`) → P3; Decline.
- States: expired, already taken.

**P3 My visits**: tabs **Upcoming** / **Past** (no Today tab).
- Upcoming card: date + pickup time, patient name/age, mobility chip, hospital, purposes; **View full details** → P3a; on the visit day also **Start trip to pickup** → P4. "Visit accepted" banner after accepting.
- Past card: date, patient, hospital · purpose, earning, payout status chip (In your wallet / Payout pending) → F4.

**P3a Visit details** (read-only)
- Displays: booking id; patient name, age, mobility (*no language shown*); date & pickup time; pickup address; hospital name, address, department, "Open in maps"; visit purposes; instructions from the User (incl. doctor name / appointment); attachments (open file); family contact (name, relation, Call); caretaker earning (3-hr block × rate; extra time in 30-min steps).
- Actions: back only (no start/back buttons).

**P4 Start trip to pickup**
- Displays: map (own location + patient home), ETA/distance, patient + mobility, addresses.
- Inputs: "Reaching pickup location" toggle (starts live location sharing).
- Actions: Call family; I've arrived → P5.

**P5 Confirm arrival**
- Inputs: 4-digit pickup code*.
- Actions: Confirm arrival (→ `IN_PROGRESS`, starts billable time) → P6; Call family; Resend code.
- States: wrong code, too many attempts.

**P6 Book ride or skip** → P7a or P7b.

**P7a Book ride**: route, options (Cab XL / Cab / Auto; provider, ETA, fare estimate, suitability tag). Note: family pays via payment request. Action: Book → P8a.

**P7b Own transport**: mode (Family car, Ambulance, Walking, Other). No fare. Actions: I've reached the hospital → H1; Book a ride instead.

**P8a Ride status**: driver, plate, vehicle, ride PIN, 4 ride events with times, fare estimate. Actions: call driver, cancel ride. On `TRIP_COMPLETED`: **Request ₹X from family** → P9a.

**P9a Ride payment**: fare, driver, "Payment request sent to {User}" → "{User} paid". Actions: Remind family; Continue (enabled once paid) → H1. Never pays with own money.

### Hospital
**H1 Services to-do** (generic for every purpose)
- Displays: one card per booked service (name, detail, status badge, times); "n of m completed"; "Scan QR" card.
- Actions per service: Start (PENDING only) · Complete (STARTED only). Scan bill → H2. Leave hospital (enabled when all completed) → D1. **Back → P1 Home.**

**H2 Scan bill QR**: camera viewfinder, torch. *No photo-upload fallback.* Capture → QR verified → H2a (or H3 with `QR_MISMATCH`).

**H2a Payment request details**
- Displays: "QR verified · {hospital}" (name matched, MCC).
- Inputs: **amount** — read-only "Amount in the QR" when present; otherwise **Amount to request*** (₹, numeric) with a note that the QR has no amount; **description*** ("What is this payment for?", quick chips: Consultation fee, Lab test, Medicines).
- Actions: **Send to family** → creates hospital bill + `HOSPITAL_BILL` payment request (description shown to User) → H3.

**H3 Bill status**
- Displays: status banner; description + amount + requested time + pay chip; QR checks.
- States: **waiting for family** (realtime "{User} paid ₹X" alert switches to paid) · **paid · attach hospital bill** (card with Take photo / Upload → H4; primary CTA "Attach hospital bill") · **paid · bill attached** ("Hospital bill attached · shared with {User}") · **QR mismatch** (no request sent; Scan again).
- Actions: Back to services; Remind family; View hospital bill.

**H4 Attach hospital bill**
- Displays: paid request card (description, amount, "Paid by {User} · time"); guidance "hospital name, date and amount must be readable".
- Inputs: bill file* — take photo or upload PDF; preview with Retake / Replace.
- Actions: **Attach & share with {User}** (disabled until a file is added) → uploads finalBill, bill status `BILL_ATTACHED` → back to H3. File appears on the User's B9.

### Drop-off
**D1 Going home: book ride or skip** → D2a or D2b.
**D2a Book return ride** · **D3a Return ride status** · **D4a Ride payment**: same contracts as P7a/P8a/P9a with leg `TO_HOME`; D4a continues → D5.
**D2b Own transport home**: mode incl. "Family collecting at hospital". Action → D5.

**D5 Handover & Visit Completed**
- Inputs: checklist* (patient safely inside; papers handed over; medicines explained; belongings returned). All required.
- Actions: Mark Visit Completed (→ `COMPLETED`, stops billable time, triggers settlement audit).
- Displays after: times, time on visit, earning; unpaid-request warning ("earnings on hold") if any. → F4.

### Settlement
**F4 Visit earnings**
- Displays: earnings wallet chip; visit earning amount; status chip; 4-step tracker (visit completed → family pays fee → bill generated & added to wallet → withdrawn to bank); earning breakdown; bank masked + UTR when withdrawn.
- Actions: Notify family (when on hold); **Withdraw ₹X to bank** (when in wallet); Raise a dispute → F5; Back to home.

**F5 Raise a dispute**
- Displays: amount on hold, waiting since, reminders sent.
- Inputs: reason* (Family hasn't cleared payments / Family disputes visit time / A bill amount is wrong / Something else), details, photo.
- Actions: Submit → ticket no. + SLA.

---

## 6. Data the screens need (read models)

| Screen | Query |
|---|---|
| B1 | User's ongoing visit (with stage, caretaker, hospital) · pending payment requests (status `REQUESTED`/`FAILED`) with count |
| B5 dialog | Cancellation quote for a booking at "now" (case, hours left, paid, deduction + reason, refund) |
| B7 | User's visits: upcoming (`WAITING`/`ASSIGNED`) and past (`COMPLETED`/`SETTLED`/`CANCELLED`) with status chip data |
| B8 / B9 | User's paid payment requests grouped by booking (+ booking charge) · one payment detail with attachments |
| P1 | Caretaker wallet balance, ongoing visit (stage → resume target), weekly earnings, visits-done count |
| P3 / P3a | Caretaker visits: upcoming / past (with earning + payout status) · full visit details (address, purposes, instructions, attachments, family contact, earning) |
| H3 / H4 | Hospital bill with status, payment request status and finalBill |

---

## 7. Realtime events / notifications

| Event | Receiver | UI effect |
|---|---|---|
| Booking payment confirmed (gateway) | User | B4 success → B5 |
| Booking cancelled | User (+ caretakers with a pending request) | B1 toast; pending P2 requests expire |
| New visit request | Nearby online caretakers | P1 alert, P2 countdown |
| Request accepted | User | B5 banner → B6; other P2s expire |
| Visit stage changed | User + Caretaker | B1 / P1 stage badge; P1 resume target |
| Caretaker location update | User | U1 / U3 map + ETA |
| Pickup OTP verified | User | Timeline step |
| Ride events (×4, per leg) | Caretaker (+ User timeline) | P8a / D3a progress |
| Payment request created (ride / hospital / caretaker fee) | User | Banner → U2b / U3b / H5 / F1; B1 pending list |
| Payment request paid / failed | Caretaker (and User) | P9a / D4a update; **H3 "{User} paid" alert → attach bill**; F4 progress; B8 list |
| Hospital bill attached | User | B9 bills section |
| Hospital bill disputed | Caretaker | H3 status |
| Service started / completed | User | H6 badges; all done → banner to U3 |
| Visit completed | User | U4; P1 card → "View payout status" |
| Settlement reminder | User | F2 message |
| Caretaker fee paid → earning in wallet | Caretaker | F4 + wallet chip update |
| Withdrawal processed | Caretaker | F4 withdrawn (bank, UTR) |

---

## 8. Common UI states
- **Loading** (skeleton), **empty** (no ongoing visit, no pending requests, no visits, no family, no search results), **error + retry**, **inline validation**, **disabled CTAs** until valid (e.g. Send to family, Attach & share), **optimistic updates** for Start/Complete and checklist ticks with rollback.
- **Payment states** on every pay screen: redirecting, success on return, failure/cancel with retry, app resumed mid-payment (poll status).
- **Uploads**: progress, failure, file too large (attachments at booking; hospital bill on H4).

---

## 9. Open points / not yet designed
- Fee strategy in §2 is a proposal (rounding, minimums, Diagnostics pro-rating).
- Cancellation: behaviour at **exactly** 8 h before pickup is unspecified; cancellation is designed only from B5 (`WAITING`), not after a caretaker is assigned.
- Late-cancellation fee: PRD says "₹600 base"; UI uses the patient's actual 3-hr wage.
- Withdrawal: PRD says caretaker wallet holds earnings "yet to be withdrawn" but not how; UI assumes a manual "Withdraw to bank".
- Hospital bill: is the attached final bill mandatory before Leave hospital / Visit Completed? Can the User dispute after seeing it? Max file size/type for H4.
- B1 pending list includes ride requests, which open U2b/U3b rather than H5.
- Sample dates differ between screens (B2/B4 show Sat 24 Oct 9:30 AM; B5 shows Mon 2 Nov 10:00 AM for the cancellation examples).
- Admission-only visits: whether the drop-off leg is skipped.
- No-caretaker-found / booking timeout on B5; payment-failed screens are described but not drawn.
- Not designed: chat, document viewer, caretaker profile & earnings history, help, terms/privacy.
