@onboarding @caretaker-app @screen-C5
Feature: Caretaker payout account (Screen C5)
  As a Caretaker who has booked a video KYC call
  I want to add the bank account where my earnings are paid
  So that I can withdraw my earnings later

  # Source: proxy-care-api-context.md §5 "C5 Payout account"; PRD §2.1 Account & Payout Setup
  # Inputs: account holder name*, account number*, re-enter account number*, IFSC*
  #         (auto-fills bank, branch, PIN). Action: Submit for review -> C6.
  # A Rs 1 test deposit confirms the account. States: IFSC invalid, numbers mismatch, test deposit failed.
  # ASSUMPTION: account number 9-18 digits; IFSC = 4 letters + "0" + 6 letters/digits; copy is placeholder.

  Background:
    Given I am a caretaker who has completed basic information
    And I have taken a profile photo and booked a video KYC call
    And I am on the "Payout account" screen

  @ui-state
  Scenario: Payout form shows required fields and read-only bank details
    Then I should see the field "Account holder name" marked as required
    And I should see the field "Account number" marked as required
    And I should see the field "Re-enter account number" marked as required
    And I should see the field "IFSC" marked as required
    And the "Bank", "Branch" and "PIN" fields should be read-only and empty
    And I should see a note that ₹1 will be sent to confirm the account
    And the "Submit for review" button should be disabled

  @ui-state
  Scenario: Account number fields are masked and use the numeric keypad
    Then the "Account number" input should open the numeric keypad
    And the "Re-enter account number" input should open the numeric keypad
    And pasting into "Re-enter account number" should be blocked

  @smoke @happy-path
  Scenario: Adding a bank account and submitting for review
    When I enter "Anita Deshmukh" in "Account holder name"
    And I enter "123456789012" in "Account number"
    And I enter "123456789012" in "Re-enter account number"
    And I enter "HDFC0001234" in "IFSC"
    Then "Bank" should be filled with "HDFC Bank"
    And "Branch" should be filled with the branch for "HDFC0001234"
    And "PIN" should be filled with the branch PIN code
    When I tap "Submit for review"
    Then I should see "Sending ₹1 to confirm your account"
    And a ₹1 test deposit should be sent to account "123456789012"
    And when the test deposit succeeds my KYC status should become "SUBMITTED"
    And I should see the "Under review" screen

  @happy-path
  Scenario: IFSC is converted to upper case
    When I type "hdfc0001234" into "IFSC"
    Then the "IFSC" field should contain "HDFC0001234"

  @ui-state
  Scenario: Bank details show a loading state while IFSC is looked up
    Given the IFSC lookup is slow
    When I enter "HDFC0001234" in "IFSC"
    Then I should see a loading indicator next to "IFSC"

  @negative @validation
  Scenario Outline: Invalid IFSC codes are rejected
    When I enter "<ifsc>" in "IFSC"
    And I move focus out of the "IFSC" input
    Then I should see the inline error "<error>" under "IFSC"
    And the "Bank", "Branch" and "PIN" fields should stay empty
    And the "Submit for review" button should be disabled

    Examples:
      | ifsc        | error                       |
      | HDFC123     | Enter a valid 11-character IFSC |
      | HDFC1001234 | Enter a valid 11-character IFSC |
      | 1234HDFC567 | Enter a valid 11-character IFSC |
      | HDFC0001234X| Enter a valid 11-character IFSC |
      | ABCD0000000 | We couldn't find this IFSC  |

  @negative @validation
  Scenario: Account numbers that do not match
    When I enter "123456789012" in "Account number"
    And I enter "123456789013" in "Re-enter account number"
    And I move focus out of the "Re-enter account number" input
    Then I should see the inline error "Account numbers don't match" under "Re-enter account number"
    And the "Submit for review" button should be disabled

  @validation
  Scenario: Mismatch error clears when the numbers match
    Given I see the inline error "Account numbers don't match"
    When I correct "Re-enter account number" to "123456789012"
    Then the inline error should not be shown

  @negative @validation
  Scenario Outline: Invalid account numbers are rejected
    When I enter "<number>" in "Account number"
    And I move focus out of the "Account number" input
    Then I should see the inline error "Enter a valid account number (9 to 18 digits)" under "Account number"

    Examples:
      | number              |
      | 12345678            |
      | 1234567890123456789 |

  @negative @validation
  Scenario Outline: Missing required fields block submission
    Given I have filled the payout form with valid data
    When I clear the "<field>" input
    And I move focus out of the "<field>" input
    Then I should see the inline error "<error>" under "<field>"
    And the "Submit for review" button should be disabled

    Examples:
      | field                   | error                           |
      | Account holder name     | Enter the account holder's name |
      | Account number          | Enter your account number       |
      | Re-enter account number | Re-enter your account number    |
      | IFSC                    | Enter the IFSC                  |

  @ui-state
  Scenario: Submit for review is enabled only when all fields are valid and bank details are filled
    When I fill in all payout fields with valid data
    And the IFSC lookup has filled the bank details
    Then the "Submit for review" button should be enabled

  @negative
  Scenario: Test deposit fails
    Given I have filled the payout form with valid data
    And the ₹1 test deposit to the account fails
    When I tap "Submit for review"
    Then I should see the error "We couldn't send ₹1 to this account. Check the details and try again."
    And I should remain on the "Payout account" screen
    And my KYC status should not be "SUBMITTED"
    And the entered values should be kept

  @negative
  Scenario: Account holder name does not match the bank's record
    Given I have filled the payout form with valid data
    And the bank returns a different account holder name for the test deposit
    When I tap "Submit for review"
    Then I should see the error "The account holder name doesn't match the bank's records"
    And I should remain on the "Payout account" screen

  @negative
  Scenario: Network failure while submitting
    Given I have filled the payout form with valid data
    And the device has no internet connection
    When I tap "Submit for review"
    Then I should see the error "No internet connection. Check your connection and try again."
    And the entered values should be kept

  @edge-case
  Scenario: Submitting twice sends a single test deposit
    Given I have filled the payout form with valid data
    When I tap "Submit for review" twice quickly
    Then exactly one ₹1 test deposit should be sent

  @edge-case
  Scenario: App closed while the test deposit is pending
    Given I tapped "Submit for review"
    And the test deposit is still pending
    When I close and relaunch the app
    Then I should see the pending state "Confirming your account"
    And when the deposit succeeds I should see the "Under review" screen

  @navigation
  Scenario: Back from Payout account returns to the checklist
    When I press the back button
    Then I should see the "KYC checklist" screen
    And the "Photo & video KYC" step should be marked "Done"
    And the "Payout account" step should be marked "Current"
