# Access control and data integrity across P4-P9a, U1, U2 and U2b
# Source: proxy-care-ui-ux-state-for-api-design.md (PRD v2.3) §2 booking state + location visibility, §3 shared payment pattern; PRD 3.2, 3.3
# Wording and error codes follow hospital-appointment/05_hospital_access_control.feature.
#
# Open design questions (no scenario until decided):
#   - What happens to an in-progress visit if the caretaker's KYC is revoked?
#   - What do ride screens show for a COMPLETED or SETTLED booking? The API rejection is covered below.

@regression @pickup-and-ride @access-control @security
Feature: Role-based visibility and access rules during pickup and ride
  As the Proxy Care platform
  I want each role to see and do only what it is allowed to during pickup and ride
  So that the handover, the location data and the money stay trustworthy

  Background:
    Given booking "PC-2481" for patient "Kamla Mehta" is sponsored by "Rohan Mehta"
    And caretaker "Anita Verma" is assigned to the booking
    And caretaker "Suresh Yadav" is an approved caretaker not assigned to the booking
    And user "Priya Nair" has no relation to the booking

  # ---------- Booking state gates ----------

  Scenario Outline: Ride screens redirect when the visit is not in progress
    Given the booking is in state "<state>"
    And I am logged in to the Caretaker app as "Anita Verma"
    When I try to open the "P6 Book ride or skip" screen
    Then I should see the text "<message>"
    And I should be on the "P3 My visits" screen

    Examples:
      | state     | message                            |
      | ASSIGNED  | Confirm pickup with the code first |
      | CANCELLED | This visit was cancelled           |

  Scenario: Ride screens open while the visit is in progress
    Given the booking is in state "IN_PROGRESS"
    And I am logged in to the Caretaker app as "Anita Verma"
    When I try to open the "P6 Book ride or skip" screen
    Then I should be on the "P6 Book ride or skip" screen

  @negative @api
  Scenario Outline: Ride APIs reject calls outside IN_PROGRESS
    Given the booking is in state "<state>"
    When "Anita Verma" calls "<endpoint>"
    Then the server should respond with error "BOOKING_NOT_IN_PROGRESS"
    And the booking should have 0 rides for leg "TO_HOSPITAL"

    Examples:
      | state     | endpoint             |
      | ASSIGNED  | book ride            |
      | ASSIGNED  | record own transport |
      | COMPLETED | book ride            |
      | COMPLETED | record own transport |
      | SETTLED   | book ride            |
      | SETTLED   | record own transport |
      | CANCELLED | book ride            |
      | CANCELLED | record own transport |

  @negative @api
  Scenario Outline: The pickup code can only be verified while the booking is assigned
    Given the booking is in state "<state>"
    When "Anita Verma" calls "verify pickup code" with the correct code
    Then the server should reject the request
    And the booking should be in state "<state>"

    Examples:
      | state           |
      | PAYMENT_PENDING |
      | WAITING         |
      | COMPLETED       |
      | SETTLED         |
      | CANCELLED       |

  @negative @api
  Scenario: Only one active ride can exist for a leg
    Given the booking is in state "IN_PROGRESS"
    And the booking has an active ride for leg "TO_HOSPITAL"
    When "Anita Verma" calls "book ride"
    Then the server should reject the request
    And the booking should have 1 ride for leg "TO_HOSPITAL"

  # ---------- Caretaker-only actions ----------

  @negative @api
  Scenario Outline: Only the assigned caretaker can run the pickup and ride flow
    Given the booking is in state "IN_PROGRESS"
    When "<actor>" calls "<endpoint>"
    Then the server should respond with "403 Forbidden"
    And the booking should be unchanged

    Examples: Unassigned caretaker
      | actor        | endpoint             |
      | Suresh Yadav | start trip to pickup |
      | Suresh Yadav | verify pickup code   |
      | Suresh Yadav | book ride            |
      | Suresh Yadav | record own transport |
      | Suresh Yadav | cancel ride          |
      | Suresh Yadav | request ride fare    |
      | Suresh Yadav | remind family        |

    Examples: Sponsoring user
      | actor       | endpoint             |
      | Rohan Mehta | start trip to pickup |
      | Rohan Mehta | verify pickup code   |
      | Rohan Mehta | book ride            |
      | Rohan Mehta | record own transport |
      | Rohan Mehta | cancel ride          |
      | Rohan Mehta | request ride fare    |
      | Rohan Mehta | remind family        |

    Examples: Unrelated user
      | actor      | endpoint             |
      | Priya Nair | start trip to pickup |
      | Priya Nair | verify pickup code   |
      | Priya Nair | book ride            |
      | Priya Nair | record own transport |
      | Priya Nair | cancel ride          |
      | Priya Nair | request ride fare    |
      | Priya Nair | remind family        |

  @negative @api
  Scenario Outline: Unauthenticated calls are rejected
    Given the booking is in state "IN_PROGRESS"
    When an unauthenticated client calls "<endpoint>"
    Then the server should respond with "401 Unauthorized"
    And the booking should be unchanged

    Examples:
      | endpoint                |
      | start trip to pickup    |
      | read caretaker location |
      | read pickup code        |
      | verify pickup code      |
      | book ride               |
      | read visit timeline     |
      | request ride fare       |
      | create gateway order    |

  @negative @api
  Scenario: A caretaker cannot act on another booking's ride through their own booking
    Given the booking has an active ride for leg "TO_HOSPITAL"
    And "Suresh Yadav" is assigned to booking "PC-2490"
    When "Suresh Yadav" calls "cancel ride" with the ride of booking "PC-2481"
    Then the server should respond with "403 Forbidden"
    And the booking should be unchanged

  @negative
  Scenario Outline: An unassigned caretaker cannot open the visit
    Given the booking is in state "IN_PROGRESS"
    And I am logged in to the Caretaker app as "Suresh Yadav"
    When I open a deep link to the "<screen>" screen
    Then I should see the text "You don't have access to this visit"
    And I should be on the "P1 Home" screen
    And I should not see the patient's address or the family contact

    Examples:
      | screen                  |
      | P4 Start trip to pickup |
      | P5 Confirm arrival      |
      | P8a Ride status         |
      | P9a Ride payment        |

  # ---------- User-only actions ----------

  @negative @api
  Scenario Outline: Only the sponsoring user can pay the ride
    Given the booking is in state "IN_PROGRESS"
    And the booking has a "RIDE_TO_HOSPITAL" payment request for "₹340"
    When "<actor>" calls "create gateway order"
    Then the server should respond with "403 Forbidden"
    And the ride payment request should have status "REQUESTED"

    Examples:
      | actor        |
      | Anita Verma  |
      | Suresh Yadav |
      | Priya Nair   |

  @negative
  Scenario: Another user cannot open the ride payment request
    Given the booking has a "RIDE_TO_HOSPITAL" payment request for "₹340"
    And I am logged in to the User app as "Priya Nair"
    When I open a deep link to the "U2b Ride payment request" screen
    Then I should see the text "This request isn't available"
    And I should not see the text "₹340"

  @negative
  Scenario Outline: Another user cannot follow the visit
    Given the booking is in state "IN_PROGRESS"
    And I am logged in to the User app as "Priya Nair"
    When I open a deep link to the "<screen>" screen
    Then I should see the text "Visit not found"
    And I should not see the caretaker or patient details

    Examples:
      | screen                     |
      | U1 Caretaker live location |
      | U2 Visit timeline          |

  # ---------- Location visibility ----------

  Scenario Outline: The roles that can see the caretaker's location
    Given live location sharing is active
    And I am logged in as the "<role>"
    When I open the map for the booking
    Then I should see the caretaker pin
    And I should see the patient's home address
    And the map should not show a patient live location

    Examples:
      | role               |
      | assigned caretaker |
      | sponsoring user    |

  @negative @api
  Scenario Outline: Others cannot read the caretaker's location or timeline
    Given live location sharing is active
    When "<actor>" calls "<endpoint>"
    Then the server should respond with "403 Forbidden"

    Examples:
      | actor        | endpoint                |
      | Suresh Yadav | read caretaker location |
      | Suresh Yadav | read visit timeline     |
      | Priya Nair   | read caretaker location |
      | Priya Nair   | read visit timeline     |

  @negative @api
  Scenario: No location is available before the trip starts
    Given the booking is in state "ASSIGNED"
    And live location sharing is inactive
    When "Rohan Mehta" calls "read caretaker location"
    Then the server should return no location

  @negative @api
  Scenario: No location is available after the visit is completed
    Given the booking is in state "COMPLETED"
    When "Rohan Mehta" calls "read caretaker location"
    Then the server should return no location

  @integration
  Scenario: The patient has no location access through SMS
    Given the patient has mobile "+919812345678"
    When the pickup code SMS is sent
    Then the SMS to "+919812345678" should contain the pickup code
    And the SMS to "+919812345678" should not contain a tracking link

  # ---------- Pickup code secrecy ----------

  Scenario Outline: The caretaker never sees the pickup code on any screen
    Given the booking is in state "<state>"
    And I am logged in to the Caretaker app as "Anita Verma"
    When I open the "<screen>" screen
    Then I should not see the pickup code
    And the API responses for that screen should not contain the pickup code

    Examples:
      | state       | screen                  |
      | ASSIGNED    | P4 Start trip to pickup |
      | ASSIGNED    | P5 Confirm arrival      |
      | IN_PROGRESS | P6 Book ride or skip    |
      | IN_PROGRESS | P8a Ride status         |
      | IN_PROGRESS | P9a Ride payment        |

  @negative @api
  Scenario Outline: Only the sponsoring user can read the pickup code
    Given the booking is in state "ASSIGNED"
    When "<actor>" calls "read pickup code"
    Then the server should respond with "403 Forbidden"

    Examples:
      | actor        |
      | Anita Verma  |
      | Suresh Yadav |
      | Priya Nair   |

  @happy-path @api
  Scenario: The sponsoring user can read the pickup code
    Given the booking is in state "ASSIGNED"
    And the pickup code is "4821"
    When "Rohan Mehta" calls "read pickup code"
    Then the server should return the code "4821"

  # ---------- Integrity of ride events and money ----------

  @negative @api
  Scenario: Ride events are only accepted from the ride partner integration
    Given the latest ride event is "TRIP_STARTED"
    When "Anita Verma" calls "report ride event" with "TRIP_COMPLETED"
    Then the server should respond with "403 Forbidden"
    And the latest ride event should be "TRIP_STARTED"

  @negative @api
  Scenario: A ride event with an invalid signature is rejected
    Given the latest ride event is "TRIP_STARTED"
    When a ride event "TRIP_COMPLETED" arrives with an invalid signature
    Then the server should reject the request
    And the latest ride event should be "TRIP_STARTED"

  @negative @api
  Scenario: The caretaker cannot change the fare
    Given the booking is in state "IN_PROGRESS"
    And the latest ride event is "TRIP_COMPLETED"
    And the ride has the final fare "₹340"
    When "Anita Verma" calls "request ride fare" with amount "₹3,400"
    Then the booking should have 1 "RIDE_TO_HOSPITAL" payment request for "₹340"

  @negative @api
  Scenario: The amount the user pays always comes from the payment request
    Given the booking has a "RIDE_TO_HOSPITAL" payment request for "₹340"
    When "Rohan Mehta" calls "create gateway order" with amount "₹34"
    Then the gateway order should be created for "₹340"

  @negative @api
  Scenario: A client success report is not trusted without the webhook
    Given the ride payment request has status "PAYING"
    When the user client reports "payment success" without a gateway webhook
    Then the ride payment request should have status "PAYING"

  @happy-path @api
  Scenario: A signed gateway webhook marks the request paid
    Given the ride payment request has status "PAYING"
    When a gateway webhook with a valid signature confirms the payment
    Then the ride payment request should have status "PAID"

  @negative @api
  Scenario: Duplicate gateway webhooks are processed once
    Given the ride payment request was marked "PAID" by webhook event "evt_456"
    When the gateway delivers webhook event "evt_456" again
    Then the ride payment request should have status "PAID"
    And the caretaker should have 1 "payment request paid" event

  @negative @api
  Scenario: Own transport cannot produce a ride payment request
    Given the booking is in state "IN_PROGRESS" with stage "OWN_TRANSPORT_TO_HOSPITAL"
    When "Anita Verma" calls "request ride fare"
    Then the server should reject the request
    And the booking should have 0 "RIDE_TO_HOSPITAL" payment requests

  # ---------- Session ----------

  @negative
  Scenario Outline: An expired session asks for OTP and returns to the same screen
    Given the booking is in state "<state>"
    And I am logged in to the "<app>" app as "<actor>"
    And I am on the "<screen>" screen
    When my session expires
    And I tap "<action>"
    Then I should be asked to verify my mobile with OTP
    And no "<request>" request should be sent before I verify

    Examples: Caretaker app
      | state       | app       | actor       | screen           | action        | request       |
      | IN_PROGRESS | Caretaker | Anita Verma | P9a Ride payment | Remind family | remind family |

    Examples: User app
      | state       | app  | actor       | screen                   | action             | request              |
      | IN_PROGRESS | User | Rohan Mehta | U2b Ride payment request | Approve & Pay ₹340 | create gateway order |

  @negative
  Scenario: An expired session asks for OTP before checking the pickup code
    Given the booking is in state "ASSIGNED"
    And I am logged in to the Caretaker app as "Anita Verma"
    And I have entered "4821" in the "Pickup code" field
    When my session expires
    And I tap "Confirm arrival"
    Then I should be asked to verify my mobile with OTP
    And no "verify pickup code" request should be sent before I verify

  @ui-state
  Scenario: Verifying after session expiry returns to the same screen with the code kept
    Given the booking is in state "ASSIGNED"
    And I am logged in to the Caretaker app as "Anita Verma"
    And I have entered "4821" in the "Pickup code" field
    And my session has expired
    When I verify my mobile with OTP
    Then I should be on the "P5 Confirm arrival" screen
    And the booking should be in state "ASSIGNED"
