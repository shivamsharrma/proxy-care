# Screen: P5 Confirm arrival (Caretaker app)
# Source: proxy-care-ui-ux-state-for-api-design.md (PRD v2.3) §5 P5, §1 Patient + Booking, §2 booking state + visit stage + fee strategy, §7 realtime; PRD 3.2
# The design names the "wrong code" state but not its wording; scenarios refer to it by name.
# Assumption: the field keeps ASCII digits only and caps at 4, including pasted text. The design only says "4-digit".
# Product decision (3 Nov 2026), overriding §5 P5:
#   - The pickup code does not expire, so P5 has no "Resend code" action.
# Product decision (22 Nov 2026): pickup code verification has no attempt limit and never blocks
#   the caretaker. A wrong code only shows the "wrong code" state.
#
# Open design questions (no scenario until decided):
#   - What happens on a no-show (§2 cancellation policy: full deduction, ₹0 refund)? No screen lets the caretaker report one at pickup.

@regression @caretaker-app @pickup-and-ride @P5
Feature: Caretaker confirms arrival with the pickup code
  As an assigned Caretaker at the patient's home
  I want to enter the 4-digit pickup code from the family
  So that the handover is verified and the visit officially starts

  Rules (context §1, §2, §5):
    - The code has 4 digits. The sponsor sees it in the User app and the patient receives it by SMS.
    - The caretaker never sees the code; it is only checked on the server.
    - A correct code moves the booking ASSIGNED -> IN_PROGRESS, sets stage PICKED_UP and starts billable time.
    - The patient's mobile is optional.
    - The code does not expire and cannot be resent from P5.
    - There is no attempt limit; wrong codes never block the caretaker.

  Background:
    Given today is "2026-11-02"
    And I am logged in to the Caretaker app as "Anita Verma"
    And I am assigned to booking "PC-2481" for patient "Kamla Mehta"
    And the booking is in state "ASSIGNED" with stage "HEADING_TO_PICKUP"
    And the sponsoring user is "Rohan Mehta"
    And the pickup code is "4821"
    And I am on the "P5 Confirm arrival" screen

  # ---------- Display ----------

  @smoke @ui-validation
  Scenario: P5 asks for the code without revealing it
    When I view the screen
    Then the "Pickup code" field should be empty
    And the "Pickup code" field should be marked as required
    And the "Confirm arrival" button should be disabled
    And the "Call family" button should be enabled
    And I should not see the pickup code

  # ---------- Happy path ----------

  @smoke @happy-path
  Scenario: The correct code starts the visit
    When I confirm arrival with the code "4821"
    Then the booking should be in state "IN_PROGRESS"
    And the booking should have stage "PICKED_UP"
    And billable time should have started
    And I should be on the "P6 Book ride or skip" screen
    And the sponsoring user should have the timeline event "Pickup OTP verified"
    And the sponsoring user should see the stage badge "Patient picked up"

  @ui-state
  Scenario: Confirm arrival shows progress while the code is checked
    Given the "verify pickup code" request is slow
    When I confirm arrival with the code "4821"
    Then the "Confirm arrival" button should be loading

  # ---------- Input validation ----------

  @ui-validation
  Scenario Outline: Confirm arrival is enabled only for a complete 4-digit code
    When I enter "<input>" in the "Pickup code" field
    Then the "Pickup code" field should contain "<shown>"
    And the "Confirm arrival" button should be <state>

    Examples: Too short
      | input | shown | state    |
      | 4     | 4     | disabled |
      | 48    | 48    | disabled |
      | 482   | 482   | disabled |

    Examples: Exact length
      | input | shown | state   |
      | 4821  | 4821  | enabled |

    Examples: Too long is capped at 4 digits
      | input | shown | state   |
      | 48215 | 4821  | enabled |

    Examples: Non-digits are ignored
      | input | shown | state    |
      | abcd  |       | disabled |
      | 48a1  | 481   | disabled |
      | 48-1  | 481   | disabled |
      | ४८२१  |       | disabled |

  @ui-validation
  Scenario Outline: A pasted code is cleaned to its digits
    When I paste "<pasted>" in the "Pickup code" field
    Then the "Pickup code" field should contain "<shown>"
    And the "Confirm arrival" button should be <state>

    Examples:
      | pasted | shown | state    |
      | 4821   | 4821  | enabled  |
      | 4-8-2  | 482   | disabled |
      | code   |       | disabled |

  @ui-validation
  Scenario: Spaces around a pasted code are removed
    When I paste the code "4821" with spaces around it in the "Pickup code" field
    Then the "Pickup code" field should contain "4821"
    And the "Confirm arrival" button should be enabled

  @ui-validation
  Scenario: Deleting a digit disables Confirm arrival again
    Given I have entered "4821" in the "Pickup code" field
    When I delete the last digit
    Then the "Confirm arrival" button should be disabled

  @ui-validation @device
  Scenario: The code field opens the numeric keyboard
    When I focus the "Pickup code" field
    Then the numeric keyboard should be shown

  @negative
  Scenario Outline: A wrong code does not start the visit
    When I confirm arrival with the code "<code>"
    Then I should see the "wrong code" state
    And I should be on the "P5 Confirm arrival" screen
    And the booking should be in state "ASSIGNED"
    And billable time should not have started
    And the sponsoring user should not have the timeline event "Pickup OTP verified"

    Examples: Unrelated codes
      | code |
      | 1234 |
      | 0000 |

    Examples: One digit or one swap away
      | code |
      | 4822 |
      | 8421 |

  @negative @security
  Scenario: The code of another booking is not accepted
    Given booking "PC-2490" has the pickup code "9173"
    When I confirm arrival with the code "9173"
    Then I should see the "wrong code" state
    And the booking should be in state "ASSIGNED"

  @negative
  Scenario: The right code is accepted after a wrong attempt
    Given I have made 1 wrong code attempt
    When I confirm arrival with the code "4821"
    Then the booking should be in state "IN_PROGRESS"
    And I should be on the "P6 Book ride or skip" screen

  @negative
  Scenario: Many wrong attempts never block the caretaker
    Given I have made 20 wrong code attempts
    When I confirm arrival with the code "4821"
    Then the booking should be in state "IN_PROGRESS"
    And I should be on the "P6 Book ride or skip" screen

  # ---------- Code validity ----------

  @happy-path
  Scenario: A code issued days earlier is still valid on the visit day
    Given the pickup code was issued on "2026-10-29"
    When I confirm arrival with the code "4821"
    Then the booking should be in state "IN_PROGRESS"
    
  # ---------- Actions ----------

  @happy-path @device
  Scenario: Call family opens the dialer so the caretaker can ask for the code
    When I tap "Call family"
    Then the phone dialer should open with the number of "Rohan Mehta"

  # ---------- Resilience ----------

  @negative
  Scenario: A double tap verifies the code once
    Given I have entered "4821" in the "Pickup code" field
    When I double tap "Confirm arrival"
    Then exactly 1 "verify pickup code" request should be sent
    And I should be on the "P6 Book ride or skip" screen

  @ui-state @negative
  Scenario: A network failure keeps the entered code and allows a retry
    Given the "verify pickup code" request will fail
    When I confirm arrival with the code "4821"
    Then I should see the "error" state
    And I should not see the "wrong code" state
    And the "Pickup code" field should contain "4821"
    And the "Confirm arrival" button should be enabled
    And the booking should be in state "ASSIGNED"

  @negative @api
  Scenario: Retrying after a lost response keeps the original start time
    Given the code "4821" was verified at "09:58 AM" and the response was lost
    When the caretaker client submits the code "4821" at "09:59 AM"
    Then the server should accept the request
    And billable time should have started at "09:58 AM"
    And the sponsoring user should have 1 "Pickup OTP verified" timeline event

  @ui-state @negative
  Scenario: Going offline blocks confirmation
    Given I have entered "4821" in the "Pickup code" field
    When the device goes offline
    Then I should see the "offline banner" state
    And the "Confirm arrival" button should be disabled

  # ---------- Navigation ----------

  @navigation @device
  Scenario: Back from P5 before verification returns to P4
    When I press the device back button
    Then I should be on the "P4 Start trip to pickup" screen
    And the booking should be in state "ASSIGNED"

  @navigation @device
  Scenario: A verified code cannot be revisited with back
    Given I have confirmed arrival with the correct code
    When I press the device back button
    Then I should not be on the "P5 Confirm arrival" screen
    And the booking should be in state "IN_PROGRESS"

  @navigation @device
  Scenario: Reopening the app before verification resumes at P4
    Given I have entered "48" in the "Pickup code" field
    When I force close and reopen the app
    And I resume the ongoing visit
    Then I should be on the "P4 Start trip to pickup" screen

  @navigation @device
  Scenario: Reopening the app after verification resumes at P6
    Given I have confirmed arrival with the correct code
    When I force close and reopen the app
    And I resume the ongoing visit
    Then I should be on the "P6 Book ride or skip" screen
