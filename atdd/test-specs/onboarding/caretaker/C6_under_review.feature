@onboarding @caretaker-app @screen-C6
Feature: Caretaker application under review (Screen C6)
  As a Caretaker who has submitted onboarding
  I want to see the status of my application and my video KYC call
  So that I know what happens next and when I can start taking visits

  # Source: proxy-care-api-context.md §5 "C6 Under review"; backlog E2-06 (ops approve/reject + online gate)
  # Displays: status timeline (details submitted, video KYC at time, approval ~24 h after call).
  # Actions: Reschedule call; Go to home -> P1.
  # MVP RULE: the "Aadhaar/PAN verified" timeline entry is NOT shown because C3 is not in the MVP.
  # DECISION: no call outcome ("completed", "missed") is recorded in the MVP; an admin only approves
  #           or rejects the KYC (ADMIN-only endpoint). A rescheduled slot is stored as is, with no
  #           availability check. Those scenarios are tagged @IgnoreForMVP.
  # ASSUMPTION: an unapproved caretaker cannot go online on P1 (backlog "online gate").
  # DECISION (2026-11-28): the ₹1 test deposit runs in the background after submission; its result is
  #           the "Bank account" timeline entry. The account becomes ACTIVE only when the video KYC is
  #           approved and the bank account is confirmed, in either order.

  Background:
    Given I am a caretaker who has submitted onboarding
    And my video KYC call is booked for "Tomorrow, 11:00 AM"
    And my onboarding status is "SUBMITTED"
    And I am on the "Under review" screen

  @smoke @happy-path @mvp-scope
  Scenario: Under review shows the MVP status timeline
    Then I should see the status timeline in this order:
      | entry                    | state   |
      | Details submitted        | Done    |
      | Bank account             | Confirming |
      | Video KYC call           | Upcoming|
      | Approval                 | To do   |
    And the "Video KYC call" entry should show "Tomorrow, 11:00 AM"
    And the "Approval" entry should say it takes about 24 hours after the call

  @happy-path
  Scenario: Rescheduling the video KYC call
    When I tap "Reschedule call"
    Then I should see the available video KYC time slots
    When I select the slot "Day after tomorrow, 2:00 PM"
    And I confirm the new slot
    Then the "Video KYC call" entry should show "Day after tomorrow, 2:00 PM"
    And the old slot "Tomorrow, 11:00 AM" should be released

  @navigation
  Scenario: Cancelling a reschedule keeps the original slot
    When I tap "Reschedule call"
    And I close the slot picker without choosing
    Then the "Video KYC call" entry should still show "Tomorrow, 11:00 AM"

  @negative @IgnoreForMVP
  Scenario: Rescheduling fails because the slot was taken
    When I tap "Reschedule call"
    And I select a slot that becomes fully booked before I confirm
    And I confirm the new slot
    Then I should see the error "That time was just taken. Please choose another."
    And the "Video KYC call" entry should still show "Tomorrow, 11:00 AM"

  @happy-path
  Scenario: Going to Home while under review
    When I tap "Go to home"
    Then I should see the "Home (P1)" screen
    And I should see a banner that my application is under review
    And the online/offline toggle should be disabled
    And I should not receive new visit requests

  @happy-path @IgnoreForMVP
  Scenario: Video KYC call completed
    Given my video KYC call has been completed
    When I open the "Under review" screen
    Then the "Video KYC call" entry should be marked "Done"
    And the "Approval" entry should be marked "In progress"

  @happy-path
  Scenario: Bank account confirmed
    Given the ₹1 test deposit to my account succeeded
    When I open the "Under review" screen
    Then the "Bank account" entry should be marked "Done"

  @negative
  Scenario: Bank check failed
    Given the ₹1 test deposit to my account failed
    When I open the "Under review" screen
    Then the "Bank account" entry should be marked "Failed"
    And I should see the error "We couldn't send ₹1 to this account. Check the details and try again."
    And I should see an "Update bank details" action

  @negative
  Scenario: Account holder name does not match the bank's record
    Given the bank returned a different account holder name for the ₹1 test deposit
    When I open the "Under review" screen
    Then the "Bank account" entry should be marked "Failed"
    And I should see the error "The account holder name doesn't match the bank's records"
    And I should see an "Update bank details" action

  @navigation
  Scenario: Update bank details opens the payout form
    Given the ₹1 test deposit to my account failed
    When I tap "Update bank details"
    Then I should see the "Payout account" screen

  @edge-case
  Scenario: App closed while the test deposit is pending
    Given the ₹1 test deposit to my account is still pending
    When I close and relaunch the app
    Then I should see the "Under review" screen
    And the "Bank account" entry should show "Confirming your account"

  @negative
  Scenario Outline: Video approved but bank account not confirmed
    Given ops approves my video KYC
    And my bank account check is "<bank>"
    When I open the app
    Then I should see the "Under review" screen

    Examples:
      | bank       |
      | confirming |
      | failed     |

  @happy-path
  Scenario: Application approved
    Given ops approves my video KYC
    And my bank account is confirmed
    When I open the app
    Then I should see the "Home (P1)" screen
    And I should see a confirmation that my account is approved
    And the online/offline toggle should be enabled

  @negative
  Scenario: Application rejected
    Given ops rejects my video KYC with a reason
    When I open the app
    Then I should see that my application was not approved
    And I should see the rejection reason
    And the online/offline toggle should not be available

  @negative @IgnoreForMVP
  Scenario: Missed video KYC call prompts a reschedule
    Given my video KYC call time has passed without the call taking place
    When I open the "Under review" screen
    Then I should see the message "You missed your video call. Book a new time."
    And the "Reschedule call" action should be highlighted

  @negative
  Scenario: Status fails to load
    Given the review status request fails
    When I open the "Under review" screen
    Then I should see the error "Couldn't load your status. Try again."
    And I should see a "Retry" button

  @navigation
  Scenario: Back from Under review does not reopen onboarding forms
    When I press the back button
    Then I should not see the "Payout account" screen
    And I should not see the "KYC checklist" screen

  @navigation
  Scenario: Relaunching while under review opens Under review
    When I close and relaunch the app
    Then I should see the "Under review" screen
