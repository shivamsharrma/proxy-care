@hospital @access-control @security
Feature: Role-based visibility and access rules during the hospital phase
  As the Proxy Care platform
  I want each role to see and do only what it is allowed to during the hospital phase
  So that money, patient data and service status stay trustworthy

  Background:
    Given booking "PC-2481" for patient "Kamla Devi" is in state "IN_PROGRESS"
    And booking "PC-2481" is sponsored by user "Anita Sharma"
    And caretaker "Ramesh Kumar" is assigned to booking "PC-2481"
    And caretaker "Suresh Yadav" is an approved caretaker not assigned to booking "PC-2481"
    And user "Vikram Mehta" has no relation to booking "PC-2481"

  # ---------------------------------------------------------------------------
  # Booking state gates
  # ---------------------------------------------------------------------------

  Scenario Outline: Hospital screens are only reachable while the visit is in progress
    Given booking "PC-2481" is in state "<state>"
    And I am logged in to the Caretaker app as "Ramesh Kumar"
    When I try to open the "Services to-do" screen for booking "PC-2481"
    Then <outcome>

    Examples:
      | state     | outcome                                                                 |
      | ASSIGNED  | I should see "Confirm pickup with the code first" and be on P3          |
      | IN_PROGRESS | I should be on the "Services to-do" screen                            |
      | COMPLETED | I should see the services as read-only with no Start, Complete or Scan QR |
      | SETTLED   | I should see the services as read-only with no Start, Complete or Scan QR |
      | CANCELLED | I should see "This visit was cancelled" and be on P3                    |

  @negative @api
  Scenario Outline: Service and bill APIs reject calls outside IN_PROGRESS
    Given booking "PC-2481" is in state "<state>"
    When caretaker "Ramesh Kumar" calls "<endpoint>" for booking "PC-2481"
    Then the server should respond with error "BOOKING_NOT_IN_PROGRESS"

    Examples:
      | state     | endpoint            |
      | ASSIGNED  | start service       |
      | ASSIGNED  | create hospital bill |
      | ASSIGNED  | attach hospital bill |
      | COMPLETED | complete service    |
      | COMPLETED | create hospital bill |
      | CANCELLED | start service       |

  # ---------------------------------------------------------------------------
  # Caretaker-only actions
  # ---------------------------------------------------------------------------

  @negative @api
  Scenario Outline: Only the assigned caretaker can change services and scan bills
    Given I am authenticated as "<actor>"
    When I call "<endpoint>" for booking "PC-2481"
    Then the server should respond with "<response>"
    And nothing should change on booking "PC-2481"

    Examples:
      | actor        | endpoint             | response      |
      | Suresh Yadav | start service        | 403 Forbidden |
      | Suresh Yadav | complete service     | 403 Forbidden |
      | Suresh Yadav | create hospital bill | 403 Forbidden |
      | Suresh Yadav | attach hospital bill | 403 Forbidden |
      | Anita Sharma | start service        | 403 Forbidden |
      | Anita Sharma | complete service     | 403 Forbidden |
      | Anita Sharma | create hospital bill | 403 Forbidden |
      | Anita Sharma | attach hospital bill | 403 Forbidden |
      | Vikram Mehta | start service        | 403 Forbidden |
      | Vikram Mehta | attach hospital bill | 403 Forbidden |

  @negative
  Scenario: An unassigned caretaker cannot see the visit
    Given I am logged in to the Caretaker app as "Suresh Yadav"
    When I open a deep link to the services of booking "PC-2481"
    Then I should see "You don't have access to this visit"
    And I should be on the "Home" screen (P1)

  # ---------------------------------------------------------------------------
  # User-only actions
  # ---------------------------------------------------------------------------

  @negative @api
  Scenario Outline: Only the sponsoring user can pay or dispute hospital bills
    Given a "₹500" hospital payment request exists for booking "PC-2481"
    And I am authenticated as "<actor>"
    When I call "<endpoint>" for that payment request
    Then the server should respond with "403 Forbidden"
    And the payment request status should remain "REQUESTED"

    Examples:
      | actor        | endpoint                 |
      | Ramesh Kumar | create gateway order     |
      | Ramesh Kumar | dispute hospital bill    |
      | Suresh Yadav | create gateway order     |
      | Vikram Mehta | create gateway order     |
      | Vikram Mehta | dispute hospital bill    |

  @negative
  Scenario: Another user cannot open the hospital payment request
    Given I am logged in to the User app as "Vikram Mehta"
    When I open a deep link to the hospital payment request for booking "PC-2481"
    Then I should see "This request isn't available"
    And I should not see the amount, description or merchant

  @negative @api
  Scenario: Only the sponsoring user and assigned caretaker can read the attached hospital bill
    Given a hospital bill with status "BILL_ATTACHED" exists for booking "PC-2481"
    When "Vikram Mehta" requests the attached hospital bill
    Then the server should respond with "403 Forbidden"
    When "Suresh Yadav" requests the attached hospital bill
    Then the server should respond with "403 Forbidden"
    When "Anita Sharma" requests the attached hospital bill
    Then the server should return the file
    When "Ramesh Kumar" requests the attached hospital bill
    Then the server should return the file

  # ---------------------------------------------------------------------------
  # Integrity of the bill and the payment
  # ---------------------------------------------------------------------------

  @negative @api
  Scenario: The amount the user pays always comes from the verified bill
    Given a "₹500" hospital payment request exists for booking "PC-2481"
    When the user app sends a gateway order request with amount "₹50"
    Then the gateway order should be created for "₹500"

  @negative @api
  Scenario: An amount carried by the QR cannot be overridden by the caretaker
    Given a verified hospital QR carries the amount "₹500"
    When the caretaker app creates a hospital bill for that QR with amount "₹5,000"
    Then the hospital bill should be created for "₹500"
    And the hospital bill should have amount source "QR"

  @api
  Scenario: A typed amount is accepted only when the QR has no amount
    Given a verified hospital QR carries no amount
    When the caretaker app creates a hospital bill for that QR with amount "₹650"
    Then the hospital bill should be created for "₹650"
    And the hospital bill should have amount source "MANUAL"

  @negative @api
  Scenario: A hospital bill cannot be created without a description
    Given a verified hospital QR carries the amount "₹500"
    When the caretaker app creates a hospital bill for that QR with no description
    Then the server should reject the request
    And no payment request should be created

  @negative @api
  Scenario Outline: The hospital's bill can only be attached after the family has paid
    Given a hospital bill with status "<status>" exists for booking "PC-2481"
    When caretaker "Ramesh Kumar" calls "attach hospital bill" for that bill
    Then the server should respond with error "BILL_NOT_ATTACHABLE"
    And the hospital bill should still have status "<status>"

    Examples:
      | status            |
      | QR_MISMATCH       |
      | PAYMENT_REQUESTED |
      | DISPUTED          |
      | BILL_ATTACHED     |

  @negative @api
  Scenario: A QR_MISMATCH bill can never be paid
    Given a hospital bill with status "QR_MISMATCH" exists for booking "PC-2481"
    Then no payment request should exist for that bill
    And any attempt to create a gateway order for that bill should fail with "BILL_NOT_PAYABLE"

  @negative @api
  Scenario: Gateway success is only trusted from the verified webhook
    Given a "₹500" hospital payment request is "PAYING"
    When the app reports "payment success" without a matching gateway webhook
    Then the payment request should remain "PAYING"
    When a gateway webhook with a valid signature confirms the payment
    Then the payment request should become "PAID"
    And the hospital bill should have status "PAID_BILL_PENDING"

  @negative @api
  Scenario: Duplicate gateway webhooks are processed once
    Given a "₹500" hospital payment request was marked "PAID" by webhook event "evt_123"
    When the gateway delivers webhook event "evt_123" again
    Then the payment request should remain "PAID"
    And the caretaker should not receive a second "Hospital bill paid" event

  # ---------------------------------------------------------------------------
  # Final bill gate on Visit Completed
  # Product decision (22 Nov 2026): Visit Completed is blocked while any bill on the
  # booking is PAID_BILL_PENDING. Leave hospital is not blocked by it.
  # ASSUMPTION: the error code name is placeholder.
  # ---------------------------------------------------------------------------

  @negative @api
  Scenario: Visit Completed is rejected while a paid bill is waiting for the hospital's bill
    Given booking "PC-2481" has stage "HANDOVER"
    And a "₹500" hospital bill with status "PAID_BILL_PENDING" exists for booking "PC-2481"
    When caretaker "Ramesh Kumar" calls "mark visit completed" for booking "PC-2481"
    Then the server should respond with error "FINAL_BILL_PENDING"
    And booking "PC-2481" should be in state "IN_PROGRESS"
    And billable time should not have stopped

  @negative @api
  Scenario: One pending bill blocks Visit Completed even when other bills are attached
    Given booking "PC-2481" has stage "HANDOVER"
    And a "₹500" hospital bill with status "BILL_ATTACHED" exists for booking "PC-2481"
    And a "₹300" hospital bill with status "PAID_BILL_PENDING" exists for booking "PC-2481"
    When caretaker "Ramesh Kumar" calls "mark visit completed" for booking "PC-2481"
    Then the server should respond with error "FINAL_BILL_PENDING"
    And booking "PC-2481" should be in state "IN_PROGRESS"

  @api
  Scenario Outline: Visit Completed is allowed once no bill is waiting for the hospital's bill
    Given booking "PC-2481" has stage "HANDOVER"
    And a hospital bill with status "<status>" exists for booking "PC-2481"
    When caretaker "Ramesh Kumar" calls "mark visit completed" for booking "PC-2481"
    Then booking "PC-2481" should be in state "COMPLETED"

    Examples:
      | status            |
      | BILL_ATTACHED     |
      | QR_MISMATCH       |
      | PAYMENT_REQUESTED |
      | DISPUTED          |

  @api
  Scenario: Attaching the hospital's bill unblocks Visit Completed
    Given booking "PC-2481" has stage "HANDOVER"
    And a "₹500" hospital bill with status "PAID_BILL_PENDING" exists for booking "PC-2481"
    When caretaker "Ramesh Kumar" attaches the hospital's bill to that bill
    And caretaker "Ramesh Kumar" calls "mark visit completed" for booking "PC-2481"
    Then booking "PC-2481" should be in state "COMPLETED"

  Scenario: Leave hospital is not blocked by a paid bill waiting for the hospital's bill
    Given I am logged in to the Caretaker app as "Ramesh Kumar"
    And every service on booking "PC-2481" has status "COMPLETED"
    And a "₹500" hospital bill with status "PAID_BILL_PENDING" exists for booking "PC-2481"
    When I open the "Services to-do" screen
    Then the "Leave hospital" button should be enabled
    When I tap "Leave hospital"
    Then I should be on the "Going home: book ride or skip" screen (D1)

  # ---------------------------------------------------------------------------
  # Visibility rules
  # ---------------------------------------------------------------------------

  Scenario Outline: What each role sees during the hospital phase
    Given I am logged in as the "<role>"
    When I open the hospital view for booking "PC-2481"
    Then I <services> service Start and Complete controls
    And I <pay> an "Approve & Pay" button for hospital bills
    And I <scan> a "Scan QR" option
    And I <whatsapp> a "Phone/Video call Caretaker" button

    Examples:
      | role                | services       | pay            | scan           | whatsapp       |
      | assigned caretaker  | should see     | should not see | should see     | should not see |
      | sponsoring user     | should not see | should see     | should not see | should see     |

  Scenario: The caretaker never sees the user's payment method or gateway details
    Given I am logged in to the Caretaker app as "Ramesh Kumar"
    And the "₹500" hospital bill was paid by "Anita Sharma"
    When I open the "Bill status" screen for that bill
    Then I should see "Anita paid ₹500"
    But I should not see the card, UPI handle or bank of the payment

  Scenario: The pickup code is not shown to the caretaker in the hospital phase
    Given I am logged in to the Caretaker app as "Ramesh Kumar"
    When I open any hospital screen for booking "PC-2481"
    Then I should not see the pickup code

  # ---------------------------------------------------------------------------
  # Session
  # ---------------------------------------------------------------------------

  @negative
  Scenario: Expired session on a hospital screen
    Given I am logged in to the Caretaker app as "Ramesh Kumar"
    And I am on the "Services to-do" screen
    When my session expires
    And I tap "Start" on the service card "Diagnostics"
    Then I should be asked to verify my mobile with OTP again
    And after verifying I should return to the "Services to-do" screen
    And the service "Diagnostics" should still have status "PENDING"
