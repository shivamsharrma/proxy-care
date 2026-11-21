@onboarding @user-app @screen-04
Feature: User profile - Stage A (Screen 04)
  As a newly verified family User
  I want to set up my own profile
  So that Proxy Care knows who is booking and where I live

  # Source: proxy-care-api-context.md §4 "04 User profile (Stage A)"
  # Inputs: full name*, sex* (F/M/Other), age, mobile (prefilled, verified, read-only),
  #         address* (text or "use current location"). Action: Continue -> 05.
  # ASSUMPTION: name 2-50 chars, letters/spaces/.'- only; age optional, whole number 18-120.
  # ASSUMPTION: error copy is placeholder.

  Background:
    Given I am signing up in the User app
    And I have verified the mobile number "9876543210"
    And I am on the "User profile" screen

  @ui-state
  Scenario: Profile form shows required fields and the verified mobile
    Then I should see the field "Full name" marked as required
    And I should see the sex options "Female", "Male" and "Other" marked as required
    And I should see the optional field "Age"
    And I should see the field "Address" marked as required
    And I should see the option "Use current location"
    And the mobile field should show "+91 9876543210"
    And the mobile field should be read-only
    And the mobile field should show a "Verified" badge

  @smoke @happy-path
  Scenario: Completing the profile with a typed address
    When I enter "Rahul Sharma" in "Full name"
    And I select the sex "Male"
    And I enter "34" in "Age"
    And I enter "Flat 12, Sunrise Apartments, Kothrud, Pune 411038" in "Address"
    And I tap "Continue"
    Then my user profile should be saved
    And I should see the "Add family member" screen

  @happy-path
  Scenario: Completing the profile without the optional age
    When I enter "Priya Nair" in "Full name"
    And I select the sex "Female"
    And I enter "22 MG Road, Bengaluru 560001" in "Address"
    And I tap "Continue"
    Then my user profile should be saved without an age
    And I should see the "Add family member" screen

  @happy-path
  Scenario: Filling the address with the current location
    Given location permission is granted
    And the device location resolves to "Koregaon Park, Pune 411001"
    When I tap "Use current location"
    Then I should see a loading indicator in the address field
    And the "Address" field should be filled with "Koregaon Park, Pune 411001"
    And the "Address" field should stay editable

  @happy-path
  Scenario: Location permission prompt on first use
    Given location permission has not been requested yet
    When I tap "Use current location"
    Then the system location permission prompt should be shown

  @negative
  Scenario: Location permission denied
    Given location permission is denied
    When I tap "Use current location"
    Then I should see the message "Allow location access or type your address"
    And the "Address" field should stay empty and editable

  @negative
  Scenario: Location could not be resolved
    Given location permission is granted
    And the device location cannot be resolved
    When I tap "Use current location"
    Then I should see the message "Couldn't find your location. Please type your address."

  @ui-state
  Scenario: Continue is disabled until all required fields are filled
    Then the "Continue" button should be disabled
    When I enter "Rahul Sharma" in "Full name"
    Then the "Continue" button should be disabled
    When I select the sex "Male"
    Then the "Continue" button should be disabled
    When I enter "Kothrud, Pune 411038" in "Address"
    Then the "Continue" button should be enabled

  @negative @validation
  Scenario Outline: Missing required fields show inline errors
    Given I have filled the profile form with valid data
    When I clear the "<field>" input
    And I move focus out of the "<field>" input
    Then I should see the inline error "<error>" under "<field>"
    And the "Continue" button should be disabled

    Examples:
      | field     | error                 |
      | Full name | Enter your full name  |
      | Address   | Enter your address    |

  @negative @validation
  Scenario Outline: Invalid full name values are rejected
    When I enter "<name>" in "Full name"
    And I move focus out of the "Full name" input
    Then I should see the inline error "<error>" under "Full name"

    Examples:
      | name          | error                                 |
      | R             | Name must have at least 2 characters  |
      | Rahul123      | Name can only contain letters         |
      | @@@@          | Name can only contain letters         |
      | <spaces-only> | Enter your full name                  |

  # <spaces-only> is a test-data token: the step definition types three spaces.

  @validation
  Scenario: Leading and trailing spaces are trimmed from the name
    When I enter "  Rahul Sharma  " in "Full name"
    And I complete the rest of the form with valid data
    And I tap "Continue"
    Then my profile name should be saved as "Rahul Sharma"

  @negative @validation
  Scenario Outline: Invalid age values are rejected
    When I enter "<age>" in "Age"
    And I move focus out of the "Age" input
    Then I should see the inline error "<error>" under "Age"

    Examples:
      | age | error                          |
      | 0   | Enter an age between 18 and 120 |
      | 17  | Enter an age between 18 and 120 |
      | 121 | Enter an age between 18 and 120 |

  @validation
  Scenario Outline: Age field accepts whole numbers only
    When I type "<typed>" into the "Age" input
    Then the "Age" input should contain "<stored>"

    Examples:
      | typed | stored |
      | 3a4   | 34     |
      | 34.5  | 345    |
      | -34   | 34     |
      | 1234  | 123    |

  @negative
  Scenario: Saving fails because of a network error
    Given I have filled the profile form with valid data
    And the device has no internet connection
    When I tap "Continue"
    Then I should see the error "No internet connection. Check your connection and try again."
    And all entered values should be kept
    And I should remain on the "User profile" screen

  @ui-state
  Scenario: Continue shows a loading state and prevents double submission
    Given I have filled the profile form with valid data
    When I tap "Continue" twice quickly
    Then the "Continue" button should show a loading indicator
    And exactly one profile save request should be sent

  @edge-case
  Scenario: Entered values survive the app being backgrounded
    Given I have entered "Rahul Sharma" in "Full name"
    When I send the app to the background and return
    Then the "Full name" input should still contain "Rahul Sharma"

  @navigation
  Scenario: Killing the app before Continue resumes onboarding at User profile
    Given I have not tapped "Continue"
    When I close and relaunch the app
    Then I should see the "User profile" screen
    And I should not be asked to verify my mobile number again
