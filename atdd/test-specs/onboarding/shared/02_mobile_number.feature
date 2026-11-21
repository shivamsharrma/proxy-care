@onboarding @shared @screen-02
Feature: Mobile number entry (Screen 02)
  As a User or Caretaker signing up
  I want to enter my mobile number and receive an OTP
  So that I can prove I own the number

  # Source: proxy-care-api-context.md §4 "02 Mobile number" (shared by both roles)
  # Inputs: country code (+91), mobile (10 digits). Action: Send OTP.
  # States: invalid number, sending, rate-limited.
  # ASSUMPTION: valid Indian mobile numbers start with 6, 7, 8 or 9.
  # ASSUMPTION: error copy below is placeholder text; replace with final UX copy.

  Background:
    Given I am on the "Welcome" screen of the User app
    And I have tapped "Get started"
    And I am on the "Mobile number" screen

  @smoke @happy-path
  Scenario: Sending an OTP to a valid mobile number
    When I enter the mobile number "9876543210"
    And I tap "Send OTP"
    Then I should see a loading indicator on the "Send OTP" button
    And the "Send OTP" button should be disabled while sending
    And an OTP should be sent to "+91 9876543210"
    And I should see the "Verify OTP" screen

  @ui-state
  Scenario: Country code is fixed to +91
    Then the country code field should show "+91"
    And the country code field should not be editable

  @ui-state
  Scenario: Mobile field opens the numeric keypad
    When I tap the mobile number field
    Then the numeric keypad should be shown

  @ui-state
  Scenario: Send OTP is disabled until 10 digits are entered
    Then the "Send OTP" button should be disabled
    When I enter the mobile number "98765"
    Then the "Send OTP" button should be disabled
    When I enter the mobile number "9876543210"
    Then the "Send OTP" button should be enabled

  @validation
  Scenario: The mobile field accepts at most 10 digits
    When I type "98765432109" into the mobile number field
    Then the mobile number field should contain "9876543210"

  @validation
  Scenario Outline: Non-digit characters are not accepted in the mobile field
    When I type "<typed>" into the mobile number field
    Then the mobile number field should contain "<stored>"

    Examples:
      | typed          | stored     |
      | 98765abc43210  | 9876543210 |
      | 98765-43210    | 9876543210 |
      | 98765 43210    | 9876543210 |

  @negative @validation
  Scenario Outline: Invalid mobile numbers are rejected
    When I enter the mobile number "<mobile>"
    And I tap "Send OTP"
    Then I should see the inline error "Enter a valid 10-digit mobile number"
    And no OTP should be sent
    And I should remain on the "Mobile number" screen

    Examples:
      | mobile     | reason                    |
      | 0123456789 | starts with 0             |
      | 1234567890 | starts with 1             |
      | 5123456789 | starts with 5             |
      | 0000000000 | all zeros                 |

  @negative @validation
  Scenario: Inline error clears when the user corrects the number
    Given I have entered the mobile number "0123456789" and tapped "Send OTP"
    And I see the inline error "Enter a valid 10-digit mobile number"
    When I clear the mobile number field
    And I enter the mobile number "9876543210"
    Then the inline error should not be shown

  @negative
  Scenario: OTP requests are rate-limited
    Given the number "9876543210" has reached the OTP request limit
    When I enter the mobile number "9876543210"
    And I tap "Send OTP"
    Then I should see the message "Too many attempts. Try again in a few minutes."
    And the "Send OTP" button should be disabled until the lock period ends
    And I should remain on the "Mobile number" screen

  @negative
  Scenario: Network failure while sending the OTP
    Given the device has no internet connection
    When I enter the mobile number "9876543210"
    And I tap "Send OTP"
    Then I should see the error "No internet connection. Check your connection and try again."
    And the "Send OTP" button should be enabled again
    And I should remain on the "Mobile number" screen

  @negative
  Scenario: Server error while sending the OTP
    Given the OTP service returns a server error
    When I enter the mobile number "9876543210"
    And I tap "Send OTP"
    Then I should see the error "Couldn't send the code. Please try again."
    And the "Send OTP" button should be enabled again

  @edge-case
  Scenario: Tapping Send OTP twice quickly sends only one OTP
    When I enter the mobile number "9876543210"
    And I tap "Send OTP" twice quickly
    Then exactly one OTP request should be sent

  @navigation
  Scenario: Back from Mobile number returns to Welcome without losing the language
    Given I had selected "हिन्दी" on the Welcome screen
    When I press the back button
    Then I should see the "Welcome" screen
    And the language should still be "हिन्दी"

  @navigation
  Scenario: The Caretaker app uses the same Mobile number screen
    Given I am on the "Welcome" screen of the Caretaker app
    When I tap "Get started"
    Then I should see the "Mobile number" screen
    And the screen should have the same fields and "Send OTP" action
