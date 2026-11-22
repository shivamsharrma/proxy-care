@onboarding @shared @screen-03
Feature: Verify OTP (Screen 03)
  As a User or Caretaker signing up
  I want to enter the 6-digit code sent to my phone
  So that my mobile number is verified and I can continue

  # Source: proxy-care-api-context.md §4 "03 Verify OTP" (shared)
  # Displays: masked number, resend countdown (30 s). Input: 6-digit OTP.
  # Actions: Verify; Resend SMS; Change number.
  # States: verifying, wrong code, expired, resend locked.
  # Routing: the app decides the role. User app: no USER role yet -> 04, onboarded -> B1.
  #          Caretaker app: no CARETAKER role yet -> C1, approved -> P1.
  # DECISION: one mobile number can hold both roles. Signing up in the other app adds that
  #           role to the same account; it never blocks the number.
  # DECISION: the MVP signs in with Supabase test phone numbers and fixed OTPs; no DLT template.
  #           The OTP expires after 60 seconds. Attempt-limit, expiry and resend-lock scenarios
  #           are tagged @IgnoreForMVP.
  # ASSUMPTION: copy is placeholder.

  Background:
    Given I have requested an OTP for the mobile number "9876543210"
    And I am on the "Verify OTP" screen

  @ui-state
  Scenario: Verify OTP screen shows the masked number and the countdown
    Then I should see the masked number "+91 98XXXXXX10"
    And I should see 6 empty OTP cells
    And I should see the resend countdown starting at "00:30"
    And the "Resend SMS" action should be disabled
    And the "Verify" button should be disabled

  @ui-state
  Scenario: Resend actions become available when the countdown ends
    When 30 seconds pass
    Then the countdown should no longer be shown
    And the "Resend SMS" action should be enabled

  @ui-state
  Scenario: Verify is enabled only when all 6 digits are entered
    When I enter the OTP "12345"
    Then the "Verify" button should be disabled
    When I enter the last OTP digit "6"
    Then the "Verify" button should be enabled

  @ui-state
  Scenario: Focus moves forward on entry and backward on delete
    When I enter the digit "1" in OTP cell 1
    Then focus should move to OTP cell 2
    When I press backspace in empty OTP cell 2
    Then focus should move to OTP cell 1

  @ui-state
  Scenario: Pasting a 6-digit code fills all cells
    When I paste "482913" into the OTP field
    Then the OTP cells should show "4", "8", "2", "9", "1", "3"
    And the "Verify" button should be enabled

  @ui-state
  Scenario: SMS autofill fills the code
    When the device suggests the code "482913" from an incoming SMS
    And I accept the suggestion
    Then the OTP cells should show "482913"

  @validation
  Scenario: OTP cells accept digits only
    When I try to type "a" into OTP cell 1
    Then OTP cell 1 should stay empty

  @smoke @happy-path
  Scenario Outline: New account is routed to the first onboarding screen for the app's role
    Given I am signing up in the <app>
    And no account exists for "9876543210"
    When I enter the correct OTP
    And I tap "Verify"
    Then I should see a "Verifying" loading state
    And the mobile number should be marked as verified
    And I should see the "<next_screen>" screen

    Examples:
      | app           | next_screen   |
      | User app      | User profile  |
      | Caretaker app | KYC checklist |

  @happy-path
  Scenario Outline: Existing account goes straight to home
    Given I am signing up in the <app>
    And a fully onboarded "<role_enum>" account exists for "9876543210"
    When I enter the correct OTP
    And I tap "Verify"
    Then I should see the "<home>" screen
    And I should not see any onboarding screen

    Examples:
      | app           | role_enum | home           |
      | User app      | USER      | Home (B1)      |
      | Caretaker app | CARETAKER | Home (P1)      |

  @happy-path @multi-role
  Scenario Outline: An account with only the other role starts onboarding for this app's role
    Given I am signing up in the <app>
    And a fully onboarded "<other_role>" account exists for "9876543210"
    When I enter the correct OTP
    And I tap "Verify"
    Then I should see the "<next_screen>" screen
    And the account for "9876543210" should have the roles "USER" and "CARETAKER"
    And the existing "<other_role>" data should be unchanged

    Examples:
      | app           | other_role | next_screen   |
      | User app      | CARETAKER  | User profile  |
      | Caretaker app | USER       | KYC checklist |

  @happy-path
  Scenario: Existing caretaker with unfinished KYC resumes at the checklist
    Given I am signing up in the Caretaker app
    And a caretaker account exists for "9876543210" with KYC status "IN_PROGRESS"
    When I enter the correct OTP
    And I tap "Verify"
    Then I should see the "KYC checklist" screen
    And the first unfinished step should be marked "Current"

  @happy-path
  Scenario: Existing user with no family member resumes at Add family member
    Given I am signing up in the User app
    And a user account exists for "9876543210" with a saved profile and no family members
    When I enter the correct OTP
    And I tap "Verify"
    Then I should see the "Add family member" screen

  @negative
  Scenario: Wrong OTP shows an error and lets the user try again
    When I enter the OTP "000000"
    And I tap "Verify"
    Then I should see the inline error "That code is incorrect. Please try again."
    And the OTP cells should be shown in the error state
    And I should remain on the "Verify OTP" screen
    When I start typing a new OTP
    Then the inline error should be cleared

  @negative @IgnoreForMVP
  Scenario: Too many wrong attempts locks verification
    Given I have entered a wrong OTP the maximum number of allowed times
    When I enter the OTP "111111"
    And I tap "Verify"
    Then I should see the message "Too many wrong attempts. Request a new code."
    And the "Verify" button should be disabled
    And the "Resend SMS" action should be available once the countdown ends

  @negative @IgnoreForMVP
  Scenario: Expired OTP cannot be used
    Given the OTP sent to "9876543210" has expired
    When I enter that OTP
    And I tap "Verify"
    Then I should see the inline error "This code has expired. Request a new one."
    And I should remain on the "Verify OTP" screen

  @happy-path
  Scenario: Resending the code by SMS restarts the countdown
    Given the resend countdown has finished
    When I tap "Resend SMS"
    Then a new OTP should be sent by SMS to "+91 9876543210"
    And I should see the confirmation "New code sent"
    And the OTP cells should be cleared
    And the resend countdown should restart at "00:30"
    And the previously sent OTP should no longer be accepted


  @negative @IgnoreForMVP
  Scenario: Resend is locked after too many resends
    Given I have resent the code the maximum number of allowed times
    When the resend countdown finishes
    Then the "Resend SMS" action should be disabled
    And I should see the message "Resend limit reached. Try again later."

  @negative
  Scenario: Network failure while verifying
    Given the device has no internet connection
    When I enter the correct OTP
    And I tap "Verify"
    Then I should see the error "No internet connection. Check your connection and try again."
    And the entered OTP should be kept
    And the "Verify" button should be enabled again

  @edge-case
  Scenario: Tapping Verify twice sends a single verification request
    When I enter the correct OTP
    And I tap "Verify" twice quickly
    Then exactly one verification request should be sent

  @edge-case
  Scenario: Countdown continues correctly after the app returns from the background
    Given the resend countdown shows "00:20"
    When I send the app to the background for 25 seconds
    And I bring the app back to the foreground
    Then the "Resend SMS" action should be enabled

  @navigation
  Scenario: Change number returns to the Mobile number screen
    When I tap "Change number"
    Then I should see the "Mobile number" screen
    And the mobile number field should contain "9876543210"
    And the field should be editable

  @navigation
  Scenario: Back button behaves like Change number
    When I press the back button
    Then I should see the "Mobile number" screen

  @navigation
  Scenario: Back after successful verification does not return to the OTP screen
    Given I am signing up in the User app
    And I have verified the correct OTP
    And I am on the "User profile" screen
    When I press the back button
    Then I should not see the "Verify OTP" screen
